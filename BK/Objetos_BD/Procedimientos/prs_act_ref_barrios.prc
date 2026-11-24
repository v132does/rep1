-- =============================================================================
-- PRS_ACT_REF_BARRIOS - SRER-7088
-- Procesa BARRIOS_BCP de forma deterministica y persiste todos los datos BCP.
-- No selecciona arbitrariamente ciudad/barrio ante multiples candidatos.
-- Incluye normalizacion puntual de 3 filas con encoding mixto detectadas en
-- el archivo fuente BARRIOS_BCP.
-- =============================================================================

CREATE OR REPLACE PROCEDURE IT.PRS_ACT_REF_BARRIOS IS

  -- Contadores
  v_cnt_upd           NUMBER := 0;
  v_cnt_ins           NUMBER := 0;
  v_cnt_sin_ciu       NUMBER := 0;
  v_cnt_ciu_amb       NUMBER := 0;
  v_cnt_sin_zona      NUMBER := 0;
  v_cnt_dpto_diff     NUMBER := 0;
  v_cnt_nombre_amb    NUMBER := 0;
  v_cnt_ba_final      NUMBER := 0;

  -- Control de ejecucion
  v_id                NUMBER;
  v_est_previo        IT.BA_MODULOS.ESTADO%TYPE;
  v_archivo           VARCHAR2(100);
  v_staging_cnt       NUMBER;
  v_staging_distintos NUMBER;

  -- Variables de trabajo
  v_cod_ciudad        IT.BA_CIUDADES.COD_CIUDAD%TYPE;
  v_cod_pais          IT.BA_CIUDADES.COD_PAIS%TYPE;
  v_cod_dpto_ciudad   IT.BA_CIUDADES.COD_DEPARTAMENTO%TYPE;
  v_cod_dpto_esperado IT.BA_BARRIOS.COD_DEPARTAMENTO%TYPE;
  v_cod_zona          IT.BA_BARRIOS.COD_TIPO_ZONA%TYPE;
  v_des_norm          IT.BA_BARRIOS.DESCRIPCION%TYPE;
  v_des_bcp           IT.BA_BARRIOS.DESCRIPCION%TYPE;
  v_nuevo_cod         IT.BA_BARRIOS.COD_BARRIO%TYPE;
  v_candidatos        NUMBER;
  v_variantes_bcp     NUMBER;
  v_rowid             ROWID;

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  BEGIN
    SELECT ARCHIVO
      INTO v_archivo
      FROM IT.GE_ARCHIVOS
     WHERE REFERENCIA = 'BCP_BARRIOS'
       AND ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_archivo := 'BARRIOS_BCP.CSV';
  END;

  SELECT COUNT(*)
    INTO v_staging_cnt
    FROM IT.SB_BCP_BAR_TMP;

  SELECT COUNT(DISTINCT TRIM(COD_BCP))
    INTO v_staging_distintos
    FROM IT.SB_BCP_BAR_TMP
   WHERE COD_BCP IS NOT NULL;

  -- Para el archivo actualmente validado esperamos una REF BCP unica por fila.
  IF v_staging_cnt <> v_staging_distintos THEN
    RAISE_APPLICATION_ERROR(
      -20210,
      'BCP_BARRIOS: staging=' || v_staging_cnt ||
      ', codigos BCP distintos=' || v_staging_distintos ||
      '. Existen codigos de barrio BCP duplicados.'
    );
  END IF;

  SELECT IT.SE_CF_ID_EJECUCION.NEXTVAL
    INTO v_id
    FROM DUAL;

  INSERT INTO IT.SB_CF_PRO_LOG
    (ID_EJECUCION, FEC_INICIO, ESTADO, TIPO_PROCESO, OBSERVACIONES)
  VALUES
    (v_id, SYSTIMESTAMP, 'CORRIENDO', 'ACT_BARRIOS',
     'Archivo: ' || v_archivo ||
     ' | Staging: ' || TO_CHAR(v_staging_cnt) || ' filas');
  COMMIT;

  SELECT ESTADO
    INTO v_est_previo
    FROM IT.BA_MODULOS
   WHERE COD_MODULO = 1;

  -- Sin COMMIT: ante error el ROLLBACK devuelve el modulo a su estado previo.
  IF v_est_previo != 2 THEN
    UPDATE IT.BA_MODULOS
       SET ESTADO = 2
     WHERE COD_MODULO = 1;
  END IF;

  FOR r IN (
    SELECT TRIM(t.COD_BCP)             COD_BCP,
           UPPER(TRIM(t.DESCRIPCION))  DES_BCP,
           TRIM(t.COD_CIUDAD_BCP)      COD_CIUDAD_BCP,
           UPPER(TRIM(t.DES_CIUDAD))   DES_CIUDAD,
           TRIM(t.COD_DEPTO_BCP)       COD_DEPTO_BCP,
           UPPER(TRIM(t.TIPO_ZONA))    TIPO_ZONA_UP
      FROM IT.SB_BCP_BAR_TMP t
     WHERE t.COD_BCP IS NOT NULL
     ORDER BY TO_NUMBER(t.COD_BCP)
  ) LOOP

    -- -------------------------------------------------------------------------
    -- Normalizacion puntual de 3 registros cuyo campo DESCRIPCION llega con
    -- bytes UTF-8 embebidos dentro del archivo WE8MSWIN1252.
    -- Se reemplaza solo la secuencia corrupta, conservando el resto del texto.
    -- -------------------------------------------------------------------------
    v_des_bcp := r.DES_BCP;

    IF TO_NUMBER(r.COD_BCP) = 101650 THEN
      v_des_bcp := REPLACE(v_des_bcp,
                           UNISTR('\00C3\2018'),
                           UNISTR('\00D1'));
    ELSIF TO_NUMBER(r.COD_BCP) IN (1406360, 1606280) THEN
      v_des_bcp := REPLACE(v_des_bcp,
                           UNISTR('\00C3\00BF'),
                           UNISTR('\00D1'));
    END IF;

    -- -------------------------------------------------------------------------
    -- 1. Ciudad: REF_EXTERNA debe resolver EXACTAMENTE una ciudad de Paraguay.
    -- -------------------------------------------------------------------------
    BEGIN
      SELECT bc.COD_CIUDAD,
             bc.COD_PAIS,
             bc.COD_DEPARTAMENTO
        INTO v_cod_ciudad,
             v_cod_pais,
             v_cod_dpto_ciudad
        FROM IT.BA_CIUDADES bc
       WHERE bc.COD_PAIS = 1
         AND bc.REF_EXTERNA = TO_NUMBER(r.COD_CIUDAD_BCP);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_cnt_sin_ciu := v_cnt_sin_ciu + 1;
        CONTINUE;
      WHEN TOO_MANY_ROWS THEN
        v_cnt_ciu_amb := v_cnt_ciu_amb + 1;
        CONTINUE;
      WHEN VALUE_ERROR THEN
        v_cnt_sin_ciu := v_cnt_sin_ciu + 1;
        CONTINUE;
    END;

    -- -------------------------------------------------------------------------
    -- 2. Departamento interno esperado a partir del codigo BCP.
    --    00 (CAPITAL) se representa como 18 en BA_CIUDADES/BA_DEPARTAMENTOS.
    --    99 (EXTERIOR) no tiene departamento interno.
    --    El resto conserva el codigo numerico BCP, que coincide con el valor
    --    historicamente usado por BA_CIUDADES.
    -- -------------------------------------------------------------------------
    BEGIN
      IF TO_NUMBER(r.COD_DEPTO_BCP) = 0 THEN
        v_cod_dpto_esperado := 18;
      ELSIF TO_NUMBER(r.COD_DEPTO_BCP) = 99 THEN
        v_cod_dpto_esperado := NULL;
      ELSE
        v_cod_dpto_esperado := TO_NUMBER(r.COD_DEPTO_BCP);
      END IF;
    EXCEPTION
      WHEN VALUE_ERROR THEN
        v_cnt_dpto_diff := v_cnt_dpto_diff + 1;
        CONTINUE;
    END;

    -- La ciudad vinculada debe ser consistente con el departamento del BCP.
    IF (v_cod_dpto_esperado IS NULL AND v_cod_dpto_ciudad IS NOT NULL)
       OR (v_cod_dpto_esperado IS NOT NULL AND
           NVL(v_cod_dpto_ciudad, -1) <> v_cod_dpto_esperado) THEN
      v_cnt_dpto_diff := v_cnt_dpto_diff + 1;
      CONTINUE;
    END IF;

    -- -------------------------------------------------------------------------
    -- 3. Tipo de zona.
    -- -------------------------------------------------------------------------
    BEGIN
      SELECT cr.VAL_MINIMO
        INTO v_cod_zona
        FROM IT.BA_COD_REFERENCIAS cr
       WHERE cr.DOMINIO = 'TIPO_ZONA_BARRIO'
         AND UPPER(TRIM(cr.SIGNIFICADO)) = r.TIPO_ZONA_UP;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_cnt_sin_zona := v_cnt_sin_zona + 1;
        CONTINUE;
      WHEN TOO_MANY_ROWS THEN
        v_cnt_sin_zona := v_cnt_sin_zona + 1;
        CONTINUE;
    END;

    -- Descripcion base sin sufijo de zona, solo para intentar vincular
    -- barrios historicos que no guardaban URBANA/RURAL en DESCRIPCION.
    v_des_norm := TRIM(REGEXP_REPLACE(
                        v_des_bcp,
                        ' - ' || r.TIPO_ZONA_UP || '$',
                        ''));

    IF v_des_norm IS NULL THEN
      v_des_norm := v_des_bcp;
    END IF;

    -- -------------------------------------------------------------------------
    -- 4. Ya vinculado por REF_EXTERNA.
    --    Debe existir como maximo una fila dentro de la ciudad.
    -- -------------------------------------------------------------------------
    SELECT COUNT(*), MIN(ROWID)
      INTO v_candidatos, v_rowid
      FROM IT.BA_BARRIOS b
     WHERE b.COD_PAIS = v_cod_pais
       AND b.COD_CIUDAD = v_cod_ciudad
       AND b.REF_EXTERNA = TO_NUMBER(r.COD_BCP);

    IF v_candidatos > 1 THEN
      RAISE_APPLICATION_ERROR(
        -20211,
        'BCP_BARRIOS: REF_EXTERNA barrio duplicada. COD_BCP=' || r.COD_BCP ||
        ', COD_CIUDAD=' || v_cod_ciudad
      );
    ELSIF v_candidatos = 1 THEN
      UPDATE IT.BA_BARRIOS b
         SET b.DES_BCO_CENTRAL  = v_des_bcp,
             b.COD_TIPO_ZONA    = v_cod_zona,
             b.COD_DEPARTAMENTO = v_cod_dpto_esperado,
             b.COD_CIUDAD_BCP   = r.COD_CIUDAD_BCP,
             b.DESC_CIUDAD_BCP  = r.DES_CIUDAD,
             b.USU_MODIFICACION = SUBSTR(USER, 1, 10),
             b.FEC_MODIFICACION = SYSDATE
       WHERE b.ROWID = v_rowid;

      v_cnt_upd := v_cnt_upd + SQL%ROWCOUNT;
      CONTINUE;
    END IF;

    -- -------------------------------------------------------------------------
    -- 5a. Match exacto contra la descripcion BCP completa.
    --     Solo se vincula si existe EXACTAMENTE un candidato interno.
    -- -------------------------------------------------------------------------
    SELECT COUNT(*), MIN(ROWID)
      INTO v_candidatos, v_rowid
      FROM IT.BA_BARRIOS b
     WHERE b.COD_PAIS = v_cod_pais
       AND b.COD_CIUDAD = v_cod_ciudad
       AND b.REF_EXTERNA IS NULL
       AND TRANSLATE(UPPER(TRIM(b.DESCRIPCION)),
                     'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                     'AEIOUAEIOUAEIOUAONU') =
           TRANSLATE(v_des_bcp,
                     'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                     'AEIOUAEIOUAEIOUAONU');

    IF v_candidatos = 1 THEN
      UPDATE IT.BA_BARRIOS b
         SET b.REF_EXTERNA      = TO_NUMBER(r.COD_BCP),
             b.DES_BCO_CENTRAL  = v_des_bcp,
             b.COD_TIPO_ZONA    = v_cod_zona,
             b.COD_DEPARTAMENTO = v_cod_dpto_esperado,
             b.COD_CIUDAD_BCP   = r.COD_CIUDAD_BCP,
             b.DESC_CIUDAD_BCP  = r.DES_CIUDAD,
             b.USU_MODIFICACION = SUBSTR(USER, 1, 10),
             b.FEC_MODIFICACION = SYSDATE
       WHERE b.ROWID = v_rowid;

      v_cnt_upd := v_cnt_upd + SQL%ROWCOUNT;
      CONTINUE;
    ELSIF v_candidatos > 1 THEN
      -- No elegir arbitrariamente entre duplicados internos.
      v_cnt_nombre_amb := v_cnt_nombre_amb + 1;
    END IF;

    -- -------------------------------------------------------------------------
    -- 5b. Match por nombre historico SIN sufijo de zona.
    --
    --     Solo es seguro si:
    --       a) ese nombre base aparece UNA sola vez en el archivo BCP para la
    --          misma ciudad, y
    --       b) hay UNA sola fila interna candidata sin REF_EXTERNA.
    --
    --     Si BCP tiene, por ejemplo, LOMA GUASU - URBANA y LOMA GUASU - RURAL,
    --     NO se asigna el barrio historico LOMA GUASU a una variante al azar.
    -- -------------------------------------------------------------------------
    SELECT COUNT(*)
      INTO v_variantes_bcp
      FROM IT.SB_BCP_BAR_TMP t
     WHERE TO_NUMBER(TRIM(t.COD_CIUDAD_BCP)) = TO_NUMBER(r.COD_CIUDAD_BCP)
       AND TRIM(REGEXP_REPLACE(
             CASE TRIM(t.COD_BCP)
               WHEN '101650' THEN
                 REPLACE(UPPER(TRIM(t.DESCRIPCION)),
                         UNISTR('\00C3\2018'),
                         UNISTR('\00D1'))
               WHEN '1406360' THEN
                 REPLACE(UPPER(TRIM(t.DESCRIPCION)),
                         UNISTR('\00C3\00BF'),
                         UNISTR('\00D1'))
               WHEN '1606280' THEN
                 REPLACE(UPPER(TRIM(t.DESCRIPCION)),
                         UNISTR('\00C3\00BF'),
                         UNISTR('\00D1'))
               ELSE UPPER(TRIM(t.DESCRIPCION))
             END,
             ' - ' || UPPER(TRIM(t.TIPO_ZONA)) || '$',
             '')) = v_des_norm;

    IF v_variantes_bcp = 1 THEN
      SELECT COUNT(*), MIN(ROWID)
        INTO v_candidatos, v_rowid
        FROM IT.BA_BARRIOS b
       WHERE b.COD_PAIS = v_cod_pais
         AND b.COD_CIUDAD = v_cod_ciudad
         AND b.REF_EXTERNA IS NULL
         AND TRANSLATE(UPPER(TRIM(b.DESCRIPCION)),
                       'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                       'AEIOUAEIOUAEIOUAONU') =
             TRANSLATE(v_des_norm,
                       'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                       'AEIOUAEIOUAEIOUAONU');

      IF v_candidatos = 1 THEN
        UPDATE IT.BA_BARRIOS b
           SET b.REF_EXTERNA      = TO_NUMBER(r.COD_BCP),
               b.DES_BCO_CENTRAL  = v_des_bcp,
               b.COD_TIPO_ZONA    = v_cod_zona,
               b.COD_DEPARTAMENTO = v_cod_dpto_esperado,
               b.COD_CIUDAD_BCP   = r.COD_CIUDAD_BCP,
               b.DESC_CIUDAD_BCP  = r.DES_CIUDAD,
               b.USU_MODIFICACION = SUBSTR(USER, 1, 10),
               b.FEC_MODIFICACION = SYSDATE
         WHERE b.ROWID = v_rowid;

        v_cnt_upd := v_cnt_upd + SQL%ROWCOUNT;
        CONTINUE;
      ELSIF v_candidatos > 1 THEN
        v_cnt_nombre_amb := v_cnt_nombre_amb + 1;
      END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- 6. No existe un match univoco: alta de un barrio BCP nuevo.
    --    Se conserva cualquier barrio historico ambiguo sin modificarlo.
    -- -------------------------------------------------------------------------
    SELECT NVL(MAX(b.COD_BARRIO), 0) + 1
      INTO v_nuevo_cod
      FROM IT.BA_BARRIOS b
     WHERE b.COD_PAIS = v_cod_pais
       AND b.COD_CIUDAD = v_cod_ciudad;

    IF v_nuevo_cod > 9999 THEN
      RAISE_APPLICATION_ERROR(
        -20212,
        'BCP_BARRIOS: sin COD_BARRIO libre para COD_CIUDAD=' || v_cod_ciudad
      );
    END IF;

    INSERT INTO IT.BA_BARRIOS
      (COD_PAIS, COD_CIUDAD, COD_BARRIO,
       DESCRIPCION,
       REF_EXTERNA, DES_BCO_CENTRAL, COD_TIPO_ZONA,
       COD_DEPARTAMENTO,
       COD_CIUDAD_BCP, DESC_CIUDAD_BCP,
       USU_INSERCION, FEC_INSERCION,
       USU_MODIFICACION, FEC_MODIFICACION)
    VALUES
      (v_cod_pais, v_cod_ciudad, v_nuevo_cod,
       v_des_bcp,
       TO_NUMBER(r.COD_BCP), v_des_bcp, v_cod_zona,
       v_cod_dpto_esperado,
       r.COD_CIUDAD_BCP, r.DES_CIUDAD,
       'BCP_IMPORT', SYSDATE,
       'BCP_IMPORT', SYSDATE);

    v_cnt_ins := v_cnt_ins + 1;

  END LOOP;

  -- ---------------------------------------------------------------------------
  -- La corrida completa debe resolver todas las filas del archivo.
  -- ---------------------------------------------------------------------------
  IF v_cnt_sin_ciu <> 0
     OR v_cnt_ciu_amb <> 0
     OR v_cnt_sin_zona <> 0
     OR v_cnt_dpto_diff <> 0
     OR (v_cnt_upd + v_cnt_ins) <> v_staging_cnt THEN
    RAISE_APPLICATION_ERROR(
      -20213,
      'BCP_BARRIOS incompleto. Staging=' || v_staging_cnt ||
      ', procesados=' || (v_cnt_upd + v_cnt_ins) ||
      ', sin_ciudad=' || v_cnt_sin_ciu ||
      ', ciudad_ambigua=' || v_cnt_ciu_amb ||
      ', sin_zona=' || v_cnt_sin_zona ||
      ', depto_inconsistente=' || v_cnt_dpto_diff
    );
  END IF;

  DELETE FROM IT.SB_BCP_BAR_TMP;

  IF v_est_previo != 2 THEN
    UPDATE IT.BA_MODULOS
       SET ESTADO = v_est_previo
     WHERE COD_MODULO = 1;
  END IF;

  SELECT COUNT(*)
    INTO v_cnt_ba_final
    FROM IT.BA_BARRIOS;

  UPDATE IT.SB_CF_PRO_LOG
     SET ESTADO          = 'OK',
         FEC_FIN         = SYSTIMESTAMP,
         TOTAL_REGISTROS = v_cnt_upd + v_cnt_ins,
         OBSERVACIONES   = 'Archivo: ' || v_archivo ||
                           ' | Staging: ' || v_staging_cnt ||
                           ' | Insertados: ' || v_cnt_ins ||
                           ' | Actualizados: ' || v_cnt_upd ||
                           ' | Match nombre ambiguo preservado: ' || v_cnt_nombre_amb ||
                           ' | Sin ciudad: ' || v_cnt_sin_ciu ||
                           ' | Ciudad ambigua: ' || v_cnt_ciu_amb ||
                           ' | Sin zona: ' || v_cnt_sin_zona ||
                           ' | Depto inconsistente: ' || v_cnt_dpto_diff ||
                           ' | BA_BARRIOS total: ' || v_cnt_ba_final
   WHERE ID_EJECUCION = v_id;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    DECLARE
      v_err VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 4000);
    BEGIN
      ROLLBACK;

      BEGIN
        UPDATE IT.SB_CF_PRO_LOG
           SET ESTADO = 'ERROR',
               FEC_FIN = SYSTIMESTAMP,
               OBSERVACIONES = 'Archivo: ' || v_archivo ||
                               ' | Staging: ' || v_staging_cnt ||
                               ' | Insertados hasta error: ' || v_cnt_ins ||
                               ' | Actualizados hasta error: ' || v_cnt_upd ||
                               ' | Sin ciudad: ' || v_cnt_sin_ciu ||
                               ' | Ciudad ambigua: ' || v_cnt_ciu_amb ||
                               ' | Sin zona: ' || v_cnt_sin_zona ||
                               ' | Depto inconsistente: ' || v_cnt_dpto_diff ||
                               ' | ERROR: ' || v_err
         WHERE ID_EJECUCION = v_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;

      RAISE_APPLICATION_ERROR(-20202, 'PRS_ACT_REF_BARRIOS: ' || v_err);
    END;
END PRS_ACT_REF_BARRIOS;
/
