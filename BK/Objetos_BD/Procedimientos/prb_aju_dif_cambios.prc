CREATE OR REPLACE PROCEDURE IT.PRB_AJU_DIF_CAMBIOS is
  /* proceso diario de ajuste por diferencia de cambios */
  v_fec_actual       date          := pag_cal.fu_obt_fec_actual(2);
  v_ano              number(4)     := to_char(v_fec_actual,'yyyy');
  v_mes              number(2)     := to_char(v_fec_actual,'mm');
  v_cod_mon_local    varchar2(4)   := pag_gen.FU_OBT_MON_LOCAL;
  v_error            varchar2(100);
  ----
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_cod_rubro        cb_rubros.cod_rubro%type;
  v_aju_oficina      VARCHAR2(01);
  v_sal_mon_local    NUMBER(18,2);
  v_sal_mon_rubro    NUMBER(18,2);
  v_cod_rub_dif_cam  VARCHAR2(15);
  v_cod_tip_cuenta   NUMBER(2);
  v_cod_moneda       ba_monedas.cod_moneda%type;
  v_cod_rub_utilidad cb_rubros.cod_rubro%type;
  v_cod_rub_perdida  cb_rubros.cod_rubro%type;
  ----
  v_tot_control      NUMBER;
  v_tot_acumulado    NUMBER;
  v_nro_linea        NUMBER;
  v_imp_dif_cambios  NUMBER;
  v_nro_asiento      NUMBER;
  asiento            NUMBER;
  v_diferencia       NUMBER;
  v_tip_movimiento   VARCHAR2(1);
  v_tip_mov_contra   VARCHAR2(1);
  v_cas_matriz       number(3);
  v_redondeo_ml      number(5);
  ----
  CURSOR OFICINA IS
     SELECT COD_OFICINA,DESCRIPCION
       FROM BA_OFICINAS
      ORDER BY COD_OFICINA;
  ----
  CURSOR CURX is
      SELECT cb_rubros.COD_RUBRO, COD_OFICINA, /*AJUSTABLE*/ 'S',--DYDMR-2990 - Solicitado y Aprobado por Hector Bengoa.
             NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0),
             NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0),
             TIPO, COD_MONEDA
        FROM CB_SAL_OFICINAS, CB_RUBROS
       WHERE ANO = v_ano
         AND MES = v_mes
         AND cb_sal_oficinas.COD_RUBRO = CB_RUBROS.COD_RUBRO
         AND IMPUTABLE = 'S'
         AND (TIPO IN (1,2,3,4,5,9))
         and substr(CB_RUBROS.cod_rubro,1,2) not in ('42','52')
         AND COD_MONEDA != v_cod_mon_local
         AND ((nvl(fug_obt_pardinamico('CB_IND_GEN_AJU_DIF_CAMBIOS'), 'N') = 'S' and
              CB_RUBROS.AJUSTABLE = 'S') or
              (nvl(fug_obt_pardinamico('CB_IND_GEN_AJU_DIF_CAMBIOS'), 'N') = 'N' and
              CB_RUBROS.AJUSTABLE in ('S', 'N')))
      ORDER BY COD_MONEDA,cb_rubros.COD_RUBRO,COD_OFICINA;
  ------
  WT_TASCTZ NUMBER;
  WT_MONEDA VARCHAR2(03);
  WC_AJCONS NUMBER(22);
  WC_CDCTAJU VARCHAR2(15);
  WT_CTACONT VARCHAR2(15) := '12';
  WT_TOTALME NUMBER(22,2);
  WT_TOTALGS NUMBER(22,2);
  WW_AJUSTO  VARCHAR2(01) := 'N';
  WT_CDOFICI NUMBER(03);
  v_hay_asiento  varchar2(1) := 'N';
  v_gen_cabecera varchar2(1) := 'N';
  v_lugar    varchar2(300);
  ---
  PROCEDURE LP_OBT_RUB_AJUSTE
    (p_cod_rubro IN     CHAR,
     p_cod_rub_utilidad IN OUT CHAR,
     p_cod_rub_perdida IN OUT CHAR) IS
  v_cod_sector varchar2(01) := SUBSTR(p_cod_rubro,1,1);
  v_cod_capitulo varchar2(01) := SUBSTR(p_cod_rubro,2,1);
  v_cod_grupo varchar2(01) := SUBSTR(p_cod_rubro,4,1);
  v_sub_cuenta varchar2(02) := SUBSTR(p_cod_rubro,9,2);
  v_tip_sub_cta varchar2(1) := 'P';
  v_nro_cuenta varchar2(3) := SUBSTR(p_cod_rubro,6,3);
  v_mod_interno varchar2(3) := substr(p_cod_rubro,11,3);
  v_cod_subcuenta  varchar2(1);
  v_cod_mon_numerico varchar2(2) := substr(p_cod_rubro,14,2);
  CURSOR C1 IS
     SELECT COD_RUB_UTILIDAD,COD_RUB_PERDIDA
      FROM CB_AJUSTES
     WHERE COD_SECTOR = v_cod_sector
       AND COD_CAPITULO = v_cod_capitulo
       AND (COD_GRUPO = v_cod_grupo OR COD_GRUPO = 'T')
       AND (NRO_CUENTA = v_nro_cuenta OR NRO_CUENTA IS NULL)
       AND (COD_SUBCUENTA = v_sub_cuenta  or cod_subcuenta = v_tip_sub_cta or COD_SUBCUENTA = 'T' ) -- Modificado por ICL 18/08/2011. Tomar el registro mas detallado y posteriormente el global.
       AND (MOD_INTERNO = v_mod_interno OR MOD_INTERNO IS NULL)
       AND (COD_MON_NUMERICO = v_cod_mon_numerico OR COD_MON_NUMERICO IS NULL)
     ORDER BY COD_GRUPO desc, nvl(NRO_CUENTA,999), COD_SUBCUENTA desc, nvl(MOD_INTERNO,999);
  R1 C1%ROWTYPE;
  BEGIN
     select cod_ofi_matriz into v_cas_matriz
       from ge_par_generales;
     -- Busco las cuentas dif.cambios a ser asignadas --------------------
     IF (MOD(TO_NUMBER(v_sub_cuenta),2) = 0) OR
        (v_sub_cuenta = '01' AND v_cod_sector||v_cod_capitulo <> '12') THEN
        v_tip_sub_cta := 'P';
     ELSE
        v_tip_sub_cta := 'I';
     END IF;
     IF C1%ISOPEN THEN
        CLOSE C1;
     END IF;
     OPEN C1;
     FETCH C1 INTO R1;
     IF C1%NOTFOUND THEN
       CLOSE C1;
       raise_application_error(-20000,'ERROR. No existe Cuenta de Ajuste p/ Sec.: '||v_cod_sector||
       ' Cap: '||v_cod_capitulo||' Gru: '||v_cod_grupo||' Cta: '||v_nro_cuenta||' TipSubCta: '||v_tip_sub_cta||
       ' CodSubCta.:'||v_sub_cuenta||' y CodSubCta.:'||v_mod_interno||' y CodSubCta.:'||v_cod_subcuenta||' Rubro:'||v_cod_rubro);
     END IF;
     p_cod_rub_utilidad := R1.COD_RUB_UTILIDAD;
     p_cod_rub_perdida := R1.COD_RUB_PERDIDA;
     CLOSE C1;
  END;

BEGIN
--Deshabilitar Clave Foranea--
sql_util.ejecute_dml('Alter table cb_asientos_det disable constraint FK_BADET_NRO_ASIENTO', v_error);
if v_error is not null then
   raise_application_error(-20000,
   'Disable Fk '||v_error);
end if;
--- Inicializo las variables a ser utilizadas en el proceso -------
v_tot_acumulado     := 0;
v_nro_linea   := 0;
v_tot_control  := 0;
WT_MONEDA := 'WQX';
v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 2, 21 ,v_cod_mon_local);
--- Busco el Primer Numero de asiento disponible ------------------
asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
v_nro_asiento := -1;
---
WC_CDCTAJU := fug_obt_pardinamico('COD_RUB_TEMPORAL');
--- Ciclo de lectura de las cuentas ordenado por Moneda,Cuenta,Of.--
OPEN CURX;
WC_AJCONS  := 0;
WT_TOTALME := 0;
WT_TOTALGS := 0;
WW_AJUSTO  := 'N';

LOOP
  v_lugar := 'Antes del Fetch' ||' '|| v_cod_moneda ||' '|| v_cod_rubro ||' '|| v_cod_oficina;
  FETCH CURX INTO v_cod_rubro, v_cod_oficina, v_aju_oficina,
                  v_sal_mon_local, v_sal_mon_rubro, v_cod_tip_cuenta,
                  v_cod_moneda;
  v_lugar := 'Despues del fectch CURX';
  EXIT WHEN CURX%notfound;
  IF v_cod_rubro <> WT_CTACONT THEN
    IF WW_AJUSTO = 'S' THEN /* hubo ajuste */
       IF NVL(WT_TOTALME,0) = 0 AND NVL(WT_TOTALGS,0) IN (1,-1) THEN
          IF WC_AJCONS <> 0 THEN /* solo si se hara ajuste of.central*/
             /* hay que ajustar la ultima linea generada */
             WC_AJCONS := NVL(WC_AJCONS,0)+NVL(WT_TOTALGS,0);
          END IF;
          IF v_tip_movimiento = 'D' THEN /* si la ultima linea es debito */
             WT_TOTALGS := WT_TOTALGS * -1; /* cambio el signo*/
          END IF;
          UPDATE CB_ASIENTOS_DET
             SET MTO_MON_LOCAL = NVL(MTO_MON_LOCAL,0)+NVL(WT_TOTALGS,0)
           WHERE FECHA = v_fec_actual
             AND COD_OFICINA = WT_CDOFICI
             AND NRO_ASIENTO = v_nro_asiento
             AND NRO_LINEA IN (v_nro_linea,v_nro_linea-1);
       END IF;
    END IF;
    IF WC_AJCONS <> 0 THEN /* se debe ajustar en la ofC.Central */
       --- busca las cuentas de ajuste correspondientes ---------
       LP_OBT_RUB_AJUSTE(WT_CTACONT,v_cod_rub_utilidad,v_cod_rub_perdida);
       ----------------------------------------------------------
       IF WC_AJCONS > 0 THEN
          -- SE HACE credito a la cuenta puente
          v_diferencia   := WC_AJCONS;
          v_tip_movimiento       := 'C';
          v_tip_mov_contra := 'D';
          v_cod_rub_dif_cam    := v_cod_rub_perdida;
       ELSE
          -- SE HACE CREDITO A LA CUENTA
          v_diferencia   := WC_AJCONS * -1;
          v_tip_movimiento       := 'D';
          v_tip_mov_contra := 'C';
          v_cod_rub_dif_cam    := v_cod_rub_utilidad;
       END IF;
       --
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO,FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, WC_CDCTAJU,
             v_diferencia, 0,v_tip_movimiento, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N',v_fec_actual);
       ---
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, v_cod_rub_dif_cam,
             v_diferencia, 0,v_tip_mov_contra, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
     END IF;
     --- actualizo las variables para el siguiente corte ----
     WT_CTACONT := v_cod_rubro;
     WC_AJCONS  := 0;
     WT_TOTALME := 0;
     WT_TOTALGS := 0;
     WW_AJUSTO  := 'N';
  END IF;
  --- busco la cotizacion de la moneda solo si hubo cambio de moneda
  IF WT_MONEDA <> v_cod_moneda THEN
     WT_TASCTZ := FUG_OBT_COTIZACION(v_cod_moneda,v_fec_actual);
     WT_MONEDA := v_cod_moneda;
  END IF;
  --- Calculo el valor en M/L del saldol en M/e para si es necesario-
  v_imp_dif_cambios  := NVL(v_sal_mon_rubro,0)*NVL(WT_TASCTZ,0)-NVL(v_sal_mon_local,0);
  v_imp_dif_cambios  := ROUND(v_imp_dif_cambios,v_redondeo_ml);
  -- voy calculando el consolidado de la cuenta -----------------------
  WT_TOTALME := NVL(WT_TOTALME,0) + NVL(v_sal_mon_rubro,0);
  WT_TOTALGS := NVL(WT_TOTALGS,0) + (NVL(v_sal_mon_local,0)+NVL(v_imp_dif_cambios,0));
  ---------------------------------------------------------------------
  v_tot_acumulado    := v_tot_acumulado + v_imp_dif_cambios;
  v_tot_control := v_tot_control + ABS(v_imp_dif_cambios);
  v_diferencia := 0;
  IF v_imp_dif_cambios != 0 THEN
     IF v_imp_dif_cambios >0 THEN
        -- SE HACE DEBITO A LA CUENTA
        v_diferencia   := v_imp_dif_cambios;
        v_tip_movimiento       := 'D';
     ELSE
        -- SE HACE CREDITO A LA CUENTA
        v_diferencia   := v_imp_dif_cambios * -1;
        v_tip_movimiento       := 'C';
     END IF;
     v_hay_asiento := 'S';
     v_gen_cabecera := 'S';
     -- carga detalles (1a. Linea)           --
     -- La cuenta que tuvo diferencia        --
     ------------------------------------------
     v_nro_linea := v_nro_linea + 1;
     v_lugar := 'Genera CB_ASIENTOS_DET';
     INSERT INTO CB_ASIENTOS_DET
          (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
           MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
           DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
           DISTRIBUIDO, FECHA)
     VALUES
          (v_cod_oficina , v_nro_asiento, v_nro_linea    , v_cod_rubro,
           v_diferencia, 0, v_tip_movimiento, 'AJUSTE',
           'ASIENTO AJUSTE', 'N','N', 0 ,'N', v_fec_actual);
     -- guardo los valores para el ajuste de 1guarani si es necesario
     WW_AJUSTO := 'S';
     WT_CDOFICI := v_cod_oficina;
     ----------------------------------------------------------------
     IF v_aju_oficina = 'S' THEN
        --- busca las cuentas de ajuste correspondientes ---------
        LP_OBT_RUB_AJUSTE(v_cod_rubro,v_cod_rub_utilidad,v_cod_rub_perdida);
        ----------------------------------------------------------
        IF v_tip_movimiento = 'D' THEN
           v_cod_rub_dif_cam    := v_cod_rub_utilidad;
           v_tip_mov_contra := 'C';
        ELSE
           v_cod_rub_dif_cam    := v_cod_rub_perdida;
           v_tip_mov_contra := 'D';
        END IF;
     ELSE
        v_cod_rub_dif_cam := WC_CDCTAJU;  /* cuenta puente de ajuste */
        IF v_tip_movimiento = 'D' THEN
           WC_AJCONS := NVL(WC_AJCONS,0) - NVL(v_diferencia,0);
           v_tip_mov_contra := 'C';
        ELSE
           WC_AJCONS := NVL(WC_AJCONS,0) + NVL(v_diferencia,0);
           v_tip_mov_contra := 'D';
        END IF;
     END IF;
     -----------------------------------------------
     -- carga detalle CUENTA DIFERENCIA DE CAMBIO --
     -----------------------------------------------
     v_nro_linea := v_nro_linea + 1;
     INSERT INTO CB_ASIENTOS_DET
           (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
            MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
            DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
            DISTRIBUIDO, FECHA)
     VALUES
           (v_cod_oficina, v_nro_asiento, v_nro_linea, v_cod_rub_dif_cam,
            v_diferencia, 0,v_tip_mov_contra, 'AJUSTE',
            'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
   END IF;
------------------------------------------------------------------
   END LOOP;
   CLOSE CURX;
   /* El ultimo corte leido */
   IF WW_AJUSTO = 'S' THEN /* hubo ajuste */
       IF NVL(WT_TOTALME,0) = 0 AND NVL(WT_TOTALGS,0) IN (1,-1) THEN
          /* hay que ajustar la ultima linea generada */
          WC_AJCONS := NVL(WC_AJCONS,0)+NVL(WT_TOTALGS,0);
          IF v_tip_movimiento = 'D' THEN /* si la ultima linea es debito */
             WT_TOTALGS := WT_TOTALGS * -1; /* cambio el signo*/
          END IF;
          UPDATE CB_ASIENTOS_DET
             SET MTO_MON_LOCAL = NVL(MTO_MON_LOCAL,0)+NVL(WT_TOTALGS,0)
           WHERE FECHA = v_fec_actual
             AND COD_OFICINA = WT_CDOFICI
             AND NRO_ASIENTO = v_nro_asiento
             AND NRO_LINEA IN (v_nro_linea,v_nro_linea-1);
       END IF;
   END IF;
   IF WC_AJCONS <> 0 THEN /* se debe ajustar en la ofC.Central */
      IF WC_AJCONS > 0 THEN
          -- SE HACE credito a la cuenta puente
          v_diferencia   := WC_AJCONS;
          v_tip_movimiento       := 'C';
          v_tip_mov_contra := 'D';
          v_cod_rub_dif_cam    := v_cod_rub_perdida;
       ELSE
          -- SE HACE CREDITO A LA CUENTA
          v_diferencia   := WC_AJCONS * -1;
          v_tip_movimiento       := 'D';
          v_tip_mov_contra := 'C';
          v_cod_rub_dif_cam    := v_cod_rub_utilidad;
       END IF;
       --
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, WC_CDCTAJU,
             v_diferencia, 0,v_tip_movimiento, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
       ---
       v_nro_linea := v_nro_linea + 1;
       INSERT INTO CB_ASIENTOS_DET
            (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
             MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
             DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
             DISTRIBUIDO, FECHA)
       VALUES
            (v_cas_matriz, v_nro_asiento, v_nro_linea, v_cod_rub_dif_cam,
             v_diferencia, 0,v_tip_mov_contra, 'AJUSTE',
             'ASIENTO AJUSTE', 'N','N', 0,'N', v_fec_actual);
   END IF;
   v_nro_asiento := asiento;
   asiento := -1;
   --v_nro_asiento := v_nro_asiento + 1;
   FOR OFI IN OFICINA LOOP
     --- Actualizo el nro de Asiento y Lineas po cada oficina ---
     UPDATE CB_ASIENTOS_DET
        SET NRO_ASIENTO = v_nro_asiento,
            NRO_LINEA = ROWNUM
      WHERE FECHA = v_fec_actual
        AND COD_OFICINA = OFI.COD_OFICINA
        AND NRO_ASIENTO = ASIENTO;
     IF SQL%FOUND THEN
        --- Sumo para el Totald e control de la cabecera --------
        SELECT SUM(MTO_MON_LOCAL) INTO v_tot_control
          FROM CB_ASIENTOS_DET
         WHERE FECHA = v_fec_actual
           AND COD_OFICINA = OFI.COD_OFICINA
           AND NRO_ASIENTO = v_nro_asiento;
        ---------------------- CABECERA -------------------------
        INSERT INTO CB_ASIENTOS
            (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
             COD_MODULO, COD_MODALIDAD,
             TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
             OFI_INTEGRADA, CONFIRMADO)
        VALUES
            (OFI.COD_OFICINA, v_nro_asiento,user,
             v_fec_actual, 2, 21,
             v_tot_control, 'N','N', NULL,'N', 'S');
        v_nro_asiento := v_nro_asiento + 1;
      END IF;
   END LOOP;
   ------- ACTUALIZA PARAMETROS -----
   prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);
   ---------------------------------
   --Habilitar Clave Foranea--
   sql_util.ejecute_dml('Alter table cb_asientos_det enable constraint FK_BADET_NRO_ASIENTO', v_error);
   if v_error is not null then
      raise_application_error(-20000,
      'Enable Fk '||v_error);
   end if;
EXCEPTION
   WHEN VALUE_ERROR THEN
     CLOSE CURX;
     raise_application_error(-20000,' ERROR. En valores del Procedure PROCESO_DE_AJUSTE '||'-'||v_lugar);
   WHEN OTHERS THEN
     CLOSE CURX;
     raise_application_error(-20000,'ERROR. en. Rubro:'||v_cod_rubro||'-'||v_lugar||'-'||SQLERRM);
END;
/

