-- =============================================================================
-- Script  : rollback_barrios_completo.sql
-- Ticket  : FIELDESK-164963 / Barrios BCP
-- Funcion : Rollback de configuracion y DDL del frente Barrios BCP.
--           Revierte todo lo creado/modificado por los scripts 0001 al 0005.
--
-- PREREQUISITO: Ejecutar PRIMERO restore_ba_barrios_from_bkp.sql
--               para revertir los datos de BA_BARRIOS antes de correr este script.
--
-- Orden de ejecucion:
--   PASO 1 - Config: eliminar setup de GE_ARCHIVOS, GE_ARC_TABLAS, GE_ARC_CAMPOS,
--                    GE_PROCESOS, BA_PROGRAMAS y dominio TIPO_ZONA_BARRIO
--   PASO 2 - DDL: drop SB_BCP_BAR_TMP, drop PRS_ACT_REF_BARRIOS,
--                 drop index IN_BARR_REF_EXTERNA,
--                 drop columnas nuevas de BA_BARRIOS,
--                 revertir descripcion a VARCHAR2(40)
--   PASO 3 - Comment: revertir COMMENT ON SB_CF_PRO_LOG
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ---------------------------------------------------------------------------
-- PASO 1: Eliminar configuracion del loader y post-proceso
-- ---------------------------------------------------------------------------
DECLARE
  v_cam NUMBER;
  v_tab NUMBER;
  v_arc NUMBER;
  v_proc NUMBER;
  v_prog NUMBER;
  v_zona NUMBER;
BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

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

  DELETE FROM IT.BA_COD_REFERENCIAS WHERE DOMINIO = 'TIPO_ZONA_BARRIO';
  v_zona := SQL%ROWCOUNT;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('[PASO 1] Config eliminada.');
  DBMS_OUTPUT.PUT_LINE('  GE_ARC_CAMPOS : ' || v_cam  || ' filas');
  DBMS_OUTPUT.PUT_LINE('  GE_ARC_TABLAS : ' || v_tab  || ' filas');
  DBMS_OUTPUT.PUT_LINE('  GE_ARCHIVOS   : ' || v_arc  || ' filas');
  DBMS_OUTPUT.PUT_LINE('  GE_PROCESOS   : ' || v_proc || ' filas');
  DBMS_OUTPUT.PUT_LINE('  BA_PROGRAMAS  : ' || v_prog || ' filas');
  DBMS_OUTPUT.PUT_LINE('  BA_COD_REF (TIPO_ZONA_BARRIO): ' || v_zona || ' filas');
END;
/

-- ---------------------------------------------------------------------------
-- PASO 2: Eliminar objetos DDL creados
-- ---------------------------------------------------------------------------

-- Drop staging (el DROP TABLE revoca automaticamente los GRANTs)
DROP PUBLIC SYNONYM SB_BCP_BAR_TMP;
DROP TABLE IT.SB_BCP_BAR_TMP PURGE;

-- Drop procedimiento
DROP PROCEDURE IT.PRS_ACT_REF_BARRIOS;

-- Drop index creado en 0001
DROP INDEX IT.IN_BARR_REF_EXTERNA;

-- Drop columnas nuevas de BA_BARRIOS
ALTER TABLE IT.BA_BARRIOS
  DROP (ref_externa, des_bco_central, cod_tipo_zona);

-- Revertir descripcion de VARCHAR2(60) a VARCHAR2(40)
-- PRECAUCION: falla si alguna descripcion supera 40 chars.
-- Si BA_BARRIOS fue restaurada en PASO 1 desde el BKP (que tenia VARCHAR2(40)),
-- todas las descripciones existentes son <= 40 chars y este MODIFY es seguro.
ALTER TABLE IT.BA_BARRIOS
  MODIFY (descripcion VARCHAR2(40));

PROMPT [PASO 2] Objetos DDL eliminados y BA_BARRIOS revertida a estructura original.

-- ---------------------------------------------------------------------------
-- PASO 3: Revertir COMMENT ON SB_CF_PRO_LOG (quitar ACT_BARRIOS)
-- ---------------------------------------------------------------------------
COMMENT ON TABLE IT.SB_CF_PRO_LOG IS
  'Log de ejecuciones BCP: CF_ALTA (Circ. SB.SG 00586/2010), CAR_PERSONAS (PRS_CAR_PERSONAS_REF), ACT_CIUDADES (PRS_ACT_REF_CIUDADES)';

PROMPT [PASO 3] Comment de SB_CF_PRO_LOG revertido.

-- ---------------------------------------------------------------------------
-- Verificacion final
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS ba_barrios_final FROM IT.BA_BARRIOS;

-- Drop BKP (descomentar cuando confirmes que el rollback es correcto)
-- DROP TABLE IT.BA_BARRIOS_BKP_GP PURGE;

PROMPT === ROLLBACK COMPLETO FINALIZADO ===
