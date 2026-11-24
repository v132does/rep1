CREATE OR REPLACE FUNCTION IT.FUG_OBT_VAL_PERSONALIZADA(P_COD_MODULO        IN BA_MODULOS.COD_MODULO%TYPE,
                                                     P_COD_MODALIDAD     IN GE_MODALIDADES.COD_MODALIDAD%TYPE,
                                                     P_COD_OFICINA       IN BA_OFICINAS.COD_OFICINA%TYPE,
                                                     P_NRO_CUENTA        IN VARCHAR2,
                                                     P_COD_MONEDA        IN BA_MONEDAS.COD_MONEDA%TYPE,
                                                     P_MTO_TRANSACCION   IN NUMBER,
                                                     P_TAS_PERSONALIZADA IN VARCHAR2,
                                                     P_COD_TASA          IN GE_TASAS.COD_TASA%TYPE,
                                                     P_COD_TRANSACCION   IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
                                                     P_FEC_FINAL         IN DATE,
                                                     P_COD_PERSONA       IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL)
  RETURN NUMBER IS
 --CRO-JM-01/2015: DYDMR-1412
 /*
   Creamos este programa para saber la tasa personalizada por código de persona
 */
  V_VAL_TASA     GE_TAS_FECHAS.VAL_TASA%TYPE;
  V_FEC_VIGENCIA DATE;
  V_COD_TASA     GE_TASAS.COD_TASA%TYPE;
  V_TIP_VALOR    GE_TASAS.TIP_VALOR%TYPE;
  V_TIPO         GE_TASAS.TIPO%TYPE;
BEGIN
  V_COD_TASA     := P_COD_TASA;
  PAG_GEN.PR_OBT_VAL_TASA(P_COD_MODULO,
                          P_COD_MODALIDAD,
                          P_COD_OFICINA,
                          P_NRO_CUENTA,
                          P_COD_MONEDA,
                          P_MTO_TRANSACCION,
                          P_TAS_PERSONALIZADA,
                          V_COD_TASA,
                          P_COD_TRANSACCION,
                          P_FEC_FINAL,
                          V_VAL_TASA,
                          V_FEC_VIGENCIA,
                          V_TIP_VALOR,
                          V_TIPO,
                          P_COD_PERSONA);
  RETURN V_VAL_TASA;
exception
  when others then
    raise_application_error(-20000,
                            'cuenta ' || p_nro_cuenta || ' - ' || sqlerrm);
END FUG_OBT_VAL_PERSONALIZADA;
/

