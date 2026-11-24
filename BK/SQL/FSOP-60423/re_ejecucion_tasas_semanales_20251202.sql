SET DEFINE OFF;

--------------------------------------------------------------------------------
-- FSOP – Re-ejecución Tasas de Interés
-- Semana: 2 de Diciembre 2025
-- Código de semana: 20251202
-- Motivo: Ejecución realizada antes del cierre, información incompleta
--------------------------------------------------------------------------------

-- Inicialización de contexto de aplicación
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
END;
/

--------------------------------------------------------------------------------
-- Inserción del registro de control para habilitar la re-ejecución de la semana
--------------------------------------------------------------------------------
BEGIN
  INSERT INTO IT.GE_FEC_TAS_INT
    ( FECHA_EJECUCION,
      MES,
      CODIGO_SEMANA,
      NRO_SEMANA,
      ULTIMA_SEMANA,
      FEC_DESDE,
      FEC_HASTA )
  VALUES
    ( TO_DATE('16/12/2025 00:00:00','DD/MM/RRRR HH24:MI:SS'),
      'DICIEMBRE',
      '20251202',
      '2',
      'N',
      TO_DATE('07/12/2025 00:00:00','DD/MM/RRRR HH24:MI:SS'),
      TO_DATE('13/12/2025 00:00:00','DD/MM/RRRR HH24:MI:SS') );

  COMMIT;
END;
/

--------------------------------------------------------------------------------
-- Ejecución del proceso de generación de Tasas de Interés
--------------------------------------------------------------------------------
BEGIN
  IT.PAG_TAS.PRC_GEN_TAS_INT();
END;
/

--------------------------------------------------------------------------------
-- Verificación de la ejecución (último ID de ejecución)
--------------------------------------------------------------------------------
SELECT *
  FROM IT.GE_LOG_TAS_INT_SEM
 WHERE ID_EJECUCION = (SELECT MAX(ID_EJECUCION)
                         FROM IT.GE_LOG_TAS_INT_SEM);

--------------------------------------------------------------------------------
-- Verificación de volumen de registros generados por CORCOD
--------------------------------------------------------------------------------
SELECT CORCOD,
       COUNT(*) AS CANTIDAD
  FROM IT.GE_REP_TAS_INT_SEM
 GROUP BY CORCOD
 ORDER BY CORCOD;
