-- =====================================================
-- DBA FASE 4: BORRADO DE TIPOS DE MIGRACIÓN
-- =====================================================
-- Genera las sentencias DROP TYPE para los 6 tipos
-- de migración del schema IT.
-- Prerequisito: 03_revoke_privilege.sql completado.
-- ADVERTENCIA: Esta es la fase destructiva.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 4: BORRADO DE TIPOS DE MIGRACIÓN - SCHEMA IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================
PROMPT
PROMPT ADVERTENCIA: Esta es la fase destructiva.
PROMPT              Los 6 tipos de migración serán eliminados del schema IT.
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP de tipos de migración ---

SELECT 'DROP ' || object_type || ' ' || owner || '.' || object_name || ';'
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
  AND  object_type = 'TYPE'
ORDER BY object_name;
