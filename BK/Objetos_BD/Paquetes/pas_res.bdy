CREATE OR REPLACE PACKAGE BODY IT.PAS_RES IS
V_SAL_MINIMO NUMBER(18);
V_RIESGO5     PR_PARAMETROS.POR_RIESGO_5%TYPE;
V_RIESGO2     PR_PARAMETROS.POR_RIESGO_2%TYPE;
V_RIESGO1a    PR_PARAMETROS.POR_RIESGO_1a%TYPE;
V_RIESGO1b    PR_PARAMETROS.POR_RIESGO_1b%TYPE;
V_RIESGO3     PR_PARAMETROS.POR_RIESGO_3%TYPE;
V_MIN_EXIGIDO PR_PARAMETROS.CAP_MIN_EXIGIDO%TYPE;
v_por_min_exigido pr_parametros.por_cap_min_exigido%type;
V_RIESGO4 PR_PARAMETROS.POR_RIESGO_4%TYPE;
/* Verificar si un cliente es de sólo consumo. */
FUNCTION FU_CLI_SOLO_CONSUMO
 (P_COD_CLIE IN SB_CLIENTES.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2
 IS
v_resultado varchar2(1) := 'S';
v_cantidad  number(8);
BEGIN
   SELECT COUNT(*)
     INTO v_cantidad
    FROM GE_CLA_OPERACIONES A
   WHERE A.COD_PERSONA = P_COD_CLIE
   AND A.TIP_DESTINO not in (3,4);
   IF v_cantidad > 0 then
      v_resultado := 'N'; -- no es solo consumo
   ELSE
      v_resultado := 'S';
   END IF;
   RETURN v_resultado;
END;
/* Obtener garantía hipotecaria de la cuenta. */
FUNCTION FU_OBT_GAR_HIPOTE_SB
 (P_NRO_CUENTA IN GE_CTA_CLIENTES.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
--cursor de garantías hipotecarias de la cuenta
CURSOR HIPO IS
   SELECT B.COD_MONEDA MONEDA, A.MTO_APL_COMPUTABLE MONTO
   FROM PR_CTA_GARANTIAS A, PR_GARANTIAS B, PR_GAR_TIPOS C
   WHERE A.NRO_GARANTIA = B.NRO_GARANTIA
   AND A.COD_GARANTIA = C.COD_GARANTIA
   AND B.COD_GARANTIA = C.COD_GARANTIA
   AND A.NRO_CUENTA = P_NRO_CUENTA
   AND TIPO='A'
   AND ESTADO='C'
   AND C.COD_GARANTIA = fug_obt_pardinamico('COD_GAR_HIPOTECARIA',6)
   AND C.COMPUTABLE = 'S';
   V_TOT_GAR NUMBER:=0;
BEGIN
   FOR REG IN HIPO LOOP
      --- acumulo las garantias hipotecarias --
      V_TOT_GAR := V_TOT_GAR + NVL(PAP_CAT.FU_CON_A_GUARANIES(REG.MONEDA, NVL(REG.MONTO,0)),0);
   END LOOP;
   RETURN V_TOT_GAR;
END;
/* Proceso principal de categorización según la resolución 8. */
PROCEDURE PR_PRO_CAT_RESOL8_SB
 (P_TIPO_PROCESO IN VARCHAR2 default 'T'
 )
 IS
-- INICIO DEL PROCESO PRINCIPAL---------------------------------------
v_error varchar2(2000);
BEGIN
   v_fec_proceso := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
   --busco parametros
   BEGIN
      SELECT POR_RIESGO_1a,POR_RIESGO_1b, POR_RIESGO_2, POR_RIESGO_3, POR_RIESGO_4,
             POR_RIESGO_5, SAL_MIN_VIGENTE, CAP_MIN_EXIGIDO, POR_CAP_MIN_EXIGIDO
      INTO   v_riesgo1a, v_riesgo1b, v_riesgo2, v_riesgo3, v_riesgo4,
             v_riesgo5, V_SAL_MINIMO, V_MIN_EXIGIDO, V_POR_MIN_EXIGIDO
      FROM PR_PARAMETROS;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         raise_application_error(-20000, 'Parámetros de riesgos no registrados');
   END;
   -- 1. Busco la moneda local y la de pase del sistema -------------
   SELECT COD_MON_LOCAL, COD_MON_FUERTE
   INTO pap_cat.v_mon_local, pap_cat.v_mon_fuerte
   FROM ge_par_generales;
   -- 2. Busco la cotizacion de la moneda fuerte----------------------
   pap_cat.v_cot_mon_fuerte := PAG_GEN.FU_OBT_COTIZACION(pap_cat.v_mon_fuerte);
   IF p_tipo_proceso = 'T' THEN    ----  solo si el proceso es general ----
      -- 3.1. Elimino los registros del FPOPECL ---------------------
      v_lugar := 'Eliminando registros anteriores';
      v_error := null;
		  sql_util.ejecute_dml('truncate table ge_cla_operaciones', v_error);
		  if v_error is not null then
			   raise_application_error(-20000,'Drop Fk '||v_error);
  		end if;
      --- DELETE FROM GE_CLA_OPERACIONES;
      v_error := null;
      --- Desactivar FK de GE_CLA_OPERACIONES con GE_CLIENTES (xq tdvia no existe)
		  sql_util.ejecute_dml('Alter table ge_cla_operaciones disable constraint FK_GCOPE_COD_PERSONA', v_error);
		  if v_error is not null then
			   raise_application_error(-20000,'Drop Fk '||v_error);
  		end if;
      -- 3.2 Proceso cada uno de los tipos de operaciones por cliente
      v_lugar := 'Preparando datos de Prestamos..';
      PR_PRO_DAT_PRESTA_SB;
      v_lugar := 'Preparando datos de Sobregiros..';
      PR_PRO_DAT_SOBREG_SB;
      v_lugar := 'Preparando datos de Tarjetas..';
      PR_PRO_DAT_TARJE_SB;
      --v_lugar := 'Preparando datos de Com. Exterior..';
      --PR_PRO_DAT_IMPORTA_S;        --todavia no existe el modulo de comercio exterior
		  COMMIT;
   END IF;
   IF p_tipo_proceso IN ('T','C') THEN  --- proc. general o por cliente --
      -- 4. Proceso de clientes ---------------------------------------
      v_lugar := 'Preparando datos de Clientes..';
      PR_PRO_CAT_CLIENT_SB;
      --- Activar FK de GE_CLA_OPERACIONES con GE_CLIENTES (xq ya existe)
		  sql_util.ejecute_dml('Alter table ge_cla_operaciones enable constraint FK_GCOPE_COD_PERSONA', v_error);
		  if v_error is not null then
			   raise_application_error(-20000,'Crea Fk '||v_error);
   		end if;
      COMMIT;
   END IF;
   IF p_tipo_proceso IN ('T','G','C') THEN -- para todos los procesos ----
      -- 5. Proceso de grupos economicos ------------------------------
      v_lugar := 'Preparando datos de Grupos Economicos..';
      PR_PRO_CAT_GRUECO_SB;
      COMMIT;
   END IF;
   COMMIT;
   -- proceso de prevision ---------------------------------------------
   ----PR_CAL_PREVISION_SB; --- Se hace aparte...
   COMMIT;
   -- end if;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Resolución 8 -'||v_lugar||'-'||v_error||'-'||sqlerrm);
END;
/* Proceso de categorización de deudas de comercio exterior. */
PROCEDURE PR_PRO_DAT_IMPORTA_S
 IS
--todavia no se existe el modulo
--- Deudas de comercio exterior ------------------------------------
/*CURSOR COMEXT IS
  SELECT SUCURSAL, NRO_DE_CLIENTE, PRODUCTO, SUB_PRODUCTO,
         a.NRO_DE_CUENTA, MONEDA, SALDO_A_AYER, ESTADO_ACTUAL,
         FECHA_DE_APERTURA, FECHA_DE_VENCIMIENTO, NEGOCIADO
    from cuentas  b, comercio_exterior a
   where producto in ('OSD') /* creditos */--
/*     and sub_producto in  ('70', -- CREDITO IRREVOCABLE DE IMPORTACION
                           '72', -- ACREEDORES P/AVALES Y ACEPTACION
                           '73') -- GARANTIAS OTORGADAS-AVALES
     and saldo_a_ayer > 0
     and a.nro_de_cuenta = b.nro_de_cuenta
     and b.estado_actual <> 'C'; -- cancelada
rv_oper ge_cla_operaciones%rowtype;
WW_TTDEUCO NUMBER(18);
WW_TTDEUDA NUMBER(18);
WW_DIASMOR NUMBER(6) := 0;*/
BEGIN/*
  FOR IM IN COMEXT LOOP
    v_lugar := 'Procesando la operacion Nro. '||IM.NRO_DE_CUENTA;
    ---1. calculo la deuda en la moneda local ----------------------
    IF IM.NEGOCIADO = 'N' THEN
       WW_TTDEUCO := FU_CON_A_GUARANIES(IM.MONEDA, IM.SALDO_A_AYER);
       WW_TTDEUDA := 0;
    ELSE
       WW_TTDEUDA := FU_CON_A_GUARANIES(IM.MONEDA, IM.SALDO_A_AYER);
       WW_TTDEUCO := 0;
    END IF;
    ---2. inserto el registro de la operacion ----------------------
    rv_oper.cod_persona         := im.nro_de_cliente;
    rv_oper.nro_cuenta          := im.nro_de_cuenta;
    rv_oper.cod_modulo          := im.producto;
    rv_oper.cod_modalidad       := im.sub_producto;
    rv_oper.cod_estado          := im.estado_actual;
    rv_oper.tot_deu_real        := ww_ttdeuda;
    rv_oper.tot_deu_contingente := ww_ttdeuco;
    rv_oper.dia_atraso          := 0;
    rv_oper.cod_moneda          := im.moneda;
    rv_oper.cod_oficina         := im.sucursal;
    rv_oper.tipo                := PR.MODALIDAD;
    rv_oper.mto_original        := nvl(ww_ttdeuda,0) + nvl(ww_ttdeuco,0);
    PR_INS_GE_CLA_OPERAC(rv_oper);
  END LOOP;
  */
  null;
END;
/* Proceso de categorización de préstamos. */
PROCEDURE PR_PRO_DAT_PRESTA_SB
 IS
--recupera la deuda de clientes x prestamos
CURSOR PRESTAMOS IS
   SELECT B.COD_PERSONA, A.NRO_CUENTA, A.COD_MODULO, A.COD_MODALIDAD,
--         A.COD_MONEDA, NVL(A.SAL_CAPITAL,0)+NVL(A.SAL_INT_ADELANTADO,0) SALDO,
         ---- No debe hacer sobre interes adelantado
         A.COD_MONEDA, NVL(A.SAL_CAPITAL,0) SALDO,
         NVL(v_fec_proceso-c.fec_vencimiento,0) DIA_ATRASO, A.ESTADO,
         A.DEV_NO_COBRADO, A.COD_OFICINA, NVL(A.TIP_RENOVACION,'A') TIPO, TIP_INTERES,
         A.MTO_CAPITAL, A.NRO_CTA_RENOVADA, (A.FEC_VENCIMIENTO - A.FEC_INICIO) PLAZO,
         A.CAT_RENOVACIONES, A.TIP_RENOVACION, A.COD_SEC_CREDITO, A.TIP_DESTINO
   FROM pr_cuotas c, PR_CTA_PRESTAMOS A, GE_CTA_CLIENTES B
   WHERE A.NRO_CUENTA = B.NRO_CUENTA
   AND NVL(A.SAL_CAPITAL,0)+NVL(A.SAL_INT_ADELANTADO,0) >0 --(x inconsistencia)
   AND A.ESTADO NOT IN ('N','I') --solo las no canceladas y irrecuperables
   AND B.RELACION ='P'--y principales de cuenta
   and a.nro_cuenta = c.nro_cuenta
   and c.nro_cuota = (select min(c1.nro_cuota)
                       from pr_cuotas c1
                      where c1.nro_cuenta = c.nro_cuenta
                        and c1.nro_cuota > 0
                        and c1.estado <> 'N'
                        and ((a.estado = 'C' and c1.estado = 'C')
                          or (a.estado <> 'C')
                            )
                     );
rv_oper ge_cla_operaciones%rowtype;
V_TOT_DEUDA NUMBER(18,2);
V_DEV_NO_COBRADO NUMBER(18,2);
v_tot_dev_no_cob NUMBER(18,2);
v_mto_original   number(18,2);
v_gar_operacion  number(18,2);
v_deu_contingente number(18,2);

function fl_obt_mto_prevision (p_nro_cuenta in pr_cta_prestamos.nro_cuenta%type)
return number is
   v_prevision pr_previsiones.monto%type;
begin
   select pr.monto
     into v_prevision
     from pr_previsiones pr
    where pr.fecha = (select max(pv.fecha) from pr_previsiones pv
                       where pr.nro_cuenta = pv.nro_cuenta)
      and pr.nro_cuenta = p_nro_cuenta;
   return v_prevision;
   exception
      when no_data_found then
          return 0;
end;

BEGIN
   FOR PR IN PRESTAMOS LOOP
      v_lugar := 'Procesando Prestamo Nro. '||PR.NRO_CUENTA;    --
		  --VER SI ES DOCUMENTADO
		  -- Inicializo el dev no cobrado
      V_DEV_NO_COBRADO :=  NVL(PR.DEV_NO_COBRADO,0);
      ---1. calculo la deuda en la moneda local ----------------------
      V_TOT_DEUDA      := PAP_CAT.FU_CON_A_GUARANIES(PR.COD_MONEDA, nvl(PR.SALDO,0)+NVL(V_DEV_NO_COBRADO,0));
      v_tot_dev_no_cob := PAP_CAT.FU_CON_A_GUARANIES(PR.COD_MONEDA, NVL(V_DEV_NO_COBRADO,0));
      --2. garantías x operación
      v_gar_operacion := PAP_CAT.FU_OBT_TOT_GAR_X_OPE(PR.NRO_CUENTA);
		  --obtener garantia hipotecaria(par_dinamico) como deuda contingencia
	    v_deu_contingente := 0; --FU_OBT_GAR_HIPOTE_SB(PR.NRO_CUENTA);
      -- Veo el monto original de la operacion------------------------
      v_mto_original := NVL(PR.MTO_CAPITAL,0);
      IF PR.TIPO <> 'A' THEN
         -- es una operacion renovada, busco el monto original del credito
         BEGIN
            SELECT MTO_CAPITAL
            INTO V_MTO_ORIGINAL
            FROM pr_cta_prestamos
            WHERE NRO_CUENTA = PR.NRO_CTA_RENOVADA;
         EXCEPTION
            WHEN OTHERS THEN
               -- sino encuentra o tiene problemas en la busqueda se asigna el actual
               V_MTO_ORIGINAL := NVL(PR.MTO_CAPITAL,0);
         END;
      END IF;
      -- inserto el registro de la operacion --------------------------
      rv_oper.cod_persona         := PR.COD_PERSONA;
      rv_oper.nro_cuenta          := PR.NRO_CUENTA;
      rv_oper.cod_modulo          := PR.COD_MODULO;
      rv_oper.cod_modalidad       := PR.COD_MODALIDAD;
      rv_oper.cod_estado          := PR.ESTADO;
      rv_oper.tot_deu_real        := V_TOT_DEUDA;
      rv_oper.tot_deu_contingente := v_deu_contingente;
      rv_oper.dev_no_cobrado      := v_tot_dev_no_cob;
      rv_oper.tot_gar_computables := v_gar_operacion;
      rv_oper.dia_atraso          := PR.DIA_ATRASO; --NO HACE FALTA CALCULAR XQ YA ESTA EN LA TABLA
      rv_oper.cod_moneda          := PR.COD_MONEDA;
      rv_oper.cod_oficina         := PR.COD_OFICINA;
      rv_oper.tipo                := PR.TIPO;
      rv_oper.tip_destino         := pr.tip_destino;
      rv_oper.cod_sec_credito     := pr.cod_sec_credito;
      rv_oper.tot_prevision       := PAP_CAT.FU_CON_A_GUARANIES(PR.COD_MONEDA, fl_obt_mto_prevision(pr.nro_cuenta));
      rv_oper.cat_renovaciones    := null;
      if pr.tip_renovacion not in ('A','N') then
         --- Solo para refinanciaciones o reestructuraciones
         --- las mismas afectan la categoria del nuevo prestamo
         rv_oper.cat_renovaciones    := pr.cat_renovaciones;
      end if;
      -- se pasa el monto original del credito a Guaranies ------------
      rv_oper.mto_original        := PAP_CAT.FU_CON_A_GUARANIES(PR.COD_MONEDA,v_mto_original);
      PR_INS_GE_CLA_OPERAC(rv_oper);
    END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Proc. Prestamo '||sqlerrm);
END;
/* Procesar categorización de cuentas corrientes sobregiradas. */
PROCEDURE PR_PRO_DAT_SOBREG_SB
 IS
CURSOR CTASCTES IS
-- las que tienen sobregiro
   select b.cod_persona,A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA,
         a.nro_cuenta, A.COD_MONEDA, (NVL(SAL_TOT_BATCH,0)-NVL(SAL_RET_BATCH,0)) *-1 SAL_ACTUAL,
         A.ESTADO, nvl(can_dias,0) can_dias
   from cc_cta_corrientes a , ge_cta_clientes b,
	     (select can_dias, d.nro_Cuenta
         from CC_SOBREGIROS_RES D) f
   where a.nro_cuenta =  b.nro_cuenta
	 AND NVL(SAL_TOT_BATCH,0) - NVL(SAL_RET_BATCH,0) < 0
 	 and f.nro_cuenta(+) = a.nro_cuenta
   and b.relacion ='P'    --solo los principales de cuenta
   AND a.estado <> 'C';   --no canceladas
rv_oper ge_cla_operaciones%rowtype;
WW_TTDEUDA NUMBER(18);
BEGIN
   FOR CC IN CTASCTES LOOP
      v_lugar := 'Procesando la Cuenta Corriente Nro. '||CC.NRO_CUENTA;
      ---1. calculo la deuda en la moneda local ----------------------
      WW_TTDEUDA := PAP_CAT.FU_CON_A_GUARANIES(CC.COD_MONEDA,CC.SAL_ACTUAL);
      ---3. inserto el registro de la operacion ----------------------
      rv_oper.cod_persona         := cc.cod_persona;
      rv_oper.nro_cuenta          := cc.nro_cuenta;
      rv_oper.cod_modulo          := cc.cod_modulo;
      rv_oper.cod_modalidad       := cc.cod_modalidad;
      rv_oper.cod_estado          := cc.estado;
      rv_oper.tot_deu_real        := ww_ttdeuda;
      rv_oper.tot_deu_contingente := 0;
      rv_oper.dia_atraso          := CC.can_dias;
      rv_oper.cod_moneda          := cc.cod_moneda;
      rv_oper.cod_oficina         := cc.cod_oficina;
      rv_oper.tipo                := 'A';
      rv_oper.mto_original        := ww_ttdeuda;
      PR_INS_GE_CLA_OPERAC(rv_oper);
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Proc. Sobregiro '||sqlerrm);
END;
/* Procesar categorización de tarjetas de crédito. */
PROCEDURE PR_PRO_DAT_TARJE_SB
 IS
--- Deudas de tarjetas ----------------------------------------------
CURSOR TARJETAS IS
   SELECT B.COD_PERSONA, A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA,
         A.NRO_CUENTA, A.COD_MONEDA,
         NVL(A.SAL_FACTURAR,0)+NVL(A.SAL_FACTURADO,0)+NVL(A.SAL_FINANCIADO,0)+NVL(A.SAL_CUO_PENDIENTES,0) SALDO,
         NVL(A.LIN_CREDITO,0)+NVL(A.LIN_CUOTAS,0) LINEA_DE_CREDITO, NVL(A.DIA_MORA,0) DIA_MORA, A.ESTADO
   FROM TA_CTA_TARJETAS A ,GE_CTA_CLIENTES B
   WHERE ESTADO <> 'C'
   AND A.NRO_CUENTA = B.NRO_CUENTA
   AND (NVL(A.SAL_FACTURAR,0)+NVL(A.SAL_FACTURADO,0)+NVL(A.SAL_FINANCIADO,0)+NVL(A.SAL_CUO_PENDIENTES,0) >0
    OR NVL(A.LIN_CREDITO,0)+NVL(A.LIN_CUOTAS,0) > 0)
   AND B.RELACION ='P';--y principales de cuenta;
rv_oper ge_cla_operaciones%rowtype;
WW_TTDEUDA NUMBER(18);
WW_TTDEUCO NUMBER(18);

function fl_obt_mto_prevision (p_nro_cuenta in ta_cta_tarjetas.nro_cuenta%type)
return number is
   v_prevision ta_previsiones.monto%type;
begin
   select pr.monto
     into v_prevision
     from ta_previsiones pr
    where pr.fecha = (select max(pv.fecha) from ta_previsiones pv
                       where pr.nro_cuenta = pv.nro_cuenta)
      and pr.nro_cuenta = p_nro_cuenta;
   return v_prevision;
   exception
      when no_data_found then
          return 0;
end;

BEGIN
   FOR TA IN TARJETAS LOOP
      v_lugar := 'Procesando la Tarjeta Nro. '||TA.NRO_CUENTA;
      ---1. calculo la deuda en la moneda local ----------------------
      WW_TTDEUDA:= PAP_CAT.FU_CON_A_GUARANIES(TA.COD_MONEDA,TA.SALDO);
      IF NVL(TA.SALDO,0) >= NVL(TA.LINEA_DE_CREDITO,0) THEN
         WW_TTDEUCO := 0;
      ELSE
         IF NVL(WW_TTDEUDA,0) < 0 THEN
            -- si tiene un credito (saldo neg.) se considera solo la linea
            WW_TTDEUCO := NVL(TA.LINEA_DE_CREDITO,0);
            WW_TTDEUDA := 0;
         ELSE
            WW_TTDEUCO := NVL(TA.LINEA_DE_CREDITO,0) - NVL(TA.SALDO,0);
         END IF;
      END IF;
      WW_TTDEUCO := PAP_CAT.FU_CON_A_GUARANIES(TA.COD_MONEDA,WW_TTDEUCO);
      ---2. inserto el registro de la operacion ----------------------
      rv_oper.cod_persona         := ta.COD_PERSONA;
      rv_oper.nro_cuenta          := ta.nro_cuenta;
      rv_oper.cod_modulo          := ta.cod_modulo;
      rv_oper.cod_modalidad       := ta.cod_modalidad;
      rv_oper.cod_estado          := ta.estado;
      rv_oper.tot_deu_real        := ww_ttdeuda;
      rv_oper.tot_deu_contingente := ww_ttdeuco;
      rv_oper.dia_atraso          := ta.dia_mora;
      rv_oper.cod_moneda          := ta.cod_moneda;
      rv_oper.cod_oficina         := ta.cod_oficina;
      rv_oper.tipo                := 'A';
      rv_oper.mto_original        := nvl(ww_ttdeuda,0) + nvl(ww_ttdeuco,0);
      rv_oper.tip_destino         := 4; --- Consumo
      rv_oper.tot_prevision       := PAP_CAT.FU_CON_A_GUARANIES(TA.COD_MONEDA, fl_obt_mto_prevision(ta.nro_cuenta));
      PR_INS_GE_CLA_OPERAC(rv_oper);
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Proc. Tarjeta '||sqlerrm);
END;
/* Procesar categorización de clientes. */
PROCEDURE PR_PRO_CAT_CLIENT_SB
 IS
/* Recupera el grupo económico de un cliente. */
FUNCTION LF_OBT_GRU_ECONOMICO
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN NUMBER;
--- leo las operaciones grabadas en la tabla de OPERACIONES -------
CURSOR TOTALES IS
   SELECT COD_PERSONA, SUM(NVL(TOT_DEU_REAL,0)) WW_TTDEUDA,
         SUM(NVL(TOT_DEU_CONTINGENTE,0)) WW_TTDEUCO,
			   SUM(NVL(TOT_GAR_COMPUTABLES,0)) WW_GARAN,
         SUM(NVL(TOT_DEU_REAL,0)+NVL(TOT_DEU_CONTINGENTE,0)) WW_CAPITAL
   FROM GE_CLA_OPERACIONES
   GROUP BY COD_PERSONA
   HAVING SUM(NVL(TOT_DEU_REAL,0) + NVL(TOT_DEU_CONTINGENTE,0)) > 0;
--- Declaro las variables del procedimiento --------------------
v_cliente VARCHAR2(10);
v_gru_eco NUMBER(03);
v_cat_auto NUMBER(5,3);
v_factorp NUMBER(10,4);
v_tot_pond NUMBER(21,4);
v_cat_pond NUMBER(5,3);
v_cat_manu NUMBER(2);
v_existe  VARCHAR2(01);
v_cat_gru NUMBER(3);
v_cla_ant number(3);
v_cat_renova NUMBER(1);
MSJ VARCHAR2(2000);

-- declaro el cursor de detalles de operaciones por cliente -------
CURSOR DETALLES IS
   SELECT NRO_CUENTA, TIP_DESTINO, COD_MODULO, COD_MODALIDAD,
         CAT_AUTOMATICA, CAT_RENOVACIONES, DIA_ATRASO, TOT_DEU_REAL OC_TTDEUDA, TOT_DEU_CONTINGENTE OC_TTDEUCO,
         TIPO,MTO_ORIGINAL, NVL(TOT_DEU_REAL,0)-NVL(DEV_NO_COBRADO,0) SAL_CAPITAL,ROWID FILA
   FROM GE_CLA_OPERACIONES
   WHERE COD_PERSONA = v_cliente;
-------------------------------------------------------------------
/* Recupera el grupo económico de un cliente. */
FUNCTION LF_OBT_GRU_ECONOMICO
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN NUMBER
 IS
V_GRUPO GE_GRU_ECONOMICOS.COD_GRU_ECONOMICO%type:=NULL;
BEGIN
   /* BUSCA DATOS EN EL ARCHIVO DE MONEDA */
   SELECT COD_GRU_ECONOMICO
     INTO V_GRUPO
     FROM GE_CLIENTES
    WHERE COD_PERSONA = P_COD_PERSONA;
   RETURN V_GRUPO;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN V_GRUPO;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Recup. G.Econ. Cliente '||P_COD_PERSONA||'-'||sqlerrm);
END;
BEGIN
   --- cero todos los clientes -------------------------------------
   UPDATE ge_clientes
   SET TOT_DEU_REAL = 0,
      TOT_DEU_CONTINGENTE = 0,
      TOT_GAR_COMPUTABLES = 0,
      TOT_PREVISION = 0,
      CAT_AUTOMATICA = 1
   where nvl(TOT_DEU_REAL,-1) != 0 or
      nvl(TOT_DEU_CONTINGENTE,-1) != 0 or
      nvl(TOT_GAR_COMPUTABLES,-1) != 0 or
      nvl(TOT_PREVISION,-1) != 0 or
      nvl(CAT_AUTOMATICA, -1) != 1;

   --- proceso de actualizacion ------------------------------------
   FOR tot IN totales LOOP
      v_cliente := tot.cod_persona;
      v_gru_eco :=null;--x cliente
	    v_cat_gru :=null;
      v_lugar := 'Procesando el Cliente Nro. '|| v_cliente;
	    --recuperar grupo economico del cliente
	    v_gru_eco:=LF_OBT_GRU_ECONOMICO(v_cliente);
      if v_gru_eco is not null then
         --insertar en ge_gru_economico
         begin
            select trunc(cat_automatica)
			      into v_cat_gru
      			from ge_gru_economicos
			      where cod_gru_economico = v_gru_eco;
    		 exception
		      	when no_data_found then
  			       insert into ge_gru_economicos(cod_gru_economico,cat_subjetiva,cat_automatica)
      				 values(v_gru_eco,NULL,1);
			      when others then
        				msj:='Ins.Grupo Economico '||sqlerrm;
				        exit;
    		 end;
  	  end if;
      v_tipo_clie := NULL;
      v_cat_manu := NULL;
      v_existe := 'N';
      BEGIN
         SELECT TIPO, nvl(cat_subjetiva,cat_automatica), CAT_SUBJETIVA
         INTO v_tipo_clie, v_cla_ant, v_cat_manu
         FROM ge_clientes
         WHERE cod_persona = v_cliente;
		     v_existe := 'S';
    		 if v_cat_gru is not null then
		        v_cla_ant := v_cat_gru; --predomina la del grupo
    		 end if;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_existe := 'N';
            v_tipo_clie := 'X';
         WHEN TOO_MANY_ROWS THEN
			      msj:='Mas de un registro en GE_CLIENTES '||v_cliente;
      			exit; --(loop)
     		 WHEN OTHERS THEN
       			msj:='Recup. Cliente '||v_cliente||'-'||sqlerrm;
      			exit; --(loop)
      END;
      --Tipo de cliente R = Grandes deudores relacionados a la Entidad,
      --                G = Mayores deudores vinculados a otros grupos económicos
      --                M = Grandes Deudores Comerciales,
      --                N = Pequeños deudores relacionados a la Entidad,
      --                C = Pequeños deudores comerciales,
      --                P = Deudores Personales, (consumo y vivienda)
      --                T = Micro creditos--NO SE USA EN LA ACTUAL
      IF NVL(tot.WW_CAPITAL,0) > (v_min_exigido * v_por_min_exigido /100)
      or (v_gru_eco is not null and FU_VER_GRU_MAS_CLIE(v_gru_eco))
      or PAP_CAT.FU_VER_CLI_REL_ENTI(v_cliente) THEN
         --EN LA ACTUAL ES 3%
         IF PAP_CAT.FU_VER_CLI_REL_ENTI(v_cliente) then
            v_tipo_clie := 'R';  -- grandes deudores comerciales relacionados
         ELSE
           if v_gru_eco is not null and FU_VER_GRU_MAS_CLIE(v_gru_eco) then
              --si tiene grupo y hay otros clientes en el mismo then
               v_tipo_clie := 'G';  -- Mayores deudores vinculados a otros grupos económicos
           else
               v_tipo_clie := 'M';  -- grandes deudores comerciales no vinculados
           END IF;
         END IF;
      ELSIF NVL(tot.WW_CAPITAL,0) > (v_sal_minimo * 100) THEN
         IF PAS_RES.FU_CLI_SOLO_CONSUMO(v_cliente) = 'N' THEN
            v_tipo_clie := 'C';  -- pequeños deudores comerciales
         ELSE
            v_tipo_clie := 'P';  -- personal
         END IF;
      ELSE
         IF PAS_RES.FU_CLI_SOLO_CONSUMO(v_cliente) = 'N' THEN
            v_tipo_clie := 'C';  -- pequeños deudores comerciales
         ELSE
            v_tipo_clie := 'P';  -- personal
         END IF;
      END IF;

/*      ELSIF NVL(tot.WW_CAPITAL,0) > (v_sal_minimo * 5) and
         PAS_RES.FU_CLI_SOLO_CONSUMO(v_cliente) =  'S'  then
         IF NVL(tot.WW_CAPITAL,0) <= (v_sal_minimo * 100) tHEN
         ELSE
            v_tipo_clie := 'C';   -- pequeños deudores comerciales
         END IF;
      ELSE
         v_tipo_clie := 'C'; -- pequeños deudores comerciales
      END IF;*/

      v_tot_pond := 0;
      FOR det IN detalles LOOP
         --- por cada operacion de credito o tarjeta, calculo el ponderado ---
         -- se calcula la categoria de acuerdo a la mora-------------
         v_tip_destino := det.tip_destino;
         if det.cat_renovaciones is not null then
            -- es un credito refinanciado, directamente debe tener 3, porque aun
            -- no pagó ni el 10% de su credito original
            v_cat_auto   := det.cat_renovaciones;
            v_cat_renova := det.cat_renovaciones;
         ELSE
            IF det.dia_atraso > 0 THEN--IS NOT NULL THEN --XQ EL CAMPO ES NOT NULL EN LA TABLA
                v_cat_auto:=FU_OBT_CAT_X_MORA_SB(det.dia_atraso, det.cod_modalidad);
            ELSE
               v_cat_auto:=NVL(det.cat_automatica,1);
            END IF;
         END IF;

         --- No debe considerar estas modalidades porque mejora la categoria
         if  det.cod_modalidad not in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
             FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6)) then
            v_tot_pond := v_tot_pond + ((NVL(det.OC_TTDEUDA,0)+NVL(det.OC_TTDEUCO,0))*v_cat_auto);
         end if;
         --v_factorp:=(NVL(det.OC_TTDEUDA,0)+NVL(det.OC_TTDEUCO,0))/
         --(NVL(tot.WW_TTDEUDA,0)+NVL(tot.WW_TTDEUCO,0));
         --v_cat_pond:= trunc(v_factorp * v_cat_auto,2);
         --v_tot_pond:= NVL(v_tot_pond,0) + v_cat_pond;
         --- actualizo la ponderacion por mora ---------------------
         UPDATE GE_CLA_OPERACIONES
         SET CAT_AUTOMATICA = v_cat_auto
         WHERE ROWID = det.FILA;
         -----------------------------------------------------------
      END LOOP;
      --- Calculo categoria ponderada
      v_cat_pond := trunc(v_tot_pond/(NVL(tot.WW_TTDEUDA,0)+NVL(tot.WW_TTDEUCO,0)),2);
      -- busco la garantia por cliente -------------------------------
      --v_garan := FU_OBT_TOT_GAR_CLIE(v_cliente,NVL(tot.WW_TTDEUDA,0));
   	  begin
		     --si no existe en ge_cliente -> inserto el cliente
      	 if nvl(v_existe,' ') ='N' then
      			insert into ge_clientes
			    	(cod_persona, tipo, tot_deu_real, tot_deu_contingente,
      			 tot_gar_computables, cod_gru_economico, cat_automatica, cat_anterior,fec_ult_clasif)
			      values
     				(v_cliente,v_tipo_clie,NVL(tot.WW_TTDEUDA,0),NVL(tot.WW_TTDEUCO,0),
		     		 NVL(TOT.WW_GARAN,0), v_gru_eco,	v_cat_pond, 1, v_fec_proceso);
    		 else
      			--- El campo catmanu se limpia si es menor al Ponderado--
            /* Con respecto a esto de acuerdo a lo que estuve viendo en Regional, la
               categoria subjetiva debe ser borrada cuando su clasificación automática
               supera a la subjetiva. Esto es para que ya le agregues esto al proceso
               -- Ya estaba en el proceso */
            --- Atlas no quiere que se modifique
            if fug_obt_tip_implementacion <> 3 then
               IF v_cat_manu IS NOT NULL THEN
				          IF v_cat_manu <= trunc(v_cat_pond) THEN
					           v_cat_manu := NULL;
				          END IF;
			         END IF;
            end if;

			      --- Actualizo los datos del cliente ---------------------
			      UPDATE ge_clientes
			      SET TOT_DEU_REAL = NVL(tot.WW_TTDEUDA,0),
				        TOT_DEU_CONTINGENTE = NVL(tot.WW_TTDEUCO,0),
	              cat_anterior = cat_automatica,
	              fec_cat_anterior = fec_ult_clasif,
                fec_ult_clasif = v_fec_proceso,
    				    TOT_GAR_COMPUTABLES = NVL(TOT.WW_GARAN,0),
			    	    TIPO = v_tipo_clie,
    				    CAT_SUBJETIVA = v_cat_manu,
		    		    CAT_AUTOMATICA = v_cat_pond,
                CAT_RENOVACIONES = v_cat_renova,
                CAT_RIESGO = fup_obt_categoria(v_cat_pond, v_cat_manu)
      			WHERE cod_persona = v_cliente;
		     end if;
      exception
		     when others then
			      msj:='Ins/Act Clien. '||sqlerrm;
      			exit;
	    end;
   END LOOP;
   IF MSJ IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20001,'-'||MSJ);
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Proc. Clien. '||sqlerrm);
END;
/* Procesar categorización de grupos económicos. */
PROCEDURE PR_PRO_CAT_GRUECO_SB
 IS
CURSOR TOTALES IS
   SELECT COD_GRU_ECONOMICO, SUM(NVL(TOT_DEU_REAL,0)) WW_TTDEUDA,
         SUM(NVL(TOT_DEU_CONTINGENTE,0)) WW_TTDEUCO,
         SUM(NVL(TOT_GAR_COMPUTABLES,0)) WW_TTGARCO
   FROM GE_CLIENTES
   WHERE COD_GRU_ECONOMICO IS NOT NULL
   GROUP BY COD_GRU_ECONOMICO
   HAVING SUM(NVL(TOT_DEU_REAL,0)+NVL(TOT_DEU_CONTINGENTE,0)) > 0;
--- declaro las variables a ser utilizadas en el proc. ------
v_gru_eco    NUMBER(03);
v_factorp    NUMBER(10,4);
v_tot_pond   NUMBER(5,3);
v_cat_pond   NUMBER(5,3);
--- declaro los detalles de los clientes --------------------
CURSOR DETALLES IS
   SELECT NVL(TOT_DEU_REAL,0) TOT_DEU_REAL,
          NVL(TOT_DEU_CONTINGENTE,0) TOT_DEU_CONTINGENTE,
          NVL(TOT_GAR_COMPUTABLES,0) TOT_GAR_COMPUTABLES,
          NVL(CAT_SUBJETIVA,CAT_AUTOMATICA) CAT_AUTOMATICA,
          TIPO, ROWID FILA
     FROM GE_CLIENTES
    WHERE COD_GRU_ECONOMICO = v_gru_eco
    AND (NVL(TOT_DEU_REAL,0) + NVL(TOT_DEU_CONTINGENTE,0)) > 0;
    --q solo traiga los q tienen deuda - VC 18/11/05
BEGIN
   UPDATE GE_GRU_ECONOMICOS
      SET CAT_AUTOMATICA = 1,
          tot_deu_real = 0,
          tot_deu_contingente = 0,
          tot_prevision = 0,
          tot_gar_computables = 0;
   FOR tot IN totales LOOP
      v_lugar := 'Procesando el Grupo Economico Nro. '||TO_CHAR(tot.COD_GRU_ECONOMICO,'999');
      v_gru_eco := tot.COD_GRU_ECONOMICO;
      v_tot_pond := 0;
      --Tipo de cliente R = Grandes deudores relacionados a la Entidad,
      --                M = Grandes Deudores Comerciales,
      --                N = Pequeños deudores relacionados a la Entidad,
      --                C = Pequeños deudores comerciales,
      --                P = Deudores Personales,
      --                T = Micro creditos
      -- veo los clientes
      FOR det IN detalles LOOP
         --- por cada operacion de credito, calculo el ponderado ---
         v_factorp:=(NVL(det.tot_DEU_REAL,0)+NVL(det.TOT_DEU_CONTINGENTE,0))/
          (NVL(tot.WW_TTDEUDA,0)+NVL(tot.WW_TTDEUCO,0));
         v_cat_pond:= v_factorp * det.cat_automatica;
         v_tot_pond:= NVL(v_tot_pond,0) + v_cat_pond;
         --- verifico si el tipo de cliente esta ok o no ---------------
         v_tipo_clie := det.TIPO;
			   IF NVL(TOT.WW_TTDEUDA,0)+NVL(TOT.WW_TTDEUCO,0) > (v_min_exigido * v_por_min_exigido /100) THEN
            IF det.TIPO IN ('N','R') THEN --pequeños y grandes relacionados
               v_tipo_clie := 'R';
            ELSE
               v_tipo_clie := 'M';--grande no relacionado
            END IF;
         ELSE
            IF det.TIPO in ('R','N') THEN
               v_tipo_clie := 'N'; --pequeño relacionado
            ELSE
               v_tipo_clie := 'C'; --pequeño no relacionado
            END IF;
         END IF;
			   -- si cambio el tipo se actualizan los tipos
         IF v_tipo_clie <> det.TIPO THEN
            UPDATE GE_CLIENTES
               SET TIPO  = v_tipo_clie
             WHERE ROWID = det.FILA;
         END IF;
      END LOOP;
      --------- VC 18/11/05
      /*aca agregar cun control para que si el valor resultante de la pondera en menor a 1
      (para evitar que se asigne 0 como categoria)
      la ponderacion puede salir por ejemplo 0,0045 y le va a asignar CERO, cuando como minimo es 1*/
      IF v_tot_pond < 1 THEN
         v_tot_pond := 1;
      END IF;
      UPDATE GE_GRU_ECONOMICOS
      SET CAT_AUTOMATICA      = NVL(v_tot_pond,1),
          TOT_DEU_REAL        = NVL(TOT_DEU_REAL,0) + nvl(tot.ww_ttdeuda,0),
          TOT_DEU_CONTINGENTE = NVL(TOT_DEU_CONTINGENTE,0) + nvl(tot.ww_ttdeuco,0),
          TOT_GAR_COMPUTABLES = NVL(TOT_GAR_COMPUTABLES,0) + nvl(tot.ww_ttgarco,0)
      WHERE COD_GRU_ECONOMICO = v_gru_eco;
      -- actualizo la categoria final del cliente (nueva resol.)
      UPDATE GE_CLIENTES A
      SET A.CAT_RIESGO = trunc(NVL(v_tot_pond,1),0),
      A.CAT_GRU_ECONOMICO = trunc(NVL(v_tot_pond,1),0)
      WHERE COD_GRU_ECONOMICO = v_gru_eco;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,'Proc. Grupos Económicos '||sqlerrm);
END;
/* Proceso de cálculo de previsiones. */
PROCEDURE PR_CAL_PREVISION_SB
 IS
CURSOR clientes IS
 SELECT COD_PERSONA, COD_GRU_ECONOMICO, NVL(CAT_SUBJETIVA,CAT_AUTOMATICA) CAT_AUTOMATICA
   FROM GE_CLIENTES
  WHERE NVL(TOT_DEU_REAL,0) + NVL(TOT_DEU_CONTINGENTE,0) > 0
  ORDER BY COD_PERSONA;
v_cliente  VARCHAR2(10);
v_cat_prev NUMBER(03);
v_previsi  NUMBER(18);
V_ESTADO ge_cla_operaciones.cod_estado%type;
CURSOR det_ope IS
  SELECT COD_PERSONA OC_CDCLIEN, NRO_CUENTA OC_NRCUENT,
         NVL(TOT_DEU_REAL,0) + NVL(TOT_DEU_CONTINGENTE,0) - NVL(TOT_GAR_COMPUTABLES,0)
         OC_TTDEUDA, NVL(DIA_ATRASO,0) DIA_ATRASO--, ESTADO OC_ESCTAOL, --CAT_AUTOMATICA OC_CATAUTO
    FROM GE_CLA_OPERACIONES
   WHERE COD_PERSONA = v_cliente
   FOR UPDATE OF TOT_PREVISION;
BEGIN
   --
   v_lugar := ' Cursor de Clientes ';
   FOR cl IN clientes LOOP
     v_lugar := 'Procesando Prevision del Cliente Nro. '||(cl.cod_persona);
     v_cat_prev := cl.cat_automatica;
     v_cliente  := cl.cod_persona;
     IF cl.cod_gru_economico IS NOT NULL AND cl.cod_gru_economico <> 0 THEN
        v_lugar := 'Al buscar Grupo Economico ';
        SELECT nvl(cat_subjetiva,cat_automatica)
          INTO v_cat_prev
          FROM ge_gru_economicos
         WHERE cod_gru_economico = cl.cod_gru_economico;
     END IF;
     IF v_cat_prev IS NULL THEN
        v_cat_prev := cl.cat_automatica;
     END IF;
     v_lugar := 'Al leer cursor de Operaciones x cliente '||v_cliente;
     FOR op IN det_ope LOOP   --x cada operación del cliente
       v_previsi := 0;
       IF    v_cat_prev = '1a' THEN
             v_previsi := op.OC_TTDEUDA * v_riesgo1a / 100;
       ELSIF v_cat_prev = '1b' THEN
             v_previsi := op.OC_TTDEUDA * v_riesgo1b / 100;      
       ELSIF v_cat_prev = '2' THEN
             v_previsi := op.OC_TTDEUDA * v_riesgo2 / 100;
       ELSIF v_cat_prev = '3' THEN
             v_previsi := op.OC_TTDEUDA * v_riesgo3 / 100;
       ELSIF v_cat_prev = '4' THEN
             v_previsi := op.OC_TTDEUDA * v_riesgo4 / 100;
       ELSIF v_cat_prev = '5' THEN
             v_previsi := op.OC_TTDEUDA * v_riesgo5 / 100;
       END IF;
       IF v_previsi < 0 THEN
          v_previsi := 0;
       END IF;
       --aparentemente no se usa, verificar
       /*IF NVL(OP.DIA_ATRASO,0) >= 0  AND NVL(OP.DIA_ATRASO,0) <= 60 THEN
          V_ESTADO := 'C';
       ELSIF NVL(OP.DIA_ATRASO,0) > 60 AND NVL(OP.DIA_ATRASO,0) <= 90 THEN
          V_ESTADO := 'V';
       ELSIF NVL(OP.DIA_ATRASO,0) > 90 AND NVL(OP.DIA_ATRASO,0) <= 180 THEN
          V_ESTADO := 'G';
       ELSE
          V_ESTADO := 'M';
       END IF;*/
       UPDATE GE_CLA_OPERACIONES
        SET TOT_PREVISION = v_previsi --, COD_ESTADO = V_ESTADO
        WHERE CURRENT OF DET_OPE;
       UPDATE ge_clientes
         SET TOT_PREVISION = NVL(TOT_PREVISION,0) + v_previsi
         WHERE COD_PERSONA= V_CLIENTE;
     END LOOP;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Cal. Previsión '||SQLERRM);
END;
/* Insertar datos en la tabla ge_cla_operaciones. */
PROCEDURE PR_INS_GE_CLA_OPERAC
 (RP_OPER IN GE_CLA_OPERACIONES%ROWTYPE
 )
 IS
BEGIN
    INSERT INTO GE_CLA_OPERACIONES
       (COD_PERSONA,        NRO_CUENTA,     COD_MODULO,
        COD_MODALIDAD,      COD_ESTADO,     TOT_DEU_REAL,
        TOT_DEU_CONTINGENTE,DEV_NO_COBRADO, CAT_AUTOMATICA,
        DIA_ATRASO,         COD_MONEDA,     TOT_GAR_COMPUTABLES,
        COD_OFICINA,        TIPO,           TOT_PREVISION,
        MTO_ORIGINAL,       TIP_DESTINO,    COD_SEC_CREDITO,
        CAT_RENOVACIONES)
    VALUES
       (RP_OPER.COD_PERSONA,        RP_OPER.NRO_CUENTA,     RP_OPER.COD_MODULO,
        RP_OPER.COD_MODALIDAD,      RP_OPER.COD_ESTADO,     RP_OPER.TOT_DEU_REAL,
        RP_OPER.TOT_DEU_CONTINGENTE,RP_OPER.DEV_NO_COBRADO, RP_OPER.CAT_AUTOMATICA,
        RP_OPER.DIA_ATRASO,         RP_OPER.COD_MONEDA,     RP_OPER.TOT_GAR_COMPUTABLES,
        RP_OPER.COD_OFICINA,        RP_OPER.TIPO,           RP_OPER.TOT_PREVISION,
        RP_OPER.MTO_ORIGINAL,       RP_OPER.TIP_DESTINO,    RP_OPER.COD_SEC_CREDITO,
        RP_OPER.CAT_RENOVACIONES);
EXCEPTION
    WHEN OTHERS THEN
        raise_application_error(-20000,SQLERRM||' al Ins. GE_CLA_OPERACIONES Clie -'||RP_OPER.COD_PERSONA||' Cta. '||RP_OPER.NRO_CUENTA);
END;
/* Obtener la categoría que le corresponde x mora. */
FUNCTION FU_OBT_CAT_X_MORA_SB
 (P_CAN_DIAS IN NUMBER,
  P_COD_MODALIDAD IN PR_CTA_PRESTAMOS.COD_MODALIDAD%TYPE
 )
 RETURN NUMBER
 IS
v_cat_mora NUMBER(1) := 1;
BEGIN
   IF v_tip_destino <> 4 THEN --- NO ES CONSUMO
      IF p_cod_modalidad in (FUG_OBT_PARDINAMICO('CHEQUES DEVUELTOS',6),
         FUG_OBT_PARDINAMICO('CHEQUES DIFERIDOS',6)) then
         v_cat_mora := 2;
         IF p_can_dias < 31 THEN
            v_cat_mora := 1;
         elsif p_can_dias > 30 and p_can_dias <= 59 then
            v_cat_mora := 2;
         elsif p_can_dias > 59 and p_can_dias <= 89 then
            v_cat_mora := 3;
         elsif p_can_dias > 89 and p_can_dias <= 119 then
            v_cat_mora := 4;
         elsif p_can_dias > 119 then
            v_cat_mora := 5;
         END IF;
      ELSE
         --- tipo de cliente comercial ----
         IF    p_can_dias <= 60 THEN
            v_cat_mora := 1;   --- riesgo normal    ---
         ELSIF p_can_dias <= 120 THEN
            v_cat_mora := 2;   --- riesgo potencial ---
         ELSIF p_can_dias <= 180 THEN
            v_cat_mora := 3;   --- riesgo real      ---
         ELSIF p_can_dias <= 360 THEN
            v_cat_mora := 4;   --- alto riesgo      ---
         ELSE
            v_cat_mora := 5;   --- irrecuperable      ---
         END IF;
      END IF;
   ELSE --- CONSUMO
      --- tipo de cliente personal, microcredito o cliente menor ----
      IF    p_can_dias <= 60 THEN
         v_cat_mora := 1;   --- riesgo normal    ---
      ELSIF p_can_dias <= 90 THEN
         v_cat_mora := 2;   --- riesgo potencial ---
      ELSIF p_can_dias <= 120 THEN
         v_cat_mora := 3;   --- riesgo real      ---
      ELSIF p_can_dias <= 180 THEN
         v_cat_mora := 4;   --- alto riesgo      ---
      ELSE
         v_cat_mora := 5;   --- irrecuperable      ---
      END IF;
   END IF;
   RETURN v_cat_mora;
END;
/* Verifica si el grupo económico tiene más de un cliente. */
FUNCTION FU_VER_GRU_MAS_CLIE
 (P_COD_GRU_ECONOMICO IN GE_GRU_ECONOMICOS.COD_GRU_ECONOMICO%TYPE
 )
 RETURN BOOLEAN
 IS
V_CANT NUMBER(20):=0;
BEGIN
   SELECT COUNT(*)
     INTO V_CANT
   FROM GE_CLIENTES C
   WHERE C.COD_GRU_ECONOMICO = P_COD_GRU_ECONOMICO
   --- Persona que poseea deuda todavia
   AND EXISTS (SELECT 1 FROM GE_CTA_CLIENTES CC, GE_CUENTAS CU
               WHERE CU.NRO_CUENTA = CC.NRO_CUENTA
               AND CU.ESTADO <> 'N'
               AND CU.COD_MODULO = 6
               AND C.COD_PERSONA = CC.COD_PERSONA);
   IF V_CANT > 1 THEN
    RETURN TRUE;
   ELSE
    RETURN FALSE;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
     RETURN FALSE;
END;
END PAS_RES;
/

