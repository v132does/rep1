-- =====================================================
-- DBA FASE 4: BORRADO DE OBJETOS INVÁLIDOS
-- =====================================================
-- Genera las sentencias DROP para todos los objetos INVALID
-- del schema IT (excepto MATERIALIZED VIEWs).
-- Prerequisito: 03_revoke_permisos.sql completado.
-- ADVERTENCIA: Esta es la fase destructiva.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 4: BORRADO DE OBJETOS INVÁLIDOS - SCHEMA IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================
PROMPT
PROMPT ADVERTENCIA: Esta es la fase destructiva.
PROMPT              Los objetos INVALID serán eliminados del schema IT.
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP de objetos inválidos ---

SELECT 'DROP ' || object_type || ' ' || owner || '.' || object_name || ';'
FROM   dba_objects
WHERE  status      = 'INVALID'
  AND  owner       = 'IT'
  AND  object_type <> 'MATERIALIZED VIEW'
ORDER BY owner, object_type, object_name;
