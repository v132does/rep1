CREATE OR REPLACE PROCEDURE IT.PRP_OBT_TAS_PRESTAMO(P_COD_MODULO            IN GE_TAS_RANGOS.COD_MODULO%TYPE,
                                                 P_COD_MODALIDAD         IN GE_TAS_RANGOS.COD_MODALIDAD%TYPE,
                                                 P_COD_SUB_MODALIDAD     IN GE_SUB_MODALIDADES.COD_SUB_MODALIDAD%TYPE,
                                                 P_COD_MONEDA            IN GE_TAS_RANGOS.COD_MONEDA%TYPE,
                                                 P_COD_OFICINA           IN GE_TAS_RANGOS.COD_OFICINA%TYPE,
                                                 P_VAL_HASTA             IN GE_TAS_RANGOS.VAL_HASTA%TYPE,
                                                 P_CUENTA                IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                                 P_COD_PERSONA           IN BA_PERSONAS.COD_PERSONA%TYPE,
                                                 P_TAS_PERSONALIZADA     IN GE_CUENTAS.TAS_PERSONALIZADA%TYPE,
                                                 P_VAL_TAS_ACTUAL        IN GE_TAS_RANGOS.VAL_TASA%TYPE,
                                                 P_VAL_TAS_RENEGOCIACION OUT GE_TAS_RANGOS.VAL_TASA%TYPE,
                                                 P_COD_TAS_RENEGOCIACION OUT GE_TAS_RANGOS.COD_TASA%TYPE,
                                                 P_VAL_SPREAD            OUT PR_SOLICITUDES.SPREAD%TYPE,
                                                 P_FEC_RENEGOCIACION     IN  GE_TAS_FECHAS.FEC_VIGENCIA%TYPE DEFAULT NULL) IS --DYDMR-4042--

  --Entradas Calculadas--
  V_FEC_FINAL             DATE := NVL(P_FEC_RENEGOCIACION, PAG_CAL.FU_OBT_FEC_ACTUAL(6));--DYDMR-4042- Se modifica cálculo para Tasa Ref. Actual Renegociación. 14/07/2016 
  V_COD_TAS_RENEGOCIACION GE_TASAS.COD_TASA%TYPE := FUG_OBT_PARDINAMICO('COD_TAS_RENEGOCIACION');

  --Parametros de Salida--
  V_VAL_TAS_RENEGOCIACION GE_TAS_RANGOS.VAL_TASA%TYPE;
  V_FEC_VIGENCIA          DATE := NULL;
  V_TIP_VALOR             GE_TASAS.TIP_VALOR%TYPE;
  V_TIPO                  GE_TASAS.TIPO%TYPE;

BEGIN

  --Buscar la Tasa de renegociación--
  BEGIN
    PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO,
                            P_COD_MODALIDAD,
                            P_COD_OFICINA,
                            P_CUENTA,
                            P_COD_MONEDA,
                            P_VAL_HASTA,
                            P_TAS_PERSONALIZADA,
                            V_COD_TAS_RENEGOCIACION,
                            NULL,
                            V_FEC_FINAL,
                            V_VAL_TAS_RENEGOCIACION,
                            V_FEC_VIGENCIA,
                            V_TIP_VALOR,
                            V_TIPO,
                            P_COD_PERSONA,
                            P_COD_SUB_MODALIDAD);
  EXCEPTION
    WHEN OTHERS THEN
      V_VAL_TAS_RENEGOCIACION := 0;
  END;
  
  --Carga de Valores para devolver--
  P_VAL_TAS_RENEGOCIACION := V_VAL_TAS_RENEGOCIACION;
  P_COD_TAS_RENEGOCIACION := V_COD_TAS_RENEGOCIACION;
  P_VAL_SPREAD            := NVL(P_VAL_TAS_ACTUAL - V_VAL_TAS_RENEGOCIACION,
                                 0);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,
                            'Tasa : ' || TO_CHAR(V_COD_TAS_RENEGOCIACION) ||
                            ' no esta registrada por rango');
END;
/

