CREATE OR REPLACE PROCEDURE IT.PRC_PRO_MOV_CAMARA
 IS
V_TPASIEN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE;
V_CDOFCMB CC_SAL_CAMARA.COD_OFI_CAMARA%TYPE;
V_CDMONED CC_SAL_CAMARA.COD_MONEDA%TYPE;
V_FCSALDO DATE;
V_CACSBCP CC_SAL_CAMARA.BCP_CHE_ENVIADOS%TYPE;
V_CRCSBCP CC_SAL_CAMARA.BCP_CHE_RECIBIDOS%TYPE;
V_RACSBCP CC_SAL_CAMARA.BCP_CHE_DEV_CAMARA%TYPE;
V_RRCSBCP CC_SAL_CAMARA.BCP_CHE_DEV_A_CAMARA%TYPE;
V_CDMODUL GE_CUENTAS.COD_MODULO%TYPE;
V_NRSECUE GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE;
V_CDMODAL GE_CUENTAS.COD_MODALIDAD%TYPE;
V_CDTRANS GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_FCDEHOY DATE;
V_FCANTER DATE;
V_CACSINT CC_SAL_CAMARA.BCP_CHE_SUC_ENVIADOS%TYPE;
V_CRCSACT CC_SAL_CAMARA.SIS_CHE_ENVIADOS%TYPE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
V_CDUSUAR GE_MOVIMIENTOS.COD_USUARIO%TYPE;
V_COD_MON_LOCAL VARCHAR2(4) := PAG_GEN.FU_OBT_MON_LOCAL;
V_COD_OFI_MATRIZ NUMBER(3) := fug_obt_ofi_matriz; --31;-- FUN_OBT_OFI_MATRIZ;
v_res_general    number(18,2) := 0;
v_lugar  varchar2(300) := null;
V_TIPRUBRO GE_MOVIMIENTOS.TIP_MOV_RUBRO%TYPE := NULL ;
V_TIP_IMPORTE CC_SAL_CAMARA.TIP_IMPORTE%TYPE;
V_CONCEPTO GE_MOVIMIENTOS.CONCEPTO%TYPE;
---Generación de movimientos contables por la boleta bcp
------------------------- DEFINE MOVIMIEN -----------------------------
CURSOR MOVIMIEN IS
 SELECT COD_OFI_CAMARA, COD_MONEDA, FECHA,
        BCP_CHE_ENVIADOS, BCP_CHE_RECIBIDOS, BCP_CHE_DEV_CAMARA,
        BCP_CHE_DEV_A_CAMARA, BCP_CHE_SUC_ENVIADOS, SIS_CHE_RECIBIDOS, TIP_IMPORTE
   FROM CC_SAL_CAMARA
  WHERE FECHA = V_FCDEHOY
    AND COD_MONEDA = v_cod_mon_local;
------------------------------------------------------------------------
-- CHEQUES 48 HS TRASLADADOS
CURSOR che_traslados is
select cod_ofi_origen, decode(cod_transaccion,632,61,fug_obt_ofi_camara(cod_ofi_origen)) cod_ofi_compensacion,
cod_moneda, sum(monto) monto
  from ge_movimientos_ant
 where fecha = V_FCANTER
   and estado = 'N'
   and reversado = 'N'
   and cod_moneda = v_cod_mon_local
   and cod_transaccion = 632 -- cheques 48 hs
 group by cod_ofi_origen, decode(cod_transaccion,632,61,fug_obt_ofi_camara(cod_ofi_origen)) , cod_moneda
UNION
 select cod_ofi_origen, fug_obt_ofi_camara(cod_ofi_origen) cod_ofi_compensacion,
cod_moneda, sum(monto) monto
  from ge_movimientos
 where  estado = 'N'
   and reversado = 'N'
   and cod_moneda = v_cod_mon_local
   and cod_transaccion in (607,615,610) -- cheques del dia
 group by cod_ofi_origen, fug_obt_ofi_camara(cod_ofi_origen), cod_moneda;

------------------------------------------------------------------------
CURSOR che_rem is
  --12/06/2013-DI-MB: Modificado para insertar los datos de manera detallada y a pedido del contador el número de cheque en el campo GE_MOVIMIENTOS.CONCEPTO
  select cod_oficina, cod_oficina cod_ofi_origen, tipo, monto, nro_cheque
    from ge_bancos b, cc_che_remitidos a
   where a.cod_banco = b.cod_banco
     and nvl(tip_dato, 1) = 1    -- 24/07/2013 DI PN: Agregado para que solo traiga los cheques en gs
     and fecha      = V_FCDEHOY;
------------------------------------------------------------------------
CURSOR che_48Hs is
select cod_ofi_origen, 61 cod_ofi_compensacion, cod_moneda, sum(monto) monto
  from ge_movimientos_ant
 where fecha = V_FCANTER
   and estado = 'N'
   and reversado = 'N'
   and cod_moneda = v_cod_mon_local
   and cod_transaccion = 632 -- CHEQUES cargo otros bancos 48 y 72 hs ingresados el dia anterior
 group by cod_ofi_origen, cod_moneda;

-->01/07/2013-DI-MB: Creado para cambiar la manera de insertar los datos, porque en el cierre mensual da errores al obtener el número de secuencia.-
CURSOR TRA_CONTABLE IS
      Select cod_modulo     ,
             cod_modalidad  ,
             cod_oficina    ,
             cod_moneda     ,
             decode(cod_modulo,6,935,906) transaccion,
             monto          ,
             estado         ,
             reversado      ,
             nro_cuenta     ,
             cod_ofi_origen ,
             nro_caja       ,
             nro_documento  ,
             nro_documento2
        From ge_movimientos_ant
       Where fecha           = V_FCANTER
         and estado          = 'N'
         and reversado       = 'N'
         and cod_moneda      <> v_cod_mon_local
         and cod_transaccion = 632 -- solo los cheques usd 48hs
         and monto           > 0;

------------------------------------------------------------------------
FUNCTION LF_SIG_SECUENCIA RETURN NUMBER IS
BEGIN
    V_NRSECUE := NVL(V_NRSECUE,0) +1;
    RETURN V_NRSECUE;
END;

PROCEDURE LP_GEN_MOV_CON
        (P_CDMODUL IN NUMBER,
         P_CDMODAL IN NUMBER,
         P_CDOFICI IN NUMBER,
         P_CDOFIOR IN NUMBER,
         P_CDMONED IN CHAR,
         P_CDMODUP IN NUMBER,
         P_CDMODAP IN NUMBER,
         P_CDTRANS IN NUMBER,
         P_CONCEPT IN CHAR,
         P_IMTRANS IN NUMBER,
         P_TPMOVIM IN VARCHAR2 DEFAULT NULL,
         P_CDSECTO IN VARCHAR2  DEFAULT NULL) IS

   V_NRO_CUENTA     GE_MOVIMIENTOS.NRO_CUENTA%type := null;
   V_TIP_MOVIMIENTO GE_TIP_ASIENTOS.TIP_MOVIMIENTO%type;
   V_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE;
BEGIN
        V_NRSECUE := NVL(V_NRSECUE,0) +1;
        IF V_NRSECUE > 990 THEN
           --V_HORA    := PAG_GEN.FU_OBT_SIG_SEGUNDO(V_HORA);
           V_HORA := FUG_OBT_HOR_DISPONIBLE(V_FCDEHOY,V_HORA,user,'N');
           V_NRSECUE := 1;
        END IF;
        IF P_CDTRANS = 630 THEN -- SPI 1775. CB. 06/09/2013
           -- 07/04/2016-JIRA-2032 :
           --V_NRO_CUENTA := '3104000026'; -- BCP CTA CTE
               V_COD_RUBRO := fug_obt_pardinamico('COD_RUB_TRA_SIPAP');
               -- DÉBITO --
               V_TIPRUBRO := 'D';
              INSERT INTO GE_MOVIMIENTOS
                     (COD_USUARIO, HORA, NRO_SECUENCIA, COD_MODULO,
                      COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, COD_TRA_PADRE,
                      COD_TRANSACCION, FECHA, FEC_VALOR, MONTO, ESTADO,
                      EMI_AVISO, CONCEPTO, COD_OFI_ORIGEN, COD_MOD_PADRE, COD_MAD_PADRE,
                      REVERSADO, PROTEGIDO, TIP_MOV_RUBRO, COD_RUBRO,COTIZACION, MTO_EQU_LOCAL)
              VALUES
                     (V_CDUSUAR, V_HORA, V_NRSECUE,
                       P_CDMODUL, P_CDMODAL, P_CDOFICI, NULL,
                      P_CDMONED, V_CDTRANS, P_CDTRANS, V_FCDEHOY,
                      V_FCDEHOY, P_IMTRANS, 'N', 'N', substr(P_CONCEPT,1,35),
                      P_CDOFIOR, P_CDMODUP,P_CDMODAP,'N','N',
                      /*MM.TIP_MOVIMIENTO,MM.COD_RUBRO*/V_TIPRUBRO,V_COD_RUBRO,NULL, NULL); --12/06/2013-DI-MB: Modificado porque se va insertar un solo registro
        ELSE
            INSERT INTO GE_MOVIMIENTOS
                     (COD_USUARIO, HORA, NRO_SECUENCIA, COD_MODULO,
                      COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, COD_TRA_PADRE,
                      COD_TRANSACCION, FECHA, FEC_VALOR, MONTO, ESTADO,
                      EMI_AVISO, CONCEPTO, COD_OFI_ORIGEN, COD_MOD_PADRE, COD_MAD_PADRE,
                      REVERSADO, PROTEGIDO, TIP_MOV_RUBRO, COD_RUBRO,COTIZACION, MTO_EQU_LOCAL)
                  VALUES
                     (V_CDUSUAR, V_HORA, V_NRSECUE,
                      P_CDMODUL, P_CDMODAL, P_CDOFICI, V_NRO_CUENTA,
                      P_CDMONED, V_CDTRANS, P_CDTRANS, V_FCDEHOY,
                      V_FCDEHOY, P_IMTRANS, 'N', 'N', substr(P_CONCEPT,1,35),
                      P_CDOFIOR, P_CDMODUP,P_CDMODAP,'N','N',
                      /*MM.TIP_MOVIMIENTO,MM.COD_RUBRO*/NULL,NULL,NULL, NULL); --12/06/2013-DI-MB: Modificado porque se va insertar un solo registro
              --END LOOP;
        END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. No existe Transaccion p/ '||v_cdmodul||'-'||v_cdmodal||TO_CHAR(V_CDTRANS));
  WHEN TOO_MANY_ROWS THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Existen varias transacc. '||v_cdmodul||'-'||V_cdmodal||TO_CHAR(V_CDTRANS));
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20000,SQLERRM);
END;
BEGIN
    V_CDMODUL := 4;
    V_CDMODAL := 41;
    V_CDTRANS := 596; -- transaccion padre
    -- V_HORA    := fug_ini_hora(SYSDATE,'HH24:MI:SS');
    V_CDUSUAR := substr(user,1,10);
    pag_cal.PR_OBT_DAT_CALENDAR(4);
    V_FCDEHOY := pag_cal.fu_obt_fec_actual(4);
    V_HORA := to_char(sysdate,'HH24:MI:SS');
    V_HORA := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
    V_FCANTER := pag_cal.G_FEC_ANTERIOR;
    IF MOVIMIEN%ISOPEN THEN
     CLOSE MOVIMIEN;
    END IF;
    ----

    SELECT SUM((NVL(BCP_CHE_ENVIADOS,0)  + NVL(BCP_CHE_DEV_A_CAMARA,0)) -
               (NVL(BCP_CHE_RECIBIDOS,0) + NVL(BCP_CHE_DEV_CAMARA,0)))
      INTO V_RES_GENERAL
      FROM CC_SAL_CAMARA
     WHERE FECHA = V_FCDEHOY
       AND TIP_IMPORTE = 0
       AND COD_MONEDA = v_cod_mon_local;

    LP_GEN_MOV_CON  (4, 42, V_COD_OFI_MATRIZ,     --SPI 1775. CB. 06/09/2013
                     V_COD_OFI_MATRIZ, V_COD_MON_LOCAL,
                     4, 41, 630,
                     '630-Resultado General s/BCP',
                     V_RES_GENERAL/*,'D',NULL*/);
                     
    BEGIN
      SELECT SUM((NVL(BCP_CHE_ENVIADOS,0)  + NVL(BCP_CHE_DEV_A_CAMARA,0)) -
                 (NVL(BCP_CHE_RECIBIDOS,0) + NVL(BCP_CHE_DEV_CAMARA,0)))
        INTO V_RES_GENERAL
        FROM CC_SAL_CAMARA
       WHERE FECHA = V_FCDEHOY
         AND TIP_IMPORTE = 1
         AND COD_MONEDA = v_cod_mon_local;
    EXCEPTION
      WHEN OTHERS THEN
        V_RES_GENERAL := 0;     
    END;    
    IF V_RES_GENERAL <> 0 THEN
       LP_GEN_MOV_CON  (4, 42, V_COD_OFI_MATRIZ,     --SPI 1775. CB. 06/09/2013
                        V_COD_OFI_MATRIZ, V_COD_MON_LOCAL,
                        4, 41, 630,
                        '630-Result. Gral. s/BCP- Alto Valor',
                        V_RES_GENERAL/*,'D',NULL*/);                 
    END IF;                    
    ------------------------- LEER MOVIMIEN ------------------------------
    OPEN MOVIMIEN;
    LOOP
       FETCH MOVIMIEN INTO V_CDOFCMB, V_CDMONED, V_FCSALDO,
                           V_CACSBCP, V_CRCSBCP, V_RACSBCP,
                           V_RRCSBCP, V_CACSINT, V_CRCSACT, V_TIP_IMPORTE;
       EXIT WHEN MOVIMIEN%NOTFOUND;
       ------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR --
       ------------------------------------------------
       v_lugar := 'V_CACSBCP' ;
       IF V_CACSBCP > 0 THEN
          IF V_TIP_IMPORTE = 0 THEN 
             V_CONCEPTO := '593-Ch.a Compensar s/BCP';
          ELSE
             V_CONCEPTO := '593-Ch.a Compensar s/BCP-Alto Valor';
          END IF; 
           LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                            V_COD_OFI_MATRIZ, V_CDMONED,
                            4, 41, 593,
                            V_CONCEPTO,
                            V_CACSBCP/*,'D',NULL*/);
       END IF;
       --------------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES RECIBIDOS DE CAMARA S/ BCP--
       --------------------------------------------------------------
       v_lugar := '  V_CRCSBCP' ;
       IF V_CRCSBCP > 0 THEN
          IF V_TIP_IMPORTE = 0 THEN 
             V_CONCEPTO := '616-Ch.Recib. de Camara s/BCP';
          ELSE
             V_CONCEPTO := '616-Ch.Recib. Cam. s/BCP-Alto Valor';
          END IF;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_COD_OFI_MATRIZ, V_CDMONED,
                           4, 41, 616,
                           V_CONCEPTO,
                           V_CRCSBCP);
       END IF;
       -----------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A COMPENSAR RECHAZADOS --
       -----------------------------------------------------------
       v_lugar := '  V_RACSBCP ' ;
       IF V_RACSBCP > 0 THEN
          IF V_TIP_IMPORTE = 0 THEN 
             V_CONCEPTO := '617-Ch.a Compensar Rechaz. s/BCP';
          ELSE
             V_CONCEPTO := '617-Ch.a Comp. Rech.s/BCP-Alt Valor';
          END IF;
          LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                           V_COD_OFI_MATRIZ, V_CDMONED,
                           4, 41, 617,
                           V_CONCEPTO,
                           V_RACSBCP);
       END IF;
       --------------------------------------------------------------------
       --- GENERA MOVIENTOS PARA CHEQUES A RECIBIDO DE CAMARA RECHAZADOS --
       --------------------------------------------------------------------
       v_lugar := '  V_RRCSBCP ' ;
       IF V_RRCSBCP > 0 THEN
          IF V_TIP_IMPORTE = 0 THEN 
             V_CONCEPTO := '594-Ch.Recibidos Rechaz. s/BCP';
          ELSE
             V_CONCEPTO := '594-Ch.Recib. Rech. s/BCP-Alt Valor';
          END IF;
           LP_GEN_MOV_CON  (4, 41, V_CDOFCMB,
                            V_COD_OFI_MATRIZ, V_CDMONED,
                            4, 41, 594,
                            V_CONCEPTO,
                            V_RRCSBCP/*,'D',NULL*/);
       END IF;
    ------------------------------------------------------------
    END LOOP;
    CLOSE MOVIMIEN;
    v_lugar := '  CHE_REM ' ;
    -- ciclo por los cheques remitidos leidos por la lectora hoy
    FOR CC IN CHE_REM LOOP
     --20/06/2013-DI-MB: Modificado para que inserte un registro por cada cheque e identificar el cheque en el campo GE_MOVIMIENTOS.CONCEPTO (Pedido del Contador)
       LP_GEN_MOV_CON  (4, 41, CC.COD_OFI_ORIGEN,
                        CC.COD_OFICINA, V_COD_MON_LOCAL,
                        4, 41, 192,
                        --'192-Ch.Remit. Bcos Lectora',
                        'Che:'||CC.NRO_CHEQUE||':192-Ch.Remit. Bcos.LECTORA',
                        cc.monto--,'C');
            );
    END LOOP;
    -- ciclo por los CHEQUES 48 HS TRASLADADOS A LA OFICINA DE CAMARA
    v_lugar := '  che_traslados ' ;
    FOR CC IN che_traslados LOOP
       LP_GEN_MOV_CON  (4, 41, CC.COD_OFI_ORIGEN,
                        CC.COD_OFI_COMPENSACION, cc.cod_moneda,
                        4, 41, 195,
                        '195-Ch. 48 Hs.',
                        cc.monto/*,'C'*/);
    END LOOP;
    v_lugar := '  CHE_48HS ' ;
    -- ciclo por los cheques del interior a compensar
    FOR CC IN CHE_48HS LOOP
       LP_GEN_MOV_CON  (4, 41, CC.COD_OFI_ORIGEN,
                        CC.COD_OFI_ORIGEN, cc.cod_moneda,
                        4, 41, 905,
                        '905-Ch. Interior a Compensar',
                        cc.monto/*,'D'*/);

       /*LP_GEN_MOV_CON  (4, 41, CC.COD_OFI_ORIGEN,
                        CC.COD_OFI_ORIGEN, cc.cod_moneda,
                        4, 41, 905,
                        '905-Ch. Interior a Compensar',
                        cc.monto,'C');*/
    END LOOP;

    v_lugar := '  insert ge_mov ' ;
    --> 01/07/2013-DI-MB: Modificado porque en el cierre de fin de mes dió un error al obtener el número de secuencia.-
    V_NRSECUE := 0;
    --v_hora    := pag_gen.fu_obt_sig_segundo(v_hora);
    v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
    For tr in TRA_CONTABLE Loop
        Begin
            v_nrsecue := nvl(v_nrsecue,0) +1;
            If v_nrsecue > 990 Then
               --v_hora    := pag_gen.fu_obt_sig_segundo(v_hora);
               v_hora := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
               v_nrsecue := 1;
            End If;
            Insert Into ge_movimientos (cod_modulo     ,
                                        cod_modalidad  ,
                                        cod_oficina    ,
                                        cod_moneda     ,
                                        cod_tra_padre  ,
                                        cod_transaccion,
                                        fecha          ,--
                                        fec_valor      ,
                                        monto          ,
                                        estado         ,
                                        concepto       ,
                                        reversado      ,
                                        cod_mod_padre  ,
                                        cod_mad_padre  ,
                                        cod_usuario    ,--
                                        hora           ,--
                                        nro_secuencia  ,--
                                        nro_cuenta     ,
                                        cod_ofi_origen ,
                                        nro_caja       ,
                                        cotizacion     ,
                                        mto_equ_local  ,
                                        nro_documento  ,
                                        nro_documento2 )
                                 values(tr.cod_modulo      ,
                                        tr.cod_modalidad   ,
                                        tr.cod_oficina     ,
                                        tr.cod_moneda      ,
                                        v_cdtrans          ,
                                        tr.transaccion     ,
                                        v_fcdehoy          ,--
                                        v_fcdehoy          ,
                                        tr.monto           ,
                                        tr.estado          ,
                                        'Traslado Contable',
                                        tr.reversado       ,
                                        4                  ,
                                        41                 ,
                                        v_cdusuar          ,--
                                        v_hora             ,--
                                        v_nrsecue          ,--
                                        tr.nro_cuenta      ,
                                        tr.cod_ofi_origen  ,
                                        tr.nro_caja        ,
                                        null               ,
                                        null               ,
                                        tr.nro_documento   ,
                                        tr.nro_documento2  );
        Exception
                 When Others then
                      raise_application_error(-20000,'Error Insertando Traslado Contable '||v_hora||sqlerrm);
        End;
    End Loop;

exception
  when others then
     raise_application_error(-20001, 'Error en '||v_lugar|| sqlerrm );
END;
/

