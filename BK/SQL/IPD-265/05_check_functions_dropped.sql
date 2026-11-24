-- =====================================================
-- DBA FASE 5: VERIFICACIÓN DE BORRADO DE FUNCIONES DE MIGRACIÓN
-- =====================================================
-- Verifica que los funciones de migración fueron eliminados
-- correctamente y detecta efectos colaterales en el schema IT.
-- Prerequisito: 04_drop_functions.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 5: VERIFICACIÓN DE BORRADO DE FUNCIONES DE MIGRACIÓN - SCHEMA IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- 1. Packages de migración residuales en IT (aborta si encuentra alguno) ---

WHENEVER SQLERROR EXIT FAILURE

DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO   v_count
  FROM   dba_objects
  WHERE  owner       = 'IT'
    AND  object_type = 'FUNCTION'
    AND  object_name IN (
          'FUG_OBT_HOR_DIS_MIGRADO',
          'FUG_OBT_USU_MIGRADO'
         );
  IF v_count > 0 THEN
    RAISE_APPLICATION_ERROR(
      -20001,
      'FALLO: ' || v_count || ' funcion(es) de migracion residuales en IT. Re-ejecutar 04_drop_functions.sql.'
    );
  END IF;
  DBMS_OUTPUT.PUT_LINE('OK: 0 funciones de migracion residuales en IT.');
END;
/

WHENEVER SQLERROR CONTINUE

PROMPT
PROMPT --- 2. Objetos invalidados en la última hora por dependencias rotas en cascada ---
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
