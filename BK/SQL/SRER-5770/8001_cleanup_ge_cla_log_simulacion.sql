-- SRER-5770 | Depuracion de logs espurios en GE_CLA_LOG_SIMULACION
-- Elimina registros de ejecuciones que solo llegaron a VALIDACION_ENTORNO_EJECUCION
-- con error de entorno (base productiva / base incorrecta) sin haber procesado datos.
-- Ref: NOR-655
--
-- Registros afectados: ~120 filas / 60 ejecuciones (sep/2025 - jun/2026)
-- Ejecutar en: produccion
--
-- PRE-CHECK: verificar antes de ejecutar
-- SELECT COUNT(DISTINCT ID_EJECUCION), COUNT(*), MIN(FECHA_INICIO), MAX(FECHA_INICIO)
-- FROM IT.GE_CLA_LOG_SIMULACION
-- WHERE ID_EJECUCION IN (
--     SELECT ID_EJECUCION FROM IT.GE_CLA_LOG_SIMULACION
--     WHERE ESTADO = 'ERROR'
--       AND (MENSAJE_ERROR LIKE '%Ejecucion prohibida en base productiva%'
--         OR MENSAJE_ERROR LIKE '%Base activa incorrecta%')
-- )
--   AND ID_EJECUCION NOT IN (
--     SELECT DISTINCT ID_EJECUCION FROM IT.GE_CLA_LOG_SIMULACION
--     WHERE PASO NOT LIKE '%LECTURA_PARAMETROS%'
--       AND PASO NOT LIKE '%VALIDACION_ENTORNO%'
-- );

DECLARE
  v_ejecuciones_spurias NUMBER;
BEGIN
  -- Identificar ejecuciones espurias (solo LECTURA + VALIDACION con error de entorno)
  SELECT COUNT(DISTINCT ID_EJECUCION)
    INTO v_ejecuciones_spurias
    FROM IT.GE_CLA_LOG_SIMULACION
   WHERE ID_EJECUCION IN (
             SELECT ID_EJECUCION FROM IT.GE_CLA_LOG_SIMULACION
              WHERE ESTADO = 'ERROR'
                AND (  MENSAJE_ERROR LIKE '%Ejecucion prohibida en base productiva%'
                    OR MENSAJE_ERROR LIKE '%Base activa incorrecta%' )
         )
     AND ID_EJECUCION NOT IN (
             SELECT DISTINCT ID_EJECUCION FROM IT.GE_CLA_LOG_SIMULACION
              WHERE PASO NOT LIKE '%LECTURA_PARAMETROS%'
                AND PASO NOT LIKE '%VALIDACION_ENTORNO%'
         );

  DBMS_OUTPUT.PUT_LINE('Ejecuciones espurias a eliminar: ' || v_ejecuciones_spurias);

  -- Eliminar registros de log espurios
  DELETE FROM IT.GE_CLA_LOG_SIMULACION
   WHERE ID_EJECUCION IN (
             SELECT ID_EJECUCION FROM IT.GE_CLA_LOG_SIMULACION
              WHERE ESTADO = 'ERROR'
                AND (  MENSAJE_ERROR LIKE '%Ejecucion prohibida en base productiva%'
                    OR MENSAJE_ERROR LIKE '%Base activa incorrecta%' )
         )
     AND ID_EJECUCION NOT IN (
             SELECT DISTINCT ID_EJECUCION FROM IT.GE_CLA_LOG_SIMULACION
              WHERE PASO NOT LIKE '%LECTURA_PARAMETROS%'
                AND PASO NOT LIKE '%VALIDACION_ENTORNO%'
         );

  DBMS_OUTPUT.PUT_LINE('Registros eliminados de GE_CLA_LOG_SIMULACION: ' || SQL%ROWCOUNT);

  COMMIT;
END;
/
