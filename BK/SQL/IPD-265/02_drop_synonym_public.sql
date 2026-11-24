-- =====================================================
-- DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS - FUNCIONES DE MIGRACIÓN
-- =====================================================
-- Genera los DROP PUBLIC SYNONYM para las 2 funciones de migración
-- del schema IT que serán eliminadas en el paso 04.
-- Prerequisito: 01_backup_expdp.sql completado.
-- =====================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET ECHO ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT =====================================================
PROMPT DBA FASE 2: BORRADO DE SINÓNIMOS PÚBLICOS - FUNCIONES DE MIGRACIÓN IT
PROMPT Fecha de ejecución:
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =====================================================

PROMPT
PROMPT --- Generando sentencias DROP PUBLIC SYNONYM para funciones de migración ---

SELECT 'DROP PUBLIC SYNONYM ' || object_name || ';'
FROM   dba_objects
WHERE  owner       = 'IT'
  AND  object_name IN (
    'FUG_OBT_HOR_DIS_MIGRADO',
    'FUG_OBT_USU_MIGRADO'
  )
ORDER BY object_name;
