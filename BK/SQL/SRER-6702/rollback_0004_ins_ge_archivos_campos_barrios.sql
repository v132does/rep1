-- =============================================================================
-- Script  : rollback_0004_ins_ge_archivos_campos_barrios.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Revierte: 0004_ins_ge_archivos_campos_barrios.sql
-- =============================================================================

SET SERVEROUTPUT ON;

DECLARE
  v_cam  NUMBER;
  v_tab  NUMBER;
  v_arc  NUMBER;
  v_proc NUMBER;
  v_prog NUMBER;
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  -- Orden: hijos antes que padres (FK)
  DELETE FROM IT.GE_ARC_CAMPOS WHERE REFERENCIA = 'BCP_BARRIOS';
  v_cam := SQL%ROWCOUNT;

  DELETE FROM IT.GE_ARC_TABLAS WHERE REFERENCIA = 'BCP_BARRIOS';
  v_tab := SQL%ROWCOUNT;

  DELETE FROM IT.GE_ARCHIVOS WHERE REFERENCIA = 'BCP_BARRIOS';
  v_arc := SQL%ROWCOUNT;

  DELETE FROM IT.GE_PROCESOS WHERE DESCRIPCION = 'BCP_BARRIOS';
  v_proc := SQL%ROWCOUNT;

  DELETE FROM IT.BA_PROGRAMAS WHERE COD_PROGRAMA = 'PRS_ACT_REF_BARRIOS';
  v_prog := SQL%ROWCOUNT;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('GE_ARC_CAMPOS eliminados : ' || v_cam  || ' (esperado: 7)');
  DBMS_OUTPUT.PUT_LINE('GE_ARC_TABLAS eliminadas : ' || v_tab  || ' (esperado: 1)');
  DBMS_OUTPUT.PUT_LINE('GE_ARCHIVOS eliminados   : ' || v_arc  || ' (esperado: 1)');
  DBMS_OUTPUT.PUT_LINE('GE_PROCESOS eliminados   : ' || v_proc || ' (esperado: 1)');
  DBMS_OUTPUT.PUT_LINE('BA_PROGRAMAS eliminados  : ' || v_prog || ' (esperado: 1)');
END;
/

-- Verificacion: todas deben retornar 0
SELECT 'GE_ARC_CAMPOS'  AS tabla, COUNT(*) AS remanente FROM IT.GE_ARC_CAMPOS  WHERE REFERENCIA = 'BCP_BARRIOS'
UNION ALL
SELECT 'GE_ARC_TABLAS',          COUNT(*)               FROM IT.GE_ARC_TABLAS  WHERE REFERENCIA = 'BCP_BARRIOS'
UNION ALL
SELECT 'GE_ARCHIVOS',            COUNT(*)               FROM IT.GE_ARCHIVOS    WHERE REFERENCIA = 'BCP_BARRIOS'
UNION ALL
SELECT 'GE_PROCESOS',            COUNT(*)               FROM IT.GE_PROCESOS    WHERE DESCRIPCION = 'BCP_BARRIOS'
UNION ALL
SELECT 'BA_PROGRAMAS',           COUNT(*)               FROM IT.BA_PROGRAMAS   WHERE COD_PROGRAMA = 'PRS_ACT_REF_BARRIOS';
