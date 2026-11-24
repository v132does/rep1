-- =====================================================
-- DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS DE OBJETOS INVÁLIDOS
-- =====================================================
-- Genera y ejecuta los DROP PUBLIC SYNONYM para todos los
-- objetos INVALID del schema IT (excepto MATERIALIZED VIEWs).
-- Prerequisito: 01_backup_expdp.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS - OBJETOS INVÁLIDOS IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP PUBLIC SYNONYM ---

SELECT 'drop public synonym ' || object_name || ';'
FROM   dba_objects
WHERE  status      = 'INVALID'
  AND  owner       = 'IT'
  AND  object_type <> 'MATERIALIZED VIEW'
ORDER BY owner, object_type, object_name;
