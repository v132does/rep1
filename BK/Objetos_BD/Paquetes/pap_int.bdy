CREATE OR REPLACE PACKAGE BODY IT.PAP_INT IS

/* Obtiene la tasa vigente. */
FUNCTION FU_OBT_TASA_VIGENTE
 (P_FEC_INICIO IN PR_SOL_TASAS.FEC_VIGENCIA%TYPE
 ,P_NRO_SOLICITUD IN PR_SOL_TASAS.NRO_SOLICITUD%TYPE
 )
 RETURN NUMBER
 IS

V_VAL_TASA PR_SOL_TASAS.VAL_TASA%TYPE;
BEGIN
   SELECT PR_SOL_TASAS.VAL_TASA
     INTO v_val_tasa
     FROM PR_SOL_TASAS
    WHERE PR_SOL_TASAS.FEC_VIGENCIA <= p_fec_inicio

      AND PR_SOL_TASAS.FEC_VIGENCIA = (SELECT MAX(PR_SOL_TASAS.FEC_VIGENCIA)
                                         FROM PR_SOL_TASAS
                                        WHERE PR_SOL_TASAS.FEC_VIGENCIA <= p_fec_inicio
                                          AND PR_SOL_TASAS.NRO_SOLICITUD = p_nro_solicitud)
      AND PR_SOL_TASAS.NRO_SOLICITUD = p_nro_solicitud;
RETURN v_val_tasa;
EXCEPTION
--
       WHEN no_data_found THEN
            raise_application_error(-20000,'Tasa Inexistente para '||
                                           'Nro.Propuesta: '       ||
                                           to_char(p_nro_solicitud)      ||
                                           ' de fecha '            ||
                                           to_char(p_fec_inicio, 'dd/mm/yyyy'));
END;
/* Calcula el interes. */
FUNCTION FU_CAL_INTERES
 (P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 ,P_FEC_VENCIMIENTO IN PR_CTA_PRESTAMOS.FEC_VENCIMIENTO%TYPE
 ,P_MTO_CAPITAL IN PR_CTA_PRESTAMOS.MTO_CAPITAL%TYPE
 ,P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE
 ,P_VAL_TASA IN PR_CTA_PRESTAMOS.VAL_TASA%TYPE
 )
 RETURN NUMBER
 IS

V_INTERES PR_CTA_PRESTAMOS.SAL_INTERES%TYPE;
V_VAL_TASA PR_CTA_PRESTAMOS.VAL_TASA%TYPE;
V_DIA_PLAZO PR_SOLICITUDES.DIA_PLAZO%TYPE;
BEGIN
/*   IF p_val_tasa = 0 THEN
      v_val_tasa := fu_obt_tasa_vigente (p_fec_inicio, p_nro_solicitud);
   ELSE
*/      v_val_tasa := p_val_tasa;
--   END IF;
   v_dia_plazo   := trunc(p_fec_vencimiento) - trunc(p_fec_inicio) + 1;
   v_interes := v_dia_plazo * p_mto_capital * v_val_tasa/36500;
   RETURN v_interes;
END;
/* Obtiene el capital acumulado. */
FUNCTION FU_OBT_CAPITAL_ACUMU
 (P_FEC_INICIO IN PR_CTA_PRESTAMOS.FEC_INICIO%TYPE
 ,P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN number
 IS

V_MTO_CAPITAL PR_CTA_PRESTAMOS.MTO_CAPITAL%TYPE;
BEGIN
SELECT SUM(NVL(PR_CUOTAS.MTO_CAPITAL,0) + NVL(PR_CUOTAS.MTO_INT_DOCUMENTADO,0) - NVL(PR_CUOTAS.MTO_CAP_ADELANTADO,0))
INTO v_mto_capital
FROM PR_CUOTAS
WHERE PR_CUOTAS.ESTADO <> 'N'
AND PR_CUOTAS.FEC_VENCIMIENTO > p_fec_inicio
and PR_CUOTAS.NRO_CUENTA = p_nro_cuenta;
RETURN v_mto_capital;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  raise_application_error(-20000, 'ERROR al obtener capital acumulado ');
WHEN OTHERS THEN
  raise_application_error(-20000, 'ERROR al buscar valor acumulado '||
                                        'de capital en PR_CUOTAS');
END;
/* Obtener Tasa de Interés Efectiva. */
FUNCTION FU_OBT_TASA_EFECTIVA
 (P_NRO_SOLICITUD IN PR_SOLICITUDES.NRO_SOLICITUD%TYPE
 ,P_FEC_INICIO IN PR_SOLICITUDES.FEC_INICIO%TYPE
 ,P_DIA_PLAZO IN PR_SOLICITUDES.DIA_PLAZO%TYPE
 )
 RETURN INTEGER
 IS

V_VAL_TASA PR_SOL_TASAS.VAL_TASA%TYPE;
V_TASA_VIGENTE PR_SOL_TASAS.VAL_TASA%TYPE;
V_DIV NUMBER(18,2);
V_EXP NUMBER(18,2);
BEGIN
V_TASA_VIGENTE := PAP_INT.FU_OBT_TASA_VIGENTE(P_FEC_INICIO,P_NRO_SOLICITUD);

V_DIV := ((V_TASA_VIGENTE*P_DIA_PLAZO)/(365*100));
V_EXP := (365/P_DIA_PLAZO);

V_VAL_TASA := ((POWER((1+V_DIV),V_EXP))-1)*100;

return nvl(v_val_tasa,0);
END;

END PAP_INT;
/

