-- =====================================================
-- DBA FASE 3: REVOCACIÓN DE PERMISOS DE OBJETOS INVÁLIDOS
-- =====================================================
-- Genera las sentencias REVOKE para todos los permisos
-- otorgados sobre objetos INVALID del schema IT.
-- Prerequisito: 02_drop_sinonimos_publicos.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 3: REVOCACIÓN DE PERMISOS - OBJETOS INVÁLIDOS IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias REVOKE sobre objetos inválidos ---

SELECT 'revoke ' || privilege || ' on ' || owner || '.' || table_name || ' from ' || grantee || ';'
FROM   dba_tab_privs
WHERE  table_name IN (
           SELECT object_name
           FROM   dba_objects
           WHERE  status      = 'INVALID'
             AND  owner       = 'IT'
             AND  object_type <> 'MATERIALIZED VIEW'
       )
  AND  owner = 'IT'
ORDER BY owner, table_name;
