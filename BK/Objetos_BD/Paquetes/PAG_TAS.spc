create or replace PACKAGE          IT.PAG_TAS IS

  ------------------------------------------------------------------------------
  -- PACKAGE SPECIFICATION: PAG_TAS | PROYECTO: NOR-314 | AUTOR: DDBAINOTTI | FECHA: 16/07/2025
  ------------------------------------------------------------------------------

  -- Retorna el codigo de cuenta contable segun los parametros.
  FUNCTION FN_CALC_CODCTA (
    I_ID_EJECUCION    IN NUMBER,
    I_COD_MODULO      IN VARCHAR2,
    I_COD_MODALIDAD   IN VARCHAR2,
    I_NRO_CUENTA      IN VARCHAR2
  ) RETURN VARCHAR2;

  -- Calcula el codigo de area BCP (ACOD).
  FUNCTION FN_CALC_ACOD (
    I_ID_EJECUCION    IN NUMBER,
    I_CODCTA          IN VARCHAR2,
    I_PLAZO           IN NUMBER,
    I_COD_MODULO      IN VARCHAR2,
    I_COD_MODALIDAD   IN VARCHAR2,
    I_NRO_CUENTA      IN VARCHAR2,
    I_COD_RUBRO      IN VARCHAR2,
    I_TIP_SALDO      IN VARCHAR2
  ) RETURN VARCHAR2;

  -- Calcula el plazo de la operacion en dias.
  FUNCTION FN_CALC_PLAZO (
    I_ID_EJECUCION      IN NUMBER,
    I_COD_MODULO        IN VARCHAR2,
    I_COD_MODALIDAD     IN VARCHAR2,
    I_FEC_APERTURA      IN DATE,
    I_FEC_VENCIMIENTO   IN DATE,
    I_NRO_CUENTA        IN VARCHAR2
  ) RETURN NUMBER;

  -- Calcula el monto segun modulo, modalidad y moneda.
  FUNCTION FN_CALC_MONTO (
    I_ID_EJECUCION    IN NUMBER,
    I_COD_MODULO      IN NUMBER,
    I_COD_MODALIDAD   IN NUMBER,
    I_NRO_CUENTA      IN VARCHAR2,
    I_SAL_CONTABLE    IN NUMBER,
    I_COD_MONEDA      IN VARCHAR2,
    I_FEC_APERTURA    IN DATE
  ) RETURN NUMBER;

  -- Calcula el periodo informativo.
  FUNCTION FN_CALC_PERIODO (
    I_ID_EJECUCION    IN NUMBER,
    I_COD_MODULO      IN VARCHAR2,
    I_COD_MODALIDAD   IN VARCHAR2,
    I_NRO_CUENTA      IN VARCHAR2
  ) RETURN NUMBER;

  -- Calcula la tasa registrada o pactada.
  FUNCTION FN_CALC_TASREG (
    I_ID_EJECUCION    IN NUMBER,
    I_COD_MODULO      IN VARCHAR2,
    I_COD_MODALIDAD   IN VARCHAR2,
    I_NRO_CUENTA      IN VARCHAR2
  ) RETURN VARCHAR2;

  -- Calcula la tasa nominal segun parametros especificados.
  FUNCTION FN_CALC_TASA_NOMINAL (
    I_ID_EJECUCION        IN NUMBER,
    I_COD_MODULO          IN VARCHAR2,
    I_COD_MODALIDAD       IN VARCHAR2,
    I_COD_OFICINA         IN VARCHAR2,
    I_NRO_CUENTA          IN VARCHAR2,
    I_COD_MONEDA          IN VARCHAR2,
    I_MONTO               IN NUMBER,
    I_TAS_PERSONALIZADA   IN VARCHAR2,
    I_COD_TASA            IN VARCHAR2,
    I_VAL_TASA            IN NUMBER,
    I_FEC_APERTURA        IN DATE
  ) RETURN NUMBER;

  -- Calcula la tasa efectiva segun tasa nominal y plazo.
  FUNCTION FN_CALC_TASA_EFECTIVA (
    I_ID_EJECUCION    IN NUMBER,
    I_TASA_NOMINAL    IN NUMBER,
    I_PLAZO_DIAS      IN NUMBER,
    I_COD_MODULO      IN VARCHAR2,
    I_COD_MODALIDAD   IN VARCHAR2,
    I_NRO_CUENTA      IN VARCHAR2,
    I_CAPITAL         IN NUMBER DEFAULT NULL
  ) RETURN NUMBER;
  
  PROCEDURE INS_LOG_TAS_INT_SEM(
    O_ID_LOG       OUT NUMBER,
    I_ID_EJECUCION IN  NUMBER,
    I_TIPO_INF     IN  VARCHAR2
  ) ;
  PROCEDURE UPD_LOG_TAS_INT_SEM(
    I_ID_LOG        IN NUMBER,
    I_CANT_CUENTAS  IN NUMBER,
    I_CANT_ERRORES  IN NUMBER,
    I_ESTADO        IN VARCHAR2,
    I_MENSAJE       IN VARCHAR2
  ) ;
  -- Registra eventos de log detallados.
  PROCEDURE PRC_LOG_TAS_INT_SEM_DET (
    I_ID_EJECUCION    IN NUMBER,
    I_TIPO_EVENTO     IN VARCHAR2,
    I_NRO_CUENTA      IN VARCHAR2,
    I_PROCESO         IN VARCHAR2,
    I_MENSAJE         IN VARCHAR2
  );

  -- Genera el informe de tasas de interes.
  PROCEDURE PRC_GEN_TAS_INT;

  -- Genera el reporte plano en GE_REP_TAS_INT_SEM.
  PROCEDURE PRC_GEN_REP_TAS_INT (
    I_ID_EJECUCION    IN NUMBER
  );
  


END PAG_TAS;
