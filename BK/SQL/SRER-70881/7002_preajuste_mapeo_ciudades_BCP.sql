-- =============================================================================
-- PREAJUSTE DE CIUDADES BCP - SRER-7088
-- Ambiente inicial validado:
--   BA_CIUDADES = 8511
--   BA_BARRIOS  = 10979
--
-- Objetivo:
--   Vincular de forma explicita ciudades Bankitti existentes cuyo nombre difiere
--   del catalogo BCP, y resolver tres casos ambiguos analizados con datos reales.
--
-- IMPORTANTE:
--   - NO inserta ciudades.
--   - NO borra ciudades.
--   - NO modifica barrios.
--   - NO cambia DESCRIPCION Bankitti.
--   - Solo asigna REF_EXTERNA.
--   - DES_BCO_CENTRAL se sincronizara luego al ejecutar PRS_ACT_REF_CIUDADES.
--   - El caso COD_BCP 212 elimina previamente la REF duplicada de COD_CIUDAD 825.
--   - No hace COMMIT automatico.
-- =============================================================================

SET SERVEROUTPUT ON;

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;
  COMMIT;
END;
/

DECLARE
  c_mapeos_esperados CONSTANT PLS_INTEGER := 19;

  v_targets          PLS_INTEGER;
  v_conflictos       PLS_INTEGER;
  v_actualizados     PLS_INTEGER := 0;
  v_limpiado_825     PLS_INTEGER := 0;
  v_post_ok          PLS_INTEGER;
  v_post_duplicadas  PLS_INTEGER;
  v_est_previo       IT.BA_MODULOS.ESTADO%TYPE;

BEGIN
  -- ---------------------------------------------------------------------------
  -- PRE-CHECK 1: deben existir exactamente los 19 COD_CIUDAD esperados,
  -- con pais, departamento y descripcion Bankitti esperados.
  -- ---------------------------------------------------------------------------
  WITH m AS (
SELECT 1022 cod_bcp, 93 cod_ciudad, 'RAUL PEÑA' descripcion_esperada, 10 cod_dpto FROM dual
UNION ALL
SELECT 1302 cod_bcp, 227 cod_ciudad, 'BELLA VISTA NORTE' descripcion_esperada, 13 cod_dpto FROM dual
UNION ALL
SELECT 1602 cod_bcp, 240 cod_ciudad, 'MARISCAL ESTIGARRIBIA' descripcion_esperada, 16 cod_dpto FROM dual
UNION ALL
SELECT 515 cod_bcp, 161 cod_ciudad, 'JOSE DOMINGO OCAMPO' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 604 cod_bcp, 172 cod_ciudad, 'DOCTOR MOISES BERTONI' descripcion_esperada, 6 cod_dpto FROM dual
UNION ALL
SELECT 1409 cod_bcp, 105 cod_ciudad, 'LA PALOMA' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 1411 cod_bcp, 233 cod_ciudad, 'YACY CAÑY' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 107 cod_bcp, 114 cod_ciudad, 'YBY YA''U' descripcion_esperada, 1 cod_dpto FROM dual
UNION ALL
SELECT 403 cod_bcp, 47 cod_ciudad, 'MAURICIO JOSE TROCHE' descripcion_esperada, 4 cod_dpto FROM dual
UNION ALL
SELECT 718 cod_bcp, 178 cod_ciudad, 'MAYOR JULIO DOMINGO OTAÑO' descripcion_esperada, 7 cod_dpto FROM dual
UNION ALL
SELECT 1205 cod_bcp, 64 cod_ciudad, 'GRAL. JOSE E. DIAZ' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 1206 cod_bcp, 217 cod_ciudad, 'GUAZU CUA' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 918 cod_bcp, 89 cod_ciudad, 'COLONIA MARIA ANTONIA' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 914 cod_bcp, 200 cod_ciudad, 'TEBICUARYMI' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 1507 cod_bcp, 295 cod_ciudad, 'TENIENTE IRALA FERNANDEZ' descripcion_esperada, 15 cod_dpto FROM dual
UNION ALL
SELECT 214 cod_bcp, 124 cod_ciudad, 'GRAL FRANCISCO ISIDORO RESQUIN' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 212 cod_bcp, 121 cod_ciudad, '25 DE DICIEMBRE' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 521 cod_bcp, 312 cod_ciudad, 'TEMBIAPORA' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 1210 cod_bcp, 221 cod_ciudad, 'MAYOR DE JESUS MARTINEZ' descripcion_esperada, 12 cod_dpto FROM dual
  )
  SELECT COUNT(*)
    INTO v_targets
    FROM m
    JOIN IT.BA_CIUDADES c
      ON c.COD_PAIS          = 1
     AND c.COD_CIUDAD        = m.COD_CIUDAD
     AND c.COD_DEPARTAMENTO  = m.COD_DPTO
     AND UPPER(TRIM(c.DESCRIPCION)) = UPPER(TRIM(m.DESCRIPCION_ESPERADA));

  IF v_targets != c_mapeos_esperados THEN
    RAISE_APPLICATION_ERROR(
      -20221,
      'PRE-CHECK: se esperaban ' || c_mapeos_esperados ||
      ' ciudades target y coinciden ' || v_targets || '. Abortando.'
    );
  END IF;

  -- ---------------------------------------------------------------------------
  -- PRE-CHECK 2:
  -- Ningun codigo BCP a asignar puede estar vinculado a otra ciudad,
  -- salvo COD_BCP 212, cuya duplicidad conocida es 121/825 y se sanea abajo.
  -- ---------------------------------------------------------------------------
  WITH m AS (
SELECT 1022 cod_bcp, 93 cod_ciudad, 'RAUL PEÑA' descripcion_esperada, 10 cod_dpto FROM dual
UNION ALL
SELECT 1302 cod_bcp, 227 cod_ciudad, 'BELLA VISTA NORTE' descripcion_esperada, 13 cod_dpto FROM dual
UNION ALL
SELECT 1602 cod_bcp, 240 cod_ciudad, 'MARISCAL ESTIGARRIBIA' descripcion_esperada, 16 cod_dpto FROM dual
UNION ALL
SELECT 515 cod_bcp, 161 cod_ciudad, 'JOSE DOMINGO OCAMPO' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 604 cod_bcp, 172 cod_ciudad, 'DOCTOR MOISES BERTONI' descripcion_esperada, 6 cod_dpto FROM dual
UNION ALL
SELECT 1409 cod_bcp, 105 cod_ciudad, 'LA PALOMA' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 1411 cod_bcp, 233 cod_ciudad, 'YACY CAÑY' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 107 cod_bcp, 114 cod_ciudad, 'YBY YA''U' descripcion_esperada, 1 cod_dpto FROM dual
UNION ALL
SELECT 403 cod_bcp, 47 cod_ciudad, 'MAURICIO JOSE TROCHE' descripcion_esperada, 4 cod_dpto FROM dual
UNION ALL
SELECT 718 cod_bcp, 178 cod_ciudad, 'MAYOR JULIO DOMINGO OTAÑO' descripcion_esperada, 7 cod_dpto FROM dual
UNION ALL
SELECT 1205 cod_bcp, 64 cod_ciudad, 'GRAL. JOSE E. DIAZ' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 1206 cod_bcp, 217 cod_ciudad, 'GUAZU CUA' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 918 cod_bcp, 89 cod_ciudad, 'COLONIA MARIA ANTONIA' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 914 cod_bcp, 200 cod_ciudad, 'TEBICUARYMI' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 1507 cod_bcp, 295 cod_ciudad, 'TENIENTE IRALA FERNANDEZ' descripcion_esperada, 15 cod_dpto FROM dual
UNION ALL
SELECT 214 cod_bcp, 124 cod_ciudad, 'GRAL FRANCISCO ISIDORO RESQUIN' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 212 cod_bcp, 121 cod_ciudad, '25 DE DICIEMBRE' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 521 cod_bcp, 312 cod_ciudad, 'TEMBIAPORA' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 1210 cod_bcp, 221 cod_ciudad, 'MAYOR DE JESUS MARTINEZ' descripcion_esperada, 12 cod_dpto FROM dual
  )
  SELECT COUNT(*)
    INTO v_conflictos
    FROM IT.BA_CIUDADES c
    JOIN m
      ON m.COD_BCP = c.REF_EXTERNA
   WHERE c.COD_PAIS = 1
     AND c.COD_CIUDAD <> m.COD_CIUDAD
     AND NOT (m.COD_BCP = 212 AND c.COD_CIUDAD = 825);

  IF v_conflictos != 0 THEN
    RAISE_APPLICATION_ERROR(
      -20222,
      'PRE-CHECK: existen ' || v_conflictos ||
      ' referencias BCP vinculadas a una ciudad distinta de la esperada. Abortando.'
    );
  END IF;

  -- ---------------------------------------------------------------------------
  -- PRE-CHECK 3:
  -- El target no puede tener actualmente otra REF_EXTERNA distinta.
  -- ---------------------------------------------------------------------------
  WITH m AS (
SELECT 1022 cod_bcp, 93 cod_ciudad, 'RAUL PEÑA' descripcion_esperada, 10 cod_dpto FROM dual
UNION ALL
SELECT 1302 cod_bcp, 227 cod_ciudad, 'BELLA VISTA NORTE' descripcion_esperada, 13 cod_dpto FROM dual
UNION ALL
SELECT 1602 cod_bcp, 240 cod_ciudad, 'MARISCAL ESTIGARRIBIA' descripcion_esperada, 16 cod_dpto FROM dual
UNION ALL
SELECT 515 cod_bcp, 161 cod_ciudad, 'JOSE DOMINGO OCAMPO' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 604 cod_bcp, 172 cod_ciudad, 'DOCTOR MOISES BERTONI' descripcion_esperada, 6 cod_dpto FROM dual
UNION ALL
SELECT 1409 cod_bcp, 105 cod_ciudad, 'LA PALOMA' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 1411 cod_bcp, 233 cod_ciudad, 'YACY CAÑY' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 107 cod_bcp, 114 cod_ciudad, 'YBY YA''U' descripcion_esperada, 1 cod_dpto FROM dual
UNION ALL
SELECT 403 cod_bcp, 47 cod_ciudad, 'MAURICIO JOSE TROCHE' descripcion_esperada, 4 cod_dpto FROM dual
UNION ALL
SELECT 718 cod_bcp, 178 cod_ciudad, 'MAYOR JULIO DOMINGO OTAÑO' descripcion_esperada, 7 cod_dpto FROM dual
UNION ALL
SELECT 1205 cod_bcp, 64 cod_ciudad, 'GRAL. JOSE E. DIAZ' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 1206 cod_bcp, 217 cod_ciudad, 'GUAZU CUA' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 918 cod_bcp, 89 cod_ciudad, 'COLONIA MARIA ANTONIA' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 914 cod_bcp, 200 cod_ciudad, 'TEBICUARYMI' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 1507 cod_bcp, 295 cod_ciudad, 'TENIENTE IRALA FERNANDEZ' descripcion_esperada, 15 cod_dpto FROM dual
UNION ALL
SELECT 214 cod_bcp, 124 cod_ciudad, 'GRAL FRANCISCO ISIDORO RESQUIN' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 212 cod_bcp, 121 cod_ciudad, '25 DE DICIEMBRE' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 521 cod_bcp, 312 cod_ciudad, 'TEMBIAPORA' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 1210 cod_bcp, 221 cod_ciudad, 'MAYOR DE JESUS MARTINEZ' descripcion_esperada, 12 cod_dpto FROM dual
  )
  SELECT COUNT(*)
    INTO v_conflictos
    FROM IT.BA_CIUDADES c
    JOIN m
      ON m.COD_CIUDAD = c.COD_CIUDAD
   WHERE c.COD_PAIS = 1
     AND c.REF_EXTERNA IS NOT NULL
     AND c.REF_EXTERNA <> m.COD_BCP;

  IF v_conflictos != 0 THEN
    RAISE_APPLICATION_ERROR(
      -20223,
      'PRE-CHECK: ' || v_conflictos ||
      ' ciudades target ya tienen una REF_EXTERNA diferente. Abortando.'
    );
  END IF;

  -- Abrir modulo en la misma transaccion.
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
  -- Caso especial 25 DE DICIEMBRE:
  -- COD_CIUDAD 121 es el registro productivo/canonico.
  -- COD_CIUDAD 825 conserva la ciudad pero queda sin referencia BCP.
  -- ---------------------------------------------------------------------------
  UPDATE IT.BA_CIUDADES
     SET REF_EXTERNA     = NULL,
         DES_BCO_CENTRAL = NULL
   WHERE COD_PAIS   = 1
     AND COD_CIUDAD = 825
     AND REF_EXTERNA = 212;

  v_limpiado_825 := SQL%ROWCOUNT;

  IF v_limpiado_825 != 1 THEN
    RAISE_APPLICATION_ERROR(
      -20224,
      'Se esperaba limpiar REF_EXTERNA=212 en COD_CIUDAD=825 y se afectaron ' ||
      v_limpiado_825 || ' filas. ROLLBACK.'
    );
  END IF;

  -- ---------------------------------------------------------------------------
  -- Aplicar los 19 mappings explicitos.
  -- ---------------------------------------------------------------------------
  MERGE INTO IT.BA_CIUDADES c
  USING (
SELECT 1022 cod_bcp, 93 cod_ciudad, 'RAUL PEÑA' descripcion_esperada, 10 cod_dpto FROM dual
UNION ALL
SELECT 1302 cod_bcp, 227 cod_ciudad, 'BELLA VISTA NORTE' descripcion_esperada, 13 cod_dpto FROM dual
UNION ALL
SELECT 1602 cod_bcp, 240 cod_ciudad, 'MARISCAL ESTIGARRIBIA' descripcion_esperada, 16 cod_dpto FROM dual
UNION ALL
SELECT 515 cod_bcp, 161 cod_ciudad, 'JOSE DOMINGO OCAMPO' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 604 cod_bcp, 172 cod_ciudad, 'DOCTOR MOISES BERTONI' descripcion_esperada, 6 cod_dpto FROM dual
UNION ALL
SELECT 1409 cod_bcp, 105 cod_ciudad, 'LA PALOMA' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 1411 cod_bcp, 233 cod_ciudad, 'YACY CAÑY' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 107 cod_bcp, 114 cod_ciudad, 'YBY YA''U' descripcion_esperada, 1 cod_dpto FROM dual
UNION ALL
SELECT 403 cod_bcp, 47 cod_ciudad, 'MAURICIO JOSE TROCHE' descripcion_esperada, 4 cod_dpto FROM dual
UNION ALL
SELECT 718 cod_bcp, 178 cod_ciudad, 'MAYOR JULIO DOMINGO OTAÑO' descripcion_esperada, 7 cod_dpto FROM dual
UNION ALL
SELECT 1205 cod_bcp, 64 cod_ciudad, 'GRAL. JOSE E. DIAZ' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 1206 cod_bcp, 217 cod_ciudad, 'GUAZU CUA' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 918 cod_bcp, 89 cod_ciudad, 'COLONIA MARIA ANTONIA' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 914 cod_bcp, 200 cod_ciudad, 'TEBICUARYMI' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 1507 cod_bcp, 295 cod_ciudad, 'TENIENTE IRALA FERNANDEZ' descripcion_esperada, 15 cod_dpto FROM dual
UNION ALL
SELECT 214 cod_bcp, 124 cod_ciudad, 'GRAL FRANCISCO ISIDORO RESQUIN' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 212 cod_bcp, 121 cod_ciudad, '25 DE DICIEMBRE' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 521 cod_bcp, 312 cod_ciudad, 'TEMBIAPORA' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 1210 cod_bcp, 221 cod_ciudad, 'MAYOR DE JESUS MARTINEZ' descripcion_esperada, 12 cod_dpto FROM dual
  ) m
     ON (c.COD_PAIS = 1 AND c.COD_CIUDAD = m.COD_CIUDAD)
  WHEN MATCHED THEN
    UPDATE SET c.REF_EXTERNA = m.COD_BCP;

  v_actualizados := SQL%ROWCOUNT;

  IF v_actualizados != c_mapeos_esperados THEN
    RAISE_APPLICATION_ERROR(
      -20225,
      'Se esperaban actualizar ' || c_mapeos_esperados ||
      ' ciudades y se actualizaron ' || v_actualizados || '. ROLLBACK.'
    );
  END IF;

  -- ---------------------------------------------------------------------------
  -- POST-CHECK: los 19 codigos BCP deben quedar vinculados exactamente
  -- una vez y al COD_CIUDAD esperado.
  -- ---------------------------------------------------------------------------
  WITH m AS (
SELECT 1022 cod_bcp, 93 cod_ciudad, 'RAUL PEÑA' descripcion_esperada, 10 cod_dpto FROM dual
UNION ALL
SELECT 1302 cod_bcp, 227 cod_ciudad, 'BELLA VISTA NORTE' descripcion_esperada, 13 cod_dpto FROM dual
UNION ALL
SELECT 1602 cod_bcp, 240 cod_ciudad, 'MARISCAL ESTIGARRIBIA' descripcion_esperada, 16 cod_dpto FROM dual
UNION ALL
SELECT 515 cod_bcp, 161 cod_ciudad, 'JOSE DOMINGO OCAMPO' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 604 cod_bcp, 172 cod_ciudad, 'DOCTOR MOISES BERTONI' descripcion_esperada, 6 cod_dpto FROM dual
UNION ALL
SELECT 1409 cod_bcp, 105 cod_ciudad, 'LA PALOMA' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 1411 cod_bcp, 233 cod_ciudad, 'YACY CAÑY' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 107 cod_bcp, 114 cod_ciudad, 'YBY YA''U' descripcion_esperada, 1 cod_dpto FROM dual
UNION ALL
SELECT 403 cod_bcp, 47 cod_ciudad, 'MAURICIO JOSE TROCHE' descripcion_esperada, 4 cod_dpto FROM dual
UNION ALL
SELECT 718 cod_bcp, 178 cod_ciudad, 'MAYOR JULIO DOMINGO OTAÑO' descripcion_esperada, 7 cod_dpto FROM dual
UNION ALL
SELECT 1205 cod_bcp, 64 cod_ciudad, 'GRAL. JOSE E. DIAZ' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 1206 cod_bcp, 217 cod_ciudad, 'GUAZU CUA' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 918 cod_bcp, 89 cod_ciudad, 'COLONIA MARIA ANTONIA' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 914 cod_bcp, 200 cod_ciudad, 'TEBICUARYMI' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 1507 cod_bcp, 295 cod_ciudad, 'TENIENTE IRALA FERNANDEZ' descripcion_esperada, 15 cod_dpto FROM dual
UNION ALL
SELECT 214 cod_bcp, 124 cod_ciudad, 'GRAL FRANCISCO ISIDORO RESQUIN' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 212 cod_bcp, 121 cod_ciudad, '25 DE DICIEMBRE' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 521 cod_bcp, 312 cod_ciudad, 'TEMBIAPORA' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 1210 cod_bcp, 221 cod_ciudad, 'MAYOR DE JESUS MARTINEZ' descripcion_esperada, 12 cod_dpto FROM dual
  )
  SELECT COUNT(*)
    INTO v_post_ok
    FROM m
   WHERE EXISTS (
         SELECT 1
           FROM IT.BA_CIUDADES c
          WHERE c.COD_PAIS    = 1
            AND c.COD_CIUDAD  = m.COD_CIUDAD
            AND c.REF_EXTERNA = m.COD_BCP
       );

  IF v_post_ok != c_mapeos_esperados THEN
    RAISE_APPLICATION_ERROR(
      -20226,
      'POST-CHECK: quedaron correctamente mapeadas ' || v_post_ok ||
      ' de ' || c_mapeos_esperados || '. ROLLBACK.'
    );
  END IF;

  WITH m AS (
SELECT 1022 cod_bcp, 93 cod_ciudad, 'RAUL PEÑA' descripcion_esperada, 10 cod_dpto FROM dual
UNION ALL
SELECT 1302 cod_bcp, 227 cod_ciudad, 'BELLA VISTA NORTE' descripcion_esperada, 13 cod_dpto FROM dual
UNION ALL
SELECT 1602 cod_bcp, 240 cod_ciudad, 'MARISCAL ESTIGARRIBIA' descripcion_esperada, 16 cod_dpto FROM dual
UNION ALL
SELECT 515 cod_bcp, 161 cod_ciudad, 'JOSE DOMINGO OCAMPO' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 604 cod_bcp, 172 cod_ciudad, 'DOCTOR MOISES BERTONI' descripcion_esperada, 6 cod_dpto FROM dual
UNION ALL
SELECT 1409 cod_bcp, 105 cod_ciudad, 'LA PALOMA' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 1411 cod_bcp, 233 cod_ciudad, 'YACY CAÑY' descripcion_esperada, 14 cod_dpto FROM dual
UNION ALL
SELECT 107 cod_bcp, 114 cod_ciudad, 'YBY YA''U' descripcion_esperada, 1 cod_dpto FROM dual
UNION ALL
SELECT 403 cod_bcp, 47 cod_ciudad, 'MAURICIO JOSE TROCHE' descripcion_esperada, 4 cod_dpto FROM dual
UNION ALL
SELECT 718 cod_bcp, 178 cod_ciudad, 'MAYOR JULIO DOMINGO OTAÑO' descripcion_esperada, 7 cod_dpto FROM dual
UNION ALL
SELECT 1205 cod_bcp, 64 cod_ciudad, 'GRAL. JOSE E. DIAZ' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 1206 cod_bcp, 217 cod_ciudad, 'GUAZU CUA' descripcion_esperada, 12 cod_dpto FROM dual
UNION ALL
SELECT 918 cod_bcp, 89 cod_ciudad, 'COLONIA MARIA ANTONIA' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 914 cod_bcp, 200 cod_ciudad, 'TEBICUARYMI' descripcion_esperada, 9 cod_dpto FROM dual
UNION ALL
SELECT 1507 cod_bcp, 295 cod_ciudad, 'TENIENTE IRALA FERNANDEZ' descripcion_esperada, 15 cod_dpto FROM dual
UNION ALL
SELECT 214 cod_bcp, 124 cod_ciudad, 'GRAL FRANCISCO ISIDORO RESQUIN' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 212 cod_bcp, 121 cod_ciudad, '25 DE DICIEMBRE' descripcion_esperada, 2 cod_dpto FROM dual
UNION ALL
SELECT 521 cod_bcp, 312 cod_ciudad, 'TEMBIAPORA' descripcion_esperada, 5 cod_dpto FROM dual
UNION ALL
SELECT 1210 cod_bcp, 221 cod_ciudad, 'MAYOR DE JESUS MARTINEZ' descripcion_esperada, 12 cod_dpto FROM dual
  )
  SELECT COUNT(*)
    INTO v_post_duplicadas
    FROM (
      SELECT c.REF_EXTERNA
        FROM IT.BA_CIUDADES c
        JOIN m
          ON m.COD_BCP = c.REF_EXTERNA
       WHERE c.COD_PAIS = 1
       GROUP BY c.REF_EXTERNA
      HAVING COUNT(*) > 1
    );

  IF v_post_duplicadas != 0 THEN
    RAISE_APPLICATION_ERROR(
      -20227,
      'POST-CHECK: quedan ' || v_post_duplicadas ||
      ' REF_EXTERNAs duplicadas dentro del set preajustado. ROLLBACK.'
    );
  END IF;

  IF v_est_previo != 2 THEN
    UPDATE IT.BA_MODULOS
       SET ESTADO = v_est_previo
     WHERE COD_MODULO = 1;
  END IF;

  DBMS_OUTPUT.PUT_LINE('[OK] Targets validados          : ' || v_targets);
  DBMS_OUTPUT.PUT_LINE('[OK] REF 212 removida de ciudad 825: ' || v_limpiado_825);
  DBMS_OUTPUT.PUT_LINE('[OK] Ciudades preajustadas       : ' || v_actualizados);
  DBMS_OUTPUT.PUT_LINE('[OK] Mapeos post-check            : ' || v_post_ok);
  DBMS_OUTPUT.PUT_LINE('[OK] REF duplicadas post-check    : ' || v_post_duplicadas);
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE(
    'Transaccion pendiente. Ejecutar COMMIT para confirmar o ROLLBACK para deshacer.'
  );

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    RAISE;
END;
/

-- =============================================================================
-- CONTROL DESPUES DE EJECUTAR (antes de COMMIT)
-- =============================================================================
--
-- SELECT cod_ciudad, descripcion, cod_departamento, ref_externa
-- FROM it.ba_ciudades
-- WHERE cod_pais = 1
--   AND ref_externa IN
--       (107,114,212,214,403,515,521,604,718,914,918,1022,1205,1206,
--        1210,1302,1409,1411,1507,1602)
-- ORDER BY ref_externa;
--
-- Luego ejecutar:
-- validacion_264_ciudades_BCP_post_proceso_v4.sql
--
-- COMMIT;
-- ROLLBACK;
