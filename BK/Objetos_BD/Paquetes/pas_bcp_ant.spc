CREATE OR REPLACE PACKAGE IT.PAS_BCP_ANT IS
  v_tip_implementacion ge_par_generales.tip_implementacion%type := fug_obt_tip_implementacion;
  v_rango1             ge_movimientos.monto%type;
  v_rango2             ge_movimientos.monto%type;
  v_rango3             ge_movimientos.monto%type;
  v_rango4             ge_movimientos.monto%type;
  v_rango5             ge_movimientos.monto%type;
  v_rango6             ge_movimientos.monto%type;
  v_sal_min_vigente    pr_parametros.sal_min_vigente%type;

  /* Recuperar TAN - Res. 012022 */
  FUNCTION FU_OBT_VAL_TIR(p_inicial   IN NUMBER,
                          p_can_items IN NUMBER,
                          p_numeros   IN VARCHAR2,
                          p_plazos    IN VARCHAR2) RETURN NUMBER;
  /* Recuperar TIR */
  FUNCTION FU_OBT_TIR_ADE(P_INICIAL   IN NUMBER,
                          P_CAN_ITEMS IN NUMBER,
                          P_NUMEROS   IN VARCHAR2,
                          P_DIAS      IN NUMBER) RETURN NUMBER;
  /* Recuperar TIR */
  FUNCTION FU_OBT_TIR(P_INICIAL   IN NUMBER,
                      P_CAN_ITEMS IN NUMBER,
                      P_NUMEROS   IN VARCHAR2) RETURN NUMBER;
  /* Obtener tasa efectiva. */
  FUNCTION FU_OBT_TAE(P_TASA IN NUMBER, P_PERIODO_CAPIT IN NUMBER)
    RETURN NUMBER;
  /* Obtener tasa anual. */
  FUNCTION FU_OBT_TAS_ANUAL(P_TIR IN NUMBER, P_PERIODO_CAPIT IN NUMBER)
    RETURN NUMBER;
  /* Obtener tasa efectiva y nominal de prestamo */
  PROCEDURE PR_OBT_TAS_PRESTAMO(P_NRO_SOLICITUD IN PR_CTA_PRESTAMOS.NRO_SOLICITUD%TYPE,
                                P_NRO_CUENTA    IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
                                P_VAL_TAE       IN OUT NUMBER,
                                P_VAL_TAN       IN OUT NUMBER);
  /* Buscar moneda fuerte */
  FUNCTION FU_OBT_MON_FUERTE RETURN VARCHAR2;
  /* Obtener fecha de vencimiento anterior del prestamos. */
  FUNCTION FU_OBT_VTO_ANT_CUO(P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE,
                              P_NRO_CUOTA  IN PR_CUOTAS.NRO_CUOTA%TYPE)
    RETURN DATE;

END PAS_BCP_ANT;
/
