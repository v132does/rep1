-- =====================================================
-- DBA FASE 4: BORRADO DE PACKAGES DE MIGRACIÓN
-- =====================================================
-- Genera las sentencias DROP PACKAGE para los 12 packages
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
PROMPT DBA FASE 4: BORRADO DE PACKAGES DE MIGRACIÓN - SCHEMA IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================
PROMPT
PROMPT ADVERTENCIA: Esta es la fase destructiva.
PROMPT              Los 12 packages de migración serán eliminados del schema IT.
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP de packages de migración ---

SELECT 'DROP ' || object_type || ' ' || owner || '.' || object_name || ';'
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
  AND  object_type = 'PACKAGE'
ORDER BY object_name;
