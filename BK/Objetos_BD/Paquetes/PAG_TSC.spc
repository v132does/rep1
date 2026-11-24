create or replace PACKAGE    IT.PAG_TSC AS
  ----------------------------------------------------------------------------
  -- Proceso principal de Tasas Saldos Contables
  --  - Genera un nuevo ID_EJECUCION
  --  - Carga IT.GE_REP_TAS_SAL_DET
  --  - Genera IT.GE_REP_TAS_SAL
  --  - Registra logs en IT.GE_LOG_TSC / IT.GE_LOG_TSC_DET
  ----------------------------------------------------------------------------
  PROCEDURE PR_EJE_TSC (
    i_fecha_corte   IN  DATE,
    o_id_ejecucion  OUT NUMBER
  );

  ----------------------------------------------------------------------------
  -- Genera el reporte agrupado (IT.GE_REP_TAS_SAL) a partir del detalle
  ----------------------------------------------------------------------------
  PROCEDURE PR_GEN_REPORTE (
    i_fecha_corte   IN DATE,
    i_id_ejecucion  IN NUMBER
  );

  ----------------------------------------------------------------------------
  -- Indica si un CODCTA está permitido según IT.GE_REL_CTA_ACOD_TAS_INT
  -- Retorna 1 = permitido, 0 = no permitido / error
  ----------------------------------------------------------------------------
  FUNCTION FN_ES_CODCTA_PERMITIDO (
    i_codcta IN VARCHAR2
  ) RETURN NUMBER;

END PAG_TSC;
