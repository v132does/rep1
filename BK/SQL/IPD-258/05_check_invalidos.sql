-- =====================================================
-- DBA FASE 5: CHEQUEO DE OBJETOS INVÁLIDOS RESIDUALES
-- =====================================================
-- Verifica objetos INVALID remanentes en el schema IT
-- tras la ejecución del borrado.
-- Prerequisito: 04_drop_invalidos.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 5: CHEQUEO DE OBJETOS INVÁLIDOS RESIDUALES - SCHEMA IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- 1. Objetos INVALID residuales en IT ---
PROMPT --- Si hay filas: algun DROP no se ejecuto ---

SELECT owner,
       object_type,
       object_name,
       status
FROM   dba_objects
WHERE  status = 'INVALID'
  AND  owner  = 'IT'
ORDER BY owner, object_type, object_name;

PROMPT
PROMPT --- 2. Objetos VALID que se invalidaron en la ultima hora (dependencias rotas en cascada) ---
PROMPT --- Si hay filas: revisar y recompilar ---

SELECT owner,
       object_type,
       object_name,
       TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') AS invalidado_en
FROM   dba_objects
WHERE  status        = 'INVALID'
  AND  owner         = 'IT'
  AND  last_ddl_time >= SYSDATE - 1/24
ORDER BY object_type, object_name;

PROMPT
PROMPT --- 3. Sinonimos publicos huerfanos (apuntan a objetos IT que ya no existen) ---
PROMPT --- Si hay filas: ejecutar DROP PUBLIC SYNONYM para cada uno ---

SELECT s.synonym_name,
       s.table_owner,
       s.table_name
FROM   all_synonyms s
WHERE  s.owner       = 'PUBLIC'
  AND  s.table_owner = 'IT'
  AND  NOT EXISTS (
           SELECT 1
           FROM   all_objects o
           WHERE  o.owner       = s.table_owner
             AND  o.object_name = s.table_name
       )
ORDER BY s.synonym_name;

PROMPT
PROMPT --- 4. Permisos huerfanos (otorgados sobre objetos IT que ya no existen) ---
PROMPT --- Si hay filas: ejecutar REVOKE para cada uno ---

SELECT p.grantee,
       p.privilege,
       p.table_name
FROM   dba_tab_privs p
WHERE  p.owner = 'IT'
  AND  NOT EXISTS (
           SELECT 1
           FROM   all_objects o
           WHERE  o.owner       = p.owner
             AND  o.object_name = p.table_name
       )
ORDER BY p.table_name, p.grantee;
