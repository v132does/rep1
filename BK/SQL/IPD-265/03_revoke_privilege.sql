-- =====================================================
-- DBA FASE 3: REVOCACIÓN DE PERMISOS - FUNCIONES DE MIGRACIÓN
-- =====================================================
-- Genera las sentencias REVOKE para todos los permisos
-- otorgados sobre los 2 funciones de migración del schema IT.
-- Prerequisito: 02_drop_synonym_public.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 3: REVOCACIÓN DE PERMISOS - FUNCIONES DE MIGRACIÓN IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias REVOKE sobre funciones de migración ---

SELECT 'REVOKE ' || privilege || ' ON ' || owner || '.' || table_name || ' FROM ' || grantee || ';'
FROM   dba_tab_privs
WHERE  owner      = 'IT'
  AND  table_name IN (
    'FUG_OBT_HOR_DIS_MIGRADO',
    'FUG_OBT_USU_MIGRADO'
  )
ORDER BY table_name;
