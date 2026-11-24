CREATE OR REPLACE PACKAGE BODY IT.PAB_SIM IS

   -- Variables globales.
   -- Devengado Ahorro Vista.
   g_cod_modulo             ah_cta_vistas.cod_modulo%type := 3;
   g_cod_tasa               ge_tasas.cod_tasa%type;
   g_cod_modalidad          ah_cta_vistas.cod_modalidad%type;
   g_cod_oficina            ah_cta_vistas.cod_oficina%type;
   g_sal_min_general        ah_cta_vistas.sal_minimo%type;
   g_sal_min_pactado        ah_cta_vistas.sal_minimo%type;
   g_cod_moneda             ba_monedas.cod_moneda%type;
   g_sal_promedio           ah_cta_vistas.sal_total%type;
   g_ult_dia_mes            cb_sim_dev_ahorros.fecha%type;
   g_ult_mes_habil          cb_sim_dev_ahorros.fecha%type;
   g_sal_acumulado          ah_cta_vistas.sal_total%type;
   g_dia_acumulado          cb_sim_dev_ahorros.can_dia_interes%type;
   g_tas_personalizada      ah_cta_vistas.tas_personalizada%type;
   g_sal_disponible         cb_sim_dev_ahorros.sal_acumulado%type;
   g_fec_apertura           ah_cta_plazos.fec_apertura%type;
   g_fec_ult_capitalizacion ah_cta_plazos.fec_ult_capitalizacion%type;
   g_fec_vencimiento        ah_cta_plazos.fec_vencimiento%type;
   g_fec_inicio             cb_sim_dev_ahorros.fec_inicio%type;
   g_mto_capital            ah_cta_certificados.capital%type;
   g_mon_local              ba_monedas.cod_moneda%type;
   g_val_tasa               cb_sim_dev_ahorros.val_tasa%type;
   g_fec_vig_tasa           ge_tas_fechas.fec_vigencia%type;
   g_mto_devengado          cb_sim_dev_ahorros.mto_dev_acumulado%type;
   g_tip_valor              varchar2(1);
   g_tip_tasa               varchar2(1);
   g_fec_final              date;
   g_fec_hoy                date;
   g_fec_anterior           date;
   g_secuencia              number(3);
   g_nro_cuenta             varchar2(15);
   g_lugar                  varchar2(250);
   v_cod_paq_exnomina ge_paquetes.cod_paquete%type := fug_obt_pardinamico('COD_PAQ_EXNOMINA');

   
/* Obtiene la hora disponible de la tabla cb_sim_movimientos. */
FUNCTION FU_OBT_HOR_DISPONIBLE (P_FECHA       IN DATE,
                                P_HORA        IN VARCHAR2,
                                P_COD_USUARIO IN VARCHAR2)
RETURN VARCHAR2 IS
  
  /* funcion para obtener la hora que no esté utilizado en movimientos */
  v_existe             varchar2(1);
  v_hora               varchar2(8) := p_hora;
  v_hor_agotada        varchar2(1) := 'N';
  v_can_bus_hora       number := 0;
  
BEGIN
  v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
  LOOP
     v_can_bus_hora := nvl(v_can_bus_hora,0) + 1;
     BEGIN
       select 'S'
         into v_existe
         from cb_sim_movimientos
        where fecha = p_fecha
          and hora = v_hora
          and cod_usuario = p_cod_usuario
          and rownum <= 1;
     EXCEPTION
       WHEN no_data_found THEN
         v_existe := 'N';
     END;
     EXIT WHEN ((v_existe = 'N') OR (v_hor_agotada = 'S'));
     v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
     IF v_can_bus_hora >= 85000 THEN
        v_hor_agotada := 'S';
     END IF;
  END LOOP;
  return v_hora;
end;

/* Obtiene la hora de los movimientos. */
FUNCTION FU_INI_HORA(P_FECHA IN DATE DEFAULT SYSDATE, P_FORMATO IN VARCHAR2 DEFAULT 'HH24:MI:SS')
RETURN VARCHAR2  
IS
 /* funcion que devuelve la hora de inicio para cada proceso de cierre para evitar duplicacion de claves */
v_hora     VARCHAR2(8) := to_char(nvl(p_fecha,SYSDATE),nvl(p_formato,'HH24:MI:SS'));
BEGIN
  v_hora := fu_obt_hor_disponible(trunc(p_fecha),v_hora,user);
  RETURN v_hora;
EXCEPTION
  WHEN OTHERS THEN
      RETURN v_hora;
END;

/* Inserta datos en la Tabla cb_sim_movimientos */
PROCEDURE PR_INS_GE_MOVIMIENTO (RP_GMOVI IN CB_SIM_MOVIMIENTOS%ROWTYPE)
IS
   -- Variables.
   v_error varchar2(30);
   
BEGIN
   v_error := 'cb_sim_movimientos';
   insert into CB_SIM_MOVIMIENTOS(cod_usuario, hora, nro_secuencia, cod_modulo, cod_modalidad, cod_oficina,
        nro_cuenta, cod_moneda, cod_tra_padre, cod_transaccion, fecha, fec_valor, nro_documento,
        monto, cod_autorizacion, cod_usu_autorizador, cod_error, cod_retencion, fec_fin_retencion, est_cuenta,
        nro_documento2, nro_documento3, estado, cod_causa, cod_banco,  cod_ofi_origen,
        cod_bco_central, concepto, cod_tip_ope_cambio, cod_tasa, val_tasa, reversado, cod_usu_reversion,
        hor_reversion, emi_aviso, protegido, cod_mod_padre, cod_mad_padre, tip_mov_rubro, cod_rubro,
        mto_equ_local, cotizacion, nro_documento4, nro_caja, cod_ref_cambio,
        referencia, cod_persona, cod_sit_contable)
        values (rp_gmovi.cod_usuario, rp_gmovi.hora, rp_gmovi.nro_secuencia, rp_gmovi.cod_modulo, rp_gmovi.cod_modalidad, rp_gmovi.cod_oficina,
        rp_gmovi.nro_cuenta, rp_gmovi.cod_moneda, rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.fecha, rp_gmovi.fec_valor, rp_gmovi.nro_documento,
        rp_gmovi.monto, rp_gmovi.cod_autorizacion, rp_gmovi.cod_usu_autorizador, rp_gmovi.cod_error, rp_gmovi.cod_retencion, rp_gmovi.fec_fin_retencion, rp_gmovi.est_cuenta,
        rp_gmovi.nro_documento2, rp_gmovi.nro_documento3, rp_gmovi.estado, rp_gmovi.cod_causa, rp_gmovi.cod_banco,  rp_gmovi.cod_ofi_origen,
        rp_gmovi.cod_bco_central, rp_gmovi.concepto, rp_gmovi.cod_tip_ope_cambio, rp_gmovi.cod_tasa, rp_gmovi.val_tasa, rp_gmovi.reversado, rp_gmovi.cod_usu_reversion,
        rp_gmovi.hor_reversion, rp_gmovi.emi_aviso, rp_gmovi.protegido, rp_gmovi.cod_mod_padre, rp_gmovi.cod_mad_padre, rp_gmovi.tip_mov_rubro, rp_gmovi.cod_rubro,
        rp_gmovi.mto_equ_local, rp_gmovi.cotizacion, rp_gmovi.nro_documento4, rp_gmovi.nro_caja, rp_gmovi.cod_ref_cambio,
        rp_gmovi.referencia, rp_gmovi.cod_persona, rp_gmovi.cod_sit_contable);
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'insertar en '||v_error
                              ||' usuario '||substr(lower(user),1,6)
                              ||' hora '||rp_gmovi.hora||' secuencia '||to_char(rp_gmovi.nro_secuencia)||' cuenta '||rp_gmovi.nro_cuenta
                              ||' moneda '||rp_gmovi.cod_moneda||' trhijo '||to_char(rp_gmovi.cod_transaccion)
                              ||' fecha  '||to_char(rp_gmovi.fecha)||' importe '||to_char(rp_gmovi.monto)
                              ||' cotizacion '||to_char(rp_gmovi.cotizacion)||' '||sqlerrm);
END;

/*Genera el devengado de las operaciones futuras.*/
PROCEDURE PR_DEV_OPE_FUTURAS(p_fecha in ge_calendarios.fec_actual%type) is
  -- Variables.
  r_bsdfut              lc_ope_futuras%rowtype;
  v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local ;  
  v_fec_actual          ge_calendarios.fec_actual%type;
  v_descuento           varchar2(1);
  v_ano_mes_actual      varchar2(6);
  v_ano_mes_liquidacion varchar2(6);
  v_ano_mes_operacion   varchar2(6);
  v_ano_mes_vencimiento varchar2(6);
  v_fila                varchar2(18);
  v_mto_emi_gs          number(18,2);
  v_mto_ven_gs          number(18,2);
  v_dia_inicio          number(18);
  v_mto_diferencia      number(18);
  v_int_devengado       number(18,2) := 0;
  v_dia_fin             number(18);
  v_mto_dia             number(18,2);
  v_cantidad            number(18);  
  v_fec_pri_mes         date;
  v_fec_ult_mes         date;
  -- Cursores.
  CURSOR c_ope_futuras IS
     SELECT f.cotizacion, f.cot_vencimiento, f.monto, f.plazo,
            f.fec_liquidacion, f.fec_operacion, f.fec_vencimiento, f.cod_moneda,
            f.rowid, f.cod_mad_padre, f.cod_ofi_origen
       FROM lc_ope_futuras f
      WHERE f.cod_mad_padre = 76
        AND f.estado in ('N','L')
        AND (f.fec_liquidacion IS NULL OR
            (f.fec_liquidacion BETWEEN v_fec_pri_mes AND v_fec_ult_mes));
   --
begin
  -- Obtiene los datos del calendario.
  BEGIN 
     pag_cal.pr_obt_dat_calendar(2);
  END;
  --
  v_fec_pri_mes    := pag_cal.g_pri_dia_mes;
  v_fec_ult_mes    := pag_cal.g_ult_dia_mes;
  v_fec_actual     := p_fecha;
  v_ano_mes_actual := TO_CHAR(v_fec_actual,'YYYYMM');
  v_cantidad       := 0;
  --
  OPEN c_ope_futuras;
  LOOP
     FETCH c_ope_futuras INTO r_bsdfut.cotizacion, r_bsdfut.cot_vencimiento, r_bsdfut.monto, r_bsdfut.plazo,
                              r_bsdfut.fec_liquidacion, r_bsdfut.fec_operacion, r_bsdfut.fec_vencimiento, r_bsdfut.cod_moneda,
                              v_fila, r_bsdfut.cod_mad_transaccion, r_bsdfut.cod_ofi_origen;
    EXIT WHEN c_ope_futuras%NOTFOUND;
    v_cantidad := v_cantidad + 1;
    --
    v_mto_emi_gs := r_bsdfut.cotizacion * r_bsdfut.monto;
    v_mto_ven_gs := r_bsdfut.cot_vencimiento * r_bsdfut.monto;
    v_mto_diferencia := abs(v_mto_ven_gs-v_mto_emi_gs);
    v_mto_dia := v_mto_diferencia/r_bsdfut.plazo;    
    v_ano_mes_liquidacion := TO_CHAR(r_bsdfut.fec_liquidacion, 'YYYYMM');
    v_ano_mes_operacion := TO_CHAR(r_bsdfut.fec_operacion, 'YYYYMM');
    v_ano_mes_vencimiento := TO_CHAR(r_bsdfut.fec_vencimiento, 'YYYYMM');
    -- Verifico si es un premio o un descuento.
    IF NVL(r_bsdfut.cot_vencimiento,0) >= NVL(r_bsdfut.cotizacion,0) THEN
       v_descuento := 'N';
    ELSE
       v_descuento := 'S';
    END IF;
    ----------------------------------------------------------
    -- 1. Mes de concresion igual al mes actual y
    --    mes de emision menor al mes actual
    -----------------------------------------------------
    IF v_ano_mes_vencimiento = v_ano_mes_actual AND
       v_ano_mes_operacion < v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(r_bsdfut.fec_vencimiento,'DD');
       v_dia_inicio := 1;
    END IF;
    -- 2. Mes de concresion igual al mes actual y
    --    mes de emision igual al mes actual.
    ---------------------------------------------------------
    IF nvl(v_ano_mes_liquidacion,' ') = v_ano_mes_actual AND
       v_ano_mes_operacion = v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(r_bsdfut.fec_vencimiento,'DD');
       v_dia_inicio := TO_CHAR(r_bsdfut.fec_operacion,'DD');
    END IF;
    -- 3. Mes de concresion es nulo, Mes de emision igual al
    --    mes actual y mes de liquidacion mayor al mes actual.
    ----------------------------------------------------------
    IF v_ano_mes_operacion = v_ano_mes_actual AND
       v_ano_mes_liquidacion IS NULL       AND
       v_ano_mes_vencimiento > v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(v_fec_ult_mes,'DD');
       v_dia_fin := v_dia_fin + 1;
       v_dia_inicio := TO_CHAR(r_bsdfut.fec_operacion,'DD');
    END IF;
    -- 5. Mes de emision es menor a mes actual y
    --    mes de concresion igual a nulo y
    --    mes de liquidacion es mayor al mes actual.
    ---------------------------------------------------------
    IF v_ano_mes_operacion < v_ano_mes_actual AND
       v_ano_mes_liquidacion IS NULL       AND
       v_ano_mes_vencimiento > v_ano_mes_actual THEN
       v_dia_fin := TO_CHAR(v_fec_ult_mes,'DD');
       v_dia_fin := v_dia_fin + 1;
       v_dia_inicio := 1;
    END IF;
    -- Calcula el importe diario de devengamiento multiplicado
    -- por la cantidad de dias transcurridos.
    ---------------------------------------------------------    
    v_int_devengado := round((v_dia_fin-v_dia_inicio) * v_mto_dia,0);
    INSERT INTO cb_sim_dev_futuras
      (nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_moneda, cod_oficina, nro_operacion, estado,
       can_dia_interes, mto_interes, mto_dev_acumulado,
       cod_mad_transaccion, cod_mad_padre, cod_ofi_origen, descuento,val_tasa)
    SELECT nro_cuenta, v_fec_actual, cod_modulo, cod_modalidad, v_cod_mon_local, cod_oficina, nro_operacion, 'M',
      (v_dia_fin-v_dia_inicio), v_int_devengado, v_int_devengado,
      cod_mad_transaccion, cod_mad_padre, cod_ofi_origen, v_descuento,0
      FROM LC_OPE_FUTURAS
     WHERE Rowid = v_fila;
    ------------------------------------------------------
  END LOOP;

END;

/* Insertar el registro del devengamiento de ahorros. */
PROCEDURE PR_INS_AH_DEVENGADOS
 (P_FEC_INICIO  IN CB_SIM_DEV_AHORROS.FEC_INICIO%TYPE,
  P_NRO_DIAS    IN CB_SIM_DEV_AHORROS.CAN_DIA_INTERES%TYPE,
  P_MTO_INTERES IN CB_SIM_DEV_AHORROS.MTO_INTERES%TYPE,
  P_MTO_CAPITAL IN CB_SIM_DEV_AHORROS.SAL_ACUMULADO%TYPE,
  P_VAL_TASA    IN CB_SIM_DEV_AHORROS.VAL_TASA%TYPE,
  P_FEC_TASA    IN CB_SIM_DEV_AHORROS.FEC_TASA%TYPE,
  P_MTO_AJUSTE  IN CB_SIM_DEV_AHORROS.MTO_AJUSTE%TYPE DEFAULT 0)
IS
BEGIN
   G_LUGAR := 'INSERTAR CB_SIM_DEV_AHORROS';
   INSERT INTO CB_SIM_DEV_AHORROS(NRO_CUENTA,
                                  COD_MONEDA,
                                  FECHA,
                                  VAL_TASA,
                                  FEC_TASA,
                                  CAN_DIA_INTERES,
                                  SAL_ACUMULADO,
                                  MTO_INTERES,
                                  FEC_INICIO,
                                  MTO_DEV_ACUMULADO,
                                  MTO_AJUSTE)
                           VALUES(G_NRO_CUENTA,
                                  G_COD_MONEDA,
                                  G_FEC_HOY,
                                  p_VAL_TASA,
                                  P_FEC_TASA,
                                  NVL(P_NRO_DIAS,0),
                                  P_MTO_CAPITAL,
                                  P_MTO_INTERES,
                                  P_FEC_INICIO,
                                  P_MTO_INTERES,
                                  P_MTO_AJUSTE);
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, SQLERRM||' / '||G_LUGAR||' / '||G_NRO_CUENTA);
END;
   
/* Actualiza los registros del devengamiento de ahorros. */
PROCEDURE PR_ACT_AH_DEVENGADOS
 (P_NRO_CUENTA     IN VARCHAR2
 ,P_FEC_INICIO     IN CB_SIM_DEV_AHORROS.FEC_INICIO%TYPE
 ,P_VAL_TASA       IN CB_SIM_DEV_AHORROS.VAL_TASA%TYPE
 ,P_MTO_CAPITAL    IN CB_SIM_DEV_AHORROS.SAL_ACUMULADO%TYPE
 ,P_INT_ANTERIOR   IN CB_SIM_DEV_AHORROS.MTO_INTERES%TYPE
 ,P_DIA_ANTERIORES IN CB_SIM_DEV_AHORROS.CAN_DIA_INTERES%TYPE
 ,P_DEV_ACUMULADO  IN CB_SIM_DEV_AHORROS.MTO_DEV_ACUMULADO%TYPE
 ,P_NRO_DIAS       IN CB_SIM_DEV_AHORROS.CAN_DIA_INTERES%TYPE
 ,P_MTO_INTERES    IN CB_SIM_DEV_AHORROS.MTO_INTERES%TYPE
 ,P_MTO_AJUSTE     IN CB_SIM_DEV_AHORROS.MTO_AJUSTE%TYPE)
IS

 -- Variables.
 v_int_hoy cb_sim_dev_ahorros.mto_interes%type;
 
BEGIN
   G_LUGAR := 'ACTUALIZA CB_SIM_DEV_AHORROS';
   V_INT_HOY := NVL(P_MTO_INTERES,0) - NVL(P_DEV_ACUMULADO,0);
   --
   UPDATE CB_SIM_DEV_AHORROS
      SET CAN_DIA_INTERES   = P_NRO_DIAS,
          MTO_DEV_ANTERIOR  = P_INT_ANTERIOR,
          DIA_DEV_ANTERIOR  = P_DIA_ANTERIORES,
          MTO_INTERES       = V_INT_HOY,
          MTO_DEV_ACUMULADO = NVL(MTO_DEV_ACUMULADO,0) + NVL(V_INT_HOY,0),
          FECHA             = G_FEC_HOY,
          SAL_ACUMULADO     = P_MTO_CAPITAL,
          VAL_TASA          = P_VAL_TASA,
          MTO_AJUSTE        = P_MTO_AJUSTE
    WHERE NRO_CUENTA = P_NRO_CUENTA
      AND FEC_INICIO = P_FEC_INICIO;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||G_LUGAR||' - '||P_NRO_CUENTA||' - '||
                              'Interes '||TO_CHAR(V_INT_HOY)||' - '||'P_MTO_CAPITAL '||TO_CHAR(P_MTO_CAPITAL));
END;  

/* Proceso del devengamiento de ahorro. */
PROCEDURE PR_PRO_AH_DEVENGADOS
 (P_FEC_DEV_INICIO IN cb_sim_dev_ahorros.FEC_INICIO%TYPE
 ,P_NRO_DIAS       IN cb_sim_dev_ahorros.CAN_DIA_INTERES%TYPE
 ,P_MTO_INTERES    IN cb_sim_dev_ahorros.MTO_INTERES%TYPE
 ,P_MTO_CAPITAL    IN cb_sim_dev_ahorros.SAL_ACUMULADO%TYPE
 ,P_VAL_TASA       IN cb_sim_dev_ahorros.VAL_TASA%TYPE
 ,P_FEC_TASA       IN cb_sim_dev_ahorros.FEC_TASA%TYPE
 ,P_MTO_AJUSTE     IN cb_sim_dev_ahorros.MTO_AJUSTE%TYPE DEFAULT 0)
 IS

 -- Variables.
 v_id      cb_sim_dev_ahorros%rowtype;
 v_int_hoy cb_sim_dev_ahorros.mto_interes%type;

 -- Cursores.
 CURSOR C_AH_DEVENGADOS IS
   SELECT *
     FROM CB_SIM_DEV_AHORROS
    WHERE NRO_CUENTA  = G_NRO_CUENTA
      AND FEC_INICIO  = P_FEC_DEV_INICIO;

BEGIN
   V_ID := NULL;
   OPEN C_AH_DEVENGADOS;
   FETCH C_AH_DEVENGADOS INTO V_ID;
   CLOSE C_AH_DEVENGADOS;
   --
      IF V_ID.FEC_INICIO IS NULL THEN
         V_INT_HOY:= NVL(P_MTO_INTERES,0);
         IF p_nro_dias > 0 THEN
           IF G_COD_MODALIDAD = 31 AND (NVL(P_MTO_CAPITAL,0)/NVL(P_NRO_DIAS,1)) < G_SAL_MIN_PACTADO THEN
              V_INT_HOY := 0;
           END IF;
         ELSE
           v_int_hoy := 0;
         END IF;
         G_LUGAR := 'Insertar AH_DEVENGADDOS';
         IF V_INT_HOY >= 0 THEN
            PR_INS_AH_DEVENGADOS(P_FEC_DEV_INICIO, P_NRO_DIAS, V_INT_HOY, P_MTO_CAPITAL, P_VAL_TASA, P_FEC_TASA, P_MTO_AJUSTE);
         END IF;
      ELSE
         V_INT_HOY := NVL(P_MTO_INTERES,0);
         IF G_COD_MODALIDAD = 31 AND G_SAL_PROMEDIO < G_SAL_MIN_PACTADO THEN
            V_INT_HOY:= 0;
         END IF;
         G_LUGAR := 'Acturalizar AH_DEVENGADDOS';
         PR_ACT_AH_DEVENGADOS(V_ID.NRO_CUENTA, P_FEC_DEV_INICIO, P_VAL_TASA, P_MTO_CAPITAL,
                              V_ID.MTO_INTERES, V_ID.CAN_DIA_INTERES, V_ID.MTO_DEV_ACUMULADO,
                              P_NRO_DIAS, V_INT_HOY,P_MTO_AJUSTE);
      END IF;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000, SQLERRM||' - '||G_LUGAR||' - '||G_NRO_CUENTA);
END;

/* Calcula el Devengado de Ahorro Vista */
PROCEDURE PR_CAL_AH_DEVENGADOS
 (P_FEC_INICIAL IN OUT AH_DEVENGADOS.FEC_INICIO%TYPE
 ,P_FEC_FINAL IN OUT AH_DEVENGADOS.FECHA%TYPE
 ,P_SALDO IN OUT AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_SAL_PROMEDIO IN AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_SAL_ACU_DIARIO IN OUT AH_DEVENGADOS.SAL_ACUMULADO%TYPE
 ,P_CAN_DIA_ACUMULADO IN OUT AH_DEVENGADOS.CAN_DIA_INTERES%TYPE)
IS

   -- Variables del procedimiento principal.   
   v_sal_acumulado        cb_sim_dev_ahorros.sal_acumulado%type := 0;
   v_sal_promedio         cb_sim_dev_ahorros.sal_acumulado%type := 0;
   v_can_dia_acumulado    ah_sal_mensuales.can_dia_acumulado%type;
   v_val_tasa             ge_tas_fechas.val_tasa%type;
   v_tip_valor            ge_tasas.tip_valor%type;   
   v_tipo                 ge_tasas.tipo%type;
   v_redondeo             number(5);
   v_mto_interes          number(18, 2) := 0;
   v_mto_int_acumulado    number(18, 2) := 0;
   v_fec_inicial          date;
   v_fec_final            date;
   /* siguiente fecha de vigencia de la tasa */
   v_sig_fec_vigencia     date;
   v_fec_vigencia         date;
   /* bandera que indica la terminación del ciclo */
   v_fin_tasa             varchar2(1) := 'N';
   
   -- Procedimientos Internos.
   -- Calcula el Saldo Acumulado.
   PROCEDURE LP_CAL_SAL_ACUMULADO
      (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
      ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
      ,P_COD_OFICINA IN AH_CTA_VISTAS.COD_OFICINA%TYPE
      ,P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
      ,P_FEC_INICIAL IN DATE
      ,P_FEC_FINAL IN DATE
      ,P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
      ,P_SALDO IN OUT NUMBER
      ,P_SAL_PROMEDIO IN OUT AH_CAPITALIZACIONES.SAL_PROMEDIO%TYPE
      ,P_SAL_ACUMULADO IN OUT NUMBER
      ,P_CAN_DIA_ACUMULADO IN OUT AH_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE)
   IS

   -- Variables.
   v_cod_transaccion  ge_transacciones.cod_transaccion%type;
   v_tip_detalle      ge_transacciones.tipo%type;
   v_fec_valor        ah_movimientos_his.fec_valor%type;
   v_monto            ah_movimientos_his.monto%type;

   -- Cursores.
   CURSOR c_mov_historicos IS
      SELECT FEC_VALOR, MONTO, T.COD_TRANSACCION, DECODE(T.COD_TRANSACCION,515,'C',560,'C',565,'C',TIPO) TIPO
        FROM GE_TRANSACCIONES T, AH_MOVIMIENTOS_HIS M
       WHERE T.COD_MODULO = p_cod_modulo
         AND T.COD_MODALIDAD = p_cod_modalidad
         AND M.NRO_CUENTA = p_nro_cuenta
         AND T.COD_TRANSACCION = M.COD_TRANSACCION
         AND T.COD_MODULO = M.COD_MODULO
         AND T.COD_MODALIDAD = M.COD_MODALIDAD
         AND FEC_VALOR >= p_fec_inicial
         AND FEC_VALOR <= p_fec_final
         AND TIPO IN ('C','D')
         AND AFECTA <> 'N'
         AND VE_CLIENTE = 'S'
   UNION ALL
      SELECT FEC_VALOR, MONTO, T.COD_TRANSACCION, DECODE(T.COD_TRANSACCION,515,'C',560,'C',565,'C',TIPO)
        FROM GE_TRANSACCIONES T, cb_sim_movimientos M
       WHERE T.COD_MODULO = p_cod_modulo
         AND T.COD_MODALIDAD = p_cod_modalidad
         AND M.NRO_CUENTA = p_nro_cuenta
         AND T.COD_TRANSACCION = M.COD_TRANSACCION
         AND T.COD_MODULO = M.COD_MODULO
         AND T.COD_MODALIDAD = M.COD_MODALIDAD
         AND FEC_VALOR >= p_fec_inicial
         AND FEC_VALOR <= p_fec_final
         AND TIPO IN ('C','D')
         AND VE_CLIENTE = 'S'
         AND AFECTA <> 'N'
       ORDER BY 1;

   BEGIN

      If p_fec_inicial = to_date('01'||to_char(p_fec_inicial, 'MMYYYY'), 'DDMMYYYY') and
        (p_fec_final = last_day(p_fec_final) or p_fec_final = G_ULT_MES_HABIL) Then
        --- Busca el saldo promedio ---
        pag_cta.pr_obt_sal_promedio (p_cod_modulo,
                                     p_cod_modalidad,
                                     p_cod_oficina,
                                     p_nro_cuenta,
                                     p_fec_inicial,
                                     p_fec_final,
                                     p_sal_acumulado,
                                     p_sal_promedio,
                                     p_can_dia_acumulado);
        -- Obtiene el Saldo Final por si tenga que utilizar para el proximo sub-periodo
        begin
          Select sal_ini_mes
            into p_saldo
            from ah_sal_mensuales
           where nro_cuenta = p_nro_cuenta
             and mes = to_number(to_char(add_months(p_fec_final,1), 'MM'))
             and ano = to_number(to_char(add_months(p_fec_final,1), 'YYYY')); 
        exception
           when no_data_found then
              p_saldo := 0;

        end;

      Else
         p_can_dia_acumulado := p_fec_final - p_fec_inicial + 1;

         p_sal_acumulado := p_saldo; --Inicializa Acumulado al Saldo Inicial
         p_sal_acumulado := (NVL(p_sal_acumulado,0) * NVL(p_can_dia_acumulado,0));

         IF c_mov_historicos%ISOPEN THEN
            CLOSE c_mov_historicos;
         END IF;

         OPEN c_mov_historicos;
            LOOP
               FETCH c_mov_historicos
               INTO v_fec_valor, v_monto, v_cod_transaccion, v_tip_detalle;
               EXIT WHEN c_mov_historicos%NOTFOUND;

               --Calcula el Saldo Acumulado
               if v_tip_detalle  = 'C'  THEN
                  p_sal_acumulado := p_sal_acumulado + ((p_fec_final-v_fec_valor+1)*v_monto);
                  p_saldo  := to_number(p_saldo) + v_monto;
               else
                  p_sal_acumulado := p_sal_acumulado -((p_fec_final-v_fec_valor+1)*v_monto);
                  p_saldo := p_saldo - v_monto;
               end if;
  
            END LOOP;

            If nvl(p_can_dia_acumulado,0) > 0 then
               p_sal_promedio := p_sal_acumulado/ p_can_dia_acumulado;
            End if;
      End If;
   END;
  
-- Proceso Principal.
BEGIN
   --Obtiene la moneda local
   v_sal_acumulado     := 0;
   v_mto_int_acumulado := 0;
   v_fec_inicial       := p_fec_inicial;
   v_fec_final         := p_fec_final;
   v_fin_tasa          := 'N';
   ---
   LOOP

      EXIT WHEN v_fin_tasa = 'S';
      -- Obtengo la sgte fecha de vigencia ---
      paa_cta.pr_tas_sig_vigencia(g_cod_tasa,3,31,g_cod_oficina,
                                  g_cod_moneda, g_nro_cuenta,
                                  v_fec_inicial, p_fec_final,
                                  v_sig_fec_vigencia, v_fin_tasa);
      v_fec_final := v_sig_fec_vigencia-1;
      -- modificacion para Banco Regional
      if to_char(v_fec_final,'yyyymm') <> to_char(v_fec_inicial,'yyyymm') then
         v_fec_final := last_day(v_fec_inicial); -- ultimo dia del mes
         v_sig_fec_vigencia := v_fec_final + 1;
         v_fin_tasa := 'N';
      end if;
      -- calculo el promedio del sub-periodo
       lp_cal_sal_acumulado(3, --modulo
                            g_cod_modalidad,
                            g_cod_oficina,
                            g_nro_cuenta,
                            v_fec_inicial,
                            v_fec_final,
                            g_cod_moneda,
                            --- OUT
                            p_saldo,
                            v_sal_promedio,
                            v_sal_acumulado,
                            v_can_dia_acumulado);
      -- si hay sub periodo que calcular
      if v_can_dia_acumulado > 0 then
         --
         pag_gen.pr_obt_val_tasa(g_cod_modulo,  g_cod_modalidad,
                                 g_cod_oficina, g_nro_cuenta,
                                 g_cod_moneda,  v_sal_promedio,
                                 g_tas_personalizada, g_cod_tasa,
                                 null,    v_fec_final,
                                 --- OUT ---
                                 v_val_tasa, v_fec_vigencia, v_tip_valor, v_tipo);                                          
         v_mto_interes :=  pag_gen.fu_cal_int_simple((v_sal_acumulado/v_can_dia_acumulado),
                                                      to_char(last_day(v_fec_inicial),'dd'),
                                                      v_val_tasa);
      else

         v_val_tasa    := 0; --- Si no tuvo promedios
         v_mto_interes := 0;
      end if;
      -- Redondeo del Interes.
      ---------------------------------------------------
      -- Si la Moneda de la Cuenta es igual a la Moneda Local
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,G_COD_MODALIDAD,g_cod_moneda);
      v_mto_interes := round(v_mto_interes,v_redondeo);
      --- Insertar devengado
      G_LUGAR := 'Procesar AH_DEVENGADOS (PR_CAL_AH_DEVENGADOS)';
      PR_PRO_AH_DEVENGADOS(v_fec_inicial, v_can_dia_acumulado, V_MTO_INTERES,
                           v_sal_acumulado, v_val_tasa, v_fec_inicial, 0);
      --
      v_mto_int_acumulado := v_mto_int_acumulado + v_mto_interes;
      -----------------------------------------------------------------------
      v_fec_inicial := v_sig_fec_vigencia;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20020,'Dev. Cta. '||g_nro_cuenta||' '||sqlerrm);
END;

/* Calcula el Devengado de Ahorro Vista */
PROCEDURE PR_DEV_AHORROS(p_fecha in ge_calendarios.fec_actual%type)
IS
   -- Cursor.
   CURSOR c_ah_cta_vistas IS
      SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA,
             FEC_ULT_CAPITALIZACION, SAL_MINIMO, TAS_PERSONALIZADA, SAL_TOTAL, COD_TASA,
             (SAL_TOTAL + MTO_CRE_A_CONFIRMAR) - (SAL_BLOQUEADO + SAL_RETENIDO + MTO_CRE_PENDIENTES + MTO_DEB_PENDIENTES) SAL_DISPONIBLE,
             SAL_ULT_CAPITALIZACION
        FROM AH_CTA_VISTAS
       WHERE ESTADO NOT IN ('C','A','P','X')
         AND FEC_APERTURA <= G_FEC_HOY;
BEGIN
      -- Asigno la fecha.      
      pag_cal.PR_OBT_DAT_CALENDAR(2);
      G_FEC_HOY     := p_fecha;
      -- Obtengo el última día del mes.
      BEGIN
         SELECT last_day(g_fec_hoy)
           INTO G_ULT_DIA_MES
           FROM DUAL;
      EXCEPTION
         WHEN OTHERS THEN
            G_ULT_DIA_MES := pag_cal.G_ULT_DIA_MES;
      END;
      
      
      G_LUGAR := 'Empieza el ciclo';
      FOR CTA_A_DEV IN C_AH_CTA_VISTAS  LOOP
         G_LUGAR             := 'INICIALIZA VARIABLE ';
         G_SECUENCIA         := 0;
         G_COD_MODULO        := CTA_A_DEV.COD_MODULO;
         G_COD_MODALIDAD     := CTA_A_DEV.COD_MODALIDAD;
         G_COD_OFICINA       := CTA_A_DEV.COD_OFICINA;
         G_NRO_CUENTA        := CTA_A_DEV.NRO_CUENTA;
         G_COD_MONEDA        := CTA_A_DEV.COD_MONEDA;
         G_FEC_ULT_CAPITALIZACION := CTA_A_DEV.FEC_ULT_CAPITALIZACION;
         G_FEC_APERTURA      := CTA_A_DEV.FEC_APERTURA;
         G_COD_TASA          := CTA_A_DEV.COD_TASA;
         G_SAL_DISPONIBLE    := CTA_A_DEV.SAL_DISPONIBLE;
         G_TAS_PERSONALIZADA := CTA_A_DEV.TAS_PERSONALIZADA;
         --

         -- Asigno la fecha del devengamiento.
         G_FEC_FINAL := G_ULT_DIA_MES;
         --
         G_LUGAR := 'Inicializa la fecha inicio del Devengado';
         IF G_FEC_ULT_CAPITALIZACION IS NULL THEN
            G_FEC_INICIO := G_FEC_APERTURA;
         ELSIF G_FEC_ULT_CAPITALIZACION >= G_FEC_APERTURA THEN
            G_FEC_INICIO := G_FEC_ULT_CAPITALIZACION + 1 ;
         ELSE
            raise_application_error(-20021,
            'Fecha de ultima capitalización no puede ser menor a la de apertura');
         END IF;
         --
         G_LUGAR := 'Inicializa Saldo Minimo Pactado';

         IF CTA_A_DEV.SAL_MINIMO IS NULL THEN
            --
            G_LUGAR := 'Obtener Parametro Saldo Minimo';
            --recuperar el saldo minimo del parametro
            DECLARE
              v_cod_persona varchar2(15) := fug_obt_cli_principal(G_NRO_CUENTA);
            BEGIN
               G_SAL_MIN_GENERAL := FUG_OBT_SAL_MIN_PACTADO(G_COD_MONEDA, v_cod_persona, G_COD_MODULO,
                               G_COD_MODALIDAD, G_COD_OFICINA);
            END;
            G_SAL_MIN_PACTADO := G_SAL_MIN_GENERAL;
         ELSE
            G_SAL_MIN_PACTADO := CTA_A_DEV.SAL_MINIMO;
         END IF;
         --
         G_LUGAR := 'Obtener Saldo Promedio AH_CTA_VISTAS';
         PAG_CTA.PR_OBT_SAL_PROMEDIO(G_COD_MODULO, G_COD_MODALIDAD, G_COD_OFICINA,
                                     G_NRO_CUENTA, G_FEC_INICIO, G_FEC_FINAL,
                                     G_SAL_ACUMULADO, G_SAL_PROMEDIO, G_DIA_ACUMULADO);

         G_LUGAR := 'Calcular devengado AH_CTA_VISTAS';
         -- Inserto el historico del devengado.
         BEGIN
            INSERT INTO cb_sim_dev_ahorros(nro_cuenta, 
                                           fecha, 
                                           cod_moneda, 
                                           val_tasa, 
                                           fec_tasa, 
                                           can_dia_interes, 
                                           sal_acumulado, 
                                           mto_interes, 
                                           dia_dev_anterior, 
                                           mto_dev_anterior, 
                                           fec_inicio, 
                                           mto_dev_acumulado, 
                                           mto_ajuste)
            SELECT nro_cuenta, 
                   fecha, 
                   cod_moneda, 
                   val_tasa, 
                   fec_tasa, 
                   can_dia_interes, 
                   sal_acumulado, 
                   mto_interes, 
                   dia_dev_anterior, 
                   mto_dev_anterior, 
                   fec_inicio, 
                   mto_dev_acumulado,                    
                   mto_ajuste
              FROM ah_devengados m 
             WHERE m.nro_cuenta = CTA_A_DEV.Nro_Cuenta 
               AND m.fecha > NVL(CTA_A_DEV.FEC_ULT_CAPITALIZACION,G_FEC_INICIO);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
         
         --- Esta rutina debe coincidir con la capitalización de ahorro a la vista
         PR_CAL_AH_DEVENGADOS(G_FEC_INICIO, G_FEC_FINAL,  CTA_A_DEV.SAL_ULT_CAPITALIZACION,
                              G_SAL_PROMEDIO, G_SAL_ACUMULADO, G_DIA_ACUMULADO );
         --
      END LOOP;
END;

FUNCTION FU_BON_SUB_SEN (P_NRO_CUENTA GE_CUENTAS.NRO_CUENTA%TYPE)
   RETURN BOOLEAN
IS
   v_existe number(1):=0;
BEGIN
   SELECT 1
     INTO v_existe
     FROM AH_CTA_CERTIFICADOS A, AH_TITULOS T
    WHERE A.NRO_CUENTA = P_NRO_CUENTA
      AND A.SER_TITULO = T.SERIE
      AND A.NRO_TITULO = T.NRO_TITULO
      AND T.SER_ORIGEN = 'SEN';
   IF nvl(v_existe,0) = 1 THEN
     RETURN TRUE;
   ELSE
     RETURN FALSE;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
     RETURN FALSE;
END;

/* Obtener fecha de vencimiento. */
FUNCTION FU_OBT_FEC_VTO_CUPON
 (P_NRO_CUENTA IN AH_CTA_VISTAS.NRO_CUENTA%TYPE
 ,P_FEC_VENCIMIENTO IN AH_CTA_PLAZOS.FEC_VENCIMIENTO%TYPE
 )
 RETURN DATE
 IS
  -- Variables.
  v_fec_vencimiento ah_cta_plazos.fec_vencimiento%type;
  v_fec_final    date;
BEGIN
  v_fec_final := g_ult_dia_mes;

  SELECT MAX(FEC_VENCIMIENTO)
    INTO V_FEC_VENCIMIENTO
    FROM AH_CUPONES
   WHERE NRO_CUENTA = P_NRO_CUENTA
     AND ((FEC_VENCIMIENTO < P_FEC_VENCIMIENTO and G_FEC_ANTERIOR + 1 = v_fec_final) OR
          (FEC_VENCIMIENTO <= P_FEC_VENCIMIENTO and G_FEC_ANTERIOR + 1 < v_fec_final)) ;
  RETURN(V_FEC_VENCIMIENTO);
EXCEPTION
  WHEN OTHERS THEN
    V_FEC_VENCIMIENTO := G_FEC_HOY;
    RETURN(V_FEC_VENCIMIENTO);
END;

/* Calcula del Devengamiento de CDA. */
PROCEDURE PR_CAL_DEV_AH_CTA_PL  (P_FEC_DEV_INICIO IN OUT AH_DEVENGADOS.FEC_INICIO%TYPE,
                                 P_FEC_DEV_FINAL IN OUT AH_DEVENGADOS.FECHA%TYPE,
                                 P_MTO_CAPITAL IN OUT AH_DEVENGADOS.SAL_ACUMULADO%TYPE,
                                 P_TAS_PERSONALIZADA IN OUT AH_CTA_PLAZOS.TAS_PERSONALIZADA%TYPE,
                                 P_FEC_APERTURA IN OUT AH_CTA_PLAZOS.FEC_APERTURA%TYPE,
                                 P_FEC_ULT_CAPITALIZACION IN OUT AH_CTA_PLAZOS.FEC_ULT_CAPITALIZACION%TYPE,
                                 P_TIP_CAPITALIZACION IN OUT AH_CTA_PLAZOS.TIP_CAPITALIZACION%TYPE)
IS
-- Variables.
v_dias cb_sim_dev_ahorros.can_dia_interes%type;
v_mto_interes cb_sim_dev_ahorros.mto_interes%type;
v_mto_int_cupon ah_cupones.mto_interes%type;
v_mto_ajuste ah_cupones.mto_interes%type;
v_fec_vto_cupon date;
v_redondeo number(5);

BEGIN
      G_LUGAR := 'Busca el valor de tasa a aplicar (PR_CAL_DEV_AH_CTA_PLAZOS)';
      PAG_GEN.PR_OBT_VAL_TASA(G_COD_MODULO,
                              G_COD_MODALIDAD, G_COD_OFICINA,
                              G_NRO_CUENTA, G_COD_MONEDA, P_MTO_CAPITAL,
                              P_TAS_PERSONALIZADA, G_COD_TASA, 609, P_FEC_DEV_FINAL,
                              G_VAL_TASA, G_FEC_VIG_TASA, G_TIP_VALOR,
                              G_TIP_TASA);
      -- busco la fecha de vencimiento de algun cupon entre la ultima capitalizacion y hoy
      IF G_COD_MODALIDAD IN (33,34,35,36) THEN
         V_FEC_VTO_CUPON := FU_OBT_FEC_VTO_CUPON(G_NRO_CUENTA, P_FEC_DEV_FINAL);
      END IF;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,G_COD_MODALIDAD,G_COD_MONEDA);
      IF (G_COD_MODALIDAD in (32,37) AND PAG_GEN.FU_AGR_MES(NVL(TRUNC(P_FEC_ULT_CAPITALIZACION),P_FEC_APERTURA),P_TIP_CAPITALIZACION) < P_FEC_DEV_FINAL) OR
         (G_COD_MODALIDAD IN (33,34,35,36) AND V_FEC_VTO_CUPON - 1 > P_FEC_DEV_INICIO  ) THEN
       -- Corte porque existe un cupon vencido en dia no habil anterior a hoy(posterior a la ultima capitalizacion)

         IF G_COD_MODALIDAD in (32,37) THEN
            V_DIAS := (PAG_GEN.FU_AGR_MES(NVL(TRUNC(P_FEC_ULT_CAPITALIZACION),P_FEC_APERTURA), P_TIP_CAPITALIZACION) - P_FEC_DEV_FINAL) + 1;
         ELSE
            V_DIAS := V_FEC_VTO_CUPON - P_FEC_DEV_INICIO;
         END IF;
         --
         G_LUGAR := 'Calcular Interes (PR_CAL_DEV_AH_CTA_PLAZOS)';
         V_MTO_INTERES := PAG_GEN.FU_CAL_INT_SIMPLE(P_MTO_CAPITAL, V_DIAS, G_VAL_TASA);
         --
         IF (G_COD_MODALIDAD IN (33,34,35)) OR
            (G_COD_MODALIDAD = 36 AND NOT FU_BON_SUB_SEN(G_NRO_CUENTA)) THEN
            V_MTO_INTERES:= FLOOR(V_MTO_INTERES) ;
         ELSIF G_COD_MONEDA = G_MON_LOCAL THEN
            V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
         ELSE
            V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
         END IF;
         V_MTO_AJUSTE := 0;
         -- Ajusto el interes al del cupon si es que son diferentes
         IF G_COD_MODALIDAD IN (33,34,35,36) THEN
            V_MTO_INT_CUPON := PAA_DEV.FU_OBT_INT_CUPON(G_NRO_CUENTA, V_FEC_VTO_CUPON - 1); -- SE envia -1 para tomar el valor del vencimiento actual
            IF ABS(V_MTO_INTERES - nvl(V_MTO_INT_CUPON,0)) != 0 and v_mto_int_cupon is not null THEN
               V_MTO_AJUSTE  := NVL(V_MTO_INTERES,0) - nvl(V_MTO_INT_CUPON,0);  -- monto del ajuste
               V_MTO_INTERES := V_MTO_INT_CUPON;
            END IF;
         END IF;
         G_MTO_DEVENGADO := G_MTO_DEVENGADO + V_MTO_INTERES;
         IF V_MTO_INTERES >= 0 THEN
            G_LUGAR := 'Procesar cb_sim_dev_ahorros PR_CAL_DEV_AH_CTA_PLAZOS';
            PR_PRO_AH_DEVENGADOS(P_FEC_DEV_INICIO, V_DIAS, V_MTO_INTERES, P_MTO_CAPITAL, G_VAL_TASA, V_FEC_VTO_CUPON-1, V_MTO_AJUSTE);
         END IF;
         --
         IF G_COD_MODALIDAD in (32,37) THEN
            P_FEC_DEV_INICIO := PAG_GEN.FU_AGR_MES(NVL(TRUNC(P_FEC_ULT_CAPITALIZACION),P_FEC_APERTURA), P_TIP_CAPITALIZACION) + 1;
         ELSE
            P_FEC_DEV_INICIO := V_FEC_VTO_CUPON;
         END IF;
      ELSIF PAA_DEV.FU_OBT_FEC_VTO_CUPON(G_NRO_CUENTA,P_FEC_DEV_FINAL+1) = P_FEC_DEV_FINAL and p_fec_dev_final = G_FEC_HOY THEN
         ---- Si el cupon vence hoy debe devengar por un solo día - Le envio mañana para que devuelva si vence hoy
         P_FEC_DEV_INICIO := P_FEC_DEV_FINAL;
      END IF;

      V_DIAS:= (P_FEC_DEV_FINAL - P_FEC_DEV_INICIO) + 1;
      G_LUGAR := 'Calcular Interes (PR_CAL_DEV_AH_CTA_PLAZOS)';
      V_MTO_INTERES := PAG_GEN.FU_CAL_INT_SIMPLE(P_MTO_CAPITAL, V_DIAS, G_VAL_TASA);
      --
      IF (G_COD_MODALIDAD IN (33,34,35)) OR
         (G_COD_MODALIDAD = 36 AND NOT FU_BON_SUB_SEN(G_NRO_CUENTA)) THEN
         V_MTO_INTERES:= FLOOR(V_MTO_INTERES) ;
      ELSIF G_COD_MONEDA = G_MON_LOCAL THEN
         V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
      ELSE
         V_MTO_INTERES := ROUND(V_MTO_INTERES,v_redondeo);
      END IF;
      V_MTO_AJUSTE := 0;
      -- Ajusto el Interés al del cupon si es que son diferentes(solo hasta 20)
      IF G_COD_MODALIDAD IN (33,34,35,36) THEN
         V_MTO_INT_CUPON := PAA_DEV.FU_OBT_INT_CUPON(G_NRO_CUENTA, P_FEC_DEV_FINAL);
            IF ABS(V_MTO_INTERES - nvl(V_MTO_INT_CUPON,0)) != 0 and v_mto_int_cupon is not null THEN
               V_MTO_AJUSTE  := NVL(V_MTO_INTERES,0) - nvl(V_MTO_INT_CUPON,0);  -- monto del ajuste
               V_MTO_INTERES := V_MTO_INT_CUPON;
            END IF;
      END IF;
      G_MTO_DEVENGADO := G_MTO_DEVENGADO + V_MTO_INTERES;

      IF V_MTO_INTERES >= 0 THEN
         G_LUGAR := 'Procesar AH_DEVENGADOS (PR_CAL_DEV_AH_CTA_PLAZOS)';
         PR_PRO_AH_DEVENGADOS(P_FEC_DEV_INICIO, V_DIAS, V_MTO_INTERES, P_MTO_CAPITAL, G_VAL_TASA, P_FEC_DEV_FINAL, V_MTO_AJUSTE);
      END IF;
   END;

/* Calcula del Devengamiento de CDA. */
PROCEDURE PR_DEV_CTA_CERTIFICADO(P_CIERRE VARCHAR2 DEFAULT null)
 IS

   -- Variables.
   v_tip_capitalizacion ah_cta_plazos.tip_capitalizacion%type;
   
   -- SELECCIONA CDA PARA DEVENGAR
   CURSOR C_AH_CTA_CERTIFICADOS IS
      SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, COD_MONEDA, FEC_APERTURA,
           CAPITAL, FEC_VENCIMIENTO, COD_TASA, TAS_PERSONALIZADA, FEC_ULT_CAPITALIZACION
      FROM AH_CTA_CERTIFICADOS
     WHERE ((NVL(P_CIERRE,'N') = 'N' AND  -- Si es por dev. diario normal
             EST_BATCH NOT IN ('V','A','T','P','C','X') AND
             NVL(FEC_ULT_CAPITALIZACION, FEC_APERTURA) <= G_FEC_HOY AND
             FEC_VENCIMIENTO > G_FEC_ANTERIOR + 1) OR
            (NVL(P_CIERRE,'N') = 'S' AND -- Si es el cierre mensual
             ESTADO NOT IN ('V','A','T','P','C','X') AND
             FEC_APERTURA = G_FEC_HOY AND
             FEC_VENCIMIENTO > G_FEC_HOY))
       UNION 
      SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.NRO_CUENTA, A.COD_MONEDA, A.FEC_APERTURA,
           A.CAPITAL, A.FEC_VENCIMIENTO, A.COD_TASA, A.TAS_PERSONALIZADA, A.FEC_ULT_CAPITALIZACION
      FROM AH_CTA_CERTIFICADOS A, AH_TITULOS T
     WHERE ((NVL(P_CIERRE,'N') = 'N' AND  -- SI ES POR DEV. DIARIO NORMAL
             A.EST_BATCH NOT IN ('V','A','T','P','C','X') AND
             NVL(A.FEC_ULT_CAPITALIZACION, A.FEC_APERTURA) <= G_FEC_HOY AND
             A.FEC_VENCIMIENTO > G_FEC_ANTERIOR + 1) OR
            (NVL(P_CIERRE,'N') = 'S' AND -- SI ES EL CIERRE MENSUAL
             A.ESTADO NOT IN ('V','A','T','P','C','X') AND
             A.FEC_VENCIMIENTO > G_FEC_HOY
             AND NOT EXISTS (SELECT 1 FROM AH_DEVENGADOS D
                             WHERE  D.NRO_CUENTA = A.NRO_CUENTA)
             AND NOT EXISTS (SELECT 1 FROM AH_DEVENGADOS_HIS H
                             WHERE  H.NRO_CUENTA = A.NRO_CUENTA)))
             AND A.SER_TITULO = T.SERIE
             AND A.NRO_TITULO = T.NRO_TITULO
             AND T.SER_ORIGEN = 'SEN';
BEGIN
--
   FOR CTA_A_DEV IN C_AH_CTA_CERTIFICADOS LOOP
      G_LUGAR           := 'INICIALIZA VARIABLE ';
      G_COD_MODULO      := CTA_A_DEV.COD_MODULO;
      G_COD_MODALIDAD   := CTA_A_DEV.COD_MODALIDAD;
      G_COD_OFICINA     := CTA_A_DEV.COD_OFICINA;
      G_NRO_CUENTA      := CTA_A_DEV.NRO_CUENTA;
      G_COD_MONEDA      := CTA_A_DEV.COD_MONEDA;
      G_FEC_APERTURA    := CTA_A_DEV.FEC_APERTURA;
      G_FEC_VENCIMIENTO := CTA_A_DEV.FEC_VENCIMIENTO;
      G_FEC_ULT_CAPITALIZACION := CTA_A_DEV.FEC_ULT_CAPITALIZACION;
      G_COD_TASA        := CTA_A_DEV.COD_TASA;
      G_MTO_CAPITAL     := CTA_A_DEV.CAPITAL;

      -- fecha de inicio del devengamiento
      G_LUGAR := 'Inicializa la fecha inicio del Devengado';
      IF G_FEC_ULT_CAPITALIZACION IS NULL THEN
         G_FEC_INICIO := G_FEC_APERTURA;
      ELSE 
         G_FEC_INICIO := G_FEC_ULT_CAPITALIZACION;
      END IF;
      -- fecha fin del devengamiento--
      G_FEC_FINAL := G_ULT_DIA_MES;
      -- Se ajusta la fecha del devengamiento si ya vence el capital
      IF G_FEC_FINAL >= G_FEC_VENCIMIENTO THEN
         G_FEC_FINAL := G_FEC_VENCIMIENTO -1;
      END IF;
      
      -- Inserto el historico del devengado.
      BEGIN
         INSERT INTO cb_sim_dev_ahorros(nro_cuenta, 
                                        fecha, 
                                        cod_moneda, 
                                        val_tasa, 
                                        fec_tasa, 
                                        can_dia_interes, 
                                        sal_acumulado, 
                                        mto_interes, 
                                        dia_dev_anterior, 
                                        mto_dev_anterior, 
                                        fec_inicio, 
                                        mto_dev_acumulado, 
                                        mto_ajuste)
         SELECT nro_cuenta, 
                fecha, 
                cod_moneda, 
                val_tasa, 
                fec_tasa, 
                can_dia_interes, 
                sal_acumulado, 
                mto_interes, 
                dia_dev_anterior, 
                mto_dev_anterior, 
                fec_inicio, 
                mto_dev_acumulado,                    
                mto_ajuste
           FROM ah_devengados m 
          WHERE m.nro_cuenta = CTA_A_DEV.Nro_Cuenta 
            AND m.fecha > NVL(CTA_A_DEV.FEC_ULT_CAPITALIZACION,G_FEC_INICIO);
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
      
      -- calculo del devengamiento
      V_TIP_CAPITALIZACION := 1;
      G_LUGAR := 'PR_DEV_AH_CTA_CERTIFICADOS';
      PR_CAL_DEV_AH_CTA_PL(G_FEC_INICIO,
                           G_FEC_FINAL, G_MTO_CAPITAL,
                           CTA_A_DEV.TAS_PERSONALIZADA, CTA_A_DEV.FEC_APERTURA,
                           CTA_A_DEV.FEC_ULT_CAPITALIZACION, V_TIP_CAPITALIZACION);
      --
   END LOOP;
END;

/* Calcula el Devengado de CDA. */
PROCEDURE PR_DEV_CERTIFICADOS(p_fecha in ge_calendarios.fec_actual%type)
IS
   
BEGIN
   -- Variables Globales.
   g_lugar     := 'obtener moneda local';

   g_mon_local := pag_gen.fu_obt_mon_local;
   --
   g_lugar := 'obtiene cambio de ge_calendrios';
   pag_cal.pr_obt_dat_calendar(2);
   --   
   g_fec_hoy       := p_fecha;
   g_fec_anterior  := pag_cal.FU_OBT_FEC_ANT_HAB(g_fec_hoy,1);
   -- Obtengo el último día del mes.
   BEGIN
      SELECT last_day(g_fec_hoy)
        INTO g_ult_dia_mes
        FROM dual;
   EXCEPTION
      WHEN OTHERS THEN
         g_ult_dia_mes   := pag_cal.g_ult_dia_mes;      
   END;
   --
   g_lugar := 'devengamiento de certificados';
   PR_DEV_CTA_CERTIFICADO('N'); 
   
END;

/* Calcula el Devengado de Préstamos. */
PROCEDURE PR_PRO_DEV_PRESTAMOS(p_fecha in ge_calendarios.fec_actual%type)
 IS
   -- Variables.
   r_deven            cb_sim_dev_prestamos%rowtype;
   v_estado           pr_cta_prestamos.estado%type;
   v_dev_ant_can_par  pr_cuotas.dev_acumulado%type;   
   v_fec_sist         date;   
   v_redondeo         number(1);
   v_moneda           varchar2(3);  
   v_acu_devengado    varchar2(1) default 'N';   
   --  
   v_mone_local       ba_monedas.cod_moneda%type;
   v_mone_fuerte      ba_monedas.cod_moneda%type;
   v_cotizacion       ge_cotizaciones.val_conversion%type;
   v_interes          pr_cuotas.mto_interes%type;
   v_capital          pr_cuotas.mto_capital%type;
   v_nro_cuenta       pr_cta_prestamos.nro_cuenta%type;
   v_categoria        ge_clientes.cat_automatica%type;
   v_cotiz_fuerte     ge_cotizaciones.val_venta%type;
   v_tasa             number;
   v_fec_ini          date;
   v_fec_fin          date;
   v_fec_ult_dev      date;      
   ultdiam            date;      
   ---
   v_dev_suspenso     pr_cuotas.dev_suspenso%type;
   v_dev_no_cobrado   pr_cuotas.dev_no_cobrado%type;
   v_tot_suspenso     pr_cuotas.dev_suspenso%type;
   v_tot_no_cobrado   pr_cuotas.dev_no_cobrado%type;
   v_mto_ajuste       cb_sim_dev_prestamos.mto_ajuste%type;
   v_fec_ini_dev      cb_sim_dev_prestamos.fec_inicio%type;
   v_fec_ini_dev_aux  cb_sim_dev_prestamos.fec_inicio%type;
   v_fec_fin_dev      cb_sim_dev_prestamos.fec_inicio%type;
   v_devengo          varchar2(1);   
   --
   v_no_cobrado       pr_cuotas.dev_no_cobrado%type;
   v_suspenso         pr_cuotas.dev_suspenso%type;
   v_acumulado        pr_cuotas.dev_acumulado%type;
   v_int_cobrado      pr_cuotas.sal_interes%type;
   v_mto_interes      pr_cuotas.sal_interes%type;
   v_sal_interes      pr_cuotas.sal_interes%type;
   v_int_devengar     pr_cuotas.sal_interes%type;
   v_val_int_devengar pr_cuotas.sal_interes%type;

   --- Definicion del cursor de prestamos vigentes a procesar
   cursor c_prestamos IS
   SELECT a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, nro_solicitud,
          val_int_devengar, val_tasa, fec_inicio, fec_vencimiento, a.tipo, a.estado,
          sal_interes, cod_moneda, NVL(fec_ult_devengado, NULL) fec_ult_dev,
          c.cod_gru_economico, fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
          dev_no_cobrado, tip_interes
     FROM ge_clientes c, ge_cta_clientes b, pr_cta_prestamos a
    WHERE c.cod_persona = b.cod_persona
      AND b.nro_cuenta  = a.nro_cuenta
      and a.cod_modalidad not in (670,671) --- No debe devengarse VENTA DE BIENES ADJUDICADOS
      and b.relacion    = 'P'
      AND a.estado not in ('N','I')  --- No incluir Canceladas ni Irrecuperables
      --- Que no tome cuentas vencidas aunque no halla devengado todo
      and (a.fec_vencimiento > decode(v_fec_sist,v_fec_fin,v_fec_sist,(v_fec_fin - 1))
         or (a.fec_vencimiento > a.fec_ult_devengado and a.val_int_devengar <> 0)) -- Modificado por ICL por diferencia en Utilidad de Agosto/2010
      --- No debe devengar las cuentas canceladas por adelantado
      and nvl(a.fec_ult_devengado,a.fec_inicio-1) < v_fec_fin
      AND a.fec_inicio <= v_fec_sist;

   --- Definicion del cursor de cuotas a procesar por prestamo
   cursor c_cuotas is
   SELECT nro_cuota, mto_capital, mto_int_documentado, mto_cap_adelantado,
          fec_vencimiento, nro_cuenta, dev_acumulado, mto_interes,
          mto_int_descontado, decode(dev_no_cobrado,0,'N','S') acu_devengado
     FROM pr_cuotas a
    WHERE a.nro_cuenta = v_nro_cuenta
      and a.nro_cuota > 0
      AND a.estado <> 'N'
      and nvl(a.sal_interes,0) + nvl(a.sal_int_documentado,0) > 0
      --- Cuando devenga de mas tambien debe incluir
      AND ((nvl(dev_acumulado,0) <> (nvl(mto_interes,0) + nvl(mto_int_documentado,0) - nvl(mto_int_descontado,0)))
      --- RI: 24/08/2010: debe incluir tambien los que devengaron adelantado, para ajustar
       or  (a.fec_vencimiento > v_fec_ult_dev)--)
      --- RI: 27/10/2010: debe incluir tambien los que tengan diferencia del Dev_no_cobrado/Suspenso
       OR  (nvl(dev_no_cobrado,0)+nvl(dev_suspenso,0)) <> (nvl(dev_acumulado,0)-((nvl(mto_interes,0)+nvl(mto_int_documentado,0)-nvl(mto_int_descontado,0))-
           (nvl(sal_interes,0)+nvl(sal_int_documentado,0)))) )
    ORDER BY a.nro_cuota;

    TYPE cursor1_type IS TABLE of c_prestamos%rowtype;
    reg cursor1_type;
    
    -- Procedimientos Internos.
    PROCEDURE pr_ins_pr_devengados
    IS
       -- Variables.
       v_rowid varchar2(100);
    BEGIN
       SELECT rowid into v_rowid
         FROM cb_sim_dev_prestamos
        WHERE nro_cuenta = r_deven.nro_cuenta
          AND nro_cuota  = r_deven.nro_cuota
          AND tipo       = r_deven.tipo
          AND cod_moneda = r_deven.cod_moneda
          AND estado     = r_deven.estado
          AND categoria  = nvl(r_deven.categoria,1)
          AND capital    = r_deven.capital
          AND val_tasa   = r_deven.val_tasa;
   
       -- Actualizar el registro existente.   
       update cb_sim_dev_prestamos
          set can_dia_anterior  = nvl(can_dia_interes,0), 
              mto_dev_anterior  = nvl(mto_dev_actual,0),  
              can_dia_interes   = r_deven.fec_ult_devengado - fec_inicio +1,
              mto_dev_actual    = nvl(mto_dev_actual,0) + nvl(r_deven.mto_dev_actual,0),
              mto_ajuste        = nvl(mto_ajuste,0) + nvl(r_deven.mto_ajuste,0),
              mto_dev_acumulado = nvl(mto_dev_acumulado,0) + nvl(r_deven.mto_dev_actual,0),
              fecha             = r_deven.fecha,
              fec_ult_devengado = r_deven.fec_ult_devengado
        where nro_cuenta = r_deven.nro_cuenta
          and nro_cuota  = r_deven.nro_cuota
          and tipo       = r_deven.tipo
          and cod_moneda = r_deven.cod_moneda
          and estado     = r_deven.estado
          and categoria  = nvl(r_deven.categoria,1)
          and capital    = r_deven.capital
          and val_tasa   = r_deven.val_tasa;
    EXCEPTION
       WHEN no_data_found THEN
          INSERT INTO cb_sim_dev_prestamos(nro_cuenta, nro_cuota, tipo, fecha, fec_inicio, fec_ult_devengado, cod_moneda,
                                           estado, categoria, capital, val_tasa, can_dia_interes, mto_dev_anterior, can_dia_anterior,
                                           mto_dev_actual, mto_ajuste, mto_dev_acumulado)
               VALUES (r_deven.nro_cuenta, r_deven.nro_cuota, r_deven.tipo, r_deven.fecha, r_deven.fec_inicio, r_deven.fec_ult_devengado, r_deven.cod_moneda,
                       r_deven.estado, nvl(r_deven.categoria,1), r_deven.capital, r_deven.val_tasa, r_deven.can_dia_interes, nvl(r_deven.mto_dev_anterior,0), r_deven.can_dia_anterior,
                       r_deven.mto_dev_actual, r_deven.mto_ajuste, nvl(r_deven.mto_dev_anterior,0)+nvl(r_deven.mto_dev_acumulado,0));
       WHEN OTHERS THEN
          IF SQLCODE = -54 THEN
             raise_application_error(-20000,'Reg. de Devengado Cta. '||r_deven.nro_cuenta||' bloqueado por otro usuario');
          END IF;
          IF SQLCODE <= -20000 THEN
             RAISE;
          ELSE
             RAISE_APPLICATION_ERROR(-20000,SQLERRM||'Actu. PR_DEVENGADOS cta '||r_deven.nro_cuenta );
          END IF;
    END;

-- Proceso Principal.
BEGIN
   PAG_CAL.PR_OBT_DAT_CALENDAR(2);
   v_fec_sist     := p_fecha;
   ultdiam        := PAG_CAL.G_ULT_DIA_MES;
   v_mone_local   := PAG_GEN.FU_OBT_MON_LOCAL;
   v_mone_fuerte  := PAG_GEN.FU_OBT_MON_FUERTE;
   v_cotiz_fuerte := PAG_GEN.FU_OBT_COTIZACION(v_mone_fuerte,v_fec_sist);
   -- Determina la fecha de devengamiento.
   v_fec_fin      := ultdiam;
   
   OPEN c_prestamos;
   LOOP
    FETCH c_prestamos BULK COLLECT INTO reg LIMIT 3000;
    FOR i in 1.. reg.count LOOP

      --- totales por cada prestamo situacion cartera
      v_nro_cuenta    := reg(i).nro_cuenta;
      v_estado        := reg(i).estado;
      v_moneda        := reg(i).cod_moneda;
      v_fec_ult_dev   := reg(i).fec_ult_dev;
      v_devengo       := 'N';

      -- Determina la fecha de fin del devengamiento.
      v_fec_fin       := ultdiam;
      
      -- Inserto los registros.
      -- Inserto el historico del devengado.
      IF pag_cal.fu_obt_fec_sig_hab(v_fec_sist,1) <= v_fec_fin THEN
         IF (pag_cal.fu_obt_fec_sig_hab(v_fec_sist,1) - v_fec_sist) <> 1 THEN 
            BEGIN
               INSERT INTO cb_sim_dev_prestamos(nro_cuenta, 
                                                fec_inicio, 
                                                val_tasa, 
                                                mto_dev_anterior, 
                                                mto_dev_actual, 
                                                capital, 
                                                nro_cuota, 
                                                tipo, 
                                                fecha, 
                                                fec_ult_devengado, 
                                                cod_moneda, 
                                                estado, 
                                                categoria, 
                                                can_dia_interes, 
                                                can_dia_anterior, 
                                                mto_ajuste, 
                                                mto_dev_acumulado)
                    SELECT nro_cuenta, 
                           fec_inicio, 
                           val_tasa, 
                           mto_dev_anterior, 
                           mto_dev_actual, 
                           capital, 
                           nro_cuota, 
                           tipo, 
                           fecha, 
                           fec_ult_devengado, 
                           cod_moneda, 
                           estado, 
                           categoria, 
                           can_dia_interes, 
                           can_dia_anterior, 
                           mto_ajuste, 
                           mto_dev_acumulado
                      FROM pr_devengados m 
                     WHERE m.nro_cuenta = v_nro_cuenta
                       AND m.fecha > NVL(reg(i).fec_ult_dev,reg(i).fec_inicio);
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
         END IF;            
      END IF;
      --
      IF v_moneda != v_mone_local THEN
         if v_moneda = v_mone_fuerte then
            v_cotizacion := v_cotiz_fuerte;
         else
            v_cotizacion := PAG_GEN.FU_OBT_COTIZACION(v_moneda,v_fec_sist);
         end if;
      END IF;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg(i).cod_modulo, reg(i).cod_modalidad, reg(i).cod_moneda, reg(i).cod_oficina);
      v_categoria := nvl(reg(i).categoria,1);
      IF reg(i).fec_ult_dev  IS NULL THEN
         v_fec_ini := reg(i).fec_inicio;
         v_fec_ult_dev := reg(i).fec_inicio;
      ELSIF reg(i).fec_ult_dev >= reg(i).fec_inicio THEN
         v_fec_ini := reg(i).fec_ult_dev + 1;
      END IF;
      IF v_fec_fin >= reg(i).fec_vencimiento THEN --si ya esta vencido o vence hoy el prestamo,se devenga hasta el vto
         v_fec_fin := reg(i).fec_vencimiento - 1;
      END IF;
      v_tasa := reg(i).val_tasa;
      --- Inicializar variables de calculo
      v_tot_suspenso   := 0;
      v_tot_no_cobrado := 0;
      FOR cuo in c_cuotas LOOP
         v_interes          := 0;
         v_dev_no_cobrado   := 0;
         v_dev_suspenso     := 0;
         v_mto_ajuste       := 0;
         v_val_int_devengar := 0;
         v_int_devengar     := 0;
         v_int_cobrado      := 0;
         v_no_cobrado       := 0;
         v_suspenso         := 0;
         v_acumulado        := 0;
         v_mto_interes      := 0;
         v_sal_interes      := 0;
         r_deven            := null;
         v_fec_fin_dev      := v_fec_fin;
         v_acu_devengado    := cuo.acu_devengado; --RABP-CNF-02-01-2015: Variable que indica si se debe acumular el devengado en pr_ins_pr_devengados
         v_dev_ant_can_par  := 0; /*dydmr2003 fm 09/07/2015*/ -- SC 12793 / EP 2015-06 - N.AN. almacena devengado acumulado antes de cancelacion parcial de capital

         if reg(i).tip_interes = 'V' then
            --- Para prestamos vencidos recorrer cuotas cuya fecha de
            --- inicio de devengado ha transcurrido
            v_fec_ini_dev := nvl(PAP_DEV.FU_OBT_FEC_INI_CUOTA(reg(i).nro_cuenta, cuo.nro_cuota),reg(i).fec_inicio);
            IF reg(i).fec_inicio < to_date('09082010','ddmmyyyy') AND -- Modificado por ICL por diferencia en Utilidad de Agosto/2010
               reg(i).nro_cuenta not in ('210223610','090070307','120005510','110035607','080001907','100068209','080038107','120057406','030003908','080052810','210223310') then
               v_fec_ini_dev_aux := nvl(FUB_OBT_FEC_INI_DEV_AS400(reg(i).nro_cuenta, cuo.nro_cuota),reg(i).fec_inicio);
               IF v_fec_ini_dev > v_fec_ini_dev_aux THEN
                  --- Plan de pago incorrecto en AS400
                  v_fec_ini_dev := v_fec_ini_dev_aux;
               END IF;
            END IF;

            if v_fec_ini_dev > v_fec_ini then
               exit;
            end if;
         else
            v_fec_ini_dev := reg(i).fec_inicio;
         end if;

         --- Recuperar capital segun el tipo de prestamo
         if reg(i).tip_interes = 'A' then
            v_capital := nvl(cuo.mto_capital,0) + nvl(cuo.mto_int_documentado,0) - nvl(cuo.mto_cap_adelantado,0);
         else
            v_capital := PAP_INT.FU_OBT_CAPITAL_ACUMU(v_fec_ini_dev, reg(i).nro_cuenta);
         end if;
         if cuo.fec_vencimiento < v_fec_fin_dev + 1 then
            v_fec_fin_dev := cuo.fec_vencimiento - 1; --- Hasta el vencimiento de la cuota
         end if;

         -- SC 12793 / EP 2015-06 - N.AN. Recupera dev anterior acancelacion parcial en caso que exista para la cuota
         -- si hay mas de un registro para la cuota se toma el ultimo, el de mayor fecha, que no este reversado
         /*DYDMR-2003 FM 08/07/2015*/
         v_dev_ant_can_par := 0;         

         --- Calcular Interes devengado desde la fecha de inicio de devengado de la cuota
         v_interes := PAP_DEV.FU_CAL_INTERES(v_fec_ini_dev, v_fec_fin_dev, v_capital,
                                             reg(i).nro_solicitud, v_tasa,
                                             cuo.nro_cuenta, cuo.nro_cuota );
                                             --- Se agregó nro de cuenta y cuota para calculo de tasas variables

         v_interes := round(v_interes, v_redondeo);
         --- Calcular el devengado por diferencia del acumulado a la fecha de fin
         --- /*dydmr 2003 fm 09/07/2015 */SC 12793 / EP 2015-06 - N.AN. suma el dev acumulado anterior a cancelacion parcial para evitar dar devengado negativo
         v_interes := nvl(v_interes,0) - nvl(cuo.dev_acumulado,0) + nvl(v_dev_ant_can_par,0);
         --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
         if cuo.fec_vencimiento = v_fec_fin_dev + 1 then
            if nvl(v_interes,0) + nvl(cuo.dev_acumulado,0) <>
               nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0)- nvl(cuo.mto_int_descontado,0) then
               v_mto_ajuste := v_interes - (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0)- nvl(cuo.mto_int_descontado,0) - nvl(cuo.dev_acumulado,0));
               v_interes    := (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0)- nvl(cuo.mto_int_descontado,0) - nvl(cuo.dev_acumulado,0));
            end if;
         end if;

         --- Verificar que no quede en negativo el val_int_devengar
         ---  /*dydmr 2003 fm 09/07/2015 */ SC 12793 / EP 2015-06 - N.AN. incluye en calculos el dev acumulado anterior a cancelacion parcial
         if (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0) - nvl(cuo.mto_int_descontado,0))
            < (nvl(cuo.dev_acumulado,0) + nvl(v_interes,0) - nvl(v_dev_ant_can_par,0)) then
            v_mto_ajuste := v_interes;
            v_interes :=  (nvl(cuo.mto_interes,0) + nvl(cuo.mto_int_documentado,0) - nvl(cuo.mto_int_descontado,0))
                          - nvl(cuo.dev_acumulado,0) + nvl(v_dev_ant_can_par,0);
            v_mto_ajuste := v_mto_ajuste - v_interes;
         end if;

         --- Verificar si debe actualizar el suspenso o no cobrado
         IF v_estado IN ('A','C') AND v_categoria IN (1,2) THEN /* solo los est 'A' y 'C' y categ 1 y 2*/
            v_dev_no_cobrado := v_interes;
            v_tot_no_cobrado := v_tot_no_cobrado + v_dev_no_cobrado;
            r_deven.tipo     := 'N';
         else
            v_dev_suspenso   := v_interes;
            v_tot_suspenso   := v_tot_suspenso + v_dev_suspenso;
            r_deven.tipo     := 'S';
         end if;

         --- Insertar devengados
         r_deven.nro_cuenta        := v_nro_cuenta;
         r_deven.nro_cuota         := cuo.nro_cuota;
         r_deven.fecha             := v_fec_sist;
         r_deven.fec_inicio        := v_fec_ini_dev;
         r_deven.fec_ult_devengado := v_fec_fin_dev;
         r_deven.cod_moneda        := reg(i).cod_moneda;
         r_deven.estado            := reg(i).estado;
         r_deven.categoria         := reg(i).categoria;
         r_deven.capital           := v_capital;
         r_deven.val_tasa          := reg(i).val_tasa;
         r_deven.can_dia_interes   := v_fec_fin_dev - v_fec_ini + 1;
         r_deven.mto_dev_actual    := v_interes;
         r_deven.mto_ajuste        := v_mto_ajuste;
         r_deven.mto_dev_acumulado := v_interes;
         --- Para casos en que no exista el registro y sea la primera vez
         r_deven.mto_dev_anterior  := cuo.dev_acumulado - nvl(v_dev_ant_can_par,0);
         pr_ins_pr_devengados;
         v_devengo := 'S';
      END LOOP;    
     END LOOP;
     EXIT WHEN c_prestamos%NOTFOUND;
   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,'Cuenta : '||v_nro_cuenta||' - '||SQLERRM);
      end if;
END;

/* Calcula el Devengado de Mesa de Dinero. */
PROCEDURE PR_PRO_DEV_MESA(p_fecha in ge_calendarios.fec_actual%type)
 IS
   -- variables globales.   
   v_moneda          varchar2(3);
   v_fec_sist        date;
   v_estado          md_cta_documentos.estado%type;
   r_deven           cb_sim_dev_mesa%rowtype;
   -- variables.
   v_mone_local      ba_monedas.cod_moneda%type;
   v_mone_fuerte     ba_monedas.cod_moneda%type;
   v_cotizacion      ge_cotizaciones.val_conversion%type;
   v_interes         pr_cuotas.mto_interes%type;
   v_capital         pr_cuotas.mto_capital%type;
   v_tasa            md_cta_documentos.val_tasa%type;
   v_nro_cuenta      pr_cta_prestamos.nro_cuenta%type;
   v_cotiz_fuerte    ge_cotizaciones.val_venta%type;
   v_dev_acumulado   cb_sim_dev_mesa.mto_dev_acumulado%type;
   v_dia_devengado   cb_sim_dev_mesa.can_dia_interes%type;
   v_dev_suspenso    pr_cuotas.dev_suspenso%type;
   v_dev_no_cobrado  pr_cuotas.dev_no_cobrado%type;
   v_mto_ajuste      cb_sim_dev_mesa.mto_ajuste%type;
   v_fec_ini_dev     cb_sim_dev_mesa.fec_inicio%type;
   v_fec_fin_dev     cb_sim_dev_mesa.fec_inicio%type;
   v_dia_dev_cuota   number;
   v_redondeo        number(1);
   v_fec_ini         date;
   v_fec_fin         date;
   v_fec_ult_dev     date;
   ultdiam           date;
   v_existe          varchar2(1);
   --- Definicion del cursor de documentos vigentes a procesar
   cursor c_documentos IS
   SELECT distinct a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.monto,
          a.val_int_devengar, val_tasa, fec_inicio, fec_vencimiento, o.estado,
          sal_interes, cod_moneda, NVL(fec_ult_devengado, NULL) fec_ult_devengado,
          c.cod_gru_economico, fup_obt_categoria(c.cat_automatica,c.cat_subjetiva) categoria,
          tip_calculo, a.val_presente,a.sal_val_presente, a.mto_interes, a.dev_acumulado,
          a.dia_ano, a.tot_int_descontado, a.sal_capital, NVL(a.sal_disponible,0) sal_disponible, o.nro_cuota, o.nro_cta_repo
     FROM ge_clientes c, ge_cta_clientes b, md_cta_documentos a, md_cuo_instrumentos o
    WHERE c.cod_persona = b.cod_persona
      and b.nro_cuenta  = a.nro_cuenta
      and a.nro_cuenta = o.nro_cuenta
      and b.relacion    = 'P'
      and o.estado not in ('S','N')  --- No incluir Canceladas
      and a.cod_modalidad <> 113 --crédito tributario no devenga
      --- Que no tome cuentas vencidas aunque no halla devengado todo
      and (a.cod_modalidad in (105,109,110) -- Desarrollo Interno del banco
       or FUM_OBT_OPE_REPO(a.cod_modulo,a.cod_modalidad,'S') = 'S' -- Repo Fase II / 04-2016
       or a.fec_vencimiento > decode(v_fec_sist,v_fec_fin,v_fec_sist,(v_fec_fin - 1))
       or (a.fec_vencimiento > a.fec_ult_devengado and a.val_int_devengar <> 0)) -- JIRA-1080
      --- No debe devengar las cuentas canceladas por adelantado
      and nvl(a.fec_ult_devengado,a.fec_inicio-1) < v_fec_fin
      and a.fec_inicio <= v_fec_sist
      and (nvl(a.sal_interes,0) > 0 or a.cod_modalidad in (109,110) or FUM_OBT_OPE_REPO(a.cod_modulo,a.cod_modalidad,'S') = 'S') -- CNFREINT-104 --
      --- Cuando devenga de mas tambien debe incluir
      and (nvl(dev_acumulado,0) <> nvl(a.mto_interes,0) or a.cod_modalidad in (109,110) or FUM_OBT_OPE_REPO(a.cod_modulo,a.cod_modalidad,'S') = 'S')
	  Order By a.nro_cuenta, o.estado, o.nro_cuota, o.nro_cta_repo Asc;

    cursor cuotas is
        select  nro_cuota, mto_interes, sal_interes, fec_vencimiento,plazo, dev_acumulado,
        mto_int_descontado, estado
          from md_doc_detalles
         where nro_cuenta = v_nro_cuenta
           and (estado != 'N' or(fec_ult_pago < fec_vencimiento) )
           and ((fec_vencimiento > V_FEC_FIN
           and fec_vencimiento - plazo  <= v_fec_sist) or estado = 'N' and fec_vencimiento >= V_FEC_FIN)
           and nvl(dev_acumulado,0) < mto_interes;
    
    -- Procedimientos Internos.
    procedure lp_obt_mto_devengar(p_nro_cuenta         in md_cuo_instrumentos.nro_cuenta%type, 
                                  p_est_cuota          in md_cuo_instrumentos.estado%type,
                                  p_nro_cuota          in md_cuo_instrumentos.nro_cuota%type,
                                  p_sal_disponible     in md_cta_documentos.sal_disponible%type,         
                                  p_monto              in out md_cta_documentos.monto%type, 
                                  p_val_int_devengar   in out md_cta_documentos.val_int_devengar%type,  
                                  p_sal_interes        in out md_cta_documentos.sal_interes%type,
                                  p_val_presente       in out md_cta_documentos.val_presente%type, 
                                  p_sal_val_presente   in out md_cta_documentos.sal_val_presente%type, 
                                  p_mto_interes        in out md_cta_documentos.mto_interes%type,
                                  p_dev_acumulado      in out md_cta_documentos.dev_acumulado%type, 
                                  p_tot_int_descontado in out md_cta_documentos.tot_int_descontado%type, 
                                  p_sal_capital        in out md_cta_documentos.sal_capital%type)
                                  is
       -- Veriables.   
       v_porcentaje     number;
       v_redondeo       number;
       v_mto_documento  md_cta_documentos.monto%type;
       v_mto_cuota      md_cuo_instrumentos.mto_cuota%type;
       v_cod_modulo     md_cta_documentos.cod_modulo%type;
       v_cod_modalidad  md_cta_documentos.cod_modalidad%type;
       v_cod_moneda     md_cta_documentos.cod_moneda%type;
       v_cod_oficina    md_cta_documentos.cod_oficina%type;

       BEGIN

          select d.monto,d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.cod_oficina, sum(c.mto_cuota)
            into v_mto_documento, v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_mto_cuota
            from md_cta_documentos d, md_cuo_instrumentos c
           where d.nro_cuenta = c.nro_cuenta
             and d.nro_cuenta = p_nro_cuenta
             and c.estado = p_est_cuota
           group by d.monto,d.cod_modulo, d.cod_modalidad, d.cod_moneda, d.cod_oficina;
    
          -- Como un Repo Otorgado tiene los mismos estados que una cuenta normal
          -- el monto a tomar en este tipo de repo es el de la negociacion y no 
          -- el saldo disponible como en los demas casos.    
          If fum_obt_ope_repo(v_cod_modulo,v_cod_modalidad,'S','O') = 'N' And p_est_cuota = 'C' And p_nro_cuota = 1 Then
             v_mto_cuota := p_sal_disponible;
          End If;
      
          v_porcentaje := (v_mto_cuota * 100 / v_mto_documento);
     
          v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 
                                              v_cod_modulo, 
                                              v_cod_modalidad, 
                                              v_cod_moneda, 
                                              v_cod_oficina );

          If v_porcentaje is not null then 
             v_porcentaje := v_porcentaje / 100;

             p_monto               :=   round((p_monto * v_porcentaje),v_redondeo);
             p_val_int_devengar    :=   round(p_val_int_devengar * v_porcentaje,v_redondeo);
             p_sal_interes         :=   round(p_sal_interes * v_porcentaje,v_redondeo);
             p_val_presente        :=   round(p_val_presente * v_porcentaje,v_redondeo);
             p_sal_val_presente    :=   round(p_sal_val_presente * v_porcentaje,v_redondeo);
             p_mto_interes         :=   round(p_mto_interes * v_porcentaje,v_redondeo);
             p_dev_acumulado       :=   round(p_dev_acumulado * v_porcentaje,v_redondeo);
             p_tot_int_descontado  :=   round(p_tot_int_descontado * v_porcentaje,v_redondeo);
             p_sal_capital         :=   round(p_sal_capital * v_porcentaje,v_redondeo);
          End if;
  
       EXCEPTION
          WHEN NO_DATA_FOUND THEN
             NULL;
       END;  

       -- Inserta en la tabla.
       PROCEDURE pr_ins_md_devengados IS
          -- Variables.
          v_rowid varchar2(100);
          v_can_dia_interes  cb_sim_dev_mesa.can_dia_interes%Type;
          v_can_dia_anterior cb_sim_dev_mesa.can_dia_anterior%Type;
       BEGIN
          IF r_deven.estado = 'C' THEN 
             select rowid 
               into v_rowid
               from cb_sim_dev_mesa
              where nro_cuenta = r_deven.nro_cuenta
                and cod_moneda = r_deven.cod_moneda
                and estado     = r_deven.estado
                and val_tasa   = r_deven.val_tasa
                and usu_insercion <> 'BBVA'; -- REPO: para no duplicar devengados migrados
        
             -- Actualizar el registro existente.
             update cb_sim_dev_mesa
                set can_dia_interes   = nvl(can_dia_interes,0) + r_deven.can_dia_interes,
                    mto_dev_actual    = nvl(mto_dev_actual,0) + nvl(r_deven.mto_dev_actual,0),
                    mto_ajuste        = nvl(mto_ajuste,0) + nvl(r_deven.mto_ajuste,0),
                    mto_dev_acumulado = nvl(mto_dev_acumulado,0) + nvl(r_deven.mto_dev_actual,0),
                    fecha             = r_deven.fecha,
                    fec_ult_devengado = r_deven.fec_ult_devengado,
                    capital           = nvl(r_deven.capital,0)
              where nro_cuenta = r_deven.nro_cuenta
                and cod_moneda = r_deven.cod_moneda
                and estado     = r_deven.estado
                and val_tasa   = r_deven.val_tasa
                and usu_insercion <> 'BBVA'; 
        
          ELSE ---CNFREINT-1 - REPO INTERBANCARIO
             select rowid 
               into v_rowid
               from cb_sim_dev_mesa
              where nro_cuenta = r_deven.nro_cuenta
                and cod_moneda = r_deven.cod_moneda
                and estado     = r_deven.estado
                and capital    = r_deven.capital 
                and val_tasa   = r_deven.val_tasa;
        
             -- Actualizar el registro existente.
             update cb_sim_dev_mesa
                set can_dia_interes   = nvl(can_dia_interes,0) + r_deven.can_dia_interes,
                    mto_dev_actual    = nvl(mto_dev_actual,0) + nvl(r_deven.mto_dev_actual,0),
                    mto_ajuste        = nvl(mto_ajuste,0) + nvl(r_deven.mto_ajuste,0),
                    mto_dev_acumulado = nvl(mto_dev_acumulado,0) + nvl(r_deven.mto_dev_actual,0),
                    fecha             = r_deven.fecha,
                    fec_ult_devengado = r_deven.fec_ult_devengado
              where nro_cuenta = r_deven.nro_cuenta
                and cod_moneda = r_deven.cod_moneda
                and estado     = r_deven.estado
                and capital    = r_deven.capital  
                and val_tasa   = r_deven.val_tasa;
                   
          END IF;

       EXCEPTION
          WHEN NO_DATA_FOUND THEN
             IF r_deven.estado = 'R' THEN
                BEGIN
                   select nvl(d.can_dia_interes,0), nvl(d.can_dia_anterior,0) 
                     into v_can_dia_interes, v_can_dia_anterior
                     from cb_sim_dev_mesa d
                    where d.nro_cuenta = r_deven.nro_cuenta
                      and d.cod_moneda = r_deven.cod_moneda
                      and d.estado     = 'C'
                      and d.val_tasa   = r_deven.val_tasa
                      and usu_insercion <> 'BBVA';
                EXCEPTION
                   WHEN OTHERS THEN
                      v_can_dia_interes := 0;
                      v_can_dia_anterior := 0;
                END;
	           END IF;
             --
             INSERT INTO cb_sim_dev_mesa(nro_cuenta,fecha,fec_inicio, fec_ult_devengado, cod_moneda,
                                         estado, capital, val_tasa,can_dia_interes, mto_dev_anterior, can_dia_anterior,
                                         mto_dev_actual, mto_ajuste, mto_dev_acumulado)
                  VALUES (r_deven.nro_cuenta, r_deven.fecha,r_deven.fec_inicio, r_deven.fec_ult_devengado,
                          r_deven.cod_moneda, r_deven.estado, r_deven.capital, r_deven.val_tasa,
                          DECODE(r_deven.estado,'R',v_can_dia_interes, NVL(r_deven.can_dia_interes,0)), 
                          DECODE(r_deven.estado,'R',0,nvl(r_deven.mto_dev_anterior,0)), 
                          DECODE(r_deven.estado,'R',v_can_dia_anterior, nvl(r_deven.can_dia_anterior,0)),
                          r_deven.mto_dev_actual, r_deven.mto_ajuste,
                          DECODE(r_deven.estado,'R',0,nvl(r_deven.mto_dev_anterior,0))+nvl(r_deven.mto_dev_acumulado,0));
          WHEN OTHERS THEN
             IF SQLCODE = -54 THEN
                raise_application_error(-20000,'Reg. de Devengado Cta. '||r_deven.nro_cuenta||' bloqueado por otro usuario');
             END IF;
             IF SQLCODE <= -20000 THEN
                RAISE;
             ELSE
                RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ACTU. CB_SIM_DEV_MESA CTA '||R_DEVEN.NRO_CUENTA );
             END IF;
          END;  
          --
          FUNCTION lf_obt_dia_devengado(p_ini_cuota in date,p_fin_cuota in date,p_fec_ini_dev in date,p_fec_fin_dev in date)
          RETURN NUMBER IS
             -- Variables.
             v_dias number := 0;
             v_inicio date;
             v_fin date;
          BEGIN
            IF p_ini_cuota > p_fec_ini_dev THEN
               v_inicio := p_ini_cuota;
            ELSE
               v_inicio := p_fec_ini_dev;
            END IF;
            IF p_fin_cuota < p_fec_fin_dev THEN
               v_fin := p_fin_cuota;
            ELSE
               v_fin := p_fec_fin_dev;
            END IF;
            v_dias := v_fin - v_inicio + 1;
            RETURN v_dias;
          END;
                
BEGIN
  --
  pag_cal.pr_obt_dat_calendar(2);
  v_fec_sist     := p_fecha;
  ultdiam        := pag_cal.g_ult_dia_mes;
  v_mone_local   := pag_gen.fu_obt_mon_local;
  v_mone_fuerte  := pag_gen.fu_obt_mon_fuerte;
  v_cotiz_fuerte := pag_gen.fu_obt_cotizacion(v_mone_fuerte,v_fec_sist);
  -- Asigno la fecha para el calculo del devengado.
  v_fec_fin      := ultdiam;

  FOR reg in c_documentos Loop
    
  --Se invoca al proceso que realice el calculo de los montos por porcentaje.
  lp_obt_mto_devengar(reg.nro_cuenta, 
                      reg.estado,
                      reg.nro_cuota,
                      reg.sal_disponible,        
                      reg.monto, 
                      reg.val_int_devengar,  
                      reg.sal_interes,
                      reg.val_presente, 
                      reg.sal_val_presente, 
                      reg.mto_interes,
                      reg.dev_acumulado, 
                      reg.tot_int_descontado, 
                      reg.sal_capital);
   --------------------------------------------------------------------------
    v_nro_cuenta    := reg.nro_cuenta;
    v_estado        := reg.estado;
    v_moneda        := reg.cod_moneda;
    v_fec_ult_dev   := reg.fec_ult_devengado;
    -- Asigno la fecha para el calculo del devengado.
    v_fec_fin       := ultdiam;
    --
    v_redondeo  := 0;
    IF v_moneda != v_mone_local THEN
      if v_moneda = v_mone_fuerte then
        v_cotizacion := v_cotiz_fuerte;
      else
        v_cotizacion := pag_gen.fu_obt_cotizacion(v_moneda,v_fec_sist);
      end if;
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', reg.cod_modulo, reg.cod_modalidad, reg.cod_moneda, reg.cod_oficina);
    END IF;
    --
    v_dev_acumulado := reg.dev_acumulado;
    v_fec_ini_dev := nvl(reg.fec_ult_devengado,reg.fec_inicio);
    --
    IF reg.fec_ult_devengado  IS NULL THEN
      v_fec_ini := reg.fec_inicio;
      v_fec_ult_dev := reg.fec_inicio;
    ELSIF reg.fec_ult_devengado >= reg.fec_inicio THEN
      v_fec_ini := reg.fec_ult_devengado + 1;
    END IF;

    IF v_fec_fin >= reg.fec_vencimiento and reg.cod_modalidad not in (109,110) THEN --si ya esta vencido o vence hoy el prestamo,se devenga hasta el vto
       v_fec_fin := reg.fec_vencimiento - 1;
    END IF;
    v_tasa := reg.val_tasa;
    --- Inicializar variables de calculo
    v_interes        := 0;
    v_dev_no_cobrado := 0;
    v_dev_suspenso   := 0;
    v_mto_ajuste     := 0;
    v_fec_fin_dev    := v_fec_fin;

    --- Recuperar capital segun el tipo de documento
    if reg.tip_calculo = 'A' then
      v_capital := nvl(reg.monto,0);
    else
      If reg.fec_vencimiento > v_fec_ini_dev And reg.estado <> 'N' Then
        v_capital := nvl(reg.val_presente,0);
      End If;
    end if;

    if reg.cod_modalidad in (109,110) then--Es VISTA y no tiene vencimiento
      v_dia_devengado   := v_fec_fin_dev - v_fec_ini + 1;
    else
      if reg.fec_vencimiento < v_fec_fin_dev + 1 then
        v_fec_fin_dev := reg.fec_vencimiento - 1; --- Hasta el vencimiento de la cuota
      end if;
      v_dia_devengado   := v_fec_fin_dev - v_fec_ini + 1;
    end if;

    if reg.cod_modalidad = 109 then
      v_interes := round(reg.sal_capital * reg.val_tasa * v_dia_devengado / (reg.dia_ano * 100),v_redondeo);
    elsif reg.cod_modalidad = 110 then
      v_interes := round(reg.sal_capital * reg.val_tasa * v_dia_devengado / (reg.dia_ano * 100),v_redondeo);
    elsif reg.cod_modalidad in (116,146) then
      v_interes := round(reg.sal_capital * reg.val_tasa * v_dia_devengado / (reg.dia_ano * 100),v_redondeo);
      --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
      if reg.fec_vencimiento = v_fec_fin_dev + 1  then
        if (nvl(v_interes,0) + nvl(v_dev_acumulado,0) <>
        nvl(reg.mto_interes,0) and
        nvl(reg.tot_int_descontado,0)=0) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
        end if;

        if (nvl(reg.tot_int_descontado,0) > 0 and
        nvl(v_interes,0) + nvl(v_dev_acumulado,0) <> nvl(reg.mto_interes,0)-nvl(reg.tot_int_descontado,0)) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := nvl(reg.sal_interes,0);
        end if;
      end if;
    elsif reg.cod_modalidad in (120,122,123,124) then
      v_interes := 0;
      v_dia_dev_cuota := 0;
      for ct in cuotas loop
        -- veo si se devenga por cuotas
        v_interes := nvl(v_interes,0)+
        round((ct.sal_interes/ct.plazo) *
        lf_obt_dia_devengado(ct.fec_vencimiento-ct.plazo,ct.fec_vencimiento,v_fec_ini,v_fec_fin_dev),v_redondeo);
      end loop;
      if v_interes = 0 then
        v_interes := round(reg.mto_interes / (reg.fec_vencimiento - reg.fec_inicio),v_redondeo) * v_dia_devengado;
      end if;

      --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
      if reg.fec_vencimiento = v_fec_fin_dev + 1  then
        if (nvl(v_interes,0) + nvl(v_dev_acumulado,0) <>
        nvl(reg.mto_interes,0) and
        nvl(reg.tot_int_descontado,0)=0) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
        end if;

        if (nvl(reg.tot_int_descontado,0) > 0 and
        nvl(v_interes,0) + nvl(v_dev_acumulado,0) <> nvl(reg.mto_interes,0)-nvl(reg.tot_int_descontado,0)) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := nvl(reg.sal_interes,0);
        end if;
      end if;

      --- Verificar que no quede en negativo el val_int_devengar
      if nvl(reg.mto_interes,0) < (nvl(v_dev_acumulado,0) + nvl(v_interes,0)) then
        v_mto_ajuste := v_interes;
        v_interes :=  (nvl(reg.mto_interes,0))- nvl(v_dev_acumulado,0);
        v_mto_ajuste := v_mto_ajuste - v_interes;
      end if;

    else
      v_interes := 0;
      v_dia_dev_cuota := 0;
      for ct in cuotas loop
        -- veo si se devenga por cuotas
        --Si la cuota fue pagada antes del vencimiento debe devengar hasta el vencimiento FQ-SPI 3124
        if ct.estado = 'N'  then
           v_fec_fin_dev := ct.fec_vencimiento;
        end if;
        
        v_interes := nvl(v_interes,0)+
        round((ct.mto_interes/ct.plazo) *
        lf_obt_dia_devengado(ct.fec_vencimiento-ct.plazo,ct.fec_vencimiento,v_fec_ini,v_fec_fin_dev),v_redondeo);
        
         if ct.fec_vencimiento = v_fec_fin_dev + 1 then
            if nvl(v_interes,0) + nvl(ct.dev_acumulado,0) <>
               nvl(ct.mto_interes,0) - nvl(ct.mto_int_descontado,0) then
               v_mto_ajuste := v_interes - (nvl(ct.mto_interes,0) - nvl(ct.mto_int_descontado,0) - nvl(ct.dev_acumulado,0));
               v_interes    := (nvl(ct.mto_interes,0) - nvl(ct.mto_int_descontado,0) - nvl(ct.dev_acumulado,0));
            end if;
         end if;
            
     end loop;
      
      --Verifico que no sea cuentas con cuotas para calcular el interes
      begin
         select distinct 'S'
           into v_existe
           from md_doc_detalles 
          where nro_cuenta = reg.nro_cuenta;
      exception
         when no_data_found then
            v_existe:= 'N';
         when others then
            v_existe:= 'N';
      end;
       
      if nvl(v_interes,0) = 0 and v_existe = 'N' then
        v_interes := round(reg.mto_interes / (reg.fec_vencimiento - reg.fec_inicio),v_redondeo) * v_dia_devengado;
      end if;
      
      --- Realizar Ajuste de los montos devengados de la cuota si la misma esta por vencer
      if reg.fec_vencimiento = v_fec_fin_dev + 1  then
        if (nvl(v_interes,0) + nvl(v_dev_acumulado,0) <>
        nvl(reg.mto_interes,0) and
        nvl(reg.tot_int_descontado,0)=0) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
        end if;

        if (nvl(reg.tot_int_descontado,0) > 0 and
        nvl(v_interes,0) + nvl(v_dev_acumulado,0) <> nvl(reg.mto_interes,0)-nvl(reg.tot_int_descontado,0)) then
          v_mto_ajuste := v_interes - (nvl(reg.mto_interes,0) - nvl(v_dev_acumulado,0));
          v_interes    := nvl(reg.sal_interes,0);
        end if;
      end if;

      --- Verificar que no quede en negativo el val_int_devengar
      if nvl(reg.mto_interes,0) < (nvl(v_dev_acumulado,0) + nvl(v_interes,0)) then
        v_mto_ajuste := v_interes;
        v_interes :=  (nvl(reg.mto_interes,0))- nvl(v_dev_acumulado,0);
        v_mto_ajuste := v_mto_ajuste - v_interes;
      end if;

    end if;
          
      --- Insertar devengados
      r_deven.nro_cuenta        := v_nro_cuenta;
      r_deven.fecha             := v_fec_sist;
      r_deven.fec_inicio        := v_fec_ini_dev;
      r_deven.fec_ult_devengado := v_fec_fin_dev;
      r_deven.cod_moneda        := reg.cod_moneda;
      r_deven.estado            := reg.estado;
      r_deven.capital           := nvl(reg.monto,0);
      r_deven.val_tasa          := reg.val_tasa;
      r_deven.can_dia_interes   := nvl(v_dia_devengado,0);
      r_deven.mto_dev_actual    := v_interes;
      r_deven.mto_ajuste        := v_mto_ajuste;
      r_deven.mto_dev_acumulado := v_interes;
      --- Para casos en que no exista el registro y sea la primera vez
      r_deven.mto_dev_anterior  := v_dev_acumulado;
      pr_ins_md_devengados;
 END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         RAISE_APPLICATION_ERROR(-20000,SQLERRM);
      end if;
END;

/* Calcula el comision por Bajo Promedio Ahorro. */
PROCEDURE PR_DEB_SAL_MIN_AHORRO(p_fecha in ge_calendarios.fec_actual%type)
IS

-- Variables.
v_encontro               char(1);
v_imp_debito             number(18, 2) := 0;
v_se_puede               varchar2(1);
v_pendiente              varchar2(1);
v_estado                 cb_sim_movimientos.estado%type;
v_concepto               cb_sim_movimientos.concepto%type;
v_nro_secuencia          cb_sim_movimientos.nro_secuencia%type;
v_sal_parametro          number(18, 2) := 0;
v_tipo                   ge_tasas.tipo%type;
v_iva                    number(18, 2) := 0;
v_nro_cuenta             ah_cta_vistas.nro_cuenta%type;
v_tas_personalizada      ah_cta_vistas.tas_personalizada%type;
v_cod_moneda             ah_cta_vistas.cod_moneda%type;
v_cod_modulo             ge_calendarios.cod_modulo%type;
v_exi_tra_prohibida      char(1);
v_cod_tasa_ah            ah_cta_vistas.cod_tasa%type;
v_est_movimiento         cb_sim_movimientos.estado%type;
v_cod_modalidad          ah_cta_vistas.cod_modalidad%type;
v_cod_oficina            ah_cta_vistas.cod_oficina%type;
v_cod_transaccion        cb_sim_movimientos.cod_transaccion%type;
v_tip_valor              ge_tasas.tip_valor%type;
r_gmovi                  cb_sim_movimientos%rowtype;
v_cod_ente               ge_entes.cod_ente%type;
v_db_empre               char(1) := 'N';
v_cod_usuario            varchar2(10);
v_fec_vigencia           ge_tas_fechas.fec_vigencia%type;
v_val_tas_global         ge_tas_fechas.val_tasa%type;
v_fec_final              ge_tas_fechas.fec_vigencia%type;
v_fecha                  cb_sim_movimientos.fecha%type;
v_hora                   cb_sim_movimientos.hora%type;
v_existe                 char(1);
v_debita                 char(1);
v_cta_db_sueldo          varchar2(15);
v_msj_error              varchar2(1000);
v_cod_tasa               ah_cta_vistas.cod_tasa%type;
v_val_tasa               ge_tas_fechas.val_tasa%type;
v_monto                  number(18, 2) := 0;
v_cod_tasa2              ah_cta_vistas.cod_tasa%type;
v_val_tasa2              ge_tas_fechas.val_tasa%type;
v_mes_actual             ah_sal_mensuales.mes%type;
v_anio_actual            ah_sal_mensuales.ano%type;
v_tra_prohibida          ah_cta_vistas.tra_prohibida%type;
v_pag_sueldo             char(1) := 'N';
v_mto_cargo              number(18, 2) := 0;
v_mto_cargo2             number(18, 2) := 0;
v_ini_mtocargo           number := 0;
v_sal_promedio           number(18, 2) := 0;
v_sal_minimo             ah_cta_vistas.sal_minimo%type;
v_sal_disponible         ah_cta_vistas.sal_total%type;
v_cod_persona            ge_cta_clientes.cod_persona%type;
v_nro_documento          cb_sim_movimientos.nro_documento%type := 0;
v_redondeo               number(4) := 0;
v_cotizacion             number;
v_tot_deb_gs             number(18);
v_mto_car_gs             number(18);
v_mto_iva_gs             number(18);
v_cod_sub_modalidad      ah_cta_vistas.cod_sub_modalidad%type;
v_ent_cta                ge_entes.cod_ente%type;
v_paquete                number := 0;
v_cod_mon_local          ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;

/* Verifica y devuelve el saldo promedio. */
PROCEDURE LP_VER_SAL_PROMEDIO
 (P_NRO_CUENTA IN AH_SAL_MENSUALES.NRO_CUENTA%TYPE
 ,P_ANIO_ACTUAL IN AH_SAL_MENSUALES.ANO%TYPE
 ,P_MES_ACTUAL IN AH_SAL_MENSUALES.MES%TYPE
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_ENCONTRO IN OUT CHAR
 );
 
/* Verifica si una cta. dada es cta. de débito en prestamos o tarjetas. */
PROCEDURE LP_VER_CTA_DEBITO
 (P_NRO_CUENTA IN VARCHAR2
 ,P_EXISTE IN OUT CHAR
 );

-- Cursores.
CURSOR aho IS
           SELECT NRO_CUENTA, COD_MONEDA,
                  0, 'N', COD_ENTE
             FROM AH_CTA_VISTAS A
            WHERE ESTADO NOT IN ('C','P','A','T','D','X')
              AND FEC_APERTURA < v_fecha
              AND CTA_COMBINADA = 'N'         
            ORDER BY 1,2,4;

-- Procedimientos Internos.
/* Verifica y devuelve el saldo promedio. */
PROCEDURE LP_VER_SAL_PROMEDIO
 (P_NRO_CUENTA IN AH_SAL_MENSUALES.NRO_CUENTA%TYPE
 ,P_ANIO_ACTUAL IN AH_SAL_MENSUALES.ANO%TYPE
 ,P_MES_ACTUAL IN AH_SAL_MENSUALES.MES%TYPE
 ,P_SAL_PROMEDIO IN OUT NUMBER
 ,P_ENCONTRO IN OUT CHAR
 )
 IS
BEGIN
  p_encontro := 'S';
  SELECT round(NVL(SAL_ACU_DIARIO,0)/CAN_DIA_ACUMULADO,0)
    INTO p_sal_promedio
    FROM AH_SAL_MENSUALES
   WHERE NRO_CUENTA = p_nro_cuenta
     AND ANO = p_anio_actual
     AND MES = p_mes_actual
     AND NVL(CAN_DIA_ACUMULADO,0) <> 0;
EXCEPTION
     WHEN NO_DATA_FOUND THEN
       p_sal_promedio := 0;
       p_encontro := 'N';
END;
/* Verifica si una cta. dada es cta. de débito en prestamos o tarjetas. */
PROCEDURE LP_VER_CTA_DEBITO
 (P_NRO_CUENTA IN VARCHAR2
 ,P_EXISTE IN OUT CHAR
 )
 IS

V_CANTIDAD NUMBER(9) := 0;
BEGIN
    SELECT NVL(COUNT(*),0) INTO v_cantidad
      FROM PR_CTA_PRESTAMOS
     WHERE NRO_CTA_DEBITO = p_nro_cuenta
       AND ESTADO <> 'N'
       AND COB_AUTOMATICO = 'S'
       AND ROWNUM = 1;
    IF NVL(v_cantidad,0) = 0 THEN
       SELECT NVL(COUNT(*),0) INTO v_cantidad
         FROM TA_CTA_TARJETAS
        WHERE NRO_CTA_DEBITO = p_nro_cuenta
          AND ESTADO <> 'C'
          AND NVL(DEB_AUTOMATICO,'N') = 'S'
          AND ROWNUM = 1;
    END IF;
    IF NVL(v_cantidad,0) > 0 THEN
       p_existe := 'S';
    ELSE
       p_existe := 'N';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001,SQLERRM||' Cta.: '||p_nro_cuenta||' '
      ||'LP_VER_CTA_DEBITO');
END;
/* Obtiene el tipo de persona. */
FUNCTION FU_OBT_TIP_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2 IS
v_tip_persona varchar2(1); 
BEGIN
     SELECT TIPO
       INTO v_tip_persona
       FROM BA_PERSONAS
      WHERE COD_PERSONA = P_COD_PERSONA;
     return v_tip_persona; 
EXCEPTION
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR (-20000,'Error al traer tipo de persona : '||p_cod_persona||' - '||sqlerrm);
END;

-- Proceso Principal.
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   v_cod_modulo    := 3; -- Modulo de Ahorro
   v_fecha         := p_fecha;
   v_hora          := fu_ini_hora(v_fecha);
   v_nro_secuencia := 0;
   v_anio_actual   := to_char(v_fecha,'YYYY');
   v_mes_actual    := to_char(v_fecha,'MM');
   v_cod_usuario   := user;
   v_encontro      := 'S';
   --cursor por cuenta de ahorro
   IF aho%ISOPEN THEN
      CLOSE aho;
   END IF;
   OPEN aho;
   LOOP
      FETCH aho INTO v_nro_cuenta, v_cod_moneda, v_iva, v_existe, v_ent_cta;
      EXIT WHEN aho%NOTFOUND;
      v_msj_error := null; /* Indic. si el mov.tiene o no error */
      V_SAL_PARAMETRO := 0;
      if v_nro_secuencia > 990 then
         v_hora          := fu_ini_hora(v_fecha);
         v_nro_secuencia := 0;
      end if;
      PAG_CTA.PR_OBT_CUENTA(v_nro_cuenta);
      if pag_cta.fu_obt_cod_error() <> 0 then
         v_msj_error := 'Cta.'||v_nro_cuenta||'-'||pag_cta.g_cod_error||'-'||pag_cta.g_msj_error;
      end if;
      v_estado       := pag_cta.g_ctas.estado;
      v_cod_oficina  := pag_cta.g_ctas.cod_oficina;
      v_db_empre     := 'N';
      v_cta_db_sueldo := NULL;
      v_sal_promedio := 0;
      v_monto        := 0;
      v_mto_cargo    := 0;
      v_imp_debito   := 0;
      v_mto_cargo    := 0;
      v_mto_cargo2   := 0;
      v_tot_deb_gs   := 0;
      v_mto_iva_gs   := 0;
      v_mto_car_gs   := 0;
      v_encontro     := 'N';
      v_se_puede     := 'S';
      v_pendiente    := 'N';
      v_cod_modalidad := pag_cta.g_ctas.cod_modalidad;
      v_cod_sub_modalidad := fug_obt_cod_sub_modalidad(v_nro_cuenta);
      v_tas_personalizada := nvl(pag_cta.g_ctas.tas_personalizada,'N');
      v_cod_tasa_ah := null;
      v_tra_prohibida := pag_cta.g_ctas.tra_prohibida;
      v_cod_ente := pag_cta.g_ctas.cod_ente;
      --principal de cuenta
      v_cod_persona := fug_obt_cli_principal(v_nro_cuenta);      
      
      If FU_OBT_TIP_PERSONA(v_cod_persona) = 'F' then -- Para personas fisicas               
         v_cod_transaccion := 528; -- Trans.Saldo Minimo - Pers.fisicas
      else
         v_cod_transaccion := 4110; -- Trans.Saldo Minimo - Pers.Juridicas
      end if;  
               
      /* ve si tiene transacciones prohibidas para la comision  */
      v_exi_tra_prohibida := 'N';
      IF v_tra_prohibida = 'S'  AND v_msj_error IS NULL THEN
         --busca transacción prohibida x la transacción padre
         v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(v_nro_cuenta, v_cod_transaccion);
         IF v_encontro = 'S' THEN
            v_exi_tra_prohibida := 'S';
         END IF;
      END IF;
      v_pag_sueldo := 'N';
      IF v_cod_ente IS NOT NULL THEN
         /* Es para evitar cobrar a ctas de pagos de sueldos */
         -- v_pag_sueldo := 'S'; 30/06/2004 OPGM
         v_pag_sueldo := 'N';
         /*Debita comisión a la empresa*/
         v_db_empre := 'N';
      END IF;
      /* Si no es una cuenta con transaccion prohibida se procesa dicha cuenta */
      IF v_msj_error IS NULL THEN
         /* ve saldo promedio */
         lp_ver_sal_promedio(v_nro_cuenta, v_anio_actual  , v_mes_actual,v_sal_promedio , v_encontro);
         IF v_encontro = 'N' THEN
            v_msj_error :='Cta '||v_nro_cuenta||' sin saldo promedio !!! ';
         END IF;
         /* Verifica que la cuenta en proceso tenga saldo minimo */
         v_sal_minimo := pag_cta.g_ctas.SAL_MINIMO;
         IF v_sal_minimo IS NULL THEN
            --recuperar el saldo mínimo del parámetro
            v_sal_parametro := FUG_OBT_SAL_MIN_PACTADO(v_cod_moneda, v_cod_persona, v_cod_modulo,
                               v_cod_modalidad, v_cod_oficina,v_cod_sub_modalidad);
            v_sal_minimo := v_sal_parametro;
         END IF;
         IF v_sal_promedio < v_sal_minimo THEN
            /* calcular el monto del cargo a debitar */
            v_sal_disponible := NVL(pag_cta.g_ctas.SAL_TOTAL,0) - NVL(pag_cta.g_ctas.SAL_RETENIDO,0) -
                                NVL(pag_cta.g_ctas.SAL_BLOQUEADO,0) - NVL(pag_cta.g_ctas.MTO_DEB_PENDIENTES,0);
            /* Busco valor de la tasa saldo min. actual para dicha cta */
            IF v_existe = 'S' THEN
               IF v_exi_tra_prohibida = 'S' OR v_pag_sueldo = 'S' THEN
                  v_mto_cargo := 0;
               ELSE
                  v_mto_cargo := pag_cta.g_ctas.sal_total;
                  v_val_tasa := pag_cta.g_ctas.sal_total;
               END IF;
               v_mto_cargo2 := pag_cta.g_ctas.sal_total;
               v_monto := v_iva;
            ELSE--siempre entra x acá
               v_debita := 'N';
               IF v_pag_sueldo = 'N' then
                  lp_ver_cta_debito(v_nro_cuenta,v_debita);
               END IF;
               v_fec_final := v_fecha;
               
               v_tip_valor := ' ';

               v_cod_tasa_ah := null;
               --busca_valor_de_tasa_a_aplicar;
               PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                                       v_nro_cuenta,v_cod_moneda,v_sal_promedio,
                                       v_tas_personalizada, v_cod_tasa_ah,v_cod_transaccion,v_fec_final,
                                       -- OUT
                                       v_val_tas_global,v_fec_vigencia,v_tip_valor,v_tipo);
               IF v_tip_valor = 'V' THEN
                  IF v_exi_tra_prohibida = 'S' OR v_pag_sueldo = 'S' THEN                     
                     v_mto_cargo := 0;
                  ELSE
                     v_mto_cargo := v_val_tas_global;
                  END IF;
                  v_mto_cargo2    := v_val_tas_global;
               ELSE
                  RAISE_APPLICATION_ERROR (-20000,'saldo min. no puede ser porcentual');
               END IF;
               IF v_cod_tasa_ah  IS NULL THEN
                  v_mto_cargo := 0;
                  v_mto_cargo2 := 0;
               END IF;
               v_cod_tasa := v_cod_tasa_ah;
               v_val_tasa := v_val_tas_global;
               v_monto := 0;
            END IF;
            /* ve si tiene transacciones prohibidas para el cobro iva */
            --sólo si ya no tiene prohibida para la transacción padre
            IF NVL(v_exi_tra_prohibida,'N') <> 'S' and v_mto_cargo <> 0 then
               v_exi_tra_prohibida := 'N';
               IF v_tra_prohibida = 'S' THEN
                  v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(v_nro_cuenta, 517);
                  IF v_encontro = 'S' THEN
                     v_exi_tra_prohibida := 'S';
                  END IF;
               END IF;
               v_tas_personalizada := nvl(pag_cta.g_ctas.tas_personalizada,'N');
               v_cod_tasa_ah := null;
               v_fec_final := v_fecha;
               v_tip_valor := ' ';
               PAG_GEN.PR_OBT_VAL_TASA(v_cod_modulo,v_cod_modalidad,v_cod_oficina,
                                       v_nro_cuenta,v_cod_moneda,0,
                                       v_tas_personalizada,v_cod_tasa_ah,517,v_fec_final,
                                       -- OUT
                                       v_val_tas_global,v_fec_vigencia,v_tip_valor,v_tipo);
               v_val_tasa2 := v_val_tas_global;
               v_cod_tasa2 := v_cod_tasa_ah;
               v_redondeo  := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_cod_modulo, v_cod_modalidad, v_cod_moneda);
               IF v_tip_valor = 'V' or v_tipo = 'V' THEN
                  RAISE_APPLICATION_ERROR(-20001,'IVA debe ser porcentual'||
                                          TO_CHAR(V_COD_MODULO)||' '||TO_CHAR(V_COD_MODALIDAD)
                                          ||' '||V_NRO_CUENTA);
               ELSE
                  --IF v_exi_tra_prohibida = 'N' THEN
                     IF v_mto_cargo2  > 0 THEN
                        IF v_cod_moneda = v_cod_mon_local THEN
                           v_monto := ROUND(nvl(v_mto_cargo2,0) *
                                      nvl(v_val_tasa2,0) / 100, v_redondeo);
                        ELSE
                           v_monto := ROUND(nvl(v_mto_cargo2,0) *
                                      nvl(v_val_tasa2,0) / 100, v_redondeo);
                        END IF;
                        --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                        v_monto := pag_gen.FU_OBT_VAL_FINAL(v_monto);
                     END IF;
                     --
                     IF v_exi_tra_prohibida = 'S' THEN                        
                        v_monto := 0;
                     END IF;
                     --
               END IF;
               /* calcular la dif.para saber si el sl. disponible  alcanza p/el debito del cargo   */
               v_imp_debito := nvl(v_mto_cargo,0) + nvl(v_monto, 0);
               -- guardo el valor inicial del cargo
               v_ini_mtocargo := v_mto_Cargo;
               IF v_db_empre = 'N' then
                  /* Se debita a la Cuenta, no a la Empresa */
                  if v_sal_disponible < v_imp_debito then
                    if v_sal_disponible <= 0 then    -- no se le cobra, pero se deja pendiente
                      v_pendiente := 'S';
                      v_se_puede   := 'N';
                    else
                       -- recalculo para cobrarle hasta el monto disponible
                       -- la diferencia queda pendiente
                       IF v_cod_moneda = v_cod_mon_local THEN
                          v_redondeo := 0;
                       else
                          v_redondeo := 2;
                       end if;
                       v_mto_cargo := round(v_sal_disponible * v_mto_cargo / v_imp_debito, v_redondeo);
                       v_monto := v_sal_disponible - v_mto_cargo;
                       v_imp_debito := nvl(v_mto_cargo,0) + nvl(v_monto, 0);
                       v_pendiente := 'S';
                       v_se_puede   := 'S';
                    end if;
                  else
                    v_se_puede := 'S';  
                  end if;
               END IF;
               if v_cod_moneda <> v_cod_mon_local then
                  v_cotizacion := pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fecha);
                  v_tot_deb_gs := round(v_imp_debito * v_cotizacion,0);
                  v_mto_iva_gs     := ROUND(nvl(v_tot_deb_gs,0) *
                                        nvl(v_val_tasa2,0) / (100+nvl(v_val_tasa2,0)), 0);
                  v_mto_car_gs   := v_tot_deb_gs - v_mto_iva_gs;                    
               else 
                  v_cotizacion := null;   
                  v_mto_iva_gs := null;
                  v_mto_car_gs := null;
               end if;
               v_concepto := 'DEBITO POR SALDO MINIMO';
               v_est_movimiento := 'N';
               /*
               || PCC-Exoneración y Extorno de Comisiones y Tasas
               */
               v_paquete := 0;
               begin
                  SELECT count(1)
                    INTO v_paquete
                    FROM ge_paq_modalidades b, ge_paquetes c
                   WHERE v_cod_modulo = b.cod_modulo
                     AND v_cod_modalidad = b.cod_modalidad
                     AND v_cod_sub_modalidad = b.cod_sub_modalidad
                     AND b.cod_paquete = c.cod_paquete
                     AND (c.estado = 'A' or (c.estado = 'I' and c.cod_paquete = v_cod_paq_exnomina));               exception
                  when no_data_found then
                     v_paquete := 0;
                  when too_many_rows then
                     v_paquete := 1;
                  when others then
                     raise_application_error(-20000,'AL Obt.Paquete:'||sqlerrm);
               end;
               if v_ent_cta IS NOT NULL or -- es PLAN SUELDOS
                  nvl(v_paquete, 0) <> 0 or -- es paquete
                  nvl(v_mto_cargo,0) <> nvl(v_val_tasa,0) then -- tiene exoneracion
                  if v_ent_cta IS NOT NULL or -- es PLAN SUELDOS
                     nvl(v_paquete, 0) <> 0 then -- es paquete
                     v_se_puede  := 'N';
                     v_pendiente := 'N';
                  end if;
               end if;
               --
               if v_se_puede = 'S' then
                  --generar movimientos
                  v_nro_documento := v_nro_documento + 1;

                  r_gmovi.cod_usuario := v_cod_usuario;
                  r_gmovi.hora := v_hora;
                  r_gmovi.cod_modulo := v_cod_modulo;
                  r_gmovi.cod_modalidad := v_cod_modalidad;
                  r_gmovi.cod_oficina := v_cod_oficina;
                  r_gmovi.nro_cuenta :=v_nro_cuenta;
                  r_gmovi.cod_moneda := v_cod_moneda;
                  r_gmovi.fecha := v_fecha;
                  r_gmovi.fec_valor := v_fecha;
                  r_gmovi.estado := 'N';
                  r_gmovi.cod_ofi_origen := v_cod_oficina;
                  r_gmovi.cod_mod_padre := v_cod_modulo;
                  r_gmovi.cod_mad_padre := v_cod_modalidad;
                  r_gmovi.reversado :='N';
                  r_gmovi.protegido :='N';
                  r_gmovi.nro_documento := v_nro_documento;
                  IF v_mto_cargo > 0 THEN
                     /* Genera el movimiento de debito en cb_sim_movimientos */
                     r_gmovi.cod_tra_padre := v_cod_Transaccion;
                     r_gmovi.cod_transaccion := v_cod_Transaccion;
                     r_gmovi.monto := v_mto_cargo;
                     r_gmovi.cod_tasa := v_cod_tasa;
                     r_gmovi.val_tasa := v_val_tasa;
                     r_gmovi.concepto := v_concepto||' '||to_char(v_fecha,'dd/mm/yyyy');
                     r_gmovi.cotizacion := v_cotizacion;
                     r_gmovi.mto_equ_local := v_mto_car_gs;
                     v_nro_secuencia := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia := v_nro_secuencia;
                     PR_INS_GE_MOVIMIENTO(r_gmovi);
                  END IF;
                  IF v_monto > 0
                  and nvl(V_DB_EMPRE,'N') = 'N' THEN
                     /* Genera el movimiento de debito en cb_sim_movimientos */
                     r_gmovi.cod_tra_padre := 517;
                     r_gmovi.cod_transaccion := 517;
                     r_gmovi.monto := v_monto;
                     r_gmovi.cod_tasa := v_cod_tasa2;
                     r_gmovi.val_tasa := v_val_tasa2;
                     r_gmovi.concepto := v_concepto||' '||to_char(v_fecha,'dd/mm/yyyy');
                     v_nro_secuencia := v_nro_secuencia + 1;
                     r_gmovi.nro_secuencia := v_nro_secuencia;
                     r_gmovi.cotizacion := v_cotizacion;
                     r_gmovi.mto_equ_local := v_mto_iva_gs;                       
                     PR_INS_GE_MOVIMIENTO(r_gmovi);
                  END IF;
               End if;              
            end if; --si no tiene transacción padre prohibida
         END IF;--si sal-promedio < minimo
      END IF;
   END LOOP;
   IF aho%ISOPEN THEN
      CLOSE aho;
   END IF;  
END;

/* Calcula el comision por Bajo Promedio Cuentas Corrientes. */
PROCEDURE PR_DEB_SAL_MIN_CTACTE(p_fecha in ge_calendarios.fec_actual%type)
 IS
  v_cdtrans      cb_sim_movimientos.cod_transaccion%type;
  v_hrmovim      cb_sim_movimientos.hora%type;
  v_encontro     varchar2(1);
  v_traprohi     varchar2(1) := 'N';
  v_autoriza     varchar2(1) := 'N';
  v_pendiente    varchar2(1) := 'N'; 
  v_salprom      cc_cta_corrientes.sal_total%type;
  v_slminpa      cc_cta_corrientes.sal_total%type;
  v_sldispo      cc_cta_corrientes.sal_total%type;
  v_mesact       cc_sal_mensuales.mes%type;
  v_aniact       cc_sal_mensuales.ano%type;
  v_imtrans      cc_cta_corrientes.sal_total%type;
  v_tasaper      varchar2(1);
  v_montcar      cb_sim_movimientos.monto%type;
  v_ini_montcar  cb_sim_movimientos.monto%type;
  v_cmoncar      cb_sim_movimientos.monto%type;
  v_cdtasca      cb_sim_movimientos.cod_tasa%type;
  v_vltasca      cb_sim_movimientos.val_tasa%type;
  v_montimp      cc_cta_corrientes.sal_total%type;
  v_ini_montimp  cc_cta_corrientes.sal_total%type;
  v_cdtasim      cb_sim_movimientos.cod_tasa%type;
  v_vltasim      cb_sim_movimientos.val_tasa%type;
  v_imdebit      cc_cta_corrientes.sal_total%type;
  v_lgpuede      varchar2(1);
  v_esmovim      varchar2(1);
  v_concept      cb_sim_movimientos.concepto%type;
  v_cuantos      NUMBER;
  v_slparam      NUMBER;   -- saldo de parametro --
  v_cdusuar      ba_usuarios.cod_usuario%type;
  v_vltasa       ge_tas_fechas.val_tasa%type;
  v_fec_vigencia ge_tas_fechas.fec_vigencia%type;
  v_tipo         ge_tasas.tipo%type;
  v_cdtasas      ah_cta_vistas.cod_tasa%type;
  v_fcdehoy      date;
  v_fcfinal      date;
  v_tpvlpor      varchar2(1);
  v_nrsecue      cb_sim_movimientos.nro_secuencia%type;
  v_nrcuent      cc_cta_corrientes.nro_cuenta%type;
  v_cdmodul      cc_cta_corrientes.cod_modulo%type;
  v_cdmodal      cc_cta_corrientes.cod_modalidad%type;
  v_cdofici      cc_cta_corrientes.cod_oficina%type;
  v_cdmoned      cc_cta_corrientes.cod_moneda%type;
  v_cod_persona    ge_cta_clientes.cod_persona%type;
  v_nro_documento  cb_sim_movimientos.nro_documento%type := 0;
  v_dia_sobregiros cc_sobregiros_res.can_dias%type;
  v_redondeo       number(4);
  v_es_combinada   varchar2(1); 
  r_cte            cc_cta_corrientes%rowtype;  
  v_paquete        number := 0; 
  
CURSOR cte IS
  select *
    from cc_cta_corrientes cc
   where cc.estado not in ('C','P','A','T','D','X')
     and cc.fec_apertura < v_fcdehoy;
     
/* Verifica y devuelve el saldo promedio. */
PROCEDURE LP_VER_SAL_PROMEDIO
         (p_modulo      IN   NUMBER,
          p_modalidad   IN   NUMBER,
          p_oficina     IN   NUMBER,
          p_cuenta      IN   CHAR,
          p_anioactual  IN   NUMBER,
          p_mesactual   IN   NUMBER,
          p_saldo_prom  OUT  NUMBER,
          p_encontro    OUT  CHAR);
          
PROCEDURE LP_VER_SAL_PROMEDIO
         (p_modulo      IN   NUMBER,
          p_modalidad   IN   NUMBER,
          p_oficina     IN   NUMBER,
          p_cuenta      IN   CHAR,
          p_anioactual  IN   NUMBER,
          p_mesactual   IN   NUMBER,
          p_saldo_prom  OUT  NUMBER,
          p_encontro    OUT  CHAR) IS
BEGIN
    p_encontro := 'S';
    If v_es_combinada = 'S' then
       SELECT nvl(decode(nvl(s.can_dia_acumulado,0),0,0,(nvl(round(NVL(s.sal_acu_diario,0)/s.can_dia_acumulado,2),0))),0) + nvl(decode(nvl(a.can_dia_acumulado,0),0,0,(nvl(round(NVL(a.sal_acu_diario,0)/a.can_dia_acumulado,2),0))),0)
         INTO p_saldo_prom
         FROM ah_sal_mensuales a, cc_sal_mensuales s, cc_cta_combinadas b
        WHERE s.nro_cuenta = p_cuenta
          and s.ano = p_anioactual 
          and s.mes = p_mesactual 
          and b.nro_cta_cte(+) = s.nro_cuenta 
          and a.nro_cuenta(+)  = b.nro_cta_ahorro 
          and a.ano(+) = p_anioactual
          and a.mes(+) = p_mesactual;
     else          
       SELECT round(NVL(sal_acu_diario,0)/can_dia_acumulado,2)
         INTO p_saldo_prom
         FROM cc_sal_mensuales
        WHERE nro_cuenta    = p_cuenta
          AND ano           = p_anioactual
          AND mes           = p_mesactual;
     End if;     
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      --raise_application_error(-20000,'No encontro en saldos mensuales. Cta : ' || p_cuenta);
      p_saldo_prom := 0;
      p_encontro := 'N';
END;
/* Obtiene el tipo de persona. */
FUNCTION FU_OBT_TIP_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2 IS
v_tip_persona varchar2(1); 
BEGIN
     SELECT TIPO
       INTO v_tip_persona
       FROM BA_PERSONAS
      WHERE COD_PERSONA = P_COD_PERSONA;
     return v_tip_persona; 
EXCEPTION
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR (-20000,'Error al traer tipo de persona : '||p_cod_persona||' - '||sqlerrm);
END;
/* Obtiene si tiene Linea de Sobregiro. */
FUNCTION FU_VER_LIN_SOBREGIRO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2 IS
v_tiene varchar2(1); 
BEGIN
     SELECT 'S'
       INTO v_tiene
       FROM CC_LIN_SOBREGIROS
      WHERE NRO_CUENTA = P_NRO_CUENTA
        AND FEC_VENCIMIENTO <= v_fcdehoy; 
     return v_tiene;
EXCEPTION
  WHEN NO_dATA_FOUND THEN
   v_tiene := 'N';
   Return v_tiene;
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR (-20000,'Error al verificar Linea de Sobregiro : '||p_nro_cuenta||' - '||sqlerrm);
END;

-- Proceso Principal.
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 2; end;
  v_cuantos := 0;  
  v_nrsecue := 0;
  v_cdusuar := substr(user,1,10);
  v_fcdehoy := p_fecha;
  v_hrmovim := fu_ini_hora(v_fcdehoy);
  v_aniact  := to_char(v_fcdehoy,'YYYY');
  v_mesact  := to_char(v_fcdehoy,'MM');
  -- ciclo para cada modulo, modal y ofic diferente.
  IF cte%ISOPEN THEN
     CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
     FETCH cte INTO r_cte;
     EXIT WHEN cte%NOTFOUND;
     v_nrcuent := r_cte.nro_cuenta;
     v_cdmodul := r_cte.cod_modulo;
     v_cdmodal := r_cte.cod_modalidad;
     v_cdofici := r_cte.cod_oficina;
     v_tasaper := nvl(r_cte.tas_personalizada,'N');
     v_es_combinada := r_cte.cta_combinada;
     v_cdtasas := null;
     v_imdebit := 0;
     v_montcar := 0;
     v_montimp := 0;
     v_ini_montcar := 0;
     v_ini_montimp := 0;
     v_cmoncar     := 0;
     --principal de cuenta
     v_cod_persona := fug_obt_cli_principal(r_cte.nro_cuenta);     
     If FU_OBT_TIP_PERSONA(v_cod_persona) = 'F' then -- Para personas fisicas               
        v_cdtrans := 528; -- Trans.Saldo Minimo - Pers.fisicas
     else
        v_cdtrans := 4110; -- Trans.Saldo Minimo - Pers.Juridicas
     end if;       
     if v_nrsecue > 990 then
       v_hrmovim := fu_ini_hora(v_fcdehoy);
       v_nrsecue := 0;
     end if;
     /* ve si tiene transacciones prohibidas */
     ------------------------------------------
     v_traprohi := 'N';
     v_pendiente := 'N';
     IF r_cte.tra_prohibida = 'S' THEN
       --verifica transaccion prohibida por la transaccion padre
       v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(r_cte.nro_cuenta, v_cdtrans,
                                                  r_cte.cod_modulo, r_cte.cod_modalidad);
       IF v_encontro = 'S' THEN
          v_traprohi := 'S';
       END IF;
     END IF;
     ------------------------------------------
     -- ve saldo promedio                   --
     -----------------------------------------
     v_salprom := 0;
     v_encontro := 'N';
     v_dia_sobregiros := 0;
     LP_VER_SAL_PROMEDIO (r_cte.cod_modulo, r_cte.cod_modalidad,
                          r_cte.cod_oficina, r_cte.nro_cuenta,
                          v_aniact       , v_mesact,
                          v_salprom      , v_encontro);
     IF v_encontro = 'S' THEN
         v_slminpa := r_cte.sal_minimo;
         IF v_slminpa IS NULL THEN --no tiene saldo minimo
            --recuperar el saldo minimo del parametro
            v_slparam := FUG_OBT_SAL_MIN_PACTADO(r_cte.cod_moneda, v_cod_persona, r_cte.cod_modulo,
                               r_cte.cod_modalidad, r_cte.cod_oficina,r_cte.cod_sub_modalidad);
            v_slminpa := v_slparam;
         END IF;
         --
         IF v_salprom >= v_slminpa THEN
           GOTO siguiente_registro;
         END IF;
				 /* Verifica los dias de sobregiro del cliente para generarle el cargo. */
				 SELECT nvl(max(can_dias),0)
				   INTO v_dia_sobregiros
					 FROM cc_sobregiros_res
          WHERE nro_cuenta = r_cte.nro_cuenta;
				 
				 IF v_dia_sobregiros >= nvl(fug_obt_pardinamico('DIA_INA_CAR_SOBREGIROS',r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda,r_cte.cod_oficina),9999) then
				    GOTO siguiente_registro;
				 END IF;
         /* calcular el monto del cargo a debitar */
         v_sldispo := NVL(r_cte.sal_total,0) - NVL(r_cte.sal_retenido,0) - NVL(r_cte.sal_bloqueado,0);
         v_cdmoned := r_cte.cod_moneda;
         v_fcfinal := v_fcdehoy;
         --v_cdtrans := 528;  --ya se asigno mas arriba
         v_tpvlpor := ' ';
         PAG_GEN.PR_OBT_VAL_TASA(r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_oficina,
                                 r_cte.nro_cuenta,r_cte.cod_moneda,v_salprom,
                                 v_tasaper, v_cdtasas,v_cdtrans,v_fcfinal,
                                -- OUT
                                 v_vltasa,v_fec_vigencia,v_tpvlpor,v_tipo);
         IF v_tpvlpor = 'V' THEN
           If v_traprohi = 'S' or v_autoriza = 'S' Then             
              v_montcar := 0;
           Else
              v_montcar := v_vltasa;
           End If;
           v_cmoncar := v_vltasa;
         ELSE
           raise_application_error(-20000,'Cargo de saldo minimo no puede ser porcentual ');
         END IF;
         IF v_cdtasas  IS NULL OR v_vltasa  = 0 THEN
            v_montcar := 0;
            v_cmoncar := 0;
         END IF;
         /* calcular el monto del impuesto sobre el cargo a debitar */
         -------------------------------------------------------------
         v_vltasca := v_vltasa;
         v_cdtasca := v_cdtasas;
         v_imtrans := v_montcar;
         v_montimp := 0;
         --- Agregado para que calcule el impuesto ---
         /* ve si tiene transacciones prohibidas */
         ------------------------------------------
         --solo si no tiene transaccion padre prohibida y si no tiene linea de sobregiro vigente
         --y si el cargo es distinto de cero
         If  nvl(v_traprohi,'N') <> 'S' 
         and FU_VER_LIN_SOBREGIRO(r_cte.nro_cuenta) = 'N'
         and v_montcar <> 0 then
            v_traprohi := 'N';
            IF r_cte.tra_prohibida = 'S' THEN
              v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(r_cte.nro_cuenta, 517,
                                                         r_cte.cod_modulo, r_cte.cod_modalidad);
              IF v_encontro = 'S' THEN
                v_traprohi := 'S';
              END IF;
            END IF;
            v_nrcuent := r_cte.nro_cuenta;
            v_cdmodul := r_cte.cod_modulo;
            v_cdmodal := r_cte.cod_modalidad;
            v_cdofici := r_cte.cod_oficina;
            v_tasaper := nvl(r_cte.tas_personalizada,'N');
            v_cdtasas := null;
            v_cdmoned := r_cte.cod_moneda;
            v_fcfinal := v_fcdehoy;
            v_tpvlpor := ' ';
            PAG_GEN.PR_OBT_VAL_TASA(r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_oficina,
                                    r_cte.nro_cuenta,r_cte.cod_moneda,0,
                                    v_tasaper, v_cdtasas,517,v_fcfinal,
                                   -- OUT
                                    v_vltasa,v_fec_vigencia,v_tpvlpor,v_tipo);
            v_vltasim  := v_vltasa;
            v_cdtasim  := v_cdtasas;
            v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda);
            IF v_tpvlpor = 'V' THEN
              raise_application_error(-20000,'IVA de Cargo de saldo minimo debe ser porcentual');
            ELSE
                --If v_traprohi = 'N' Then
                  If v_cmoncar > 0 Then
                     v_montimp := Round(nvl(v_cmoncar,0) *
                                        nvl(v_vltasim,0) / 100, v_redondeo);
                     
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_montimp := pag_gen.FU_OBT_VAL_FINAL(v_montimp);
                     
                  End If;
                  --
                  If v_traprohi = 'S' Then
                     v_montimp := 0;
                  End If;
            END IF;
            --  /* calcular la diferencia para saber si el saldo disponible
            --     alcanza para el debito del cargo e impuesto.               */
            v_imdebit := v_montcar + v_montimp;
            -- guardo los importes originales
            v_ini_montcar := v_montcar;
            v_ini_montimp := v_montimp;
            v_lgpuede := 'S';
            IF v_sldispo - v_imdebit < 0 THEN
              v_lgpuede := 'S';
              v_esmovim := 'N';
              -- if r_cte.estado = 'I' then  -- cuentas inactivas
              -- ya no importa si esta inactiva. Siempre se cobra solo lo que tiene, pedido
              -- de Yanagida 28/12/06
              if v_sldispo = 0 then    -- no esta sobregirado, no se le sobregira pero se deja pendiente
                 v_pendiente := 'S';
                 v_lgpuede := 'N';
              elsif v_sldispo <> 0 then    --si tiene saldo o si esta sobregirado se le cobra igual
                 if  v_sldispo > 0 then
                   -- recalculo para cobrarle hasta el monto disponible
                   v_montcar := round(v_sldispo * v_montcar / v_imdebit, v_redondeo);
                   v_montimp := v_sldispo - v_montcar;
                   v_imdebit := nvl(v_montcar,0) + nvl(v_montimp, 0);    
                   v_lgpuede := 'S';                
                   v_pendiente := 'S';
                 else
                   v_lgpuede := 'S';                
                   v_pendiente := 'N';                     
                 end if;  
              end if;
              -- end if;
            END IF;
            IF v_lgpuede = 'S' THEN
              v_esmovim := 'N';
            ELSE
              If v_montcar > 0 Then
                 v_concept := 'DEBITO POR SALDO MINIMO '||to_char(v_fcdehoy,'dd/mm/yyyy');
                 v_esmovim := 'E';
                 v_cuantos := v_cuantos + 1;
              End If;
            END IF;
            /*
            || PCC-Exoneración y Extorno de Comisiones y Tasas
            */
            v_paquete := 0;
            begin
               SELECT count(1)
                 INTO v_paquete
                 FROM ge_paq_modalidades b, ge_paquetes c
                WHERE r_cte.cod_modulo = b.cod_modulo
                  AND r_cte.cod_modalidad = b.cod_modalidad
                  AND r_cte.cod_sub_modalidad = b.cod_sub_modalidad
                  AND b.cod_paquete = c.cod_paquete
                  AND (c.estado = 'A' or (c.estado = 'I' and c.cod_paquete = v_cod_paq_exnomina));               
            exception
               when no_data_found then
                  v_paquete := 0;
               when too_many_rows then
                  v_paquete := 1;
               when others then
                  raise_application_error(-20000,'AL Obt.Paquete:'||sqlerrm);
            end;
            if r_cte.cod_ente IS NOT NULL or -- es PLAN SUELDOS
               nvl(v_paquete, 0) <> 0 or -- es paquete
               nvl(v_montcar,0) <> nvl(v_vltasca,0) then -- tiene exoneracion
               if r_cte.cod_ente IS NOT NULL or -- es PLAN SUELDOS
                  nvl(v_paquete, 0) <> 0 then -- es paquete
                  v_lgpuede   := 'N';
                  v_pendiente := 'N';
               end if;
            end if;
            ---
            If v_lgpuede = 'S' then
              if v_montcar > 0 or v_montimp > 0 then
                 --generar movimientos
                 v_nro_documento := v_nro_documento + 1;
              end if;
              IF v_montcar > 0 THEN
             -- movimiento de debito
             -----------------------
               v_nrsecue := v_nrsecue + 1;
               insert into cb_sim_movimientos
                (cod_usuario, hora, nro_secuencia,
                 cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                 cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                 fec_valor, monto, estado, cod_ofi_origen,
                 cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                 reversado, protegido, nro_documento, concepto)
               VALUES
                (v_CDUSUAR, v_HRMOVIM, v_NRSECUE,
                 r_cte.cod_modulo, r_cte.cod_modalidad, r_cte.cod_oficina,
                 r_cte.nro_cuenta, r_cte.cod_moneda, v_cdtrans,v_cdtrans,v_fcdehoy,
                 v_fcdehoy, v_montcar, v_esmovim,r_cte.cod_oficina,
                 v_cdtasca, v_vltasca,r_cte.cod_modulo, r_cte.cod_modalidad,'N','N', v_nro_documento, v_concept);
              END IF;
              IF v_montimp > 0 THEN
             -- movimiento de debito
             -----------------------
               v_nrsecue := v_nrsecue + 1;
               insert into cb_sim_movimientos
                 (cod_usuario, hora, nro_secuencia,
                 cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                 cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                 fec_valor, monto, estado, cod_ofi_origen,
                 cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                 reversado, protegido, nro_documento, concepto)
               values
                (v_cdusuar, v_hrmovim, v_nrsecue,
                 r_cte.cod_modulo, r_cte.cod_modalidad, r_cte.cod_oficina,
                 r_cte.nro_cuenta, r_cte.cod_moneda, 517,517,v_fcdehoy,
                 v_fcdehoy, v_montimp, 'N',r_cte.cod_oficina,
                 v_cdtasim, v_vltasim,4, 41,'N','N', v_nro_documento, v_concept);
              End if;--mto imp
            end if;  
       end if; --si no tiene tra padre prohibida
     End if;--si encontro = s
     <<siguiente_registro>>
     NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
EXCEPTION
  when no_data_found then
    raise_application_error(-20000,'No existe datos en el archivo');
end;

/* Trae la situacion del sobregiro en Cc_sobregiros_res*/
FUNCTION FU_SIT_SOBREGIRO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
v_situacion varchar2(1);
Begin
    Select sit_deuda
      into v_situacion
      from cc_sobregiros_res
     where nro_cuenta = p_nro_cuenta;
    Return v_situacion;
Exception
 when others then
   return null;
End;

/* Genera los cargos por utilización de linea - Sobregiros. */
FUNCTION FU_UTI_LINEA(p_fecha in ge_calendarios.fec_actual%type,
                      P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,
                      P_PROCESA IN VARCHAR2 DEFAULT 'S')
RETURN NUMBER
IS
  -- Variables.
  v_fcdehoy          ge_calendarios.fec_actual%type; 
  v_nrsecue          cb_sim_movimientos.nro_secuencia%type;
  v_hrmovim          cb_sim_movimientos.hora%type;
  v_imdebit          cb_sim_movimientos.monto%type :=  0;
  r_gmovi            cb_sim_movimientos%ROWTYPE;
  --
  v_cod_tra_cargo    number(4);--Transaccion para el cobro de cargos
  v_cod_tas_cargo    number(4);
  v_val_tas_cargo    number(18,4);
  v_val_cargo        number(18,2);
  v_val_max_tae      number;
  v_cod_tra_impuesto number(4);
  v_cod_tas_impuesto number(4);
  v_val_tas_impuesto number(18,4);
  v_val_impuesto     number(18,2);
  v_can_decimales    number; --Para el redondeo, recalculo impuesto TAE
  --
  CURSOR cte IS
    select cc.*
      from cc_cta_corrientes cc,cc_sobregiros_res s
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.nro_cuenta = s.nro_cuenta(+)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.cod_ente is not null -- solo para los que son PLAN SUELDOS
       and s.can_dias < nvl(fug_obt_pardinamico('DIA_INA_CAR_SOBREGIROS',cc.cod_modulo,cc.cod_modalidad,cc.cod_moneda,cc.cod_oficina),9999)
       and cc.fec_apertura <= v_fcdehoy
       and exists
           (select 'S'
              from cc_sobregiros ccs
         where ccs.nro_cuenta = cc.nro_cuenta
         and fecha between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
         and trunc(v_fcdehoy)
         and nvl(ccs.mto_linea,0) <> 0
         and liquidado = 'N' );
   --
   r_cte     cte%rowtype;
  
BEGIN
  -- Verifica el estado del modulo para acumular o no
  v_fcdehoy := p_fecha;
  v_hrmovim := fu_ini_hora(v_fcdehoy);
  
  v_nrsecue := 0;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;

    if FU_SIT_SOBREGIRO(r_cte.nro_cuenta) not in('S','V') then  -- En gestion, mayor a 60 dias
      v_cod_tra_cargo := 787;  -- para los que estan en gestion
    else
      v_cod_tra_cargo := 786;  -- si no esta en gestion
    End if;
    -- Cero los valores para asegurar
    v_imdebit := 0;
    v_val_cargo := 0;
    v_val_impuesto := 0;
    -- obtengo el cargo y el impuesto
    prg_obt_cargos(r_cte.cod_oficina,
                   r_cte.nro_cuenta,
                   r_cte.cod_moneda,
                   NULL,
                   r_cte.cod_modulo,
                   r_cte.cod_modalidad,
                   v_cod_tra_cargo,--Transaccion para el cobro de cargos
                   v_cod_tas_cargo,
                   v_val_tas_cargo,
                   v_val_cargo,
                   v_cod_tra_impuesto,
                   v_cod_tas_impuesto,
                   v_val_tas_impuesto,
                   v_val_impuesto);
     if v_nrsecue > 990 then
        v_hrmovim := fu_ini_hora(v_fcdehoy);
        v_nrsecue := 0;
     end if;

     --Verificar si excede el límite s/ TAE para Sobregiro
     v_can_decimales:= fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda);

     if r_cte.cod_modulo = 4 and r_cte.cod_modalidad = 41 then
        v_val_max_tae := fuc_obt_val_max_tae(r_cte.nro_cuenta,
                                           r_cte.cod_modulo,
                                           r_cte.cod_modalidad,
                                           v_cod_tra_cargo,
                                           v_val_cargo);
       if v_val_cargo > v_val_max_tae then
          v_val_cargo := v_Val_max_tae; --fuc_obt_val_max_tae(r_cte.nro_cuenta,
                                          --   r_cte.cod_modulo,
                                          --   r_cte.cod_modalidad,
                                          --   v_cod_tra_cargo,
                                          --   v_val_cargo);
           --Volver a Calcular el IVA
           v_val_impuesto := round(nvl(v_val_cargo,0)*nvl(v_val_tas_impuesto,0)/(100),v_can_decimales);
       end if;
     end if;
     --

     -- Calcula el monto a debitar de la cuenta
     v_imdebit := v_val_cargo + v_val_impuesto;
     IF p_procesa = 'S' then
       IF v_val_cargo > 0 and p_procesa = 'S' THEN
         -- movimiento de debito del Cargo
         -----------------------
         v_nrsecue := v_nrsecue + 1;
         r_gmovi.cod_modulo      := r_cte.cod_modulo;
         r_gmovi.cod_modalidad   := r_cte.cod_modalidad;
         r_gmovi.cod_oficina     := r_cte.cod_oficina;
         r_gmovi.nro_cuenta      := r_cte.nro_cuenta;
         r_gmovi.cod_moneda      := r_cte.cod_moneda;
         r_gmovi.cod_usuario     := substr(upper(user), 1, 10);
         r_gmovi.hora            := v_hrmovim;
         r_gmovi.fecha           := v_fcdehoy;
         r_gmovi.nro_secuencia   := v_nrsecue;
         --
         r_gmovi.fec_valor       := v_fcdehoy;
         r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
         r_gmovi.cod_mod_padre   := r_cte.cod_modulo;
         r_gmovi.cod_mad_padre   := r_cte.cod_modalidad;
         r_gmovi.cod_transaccion := v_cod_tra_cargo;
         r_gmovi.monto           := v_val_cargo;
         r_gmovi.nro_documento   := null;
         r_gmovi.nro_documento2  := null;
         r_gmovi.nro_documento3  := null;
         r_gmovi.cod_tasa        := v_cod_tas_cargo;
         r_gmovi.val_tasa        := v_val_tas_cargo;
         r_gmovi.cotizacion      := null;
         r_gmovi.cod_ofi_origen  := r_cte.cod_oficina;
         r_gmovi.emi_aviso       := 'N';
         r_gmovi.concepto        := 'Debito Cargo Sobregiro';
         r_gmovi.estado          := 'N';
         r_gmovi.reversado       := 'N';
         pr_ins_ge_movimiento(r_gmovi);
       END IF;
       IF v_val_impuesto > 0 THEN
          -- movimiento de debito por iva
          ----------------------------------
          v_nrsecue := v_nrsecue + 1;
          r_gmovi.cod_modulo      := r_cte.cod_modulo;
          r_gmovi.cod_modalidad   := r_cte.cod_modalidad;
          r_gmovi.cod_oficina     := r_cte.cod_oficina;
          r_gmovi.nro_cuenta      := r_cte.nro_cuenta;
          r_gmovi.cod_moneda      := r_cte.cod_moneda;
          r_gmovi.cod_usuario     := substr(upper(user), 1, 10);
          r_gmovi.hora            := v_hrmovim;
          r_gmovi.fecha           := v_fcdehoy;
          r_gmovi.nro_secuencia   := v_nrsecue;
          --
          r_gmovi.fec_valor       := v_fcdehoy;
          r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
          r_gmovi.cod_mod_padre   := r_cte.cod_modulo;
          r_gmovi.cod_mad_padre   := r_cte.cod_modalidad;
          r_gmovi.cod_transaccion := v_cod_tra_impuesto;
          r_gmovi.monto           := v_val_impuesto;
          r_gmovi.nro_documento   := null;
          r_gmovi.nro_documento2  := null;
          r_gmovi.nro_documento3  := null;
          r_gmovi.cod_tasa        := v_cod_tas_impuesto;
          r_gmovi.val_tasa        := v_val_tas_impuesto;
          r_gmovi.cotizacion      := null;
          r_gmovi.cod_ofi_origen  := r_cte.cod_oficina;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := 'Debito Iva-Cargo por Sobregiro';
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          pr_ins_ge_movimiento(r_gmovi);
       END IF;     
    end if;
     <<fin_mientras>> NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  -- Retorna el monto del debito
  Return v_imdebit;
EXCEPTION
  when no_data_found then
     raise_application_error(-20000,'No existen datos');
End;

/* Debita los excesos de plazo, los que superan 30 dias de sobregiro */
FUNCTION FU_PRO_EXE_PLAZO(p_fecha in ge_calendarios.fec_actual%type,
                          p_nro_cuenta in ge_cuentas.nro_cuenta%type default null,
                          p_procesa in varchar2 default 'S')
RETURN NUMBER
IS
  -- Variables.
  v_fcdehoy ge_calendarios.fec_actual%type;

   -- Cursores.
  CURSOR cte IS
    select cc.*
      from cc_cta_corrientes cc,cc_sobregiros_res r
     where cc.nro_cuenta = nvl(p_nro_cuenta,cc.nro_cuenta)
       and cc.nro_cuenta = r.nro_cuenta(+)
       and cc.estado not in ('C','P','A','T','D','X')
       and cc.cod_modalidad = 41
       and cc.fec_apertura <= v_fcdehoy
       and r.can_dias < nvl(fug_obt_pardinamico('DIA_INA_CAR_SOBREGIROS',cc.cod_modulo,cc.cod_modalidad,cc.cod_moneda,cc.cod_oficina),9999)
       and exists
           (select 'S'
              from cc_sobregiros ccs
              where ccs.nro_cuenta = cc.nro_cuenta
               and fecha between to_date('01'||to_char(v_fcdehoy, 'mmyyyy'),'ddmmyyyy')
               and trunc(v_fcdehoy))
       and ((cc.cod_ente is not null  -- cuenta de nomina
       and not exists  --  para que no tome las cuentas de nomina vigentes
            (select 'S' from gv_movimientos h
              where h.nro_cuenta = cc.nro_cuenta
                and h.cod_transaccion = 602  --Credito en cuenta
                and h.fecha between to_Date('01'||to_char(add_months(v_fcdehoy,-1),'mmyyyy'),'ddmmyyyy')
                and trunc(v_fcdehoy)
                and h.concepto like 'Pago de Sueldo%'))
        or cc.cod_ente is null);
  r_cte cte%rowtype;
  --
  v_nrsecue cb_sim_movimientos.nro_secuencia%type;
  v_hrmovim cb_sim_movimientos.hora%type;
  v_imdebit cb_sim_movimientos.monto%type :=  0;
  r_gmovi   cb_sim_movimientos%ROWTYPE;

  v_cod_tra_cargo    number(4);
  v_cod_tas_cargo    number(4);
  v_val_tas_cargo    number(18,4);
  v_val_cargo        number(18,2);
  v_cod_tra_impuesto number(4);
  v_cod_tas_impuesto number(4);
  v_val_tas_impuesto number(18,4);
  v_val_impuesto     number(18,2);
  v_cant             number := 0;

BEGIN
  -- Verifica el estado del modulo para acumular o no
  v_fcdehoy := p_fecha;
  v_hrmovim := fu_ini_hora(v_fcdehoy);
  v_nrsecue := 0;
  --
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
    FETCH cte INTO r_cte;
    EXIT WHEN cte%NOTFOUND;

    -- busco la cantidad de dias en exceso
    Begin
      select count(*)
        into v_cant
        from cc_sobregiros ccs
       where ccs.nro_cuenta = r_cte.nro_cuenta
         and ccs.fecha between TO_DATE('01' || to_char(v_fcdehoy, 'MMYYYY'), 'DDMMYYYY') AND trunc(v_fcdehoy)
         and (ccs.mto_linea = 0 and can_dias > 30)
         and ccs.liquidado = 'N'; -- Sobregiros sin linea y sobregiros mayores a 30 dias
    exception
      when no_data_found then
        v_cant := 0;
    end;
    -- Cero los valores para asegurar
    v_imdebit := 0;
    v_val_cargo := 0;
    v_val_impuesto := 0;
    If v_cant > 0 then   -- si encontro algun registro
      If r_cte.cod_ente is null then -- No incluye nomina.       
         -- Verifico el estado del sobregiro, si esta en gestion se genera el movimiento
         -- con otra transaccion
         if FU_SIT_SOBREGIRO(r_cte.nro_cuenta) not in('S','V') then  -- En gestion, mayor a 60 dias
            v_cod_tra_cargo := 981;  --Transaccion para sobregiros en gestion
         else
            v_cod_tra_cargo := 788;  --Transaccion para el cobro de cargos
         end if;
         -- obtengo el cargo y el impuesto
         prg_obt_cargos(r_cte.cod_oficina,
                        r_cte.nro_cuenta,
                        r_cte.cod_moneda,
                        NULL,
                        r_cte.cod_modulo,
                        r_cte.cod_modalidad,
                        v_cod_tra_cargo,--Transaccion para el cobro de cargos
                        v_cod_tas_cargo,
                        v_val_tas_cargo,
                        v_val_cargo,
                        v_cod_tra_impuesto,
                        v_cod_tas_impuesto,
                        v_val_tas_impuesto,
                        v_val_impuesto);
         if v_nrsecue > 990 then
            v_hrmovim := fu_ini_hora(v_fcdehoy);
            v_nrsecue := 0;
         end if;
     -- Calcula el monto a debitar de la cuenta
         v_imdebit := v_val_cargo + v_val_impuesto;
         IF p_procesa = 'S' then
            IF v_val_impuesto > 0 and p_procesa = 'S' THEN
            -- movimiento de debito del Cargo
            -----------------------
            v_nrsecue := v_nrsecue + 1;
            r_gmovi.cod_modulo      := r_cte.cod_modulo;
            r_gmovi.cod_modalidad   := r_cte.cod_modalidad;
            r_gmovi.cod_oficina     := r_cte.cod_oficina;
            r_gmovi.nro_cuenta      := r_cte.nro_cuenta;
            r_gmovi.cod_moneda      := r_cte.cod_moneda;
            r_gmovi.cod_usuario     := substr(upper(user), 1, 10);
            r_gmovi.hora            := v_hrmovim;
            r_gmovi.fecha           := v_fcdehoy;
            r_gmovi.nro_secuencia   := v_nrsecue;
            --
            r_gmovi.fec_valor       := v_fcdehoy;
            r_gmovi.cod_tra_padre   := v_cod_tra_cargo;
            r_gmovi.cod_mod_padre   := r_cte.cod_modulo;
            r_gmovi.cod_mad_padre   := r_cte.cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_tra_cargo;
            r_gmovi.monto           := v_val_cargo;
            r_gmovi.nro_documento   := null;
            r_gmovi.nro_documento2  := null;
            r_gmovi.nro_documento3  := null;
            r_gmovi.cod_tasa        := v_cod_tas_cargo;
            r_gmovi.val_tasa        := v_val_tas_cargo;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := r_cte.cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Debito Cargo Exceso Linea';
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            pr_ins_ge_movimiento(r_gmovi);
         END IF;
         IF v_val_impuesto > 0 THEN
            -- movimiento de debito por iva
            ----------------------------------
            v_nrsecue := v_nrsecue + 1;
            r_gmovi.cod_modulo      := r_cte.cod_modulo;
            r_gmovi.cod_modalidad   := r_cte.cod_modalidad;
            r_gmovi.cod_oficina     := r_cte.cod_oficina;
            r_gmovi.nro_cuenta      := r_cte.nro_cuenta;
            r_gmovi.cod_moneda      := r_cte.cod_moneda;
            r_gmovi.cod_usuario     := substr(upper(user), 1, 10);
            r_gmovi.hora            := v_hrmovim;
            r_gmovi.fecha           := v_fcdehoy;
            r_gmovi.nro_secuencia   := v_nrsecue;
            --
            r_gmovi.fec_valor       := v_fcdehoy;
            r_gmovi.cod_tra_padre   := v_cod_tra_impuesto;
            r_gmovi.cod_mod_padre   := r_cte.cod_modulo;
            r_gmovi.cod_mad_padre   := r_cte.cod_modalidad;
            r_gmovi.cod_transaccion := v_cod_tra_impuesto;
            r_gmovi.monto           := v_val_impuesto;
            r_gmovi.nro_documento   := null;
            r_gmovi.nro_documento2  := null;
            r_gmovi.nro_documento3  := null;
            r_gmovi.cod_tasa        := v_cod_tas_impuesto;
            r_gmovi.val_tasa        := v_val_tas_impuesto;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := r_cte.cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := 'Debito Iva-Exceso de Linea';
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            pr_ins_ge_movimiento(r_gmovi);
         END IF; 
     end if;
   End if;
  End if;
     <<fin_mientras>>
     NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
  -- Retorna el monto del debito
  Return v_imdebit;
EXCEPTION
  when no_data_found then
     raise_application_error(-20000,'No existen datos');
End;

/* Calcula cargos por Sobregiros. */
PROCEDURE PR_LIQ_CAR_SOBREGIROS(p_fecha in ge_calendarios.fec_actual%type,
                                p_nro_cuenta in ge_cuentas.nro_cuenta%type default null)
IS
 -- Variables.
 v_valor           number;
 v_lugar           varchar2(1000);

BEGIN
   --------------------------------------------------
   -- cargos por sobregiro por utilizacion de linea -
   --------------------------------------------------
   v_lugar := p_nro_cuenta||',FU_UTI_LINEA';
   v_valor := FU_UTI_LINEA(p_fecha,p_nro_cuenta,'S');

   -----------------------------------------------------------------------------------------------
   -- cargos por sobregiro por exceso de plazo   > 30 DIAS
   -----------------------------------------------------------------------------------------------
   v_lugar := p_nro_cuenta||'FU_PRO_EXE_PLAZO';
   v_valor := FU_PRO_EXE_PLAZO(p_fecha,p_nro_cuenta,'S');
   
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error en PR_LIQ_CAR_SOBREGIROS : '||v_lugar||'-'|| sqlerrm);
END;

/* Genera el movimiento de los gastos. */
PROCEDURE PR_DEB_CRE_BATCH (P_COD_DEB_CRE IN GE_DEB_CRE_BATCH.COD_DEB_CRE_BATCH%TYPE,
                            P_FECHA IN GE_CALENDARIOS.FEC_ACTUAL%TYPE,
                            P_NRO_CUENTA  IN VARCHAR2 DEFAULT NULL)
IS
   -- Variables.     
   v_fecha          ge_calendarios.fec_actual%type;
   v_hora           cb_sim_movimientos.hora%type := fu_ini_hora(v_fecha);
   v_nro_secuencia  cb_sim_movimientos.nro_secuencia%type;
   v_tra_padre      ge_transacciones.cod_transaccion%type;
   v_transaccion    ge_transacciones.cod_transaccion%type;
   v_mod_padre      ge_transacciones.cod_modulo%type;
   v_mad_padre      ge_transacciones.cod_modalidad%type;
   v_concepto       cb_sim_movimientos.concepto%type;
   v_fcproxi        DATE;
   rv_gcale         ge_calendarios%ROWTYPE;
   --
   v_cuenta         ge_cuentas.nro_cuenta%type;
   v_mto_pago       ge_cuentas.sal_contable%type;
   v_nro_documento  cb_sim_movimientos.nro_documento%type;
   v_nro_documento2 cb_sim_movimientos.nro_documento2%type;
   v_estado         ge_cuentas.estado%type;
   v_tipo           varchar2(1);
   ---
   r_gmovi          cb_sim_movimientos%rowtype;
   v_cod_ofi_origen ba_oficinas.cod_oficina%type;
   v_cod_moneda     varchar2(3);
   v_cod_usuario    varchar2(10) := upper(user);
   v_tip_mov_contra varchar2(1);
   v_sobregiro      ge_deb_cre_batch.sobregiro%type;
   v_cob_parcial    ge_deb_cre_batch.cob_parcial%type;
   v_pendiente      ge_deb_cre_batch.pendiente%type;
   v_pro_error      ge_deb_cre_batch.pro_error%type;
   v_cantidad       number;
   v_mto_mov        cb_sim_movimientos.monto%type;
   v_cod_tas_cargo  cb_sim_movimientos.cod_tasa%type;
   v_val_tas_cargo  cb_sim_movimientos.val_tasa%type;
   v_mto_cargo      cb_sim_movimientos.monto%type;
   v_tra_iva        cb_sim_movimientos.cod_transaccion%type;
   v_cod_tas_iva    cb_sim_movimientos.cod_tasa%type;
   v_val_tas_iva    cb_sim_movimientos.val_tasa%type;
   v_mto_iva        cb_sim_movimientos.monto%type;
   v_sal_disponible cb_sim_movimientos.monto%type;
   v_mto_total      cb_sim_movimientos.monto%type;
   v_mto_tot_cargo  cb_sim_movimientos.monto%type;
   v_lugar          varchar2(3000);
   v_hubo_error     varchar2(1):='N';
   v_cod_error      ge_deb_cre_errores.cod_error%type;
   v_nro_reg        ge_deb_cre_errores.nro_secuencia%type;
   v_cod_mad_cta    cb_sim_movimientos.cod_modalidad%type;
   v_redondeo       number(2);
   v_mto_cargo_par  cb_sim_movimientos.monto%type;
   v_mto_iva_par    cb_sim_movimientos.monto%type;
   v_tip_mov        ge_deb_cre_batch.tip_movimiento%type;
   v_dif_hora       ge_deb_cre_batch.dif_hora%type;
   v_pre_proceso    ge_deb_cre_batch.pre_proceso%type;
   v_pos_proceso    ge_deb_cre_batch.pos_proceso%type;
   v_iva_incluido   ge_deb_cre_batch.iva_incluido%type;
   v_error          varchar2(4000);
   v_val_max_tae    cb_sim_movimientos.monto%type;
   v_cod_mon_local  varchar2(3) := pag_gen.fu_obt_mon_local;
   v_red_mon_local  number(2)   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_mon_local);
   v_cotizacion     ge_cotizaciones.val_conversion%type;
   --
   v_cod_programa   ge_procesos_det.cod_programa%TYPE;
   g_fre_proceso    varchar2(1);
   
   -- Cursor Dinámico.
   TYPE t_tipo_cursor IS REF CURSOR;
   c_cursor    t_tipo_cursor;
   v_sentencia ge_deb_cre_batch.det_sql%type;

--proceso principal
BEGIN
  v_hubo_error     := 'N';
  v_nro_reg        := 0;
  v_fecha          := p_fecha;
  v_fcproxi        := pag_cal.FU_OBT_FEC_SIG_HAB(v_fecha,1);
  v_hora           := fu_ini_hora(v_fecha);
  
  v_nro_secuencia  := -999; --hacer x operación de deb/cred, no x cuenta
  v_lugar := null;
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  --busco oficina origen
  begin
    select cod_oficina
      into v_cod_ofi_origen
      from ba_usuarios
     where cod_usuario = user;
  exception
    when others then
       raise_application_error(20009,'Al recup. oficina del usuario '||sqlerrm);
  end;
  -----------------------------
  --OJO VER PARA PROCESAR 'TODOS' LOS DEBITOS CREDITOS CUANDO NO RECIBE PARAMETRO
  --
  begin
    select tip_movimiento, det_sql,
           cod_transaccion, cod_mod_padre, cod_mad_padre,
           descripcion, cod_transaccion, sobregiro,
           cob_parcial, pendiente, pro_error, dif_hora,
           pre_proceso, pos_proceso, iva_incluido
    into   v_tipo, v_sentencia,
           v_tra_padre, v_mod_padre, v_mad_padre,
           v_concepto, v_transaccion, v_sobregiro,
           v_cob_parcial, v_pendiente, v_pro_error, v_dif_hora,
           v_pre_proceso, v_pos_proceso, v_iva_incluido
    from   GE_DEB_CRE_BATCH
    where  COD_DEB_CRE_BATCH = P_COD_DEB_CRE;
    --agregar order by al query si no tiene, siempre x moneda (posición 3)
    if instr(upper(v_sentencia),'ORDER')= 0 THEN
      v_sentencia := v_sentencia ||' ORDER BY 3';
    end if;
  exception
    when no_data_found then
      v_cod_error := 100; --menores al 100 son del pag_cta.
      v_lugar := 'No existen datos para el Crédito / Débito '||p_cod_deb_cre;
      v_hubo_error := 'S';
      raise_application_error(-20000,v_lugar);
    when others then
      v_cod_error := 100;
      v_lugar := 'Recup.Déb.Créd. '||p_cod_deb_cre || ' - ' ||sqlerrm;
      v_hubo_error := 'S';
      raise_application_error(-20000,v_lugar);
  end;
  --tipo de mov. de contrapartida
  if v_tipo = 'C' then
    v_tip_mov_contra := 'D';
  else
    v_tip_mov_contra := 'C';
  end if;
  --
  g_fre_proceso := 'M';
  --
  v_mto_total := 0;
  v_mto_tot_cargo := 0;
  -----------------------------
  if v_hubo_error = 'N' then
    -- ejecuto proceso previo si existe
    if v_pre_proceso is not null then
        sql_util.ejecute_dml('BEGIN '||v_pre_proceso||'; END;', v_error);
        v_error := replace(v_error,'SQL_UTIL.EJECUTE_DML','*');
        if v_error is not null then
           v_cod_error := 104;
           v_hubo_error := 'S';
           v_lugar := 'Proceso previo '||v_error;
           raise_application_error(-20000,v_lugar);
        end if;
    end if;
    -- 
    v_sentencia := replace(v_sentencia,'&NRO_CUENTA',p_nro_cuenta);
    --
    open c_cursor for v_sentencia;
    loop
      fetch c_cursor into v_cuenta, v_mto_pago, v_cod_moneda, v_cantidad, v_nro_documento, v_nro_documento2;
      exit when c_cursor%notfound;
      v_cotizacion := nvl(pag_gen.fu_obt_cotizacion( v_cod_moneda, v_fecha),1);
      v_nro_reg := v_nro_reg + 1;
      if v_dif_hora = 'S' then
         v_hora := fu_ini_hora(v_fecha);        
      end if;
      pag_cta.pr_set_nro_documento2(v_nro_documento2);
      --limpiar variables
      v_cod_tas_cargo  := 0;
      v_val_tas_cargo  := 0;
      v_mto_cargo      := 0;
      v_tra_iva        := null;
      v_cod_tas_iva    := null;
      v_val_tas_iva    := null;
      v_mto_iva        := 0;
      v_cod_mad_cta    := null;
      v_sal_disponible := 0;
      v_mto_mov        := 0;
      v_mto_cargo_par  := 0;
      v_mto_iva_par    := 0;
      pag_cta.g_sobregira := 'N';
      v_val_max_tae    := 0;
      --verificar monto
      if nvl(v_mto_pago,0) <= 0 then
        v_cod_error := 102;
        v_lugar := 'Monto definido en el SQL debe ser mayor a cero: ' || v_mto_pago;
        v_hubo_error := 'S';
        raise_application_error(-20000,v_lugar); --debe caer el proceso ya que está mal definido
      end if;
      --verificar cantidad
      if v_cantidad <= 0 then
        v_cod_error := 102;
        v_lugar := 'Cantidad definida en el SQL debe ser mayor a cero: ' || v_cantidad;
        v_hubo_error := 'S';
        raise_application_error(-20000,v_lugar); --debe caer el proceso ya que está mal definido
      end if;
      --cantidad sólo permitida para cargos
      if v_cantidad > 0 and v_tipo <> 'G' then
        v_cod_error := 103;
        v_lugar := '''Cantidad'''' sólo válida para Cargos: ' || v_cantidad;
        v_hubo_error := 'S';
        raise_application_error(-20000,v_lugar); --debe caer el proceso ya que está mal definido
      end if;
      --- Recuperar datos de la cuenta
      pag_cta.pr_obt_cuenta(v_cuenta);
      if pag_cta.g_cod_error <> 0 then
        v_cod_error := 104;
        v_lugar := 'Recup. datos de la cuenta ' || v_cuenta || ' - ' ||pag_cta.g_msj_error;
        v_hubo_error := 'S';
        goto siguiente;
      end if;
      v_cod_mad_cta    := pag_cta.g_ctas.cod_modalidad;
      v_sal_disponible := pag_cta.fu_sal_dis_combinada;
      v_estado         := pag_cta.G_CTAS.estado;
      --
      if v_cod_moneda <> pag_cta.g_ctas.cod_moneda then
        v_cod_error := 105;
        v_lugar := 'Moneda de la Cuenta y del SQL diferentes ' || v_cod_moneda || ' - ' ||pag_cta.g_ctas.cod_moneda;
        v_hubo_error := 'S';
        goto siguiente;
      end if;
      --ahorro, cta cte y tarjetas
      if v_cod_mad_cta not in (31,41) and substr(v_cod_mad_cta,1,1) <> 5 then
        v_cod_error := 106;
        v_lugar := 'Modalidad de la Cuenta no permite Déb./Créd. ' || v_cuenta || ' - ' ||v_cod_mad_cta;
        v_hubo_error := 'S';
        goto siguiente;
      end if;
      --redondeo
      v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',v_mod_padre,v_mad_padre,v_cod_moneda);
      --
      v_mto_total := 0;
      v_mto_tot_cargo := 0;
      --determinar el monto del movimiento
      if v_tipo in ('D', 'C') then
        v_mto_mov := v_mto_pago;
        v_tip_mov := v_tipo;
      elsif v_tipo = 'G' then
        v_tip_mov := 'D'; --debe hacer débito
        --es cargo, calcular el monto e impuesto, en base al monto imponible
        begin
          v_lugar := 'cta : '||v_cuenta||' pr_obt_Cargos';
          PAG_CAR.PR_OBT_CARGOS(pag_cta.g_ctas.cod_oficina,v_cuenta,v_cod_moneda,v_mto_pago,pag_cta.G_CTAS.cod_modulo, pag_cta.g_ctas.cod_modalidad,
             v_transaccion, v_iva_incluido,v_cod_tas_cargo, v_val_tas_cargo, v_mto_cargo, v_tra_iva, v_cod_tas_iva, v_val_tas_iva, v_mto_iva);
        exception
          when others then
            v_cod_error := 107;
            v_lugar := sqlerrm;
            v_hubo_error := 'S';
            goto siguiente;
        end;
        -- Para evitar que continue con los pasos siguientes si no hay nada que cobrar...
        if (nvl(v_mto_cargo,0)+ nvl(v_mto_iva,0)) = 0 then
           goto siguiente;
        end if;
        --si tiene cantidad
        if v_cantidad > 0 then
          v_mto_cargo := nvl(v_mto_cargo,0) * v_cantidad; --si tiene cantidad se multiplica
          v_mto_iva := nvl(v_mto_iva,0) * v_cantidad; --si tiene cantidad se multiplica
        end if;

        --Verificar si excede el límite s/ TAE para Sobregiro
        if pag_cta.g_ctas.cod_modulo = 4 and pag_cta.g_ctas.cod_modalidad = 41 then
          v_val_max_tae := fuc_obt_val_max_tae(v_cuenta,pag_cta.g_ctas.cod_modulo,pag_cta.g_ctas.cod_modalidad,v_transaccion,v_mto_cargo);
          if v_mto_cargo > v_val_max_tae then
             v_mto_cargo := v_val_max_tae; 
              --Volver a Calcular el IVA
              v_mto_iva := round(nvl(v_mto_cargo,0)*nvl(v_val_tas_iva,0)/(100),v_redondeo);
          end if;
        end if;
        --monto operación es el cargo + el impuesto
        v_mto_mov := nvl(v_mto_cargo,0) + nvl(v_mto_iva,0);
      end if;

      --si es crédito o si es débito/cargo y el saldo es suficiente, genera el movimiento
      if v_tipo = 'C' or v_sal_disponible >= v_mto_mov then
        if v_tipo = 'G' and v_mto_cargo > 0 then --generar mov x el cargo
          --v_nro_secuencia := v_nro_secuencia + 1;
          --- Actualizar los datos de las cuentas con movimientos.
          if v_nro_Secuencia > 990 then
            v_hora := fu_ini_hora(v_fecha);     
            v_nro_secuencia := -999;
          end if;
          v_lugar := '1- PR_aCT_OPERACION';
          --
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.cod_modulo      := v_mod_padre; --de la transac padre
          r_gmovi.cod_modalidad   := v_mad_padre; --de la transac padre
          r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
          r_gmovi.nro_cuenta      := v_cuenta;
          r_gmovi.cod_moneda      := v_cod_moneda;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fecha;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          --
          r_gmovi.fec_valor       := v_fecha;
          r_gmovi.cod_tra_padre   := v_tra_padre;
          r_gmovi.cod_mod_padre   := v_mod_padre;
          r_gmovi.cod_mad_padre   := v_mad_padre;
          r_gmovi.cod_transaccion := v_transaccion; --si tiene transacción
          r_gmovi.monto           := v_mto_cargo;
          r_gmovi.nro_documento   := v_nro_documento;
          r_gmovi.nro_documento2  := null;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;
          r_gmovi.cod_ofi_origen  := pag_cta.g_ctas.cod_oficina;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := v_concepto;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.nro_caja        := null;
          r_gmovi.cod_rubro       := null; 
          r_gmovi.tip_mov_rubro   := null;          
          r_gmovi.cod_tasa        := v_cod_tas_cargo;
          r_gmovi.val_tasa        := v_val_tas_cargo;
          IF r_gmovi.cod_moneda <> v_cod_mon_local THEN 
             r_gmovi.cotizacion      := v_cotizacion;
             r_gmovi.mto_equ_local   := round((v_mto_cargo * v_cotizacion),v_red_mon_local);
          ELSE
             r_gmovi.cotizacion      := null;
             r_gmovi.mto_equ_local   := null;          
          END IF;
          -- Inserta los registros.
          PR_INS_GE_MOVIMIENTO(r_gmovi); 
          --          
          if v_mto_iva > 0 then --generar movimiento x el iva
            --- Actualizar los datos de las cuentas con movimientos.
            if v_nro_Secuencia > 990 then
              v_hora := fu_ini_hora(v_fecha);      
              v_nro_secuencia := -999;
            end if;
            --
            v_lugar := '2- PR_ACT_OPERACION';
            --
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.cod_modulo      := v_mod_padre; --de la transac padre
            r_gmovi.cod_modalidad   := v_mad_padre; --de la transac padre
            r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
            r_gmovi.nro_cuenta      := v_cuenta;
            r_gmovi.cod_moneda      := v_cod_moneda;
            r_gmovi.cod_usuario     := v_cod_usuario;
            r_gmovi.hora            := v_hora;
            r_gmovi.fecha           := v_fecha;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            --
            r_gmovi.fec_valor       := v_fecha;
            r_gmovi.cod_tra_padre   := v_tra_iva;
            r_gmovi.cod_mod_padre   := v_mod_padre;
            r_gmovi.cod_mad_padre   := v_mad_padre;
            r_gmovi.cod_transaccion := v_tra_iva; --si tiene transacción
            r_gmovi.monto           := v_mto_iva;
            r_gmovi.nro_documento   := v_nro_documento;
            r_gmovi.nro_documento2  := null;
            r_gmovi.cod_tasa        := null;
            r_gmovi.val_tasa        := null;
            r_gmovi.cotizacion      := null;
            r_gmovi.cod_ofi_origen  := pag_cta.g_ctas.cod_oficina;
            r_gmovi.emi_aviso       := 'N';
            r_gmovi.concepto        := v_concepto;
            r_gmovi.estado          := 'N';
            r_gmovi.reversado       := 'N';
            r_gmovi.nro_caja        := null;
            r_gmovi.cod_rubro       := null; 
            r_gmovi.tip_mov_rubro   := null;
            r_gmovi.cod_tasa        := v_cod_tas_iva;
            r_gmovi.val_tasa        := v_val_tas_iva;
            IF r_gmovi.cod_moneda <> v_cod_mon_local THEN 
             r_gmovi.cotizacion      := v_cotizacion;
             r_gmovi.mto_equ_local   := round((v_mto_cargo * v_cotizacion),v_red_mon_local);
          ELSE
             r_gmovi.cotizacion      := null;
             r_gmovi.mto_equ_local   := null;          
          END IF;
            -- Inserta los registros.
            PR_INS_GE_MOVIMIENTO(r_gmovi); 
            --
          end if;
        else --generar mov x el monto del movimiento
          --v_nro_secuencia := v_nro_secuencia + 1;
          --- Actualizar los datos de las cuentas con movimientos.
          if v_nro_Secuencia > 990 then
            v_hora := fu_ini_hora(v_fecha);        
            v_nro_secuencia := -999;
          end if;
          v_lugar := '3- PR_ACT_OPERACION';
          --
          v_nro_secuencia         := v_nro_secuencia + 1;
          r_gmovi.cod_modulo      := v_mod_padre; --de la transac padre
          r_gmovi.cod_modalidad   := v_mad_padre; --de la transac padre
          r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
          r_gmovi.nro_cuenta      := v_cuenta;
          r_gmovi.cod_moneda      := v_cod_moneda;
          r_gmovi.cod_usuario     := v_cod_usuario;
          r_gmovi.hora            := v_hora;
          r_gmovi.fecha           := v_fecha;
          r_gmovi.nro_secuencia   := v_nro_secuencia;
          --
          r_gmovi.fec_valor       := v_fecha;
          r_gmovi.cod_tra_padre   := v_tra_padre;
          r_gmovi.cod_mod_padre   := v_mod_padre;
          r_gmovi.cod_mad_padre   := v_mad_padre;
          r_gmovi.cod_transaccion := v_transaccion; --si tiene transacción
          r_gmovi.monto           := v_mto_mov;
          r_gmovi.nro_documento   := v_nro_documento;
          r_gmovi.nro_documento2  := null;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          r_gmovi.cotizacion      := null;
          r_gmovi.cod_ofi_origen  := pag_cta.g_ctas.cod_oficina;
          r_gmovi.emi_aviso       := 'N';
          r_gmovi.concepto        := v_concepto;
          r_gmovi.estado          := 'N';
          r_gmovi.reversado       := 'N';
          r_gmovi.nro_caja        := null;
          r_gmovi.cod_rubro       := null; 
          r_gmovi.tip_mov_rubro   := null;
          r_gmovi.cod_tasa        := null;
          r_gmovi.val_tasa        := null;
          IF r_gmovi.cod_moneda <> v_cod_mon_local THEN 
             r_gmovi.cotizacion      := v_cotizacion;
             r_gmovi.mto_equ_local   := round((v_mto_cargo * v_cotizacion),v_red_mon_local);
          ELSE
             r_gmovi.cotizacion      := null;
             r_gmovi.mto_equ_local   := null;          
          END IF;
          -- Inserta los registros.
          PR_INS_GE_MOVIMIENTO(r_gmovi); 
          --
        end if; --cargo o crédito/débito
        --
      end if;
      -- Fin movimientos de cuentas
      -- Siguiente registro
      <<siguiente>>
      null;
    end loop; --hasta aquí procesamiento de cuentas    
  end if;
exception
  when others then
      raise_application_error(-20000,'Deb.Cre.Batch. - Lugar : '||v_lugar||' Cta : '||v_cuenta||' - '||sqlerrm);
END;

/* Comisiones de retención de extracto por cliente. */
PROCEDURE PR_GEN_COM_RET_EXTRACTO(p_fecha in ge_calendarios.fec_actual%type) IS
BEGIN
   PR_DEB_CRE_BATCH('17',p_fecha);
EXCEPTION
   WHEN OTHERS THEN 
      raise_application_error(-20000,'Deb.Cre.Batch. - PR_GEN_COM_RET_EXTRACTO : '||' - '||sqlerrm);
END;

/* Comisiones por mantenimiento cliente Vip.. */
PROCEDURE PR_GEN_COM_CLI_VIP(p_fecha in ge_calendarios.fec_actual%type) IS
BEGIN
   PR_DEB_CRE_BATCH('20',p_fecha);
EXCEPTION
   WHEN OTHERS THEN 
      raise_application_error(-20000,'Deb.Cre.Batch. - PR_GEN_COM_CLI_VIP : '||' - '||sqlerrm);
END;

/* Comisiones por mantenimiento - Empresario 360. */
PROCEDURE PR_GEN_COM_CLI_360(p_fecha in ge_calendarios.fec_actual%type) IS
BEGIN
   PR_DEB_CRE_BATCH('16',p_fecha);
EXCEPTION
   WHEN OTHERS THEN 
      raise_application_error(-20000,'Deb.Cre.Batch. - PR_GEN_COM_CLI_360 : '||' - '||sqlerrm);
END;

/* Comisiones por mantenimiento - Empresario 360. */
PROCEDURE PR_GEN_COM_BAN_PERSONAL(p_fecha in ge_calendarios.fec_actual%type) IS
BEGIN
   PR_DEB_CRE_BATCH('25',p_fecha);
EXCEPTION
   WHEN OTHERS THEN 
      raise_application_error(-20000,'Deb.Cre.Batch. - PR_GEN_COM_BAN_PERSONAL : '||' - '||sqlerrm);
END;

/* Calcula del Devengamiento de Cargos Diferidos. */
PROCEDURE PR_CAL_DEV_COMISIONES(p_fecha in ge_calendarios.fec_actual%type)
IS
   -- Variables.
   v_fec_actual  date := p_fecha;
   v_fec_proceso date;
   ---
   cursor rg_movi is
   select decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local) monto,
          b.fec_inicio, b.fec_vencimiento, b.fec_ult_proceso,
          b.mto_dev_anterior, b.mto_dev_actual, b.mto_dev_acumulado,
          b.estado, b.can_dia_actual, b.can_dia_anterior,
          b.cod_modulo, b.cod_mov_diferido, b.cod_moneda,
          c.estado est_cuenta
   from   cb_sim_mov_diferidos b, ge_cuentas c
   where((b.mto_dev_acumulado < decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local)
   and    b.estado <> 'R') or (b.estado = 'R' and (b.mto_dev_acumulado <> b.mto_dev_actual))) 
   and    b.nro_cuenta = c.nro_cuenta
   and    b.fecha < v_fec_actual
   and    b.fec_inicio <= v_fec_actual -- agregado para cuentas migradas
   --- Reversar el devengado de la cancelación por de la cuenta
   --- Para las cuentas que reversaron su cancelación
   union
   select decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local) monto,
          b.fec_inicio, b.fec_vencimiento, b.fec_ult_proceso,
          b.mto_dev_anterior, b.mto_dev_actual, b.mto_dev_acumulado,
          b.estado, b.can_dia_actual, b.can_dia_anterior,
          b.cod_modulo, b.cod_mov_diferido, b.cod_moneda,
          c.estado est_cuenta
   from   cb_sim_mov_diferidos b, ge_cuentas c
   where  b.mto_dev_acumulado >= decode(b.cod_moneda,pag_gen.FU_OBT_MON_LOCAL,b.monto,b.mto_equ_local)
   and    b.nro_cuenta = c.nro_cuenta
   and    b.fec_vencimiento > v_fec_actual
   and    b.fecha < v_fec_actual
   and    b.fec_inicio <= v_fec_actual -- agregado para cuentas migradas
   and  ((c.estado <> 'C' and c.cod_modulo in (3,4,5,7,8,15))
      or (c.estado <> 'N' and c.cod_modulo in (6,10)));
   ---
   v_fec_calculo       date;
   v_can_dia_anterior  cb_sim_mov_diferidos.can_dia_anterior%type;
   v_can_dia_actual    cb_sim_mov_diferidos.can_dia_actual%type;
   v_mto_dev_anterior  cb_sim_mov_diferidos.mto_dev_anterior%type;
   v_mto_dev_actual    cb_sim_mov_diferidos.mto_dev_actual%type;
   v_mto_dev_acumulado cb_sim_mov_diferidos.mto_dev_acumulado%type;
   v_can_tot_dias      number;
   v_estado            cb_sim_mov_diferidos.estado%type;
begin
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   -- Inserto los registros de la tabla actual.
   BEGIN
      INSERT INTO cb_sim_mov_diferidos SELECT * FROM ge_mov_diferidos;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,'Error en PR_CAL_DEV_COMISIONES - Insertar datos de ge_mov_diferidos: '||'-'|| sqlerrm);
   END;
   -- Obtiene las fecha para el devengamiento.
   pag_cal.pr_obt_dat_calendar(2);
   v_fec_proceso := pag_cal.g_ult_dia_mes;
   -- Actualizo el devengado.
   for i in rg_movi loop
      if i.estado = 'N' then
         v_can_dia_anterior := i.can_dia_actual;
         v_mto_dev_anterior := i.mto_dev_actual;
         v_can_tot_dias     := i.fec_vencimiento - i.fec_inicio;
         v_can_dia_actual   := 0;
         v_mto_dev_actual := 0;
         --- Cuentas canceladas deben devengar totalmente
         if (i.est_cuenta = 'C' and i.cod_modulo in (3,4,5,7,8,15))
         or (i.est_cuenta = 'N' and i.cod_modulo in (6,10))
         or v_fec_proceso > i.fec_vencimiento then
            v_fec_calculo := i.fec_vencimiento;
         else
            v_fec_calculo := v_fec_proceso;
         end if;
         ---
         v_can_dia_actual := v_fec_calculo - nvl(i.fec_ult_proceso,i.fec_inicio);
			---
         if v_can_dia_actual > 0 then
            v_mto_dev_actual := round(i.monto / v_can_tot_dias * v_can_dia_actual,0);
            -- Se verifica si corresponde a una reversión
            if i.mto_dev_acumulado >= i.monto and
               i.fec_vencimiento > v_fec_proceso then
               i.mto_dev_acumulado := i.mto_dev_acumulado - i.mto_dev_actual;
               v_estado := 'C';
            else
               v_estado := 'N';
            end if;
            -- para redondear correctamente en el último devengado
            if (i.mto_dev_acumulado + v_mto_dev_actual) > i.monto then
               v_mto_dev_actual := i.monto - i.mto_dev_acumulado;
            end if;
            ---
            v_mto_dev_acumulado := i.mto_dev_acumulado + v_mto_dev_actual;
            ---
            update cb_sim_mov_diferidos
            set    can_dia_anterior  = v_can_dia_anterior,
                   can_dia_actual    = v_can_dia_actual,
                   mto_dev_anterior  = v_mto_dev_anterior,
                   mto_dev_actual    = v_mto_dev_actual,
                   mto_dev_acumulado = v_mto_dev_acumulado,
                   estado            = v_estado,
                   fec_ult_proceso   = v_fec_actual
            where  cod_mov_diferido  = i.cod_mov_diferido;
         end if;
      elsif i.estado = 'R' then
         if i.monto > i.mto_dev_acumulado then
            update cb_sim_mov_diferidos
            set    mto_dev_actual    = mto_dev_acumulado,
                   fec_ult_proceso   = v_fec_actual
            where  cod_mov_diferido  = i.cod_mov_diferido;
         end if;
      end if;
   end loop;
end;

/* Agrupa las Transacciones para generar los asientos contables. */
PROCEDURE PR_CON_TRANSACCION(p_fecha in ge_calendarios.fec_actual%type)
IS

-- Variables.
v_cod_modulo         cb_sim_movimientos.cod_modulo%type;
v_cod_modalidad      cb_sim_movimientos.cod_modalidad%type;
v_fecha              cb_sim_movimientos.fecha%type;
v_cod_mad_padre      cb_sim_movimientos.cod_mad_padre%type;
v_cod_transaccion    cb_sim_movimientos.cod_transaccion%type;
v_cod_moneda         cb_sim_movimientos.cod_moneda%type;
v_cod_ofi_origen     cb_sim_movimientos.cod_ofi_origen%type;
v_afecta             ge_transacciones.afecta%type;
v_detalle            ge_transacciones.tipo%type;
v_residente          ge_tip_deudores.ind_residente%type;
v_cod_sector         ge_tip_asientos.cod_sec_contable%type;
v_tip_deudor         ge_tip_deudores.cod_tip_deudor%type;
v_cod_plazo          ge_plz_contables.cod_plazo%type;
v_can_dias           ge_plz_contables.can_dias%type;
v_cod_oficina        cb_sim_movimientos.cod_oficina%type;
v_nro_cuenta         cb_sim_movimientos.nro_cuenta%type;
v_monto              cb_sim_movimientos.monto%type;
v_mto_equ_local      cb_sim_movimientos.mto_equ_local%type;
v_est_cuenta         cb_sim_movimientos.est_cuenta%type;
v_fec_valor          cb_sim_movimientos.fec_valor%type;
v_cod_tra_padre      cb_sim_movimientos.cod_tra_padre%type;
v_reversado          cb_sim_movimientos.reversado%type;
v_est_movimiento     cb_sim_movimientos.estado%type;
v_cod_mod_padre      cb_sim_movimientos.cod_mod_padre%type;
v_cod_mon_local      ba_monedas.cod_moneda%type;
v_nro_documento2     cb_sim_movimientos.nro_documento2%type;
v_usu_insercion      cb_sim_movimientos.usu_insercion%type;
v_cod_sit_contable   cb_sim_movimientos.cod_sit_contable%type;
v_cod_tip_referencia lc_ope_futuras.cod_tip_referencia%type;
v_nro_ref_cambio     cb_sim_movimientos.nro_documento2%type;
v_tip_cuenta         cb_sim_con_transacciones.tip_cuenta%type;
v_tip_interes        cb_sim_con_transacciones.tip_interes%type;
v_tip_renovacion     cb_sim_con_transacciones.tip_renovacion%type;
v_cat_automatica     cb_sim_con_transacciones.cat_automatica%type;
v_concepto           cb_sim_con_transacciones.concepto%type;
v_cod_persona        cb_sim_movimientos.cod_persona%type;
v_cod_usuario        cb_sim_movimientos.cod_usuario%type;
v_hora               cb_sim_movimientos.hora%type;
v_referencia         cb_sim_movimientos.referencia%type;
v_cod_tra_pre_tar    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_TRA_PRE_TARJETAS');
v_tra_fila           varchar2(100);
v_nom_rutina1        varchar2(1000);
v_mov_fila           varchar2(100);
v_hay_error          varchar2(1);
v_msj_error          varchar2(150);
v_detallado          varchar2(1);
v_cod_rubro          varchar2(20);
v_cod_sec_rubro      varchar2(3);
v_nro_secuencia      number;
v_nro_registros      number := 0;
v_err_cliente        number(1);
v_sig_nro_referencia number(7);
v_nro_referencia     number(7);
 
-- Cursores.
CURSOR CURSOR1 IS
   SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, nvl(MONTO,0),
          EST_CUENTA, FEC_VALOR, COD_TRA_PADRE, REVERSADO, ESTADO,
          COD_MOD_PADRE, COD_MAD_PADRE, COD_TRANSACCION, COD_MONEDA, COD_OFI_ORIGEN,
          MTO_EQU_LOCAL, NRO_DOCUMENTO2, USU_INSERCION, rowid,
          COD_SIT_CONTABLE, CONCEPTO,
          COD_PERSONA, cod_ref_cambio, nro_documento2,
          cod_usuario, hora, referencia, nro_secuencia,
          cod_rubro
     FROM CB_SIM_MOVIMIENTOS
    WHERE /*COD_MODULO IN (1,2,3,4,5,6,7,8,9,10,13,14,15,16,26,28,30,31) AND*/ COD_TRANSACCION > 0
      AND ESTADO = 'N'
    ORDER BY FEC_INSERCION, NRO_SECUENCIA;


/* Obtiene el código de plazo a partir de la cantidad de días. */
PROCEDURE LP_OBT_COD_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 );
 
/* Obtiene el código de plazo a partir de la cantidad de días. */
PROCEDURE LP_OBT_COD_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 )
 IS
BEGIN
  SELECT COD_PLAZO
    INTO p_cod_plazo
    FROM GE_PLZ_CONTABLES
   WHERE CAN_DIAS = (SELECT MIN(CAN_DIAS)
                       FROM GE_PLZ_CONTABLES
                      WHERE CAN_DIAS >= p_can_dias);
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'En lp_obt_cod_plazo '||SQLERRM);
END;
/* Procedimiento Equivalente Moneda Local */
PROCEDURE LP_EQU_MON_LOCAL
 IS

V_MTO_COTIZACION GE_COTIZACIONES.VAL_CONVERSION%TYPE;
V_COD_MONEDA BA_MONEDAS.COD_MONEDA%TYPE;
CURSOR c_movimientos IS
   SELECT DISTINCT COD_MONEDA
     FROM CB_SIM_MOVIMIENTOS
    WHERE COD_MONEDA <> v_cod_mon_local
      AND MTO_EQU_LOCAL IS NULL;
BEGIN

   OPEN c_movimientos;
   LOOP
      FETCH c_movimientos INTO v_cod_moneda;
         EXIT WHEN c_movimientos%NOTFOUND;
         ---------------------------------------------------------
         -----      LEER COTIZACION
         ---------------------------------------------------------
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fecha);
         ----------------------------------------------------------
         -------- ACTUALIZA CB_SIM_MOVIMIENTOS CON EL IMPORTE EQUIVALENTE GS.
         ----------------------------------------------------------
         UPDATE CB_SIM_MOVIMIENTOS
            SET MTO_EQU_LOCAL = round(nvl(MONTO,0)*v_mto_cotizacion,0),
                COTIZACION = v_mto_cotizacion
          WHERE COD_MONEDA = v_cod_moneda
            AND MTO_EQU_LOCAL IS NULL;
   END LOOP;
   IF c_movimientos%ISOPEN THEN
      CLOSE c_movimientos;
   END IF;
END;
BEGIN
   v_err_cliente   := 0;
   v_fecha         := p_fecha;
   v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
   v_msj_error     := ' ';
   ---1. Cerando los posibles registro del dia, si existen----------
   DELETE FROM CB_SIM_CON_TRANSACCIONES;
   ---2. Actualizo el nro_documento4 que es la referencia del asiento
   update CB_SIM_MOVIMIENTOS set nro_documento4 = null where nro_documento4 is not null;
   
   commit;  -- esto se hace para liberar recursos luego de inicializar las tablas

   ---2. Leo el sgte. nro. de referencia del GE_PAR_GENERALES ---------------
   v_sig_nro_referencia := fug_obt_pardinamico('SIG_NRO_REF_BALANCE',v_cod_modulo, v_cod_modalidad, v_cod_oficina,v_cod_moneda);
   ---3. Leyendo los datos del diario (CB_SIM_MOVIMIENTOS) y act.cb_sim_con_transacciones-------
   IF cursor1%ISOPEN THEN
      CLOSE cursor1;
   END IF;
   OPEN cursor1;
   LOOP
      v_cod_sec_rubro := 'N'; -- dato por defecto 
      --- leo el registro del CB_SIM_MOVIMIENTOS --------------------------------
      FETCH cursor1
     INTO  v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_nro_cuenta, v_monto,
            v_est_cuenta, v_fec_valor, v_cod_tra_padre, v_reversado, v_est_movimiento,
            v_cod_mod_padre, v_cod_mad_padre, v_cod_transaccion, v_cod_moneda, v_cod_ofi_origen,
            v_mto_equ_local, v_nro_documento2, v_usu_insercion, v_mov_fila,
            v_cod_sit_contable, v_concepto, v_cod_persona, v_cod_tip_referencia, V_NRO_REF_cambio,
            v_cod_usuario, v_hora, v_referencia, v_nro_secuencia,
            v_cod_rubro;
      EXIT WHEN cursor1%NOTFOUND;
      v_nro_registros := v_nro_registros + 1;
      --- asigno valores por defecto, por si exista cuenta cliente ---
      v_residente  := 'S';
      v_cod_sector := 'N';
      v_tip_deudor := '2';
      v_cod_plazo  := 0;
      v_tip_cuenta := NULL;
      --v_est_cuenta := null;
      v_tip_interes := null;
      v_tip_renovacion := null;
      v_cat_automatica := null;
      v_can_dias := null;
      --- Comun a todos los modulos-----------------------------------
      v_hay_error  := 'N';
      BEGIN
          SELECT upper(rtrim(RUTINA1)),
                 TIPO, AFECTA, nvl(detallado,'N')
            INTO v_nom_rutina1, v_detalle, v_afecta, v_detallado
            FROM GE_TRANSACCIONES
           WHERE COD_TRANSACCION = v_cod_transaccion
             AND COD_MODULO = v_cod_modulo
             AND COD_MODALIDAD = v_cod_modalidad;
      EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_hay_error := 'S';
            raise_application_error(-20000,'Trans. no existe '||to_char(v_cod_modulo)||' '
                                    ||to_char(v_cod_modalidad)||' '||TO_CHAR(v_cod_transaccion));
           UPDATE CB_SIM_MOVIMIENTOS
           SET    ESTADO = 'E'
           WHERE rowid = v_mov_fila;
      END;
      if v_cod_rubro is not null then
         v_detallado := 'S'; -- siempre que haya rubro en el movimiento debe si o si ser detallado
      end if;
      v_err_cliente := 0;
      IF v_hay_error = 'N' THEN
         --- busco el cliente principal de la cuenta ------------------
          IF v_cod_modulo = 7 and v_nro_ref_cambio is not null and v_nro_cuenta is null then
             BEGIN
             SELECT FEC_VENCIMIENTO - FEC_OPERACION
                INTO v_can_dias
              FROM LC_OPE_FUTURAS
             WHERE cod_tip_referencia = v_cod_tip_referencia
               and nro_referencia = v_nro_ref_cambio;
               lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
             EXCEPTION
                WHEN no_data_found then
                   null;
               END;
            IF v_cod_persona is not null then
            -- el movimiento tiene persona identificada, se puede buscar los datos del cliente
              BEGIN
                SELECT GE_CLIENTES.RESIDENTE,GE_CLIENTES.COD_SEC_CONTABLE,
                GE_CLIENTES.COD_TIP_DEUDOR
                  INTO v_residente, v_cod_sector, v_tip_deudor
                  FROM GE_CLIENTES
                 WHERE GE_CLIENTES.COD_PERSONA = v_cod_persona;
              EXCEPTION
                 WHEN OTHERS THEN
                      v_residente  := 'S';
                      v_cod_sector := 'N';
                      v_tip_deudor := '2';
              END;
            END IF;
         ELSIF v_nro_cuenta IS NOT NULL THEN
             BEGIN
                 SELECT GE_CLIENTES.RESIDENTE,
                        GE_CLIENTES.COD_SEC_CONTABLE,
                        GE_CLIENTES.COD_TIP_DEUDOR
                   INTO v_residente, v_cod_sector, v_tip_deudor
                   FROM GE_CLIENTES,GE_CTA_CLIENTES
                  WHERE GE_CTA_CLIENTES.NRO_CUENTA  = v_nro_cuenta
                    AND GE_CTA_CLIENTES.RELACION = 'P'
                    AND GE_CLIENTES.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA
                    AND GE_CTA_CLIENTES.COD_MODULO = v_cod_modulo
                    AND GE_CTA_CLIENTES.COD_MODALIDAD = v_cod_modalidad;
             EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                     raise_application_error(-20000,'Cta.sin Cliente Principal : '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                     v_err_cliente := 1;
                 WHEN TOO_MANY_ROWS THEN
                     raise_application_error(-20000,'Cta.con Clie.Princ. duplicado: '||v_nro_cuenta||' Modulo '||v_cod_modulo||' Modal '||v_cod_modalidad||' Ofi '||v_cod_oficina);
                     v_err_cliente := 2;
             END;
             -- si no hubo error en la busqueda de la Clte Principal---
             IF v_err_cliente = 0 THEN
                IF v_cod_modalidad in (32,37,38) THEN
                   --Busqueda del Plazo de la Cuentas plazo fijo y CDA.---
                        SELECT FEC_VENCIMIENTO - FEC_APERTURA
                         INTO v_can_dias
                         FROM AH_CTA_PLAZOS
                        WHERE NRO_CUENTA = v_nro_cuenta;
                          lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                ELSIF v_cod_modalidad in (33,34,35,36) THEN
                       SELECT FEC_VENCIMIENTO - FEC_APERTURA
                         INTO v_can_dias
                         FROM AH_CTA_CERTIFICADOS
                        WHERE NRO_CUENTA = v_nro_cuenta;
                          lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                END IF;
                --si es prestamo calculo el plazo entre las fechas
                IF v_cod_modulo = 6 THEN
                   BEGIN
                   SELECT FEC_VENCIMIENTO - FEC_INICIO,
                          tipo, tip_interes, nvl(tip_renovacion,'A'),
                          nvl(v_est_cuenta,estado), FUP_OBT_SEC_RUBRO(cod_sec_credito)
                    INTO v_can_dias, v_tip_cuenta, v_tip_interes,
                         v_tip_renovacion, v_est_cuenta, v_cod_sec_rubro
                    FROM PR_CTA_PRESTAMOS
                   WHERE NRO_CUENTA = v_nro_cuenta;
                     lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   EXCEPTION
                      WHEN no_data_found then
                         RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||v_nro_cuenta);
                     END;
                END IF;

                --si es MD calculo el plazo entre las fechas
                IF v_cod_modulo = 10 THEN
                   BEGIN
                   SELECT NVL(FEC_VENCIMIENTO - FEC_INICIO,0),
                          tip_calculo,
                          nvl(v_est_cuenta,estado)
                    INTO v_can_dias, v_tip_interes,
                         v_est_cuenta
                    FROM MD_CTA_DOCUMENTOS
                   WHERE NRO_CUENTA = v_nro_cuenta;
                     lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                   EXCEPTION
                      WHEN no_data_found then
                         RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||v_nro_cuenta);
                     END;
                END IF;
                if v_cod_sit_contable is null then
                  begin
                   select cod_sit_contable
                     into v_cod_sit_contable
                     from ge_cuentas
                    where nro_cuenta = v_nro_cuenta;
                  exception
                     when no_data_found then
                          RAISE_APPLICATION_ERROR(-20000,'Cuenta no existe en ge_cuentas '||v_nro_cuenta);
                  end;
                end if;
                --
                if v_cod_modulo = 5 then
                   --Se cambia debido a que siempre toma el rubro solamente para la categoria actual
                   --y para las transacciones 944 y 946 se desea tomar según lo registrado con el movimiento--CN 25/04/2004--
                   --para que el cambio afecte solamente a estas transacciones
                   if instr(v_cod_tra_pre_tar,','||v_cod_transaccion||',') = 0 then
                   --- Para la parametrizacion contable el estado de la tarjeta
                   --- se hace igual que el prestamo
                   select decode(t.cat_automatica,'1','C',
                          '2','V','3','G','4','M','M') estado
                     into v_est_cuenta
                     from ta_cta_tarjetas t
                    where t.nro_cuenta = V_NRO_CUENTA;
                   end if;
                end if;
                ------------------------------------------------------
                if v_cod_modulo in (4,5,6) then
                   --- Verifico categoria
                   begin
                      select fup_obt_categoria(c.cat_automatica,c.cat_subjetiva)
                        into v_cat_automatica
                        from ge_clientes c, ge_cta_clientes cc
                       where c.cod_persona = cc.cod_persona
                         and cc.relacion = 'P'
                         and cc.nro_cuenta = v_nro_cuenta;
                   exception
                      when no_data_found then
                         v_cat_automatica := 1;
                   end;
                   --- Recuperar categoria para valuaciones
                   if v_cod_modulo = 6 and v_cod_tra_padre = 150 then
                      if v_nro_documento2 is not null then
                         --- El movimiento trae categoria
                         v_cat_automatica := v_nro_documento2;
                      end if;
                   end if;
                end if;
             END IF;
         ELSIF v_cod_persona is not null then
             -- el movimiento tiene persona identificada, se puede buscar los datos del cliente
             BEGIN
                 SELECT GE_CLIENTES.RESIDENTE,
                        GE_CLIENTES.COD_SEC_CONTABLE,
                        GE_CLIENTES.COD_TIP_DEUDOR
                   INTO v_residente, v_cod_sector, v_tip_deudor
                   FROM GE_CLIENTES
                  WHERE GE_CLIENTES.COD_PERSONA = v_cod_persona;
             EXCEPTION
                 WHEN OTHERS THEN
                      v_residente  := 'S';
                      v_cod_sector := 'N';
                      v_tip_deudor := '2';
             END;
         END IF;
        IF v_err_cliente = 0 AND v_detalle IN ('C','D') THEN
                 --- Busco si existe en Nro. de Referencia del cb_sim_con_transacciones--------
                 BEGIN
                 if v_detallado = 'S' then
                    raise no_data_found;
                 else   
                   SELECT /*+ INDEX(cb_sim_con_transacciones IN_GCTRA_FECHA1)*/ NRO_REFERENCIA,rowid
                     INTO v_nro_referencia,v_tra_fila
                     FROM CB_SIM_CON_TRANSACCIONES
                    WHERE FECHA           = v_fecha
                      AND COD_MOD_PADRE   = v_cod_mod_padre
                      AND COD_MAD_PADRE   = v_cod_mad_padre
                      AND COD_OFI_ORIGEN  = v_cod_ofi_origen
                      AND COD_OFICINA     = v_cod_oficina
                      AND COD_MONEDA      = v_cod_moneda
                      AND COD_MODULO      = v_cod_modulo
                      AND COD_MODALIDAD   = v_cod_modalidad
                      AND COD_TRANSACCION = v_cod_transaccion
                      AND COD_SECTOR      = v_cod_sector
                      AND COD_TIP_DEUDOR  = v_tip_deudor
                      AND RESIDENTE       = v_residente
                      AND COD_PLAZO       = v_cod_plazo
                      AND REVERSADO       = v_reversado
                      AND nvl(est_cuenta,'X')     = nvl(v_est_cuenta,'X')
                      AND nvl(tip_cuenta,'X')     = nvl(v_tip_cuenta,'X')
                      AND nvl(tip_interes,'X')    = nvl(v_tip_interes,'X')
                      AND nvl(tip_renovacion,'X') = nvl(v_tip_renovacion,'X')
                      AND nvl(cat_automatica,'9') = nvl(v_cat_automatica,'9')
                      and nvl(cod_sit_contable,-1) = nvl(v_cod_sit_contable,-1)
                      and (nvl(v_detallado,'N') = 'N' and concepto is null)
                      and cod_sec_rubro = nvl(v_cod_sec_rubro,'N');
                   if v_cod_moneda != v_cod_mon_local and nvl(v_mto_equ_local, 0) = 0 then
                      v_mto_equ_local := round(nvl(v_monto,0) * pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fecha),0);
                   end if;
                   -- actualizo el registro del cb_sim_con_transacciones.-------------------
                   UPDATE CB_SIM_CON_TRANSACCIONES
                      SET CANTIDAD = NVL(CANTIDAD,0)+1,
                          TOTAL = NVL(TOTAL,0)+NVL(v_monto,0),
                          TOT_MON_LOCAL = nvl(TOT_MON_LOCAL,0) + nvl(v_mto_equ_local,0)
                    WHERE ROWID = v_tra_fila;
                 end if;   
                   --------------------------------------------------------
                 EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                      -- asigno sgte.valor al Nro.Ref e incremento contador--
                      v_nro_referencia := v_sig_nro_referencia;
                      v_sig_nro_referencia := nvl(v_sig_nro_referencia,0) + 1;
                       if v_cod_moneda != v_cod_mon_local and nvl(v_mto_equ_local, 0) = 0 then
                          v_mto_equ_local := round(nvl(v_monto,0) * pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fecha),0);
                       end if;
                      -- para interfaz con la as/400
                      if v_detallado = 'S' then
                          begin
                            v_concepto := substr(nvl(fub_obt_referencia(v_mov_fila),v_concepto),1,100);
                          exception
                             when others then
                                v_concepto := null;
                          end;
                      end if;

                      -- no existe registro, se debe generar ----------------
                      INSERT INTO CB_SIM_CON_TRANSACCIONES
                          (FECHA,COD_MOD_PADRE,COD_MAD_PADRE,COD_OFI_ORIGEN,
                           COD_OFICINA,COD_MONEDA,COD_MODULO,COD_MODALIDAD,
                           COD_TRANSACCION,COD_SECTOR,COD_TIP_DEUDOR,RESIDENTE,
                           COD_PLAZO,CANTIDAD,TOTAL,TOT_MON_LOCAL,
                           est_cuenta, tip_cuenta, tip_interes, tip_renovacion,
                           cat_automatica, NRO_REFERENCIA, cod_sit_contable,
                           nro_cuenta, concepto, cod_sec_rubro, REVERSADO)
                       VALUES
                          (v_fecha,v_cod_mod_padre,v_cod_mad_padre,v_cod_ofi_origen,
                           v_cod_oficina,v_cod_moneda,v_cod_modulo,v_cod_modalidad,
                           v_cod_transaccion,v_cod_sector,v_tip_deudor,v_residente,
                           v_cod_plazo,1         ,v_monto,v_mto_equ_local,
                           v_est_cuenta, v_tip_cuenta, v_tip_interes, v_tip_renovacion,
                           v_cat_automatica, v_nro_referencia, v_cod_sit_contable,
                           decode(v_detallado,'S',v_nro_cuenta, null),
                           decode(v_detallado,'S',v_concepto, null),
                           nvl(v_cod_sec_rubro,'N'), v_reversado); 
                         ------------------------------------------------------
                    WHEN TOO_MANY_ROWS THEN
                       v_hay_error := 'S';
                        raise_application_error(-20000,'Reg. dup. cb_sim_con_transacciones '||
                       to_char(v_fecha,'dd/mm/yyyy')||'-op:'||v_cod_mod_padre||'-ap:'||
                       v_cod_mad_padre||'-oo:'||v_cod_ofi_origen||'-of:'||v_cod_oficina||'-mn:'||
                       v_cod_moneda||'-mo:'||v_cod_modulo||'-cm:'||v_cod_modalidad||'-ct:'||
                       v_cod_transaccion||'-cs:'||v_cod_sector||'-td:'||v_tip_deudor||'-r:'||
                       v_residente||'-cp:'||v_cod_plazo||'-ec:'||v_est_cuenta||'-tc:'||
                       v_tip_cuenta||'-ti:'||v_tip_interes||'-tr:'||v_tip_renovacion||'-ca:'||
                       v_cat_automatica||'-sc:'||v_cod_sit_contable);
                 END;
                 --- actualizo el mov. del CB_SIM_MOVIMIENTOS con el nro. de ref.-----
                 UPDATE CB_SIM_MOVIMIENTOS
                    SET PROTEGIDO = 'S',
                        NRO_DOCUMENTO4 = v_nro_referencia
                 WHERE ROWID = v_mov_fila; -- Ajuste temporal para evitar movimientos de interface (TYS 22-08-2006)
         END IF;
     END IF;
   END LOOP;
   CLOSE cursor1;
   --- Actualizo el Sgte.Nro.Ref.
   PRG_ACT_PAR_DINAMICO('SIG_NRO_REF_BALANCE',v_cod_modulo, v_cod_modalidad,v_cod_moneda, v_cod_oficina,v_sig_nro_referencia);
   -------------------------------------------------------------
   --- Actualizar cotización
   LP_EQU_MON_LOCAL; 
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Ref: '||v_sig_nro_referencia||' hora '||v_hora||' '||v_nro_cuenta||' '||sqlerrm);
END;

/* Genera los asientos contables.*/
PROCEDURE PR_GEN_ASIENTOS(p_fecha in ge_calendarios.fec_actual%type) IS
   -- Variables.
   v_cod_oficina       ba_oficinas.cod_oficina%TYPE;
   v_cod_mon_local     ba_monedas.cod_moneda%TYPE;
   v_fec_actual        ge_calendarios.fec_actual%TYPE;
   v_fec_proceso       ge_calendarios.fec_actual%TYPE;
   v_ult_dia_mes_habil ge_calendarios.fec_actual%TYPE;
   r_baade             cb_sim_asientos_det%ROWTYPE;
   v_error             VARCHAR2(250);
   v_lugar             VARCHAR2(250);   
   /* Intereses Devengado de Mesa de Dinero */
   PROCEDURE lp_int_dev_mesadinero;
   /* Cabecera Asiento */
   PROCEDURE lp_cab_asiento;
   /* Procedimiento Equivalente Moneda Local */
   PROCEDURE lp_equ_mon_local;
   /* Estadistico */
   PROCEDURE lp_estadistico;
   /* Movimientos Diarios */
   PROCEDURE lp_mov_diarios;
   /* Intereses Devengados */
   PROCEDURE lp_int_devengados;
   /* Intereses Devengado de Prestamos */
   PROCEDURE lp_int_dev_prestamos;
   /* Intereses Devengado de Comisiones Diferidas */
   PROCEDURE lp_int_dev_comisiones;
   -- Intereses Devengado Operaciones Futuras
   PROCEDURE lp_dev_ope_futuras;
   /* Insertar asientos automaticos detalles. */
   PROCEDURE lp_ins_asi_sim_det(rp_baade IN cb_sim_asientos_det%ROWTYPE);
   /* Obtener la moneda del rubro del parametro. */
   PROCEDURE lp_obt_mon_rubro
   (
      p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
      p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
      p_encontro   IN OUT VARCHAR2
   );

   /* Cabecera Asiento */
   PROCEDURE lp_cab_asiento IS

      v_nro_linea     cb_sim_asientos_det.nro_linea%TYPE;
      v_cod_oficina   ba_oficinas.cod_oficina%TYPE;
      v_cod_modalidad ge_modalidades.cod_modalidad%TYPE := 21;
      v_cod_modulo    ba_modulos.cod_modulo%TYPE := 2;
      ---Reactivar FK
      v_nro_asiento    NUMBER;
      wk_imtotct       NUMBER;
      v_tot_debito     NUMBER;
      v_tot_credito    NUMBER;
      v_tip_movimiento cb_sim_asientos_det.tip_movimiento%TYPE;

      v_msj       VARCHAR2(1000);
      v_fec_valor DATE;
      -- Crea el cursor con los diferentes a Activo Fijo; esto es para que no
      -- reenumere los asientos de Activo Fijo.--
      CURSOR cur_01 IS
         SELECT DISTINCT cod_oficina, nvl(fec_valor, fecha) fec_valor
           FROM cb_sim_asientos_det;
      r_02 cb_sim_asientos_det%ROWTYPE;

      CURSOR cur_02 IS
         SELECT *
           FROM cb_sim_asientos_det
          WHERE cod_oficina = v_cod_oficina
            AND (fec_valor = v_fec_valor OR fec_valor IS NULL)
            FOR UPDATE OF nro_asiento, nro_linea;
   BEGIN
      v_msj := 'Generando cabecera de asientos';
      OPEN cur_01;
      LOOP
         FETCH cur_01
            INTO v_cod_oficina, v_fec_valor;
         EXIT WHEN cur_01%NOTFOUND;
         ----- lee parametros de contabilidad ------
         v_nro_asiento := fug_obt_pardinamico('SIG_NRO_REF_BALANCE');
         prg_act_par_dinamico('SIG_NRO_REF_BALANCE', NULL, NULL, NULL, NULL, (v_nro_asiento + 1));
         v_msj := 'Generando cabecera asiento ' || to_char(v_cod_oficina) || '-' ||
                  to_char(v_nro_asiento);
         ----- fin leer parametros
         IF cur_02%ISOPEN THEN
            CLOSE cur_02;
         END IF;
         OPEN cur_02;
         v_nro_linea   := 0;
         wk_imtotct    := 0;
         v_tot_debito  := 0;
         v_tot_credito := 0;
         LOOP
            FETCH cur_02
               INTO r_02;
            EXIT WHEN cur_02%NOTFOUND;
            IF v_nro_linea = 999999 THEN
               v_msj := 'CUIDADO: Se debe agrandar el campo de nro. de linea';
            END IF;
            v_nro_linea := v_nro_linea + 1;

            wk_imtotct := wk_imtotct + nvl(r_02.mto_mon_local, 0);
            IF r_02.tip_movimiento = 'D' THEN
               v_tot_debito := nvl(v_tot_debito, 0) + r_02.mto_mon_local;
            ELSE
               v_tot_credito := nvl(v_tot_credito, 0) + r_02.mto_mon_local;
            END IF;
            UPDATE cb_sim_asientos_det
               SET nro_asiento = nvl(v_nro_asiento, 999),
                   nro_linea   = nvl(v_nro_linea, 9999)
             WHERE CURRENT OF cur_02;
         END LOOP;
         --- Verificar diferencia por redondeo
         IF v_tot_debito <> v_tot_credito THEN
            --- Verificar si esta parametrizado el redondeo
            IF fug_obt_pardinamico('ASI_REDONDEAR') = 'S' AND
               abs(v_tot_credito - v_tot_debito) <= fug_obt_pardinamico('ASI_MTO_REDONDEO') THEN
               --- Insertar linea de ajuste de la diferencia
               v_nro_linea := v_nro_linea + 1;
               IF v_tot_debito > v_tot_credito THEN
                  v_tip_movimiento  := 'C';
                  r_baade.cod_rubro := fug_obt_pardinamico('ASI_RUB_RED_GAN'); -- Tipo C= Ganancia; Tipo D= Perdida. CB 21/11/2013 DYDMR-11
               ELSE
                  v_tip_movimiento  := 'D';
                  r_baade.cod_rubro := fug_obt_pardinamico('ASI_RUB_RED_PER');
               END IF;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := v_cod_oficina;
               r_baade.nro_asiento    := v_nro_asiento;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := 0;
               r_baade.mto_mon_local  := abs(v_tot_credito - v_tot_debito);
               r_baade.descripcion    := 'DIFERENCIA DE CAMBIO';
               r_baade.referencia     := NULL;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := NULL;
               r_baade.distribuido    := 'N';
               r_baade.ref_movimiento := NULL;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_sim_det(r_baade);
               wk_imtotct := wk_imtotct + abs(v_tot_credito - v_tot_debito);
            END IF;
         END IF;
         -----------------------
         -- graba la cabecera --
         -----------------------
         v_cod_oficina := nvl(v_cod_oficina, 0);
         INSERT INTO cb_sim_asientos
            (cod_oficina, nro_asiento, cod_usuario, fecha, cod_modulo, cod_modalidad, tot_control,
             actualizado, reversado, cod_ofi_origen, ofi_integrada, confirmado, fec_valor)
         VALUES
            (v_cod_oficina, v_nro_asiento, USER, v_fec_actual, v_cod_modulo, v_cod_modalidad,
             wk_imtotct, 'N', 'N', v_cod_oficina, 'N', 'S', v_fec_valor);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_msj || ' ' || SQLERRM);
   END;
   /* Procedimiento Equivalente Moneda Local */
   PROCEDURE lp_equ_mon_local IS

      v_mto_cotizacion ge_cotizaciones.val_conversion%TYPE;
      v_cod_moneda     ba_monedas.cod_moneda%TYPE;
      v_cod_modulo     ba_modulos.cod_modulo%TYPE;
      v_cod_modalidad  ge_modalidades.cod_modalidad%TYPE;
      v_redondeo       NUMBER(5);
      v_msj            VARCHAR2(200);
      CURSOR c_movimientos IS
         SELECT DISTINCT cod_moneda, cod_modulo, cod_modalidad
           FROM cb_sim_movimientos
          WHERE cod_rubro IS NOT NULL
            AND cod_moneda <> v_cod_mon_local
            AND mto_equ_local IS NULL;
   BEGIN
      v_msj := ' Equivalente en moneda local ';

      OPEN c_movimientos;
      LOOP
         FETCH c_movimientos
            INTO v_cod_moneda, v_cod_modulo, v_cod_modalidad;
         EXIT WHEN c_movimientos%NOTFOUND;
         v_msj := ' MONEDA : ' || v_cod_moneda;

         ---------------------------------------------------------
         -----      LEER COTIZACION
         ---------------------------------------------------------
         v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
         ----------------------------------------------------------
         -------- ACTUALIZA CB_SIM_MOVIMIENTOS CON EL IMPORTE EQUIVALENTE GS.
         ----------------------------------------------------------
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         UPDATE cb_sim_movimientos
            SET mto_equ_local = round(nvl(monto, 0) * v_mto_cotizacion, v_redondeo)
          WHERE cod_moneda = v_cod_moneda
            AND mto_equ_local IS NULL;
      END LOOP;
      IF c_movimientos%ISOPEN THEN
         CLOSE c_movimientos;
      END IF;
   END;
   /* Estadistico */
   PROCEDURE lp_estadistico IS

      v_cod_mon_rubro    cb_rubros.cod_moneda%TYPE;
      v_nro_linea        ge_tip_asientos.nro_linea%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_nro_referencia   cb_sim_con_transacciones.nro_referencia%TYPE;
      v_cod_plazo        cb_sim_con_transacciones.cod_plazo%TYPE;
      v_cod_tip_deudor   cb_sim_con_transacciones.cod_tip_deudor%TYPE;
      v_cod_sector       cb_sim_con_transacciones.cod_sector%TYPE;
      v_residente        cb_sim_con_transacciones.residente%TYPE;
      v_cod_mad_padre    cb_sim_con_transacciones.cod_mad_padre%TYPE;
      v_cod_mod_padre    cb_sim_con_transacciones.cod_mod_padre%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_modalidad    cb_sim_con_transacciones.cod_modalidad%TYPE;
      v_cod_modulo       cb_sim_con_transacciones.cod_modulo%TYPE;
      v_cod_ofi_origen   cb_sim_con_transacciones.cod_ofi_origen%TYPE;
      v_cod_oficina      cb_sim_con_transacciones.cod_oficina%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_moneda       cb_sim_con_transacciones.cod_moneda%TYPE;
      v_cod_tip_asiento  ge_transacciones.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_transacciones.cod_tip_asiento2%TYPE;
      v_tot_mon_local    cb_sim_con_transacciones.tot_mon_local%TYPE;
      v_total            cb_sim_con_transacciones.total%TYPE;
      xx_immovml         NUMBER(18, 2);
      xx_immovex         NUMBER(18, 2);
      xx_vltasci         NUMBER(16, 2);
      v_mensaje          varchar2(200);

      wk_lgofici       CHAR(1); --Indica si se tiene que hacer un asiento interoficina
      v_tip_movimiento ge_tip_asientos.tip_movimiento%TYPE;
      x_tip_movimiento ge_tip_asientos.tip_movimiento%TYPE;
      ----
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    cb_sim_con_transacciones.cod_oficina%TYPE;
      vh_nro_asiento    NUMBER;
      vh_cod_rubro      cb_rubros.cod_rubro%TYPE;
      wh_immovml        NUMBER;
      wh_dcrefer        CHAR(11);
      wh_dcdescr        CHAR(60);
      wh_lgprote        CHAR(1);
      wh_lgdeact        CHAR(1);
      wh_lgctadi        CHAR(1);
      ----
      v_encontro CHAR(1);
      --
      v_sigue    CHAR(1);
      ww_nrcuent CHAR(15);
      v_msj      VARCHAR2(250);
      ---
      v_est_cuenta       cb_sim_con_transacciones.est_cuenta%TYPE;
      v_tip_cuenta       cb_sim_con_transacciones.tip_cuenta%TYPE;
      v_tip_interes      cb_sim_con_transacciones.tip_interes%TYPE;
      v_tip_renovacion   cb_sim_con_transacciones.tip_renovacion%TYPE;
      v_cat_automatica   cb_sim_con_transacciones.cat_automatica%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_redondeo         NUMBER(5);
      v_fec_valor        DATE;
      v_cod_sit_contable cb_sim_con_transacciones.cod_sit_contable%TYPE;
      v_nro_cuenta       cb_sim_con_transacciones.nro_cuenta%TYPE;
      v_concepto         cb_sim_con_transacciones.concepto%TYPE;
      v_cod_sec_rubro    cb_sim_con_transacciones.cod_sec_rubro%TYPE;
      v_registro         VARCHAR2(200);
      v_val_reg_exc_gen_asientos ge_par_dinamicos.val_parametro%type;

      CURSOR c_transacciones IS
         SELECT ct.cod_moneda,
                ct.total,
                t.cod_tip_asiento,
                t.descripcion,
                ct.cod_oficina,
                ct.cod_ofi_origen,
                ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_transaccion,
                ct.cod_mod_padre,
                ct.cod_mad_padre,
                ct.residente,
                ct.cod_sector,
                ct.cod_tip_deudor,
                ct.cod_plazo,
                ct.tot_mon_local,
                ct.est_cuenta,
                ct.tip_cuenta,
                ct.tip_interes,
                ct.tip_renovacion,
                ct.cat_automatica,
                ct.nro_referencia,
                mo.cod_pro_contable,
                t.cod_tip_asiento2,
                ct.fecha fec_valor,
                ct.cod_sit_contable,
                ct.nro_cuenta,
                ct.concepto,
                ct.cod_sec_rubro,
                ct.rowid registro
           FROM ge_transacciones t, cb_sim_con_transacciones ct, ge_modalidades mo
          WHERE fecha = v_fec_actual
            AND t.tipo IN ('D', 'C')
            AND t.cod_modulo = ct.cod_modulo
            AND t.cod_modalidad = ct.cod_modalidad
            AND t.cod_transaccion = ct.cod_transaccion
            AND t.cod_tip_asiento IS NOT NULL
            AND t.batch = 'B'
            AND t.cod_modulo = mo.cod_modulo
            AND t.cod_modalidad = mo.cod_modalidad
            AND not exists (select 1 
                              from ge_par_dinamicos x
                             where x.parametro = 'REG_EXC_GEN_ASIENTOS'
                               and instr(x.val_parametro,','||ct.rowid||',') > 0);
      ---------------------------------------------------------------------
      r_tp ge_tip_asientos%ROWTYPE;
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sector OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1)
            AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable)

          ORDER BY nro_linea;
   BEGIN
      v_msj := '--- Estadistico ---';
      OPEN c_transacciones;
      LOOP
         --- para cada registro de estadistico ---
         FETCH c_transacciones
            INTO v_cod_moneda,
                 v_total,
                 v_cod_tip_asiento,
                 v_des_transaccion,
                 v_cod_oficina,
                 v_cod_ofi_origen,
                 v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_transaccion,
                 v_cod_mod_padre,
                 v_cod_mad_padre,
                 v_residente,
                 v_cod_sector,
                 v_cod_tip_deudor,
                 v_cod_plazo,
                 v_tot_mon_local,
                 v_est_cuenta,
                 v_tip_cuenta,
                 v_tip_interes,
                 v_tip_renovacion,
                 v_cat_automatica,
                 v_nro_referencia,
                 v_cod_pro_contable,
                 v_cod_tip_asiento2,
                 v_fec_valor,
                 v_cod_sit_contable,
                 v_nro_cuenta,
                 v_concepto,
                 v_cod_sec_rubro,
                 v_registro;

         EXIT WHEN c_transacciones%NOTFOUND;
         v_mensaje := 'Tran: '||to_char(v_cod_modulo)||'-'||to_char(v_cod_modalidad)||'-'||to_char(v_cod_transaccion)||'- Cta: '||v_nro_cuenta||'- Mon: '||v_cod_moneda||'- Mto: '|| rtrim(ltrim(to_char(v_total,'999,999,999,999.99')));

         --v_cod_mon_local es inicializado en pra_gen_asientos
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            ---- ES MONEDA NACIONAL --
            ------------------------
            xx_immovml := round(v_total, v_redondeo);
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            -- ES MONEDA EXTRANJERA --
            --------------------------
            IF v_tot_mon_local IS NULL THEN
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
               xx_immovml       := round(v_total * v_mto_cotizacion, v_redondeo);
               xx_vltasci       := v_mto_cotizacion;
            ELSE
               xx_immovml := v_tot_mon_local;
               xx_vltasci := NULL;
            END IF;
            xx_immovex := v_total;
         END IF;
         wk_lgofici := 'N';
         ----------------------------------------
         IF v_cod_oficina <> v_cod_ofi_origen THEN
            -- ES ASIENTO INTEROFICINA
            wk_lgofici := 'S';
         END IF;
         ------- ciclo para GE_TIP_ASIENTOS (tipos de asientos relacionados a
         -------                     la transaccion leida)
         ------------------------------------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         v_sigue     := 'N';
         LOOP
            -- para cada registro de GE_TIP_ASIENTOS
            FETCH c_tip_asientos
               INTO r_tp;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            -------------------------------------------------
            IF v_sigue = 'S' THEN
               -- ya hubo otra linea interoficina
               IF (v_tip_movimiento <> r_tp.tip_movimiento AND r_tp.nro_linea = 1 AND
                  xx_immovml > 0) OR (v_tip_movimiento = r_tp.tip_movimiento AND r_tp.nro_linea = 1 AND
                  xx_immovml <= 0) THEN
                  v_sigue := 'N'; -- se apaga para que no genere interoficina
               END IF;
            ELSE
               IF wk_lgofici = 'S' AND r_tp.nro_linea = 1 THEN
                  v_tip_movimiento := r_tp.tip_movimiento;
                  x_tip_movimiento := r_tp.tip_movimiento; -- para el interoficina
                  v_sigue          := 'S'; /* se hara interoficina */
               END IF;
            END IF;
            v_encontro := 'S';
            ---Reemplaza el tipo de deudor -----------------------
            IF r_tp.ind_deudor = 'S' THEN
               ww_nrcuent := substr(r_tp.cod_rubro, 1, 8) || ltrim(to_char(v_cod_tip_deudor, '00')) ||
                             substr(r_tp.cod_rubro, 11, 5);
            ELSE
               ww_nrcuent := r_tp.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo-----------------------
            IF r_tp.ind_plazo = 'S' THEN
               ww_nrcuent := substr(ww_nrcuent, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                             substr(ww_nrcuent, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_tp.ind_producto = 'S' THEN
               ww_nrcuent := substr(ww_nrcuent, 1, 10) || ltrim(to_char(v_cod_pro_contable, '000')) ||
                             substr(r_tp.cod_rubro, 14, 2);
            END IF;
            IF substr(r_tp.cod_rubro, 11, 3) = 'SEC' THEN
               -- es solo para prestamos, para contabilizar por sector
               ww_nrcuent := substr(ww_nrcuent, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                             substr(r_tp.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            --- Lee Plan de ctas. consolidado p/tomar la moneda
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(ww_nrcuent, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Rubro no existe -Plan Ctas.Consol' || ww_nrcuent;
               --vh_cod_rubro := '999999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
               --v_cod_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               --- ES MONEDA LOCAL
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            IF r_tp.nro_linea = 1 THEN
               vh_cod_oficina := v_cod_oficina;
            ELSE
               vh_cod_oficina := v_cod_ofi_origen;
            END IF;
            vh_nro_asiento := 0;
            vh_cod_rubro   := ww_nrcuent;
            IF xx_immovml > 0 THEN
               wh_immovml       := xx_immovml;
               v_tip_movimiento := r_tp.tip_movimiento;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_tp.tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
            END IF;
            wh_dcrefer := NULL;
            IF v_cod_transaccion BETWEEN 150 AND 171 THEN
               wh_dcrefer := 'VALUAC';
            END IF;
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            wh_lgctadi := 'N'; ---r_tp.at_lgctadi;
            IF substr(v_concepto, 1, 1) = '/' THEN
               wh_dcdescr := substr(v_concepto, 1, 60);
            ELSIF v_nro_cuenta IS NOT NULL THEN
               wh_dcdescr := substr('Cli:' || fug_obt_cli_principal(v_nro_cuenta) || ' Cta:' ||
                                    v_nro_cuenta || ' ' || v_concepto, 1, 60);
            ELSIF v_concepto IS NOT NULL THEN
               wh_dcdescr := substr(v_concepto, 1, 60);

            ELSE

               wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                    to_char(v_cod_transaccion) || ' ' || v_des_transaccion, 1, 60);
            END IF;
            --------------------------------------------------
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := v_nro_referencia;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END LOOP;
         ---------------------------
         IF wk_lgofici = 'S' AND v_sigue = 'S' THEN
            -- tomo el tipo de movimiento de la linea 1
            v_tip_movimiento := x_tip_movimiento;
            -- Recuperar cuenta contable interoficina
            vh_cod_rubro   := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,
                                                  v_cod_oficina);
            vh_cod_oficina := v_cod_oficina; -- oficina de la cuenta
            vh_cod_rubro   := substr(vh_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_ofi_origen, '000')) ||
                              substr(vh_cod_rubro, 14, 2);
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Rubro Inexistente-Plan de Ctas.Consol' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
               --v_cod_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -------------------------------------------------------------
            --- VER SI EL TIPO DE MOVIMIENTO ES DE DEBITO O CREDITO
            ------------------------------------------------------------
            IF v_tip_movimiento = 'D' THEN
               v_tip_movimiento := 'C';
            ELSE
               v_tip_movimiento := 'D';
            END IF;
            wh_dcdescr := substr(TRIM(wh_dcdescr) || '(Inter of)', 1, 60);
            /*
            wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
                          to_char(v_cod_modalidad) || ' ' ||
                          to_char(v_cod_transaccion) || ' ' ||
                          '(Inter of)'        || ' ' ||
                          v_des_transaccion,1,60);
            */
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            wh_lgctadi := 'N'; ---- r_tp.at_lgctadi;
            IF xx_immovml > 0 THEN
               wh_immovml := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF v_tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
            END IF;
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := v_nro_referencia;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_sim_det(r_baade);
            END IF;
            -- Recuperar cuenta contable interoficina
            vh_cod_rubro   := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL, v_cod_moneda,
                                                  v_cod_oficina);
            vh_cod_oficina := v_cod_ofi_origen; -- oficina origen
            vh_cod_rubro   := substr(vh_cod_rubro, 1, 10) || ltrim(to_char(v_cod_oficina, '000')) ||
                              substr(vh_cod_rubro, 14, 2);

            vh_nro_asiento := 0;
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            v_tip_movimiento := x_tip_movimiento;
            IF xx_immovml > 0 THEN
               wh_immovml := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF v_tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
            END IF;
            --
            IF v_encontro = 'N' THEN
               wh_dcdescr := 'RUBRO INEXISTENTE ' || vh_cod_rubro;
            END IF;
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            wh_lgctadi := 'N'; 
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := v_nro_referencia;
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END IF;
         ---------------- FIN INTEROFICINA ------------------
      END LOOP;
      IF c_transacciones%ROWCOUNT = 0 THEN
         raise_application_error(-20000,
                                 'No se encontro registro en cb_sim_con_transacciones-GE_TRANSACCIONES');
      END IF;
      --Agregar validacion para eliminar el parametro si fue cargado--
      v_val_reg_exc_gen_asientos := null;
      v_val_reg_exc_gen_asientos := fug_obt_pardinamico('REG_EXC_GEN_ASIENTOS');
      if v_val_reg_exc_gen_asientos is not null then
         delete from ge_par_dinamicos x
          where x.parametro = 'REG_EXC_GEN_ASIENTOS';
      end if;
   EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20002,'Error en el identificador rowid: '||v_nro_linea||' -'|| v_registro||'- '||v_mensaje||'. '|| sqlerrm);
   END;
   
   /* Movimientos Diarios */
   PROCEDURE lp_mov_diarios IS

      /* Moneda de la Cuenta Contable */
      v_cod_mon_rubro  cb_rubros.cod_moneda%TYPE;
      v_encontro       VARCHAR2(1) := 'N';
      v_fila           VARCHAR2(20);
      v_nro_documento4 cb_sim_movimientos.nro_documento4%type;
      v_nro_documento3 cb_sim_movimientos.nro_documento3%type;
      v_nro_documento2 cb_sim_movimientos.nro_documento2%type;
      v_cod_ref_cambio cb_sim_movimientos.cod_ref_cambio%type;
      v_cod_usuario    cb_sim_movimientos.cod_usuario%type;
      v_concepto       cb_sim_movimientos.concepto%type;
      v_cod_mad_padre  cb_sim_movimientos.cod_mad_padre%type;
      v_cod_mod_padre  cb_sim_movimientos.cod_mod_padre%type;
      v_mto_equ_local  cb_sim_movimientos.mto_equ_local%type;
      v_monto          cb_sim_movimientos.monto%type;
      v_tip_mov_rubro  cb_sim_movimientos.tip_mov_rubro%type;
      v_cod_oficina    cb_sim_movimientos.cod_oficina%type;
      v_cod_ofi_origen cb_sim_movimientos.cod_ofi_origen%type;
      v_cod_rubro      cb_sim_movimientos.cod_rubro%type;
      v_cod_modalidad  cb_sim_movimientos.cod_modalidad%type;
      v_cod_modulo     cb_sim_movimientos.cod_modulo%type;
      ---
      vh_tip_mov_rubro cb_sim_movimientos.tip_mov_rubro%type;
      vh_cod_rubro     cb_rubros.cod_rubro%TYPE;
      wh_dcrefer       CHAR(11);
      wh_dcdescr       CHAR(60);
      vh_nro_asiento   NUMBER;
      wh_lgprote       CHAR(1);
      wh_lgdeact       CHAR(1);
      wh_lgctadi       CHAR(1);
      ---
      wh_immovml        NUMBER;
      xx_immovml        NUMBER;
      wh_immovex        NUMBER;
      xx_immovex        NUMBER;
      wh_vltasci        NUMBER;
      xx_vltasci        NUMBER;
      vh_cod_oficina    cb_sim_movimientos.cod_oficina%type;
      vh_cod_modulo     cb_sim_movimientos.cod_modulo%type;
      vh_cod_modalidad  cb_sim_movimientos.cod_modalidad%type;
      v_fecha           cb_sim_movimientos.fecha%type;
      wk_cdctaco        cb_rubros.cod_rubro%type;
      wk_lgofici        CHAR(1);
      wk_sgnrref        NUMBER(7);
      v_msj             VARCHAR2(200);
      v_nro_linea       NUMBER;
      v_hora            cb_sim_movimientos.hora%type;
      v_nro_secuencia   cb_sim_movimientos.nro_secuencia%type;
      v_cotizacion      cb_sim_movimientos.cotizacion%type;
      v_fec_valor       DATE;

      --Declaracion del  Cursor
      CURSOR c_movimientos IS
         SELECT cod_modulo,
                cod_modalidad,
                cod_oficina,
                cod_rubro,
                fecha,
                tip_mov_rubro,
                nvl(monto, 0),
                nvl(mto_equ_local, 0),
                cod_ofi_origen,
                cod_mod_padre,
                cod_mad_padre,
                substr(concepto, 1, 35),
                cod_usuario,
                cod_ref_cambio,
                nro_documento2,
                nro_documento3,
                nro_documento4,
                hora,
                nro_secuencia,
                ROWID,
                cotizacion,
                fecha fec_valor
           FROM CB_SIM_MOVIMIENTOS
          WHERE cod_rubro IS NOT NULL
            AND estado IN ('N', 'H') --original
          ORDER BY cod_modulo,
                   cod_modalidad,
                   cod_oficina,
                   cod_rubro,
                   tip_mov_rubro,
                   cod_ofi_origen,
                   cod_mod_padre,
                   cod_mad_padre;
   BEGIN
      --- Leo el sgte. nro. de referencia del GE_PAR_DINAMICOS -- Es el mismo que utiliza act. de saldos de ahorros
      wk_sgnrref  := fug_obt_pardinamico('SIG_NRO_REF_BALANCE');
      v_msj       := ' Movimientos c_movimientos ';
      v_nro_linea := 0;
      -----------
      OPEN c_movimientos;
      LOOP
         FETCH c_movimientos
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_rubro,
                 v_fecha,
                 v_tip_mov_rubro,
                 v_monto,
                 v_mto_equ_local,
                 v_cod_ofi_origen,
                 v_cod_mod_padre,
                 v_cod_mad_padre,
                 v_concepto,
                 v_cod_usuario,
                 v_cod_ref_cambio,
                 v_nro_documento2,
                 v_nro_documento3,
                 v_nro_documento4,
                 v_hora,
                 v_nro_secuencia,
                 v_fila,
                 v_cotizacion,
                 v_fec_valor;
         EXIT WHEN c_movimientos%NOTFOUND;
         v_encontro := 'S';
         lp_obt_mon_rubro(v_cod_rubro, v_cod_mon_rubro, v_encontro);
         IF v_encontro = 'N' THEN
            --vh_cod_rubro := '999999999999';
            v_cod_mon_rubro := v_cod_mon_local;
         END IF;
         IF v_cod_mon_rubro = v_cod_mon_local THEN
            xx_immovml := v_monto;
            xx_immovex := 0;
            xx_vltasci := NULL;
            wh_immovml := v_monto;
            wh_immovex := 0;
            wh_vltasci := 0;
         ELSE
            xx_immovml := v_mto_equ_local;
            xx_immovex := v_monto;
            xx_vltasci := v_cotizacion;
            wh_immovml := v_mto_equ_local;
            wh_immovex := v_monto;
            wh_vltasci := v_cotizacion;
         END IF;
         wk_lgofici := 'N';
         IF v_cod_oficina <> v_cod_ofi_origen THEN
            wk_lgofici := 'S';
         END IF;
         IF xx_immovml > 0 THEN
            wh_immovml       := xx_immovml;
            vh_tip_mov_rubro := v_tip_mov_rubro;
         ELSE
            wh_immovml := xx_immovml * -1;
            wh_immovex := wh_immovex * -1;
            IF v_tip_mov_rubro = 'D' THEN
               vh_tip_mov_rubro := 'C';
            ELSE
               vh_tip_mov_rubro := 'D';
            END IF;
         END IF;
         vh_cod_oficina   := v_cod_oficina;
         vh_cod_modulo    := v_cod_modulo;
         vh_cod_modalidad := v_cod_modalidad;
         vh_cod_rubro     := v_cod_rubro;
         IF v_concepto IS NULL THEN
            wh_dcdescr := substr(fub_obt_referencia(v_fila), 1, 60);
         ELSE
            wh_dcdescr := substr(nvl(fub_obt_referencia(v_fila), v_concepto), 1, 60);
         END IF;
         IF v_cod_mod_padre = 7 THEN
            wh_dcrefer := substr(rtrim(v_cod_ref_cambio) || '/' || ltrim(to_char(v_nro_documento2)),
                                 1, 11);
         ELSE
            wh_dcrefer := v_cod_usuario;
         END IF;
         IF v_cod_mod_padre IN (7, 9) THEN
            IF v_nro_documento3 IS NOT NULL THEN
               wh_dcdescr := substr(ltrim(to_char(v_nro_documento3, '999999999999999')) || ' ' ||
                                    wh_dcdescr, 1, 60);
            ELSE
               wh_dcdescr := substr(wh_dcdescr, 1, 60);
            END IF;
         END IF;
         wh_lgprote := 'N';
         wh_lgdeact := 'N';
         wh_lgctadi := 'N';
         IF wh_immovml <> 0 THEN
            v_nro_linea := v_nro_linea + 1;
            --- Cargar registro de asientos detalles
            r_baade.fecha          := v_fecha;
            r_baade.cod_oficina    := vh_cod_oficina;
            r_baade.nro_asiento    := 0;
            r_baade.nro_linea      := v_nro_linea;
            r_baade.cod_rubro      := vh_cod_rubro;
            r_baade.tip_movimiento := vh_tip_mov_rubro;
            r_baade.mto_mon_rubro  := wh_immovex;
            r_baade.mto_mon_local  := wh_immovml;
            r_baade.descripcion    := wh_dcdescr;
            r_baade.referencia     := wh_dcrefer;
            r_baade.protegido      := wh_lgprote;
            r_baade.actualizado    := wh_lgdeact;
            r_baade.val_cotizacion := wh_vltasci;
            r_baade.distribuido    := wh_lgctadi;
            r_baade.ref_movimiento := nvl(v_nro_documento4, wk_sgnrref);
            r_baade.fec_valor      := v_fec_valor;
            lp_ins_asi_sim_det(r_baade);
         END IF;
         ------------------ INTEROFICINA --------------------
         ---------------------------
         IF wk_lgofici = 'S' THEN
            -- Recuperar cuenta contable interoficina
            wk_cdctaco     := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                                  v_cod_mon_rubro, v_cod_oficina);
            vh_cod_oficina := v_cod_oficina;
            wk_cdctaco     := substr(wk_cdctaco, 1, 10) || ltrim(to_char(v_cod_ofi_origen, '000')) ||
                              substr(wk_cdctaco, 14, 2);

            vh_nro_asiento := 0;
            vh_cod_rubro   := wk_cdctaco;
            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            IF v_tip_mov_rubro = 'D' THEN
               vh_tip_mov_rubro := 'C';
            ELSE
               vh_tip_mov_rubro := 'D';
            END IF;
            /*         wh_dcdescr := substr(to_char(v_cod_modulo) || ' ' ||
            to_char(v_cod_modalidad) || ' ' ||
            ' (Inter of) '||v_concepto,1,60);*/
            wh_dcdescr := substr(TRIM(wh_dcdescr) || '(Inter of)', 1, 60);
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            IF xx_immovml > 0 THEN
               wh_immovml := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF vh_tip_mov_rubro = 'D' THEN
                  vh_tip_mov_rubro := 'C';
               ELSE
                  vh_tip_mov_rubro := 'D';
               END IF;
            END IF;
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fecha;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := vh_cod_rubro;
               r_baade.tip_movimiento := vh_tip_mov_rubro;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := wh_lgctadi;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := 'N';
               r_baade.ref_movimiento := nvl(v_nro_documento4, wk_sgnrref);
               r_baade.fec_valor      := v_fec_valor;
               lp_ins_asi_sim_det(r_baade);
            END IF;
            -----------------------
            -- Recuperar cuenta contable interoficina para oficina origen
            wk_cdctaco     := fug_obt_pardinamico('COD_RUB_INTEROFICINA', NULL, NULL,
                                                  v_cod_mon_rubro, v_cod_ofi_origen);
            vh_cod_oficina := v_cod_ofi_origen;
            vh_cod_rubro   := substr(wk_cdctaco, 1, 10) || ltrim(to_char(v_cod_oficina, '000')) ||
                              substr(wk_cdctaco, 14, 2);

            --- ve moneda de la cuenta --
            v_encontro := 'S';
            lp_obt_mon_rubro(vh_cod_rubro, v_cod_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'RUBRO INEXISTENTE EN PLAN DE CUENTAS ' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999';
               IF substr(vh_cod_rubro, 14, 2) IN ('99', '98') THEN
                  v_cod_mon_rubro := v_cod_mon_local;
               END IF;
            END IF;
            IF v_cod_mon_rubro = v_cod_mon_local THEN
               -- moneda local
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            --wh_dcdescr := to_char(vh_cod_modulo) || ' ' ||
            --              to_char(vh_cod_modalidad) || ' ' ||
            --              ' (Inter of)';
            IF v_encontro = 'N' THEN
               wh_dcdescr := 'RUBRO INEXISTENTE ' || vh_cod_rubro;
               --vh_cod_rubro := '999999999999';
            END IF;
            wh_lgprote := 'N';
            wh_lgdeact := 'N';
            IF xx_immovml > 0 THEN
               wh_immovml       := xx_immovml;
               vh_tip_mov_rubro := v_tip_mov_rubro;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF v_tip_mov_rubro = 'D' THEN
                  vh_tip_mov_rubro := 'C';
               ELSE
                  vh_tip_mov_rubro := 'D';
               END IF;
            END IF;
            IF wh_immovml <> 0 THEN
               BEGIN
                  v_nro_linea := v_nro_linea + 1;
                  --- Cargar registro de asientos detalles
                  r_baade.fecha          := v_fecha;
                  r_baade.cod_oficina    := vh_cod_oficina;
                  r_baade.nro_asiento    := 0;
                  r_baade.nro_linea      := v_nro_linea;
                  r_baade.cod_rubro      := vh_cod_rubro;
                  r_baade.tip_movimiento := vh_tip_mov_rubro;
                  r_baade.mto_mon_rubro  := wh_immovex;
                  r_baade.mto_mon_local  := wh_immovml;
                  r_baade.descripcion    := wh_dcdescr;
                  r_baade.referencia     := wh_dcrefer;
                  r_baade.protegido      := 'N';
                  r_baade.actualizado    := wh_lgctadi;
                  r_baade.val_cotizacion := wh_vltasci;
                  r_baade.distribuido    := 'N';
                  r_baade.ref_movimiento := nvl(v_nro_documento4, wk_sgnrref);
                  r_baade.fec_valor      := v_fec_valor;
                  lp_ins_asi_sim_det(r_baade);
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20001,
                                             'Error LP_MOV_DIARIOS, Nro.Linea ' || v_nro_linea || ' ' ||
                                              SQLERRM);
               END;
            END IF;
         END IF;
         ---------------- FIN INTEROFICINA ------------------
         IF v_nro_documento4 IS NULL THEN
            UPDATE CB_SIM_MOVIMIENTOS SET nro_documento4 = wk_sgnrref WHERE ROWID = v_fila;            
            wk_sgnrref := nvl(wk_sgnrref, 0) + 1;
         END IF;
      END LOOP;
      ---- actualizo el GE_PAR_GENERALES ----------------------------------
      --- Actualizo sgte. nro. de referencia
      prg_act_par_dinamico('SIG_NRO_REF_BALANCE', NULL, NULL, NULL, NULL, wk_sgnrref);
   END;
   /* Intereses Devengados */
   PROCEDURE lp_int_devengados IS

      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      cb_sim_dev_ahorros.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_ofi_origen ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_modulo     ah_cta_vistas.cod_modulo%TYPE;
      vh_cod_modalidad  ah_cta_vistas.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer CHAR(11);
      wh_lgprote CHAR(1);
      wh_lgdeact CHAR(1);
      wh_lgctadi CHAR(1);
      wh_dcdescr CHAR(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  CHAR(1);
      v_msj       VARCHAR2(250);
      --
      wk_plazoav NUMBER(02) := 1; -- esto se definio solo p/select de A.V.
      --
      CURSOR cur3 IS
         SELECT cv.cod_modulo,
                cv.cod_modalidad,
                cv.cod_oficina,
                cv.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                wk_plazoav,
                nvl(mo.cod_pro_contable, 0) cod_pro_contable
           FROM ah_cta_vistas   cv,
                ge_clientes     c,
                cb_sim_dev_ahorros d,
                ge_cta_clientes cc,
                ge_modalidades  mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = cv.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND cv.cod_modulo = mo.cod_modulo
            AND cv.cod_modalidad = mo.cod_modalidad
          GROUP BY cv.cod_modulo,
                   cv.cod_modalidad,
                   cv.cod_oficina,
                   cv.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   9,
                   nvl(mo.cod_pro_contable, 0)
         UNION
         SELECT cp.cod_modulo,
                cp.cod_modalidad,
                cp.cod_oficina,
                cp.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0)
           FROM ge_plz_contables pc,
                cb_sim_dev_ahorros d,
                ah_cta_plazos    cp,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = cp.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND cc.relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND cp.cod_modulo = mo.cod_modulo
            AND cp.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (cp.fec_vencimiento - cp.fec_apertura))
          GROUP BY cp.cod_modulo,
                   cp.cod_modalidad,
                   cp.cod_oficina,
                   cp.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0)
         UNION
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0)
           FROM ge_plz_contables    pc,
                cb_sim_dev_ahorros  d,
                ah_cta_certificados ct,
                ge_clientes         c,
                ge_cta_clientes     cc,
                ge_modalidades      mo
          WHERE fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_apertura))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0);
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'NO TIENE ASIENTO RELAC.P/DEVENG ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad));
            WHEN OTHERS THEN
               raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);

         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   
   -- Insteres Devengado de Prestamos
   PROCEDURE lp_int_dev_prestamos IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      cb_sim_dev_ahorros.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  VARCHAR2(1);
      v_msj       VARCHAR2(250);
      --
      v_cod_sec_rubro cb_sim_con_transacciones.cod_sec_rubro%TYPE;

      CURSOR cur3 IS
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.categoria,
                ct.tipo,
                ct.tip_interes,
                nvl(ct.tip_renovacion, 'A') tip_renovacion,
                d.estado,
                fup_obt_sec_rubro(ct.cod_sec_credito)
           FROM ge_plz_contables pc,
                cb_sim_dev_prestamos d,
                pr_cta_prestamos ct,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (ct.fec_vencimiento - ct.fec_inicio))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.categoria,
                   ct.tipo,
                   ct.tip_interes,
                   nvl(ct.tip_renovacion, 'A'),
                   d.estado,
                   fup_obt_sec_rubro(ct.cod_sec_credito);
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      v_redondeo         NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cat_automatica,
                 v_tip_cuenta,
                 v_tip_interes,
                 v_tip_renovacion,
                 v_est_cuenta,
                 v_cod_sec_rubro;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 901
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-901 no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            /*if fug_obt_tip_implementacion = 1 then
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cot_venta(v_cod_moneda, v_fec_actual);
            else*/
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            --end if;
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(901) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
         --- ve el tipo de asiento por el DEBITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = 903
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) ||
                                        '-903 no tiene asiento de Debito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20002, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovml := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            -- se obtiene la cotizacion de cierre
            v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            xx_immovml := round(v_mto_interes * v_mto_cotizacion, v_redondeo);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            --Reemplaza el código del sector de crédito
            IF substr(r_gtasi.cod_rubro, 11, 3) = 'SEC' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(v_cod_sec_rubro, '000')) ||
                              substr(r_gtasi.cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(903) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.ref_movimiento := NULL;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   -- Insteres Devengado de Comisiones Diferidas
   PROCEDURE lp_int_dev_comisiones IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      cb_sim_dev_ahorros.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      xx_immovml         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_ofi_origen ah_cta_vistas.cod_oficina%TYPE;
      vh_cod_modulo     ah_cta_vistas.cod_modulo%TYPE;
      vh_cod_modalidad  ah_cta_vistas.cod_modalidad%TYPE;

      wh_immovml NUMBER;
      wh_dcrefer CHAR(11);
      wh_lgprote CHAR(1);
      wh_lgdeact CHAR(1);
      wh_lgctadi CHAR(1);
      wh_dcdescr CHAR(60);
      --
      v_nro_linea ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_encontro  CHAR(1);
      v_msj       VARCHAR2(250);
      --
      CURSOR cur3 IS
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda, --v_cod_mon_local,
                SUM(md.mto_dev_actual),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0) cod_pro_contable,
                md.cod_transaccion
           FROM cb_sim_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = v_fec_actual
            AND md.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND md.cod_modulo = mo.cod_modulo
            AND md.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
          GROUP BY md.cod_modulo,
                   md.cod_modalidad,
                   md.cod_oficina,
                   md.cod_moneda, --v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   md.cod_transaccion
         UNION
         SELECT md.cod_modulo,
                md.cod_modalidad,
                md.cod_oficina,
                md.cod_moneda, --v_cod_mon_local,
                (SUM(md.mto_dev_anterior) * -1),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0) cod_pro_contable,
                md.cod_transaccion
           FROM cb_sim_mov_diferidos md,
                ge_clientes      c,
                ge_cta_clientes  cc,
                ge_modalidades   mo,
                ge_plz_contables pc
          WHERE md.fec_ult_proceso = v_fec_actual
            AND md.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND md.estado = 'C'
            AND c.cod_persona = cc.cod_persona
            AND md.cod_modulo = mo.cod_modulo
            AND md.cod_modalidad = mo.cod_modalidad
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (md.fec_vencimiento - md.fec_inicio))
          GROUP BY md.cod_modulo,
                   md.cod_modalidad,
                   md.cod_oficina,
                   md.cod_moneda, --v_cod_mon_local,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   md.cod_transaccion;
      --
      v_cod_tip_asiento ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      r_gtasi           ge_tip_asientos%ROWTYPE;
      v_redondeo        NUMBER(5);
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      v_msj := ' Comisiones Diferidas ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_cod_transaccion;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento
         BEGIN
            SELECT cod_tip_asi_resultado, descripcion
              INTO v_cod_tip_asiento, v_des_transaccion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asi_resultado IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'NO TIENE ASIENTO RELAC.P/DEVENG COMISION ' ||
                                        to_char(v_cod_modulo) || '-' || to_char(v_cod_modalidad) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);

         END;
         ------------------
         -- ve la moneda --
         ------------------
         /*--v_cod_mon_local y v_fec_actual, son inicializados en pra_gen_asientos*/
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', v_cod_modulo, v_cod_modalidad,
                                           v_cod_mon_local);
         --IF v_cod_moneda =  v_cod_mon_local THEN
         -- Comisiones diferidas siempre --
         -- es moneda nacional --
         ------------------------
         xx_immovml := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovml > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovml       := xx_immovml;
            ELSE
               wh_immovml := xx_immovml * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(v_cod_transaccion) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; 
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovml <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovml;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   -- Insteres Devengado de Mesa de Dinero
   PROCEDURE lp_int_dev_mesadinero IS
      v_cod_mad_padre    ge_modalidades.cod_modalidad%TYPE;
      v_cod_mod_padre    ba_modulos.cod_modulo%TYPE;
      v_tip_movimiento   ge_tip_asientos.tip_movimiento%TYPE;
      v_mon_rubro        cb_rubros.cod_moneda%TYPE;
      v_mto_cotizacion   ge_cotizaciones.val_conversion%TYPE;
      v_des_transaccion  ge_transacciones.descripcion%TYPE;
      v_cod_sec_contable ge_sec_contables.cod_sec_contable%TYPE;
      v_cod_plazo        ge_plz_contables.cod_plazo%TYPE;
      v_tip_deudor       ge_clientes.cod_tip_deudor%TYPE;
      v_residente        ge_clientes.residente%TYPE;
      v_mto_interes      cb_sim_dev_ahorros.mto_interes%TYPE;
      v_cod_moneda       ah_cta_vistas.cod_moneda%TYPE;
      v_cod_oficina      ah_cta_vistas.cod_oficina%TYPE;
      v_cod_modalidad    ah_cta_vistas.cod_modalidad%TYPE;
      v_cod_modulo       ah_cta_vistas.cod_modulo%TYPE;
      v_cod_transaccion  ge_transacciones.cod_transaccion%TYPE;
      v_cod_pro_contable ge_modalidades.cod_pro_contable%TYPE;
      v_est_cuenta       ge_tip_asientos.est_cuenta%TYPE;
      v_tip_cuenta       ge_tip_asientos.tip_cuenta%TYPE;
      v_tip_interes      ge_tip_asientos.tip_interes%TYPE;
      v_tip_renovacion   ge_tip_asientos.tip_renovacion%TYPE;
      v_cat_automatica   ge_tip_asientos.cat_automatica%TYPE;
      xx_immovgs         NUMBER;
      xx_immovex         NUMBER;
      xx_vltasci         NUMBER;
      --
      vh_nro_asiento    NUMBER;
      wh_immovex        NUMBER;
      wh_vltasci        NUMBER;
      vh_cod_oficina    pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_ofi_origen pr_cta_prestamos.cod_oficina%TYPE;
      vh_cod_modulo     pr_cta_prestamos.cod_modulo%TYPE;
      vh_cod_modalidad  pr_cta_prestamos.cod_modalidad%TYPE;

      wh_immovgs NUMBER;
      wh_dcrefer VARCHAR2(11);
      wh_lgprote VARCHAR2(1);
      wh_lgdeact VARCHAR2(1);
      wh_lgctadi VARCHAR2(1);
      wh_dcdescr VARCHAR2(60);
      --
      v_nro_linea        ge_tip_asientos.nro_linea%TYPE;
      v_cod_rubro        cb_rubros.cod_rubro%TYPE; --wh_cdcuent
      v_cod_sit_contable md_cta_documentos.cod_sit_contable%TYPE;
      v_encontro         VARCHAR2(1);
      v_msj              VARCHAR2(250);
      --
      CURSOR cur3 IS
         SELECT ct.cod_modulo,
                ct.cod_modalidad,
                ct.cod_oficina,
                ct.cod_moneda,
                SUM(nvl(d.mto_dev_actual, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                nvl(mo.cod_pro_contable, 0),
                d.estado,
                ct.cod_sit_contable
           FROM ge_plz_contables  pc,
                cb_sim_dev_mesa d,
                md_cta_documentos ct,
                ge_clientes       c,
                ge_cta_clientes   cc,
                ge_modalidades    mo
          WHERE d.fecha = v_fec_actual
            AND d.nro_cuenta = ct.nro_cuenta
            AND d.nro_cuenta = cc.nro_cuenta
            AND relacion = 'P'
            AND c.cod_persona = cc.cod_persona
            AND mo.cod_modulo = ct.cod_modulo
            AND mo.cod_modalidad = ct.cod_modalidad
               -- si estado = RIPEADO, devengar en plazo del REPO
            AND pc.can_dias =
                (SELECT MIN(can_dias)
                   FROM ge_plz_contables
                  WHERE can_dias >= (decode(d.estado, 'E', (ct.fec_ven_repo - ct.fec_ini_repo),
                                            (ct.fec_vencimiento - ct.fec_inicio))))
          GROUP BY ct.cod_modulo,
                   ct.cod_modalidad,
                   ct.cod_oficina,
                   ct.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   nvl(mo.cod_pro_contable, 0),
                   d.estado,
                   ct.cod_sit_contable;
      --
      v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%TYPE;
      v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%TYPE;
      r_gtasi            ge_tip_asientos%ROWTYPE;
      --
      CURSOR c_tip_asientos IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento IN (v_cod_tip_asiento, v_cod_tip_asiento2)
            AND cod_moneda = v_cod_moneda
            AND (cod_sec_contable = v_cod_sec_contable OR cod_sec_contable IS NULL)
            AND (ind_residente = v_residente OR ind_residente = 'X')
            AND (est_cuenta = v_est_cuenta OR nvl(est_cuenta, 'X') = 'X')
            AND (tip_cuenta = v_tip_cuenta OR nvl(tip_cuenta, 'X') = 'X')
            AND (tip_interes = v_tip_interes OR nvl(tip_interes, 'X') = 'X')
            AND (tip_renovacion = v_tip_renovacion OR nvl(tip_renovacion, 'X') = 'X')
            AND (cat_automatica = v_cat_automatica OR nvl(cat_automatica, -1) = -1)
            AND (cod_sit_contable IS NULL OR cod_sit_contable = v_cod_sit_contable);
   BEGIN
      v_msj := ' Intereses devengados ';
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_modalidad,
                 v_cod_oficina,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_tip_deudor,
                 v_cod_plazo,
                 v_cod_pro_contable,
                 v_est_cuenta,
                 v_cod_sit_contable;
         EXIT WHEN cur3%NOTFOUND;
         IF v_est_cuenta = 'E' THEN
            -- Si es una cuenta con Estado REPO carga la transacción 902
            v_cod_transaccion := 902;
         ELSE
            v_cod_transaccion := 901;
         END IF;
         --- ve el tipo de asiento por el CREDITO
         BEGIN
            SELECT cod_tip_asiento, descripcion, cod_tip_asiento2
              INTO v_cod_tip_asiento, v_des_transaccion, v_cod_tip_asiento2
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_modalidad
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'Transaccion ' || to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_modalidad) || '-' || v_est_cuenta ||
                                        ' no tiene asiento de Credito definido.');
            WHEN OTHERS THEN
               IF SQLCODE <= -20000 THEN
                  RAISE;
               ELSE
                  raise_application_error(-20001, 'Error lp_int_devengados ' || SQLERRM);
               END IF;
         END;
         ------------------
         -- ve la moneda --
         ------------------
         IF v_cod_moneda = v_cod_mon_local THEN
            -- es moneda nacional --
            ------------------------
            xx_immovgs := v_mto_interes;
            xx_immovex := 0;
            xx_vltasci := 0;
         ELSE
            IF fug_obt_tip_implementacion = 1 THEN
               -- se obtiene la cotizacion de venta
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            ELSE
               -- se obtiene la cotizacion de cierre
               v_mto_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
            END IF;
            xx_immovgs := round(v_mto_interes * v_mto_cotizacion, 0);
            xx_immovex := v_mto_interes;
            xx_vltasci := v_mto_cotizacion;
         END IF;
         
         -- REPO-CNF-12/2015: Para documentos Ripeados se cambia para tomar los rubros correctos
         If v_est_cuenta = 'R' Then
           v_cod_sit_contable := '10000003';
         End If;
         
         ----- ciclo para GE_TIP_ASIENTOS ------
         -------------------------------
         IF c_tip_asientos%ISOPEN THEN
            CLOSE c_tip_asientos;
         END IF;
         OPEN c_tip_asientos;
         v_nro_linea := 0;
         LOOP
            FETCH c_tip_asientos
               INTO r_gtasi;
            EXIT WHEN c_tip_asientos%NOTFOUND;
            ---Reemplaza el valor del tipo de deudor, si importa-
            IF r_gtasi.ind_deudor = 'S' THEN
               v_cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) || ltrim(to_char(v_tip_deudor, '00')) ||
                              substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               v_cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---Reemplaza el codigo del plazo si es necesario -----
            IF r_gtasi.ind_plazo = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                              substr(v_cod_rubro, 4, 12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_gtasi.ind_producto = 'S' THEN
               v_cod_rubro := substr(v_cod_rubro, 1, 10) ||
                              ltrim(to_char(v_cod_pro_contable, '000')) ||
                              substr(v_cod_rubro, 14, 2);
            END IF;
            ------------------------------------------------------
            v_encontro := 'S';
            lp_obt_mon_rubro(v_cod_rubro, v_mon_rubro, v_encontro);
            IF v_encontro = 'N' THEN
               v_msj := 'Cuenta inexistente en Plan de Cuentas ' || v_cod_rubro;
               --v_cod_rubro  := '999999999999999';
               v_mon_rubro := v_cod_mon_local;
            END IF;
            IF v_mon_rubro = v_cod_mon_local THEN
               -- moneda local --
               wh_immovex := 0;
               wh_vltasci := 0;
            ELSE
               wh_immovex := xx_immovex;
               wh_vltasci := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            v_tip_movimiento := r_gtasi.tip_movimiento;
            IF xx_immovgs > 0 THEN
               v_tip_movimiento := r_gtasi.tip_movimiento;
               wh_immovgs       := xx_immovgs;
            ELSE
               wh_immovgs := xx_immovgs * -1;
               wh_immovex := wh_immovex * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  v_tip_movimiento := 'D';
               ELSE
                  v_tip_movimiento := 'C';
               END IF;
            END IF;
            ------------------------------------------------------
            wh_dcrefer        := 'DEVENG.';
            wh_dcdescr        := substr(to_char(v_cod_modulo) || ' ' || to_char(v_cod_modalidad) || ' ' ||
                                        to_char(v_est_cuenta) || ' ' || v_des_transaccion, 1, 60);
            vh_cod_oficina    := v_cod_oficina;
            vh_cod_modulo     := v_cod_modulo;
            vh_cod_modalidad  := v_cod_modalidad;
            vh_cod_ofi_origen := v_cod_oficina;
            wh_lgprote        := 'N';
            wh_lgdeact        := 'N';
            wh_lgctadi        := 'N'; ----r_gtasi.at_lgctadi;-- Ver que campo es
            vh_nro_asiento    := 0;
            v_cod_mod_padre   := v_cod_modulo;
            v_cod_mad_padre   := v_cod_modalidad;
            -----
            IF wh_immovgs <> 0 THEN
               v_nro_linea := v_nro_linea + 1;
               --- Cargar registro de asientos detalles
               r_baade.fecha          := v_fec_actual;
               r_baade.cod_oficina    := vh_cod_oficina;
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := v_nro_linea;
               r_baade.cod_rubro      := v_cod_rubro;
               r_baade.tip_movimiento := v_tip_movimiento;
               r_baade.mto_mon_rubro  := wh_immovex;
               r_baade.mto_mon_local  := wh_immovgs;
               r_baade.descripcion    := wh_dcdescr;
               r_baade.referencia     := wh_dcrefer;
               r_baade.protegido      := wh_lgprote;
               r_baade.actualizado    := wh_lgdeact;
               r_baade.val_cotizacion := wh_vltasci;
               r_baade.distribuido    := wh_lgctadi;
               r_baade.ref_movimiento := NULL;
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --         
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   -- Intereses Devengados Operaciones Futuras.
   PROCEDURE lp_dev_ope_futuras IS
      v_fec_actual      ge_calendarios.fec_actual%TYPE := pae_cnf.fu_obt_fec_actual(7);
      v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
      v_cod_mon_cta     ba_monedas.cod_moneda%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
      v_descripcion     ge_transacciones.descripcion%TYPE;
      v_cod_tip_asiento ge_transacciones.cod_tip_asiento%TYPE;
      v_encontro        VARCHAR2(1);
      -- Variables Cursor
      v_cod_modulo          lc_devengados.cod_modulo%TYPE;
      v_cod_mad_transaccion lc_devengados.cod_mad_transaccion%TYPE;
      v_cod_ofi_origen      lc_devengados.cod_oficina%TYPE;
      v_cod_moneda          lc_devengados.cod_moneda%TYPE;
      v_mto_interes         lc_devengados.mto_interes%TYPE;
      v_cod_mad_padre       lc_devengados.cod_mad_padre%TYPE;
      v_descuento           lc_devengados.descuento%TYPE;
      v_residente           ge_clientes.residente%TYPE;
      v_cod_sec_contable    ge_clientes.cod_sec_contable%TYPE;
      v_cod_tip_deudor      ge_clientes.cod_tip_deudor%TYPE;
      v_cod_plazo           ge_plz_contables.cod_plazo%TYPE;
      --
      xx_immovgs NUMBER;
      xx_immovex NUMBER;
      xx_vltasci NUMBER;
      --
      r_baade cb_sim_asientos_det%ROWTYPE;
      r_gtasi ge_tip_asientos%ROWTYPE;
      ----------------------------------------------------------------------
      -- Leer todas las operaciones a futuro vigentes -- MODALIDAD = 76   --
      ----------------------------------------------------------------------
      CURSOR cur3 IS
         SELECT d.cod_modulo,
                d.cod_mad_transaccion,
                d.cod_ofi_origen,
                d.cod_moneda,
                SUM(nvl(d.mto_interes, 0)),
                c.cod_sec_contable,
                c.residente,
                c.cod_tip_deudor,
                nvl(pc.cod_plazo, 0),
                d.cod_mad_padre,
                d.descuento
           FROM cb_sim_dev_futuras d,
                lc_ope_futuras o,
                ge_clientes    c,
                ge_plz_contables pc
          WHERE d.fecha = v_fec_actual
            AND d.cod_modalidad = o.cod_modalidad
            AND d.cod_oficina = o.cod_oficina
            AND d.nro_cuenta = o.nro_cuenta
            AND d.nro_operacion = o.nro_operacion
            AND d.cod_mad_transaccion = o.cod_mad_transaccion
            AND c.cod_persona = o.cod_persona
            AND pc.can_dias =
                (SELECT MIN(gp.can_dias)
                   FROM ge_plz_contables gp
                  WHERE can_dias >= (o.fec_vencimiento - o.fec_operacion))
          GROUP BY d.cod_modulo,
                   d.cod_mad_transaccion,
                   d.cod_ofi_origen,
                   d.cod_moneda,
                   c.cod_sec_contable,
                   c.residente,
                   c.cod_tip_deudor,
                   pc.cod_plazo,
                   d.cod_mad_padre,
                   d.descuento
         HAVING SUM(nvl(d.mto_interes, 0)) > 0;
      --
      CURSOR cur5 IS
         SELECT *
           FROM ge_tip_asientos
          WHERE cod_tip_asiento = v_cod_tip_asiento
            AND cod_moneda = v_cod_moneda
            AND cod_sec_contable = v_cod_sec_contable
            AND (ind_residente = v_residente OR ind_residente = 'X');
   BEGIN
      OPEN cur3;
      LOOP
         FETCH cur3
            INTO v_cod_modulo,
                 v_cod_mad_transaccion,
                 v_cod_ofi_origen,
                 v_cod_moneda,
                 v_mto_interes,
                 v_cod_sec_contable,
                 v_residente,
                 v_cod_tip_deudor,
                 v_cod_plazo,
                 v_cod_mad_padre,
                 v_descuento;
         EXIT WHEN cur3%NOTFOUND;
         --- ve el tipo de asiento ---
         IF v_cod_mad_padre = 76 THEN
            -- operaciones futuras --
            IF v_cod_mad_transaccion = 71 THEN
               -- es una compra --
               IF v_descuento = 'N' THEN
                  -- es un premio --
                  v_cod_transaccion := 1901;
               ELSE
                  v_cod_transaccion := 1902;
               END IF;
            ELSE
               -- es una venta --
               IF v_descuento = 'N' THEN
                  -- es un premio --
                  v_cod_transaccion := 1902;
               ELSE
                  v_cod_transaccion := 1901;
               END IF;
            END IF;            
         ELSE
            raise_application_error(-20004,
                                    'ERROR. La modalidad ' || to_char(v_cod_mad_padre) ||
                                     ' no esta definida ');
         END IF;
         BEGIN
            SELECT cod_tip_asiento, descripcion
              INTO v_cod_tip_asiento, v_descripcion
              FROM ge_transacciones
             WHERE cod_modulo = v_cod_modulo
               AND cod_modalidad = v_cod_mad_transaccion
               AND cod_transaccion = v_cod_transaccion
               AND cod_tip_asiento IS NOT NULL;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'No tiene Asiento Relac. para Deveng.: ' ||
                                        to_char(v_cod_modulo) || '-' ||
                                        to_char(v_cod_mad_transaccion) || '-' ||
                                        to_char(v_cod_transaccion));
            WHEN OTHERS THEN
               raise_application_error(-20001, SQLERRM);
         END;
         ------------------------
         xx_immovgs := v_mto_interes;
         xx_immovex := 0;
         xx_vltasci := 0;
         -------------------------------
         ----- ciclo para GE_TIP_ASIENTOS ------

         IF cur5%ISOPEN THEN
            CLOSE cur5;
         END IF;
         OPEN cur5;
         r_baade.nro_linea := 0;
         r_baade.fecha     := v_fec_actual;
         LOOP
            FETCH cur5
               INTO r_gtasi;
            EXIT WHEN cur5%NOTFOUND;
            ---Agregado por agustin para el nuevo plan de cuentas ---
            IF r_gtasi.ind_deudor = 'S' THEN
               r_baade.cod_rubro := substr(r_gtasi.cod_rubro, 1, 8) ||
                                    ltrim(to_char(v_cod_tip_deudor, '00')) ||
                                    substr(r_gtasi.cod_rubro, 11, 5);
            ELSE
               r_baade.cod_rubro := r_gtasi.cod_rubro;
            END IF;
            ---------------------------------------------------------
            IF r_gtasi.ind_plazo = 'S' THEN
               r_baade.cod_rubro := substr(r_baade.cod_rubro, 1, 2) || ltrim(to_char(v_cod_plazo)) ||
                                    substr(r_baade.cod_rubro, 4, 12);
            END IF;
            --
            v_encontro := 'S';
            --
            lp_obt_mon_rubro(r_baade.cod_rubro, v_cod_mon_cta, v_encontro);
            IF v_encontro = 'N' THEN
               --r_baade.cod_rubro  := '999999999999999';
               v_cod_mon_cta := v_cod_mon_local;
            END IF;
            --
            IF v_cod_mon_cta = v_cod_mon_local THEN
               -- moneda local --
               r_baade.mto_mon_rubro  := 0;
               r_baade.val_cotizacion := 0;
            ELSE
               r_baade.mto_mon_rubro  := xx_immovex;
               r_baade.val_cotizacion := xx_vltasci;
            END IF;
            -- ve el tipo de movimiento --
            ------------------------------
            IF xx_immovgs > 0 THEN
               r_baade.tip_movimiento := r_gtasi.tip_movimiento;
               r_baade.mto_mon_local  := xx_immovgs;
            ELSE
               r_baade.mto_mon_local := xx_immovgs * -1;
               r_baade.mto_mon_rubro := r_baade.mto_mon_rubro * -1;
               IF r_gtasi.tip_movimiento = 'C' THEN
                  r_baade.tip_movimiento := 'D';
               ELSE
                  r_baade.tip_movimiento := 'C';
               END IF;
            END IF;
            IF r_baade.mto_mon_local <> 0 THEN
               --
               r_baade.referencia     := 'DEVENG.';
               r_baade.descripcion    := to_char(v_cod_modulo) || ' ' ||
                                         to_char(v_cod_mad_transaccion) || ' ' ||
                                         to_char(v_cod_transaccion) || ' ' ||
                                         substr(v_descripcion, 1, 20);
               r_baade.cod_oficina    := v_cod_ofi_origen;
               r_baade.protegido      := 'N';
               r_baade.actualizado    := 'N';
               r_baade.distribuido    := 'N';
               r_baade.nro_asiento    := 0;
               r_baade.nro_linea      := r_baade.nro_linea + 1;
               --
               lp_ins_asi_sim_det(r_baade);
            END IF;
         END LOOP; -- fin de tipo de asientos --
      END LOOP; -- fin del ciclo de intereses devengados --
   END;
   /* Insertar asientos automaticos detalles. */
   PROCEDURE lp_ins_asi_sim_det(rp_baade IN cb_sim_asientos_det%ROWTYPE) IS
   BEGIN
      INSERT INTO cb_sim_asientos_det
         (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro, tip_movimiento, mto_mon_rubro,
          mto_mon_local, descripcion, referencia, protegido, actualizado, val_cotizacion,
          distribuido, ref_movimiento, fec_valor)
      VALUES
         (rp_baade.fecha, rp_baade.cod_oficina, rp_baade.nro_asiento, rp_baade.nro_linea,
          rp_baade.cod_rubro, rp_baade.tip_movimiento, rp_baade.mto_mon_rubro,
          rp_baade.mto_mon_local, rp_baade.descripcion, rp_baade.referencia, rp_baade.protegido,
          rp_baade.actualizado, rp_baade.val_cotizacion, rp_baade.distribuido,
          rp_baade.ref_movimiento, rp_baade.fec_valor);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Ins.cb_sim_asientos_det ' || rp_baade.nro_asiento || '-' ||
                                  rp_baade.referencia || '-' || SQLERRM);
   END;
   /* Obtener la moneda del rubro del parametro. */
   PROCEDURE lp_obt_mon_rubro
   (
      p_cod_rubro  IN cb_rubros.cod_moneda%TYPE,
      p_cod_moneda IN OUT cb_rubros.cod_moneda%TYPE,
      p_encontro   IN OUT VARCHAR2
   ) IS
   BEGIN
      SELECT cod_moneda INTO p_cod_moneda FROM cb_rubros WHERE cod_rubro = p_cod_rubro;
   EXCEPTION
      WHEN no_data_found THEN
         IF substr(p_cod_rubro, 14, 2) IN ('99', '00') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_local;
            p_encontro   := 'S';
         ELSIF substr(p_cod_rubro, 14, 2) IN ('01', '98') THEN
            p_cod_moneda := pag_gen.fu_obt_mon_fuerte;
            p_encontro   := 'S';
         ELSE
            -- OJO!! temporal hasta aqui -------------------------
            p_encontro := 'N';
         END IF;
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Rec. Rubro ' || p_cod_rubro || '-' || SQLERRM);
   END;
BEGIN
   v_lugar := 'INICIO';
   --
   sql_util.ejecute_dml('alter table CB_SIM_ASIENTOS_DET disable constraint PK_CB_SIM_ASIENTOS_DET',
                        v_error);
   IF v_error IS NOT NULL THEN
      raise_application_error(-20000, 'Disable PK ' || v_error);
   END IF; 
   --Obtiene las Fechas necesarias----------------------
   pag_cal.pr_obt_dat_calendar(2);
   v_fec_actual        := p_fecha;
   v_fec_proceso       := pag_cal.G_ULT_DIA_MES; -- Para el devengado de diferidos.
   v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;
   -----------------------------------------------------
   --Obtiene la Moneda Local
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   -----------------------------------------------------
   v_cod_oficina := 0;
   -----------------------------------
   -- limpia las tablas de asientos --
   ------------------------------------------------------------------------
   DELETE cb_sim_asientos_det;

   ---llama a procedimientos --
   ----------------------------
   --
   v_lugar := 'LP_EQU_MON_LOCAL';
   lp_equ_mon_local;
   v_lugar := 'LP_ESTADISTICO';
   lp_estadistico;
   v_lugar := 'LP_MOV_DIARIOS';
   lp_mov_diarios;
   v_lugar := 'LP_INT_DEVENGADOS';
   lp_int_devengados;
   v_lugar := 'LP_INT_DEV_PRESTAMOS';
   lp_int_dev_prestamos;
   v_lugar := 'LP_INT_DEV_COMISIONES';
   lp_int_dev_comisiones;
   v_lugar := 'LP_INT_DEV_MESADINERO';
   lp_int_dev_mesadinero;
   v_lugar := 'LP_DEV_OPE_FUTURAS';
   lp_dev_ope_futuras;
   v_lugar := 'LP_CAB_ASIENTO';
   -----------------------------------------------------------
   -- genera la cabecera a partir de los detalles generados --
   -----------------------------------------------------------
   lp_cab_asiento;
   v_lugar := 'FIN LP_CAB_ASIENTO';
   ---borrar asientos nro 0---
   BEGIN
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
   END;
   DELETE FROM cb_sim_asientos_det t WHERE t.nro_asiento = 0;
   --
   sql_util.ejecute_dml('alter table CB_SIM_ASIENTOS_DET enable constraint PK_CB_SIM_ASIENTOS_DET',
                        v_error);
   IF v_error IS NOT NULL THEN
      raise_application_error(-20000, 'Enable PK ' || v_error);
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20001, 'Error en proc. ' || v_lugar ||'-'|| sqlerrm);
END;

/* Obtiene los asientos futuros */
PROCEDURE PR_ASI_FUTUROS(p_fecha in ge_calendarios.fec_actual%type) is
   
   -- Variables.
   v_fec_actual     date        := p_fecha;
   v_fec_mes        date;
   v_nro_asiento    number;
   v_procesar       varchar2(1) := 'N';
   
   -- Cursores.
   CURSOR asi IS
      SELECT COD_OFICINA, NRO_ASIENTO, COD_CARGO, FECHA, ROWID FILA
        FROM CB_ASI_FUTUROS
       WHERE FECHA <= v_fec_mes
         AND nro_asi_real IS NULL;

begin
   pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
   -- Obtengo la fecha del último día del mes.
   BEGIN
      SELECT last_day(v_fec_actual) 
        INTO v_fec_mes
        FROM dual;
   EXCEPTION
      WHEN OTHERS THEN 
         v_fec_mes := p_fecha;
   END;
   -- Obtengo el número de asiento.
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_REF_BALANCE');
   FOR a in asi LOOP
     -- Se agregan nuevos datos el 07/10/2011 para dejar como backup del asiento futuro el asiento real
     -- Realizado por Ingrid Larraín para optimización de espacio
     -- inserto la cabecera
     insert into cb_sim_asientos
           (cod_oficina, nro_asiento, cod_usuario, fecha,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fec_valor, nro_asi_futuro, cod_cargo)
     select cod_oficina, v_nro_asiento, cod_usuario, v_fec_actual,
            cod_modulo, cod_modalidad,
            tot_control, actualizado, reversado, cod_ofi_origen,
            ofi_integrada, confirmado, fecha, nro_asiento, cod_cargo
       from cb_asi_futuros
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and nro_asi_real is null
        and fecha = a.fecha;
     -- inserto los detalles de los asientos
     insert into cb_sim_asientos_det
           (fecha, cod_oficina, nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fec_valor)
     select v_fec_actual, cod_oficina, v_nro_asiento, nro_linea, cod_rubro,
            tip_movimiento, mto_mon_rubro, mto_mon_local,
            descripcion, referencia, protegido, actualizado,
            val_cotizacion, distribuido, ref_movimiento, fecha
       from cb_asi_futuros_det
      where cod_oficina = a.cod_oficina
        and nro_asiento = a.nro_asiento
        and fecha = a.fecha;
     -- incrementa numero de asiento
     v_nro_asiento := v_nro_asiento + 1;
     v_procesar := 'S';     
     --
   END LOOP;

   ------- ACTUALIZA PARAMETROS -----
   if v_procesar = 'S' then
      prg_act_par_dinamico('SIG_NRO_REF_BALANCE',null, null, null, null, v_nro_asiento);
   end if;
end;

/* Proceso que valida los asientos contables */
PROCEDURE PR_VAL_ASIENTOS(p_fecha in ge_calendarios.fec_actual%type) IS
  -- Variables.
  v_debito        NUMBER;
  v_credito       NUMBER;
  v_deb_mon_rubro NUMBER;
  v_cre_mon_rubro NUMBER;
  v_imputable     VARCHAR2(1);
  v_fec_actual    date   := p_fecha;

 ------- para cabecera de asientos ------
  R_CAB   cb_sim_asientos%rowtype;
  CURSOR CAB is SELECT *
                  FROM   cb_sim_asientos
                   FOR UPDATE OF CONFIRMADO;
 ------ detalle de asientos -------
  R_DET   cb_sim_asientos_det%rowtype;
  CURSOR DET is SELECT *
                FROM  cb_sim_asientos_det
                WHERE COD_OFICINA = R_CAB.COD_OFICINA
                  AND NRO_ASIENTO = R_CAB.NRO_ASIENTO;
  ----------------------------------
  CURSOR CTA is SELECT IMPUTABLE
                FROM CB_RUB_OFICINAS B,CB_RUBROS A
               WHERE B.COD_OFICINA = R_CAB.COD_OFICINA
                 AND A.COD_RUBRO = R_DET.COD_RUBRO
                 AND B.COD_RUBRO = A.COD_RUBRO;
  --
  v_nro_asiento   cb_sim_validaciones.nro_asiento%type;
  v_nro_linea     cb_sim_validaciones.nro_linea%type;
  v_msj_error     cb_sim_validaciones.error%type;
  v_cod_modulo    cb_sim_validaciones.cod_modulo%type;
  v_cod_modalidad cb_sim_validaciones.cod_modalidad%type;
  v_cod_oficina   cb_sim_validaciones.cod_oficina%type;
  v_error         cb_sim_validaciones.error%type;
  --
  PROCEDURE LP_GEN_ERROR IS
      BEGIN
         INSERT INTO cb_sim_validaciones
            (FECHA, NRO_ASIENTO, NRO_LINEA, ERROR,
             COD_MODULO, COD_MODALIDAD, COD_OFICINA)
         VALUES(v_fec_actual, v_nro_asiento,v_nro_linea, v_msj_error,
             v_cod_modulo,v_cod_modalidad, v_cod_oficina);
  END;

BEGIN
 -- limpia archivo CB_VALIDACIONES
 delete cb_sim_validaciones where nro_asiento <> -1;
 ----- verifica si hay asientos para validar -----
  OPEN CAB;
  LOOP
     FETCH CAB INTO R_CAB;
     EXIT WHEN CAB%notfound;
     ------- INICIO VALIDA CABECERA -------
     v_cod_modulo    := R_CAB.COD_MODULO;
     v_cod_modalidad := R_CAB.COD_MODALIDAD;
     v_nro_asiento   := R_CAB.NRO_ASIENTO;
     v_cod_oficina   := R_CAB.COD_OFICINA;
     v_nro_linea     := 0;
     v_msj_error     := NULL;
     --------- FIN VALIDA CABECERA --------
     -- ve los detalles de los asientos que corresponden --
     ------------------------------------------------------
     IF DET%isopen THEN
        CLOSE DET;
     END IF;
      OPEN DET;
      v_debito   := 0;
      v_credito   := 0;
      v_deb_mon_rubro := 0;
      v_cre_mon_rubro := 0;
      LOOP
         FETCH DET INTO R_DET;
         EXIT WHEN DET%notfound;
         v_nro_linea := R_DET.NRO_LINEA;
         IF CTA%ISOPEN THEN
            CLOSE CTA;
         END IF;
         OPEN CTA;
         FETCH CTA INTO v_imputable;
         IF CTA%NOTFOUND THEN
            v_msj_error :='No existe cuenta ' || r_det.COD_RUBRO
            || ' en CB_RUB_OFICINAS';
            LP_GEN_ERROR;
         END IF;
         IF v_imputable = 'N' THEN
            v_msj_error :='Cuenta '||r_det.COD_RUBRO||' no es '||
            'imputable ';
            LP_GEN_ERROR;
         END IF;
         IF R_DET.TIP_MOVIMIENTO = 'D' THEN
            v_debito   := v_debito   + NVL(R_DET.MTO_MON_LOCAL,0);
            v_deb_mon_rubro := v_deb_mon_rubro + NVL(R_DET.MTO_MON_RUBRO,0);
         ELSIF R_DET.TIP_MOVIMIENTO = 'C' THEN
            v_credito   := v_credito   + NVL(R_DET.MTO_MON_LOCAL,0);
            v_cre_mon_rubro := v_cre_mon_rubro + NVL(R_DET.MTO_MON_RUBRO,0);
         ELSE
           v_msj_error := 'Tipo de Movimiento Invalido ' ;
            LP_GEN_ERROR;
         END IF;
         IF R_DET.MTO_MON_LOCAL = 0 THEN
            v_msj_error := 'Importe Gs = 0 ';
            LP_GEN_ERROR;
         END IF;
         IF R_DET.REFERENCIA IS NULL AND
            R_DET.DESCRIPCION IS NULL THEN
            v_msj_error := 'Descripcion y Referencia en blanco' ;
            LP_GEN_ERROR;
         END IF;
         IF R_DET.MTO_MON_LOCAL <> TRUNC(R_DET.MTO_MON_LOCAL) THEN
            v_msj_error := 'Cuenta '||r_det.COD_RUBRO||' Moneda local con decimales' ;
            LP_GEN_ERROR;
         END IF;
      END LOOP;
      v_nro_linea := v_nro_linea + 1;
      IF DET%rowcount > 0 THEN
         IF v_debito <> v_credito THEN
            v_msj_error := 'Asiento no balancea.' ;
            LP_GEN_ERROR;
            IF R_CAB.CONFIRMADO = 'S' THEN
               v_nro_linea := v_nro_linea + 1;
               v_msj_error := 'Asiento no balancea y marcado OK.';
               LP_GEN_ERROR;
            END IF;
         ELSE
            IF v_debito * 2 <> R_CAB.TOT_CONTROL THEN
               v_msj_error := 'Total de Control no coincide con suma de debitos y creditos ';
               LP_GEN_ERROR;
            END IF;
         END IF;
      ELSE
         v_msj_error  := 'No existen lineas de detalle ';
         LP_GEN_ERROR;
      END IF;
      IF v_msj_error is not null THEN
         UPDATE cb_sim_asientos SET CONFIRMADO = 'N' WHERE CURRENT OF CAB;
      ELSE
         UPDATE cb_sim_asientos SET CONFIRMADO = 'S' WHERE CURRENT OF CAB;
      END IF;
  END LOOP;
  IF CAB%rowcount = 0 THEN
     RAISE_APPLICATION_ERROR(-20000,' ERROR. No existen asientos para validar en esta fecha');
  END IF;
  CLOSE CAB;
  CLOSE DET;

  begin
    select /*count(*),*/nro_asiento,error
      into /*v_cantidad,*/v_nro_asiento,v_error
      from cb_sim_validaciones
     where rownum = 1
       and nro_asiento <> -1;
    if /*v_cantidad*/length(v_error) > 0 then
       RAISE_APPLICATION_ERROR(-20000,' Existe error en el Asiento Nro.: '||v_nro_asiento||' Error: '||v_error);
    end if;
  exception
    when no_data_found then
      null;
  end;  
---------------------------------
EXCEPTION
   WHEN OTHERS THEN
     IF CAB%isopen THEN
        CLOSE CAB;
     END IF;
     IF DET%isopen THEN
        CLOSE DET;
     END IF;
     IF sqlcode <= -20000 THEN
       raise;
     ELSE
       RAISE_APPLICATION_ERROR(-20000,'Error en la validacion de Asientos '||sqlerrm);
     END IF;
END;

/* Actualiza los saldos del Balance */
PROCEDURE PR_ACT_SALDOS(p_fecha in ge_calendarios.fec_actual%type) 
IS
  -- Cursores.
  CURSOR SALD_M IS
         SELECT CB_SIM_ASIENTOS.COD_OFICINA, CB_SIM_ASIENTOS_DET.COD_RUBRO,
                CB_SIM_ASIENTOS_DET.TIP_MOVIMIENTO, BA_OFICINAS.DESCRIPCION,
                SUM(NVL(CB_SIM_ASIENTOS_DET.MTO_MON_LOCAL,0)),
                SUM(NVL(CB_SIM_ASIENTOS_DET.MTO_MON_RUBRO,0)),
                decode(substr(cb_rubros.cod_rubro,14,2),'98','USD',CB_RUBROS.COD_MONEDA)
           FROM CB_RUBROS, CB_SIM_ASIENTOS, CB_SIM_ASIENTOS_DET, BA_OFICINAS
          WHERE CB_SIM_ASIENTOS.COD_OFICINA = CB_SIM_ASIENTOS_DET.COD_OFICINA
            AND CB_SIM_ASIENTOS.COD_OFICINA = BA_OFICINAS.COD_OFICINA
            AND CB_SIM_ASIENTOS.NRO_ASIENTO = CB_SIM_ASIENTOS_DET.NRO_ASIENTO
            AND CB_SIM_ASIENTOS.CONFIRMADO = 'S'
            AND CB_SIM_ASIENTOS.ACTUALIZADO = 'N'
            AND CB_RUBROS.COD_RUBRO = CB_SIM_ASIENTOS_DET.COD_RUBRO
          GROUP BY CB_SIM_ASIENTOS.COD_OFICINA, CB_SIM_ASIENTOS_DET.COD_RUBRO,
                   CB_SIM_ASIENTOS_DET.TIP_MOVIMIENTO, BA_OFICINAS.DESCRIPCION,
                  decode(substr(cb_rubros.cod_rubro,14,2),'98','USD',CB_RUBROS.COD_MONEDA);
  -- Variables.
  CDOFICI      NUMBER(03);
  IMMOVGS      NUMBER(18,2);
  IMMONEX      NUMBER(18,2);
  WW_IMMOUSD   NUMBER(18,2);
  CDCUENT      VARCHAR2(15);
  TPMOVIM      VARCHAR2(01);
  NMOFICI      VARCHAR2(35);
  WCDMONED     VARCHAR2(4) ;
  W_MON_FUERTE VARCHAR2(4) := PAG_GEN.FU_OBT_MON_FUERTE;
  W_MON_LOCAL  VARCHAR2(4) := PAG_GEN.FU_OBT_MON_LOCAL;
  --
  v_fec_actual date := p_fecha;
  v_ano number(4)   := to_char(v_fec_actual,'yyyy');
  v_mes number(2)   := to_char(v_fec_actual,'mm');
  --
  PROCEDURE lp_sum_sal_consolidados(WCDCUENT IN CHAR,
                                    WTPMOVIM IN CHAR,
                                    WIMMOVGS IN NUMBER,
                                    WIMMONEX IN NUMBER,
                                    WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                ---------------------------------------------------------
                -- VERIFICA SI EXISTE EN CB_SAL_CONSOLIDADOS EL PADRE
                ---------------------------------------------------------
                BEGIN
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SIM_SAL_CONSOLIDADOS
                   WHERE COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                       INSERT INTO CB_SIM_SAL_CONSOLIDADOS
                                       (COD_RUBRO, ANO, MES, PROTEGIDO)
                                VALUES (CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - '||sqlerrm);
                END;
                IF WTPMOVIM = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE CB_SIM_SAL_CONSOLIDADOS
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE CB_SIM_SAL_CONSOLIDADOS
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                END IF;
             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuenta');
  END;
  --
  PROCEDURE lp_ins_rub_oficinas(WCDOFICI IN NUMBER, WCDCUENT IN CHAR) IS
  CDCUENT VARCHAR2(15);
  CDDIGVE NUMBER(01);
  CDCTDFC VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  CDTIPCT NUMBER(01);
  CDNIVCT NUMBER(02);
  NRMAYOR NUMBER(05);
  BEGIN
  SELECT COD_RUBRO, null, null, COD_RUB_PADRE,
         TIPO, NIVEL, ULT_NRO_MAYOR
    INTO CDCUENT, CDDIGVE, CDCTDFC, CDCTPAD,
         CDTIPCT, CDNIVCT, NRMAYOR
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     INSERT INTO CB_RUB_OFICINAS (COD_OFICINA, COD_RUBRO, ULT_NRO_EXTRACTO)
                  VALUES (WCDOFICI, CDCUENT, NRMAYOR);
     LOOP
     BEGIN
     SELECT COD_RUBRO, COD_RUB_PADRE, TIPO, NIVEL, ULT_NRO_MAYOR
       INTO CDCUENT, CDCTPAD, CDTIPCT, CDNIVCT, NRMAYOR
       FROM CB_RUBROS
      WHERE COD_RUBRO = CDCTPAD;
         IF SQL%FOUND THEN
            INSERT INTO CB_RUB_OFICINAS
            SELECT WCDOFICI, CDCUENT, NRMAYOR, USER, SYSDATE, USER, SYSDATE
              FROM DUAL
             WHERE NOT EXISTS (SELECT 'X' FROM CB_RUB_OFICINAS
                                WHERE COD_OFICINA = WCDOFICI
                                  AND COD_RUBRO = CDCUENT);
         END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     EXIT;
     END;
     END LOOP;
  END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||' inexistente en el Plan de Cuentas Consolidado');
  END;
  --
  PROCEDURE lp_ins_sal_consolidados(WCDCUENT IN CHAR,
                               WTPMOVIM IN VARCHAR2,
                               WIMMOVGS IN NUMBER,
                               WIMMONEX IN NUMBER,
                               WIMMOUSD IN NUMBER,
                               WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  LGPROTE VARCHAR2(01) := 'N'; ---
  V_MON_EQU_LOCAL NUMBER(18,2) := 0;
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     IF WCDMONED <> W_MON_LOCAL THEN
        V_MON_EQU_LOCAL := WIMMOVGS;
     END IF;

     IF WTPMOVIM = 'D' THEN
        -----------------------------------------------------------------
        -- INSERTA SALDO DE DEBITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_CONSOLIDADOS (COD_RUBRO, ANO, MES, DEB_MON_LOCAL, DEB_MON_RUBRO, PROTEGIDO, DEB_EQU_LOCAL)
                     VALUES (CDCUENT, v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE,V_MON_EQU_LOCAL);
     ELSE
        -----------------------------------------------------------------
        -- INSERTA SALDO DE CREDITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_CONSOLIDADOS (COD_RUBRO, ANO, MES, CRE_MON_LOCAL, CRE_MON_RUBRO, PROTEGIDO, CRE_EQU_LOCAL)
                     VALUES (CDCUENT,  v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE, V_MON_EQU_LOCAL);
      END IF;
      lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
     END IF;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||' inexistente en Plan de Cuentas Consolidado');
  END;
  ---
  PROCEDURE lp_sum_sal_oficinas(WCDOFICI IN NUMBER,
                             WCDCUENT IN CHAR,
                             WTPMOVIM IN CHAR,
                             WIMMOVGS IN NUMBER,
                             WIMMONEX IN NUMBER,
                             WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN CB_SAL_OFICINAS
                  ---------------------------------------------------------
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SIM_SAL_OFICINAS
                   WHERE COD_OFICINA = WCDOFICI
                     AND COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, PROTEGIDO)
                                            VALUES (WCDOFICI, CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - Ofic '||wcdofici||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                   IF WTPMOVIM = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE CB_SIM_SAL_OFICINAS
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                   ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE CB_SIM_SAL_OFICINAS
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                   END IF;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||' inexistente en Plan de Cuenta');
  END;
  --
  PROCEDURE lp_ins_sal_oficinas(WCDOFICI IN NUMBER,
                                WCDCUENT IN CHAR,
                                WTPMOVIM IN CHAR,
                                WIMMOVGS IN NUMBER,
                                WIMMONEX IN NUMBER,
                                WIMMOUSD IN NUMBER,
                                WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  LGPROTE VARCHAR2(01) := 'N'; ---
  V_MON_EQU_LOCAL NUMBER(18,2) := 0;
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     IF WCDMONED <> W_MON_LOCAL THEN
        V_MON_EQU_LOCAL := WIMMOVGS;
     END IF;
     IF WTPMOVIM = 'D' THEN
        -----------------------------------------------------------------
        -- INSERTA SALDO DE DEBITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, DEB_MON_LOCAL, DEB_MON_RUBRO, PROTEGIDO, DEB_EQU_LOCAL)
                     VALUES (WCDOFICI, CDCUENT,  v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE,V_MON_EQU_LOCAL);
     ELSE
        -----------------------------------------------------------------
        -- INSERTA SALDO DE CREDITO
        -----------------------------------------------------------------
        INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, CRE_MON_LOCAL, CRE_MON_RUBRO, PROTEGIDO, CRE_EQU_LOCAL)
                     VALUES (WCDOFICI, CDCUENT,  v_ano, v_mes, WIMMOVGS, WIMMONEX, LGPROTE, V_MON_EQU_LOCAL);
      END IF;
  END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuentas Consolidado');
  END;
  --
  PROCEDURE lp_act_asientos(WCDOFICI IN NUMBER,
                            WCDCUENT IN CHAR,
                            WTPMOVIM IN CHAR) IS
     cursor c_asientos is
     select fecha, cod_oficina, nro_asiento
       from CB_SIM_ASIENTOS
      WHERE CB_SIM_ASIENTOS.COD_OFICINA = WCDOFICI
        AND CB_SIM_ASIENTOS.NRO_ASIENTO IN (SELECT NRO_ASIENTO FROM CB_SIM_ASIENTOS_DET
                               WHERE CB_SIM_ASIENTOS_DET.COD_OFICINA = CB_SIM_ASIENTOS.COD_OFICINA
                                 AND CB_SIM_ASIENTOS_DET.NRO_ASIENTO = CB_SIM_ASIENTOS_DET.NRO_ASIENTO
                                 AND CB_SIM_ASIENTOS_DET.COD_RUBRO = WCDCUENT
                                 AND CB_SIM_ASIENTOS_DET.TIP_MOVIMIENTO = WTPMOVIM)
        AND CB_SIM_ASIENTOS.ACTUALIZADO = 'N'
        AND CB_SIM_ASIENTOS.CONFIRMADO = 'S';

  BEGIN  
     for i in c_asientos loop
        UPDATE CB_SIM_ASIENTOS
           SET CB_SIM_ASIENTOS.ACTUALIZADO = 'S'
         WHERE CB_SIM_ASIENTOS.FECHA = i.fecha
           and CB_SIM_ASIENTOS.COD_OFICINA = i.cod_oficina
           and CB_SIM_ASIENTOS.Nro_Asiento = i.nro_asiento;

        UPDATE CB_SIM_ASIENTOS_DET
           SET CB_SIM_ASIENTOS_DET.ACTUALIZADO = 'S'
         WHERE CB_SIM_ASIENTOS_DET.FECHA = i.fecha
           and CB_SIM_ASIENTOS_DET.COD_OFICINA = i.cod_oficina
           and CB_SIM_ASIENTOS_DET.Nro_Asiento = i.nro_asiento
           AND CB_SIM_ASIENTOS_DET.ACTUALIZADO = 'N';
     end loop;
  END;
  --
  PROCEDURE lp_act_sal_oficinas(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              WTPMOVIM IN CHAR,
                              WIMMOVGS IN NUMBER,
                              WIMMONEX IN NUMBER,
                              WIMMOUSD IN NUMBER,
                              WCDMONED IN VARCHAR2) IS
  WDUMMY   CHAR(1);
  BEGIN
  SELECT 'X' INTO WDUMMY
    FROM CB_SIM_SAL_OFICINAS
   WHERE COD_OFICINA = WCDOFICI
     AND COD_RUBRO = WCDCUENT
     AND ANO = v_ano
     AND MES = v_mes
     FOR UPDATE OF COD_RUBRO;
     IF SQL%FOUND THEN
        IF WTPMOVIM = 'D' THEN
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE DEBITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_OFICINAS
              SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_OFICINA = WCDOFICI
              AND COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           --lp_sum_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
        ELSE
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE CREDITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_OFICINAS
              SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_OFICINA = WCDOFICI
              AND COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           --lp_sum_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
        END IF;
     END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     ----------------------------------------------------------------
     -- NO ENCONTRO REGISTRO EN CB_SAL_OFICINAS POR LO TANTO SE DEBE INSERTAR
     -- LA CUENTA PREVIA VERIFICACION EN CB_RUB_OFICINAS
     ----------------------------------------------------------------
     BEGIN
       SELECT 'X'
         INTO WDUMMY
         FROM CB_RUB_OFICINAS
        WHERE COD_OFICINA = WCDOFICI
          AND COD_RUBRO = WCDCUENT;
       IF SQL%FOUND THEN
          lp_ins_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END IF;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
         ------------------------------------------------------------
         -- INSERTA CUENTAS EN EL PLAN DE CUENTAS CONSOLIDADO
         -- CUENTAS ASENTABLES Y CUENTAS PADRES
         ------------------------------------------------------------
         lp_ins_rub_oficinas(WCDOFICI, WCDCUENT);
         lp_ins_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END;
  END;
  --
  PROCEDURE lp_act_sal_consolidados(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              WTPMOVIM IN CHAR,
                              WIMMOVGS IN NUMBER,
                              WIMMONEX IN NUMBER,
                              WIMMOUSD IN NUMBER,
                              WCDMONED IN VARCHAR2) IS
  WDUMMY   CHAR(1);
  BEGIN
  SELECT 'X' INTO WDUMMY
    FROM CB_SIM_SAL_CONSOLIDADOS
   WHERE COD_RUBRO = WCDCUENT
     AND ANO = v_ano
     AND MES = v_mes
     FOR UPDATE OF COD_RUBRO;
     IF SQL%FOUND THEN
        IF WTPMOVIM = 'D' THEN
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE DEBITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_CONSOLIDADOS
              SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
        ELSE
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE CREDITO
           ------------------------------------------------------------
           UPDATE CB_SIM_SAL_CONSOLIDADOS
              SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
        END IF;
     END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     ----------------------------------------------------------------
     -- NO ENCONTRO REGISTRO EN CB_SAL_CONSOLIDADOS POR LO TANTO SE DEBE INSERTAR
     -- LA CUENTA PREVIA VERIFICACION EN CB_RUB_OFICINAS
     ----------------------------------------------------------------
     BEGIN
       SELECT 'X'
         INTO WDUMMY
         FROM CB_RUB_OFICINAS
        WHERE COD_OFICINA = WCDOFICI
          AND COD_RUBRO = WCDCUENT;
       IF SQL%FOUND THEN
          lp_ins_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END IF;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
         ------------------------------------------------------------
         -- INSERTA CUENTAS EN EL PLAN DE CUENTAS CONSOLIDADO
         -- CUENTAS ASENTABLES Y CUENTAS PADRES
         ------------------------------------------------------------
         lp_ins_rub_oficinas(WCDOFICI,WCDCUENT);
         lp_ins_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END;
  END;

-- Inicio del proceso principal de actualizacion de saldos contables
BEGIN
  PAE_CNF.G_COD_MODULO := 2;
  IF SALD_M%ISOPEN THEN
     CLOSE SALD_M;
  END IF;
  OPEN SALD_M;
  LOOP
  FETCH SALD_M INTO CDOFICI, CDCUENT, TPMOVIM, NMOFICI, IMMOVGS, IMMONEX, WCDMONED;
  WW_IMMOUSD := fub_con_mon_a_moneda(WCDMONED,W_MON_FUERTE,IMMONEX); --Obtener la cotización del modulo 2 (Contabilidad).
  EXIT WHEN SALD_M%notfound;
  IF SALD_M%FOUND THEN
     lp_act_sal_oficinas(CDOFICI, CDCUENT, TPMOVIM, IMMOVGS, IMMONEX,WW_IMMOUSD,WCDMONED);
  END IF;
  lp_act_asientos(CDOFICI, CDCUENT, TPMOVIM);
  END LOOP;
END;

PROCEDURE PR_SUM_SAL_OFICINAS(p_fecha in ge_calendarios.fec_actual%type) 
IS

-- Variables.
v_cod_mon_fuerte        varchar2(4) := pag_gen.FU_OBT_MON_FUERTE;
v_fec_actual            date        := p_fecha;
v_ano                   number(4)   := to_char(v_fec_actual,'yyyy');
v_mes                   number(2)   := to_char(v_fec_actual,'mm');
v_sal_mon_rub_ant       number;
v_deb_mon_rubro         number;
v_cre_mon_rubro         number;
v_sal_ini_mes_mon_rubro number;

-- Cursores.
cursor cta is
 select a.cod_oficina, b.cod_rub_padre, b.cod_moneda,
        sum(nvl(sal_mon_loc_ant,0)) sal_mon_loc_ant,
        sum(nvl(deb_mon_local,0)) deb_mon_local,
        sum(nvl(cre_mon_local,0)) cre_mon_local,
        sum(nvl(sal_mon_rub_ant,0)) sal_mon_rub_ant,
        sum(nvl(deb_mon_rubro,0)) deb_mon_rubro,
        sum(nvl(cre_mon_rubro,0)) cre_mon_rubro,
        sum(nvl(sal_equ_loc_ant,0)) sal_equ_loc_ant,
        sum(nvl(deb_equ_local,0)) deb_equ_local,
        sum(nvl(cre_equ_local,0)) cre_equ_local,
        sum(nvl(sal_ini_mes_mon_local,0)) sal_ini_mes_mon_local,
        sum(nvl(sal_ini_mes_mon_rubro,0)) sal_ini_mes_mon_rubro,
        sum(nvl(sal_ini_mes_mon_fuerte,0)) sal_ini_mes_mon_fuerte,
        sum(nvl(sal_ini_mes_equ_local,0)) sal_ini_mes_equ_local
   from  cb_sim_sal_oficinas a,cb_rubros b
  where a.cod_rubro = b.cod_rubro
    and b.imputable = 'S'
   group by a.cod_oficina, b.cod_rub_padre, b.cod_moneda;

-- Procedimientos Internos.
PROCEDURE lp_sum_sal_oficinas(wcdofici in number,
                              wcdcuent in char,
                              p_sal_mon_loc_ant in number,
                              p_deb_mon_local in number,
                              p_cre_mon_local  in number,
                              p_sal_mon_rub_ant in number,
                              p_deb_mon_rubro in number,
                              p_cre_mon_rubro in number,
                              p_sal_equ_loc_ant in number,
                              p_deb_equ_local in number,
                              p_cre_equ_local in number,
                              p_sal_ini_mes_mon_local in number,
                              p_sal_ini_mes_mon_rubro in number,
                              p_sal_ini_mes_mon_fuerte in number,
                              p_sal_ini_mes_equ_local in number) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN CB_SAL_OFICINAS
                  ---------------------------------------------------------
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SIM_SAL_OFICINAS
                   WHERE COD_OFICINA = WCDOFICI
                     AND COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO CB_SIM_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, PROTEGIDO)
                                        VALUES (WCDOFICI, CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - Ofic '||wcdofici||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                    ----------------------------------------
                      UPDATE CB_SIM_SAL_OFICINAS
                        SET sal_mon_loc_ant = nvl(sal_mon_loc_ant,0) + nvl(p_sal_mon_loc_ant,0),
                            deb_mon_local = nvl(deb_mon_local,0) + nvl(p_deb_mon_local,0),
                            cre_mon_local =  nvl(cre_mon_local,0) + nvl(p_cre_mon_local,0),
                            sal_mon_rub_ant = nvl(sal_mon_rub_ant,0) + nvl(p_sal_mon_rub_ant,0),
                            deb_mon_rubro = nvl(deb_mon_rubro,0) + nvl(p_deb_mon_rubro,0),
                            cre_mon_rubro = nvl(cre_mon_rubro,0) + nvl(p_cre_mon_rubro,0),
                            sal_equ_loc_ant = nvl(sal_equ_loc_ant,0) + nvl(p_sal_equ_loc_ant,0),
                            deb_equ_local = nvl(deb_equ_local,0) + nvl(p_deb_equ_local,0),
                            cre_equ_local = nvl(cre_equ_local,0) + nvl(p_cre_equ_local,0),
                            sal_ini_mes_mon_local = nvl(sal_ini_mes_mon_local,0) + nvl(p_sal_ini_mes_mon_local,0),
                            sal_ini_mes_mon_rubro = nvl(sal_ini_mes_mon_rubro,0) + nvl(p_sal_ini_mes_mon_rubro,0),
                            sal_ini_mes_mon_fuerte = nvl(sal_ini_mes_mon_fuerte,0) + nvl(p_sal_ini_mes_mon_fuerte,0),
                            sal_ini_mes_equ_local = nvl(sal_ini_mes_equ_local,0) + nvl(p_sal_ini_mes_equ_local,0)
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuenta');
  END;
-- Proceso Principal.
begin
    -- cero todas las cuentas no imputables
    update CB_SIM_SAL_OFICINAS a
       set sal_mon_loc_ant = 0,
             deb_mon_local = 0,
             cre_mon_local = 0,
             sal_mon_rub_ant = 0,
             deb_mon_rubro = 0,
             cre_mon_rubro = 0,
             sal_equ_loc_ant = 0,
             deb_equ_local = 0,
             cre_equ_local = 0,
             sal_ini_mes_mon_local = 0,
             sal_ini_mes_mon_rubro = 0,
             sal_ini_mes_mon_fuerte = 0,
             sal_ini_mes_equ_local = 0
      where exists (select 0 from cb_rubros b
                     where b.cod_rubro = a.cod_rubro
                       and b.imputable = 'N');
   -- sumarizo las cuentas
   for r in cta loop
      v_sal_mon_rub_ant       := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.sal_mon_rub_ant,null,v_fec_actual);
      v_deb_mon_rubro         := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.deb_mon_rubro,null,v_fec_actual);
      v_cre_mon_rubro         := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.cre_mon_rubro,null,v_fec_actual);
      v_sal_ini_mes_mon_rubro := fub_con_mon_a_moneda(r.cod_moneda,v_cod_mon_fuerte,r.sal_ini_mes_mon_rubro,null,v_fec_actual);

      update CB_SIM_SAL_OFICINAS
         set sal_mon_loc_ant = sal_mon_loc_ant + r.sal_mon_loc_ant,
             deb_mon_local = deb_mon_local + r.deb_mon_local,
             cre_mon_local = cre_mon_local + r.cre_mon_local,
             sal_mon_rub_ant = sal_mon_rub_ant + v_sal_mon_rub_ant,
             deb_mon_rubro = deb_mon_rubro + v_deb_mon_rubro,
             cre_mon_rubro = cre_mon_rubro + v_cre_mon_rubro,
             sal_equ_loc_ant = sal_equ_loc_ant + r.sal_equ_loc_ant,
             deb_equ_local = deb_equ_local + r.deb_equ_local,
             cre_equ_local = cre_equ_local + r.cre_equ_local,
             sal_ini_mes_mon_local = sal_ini_mes_mon_local + r.sal_ini_mes_mon_local,
             sal_ini_mes_mon_rubro = sal_ini_mes_mon_rubro + v_sal_ini_mes_mon_rubro,
             sal_ini_mes_mon_fuerte = sal_ini_mes_mon_fuerte + r.sal_ini_mes_mon_fuerte,
             sal_ini_mes_equ_local =  sal_ini_mes_equ_local + r.sal_ini_mes_equ_local
       where cod_rubro = r.cod_rub_padre
         and cod_oficina = r.cod_oficina;

      --Si no existe, crear la cuenta padre en cb_sal_oficinas.
      if sql%notfound then
         insert into CB_SIM_SAL_OFICINAS
         (cod_oficina, cod_rubro, ano, mes, protegido,
          sal_mon_loc_ant, deb_mon_local, cre_mon_local, sal_mon_rub_ant,
          deb_mon_rubro, cre_mon_rubro, sal_equ_loc_ant, deb_equ_local,
          cre_equ_local, sal_ini_mes_mon_local, sal_ini_mes_mon_rubro,
          sal_ini_mes_mon_fuerte, sal_ini_mes_equ_local)
         values
         (r.cod_oficina, r.cod_rub_padre, v_ano, v_mes, 'S',
          r.sal_mon_loc_ant, r.deb_mon_local, r.cre_mon_local, v_sal_mon_rub_ant,
          v_deb_mon_rubro, v_cre_mon_rubro, r.sal_equ_loc_ant, r.deb_equ_local,
          r.cre_equ_local, r.sal_ini_mes_mon_local, v_sal_ini_mes_mon_rubro,
          r.sal_ini_mes_mon_fuerte, r.sal_ini_mes_equ_local);
      end if;

      -- Actualizo los demas rubros padres.
      lp_sum_sal_oficinas(r.cod_oficina,
                          r.cod_rub_padre,
                          r.sal_mon_loc_ant ,
                          r.deb_mon_local,
                          r.cre_mon_local,
                          v_sal_mon_rub_ant,
                          v_deb_mon_rubro,
                          v_cre_mon_rubro,
                          r.sal_equ_loc_ant,
                          r.deb_equ_local,
                          r.cre_equ_local,
                          r.sal_ini_mes_mon_local,
                          v_sal_ini_mes_mon_rubro,
                          r.sal_ini_mes_mon_fuerte,
                          r.sal_ini_mes_equ_local);
  END LOOP;
END;

/* Actualiza el Balance Consolidado. */
PROCEDURE PR_SUM_SAL_CONSOLIDADOS(p_fecha in ge_calendarios.fec_actual%type)
IS
-- Variables.
v_fec_actual    date := p_fecha;
v_ano           number(4);
v_mes           number(2);
v_cod_rubro     varchar2(15);

-- Cursores.
CURSOR UTI is
  SELECT SUBSTR(COD_RUBRO,1,5)||'XXX'||SUBSTR(COD_RUBRO,9) COD_RUBRO, ANO, MES,
         SUM(NVL(SAL_MON_LOC_ANT,0)) SAL_MON_LOC_ANT,
         SUM(NVL(DEB_MON_LOCAL,0)) DEB_MON_LOCAL,
         SUM(NVL(CRE_MON_LOCAL,0)) CRE_MON_LOCAL,
         SUM(NVL(SAL_INI_MES_MON_LOCAL,0)) SAL_INI_MES_MON_LOCAL,
         SUM(NVL(SAL_MON_RUB_ANT,0)) SAL_MON_RUB_ANT,
         SUM(NVL(DEB_MON_RUBRO,0)) DEB_MON_RUBRO,
         SUM(NVL(CRE_MON_RUBRO,0)) CRE_MON_RUBRO,
         SUM(NVL(SAL_INI_MES_MON_RUBRO,0)) SAL_INI_MES_MON_RUBRO,
         SUM(NVL(SAL_EQU_LOC_ANT,0)) SAL_EQU_LOC_ANT,
         SUM(NVL(DEB_EQU_LOCAL,0)) DEB_EQU_LOCAL,
         SUM(NVL(CRE_EQU_LOCAL,0)) CRE_EQU_LOCAL,
         SUM(NVL(SAL_INI_MES_EQU_LOCAL,0)) SAL_INI_MES_EQU_LOCAL
    FROM CB_SIM_SAL_OFICINAS
   WHERE CB_SIM_SAL_OFICINAS.ANO = v_ano
     AND CB_SIM_SAL_OFICINAS.MES = v_mes
     AND SUBSTR(COD_RUBRO,1,8) IN ('31060418','31060422')
   GROUP BY SUBSTR(COD_RUBRO,1,5)||'XXX'||SUBSTR(COD_RUBRO,9), ANO, MES;

BEGIN
  -- Variables de fecha.
  v_ano := to_char(v_fec_actual,'yyyy');
  v_mes := to_char(v_fec_actual,'mm');
  /* borro los registros anteriores */
  DELETE CB_SIM_SAL_CONSOLIDADOS
   WHERE CB_SIM_SAL_CONSOLIDADOS.ANO = v_ano
     AND CB_SIM_SAL_CONSOLIDADOS.MES = v_mes;
  /* copios los saldos por oficina */
  INSERT INTO CB_SIM_SAL_CONSOLIDADOS
    (COD_RUBRO, ANO, MES, SAL_MON_LOC_ANT,
     DEB_MON_LOCAL, CRE_MON_LOCAL,
     SAL_INI_MES_MON_LOCAL, SAL_MON_RUB_ANT,
     DEB_MON_RUBRO, CRE_MON_RUBRO, SAL_INI_MES_MON_RUBRO,
     SAL_EQU_LOC_ANT, DEB_EQU_LOCAL, CRE_EQU_LOCAL, SAL_INI_MES_EQU_LOCAL)
  SELECT COD_RUBRO, ANO, MES,
         SUM(NVL(SAL_MON_LOC_ANT,0)),
         SUM(NVL(DEB_MON_LOCAL,0)),
         SUM(NVL(CRE_MON_LOCAL,0)),
         SUM(NVL(SAL_INI_MES_MON_LOCAL,0)),
         SUM(NVL(SAL_MON_RUB_ANT,0)),
         SUM(NVL(DEB_MON_RUBRO,0)),
         SUM(NVL(CRE_MON_RUBRO,0)),
         SUM(NVL(SAL_INI_MES_MON_RUBRO,0)),
         SUM(NVL(SAL_EQU_LOC_ANT,0)),
         SUM(NVL(DEB_EQU_LOCAL,0)),
         SUM(NVL(CRE_EQU_LOCAL,0)),
         SUM(NVL(SAL_INI_MES_EQU_LOCAL,0))
    FROM CB_SIM_SAL_OFICINAS
   WHERE CB_SIM_SAL_OFICINAS.ANO = v_ano
     AND CB_SIM_SAL_OFICINAS.MES = v_mes
     AND SUBSTR(COD_RUBRO,1,8) NOT IN ('31060418','31060422')
   GROUP BY COD_RUBRO, ANO, MES;
  /* utilidad */
  FOR I IN UTI LOOP
     IF i.sal_mon_loc_ant + i.deb_mon_local - i.cre_mon_local > 0 then
         -- PERDIDA
         V_COD_RUBRO := REPLACE(i.cod_rubro,'XXX','422');
     ELSE
         -- GANANCIA
         V_COD_RUBRO := REPLACE(i.cod_rubro,'XXX','418');
     END IF;
     INSERT INTO CB_SIM_SAL_CONSOLIDADOS
      (COD_RUBRO, ANO, MES, SAL_MON_LOC_ANT,
       DEB_MON_LOCAL, CRE_MON_LOCAL,
       SAL_INI_MES_MON_LOCAL, SAL_MON_RUB_ANT,
       DEB_MON_RUBRO, CRE_MON_RUBRO, SAL_INI_MES_MON_RUBRO,
       SAL_EQU_LOC_ANT, DEB_EQU_LOCAL, CRE_EQU_LOCAL, SAL_INI_MES_EQU_LOCAL)
    VALUES
     ( V_COD_RUBRO, V_ANO, V_MES,
       I.SAL_MON_LOC_ANT,
       I.DEB_MON_LOCAL,
       I.CRE_MON_LOCAL,
       I.SAL_INI_MES_MON_LOCAL,
       I.SAL_MON_RUB_ANT,
       I.DEB_MON_RUBRO,
       I.CRE_MON_RUBRO,
       I.SAL_INI_MES_MON_RUBRO,
       I.SAL_EQU_LOC_ANT,
       I.DEB_EQU_LOCAL,
       I.CRE_EQU_LOCAL,
       I.SAL_INI_MES_EQU_LOCAL);
  END LOOP;
END;

/* Realiza la valuación del Balance. */
PROCEDURE PR_AJU_DIF_CAMBIOS(p_fecha in ge_calendarios.fec_actual%type) is
  /* proceso diario de ajuste por diferencia de cambios */
  v_fec_actual       date          := p_fecha;
  v_ano              number(4)     := to_char(v_fec_actual,'yyyy');
  v_mes              number(2)     := to_char(v_fec_actual,'mm');
  v_cod_mon_local    varchar2(4)   := pag_gen.FU_OBT_MON_LOCAL;
  --
  v_cod_oficina      ba_oficinas.cod_oficina%type;
  v_cod_rubro        cb_rubros.cod_rubro%type;
  v_aju_oficina      VARCHAR2(01);
  v_sal_mon_local    NUMBER(16,2);
  v_sal_mon_rubro    NUMBER(16,2);
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
  
  -- Cursores.
  CURSOR OFICINA IS
     SELECT COD_OFICINA,DESCRIPCION
       FROM BA_OFICINAS
      ORDER BY COD_OFICINA;
  ----
  CURSOR CURX is
      SELECT cb_rubros.COD_RUBRO, COD_OFICINA, /*AJUSTABLE*/ 'S',
             NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0),
             NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0),
             TIPO, COD_MONEDA
        FROM CB_SIM_SAL_OFICINAS, CB_RUBROS
       WHERE ANO = v_ano
         AND MES = v_mes
         AND CB_SIM_SAL_OFICINAS.COD_RUBRO = CB_RUBROS.COD_RUBRO
         AND IMPUTABLE = 'S'
         AND (TIPO IN (1,2,3,4,5,9))
         and substr(CB_RUBROS.cod_rubro,1,2) not in ('42','52')
         AND COD_MONEDA != v_cod_mon_local
      ORDER BY COD_MONEDA,cb_rubros.COD_RUBRO,COD_OFICINA;
  --
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
       AND (COD_SUBCUENTA = v_sub_cuenta  or cod_subcuenta = v_tip_sub_cta or COD_SUBCUENTA = 'T' ) -- Modificado por ICL 18/08/2011. Tomar el registro más detallado y posteriormente el global.
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

-- Proceso Principal.
BEGIN
--- Inicializo las variables a ser utilizadas en el proceso -------
v_tot_acumulado     := 0;
v_nro_linea   := 0;
v_tot_control  := 0;
WT_MONEDA := 'WQX';
v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 2, 21 ,v_cod_mon_local);
--- Busco el Primer Numero de asiento disponible ------------------
asiento := fug_obt_pardinamico('SIG_NRO_REF_BALANCE');
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
  v_lugar := 'Antes del Fetch ';
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
          UPDATE CB_SIM_ASIENTOS_DET
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
       INSERT INTO CB_SIM_ASIENTOS_DET
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
       INSERT INTO CB_SIM_ASIENTOS_DET
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
     INSERT INTO CB_SIM_ASIENTOS_DET
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
     INSERT INTO CB_SIM_ASIENTOS_DET
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
          UPDATE CB_SIM_ASIENTOS_DET
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
       INSERT INTO CB_SIM_ASIENTOS_DET
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
       INSERT INTO CB_SIM_ASIENTOS_DET
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
     UPDATE CB_SIM_ASIENTOS_DET
        SET NRO_ASIENTO = v_nro_asiento,
            NRO_LINEA = ROWNUM
      WHERE FECHA = v_fec_actual
        AND COD_OFICINA = OFI.COD_OFICINA
        AND NRO_ASIENTO = ASIENTO;
     IF SQL%FOUND THEN
        --- Sumo para el Totald e control de la cabecera --------
        SELECT SUM(MTO_MON_LOCAL) INTO v_tot_control
          FROM CB_SIM_ASIENTOS_DET
         WHERE FECHA = v_fec_actual
           AND COD_OFICINA = OFI.COD_OFICINA
           AND NRO_ASIENTO = v_nro_asiento;
        ---------------------- CABECERA -------------------------
        INSERT INTO CB_SIM_ASIENTOS
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
   prg_act_par_dinamico('SIG_NRO_REF_BALANCE',null, null, null, null, v_nro_asiento);   
EXCEPTION
   WHEN VALUE_ERROR THEN
     CLOSE CURX;
     raise_application_error(-20000,' ERROR. En valores del Procedure PROCESO_DE_AJUSTE '||'-'||v_lugar);
   WHEN OTHERS THEN
     CLOSE CURX;
     raise_application_error(-20000,'ERROR. en. Rubro:'||v_cod_rubro||'-'||v_lugar||'-'||SQLERRM);
END;

/* Calcula la Utilidad del Balance. */
PROCEDURE PR_CAL_UTILIDAD(p_fecha in ge_calendarios.fec_actual%type) 
IS

-- Variables.
v_fec_actual  date := p_fecha;
ww_sal7       number;
ww_sal6       number;
ww_debi       number;
ww_cred       number;
ww_dife       number;
ww_deb_hoy    number;
ww_cre_hoy    number;
ww_sal_act    number;
v_mes         number := to_char(v_fec_actual,'MM');
v_ano         number := to_char(v_fec_actual,'YYYY');

-- Cursores.
cursor  ofi is
   select distinct cod_oficina
     from cb_sim_sal_oficinas;
     
-- Proceso Principal.     
begin
  -- Proceso.
  for o in ofi loop
    ww_sal7 := 0;
    ww_sal6 := 0;
    ww_debi := 0;
    ww_cred := 0;
    -- cargo los rubros de utilidad por si no existan
    insert into cb_sim_sal_oficinas
               (cod_oficina, cod_rubro, ano, mes)
        select o.cod_oficina, b.cod_rubro, v_ano, v_mes
          from cb_rubros b
         where cod_rubro in ('310604180000000','310604180100000','310604180100199',
                             '310604220000000','310604220100000','310604220100199',
                             '310600000000000','310000000000000','300000000000000')
           and not exists (select 0 from cb_sim_sal_oficinas a
                            where a.cod_rubro = b.cod_rubro
                              and a.mes = v_mes
                              and a.ano = v_ano
                              and a.cod_oficina = o.cod_oficina);
    -- saldo de la cuenta GANANCIAS
    begin
    select sum(nvl(sal_mon_loc_ant,0))
      into ww_sal6
      from cb_sim_sal_oficinas
     where cod_rubro = '600000000000000'
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
    -- saldo de la cuenta PERDIDAS
    select sum(nvl(sal_mon_loc_ant,0))
      into ww_sal7
      from cb_sim_sal_oficinas
     where cod_rubro = '700000000000000'
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
    exception
       when others then
        raise_application_error(-20000,'Error al buscar la Ganancia o Perdida de la Oficina '||o.cod_oficina|| ' Mes '||v_mes||'/'||v_ano);
    end;
    -- movimiento debito de hoy de la cuenta 6000000000 y 7000000000
    select sum(nvl(DEB_MON_LOCAL,0))
      into ww_debi
      from cb_sim_sal_oficinas, cb_rubros
     where cb_rubros.cod_rubro = cb_sim_sal_oficinas.cod_rubro
       and imputable = 'S'
       and cod_oficina = o.cod_oficina
       and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
    -- movimiento credito de hoy de la cuenta 6000000000 y 7000000000
    select sum(nvl(CRE_MON_LOCAL,0))
      into ww_cred
      from cb_sim_sal_oficinas, cb_rubros
     where cb_rubros.cod_rubro = cb_sim_sal_oficinas.cod_rubro
       and imputable = 'S'
       and cod_oficina = o.cod_oficina
       and substr(cb_rubros.cod_rubro,1,1) in ('6','7');
    -- halla la diferencia entre ambos movimientos debitos y creditos
    ww_dife :=  abs(nvl(ww_debi,0)-nvl(ww_cred,0));
    -- calculo el saldo actual
    ww_sal_act := nvl(ww_sal6,0) + nvl(ww_sal7,0)+nvl(ww_debi,0)-nvl(ww_cred,0);
    -- calculo el debito y credito de hoy
    if nvl(ww_debi,0) > nvl(ww_cred,0) then
       ww_deb_hoy := nvl(ww_dife,0);
       ww_cre_hoy := 0;
    else
       ww_cre_hoy := nvl(ww_dife,0);
       ww_deb_hoy :=0;
    end if;
    -- si es ganancia
    if ww_sal_act < 0 then
    -- Modificado por Ingrid Larráin : 29/07/2011, porque el BBVA expone siempre GANANCIA.
        -- actualiza con la diferencia entre ambos saldos
        update cb_sim_sal_oficinas
           set deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in ('310604180000000','310604180100000','310604180100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
        -- cero los datos de las perdidas
        update cb_sim_sal_oficinas
           set deb_mon_local   = 0,
               cre_mon_local   = 0
         where cod_rubro in ('310604220000000','310604220100000','310604220100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    else
        -- perdida
        -- actualiza con la diferencia entre ambos saldos
        update cb_sim_sal_oficinas
           set deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro in ('310604180000000','310604180100000','310604180100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
        -- actualiza en cero las ganancias
        update cb_sim_sal_oficinas
           set deb_mon_local   = 0,
               cre_mon_local   = 0
         where cod_rubro in ('310604220000000','310604220100000','310604220100199')
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    end if;
    -- actualizo el padre comun
    update cb_sim_sal_oficinas
           set deb_mon_local   = ww_deb_hoy,
               cre_mon_local   = ww_cre_hoy
         where cod_rubro = '310600000000000'
           and mes = v_mes and ano = v_ano
           and cod_oficina = o.cod_oficina;
    ----------------------------------------
    -- sumarizacion de patrimonio
    ----------------------------------------
    update cb_sim_sal_oficinas
       set deb_mon_local = nvl(deb_mon_local,0) + nvl(ww_deb_hoy,0),
           cre_mon_local = nvl(cre_mon_local,0) + nvl(ww_cre_hoy,0)
     where cod_rubro in ('300000000000000','310000000000000')
       and mes = v_mes and ano = v_ano
       and cod_oficina = o.cod_oficina;
  end loop;
END;

/* Genera el Balance por Sucursal. */
PROCEDURE PR_CON_BALANCE(p_fecha in ge_calendarios.fec_actual%type) IS

-- Variables.
v_fec_actual ge_calendarios.fec_actual%type := p_fecha;

BEGIN
     
   -- Obtengo los datos de la tabla cb_sal_oficinas_dia.
   BEGIN
      -- El balance por oficinas.
      INSERT INTO cb_sim_sal_oficinas
           SELECT cod_oficina, 
                  cod_rubro, 
                  to_char(fecha,'yyyy'),
                  to_char(fecha,'mm'),
                  sal_mon_loc_ant, 
                  deb_mon_local, 
                  cre_mon_local, 
                  sal_ini_mes_mon_local, 
                  sal_mon_rub_ant, 
                  deb_mon_rubro, 
                  cre_mon_rubro, 
                  sal_ini_mes_mon_rubro, 
                  sal_ini_mes_mon_fuerte, 
                  protegido,                   
                  sal_equ_loc_ant, 
                  deb_equ_local, 
                  cre_equ_local, 
                  sal_ini_mes_equ_local,
                  usu_insercion, 
                  fec_insercion, 
                  usu_modificacion, 
                  fec_modificacion
             FROM cb_sal_oficinas_dia m
            WHERE m.fecha = v_fec_actual;

      -- El balance consolidado.  
      INSERT INTO cb_sim_sal_consolidados
           SELECT cod_rubro, 
                  to_char(fecha,'yyyy'),
                  to_char(fecha,'mm'),
                  sal_mon_loc_ant, 
                  deb_mon_local, 
                  cre_mon_local, 
                  sal_ini_mes_mon_local, 
                  sal_mon_rub_ant, 
                  deb_mon_rubro, 
                  cre_mon_rubro, 
                  sal_ini_mes_mon_rubro, 
                  protegido,                    
                  sal_equ_loc_ant, 
                  deb_equ_local, 
                  cre_equ_local, 
                  sal_ini_mes_equ_local,
                  usu_insercion, 
                  fec_insercion, 
                  usu_modificacion, 
                  fec_modificacion
             FROM cb_sal_consolidados_dia m
            WHERE m.fecha = v_fec_actual;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error en PR_CON_BALANCE - Inserta Datos: ' ||' - '|| sqlerrm);
   END;
   
   -- Ejecuto la generación del Balance.
   BEGIN      
      PR_ASI_FUTUROS(v_fec_actual);
      PR_VAL_ASIENTOS(v_fec_actual);
      PR_ACT_SALDOS(v_fec_actual);
      PR_SUM_SAL_OFICINAS(v_fec_actual);
      PR_SUM_SAL_CONSOLIDADOS(v_fec_actual);
      PR_AJU_DIF_CAMBIOS(v_fec_actual);
      PR_SUM_SAL_OFICINAS(v_fec_actual);
      PR_SUM_SAL_CONSOLIDADOS(v_fec_actual);
      PR_CAL_UTILIDAD(v_fec_actual);
      PR_SUM_SAL_OFICINAS(v_fec_actual);
      PR_SUM_SAL_CONSOLIDADOS(v_fec_actual);
      PAG_EVO.PR_BAL_SIM_ABI_SUC(v_fec_actual);
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001, 'Error en PR_CON_BALANCE - Genera Balance: ' ||' - '|| sqlerrm);
   END;
END;

/* Proceso que genera el Balance Proyectado. */
PROCEDURE PR_GEN_BALANCE IS

-- Variables.
v_fec_actual  ge_calendarios.fec_actual%type;
v_msj         varchar2(250);
v_gen_balance ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CBN_GEN_BAL_PROYECTADO');

BEGIN
   -- Obtiene los datos del último cierre del Balance.
   BEGIN
      SELECT max(a.fecha)
        INTO v_fec_actual
        FROM cb_sal_consolidados_dia a;       
   EXCEPTION 
      WHEN OTHERS THEN 
         v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(2);
   END;

   -- Verifico si se ejecuta el proceso.
   IF NVL(v_gen_balance,'N') = 'S' THEN            
      -- Actualizo las tablas y parametros.
      -- Actualizo el nro. de referencia de los asientos.
      prg_act_par_dinamico('SIG_NRO_REF_BALANCE', NULL, NULL, NULL, NULL, 1);   
      -- Elimino los registro de las tablas.
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_dev_futuras', v_msj);
      if v_msj is not null then
         raise_application_error(-20001, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_dev_ahorros DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20002, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_dev_prestamos DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20001, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_dev_mesa DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20002, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_movimientos DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20001, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_mov_diferidos DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20002, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_con_transacciones DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20001, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_sal_oficinas DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20002, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_sal_consolidados DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20001, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_asientos_det DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20002, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_asientos DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20001, v_msj);
      end if;
      v_msj := null;
      sql_util.ejecute_dml('TRUNCATE TABLE cb_sim_validaciones DROP STORAGE', v_msj);
      if v_msj is not null then
         raise_application_error(-20001, v_msj);
      end if;
     
      -- Ejecuto los procesos de devengamientos y cargos.
      BEGIN
         PR_DEV_OPE_FUTURAS(v_fec_actual);
         PR_DEV_AHORROS(v_fec_actual);
         PR_DEV_CERTIFICADOS(v_fec_actual);
         PR_PRO_DEV_PRESTAMOS(v_fec_actual);
         PR_PRO_DEV_MESA(v_fec_actual);
         PR_DEB_SAL_MIN_AHORRO(v_fec_actual);
         PR_DEB_SAL_MIN_CTACTE(v_fec_actual);
         PR_LIQ_CAR_SOBREGIROS(v_fec_actual);
         PR_GEN_COM_RET_EXTRACTO(v_fec_actual);
         PR_GEN_COM_CLI_VIP(v_fec_actual);
         PR_GEN_COM_CLI_360(v_fec_actual);
         PR_GEN_COM_BAN_PERSONAL(v_fec_actual);
         PR_CAL_DEV_COMISIONES(v_fec_actual);
         PR_CON_TRANSACCION(v_fec_actual);
         PR_GEN_ASIENTOS(v_fec_actual);
      EXCEPTION
         WHEN OTHERS THEN 
            raise_application_error(-20001, 'Error en PR_GEN_BALANCE' ||' - '|| sqlerrm);
      END;
      
      -- Ejecuto la generación del Balance.
      BEGIN
         PR_CON_BALANCE(v_fec_actual);               
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20001, 'Error en PR_GEN_BALANCE' ||' - '|| sqlerrm);
      END;
      
      -- Actualizo el parametro de ejecución.
      prg_act_par_dinamico('CBN_GEN_BAL_PROYECTADO', NULL, NULL, NULL, NULL, 'N');
   END IF;   
END;

END PAB_SIM;
/

