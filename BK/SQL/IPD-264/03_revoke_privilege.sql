-- =====================================================
-- DBA FASE 3: REVOCACIÓN DE PERMISOS - TIPOS DE MIGRACIÓN
-- =====================================================
-- Genera las sentencias REVOKE para todos los permisos
-- otorgados sobre los 6 tipos de migración del schema IT.
-- Prerequisito: 02_drop_synonym_public.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 3: REVOCACIÓN DE PERMISOS - TIPOS DE MIGRACIÓN IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias REVOKE sobre tipos de migración ---

SELECT 'REVOKE ' || privilege || ' ON ' || owner || '.' || table_name || ' FROM ' || grantee || ';'
FROM   dba_tab_privs
WHERE  owner      = 'IT'
  AND  table_name IN (
    'MIGR_FILTER',
    'MIGR_FILTER_SET',
    'MIGR_REPORT_DETAIL_ROW',
    'MIGR_REPORT_DETAIL_TABLE',
    'MIGR_REPORT_SUM_ROW',
    'MIGR_REPORT_SUM_TABLE'
  )
ORDER BY table_name;
