-- =============================================================================
-- ALTA CONTROLADA DE 5 CIUDADES BCP FALTANTES - SRER-7088
--
-- Precondicion validada:
--   259 / 264 ciudades utilizadas por BARRIOS_BCP ya resueltas.
--   Quedan exactamente estas 5 sin match en BA_CIUDADES:
--
--     0114 - ITACUÁ                 - CONCEPCION  (COD_DEPTO 1)
--     0222 - SAN JOSÉ DEL ROSARIO   - SAN PEDRO   (COD_DEPTO 2)
--     1306 - CERRO CORÁ             - AMAMBAY     (COD_DEPTO 13)
--     1414 - MARACANÁ               - CANINDEYU   (COD_DEPTO 14)
--     1606 - BOQUERÓN               - BOQUERON    (COD_DEPTO 16)
--
-- Objetivo:
--   Dar de alta SOLO estas ciudades, que tienen barrios vigentes en
--   BARRIOS_BCP.csv, evitando el alta automatica indiscriminada desde
--   PRS_ACT_REF_CIUDADES.
--
-- IMPORTANTE:
--   - NO toca barrios.
--   - NO modifica ciudades existentes.
--   - NO hace COMMIT automatico.
--   - Utiliza el primer COD_CIUDAD libre entre 1 y 999 para COD_PAIS=1.
--   - Usa UNISTR para no depender del encoding con que se abra el SQL.
-- =============================================================================

SET SERVEROUTPUT ON;

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

DECLARE
  c_altas_esperadas CONSTANT PLS_INTEGER := 5;

  v_est_previo    IT.BA_MODULOS.ESTADO%TYPE;
  v_pre_refs      PLS_INTEGER;
  v_pre_nombres   PLS_INTEGER;
  v_insertadas    PLS_INTEGER := 0;
  v_post_refs     PLS_INTEGER;
  v_cod_ciudad    IT.BA_CIUDADES.COD_CIUDAD%TYPE;

BEGIN
  -- ---------------------------------------------------------------------------
  -- PRE-CHECK 1: ninguno de los 5 codigos BCP puede existir actualmente.
  -- ---------------------------------------------------------------------------
  SELECT COUNT(*)
    INTO v_pre_refs
    FROM IT.BA_CIUDADES
   WHERE COD_PAIS = 1
     AND REF_EXTERNA IN (114,222,1306,1414,1606);

  IF v_pre_refs != 0 THEN
    RAISE_APPLICATION_ERROR(
      -20231,
      'PRE-CHECK: ya existen ' || v_pre_refs ||
      ' referencias BCP del conjunto a insertar. Abortando.'
    );
  END IF;

  -- ---------------------------------------------------------------------------
  -- PRE-CHECK 2: no debe existir la misma ciudad en el mismo departamento.
  -- Se compara normalizando tildes.
  -- ---------------------------------------------------------------------------
  SELECT COUNT(*)
    INTO v_pre_nombres
    FROM IT.BA_CIUDADES c
   WHERE c.COD_PAIS = 1
     AND (
          (c.COD_DEPARTAMENTO = 1
           AND TRANSLATE(UPPER(TRIM(c.DESCRIPCION)),
                         'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                         'AEIOUAEIOUAEIOUAONU') = 'ITACUA')
       OR (c.COD_DEPARTAMENTO = 2
           AND TRANSLATE(UPPER(TRIM(c.DESCRIPCION)),
                         'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                         'AEIOUAEIOUAEIOUAONU') = 'SAN JOSE DEL ROSARIO')
       OR (c.COD_DEPARTAMENTO = 13
           AND TRANSLATE(UPPER(TRIM(c.DESCRIPCION)),
                         'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                         'AEIOUAEIOUAEIOUAONU') = 'CERRO CORA')
       OR (c.COD_DEPARTAMENTO = 14
           AND TRANSLATE(UPPER(TRIM(c.DESCRIPCION)),
                         'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                         'AEIOUAEIOUAEIOUAONU') = 'MARACANA')
       OR (c.COD_DEPARTAMENTO = 16
           AND TRANSLATE(UPPER(TRIM(c.DESCRIPCION)),
                         'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                         'AEIOUAEIOUAEIOUAONU') = 'BOQUERON')
         );

  IF v_pre_nombres != 0 THEN
    RAISE_APPLICATION_ERROR(
      -20232,
      'PRE-CHECK: existen ' || v_pre_nombres ||
      ' ciudades con mismo nombre/departamento. Abortando.'
    );
  END IF;

  -- Abrir modulo dentro de la misma transaccion.
  SELECT ESTADO
    INTO v_est_previo
    FROM IT.BA_MODULOS
   WHERE COD_MODULO = 1;

  IF v_est_previo != 2 THEN
    UPDATE IT.BA_MODULOS
       SET ESTADO = 2
     WHERE COD_MODULO = 1;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Insercion 1: ITACUÁ / BCP 114 / CONCEPCION
  -- ---------------------------------------------------------------------------
  SELECT MIN(n)
    INTO v_cod_ciudad
    FROM (SELECT ROWNUM n FROM DUAL CONNECT BY ROWNUM <= 999)
   WHERE n NOT IN (
         SELECT COD_CIUDAD FROM IT.BA_CIUDADES WHERE COD_PAIS = 1
       );

  IF v_cod_ciudad IS NULL THEN
    RAISE_APPLICATION_ERROR(-20233, 'Sin COD_CIUDAD libre entre 1 y 999.');
  END IF;

  INSERT INTO IT.BA_CIUDADES
    (COD_CIUDAD, DESCRIPCION, COD_PAIS, COD_DEPARTAMENTO,
     REF_EXTERNA, DES_BCO_CENTRAL)
  VALUES
    (v_cod_ciudad, UNISTR('ITACU\00C1'), 1, 1,
     114, UNISTR('ITACU\00C1'));

  DBMS_OUTPUT.PUT_LINE(
    '[ALTA] COD_BCP=114 | COD_CIUDAD=' || v_cod_ciudad || ' | ITACUA'
  );
  v_insertadas := v_insertadas + 1;

  -- ---------------------------------------------------------------------------
  -- Insercion 2: SAN JOSÉ DEL ROSARIO / BCP 222 / SAN PEDRO
  -- ---------------------------------------------------------------------------
  SELECT MIN(n)
    INTO v_cod_ciudad
    FROM (SELECT ROWNUM n FROM DUAL CONNECT BY ROWNUM <= 999)
   WHERE n NOT IN (
         SELECT COD_CIUDAD FROM IT.BA_CIUDADES WHERE COD_PAIS = 1
       );

  IF v_cod_ciudad IS NULL THEN
    RAISE_APPLICATION_ERROR(-20234, 'Sin COD_CIUDAD libre entre 1 y 999.');
  END IF;

  INSERT INTO IT.BA_CIUDADES
    (COD_CIUDAD, DESCRIPCION, COD_PAIS, COD_DEPARTAMENTO,
     REF_EXTERNA, DES_BCO_CENTRAL)
  VALUES
    (v_cod_ciudad, UNISTR('SAN JOS\00C9 DEL ROSARIO'), 1, 2,
     222, UNISTR('SAN JOS\00C9 DEL ROSARIO'));

  DBMS_OUTPUT.PUT_LINE(
    '[ALTA] COD_BCP=222 | COD_CIUDAD=' || v_cod_ciudad || ' | SAN JOSE DEL ROSARIO'
  );
  v_insertadas := v_insertadas + 1;

  -- ---------------------------------------------------------------------------
  -- Insercion 3: CERRO CORÁ / BCP 1306 / AMAMBAY
  -- ---------------------------------------------------------------------------
  SELECT MIN(n)
    INTO v_cod_ciudad
    FROM (SELECT ROWNUM n FROM DUAL CONNECT BY ROWNUM <= 999)
   WHERE n NOT IN (
         SELECT COD_CIUDAD FROM IT.BA_CIUDADES WHERE COD_PAIS = 1
       );

  IF v_cod_ciudad IS NULL THEN
    RAISE_APPLICATION_ERROR(-20235, 'Sin COD_CIUDAD libre entre 1 y 999.');
  END IF;

  INSERT INTO IT.BA_CIUDADES
    (COD_CIUDAD, DESCRIPCION, COD_PAIS, COD_DEPARTAMENTO,
     REF_EXTERNA, DES_BCO_CENTRAL)
  VALUES
    (v_cod_ciudad, UNISTR('CERRO COR\00C1'), 1, 13,
     1306, UNISTR('CERRO COR\00C1'));

  DBMS_OUTPUT.PUT_LINE(
    '[ALTA] COD_BCP=1306 | COD_CIUDAD=' || v_cod_ciudad || ' | CERRO CORA'
  );
  v_insertadas := v_insertadas + 1;

  -- ---------------------------------------------------------------------------
  -- Insercion 4: MARACANÁ / BCP 1414 / CANINDEYU
  -- ---------------------------------------------------------------------------
  SELECT MIN(n)
    INTO v_cod_ciudad
    FROM (SELECT ROWNUM n FROM DUAL CONNECT BY ROWNUM <= 999)
   WHERE n NOT IN (
         SELECT COD_CIUDAD FROM IT.BA_CIUDADES WHERE COD_PAIS = 1
       );

  IF v_cod_ciudad IS NULL THEN
    RAISE_APPLICATION_ERROR(-20236, 'Sin COD_CIUDAD libre entre 1 y 999.');
  END IF;

  INSERT INTO IT.BA_CIUDADES
    (COD_CIUDAD, DESCRIPCION, COD_PAIS, COD_DEPARTAMENTO,
     REF_EXTERNA, DES_BCO_CENTRAL)
  VALUES
    (v_cod_ciudad, UNISTR('MARACAN\00C1'), 1, 14,
     1414, UNISTR('MARACAN\00C1'));

  DBMS_OUTPUT.PUT_LINE(
    '[ALTA] COD_BCP=1414 | COD_CIUDAD=' || v_cod_ciudad || ' | MARACANA'
  );
  v_insertadas := v_insertadas + 1;

  -- ---------------------------------------------------------------------------
  -- Insercion 5: BOQUERÓN / BCP 1606 / BOQUERON
  -- ---------------------------------------------------------------------------
  SELECT MIN(n)
    INTO v_cod_ciudad
    FROM (SELECT ROWNUM n FROM DUAL CONNECT BY ROWNUM <= 999)
   WHERE n NOT IN (
         SELECT COD_CIUDAD FROM IT.BA_CIUDADES WHERE COD_PAIS = 1
       );

  IF v_cod_ciudad IS NULL THEN
    RAISE_APPLICATION_ERROR(-20237, 'Sin COD_CIUDAD libre entre 1 y 999.');
  END IF;

  INSERT INTO IT.BA_CIUDADES
    (COD_CIUDAD, DESCRIPCION, COD_PAIS, COD_DEPARTAMENTO,
     REF_EXTERNA, DES_BCO_CENTRAL)
  VALUES
    (v_cod_ciudad, UNISTR('BOQUER\00D3N'), 1, 16,
     1606, UNISTR('BOQUER\00D3N'));

  DBMS_OUTPUT.PUT_LINE(
    '[ALTA] COD_BCP=1606 | COD_CIUDAD=' || v_cod_ciudad || ' | BOQUERON'
  );
  v_insertadas := v_insertadas + 1;

  IF v_insertadas != c_altas_esperadas THEN
    RAISE_APPLICATION_ERROR(
      -20238,
      'Se esperaban insertar ' || c_altas_esperadas ||
      ' ciudades y se insertaron ' || v_insertadas || '. ROLLBACK.'
    );
  END IF;

  -- ---------------------------------------------------------------------------
  -- POST-CHECK:
  -- cada una de las 5 REF_EXTERNAs debe existir exactamente una vez.
  -- ---------------------------------------------------------------------------
  SELECT COUNT(*)
    INTO v_post_refs
    FROM (
      SELECT REF_EXTERNA
        FROM IT.BA_CIUDADES
       WHERE COD_PAIS = 1
         AND REF_EXTERNA IN (114,222,1306,1414,1606)
       GROUP BY REF_EXTERNA
      HAVING COUNT(*) = 1
    );

  IF v_post_refs != c_altas_esperadas THEN
    RAISE_APPLICATION_ERROR(
      -20239,
      'POST-CHECK: referencias univocas=' || v_post_refs ||
      ', esperado=' || c_altas_esperadas || '. ROLLBACK.'
    );
  END IF;

  IF v_est_previo != 2 THEN
    UPDATE IT.BA_MODULOS
       SET ESTADO = v_est_previo
     WHERE COD_MODULO = 1;
  END IF;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('[OK] Ciudades insertadas             : ' || v_insertadas);
  DBMS_OUTPUT.PUT_LINE('[OK] Referencias BCP univocas post  : ' || v_post_refs);
  DBMS_OUTPUT.PUT_LINE(
    'Transaccion pendiente. Ejecutar validacion 264/264 antes de COMMIT.'
  );

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    RAISE;
END;
/

-- =============================================================================
-- ANTES DE COMMIT:
--
-- 1) Ejecutar validacion_264_ciudades_BCP_post_proceso_v4.sql
--    Esperado:
--      OK_REF_UNICO = 264 ciudades / 7995 barrios
--      Sin detalle de inconsistencias.
--
-- 2) Confirmar total de ciudades:
--    SELECT COUNT(*) FROM IT.BA_CIUDADES;
--    Sobre el baseline actual deberia pasar de 8511 a 8516.
--
-- COMMIT;
-- ROLLBACK;
-- =============================================================================
