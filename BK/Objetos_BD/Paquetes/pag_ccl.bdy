CREATE OR REPLACE PACKAGE BODY IT.PAG_CCL IS

-- Debe ser una variable general para que cuando procese un cliente siga bien la secuencia...
v_nro_secuencia     ge_movimientos.nro_secuencia%type := 0;

/* Genera transacci�n de la cuenta. */
PROCEDURE PR_GEN_TRA_CTA
 (P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_OFICINA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_SEC_CON_ANT IN GE_TIP_DEUDORES.COD_SEC_CONTABLE%TYPE
 ,P_IND_RES_ANT IN GE_TIP_DEUDORES.IND_RESIDENTE%TYPE
 ,P_COD_TIP_DEU_ANT IN GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE
 ,P_COD_SEC_CON_ACT IN GE_TIP_DEUDORES.COD_SEC_CONTABLE%TYPE
 ,P_IND_RES_ACT IN GE_TIP_DEUDORES.IND_RESIDENTE%TYPE
 ,P_COD_TIP_DEU_ACT IN GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE
 )
 IS

/* Obtener datos de la cuenta */
PROCEDURE LP_OBT_DAT_CTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN OUT GE_CUENTAS.COD_MONEDA%TYPE
 ,P_CAPITAL IN OUT GE_CUENTAS.SAL_CONTABLE%TYPE
 ,P_INTERES IN OUT GE_CUENTAS.SAL_CONTABLE%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 ,P_EST_CUENTA IN OUT GE_TIP_ASIENTOS.EST_CUENTA%TYPE
 ,P_TIP_CUENTA IN OUT GE_TIP_ASIENTOS.TIP_CUENTA%TYPE
 ,P_TIP_INTERES IN OUT GE_TIP_ASIENTOS.TIP_INTERES%TYPE
 ,P_TIP_RENOVACION IN OUT GE_TIP_ASIENTOS.TIP_RENOVACION%TYPE
 ,P_CAT_AUTOMATICA IN OUT GE_TIP_ASIENTOS.CAT_AUTOMATICA%TYPE
 ,P_PIGNORADO IN OUT GE_CUENTAS.SAL_CONTABLE%TYPE
 ,P_COD_SEC_CREDITO IN OUT PR_CTA_PRESTAMOS.COD_SEC_CREDITO%TYPE
 );
/* Verificar tipo de amortizaci�n. */
FUNCTION LF_VER_TIP_AMORTIZ
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
/* Obtener tipo de asiento para la transacci�n. */
PROCEDURE LP_OBT_ASI_TRAN
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TIP_ASIENTO IN OUT GE_TRANSACCIONES.COD_TIP_ASIENTO%TYPE
 ,P_COD_PRO_CONTABLE IN OUT GE_MODALIDADES.COD_PRO_CONTABLE%TYPE
 );
/* Obtener asiento asociado. */
PROCEDURE LP_OBT_ASI_ASOCIADO
 (P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TIP_ASIENTO IN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE
 ,P_COD_OFICINA IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_COD_SEC_CONTABLE IN GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE
 ,P_IND_RESIDENTE IN GE_TIP_ASIENTOS.IND_RESIDENTE%TYPE
 ,P_COD_TIP_DEUDOR IN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE
 ,P_COD_PLAZO IN GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 ,P_EST_CUENTA IN GE_TIP_ASIENTOS.EST_CUENTA%TYPE
 ,P_TIP_CUENTA IN GE_TIP_ASIENTOS.TIP_CUENTA%TYPE
 ,P_TIP_INTERES IN GE_TIP_ASIENTOS.TIP_INTERES%TYPE
 ,P_TIP_RENOVACION IN GE_TIP_ASIENTOS.TIP_RENOVACION%TYPE

 ,P_CAT_AUTOMATICA IN GE_TIP_ASIENTOS.CAT_AUTOMATICA%TYPE
 ,P_IMPORTE IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_SEC_RUBRO IN GE_CON_TRANSACCIONES.COD_SEC_RUBRO%TYPE default null
 );
   v_cod_moneda        ba_monedas.cod_moneda%type;
   v_capital           ge_cuentas.sal_contable%type;
   v_interes           ge_cuentas.sal_contable%type;
   v_pignorado         ge_cuentas.sal_contable%type;
   v_situacion         ah_cta_vistas.cta_combinada%type;
   v_est_cta_batch     ah_cta_certificados.est_cer_batch%type;
   v_cod_plazo         ge_plz_contables.cod_plazo%type;
   v_cod_tip_asiento   ge_tip_asientos.cod_tip_asiento%type;
   v_tip_amortizacion  pr_solicitudes.tip_amortizacion%type := 'N';
   v_cod_transaccion   ge_transacciones.cod_transaccion%type := 656;
   --- Viene del Pap� PRA_TRA_SAL_CLI -- ojo definir en el trigger
   v_hora              ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
   v_cod_mod_padre     ba_modulos.cod_modulo%type := p_cod_modulo;
   v_cod_mad_padre     ge_modalidades.cod_modalidad%type := p_cod_modalidad;
   v_cod_tra_padre     ge_transacciones.cod_transaccion%type := 357;
   V_EST_CUENTA        GE_TIP_ASIENTOS.EST_CUENTA%TYPE;
   V_TIP_CUENTA        GE_TIP_ASIENTOS.TIP_CUENTA%TYPE;
   V_TIP_INTERES       GE_TIP_ASIENTOS.TIP_INTERES%TYPE;
   V_TIP_RENOVACION    GE_TIP_ASIENTOS.TIP_RENOVACION%TYPE;
   V_CAT_AUTOMATICA    GE_TIP_ASIENTOS.CAT_AUTOMATICA%TYPE;
   v_cod_pro_contable ge_modalidades.cod_pro_contable%type;
   v_cod_sec_credito   pr_cta_prestamos.cod_sec_credito%type;
   v_cod_sec_rubro     pr_sec_creditos.cod_sec_rubro%type;

/* Obtener datos de la cuenta */
PROCEDURE LP_OBT_DAT_CTA
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_MONEDA IN OUT GE_CUENTAS.COD_MONEDA%TYPE
 ,P_CAPITAL IN OUT GE_CUENTAS.SAL_CONTABLE%TYPE
 ,P_INTERES IN OUT GE_CUENTAS.SAL_CONTABLE%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 ,P_EST_CUENTA IN OUT GE_TIP_ASIENTOS.EST_CUENTA%TYPE
 ,P_TIP_CUENTA IN OUT GE_TIP_ASIENTOS.TIP_CUENTA%TYPE
 ,P_TIP_INTERES IN OUT GE_TIP_ASIENTOS.TIP_INTERES%TYPE
 ,P_TIP_RENOVACION IN OUT GE_TIP_ASIENTOS.TIP_RENOVACION%TYPE
 ,P_CAT_AUTOMATICA IN OUT GE_TIP_ASIENTOS.CAT_AUTOMATICA%TYPE
 ,P_PIGNORADO IN OUT GE_CUENTAS.SAL_CONTABLE%TYPE
 ,P_COD_SEC_CREDITO IN OUT PR_CTA_PRESTAMOS.COD_SEC_CREDITO%TYPE
 )
 IS
V_COD_SUB_MODALIDAD GE_SUB_MODALIDADES.COD_SUB_MODALIDAD%TYPE;
/* Obtener maxima fecha de capitalizacion */
FUNCTION LF_OBT_MAX_FEC_CAP
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN DATE;
/* Obtener monto devengado historico. */
FUNCTION LF_OBT_MTO_DEV_HIS
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN AH_DEVENGADOS.FECHA%TYPE
 )
 RETURN NUMBER;
/* Obtener monto pignorado de la cuenta. */
FUNCTION LF_OBT_MTO_PIGNORADO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER;
/* Obtener plazo en base a los dias. */
FUNCTION LF_OBT_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 )
 RETURN NUMBER;
 v_fecha date;
 v_ctdias number(4) := 0;

/* Obtener maxima fecha de capitalizacion */
FUNCTION LF_OBT_MAX_FEC_CAP
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN DATE
 IS
v_fecha ah_capitalizaciones.fecha%type;
BEGIN
   SELECT MAX(FECHA)
     INTO v_FECHA
     FROM AH_CAPITALIZACIONES
    WHERE NRO_CUENTA = p_nro_cuenta;
    return v_fecha;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Obt.Max.Fec.Cap '||sqlerrm);
END;
/* Obtener monto devengado historico. */
FUNCTION LF_OBT_MTO_DEV_HIS
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FECHA IN AH_DEVENGADOS.FECHA%TYPE
 )
 RETURN NUMBER
 IS
v_mto_interes ah_devengados_his.mto_interes%type;
BEGIN
   SELECT SUM(MTO_INTERES)
     INTO v_mto_interes
     FROM AH_DEVENGADOS_HIS
    WHERE NRO_CUENTA = p_nro_cuenta
      AND ANO >= TO_CHAR(p_FECHA,'YYYY')
      AND MES >  TO_CHAR(p_FECHA,'MM');
   return v_mto_interes;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Ah.Deve.His. '||sqlerrm);
END;
/* Obtener monto pignorado de la cuenta. */
FUNCTION LF_OBT_MTO_PIGNORADO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN NUMBER
 IS
v_mto_pignorado ge_bloqueos.monto%type;
BEGIN
   SELECT nvl(SUM(v.monto), 0) monto
     INTO v_mto_pignorado
     FROM (SELECT DISTINCT gb.*
             FROM pr_gar_cash c, pr_garantias ga, ge_bloqueos gb
            WHERE ga.nro_garantia = c.nro_garantia
              AND ga.estado IN ('C', 'V', 'N', 'T')
              AND c.nro_cta_referencia = gb.nro_cuenta
              AND gb.cod_causa = '230'
              AND c.nro_cta_referencia = p_nro_cuenta) v;
   return v_mto_pignorado;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Monto Pignorado. '||sqlerrm);
END;
/* Obtener plazo en base a los dias. */
FUNCTION LF_OBT_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 )
 RETURN NUMBER
 IS
v_cod_plazo ge_plz_contables.cod_plazo%type;
BEGIN
   SELECT COD_PLAZO
     INTO v_cod_plazo
     FROM GE_PLZ_CONTABLES
    WHERE CAN_DIAS = (SELECT MIN(CAN_DIAS)
                        FROM GE_PLZ_CONTABLES
                       WHERE CAN_DIAS >= p_can_dias);
   RETURN v_cod_plazo;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000,'No existe codigo de Plazo p/'||to_char(p_can_dias,'999')||' dias.');
   WHEN TOO_MANY_ROWS THEN
      raise_application_error(-20000,'Existen varios codigos de Plazo p/'||to_char(p_can_dias,'999')||' dias.');
   WHEN OTHERS THEN
      raise_application_error(-20000,'BUSCA_PLAZO '||SQLERRM);
END;

BEGIN
   p_interes := 0;
   p_pignorado := 0;
   --- Busco los datos de la cuentas de ahorros ----------------------
   IF p_cod_modulo = 3 THEN
      --- busco la maxima fecha de capitalizacion de la cuenta --------
      v_fecha := LF_OBT_MAX_FEC_CAP(p_nro_cuenta);
      IF p_cod_modalidad = 31 THEN
         SELECT NVL(SAL_TOT_BATCH,0) - NVL(SAL_RET_BATCH,0),
                COD_MONEDA, 0, cod_sub_modalidad
           INTO p_capital, p_cod_moneda, v_ctdias, v_cod_sub_modalidad
           FROM AH_CTA_VISTAS
          WHERE NRO_CUENTA = p_nro_cuenta;
          begin
            p_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(p_cod_modulo)||trim(p_cod_modalidad)||trim(v_cod_sub_modalidad));
          exception
            when others then
              p_tip_cuenta := null;
          end;
      ELSIF p_cod_modalidad in (32,37,38) THEN
         SELECT SAL_TOT_BATCH, COD_MONEDA, FEC_VENCIMIENTO-FEC_APERTURA
           INTO p_capital, p_cod_moneda, v_ctdias
           FROM AH_CTA_PLAZOS
          WHERE NRO_CUENTA = p_nro_cuenta;
      ELSIF p_cod_modalidad IN (33,34,35,36) THEN
         SELECT SAL_TOT_BATCH, COD_MONEDA, FEC_VENCIMIENTO-FEC_APERTURA
           INTO p_capital, p_cod_moneda, v_ctdias
           FROM AH_CTA_CERTIFICADOS
          WHERE NRO_CUENTA = p_nro_cuenta;
      END IF;
      --- busco el interes de la cuenta -----------------------------
      p_interes := lf_obt_mto_dev_his(p_nro_cuenta,v_fecha);
      --- busco el monto pignorado de la cuenta -----------------------------
      p_pignorado := lf_obt_mto_pignorado(p_nro_cuenta);
   ELSIF p_cod_modulo = 4 THEN
      IF p_cod_modalidad = 41 then
        SELECT NVL(SAL_TOT_BATCH,0) - NVL(SAL_RET_BATCH,0),
               COD_MONEDA, 0
          INTO p_capital, p_cod_moneda, v_ctdias
          FROM cc_cta_corrientes
         WHERE nro_cuenta = p_nro_cuenta;
      else
        SELECT NVL(SAL_TOT_BATCH,0) - NVL(SAL_RET_BATCH,0),
               COD_MONEDA, 0
          INTO p_capital, p_cod_moneda, v_ctdias
          FROM cc_cta_bancarias
         WHERE nro_cuenta = p_nro_cuenta;
      end if;
      --- busco el monto pignorado de la cuenta -----------------------------
      p_pignorado := lf_obt_mto_pignorado(p_nro_cuenta);
   ELSIF p_cod_modulo = 6 THEN
      IF p_cod_modalidad NOT IN (68,69) THEN
         SELECT PRE.SAL_CAP_BATCH,PRE.SAL_INT_BATCH,PRE.COD_MONEDA,
                PRE.FEC_VENCIMIENTO - PRE.FEC_INICIO,
                tipo, tip_interes, nvl(tip_renovacion,'A'),
                estado, cod_sec_credito
           INTO p_capital, p_interes, p_cod_moneda, v_ctdias,
                p_tip_cuenta, p_tip_interes, p_tip_renovacion,
                p_est_cuenta, P_COD_SEC_CREDITO
           FROM PR_CTA_PRESTAMOS PRE
          WHERE PRE.NRO_CUENTA = p_nro_cuenta;
/*      ELSE
         SELECT FI_VLMONTO,0         ,FI_CDMONED,FI_FCVENCI-FI_FCCONCE
           INTO p_capital, p_interes, p_cod_moneda, v_ctdias
           FROM FPFIANZ
          WHERE FI_CDMODUL = WW_CDMODUL
            AND FI_CDMODAL = WW_CDMODAL
            AND FI_NRCUENT = WW_NRCUENT;*/
      END IF;
/* ELSIF p_cod_modulo = 8 THEN
      IF p_cod_modalidad = 81 THEN
         SELECT IM_SLCARBA,0 ,IM_CDMONED,IM_FCVENCI-IM_FCAPROB
           INTO p_capital, p_interes, p_cod_moneda, v_ctdias
           FROM FXIMPOR
          WHERE IM_CDMODUL = WW_CDMODUL AND IM_CDMODAL = WW_CDMODAL
            AND IM_CDOFICI = WW_CDOFICI AND IM_NRIMPOR = WW_NRCUENT;
      ELSIF p_cod_modalidad = 82 THEN
         SELECT EX_SLCARBA,0 ,EX_CDMONED,EX_FCVENCI-EX_FCAPROB
           INTO p_capital, p_interes, p_cod_moneda, v_ctdias
           FROM FXEXPOR
          WHERE EX_CDMODUL = WW_CDMODUL AND EX_CDMODAL = WW_CDMODAL
            AND EX_CDOFICI = WW_CDOFICI AND EX_NREXPOR = WW_NRCUENT;
      END IF;                 */
   END IF;
/*    if p_cod_modulo in (4,5,6) then
       --- Verifico categoria
       begin
          select fup_obt_categoria(c.cat_automatica,c.cat_subjetiva)
            into v_cat_automatica
            from ge_clientes c, ge_cta_clientes cc
           where c.cod_persona = cc.cod_persona
             and cc.relacion = 'P'
             and cc.nro_cuenta = p_nro_cuenta;
       exception
          when no_data_found then
             v_cat_automatica := 1;
       end;
    end if;*/

   --- busco el plazo que le corresponde a la cuenta ---------------
   p_cod_plazo := lf_obt_plazo(v_ctdias);
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000, 'No existe cta Nro.: '||p_nro_cuenta);
   WHEN TOO_MANY_ROWS THEN
      raise_application_error(-20000, 'Existen varios registros p/ la Cta.: '||p_nro_cuenta);
   WHEN VALUE_ERROR THEN
      raise_application_error(-20000, 'BUSCA DATOS CUENTA (value error)');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'OBT.DAT.CTA '||SQLERRM);
END;
/* Verificar tipo de amortizaci�n. */
FUNCTION LF_VER_TIP_AMORTIZ
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2
 IS
v_tip_amortizacion pr_solicitudes.tip_amortizacion%type;
   v_aux number;
BEGIN
   v_tip_amortizacion := 'N';
   SELECT COUNT(*) INTO v_aux
     FROM PR_CUOTAS
    WHERE MTO_CAPITAL > 0
      AND NRO_CUOTA > 0
      AND NRO_CUENTA = p_nro_cuenta;
   IF v_aux > 1 THEN
      v_tip_amortizacion := 'S';
   END IF;
   return v_tip_amortizacion;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000, 'No se encuentra registro de CUOTAS');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Ver.Tip.Capit.'||SQLERRM);
END;
/* Obtener tipo de asiento para la transacci�n. */
PROCEDURE LP_OBT_ASI_TRAN
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TIP_ASIENTO IN OUT GE_TRANSACCIONES.COD_TIP_ASIENTO%TYPE
 ,P_COD_PRO_CONTABLE IN OUT GE_MODALIDADES.COD_PRO_CONTABLE%TYPE
 )
 IS
v_cod_tip_asiento ge_transacciones.cod_tip_asiento%type;
BEGIN
   SELECT G.COD_TIP_ASIENTO, M.COD_PRO_CONTABLE
     INTO p_cod_tip_asiento, p_cod_pro_contable
     FROM GE_MODALIDADES M, GE_TRANSACCIONES G
    WHERE m.cod_modulo = g.cod_modulo
      AND m.cod_modalidad = g.cod_modalidad
      AND g.COD_MODULO = p_cod_modulo
      AND g.COD_MODALIDAD = p_cod_modalidad
      AND g.COD_TRANSACCION = p_cod_transaccion;
   IF v_cod_tip_asiento IS NULL THEN
      v_cod_tip_asiento := NULL;
   END IF;
--   RETURN v_cod_tip_asiento;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_cod_tip_asiento := NULL;
      P_COD_PRO_CONTABLE := NULL;
  --    RETURN v_cod_tip_asiento;
   WHEN OTHERS THEN
      raise_application_error(-20000, 'BUSCA_TRANS: '||SQLERRM);
END;
/* Obtener asiento asociado. */
PROCEDURE LP_OBT_ASI_ASOCIADO
 (P_COD_MODULO IN GE_CUENTAS.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_CUENTAS.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TIP_ASIENTO IN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE
 ,P_COD_OFICINA IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_COD_MONEDA IN GE_CUENTAS.COD_MONEDA%TYPE
 ,P_COD_SEC_CONTABLE IN GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE
 ,P_IND_RESIDENTE IN GE_TIP_ASIENTOS.IND_RESIDENTE%TYPE
 ,P_COD_TIP_DEUDOR IN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE
 ,P_COD_PLAZO IN GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 ,P_EST_CUENTA IN GE_TIP_ASIENTOS.EST_CUENTA%TYPE
 ,P_TIP_CUENTA IN GE_TIP_ASIENTOS.TIP_CUENTA%TYPE
 ,P_TIP_INTERES IN GE_TIP_ASIENTOS.TIP_INTERES%TYPE
 ,P_TIP_RENOVACION IN GE_TIP_ASIENTOS.TIP_RENOVACION%TYPE
 ,P_CAT_AUTOMATICA IN GE_TIP_ASIENTOS.CAT_AUTOMATICA%TYPE
 ,P_IMPORTE IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_SEC_RUBRO IN GE_CON_TRANSACCIONES.COD_SEC_RUBRO%TYPE default null
 )
 IS
CURSOR c_ge_tip_asientos IS
   SELECT IND_PLAZO, IND_DEUDOR, TIP_MOVIMIENTO, COD_RUBRO, IND_PRODUCTO
     FROM GE_TIP_ASIENTOS
    WHERE COD_TIP_ASIENTO = p_cod_tip_asiento
      AND COD_MONEDA = p_cod_moneda
      AND COD_SEC_CONTABLE = p_cod_sec_contable
      AND (IND_RESIDENTE = p_ind_residente OR IND_RESIDENTE = 'X')
      AND (est_cuenta = p_est_cuenta or nvl(est_cuenta,'X') = 'X')
      AND ((nvl(p_tip_cuenta,'x') = 'B' and tip_cuenta = p_tip_cuenta) or
          (nvl(p_tip_cuenta, 'x') <> 'B' and (tip_cuenta = p_tip_cuenta or nvl(tip_cuenta,'X') = 'X')))
      AND (tip_interes = p_tip_interes or nvl(tip_interes,'X') = 'X')
      AND (tip_renovacion = p_tip_renovacion or nvl(tip_renovacion,'X') = 'X')
      AND (cat_automatica = p_cat_automatica or nvl(cat_automatica,-1) = -1);
   v_contador   NUMBER := 0;
   v_cod_rubro  cb_rubros.cod_rubro%type;
   v_cod_pro_contable ge_modalidades.cod_pro_contable%type;
   r_gmovi      ge_movimientos%rowtype;
BEGIN
   FOR FGT IN c_ge_tip_asientos LOOP
      v_contador  := NVL(v_contador,0) + 1;
      v_cod_rubro := FGT.COD_RUBRO;
      IF FGT.IND_DEUDOR = 'S' THEN
         v_cod_rubro := SUBSTR(v_cod_rubro,1,8)||
                        LTRIM(TO_CHAR(p_cod_tip_deudor,'00'))||
                        SUBSTR(v_cod_rubro,11,5);
      END IF;
      IF FGT.IND_PLAZO = 'S' THEN
         v_cod_rubro:= SUBSTR(v_cod_rubro,1,2)||
                       LTRIM(TO_CHAR(p_cod_plazo))||
                       SUBSTR(v_cod_rubro,4,12);
      END IF;
      IF FGT.IND_PRODUCTO = 'S' and substr(v_cod_rubro, 11, 3) <> 'SEC' THEN
         v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                       LTRIM(TO_CHAR(NVL(v_cod_pro_contable,0),'000'))||
                       SUBSTR(v_cod_rubro,14,2);
      END IF;
      -- OMM 09/06/2016 DYDMR-4061
      IF substr(v_cod_rubro, 11, 3) = 'SEC' THEN
               -- es solo para prestamos, para contabilizar por sector
           v_cod_rubro := substr(v_cod_rubro, 1, 10) || ltrim(to_char(p_cod_sec_rubro, '000')) ||
                       SUBSTR(v_cod_rubro,14,2);
      END IF;
      v_nro_secuencia := v_nro_secuencia + 1;
      r_gmovi.cod_modulo      := p_cod_modulo;
      r_gmovi.cod_modalidad   := p_cod_modalidad;
      r_gmovi.cod_transaccion := p_cod_transaccion;
      r_gmovi.cod_moneda      := p_cod_moneda;
      r_gmovi.cod_oficina     := p_cod_oficina;
      r_gmovi.monto           := p_importe;
      r_gmovi.tip_mov_rubro   := fgt.tip_movimiento;
      r_gmovi.cod_rubro       := v_cod_rubro;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := user;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := pag_cal.g_fec_actual;
      r_gmovi.fec_valor       := pag_cal.g_fec_actual;
      r_gmovi.cod_ofi_origen  := p_cod_oficina;
      r_gmovi.estado          := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.cod_mad_padre   := v_cod_mad_padre;
      r_gmovi.cod_mod_padre   := v_cod_mod_padre;
      r_gmovi.cod_tra_padre   := v_cod_tra_padre;
      r_gmovi.concepto        := 'Cambio de Situac.Cliente';
      pag_gen.pr_ins_ge_movimiento(r_gmovi);
   END LOOP;
   IF v_contador = 0 THEN
      raise_application_error(-20000, 'No existe asiento.:'||to_char(p_cod_tip_asiento)||
          ' Res.:'||p_ind_residente||' Sec.'||p_cod_sec_contable||' Modalidad: '||to_char(p_cod_modalidad)||'Transaccion: '||p_cod_transaccion||' ');
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Obt.Asi.Asociado '||to_char(p_cod_tip_asiento)||
                            ' Modalidad: '||to_char(p_cod_modalidad)||'Transaccion: '||p_cod_transaccion||' '||sqlerrm);
END;
BEGIN
   pag_cal.pr_obt_dat_calendar(v_cod_mod_padre);   --- ojo poner en el trigger
   lp_obt_dat_cta(p_nro_cuenta, p_cod_modulo, p_cod_modalidad,
                  --- OUT
                  v_cod_moneda, v_capital, v_interes, v_cod_plazo,
                  v_est_cuenta, v_tip_cuenta, v_tip_interes,
                  v_tip_renovacion, v_cat_automatica, v_pignorado, v_cod_sec_credito);

   IF p_cod_modulo = 6 THEN
      v_tip_amortizacion := lf_ver_tip_amortiz(p_nro_cuenta);
      v_cod_sec_rubro    := FUP_OBT_SEC_RUBRO(v_cod_sec_credito) ;
      IF v_tip_amortizacion = 'S' THEN
         v_cod_transaccion := 658;
      END IF;
   ELSE
      v_cod_sec_rubro := NULL ;
   END IF;
   IF NVL(v_capital,0) <> 0 THEN
      lp_obt_asi_tran(p_cod_modulo,p_cod_modalidad,v_cod_transaccion, v_cod_tip_asiento, v_cod_pro_contable);
      IF NVL(v_cod_tip_asiento,0) > 0 THEN
         --- Generar movimiento por el estado actual
         if  p_cod_sec_con_act is not null
         and p_ind_res_act     is not null
         and p_cod_tip_deu_act is not null then
            LP_OBT_ASI_ASOCIADO(p_cod_modulo,p_cod_modalidad,null,v_cod_tip_asiento, --DYDMR-2915--
                                p_cod_oficina,v_cod_moneda,
                                p_cod_sec_con_act,p_ind_res_act,
                                p_cod_tip_deu_act,v_cod_plazo,
                                v_est_cuenta, v_tip_cuenta,
                                v_tip_interes, v_tip_renovacion,
                                v_cat_automatica,
                                v_capital,v_cod_sec_rubro );
         end if;
         --- Generar movimiento por el estado anterior
         if  p_cod_sec_con_ant is not null
         and p_ind_res_ant     is not null
         and p_cod_tip_deu_ant is not null then
            LP_OBT_ASI_ASOCIADO(p_cod_modulo,p_cod_modalidad,null,v_cod_tip_asiento, --DYDMR-2915--
                                p_cod_oficina,v_cod_moneda,
                                p_cod_sec_con_ant,p_ind_res_ant,
                                p_cod_tip_deu_ant,v_cod_plazo,
                                v_est_cuenta, v_tip_cuenta,
                                v_tip_interes, v_tip_renovacion,
                                v_cat_automatica,
                                v_capital*-1, v_cod_sec_rubro);
         end if;
      END IF;
   END IF;
   IF NVL(v_interes,0) <> 0 THEN
      lp_obt_asi_tran(p_cod_modulo,p_cod_modalidad,657, v_cod_tip_asiento, v_cod_pro_contable);
      IF NVL(v_cod_tip_asiento,0) > 0 THEN
         if  p_cod_sec_con_act is not null
         and p_ind_res_act     is not null
         and p_cod_tip_deu_act is not null then
            LP_OBT_ASI_ASOCIADO(p_cod_modulo,p_cod_modalidad,null,v_cod_tip_asiento, --DYDMR-2915--
                                p_cod_oficina,v_cod_moneda,
                                p_cod_sec_con_act,p_ind_res_act,
                                p_cod_tip_deu_act,v_cod_plazo,
                                v_est_cuenta, v_tip_cuenta,
                                v_tip_interes, v_tip_renovacion,
                                v_cat_automatica,
                                v_interes, v_cod_sec_rubro);
         end if;
         if  p_cod_sec_con_ant is not null
         and p_ind_res_ant     is not null
         and p_cod_tip_deu_ant is not null then
            LP_OBT_ASI_ASOCIADO(p_cod_modulo,p_cod_modalidad,null,v_cod_tip_asiento, --DYDMR-2915--
                                p_cod_oficina,v_cod_moneda,
                                p_cod_sec_con_ant,p_ind_res_ant,
                                p_cod_tip_deu_act,v_cod_plazo,
                                v_est_cuenta, v_tip_cuenta,
                                v_tip_interes, v_tip_renovacion,
                                v_cat_automatica,
                                v_interes*-1, v_cod_sec_rubro);
         end if;
       END IF;
   END IF;
   -- DYDMR-2915 --
   IF NVL(v_pignorado,0) <> 0 THEN
      --- Obtenermos la transaccion correspondiente
      IF p_cod_modulo = 4 THEN -- Cta cte --
         v_cod_transaccion := 2604;
      END IF;
      IF p_cod_modulo = 3 THEN -- Cta Ahorro, CDA, Cupones --
         v_cod_transaccion := 2604;
         --Determino si la cuenta es combinada--
         begin
          select v.cta_combinada into v_situacion from ah_cta_vistas v where v.nro_cuenta = p_nro_cuenta;
         exception
           when others then
             v_situacion := 'N';
         end;
         IF NVL(v_situacion,'N') = 'S' THEN
            v_cod_transaccion := 2605;
         END IF;
         -- cda y cupones --
         IF p_cod_modalidad in (33,36) THEN
            begin
             select decode(a.est_batch,
                           'B',
                           decode(a.est_cer_batch, 'V', 'V', 'N'),
                           decode(a.est_batch, 'P', 'V', a.est_batch)) est_batch
               into v_est_cta_batch
               from ah_cta_certificados a
              where a.nro_cuenta = p_nro_cuenta;
            exception
              when others then
                v_est_cta_batch := 'N';
            end;
            IF v_est_cta_batch = 'V' THEN --si esta vencido
               v_cod_transaccion := 2605;
            ELSE
               v_cod_transaccion := '603';
            END IF;
         END IF;
      END IF;
      lp_obt_asi_tran(p_cod_modulo,p_cod_modalidad,v_cod_transaccion, v_cod_tip_asiento, v_cod_pro_contable);
      IF NVL(v_cod_tip_asiento,0) > 0 THEN
         --- Generar movimiento por el estado actual
         if  p_cod_sec_con_act is not null
         and p_ind_res_act     is not null
         and p_cod_tip_deu_act is not null then
            LP_OBT_ASI_ASOCIADO(p_cod_modulo,p_cod_modalidad,null,v_cod_tip_asiento,
                                p_cod_oficina,v_cod_moneda,
                                p_cod_sec_con_act,p_ind_res_act,
                                p_cod_tip_deu_act,v_cod_plazo,
                                v_est_cuenta, v_tip_cuenta,
                                v_tip_interes, v_tip_renovacion,
                                v_cat_automatica,
                                v_pignorado, v_cod_sec_rubro);
         end if;
         --- Generar movimiento por el estado anterior
         if  p_cod_sec_con_ant is not null
         and p_ind_res_ant     is not null
         and p_cod_tip_deu_ant is not null then
            LP_OBT_ASI_ASOCIADO(p_cod_modulo,p_cod_modalidad,null,v_cod_tip_asiento,
                                p_cod_oficina,v_cod_moneda,
                                p_cod_sec_con_ant,p_ind_res_ant,
                                p_cod_tip_deu_ant,v_cod_plazo,
                                v_est_cuenta, v_tip_cuenta,
                                v_tip_interes, v_tip_renovacion,
                                v_cat_automatica,
                                v_pignorado*-1, v_cod_sec_rubro);
         end if;
      END IF;
   END IF;
END;
/* Obtener datos contables del cliente. */
PROCEDURE PR_OBT_DAT_CON_CLI
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_SEC_CONTABLE IN OUT GE_CLIENTES.COD_SEC_CONTABLE%TYPE
 ,P_RESIDENTE IN OUT GE_CLIENTES.RESIDENTE%TYPE
 ,P_COD_TIP_DEUDOR IN OUT GE_CLIENTES.COD_TIP_DEUDOR%TYPE
 )
 IS
BEGIN
   SELECT COD_SEC_CONTABLE,RESIDENTE,COD_TIP_DEUDOR
     INTO p_cod_sec_contable,p_residente,p_cod_tip_deudor
     FROM GE_CLIENTES
    WHERE COD_PERSONA = p_cod_persona;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000, 'Cliente '||p_cod_persona||' no registrado');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Obt.Dat.Cliente '||SQLERRM);
END;
/* Verifica el tipo de cliente si es valido. */
FUNCTION FU_VER_TIP_VALIDO
 (P_COD_SEC_CONTABLE IN GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE
 ,P_IND_RESIDENTE IN GE_TIP_DEUDORES.IND_RESIDENTE%TYPE
 ,P_COD_TIP_DEUDOR IN GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE
 )
 RETURN VARCHAR2
 IS

v_ind_sino  varchar2(1) := 'N';
BEGIN
   SELECT 'S' INTO v_ind_sino
     FROM GE_TIP_DEUDORES
    WHERE COD_SEC_CONTABLE = p_cod_sec_contable
      AND IND_RESIDENTE = p_ind_residente
      AND COD_TIP_DEUDOR = p_cod_tip_deudor;
   RETURN ('S');
EXCEPTION
   WHEN TOO_MANY_ROWS THEN
      RETURN ('S');
   WHEN NO_DATA_FOUND THEN
      RETURN ('N');
   WHEN OTHERS THEN
      raise_application_error(-20000,'Al leer GE_TIP_DEUDORES '||SQLERRM);
END;

END PAG_CCL;
/

