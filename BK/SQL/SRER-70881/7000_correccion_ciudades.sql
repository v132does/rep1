-- =============================================================================
-- Script  : 7000_correccion_ciudades.sql
-- Ticket  : SRER-7088
-- Objeto  : IT.BA_CIUDADES, IT.BA_DIRECCIONES
--
-- Saneamiento del incidente de importacion del 14/08/2026.
-- El script admite dos estados:
--   A) PRE: 124 ciudades corruptas + 9 altas no deseadas -> ejecuta correccion.
--   B) POST: correccion ya aplicada -> no realiza DML y finaliza OK.
-- Cualquier estado parcial/diferente aborta.
-- =============================================================================

SET SERVEROUTPUT ON;

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

DECLARE
  c_p1_ciudades_esperadas CONSTANT PLS_INTEGER := 124;
  c_p2_ciudades_esperadas CONSTANT PLS_INTEGER := 9;

  v_p1_ciudades   PLS_INTEGER;
  v_p1_barrios    PLS_INTEGER;
  v_p1_dirs       PLS_INTEGER;
  v_p1_dir1_old   PLS_INTEGER;
  v_p1_dir2_old   PLS_INTEGER;
  v_p1_dir1_new   PLS_INTEGER;
  v_p1_dir2_new   PLS_INTEGER;

  v_p2_ciudades   PLS_INTEGER;
  v_p2_dirs       PLS_INTEGER;
  v_p2_barrios    PLS_INTEGER;

  v_est_previo    IT.BA_MODULOS.ESTADO%TYPE;
  v_rows          PLS_INTEGER;

BEGIN
  SELECT COUNT(*)
    INTO v_p1_ciudades
    FROM IT.BA_CIUDADES
   WHERE FEC_INSERCION >= DATE '2026-08-14'
     AND FEC_INSERCION <  DATE '2026-08-15'
     AND INSTR(ASCIISTR(DESCRIPCION), '\00BF') > 0;

  SELECT COUNT(*)
    INTO v_p1_barrios
    FROM IT.BA_BARRIOS b
   WHERE EXISTS (
         SELECT 1
           FROM IT.BA_CIUDADES c
          WHERE c.COD_PAIS   = b.COD_PAIS
            AND c.COD_CIUDAD = b.COD_CIUDAD
            AND c.FEC_INSERCION >= DATE '2026-08-14'
            AND c.FEC_INSERCION <  DATE '2026-08-15'
            AND INSTR(ASCIISTR(c.DESCRIPCION), '\00BF') > 0
       );

  SELECT COUNT(*)
    INTO v_p1_dirs
    FROM IT.BA_DIRECCIONES d
    JOIN IT.BA_CIUDADES c
      ON c.COD_PAIS = d.COD_PAIS
     AND c.COD_CIUDAD = d.COD_CIUDAD
   WHERE c.FEC_INSERCION >= DATE '2026-08-14'
     AND c.FEC_INSERCION <  DATE '2026-08-15'
     AND INSTR(ASCIISTR(c.DESCRIPCION), '\00BF') > 0;

  SELECT COUNT(*) INTO v_p1_dir1_old
    FROM IT.BA_DIRECCIONES
   WHERE COD_PERSONA = 19992463
     AND COD_DIRECCION = 1
     AND COD_PAIS = 1
     AND COD_CIUDAD = 316;

  SELECT COUNT(*) INTO v_p1_dir2_old
    FROM IT.BA_DIRECCIONES
   WHERE COD_PERSONA = 8666853
     AND COD_DIRECCION = 3
     AND COD_PAIS = 1
     AND COD_CIUDAD = 341;

  SELECT COUNT(*) INTO v_p1_dir1_new
    FROM IT.BA_DIRECCIONES
   WHERE COD_PERSONA = 19992463
     AND COD_DIRECCION = 1
     AND COD_PAIS = 1
     AND COD_CIUDAD = 1;

  SELECT COUNT(*) INTO v_p1_dir2_new
    FROM IT.BA_DIRECCIONES
   WHERE COD_PERSONA = 8666853
     AND COD_DIRECCION = 3
     AND COD_PAIS = 1
     AND COD_CIUDAD = 115;

  SELECT COUNT(*)
    INTO v_p2_ciudades
    FROM IT.BA_CIUDADES c
   WHERE c.COD_PAIS = 1
     AND c.FEC_INSERCION >= DATE '2026-08-14'
     AND c.FEC_INSERCION <  DATE '2026-08-15'
     AND c.REF_EXTERNA IN (115,116,118,119,120,121,1023,1607,1706);

  SELECT COUNT(*)
    INTO v_p2_dirs
    FROM IT.BA_DIRECCIONES d
    JOIN IT.BA_CIUDADES c
      ON c.COD_PAIS = d.COD_PAIS
     AND c.COD_CIUDAD = d.COD_CIUDAD
   WHERE c.COD_PAIS = 1
     AND c.FEC_INSERCION >= DATE '2026-08-14'
     AND c.FEC_INSERCION <  DATE '2026-08-15'
     AND c.REF_EXTERNA IN (115,116,118,119,120,121,1023,1607,1706);

  SELECT COUNT(*)
    INTO v_p2_barrios
    FROM IT.BA_BARRIOS b
    JOIN IT.BA_CIUDADES c
      ON c.COD_PAIS = b.COD_PAIS
     AND c.COD_CIUDAD = b.COD_CIUDAD
   WHERE c.COD_PAIS = 1
     AND c.FEC_INSERCION >= DATE '2026-08-14'
     AND c.FEC_INSERCION <  DATE '2026-08-15'
     AND c.REF_EXTERNA IN (115,116,118,119,120,121,1023,1607,1706);

  DBMS_OUTPUT.PUT_LINE('[PRE] Corruptas       : ' || v_p1_ciudades);
  DBMS_OUTPUT.PUT_LINE('[PRE] Barrios hijos   : ' || v_p1_barrios);
  DBMS_OUTPUT.PUT_LINE('[PRE] Direcciones old : ' || v_p1_dirs);
  DBMS_OUTPUT.PUT_LINE('[PRE] Altas no deseadas: ' || v_p2_ciudades);

  -- Ya aplicado: estado validado luego del saneamiento.
  IF v_p1_ciudades = 0
     AND v_p2_ciudades = 0
     AND v_p1_dir1_old = 0
     AND v_p1_dir2_old = 0
     AND v_p1_dir1_new = 1
     AND v_p1_dir2_new = 1 THEN
    DBMS_OUTPUT.PUT_LINE('[OK] Correccion ya aplicada previamente. Sin DML.');
    RETURN;
  END IF;

  -- Estado PRE exacto.
  IF v_p1_ciudades <> c_p1_ciudades_esperadas
     OR v_p1_barrios <> 0
     OR v_p1_dirs <> 2
     OR v_p1_dir1_old <> 1
     OR v_p1_dir2_old <> 1
     OR v_p2_ciudades <> c_p2_ciudades_esperadas
     OR v_p2_dirs <> 0
     OR v_p2_barrios <> 0 THEN
    RAISE_APPLICATION_ERROR(
      -20001,
      'Estado de datos distinto al PRE o POST esperado. Abortando saneamiento.'
    );
  END IF;

  SELECT ESTADO
    INTO v_est_previo
    FROM IT.BA_MODULOS
   WHERE COD_MODULO = 1;

  IF v_est_previo <> 2 THEN
    UPDATE IT.BA_MODULOS SET ESTADO = 2 WHERE COD_MODULO = 1;
  END IF;

  UPDATE IT.BA_DIRECCIONES
     SET COD_CIUDAD = 1
   WHERE COD_PERSONA = 19992463
     AND COD_DIRECCION = 1
     AND COD_PAIS = 1
     AND COD_CIUDAD = 316;
  IF SQL%ROWCOUNT <> 1 THEN
    RAISE_APPLICATION_ERROR(-20002, 'Direccion 19992463: cantidad inesperada.');
  END IF;

  UPDATE IT.BA_DIRECCIONES
     SET COD_CIUDAD = 115
   WHERE COD_PERSONA = 8666853
     AND COD_DIRECCION = 3
     AND COD_PAIS = 1
     AND COD_CIUDAD = 341;
  IF SQL%ROWCOUNT <> 1 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Direccion 8666853: cantidad inesperada.');
  END IF;

  DELETE FROM IT.BA_CIUDADES
   WHERE FEC_INSERCION >= DATE '2026-08-14'
     AND FEC_INSERCION <  DATE '2026-08-15'
     AND INSTR(ASCIISTR(DESCRIPCION), '\00BF') > 0;
  IF SQL%ROWCOUNT <> c_p1_ciudades_esperadas THEN
    RAISE_APPLICATION_ERROR(-20004, 'Cantidad inesperada de corruptas eliminadas.');
  END IF;

  DELETE FROM IT.BA_CIUDADES c
   WHERE c.COD_PAIS = 1
     AND c.FEC_INSERCION >= DATE '2026-08-14'
     AND c.FEC_INSERCION <  DATE '2026-08-15'
     AND c.REF_EXTERNA IN (115,116,118,119,120,121,1023,1607,1706);
  IF SQL%ROWCOUNT <> c_p2_ciudades_esperadas THEN
    RAISE_APPLICATION_ERROR(-20005, 'Cantidad inesperada de altas eliminadas.');
  END IF;

  IF v_est_previo <> 2 THEN
    UPDATE IT.BA_MODULOS SET ESTADO = v_est_previo WHERE COD_MODULO = 1;
  END IF;

  DBMS_OUTPUT.PUT_LINE('[OK] Direcciones corregidas        : 2');
  DBMS_OUTPUT.PUT_LINE('[OK] Ciudades corruptas eliminadas: 124');
  DBMS_OUTPUT.PUT_LINE('[OK] Altas no deseadas eliminadas : 9');
  DBMS_OUTPUT.PUT_LINE('Transaccion pendiente. Ejecutar COMMIT para confirmar.');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    RAISE;
END;
/
