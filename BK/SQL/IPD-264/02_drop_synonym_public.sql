-- =====================================================
-- DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS - TIPOS DE MIGRACIÓN
-- =====================================================
-- Genera los DROP PUBLIC SYNONYM para los 6 tipos de migración
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
PROMPT DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS - TIPOS DE MIGRACIÓN IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP PUBLIC SYNONYM para tipos de migración ---

SELECT 'DROP PUBLIC SYNONYM ' || object_name || ';'
FROM   dba_objects
WHERE  owner       = 'IT'
  AND  object_name IN (
    'MIGR_FILTER',
    'MIGR_FILTER_SET',
    'MIGR_REPORT_DETAIL_ROW',
    'MIGR_REPORT_DETAIL_TABLE',
    'MIGR_REPORT_SUM_ROW',
    'MIGR_REPORT_SUM_TABLE'
  )
ORDER BY object_name;
