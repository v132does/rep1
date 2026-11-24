-- =====================================================
-- DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS - PACKAGES DE MIGRACIÓN
-- =====================================================
-- Genera los DROP PUBLIC SYNONYM para los 12 packages de migración
-- del schema IT que serán eliminados en el paso 04.
-- Prerequisito: 01_backup_expdp.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS - PACKAGES DE MIGRACIÓN IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP PUBLIC SYNONYM para packages de migración ---

SELECT 'DROP PUBLIC SYNONYM ' || object_name || ';'
FROM   dba_objects
WHERE  owner       = 'IT'
  AND  object_name IN (
    'MIGGRUPOECONOMICO',
    'MIGRATION',
    'MIGRATION_REPORT',
    'MIGRATION_TRANSFORMER',
    'NEW_MIG_BALANCE',
    'PAW_TRANF_MIGRATION',
    'SS2K5ALLPLATFORM',
    'SYB12ALLPLATFORM',
    'TDALLPLATFORM'
  )
ORDER BY object_name;
