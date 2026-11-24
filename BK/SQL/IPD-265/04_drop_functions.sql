-- =====================================================
-- DBA FASE 4: BORRADO DE FUNCIONES DE MIGRACIÓN
-- =====================================================
-- Genera las sentencias DROP FUNCTION para las 2 funciones
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
PROMPT DBA FASE 4: BORRADO DE FUNCIONES DE MIGRACIÓN - SCHEMA IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================
PROMPT
PROMPT ADVERTENCIA: Esta es la fase destructiva.
PROMPT              Las 2 funciones de migración serán eliminadas del schema IT.
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP de funciones de migración ---

SELECT 'DROP ' || object_type || ' ' || owner || '.' || object_name || ';'
FROM   dba_objects
WHERE  owner       = 'IT'
  AND  object_name IN (
    'FUG_OBT_HOR_DIS_MIGRADO',
    'FUG_OBT_USU_MIGRADO'
  )
  AND  object_type = 'FUNCTION'
ORDER BY object_name;
