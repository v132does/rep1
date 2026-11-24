-- =============================================================================
-- PRS_ACT_REF_CIUDADES - SRER-7088
-- Actualiza referencias BCP solo cuando el match es univoco.
-- No realiza altas automaticas de ciudades.
-- Casos excepcionales del catalogo PY se regularizan mediante scripts de datos.
-- =============================================================================

CREATE OR REPLACE EDITIONABLE PROCEDURE "IT"."PRS_ACT_REF_CIUDADES" IS

  -- Contadores
  v_cnt_ref          NUMBER := 0; -- actualizadas por REF_EXTERNA ya consistente
  v_cnt_nombre       NUMBER := 0; -- vinculadas/revinculadas por nombre + pais + departamento
  v_cnt_sin_pais     NUMBER := 0; -- pais ISO no resuelto
  v_cnt_sin_dpto     NUMBER := 0; -- departamento PY no resuelto
  v_cnt_sin_match    NUMBER := 0; -- sin ciudad Bankitti deterministica
  v_cnt_amb_ref      NUMBER := 0; -- mas de una ciudad con la misma REF_EXTERNA
  v_cnt_amb_nombre   NUMBER := 0; -- mas de una ciudad candidata por nombre/departamento
  v_cnt_cod_invalido NUMBER := 0; -- COD_BCP no numerico

  -- Control de ejecucion
  v_id           NUMBER;
  v_est_previo   IT.BA_MODULOS.ESTADO%TYPE;
  v_archivo      VARCHAR2(100);
  v_staging_cnt  NUMBER;
  v_ba_cnt       NUMBER;
  v_ba_final     NUMBER;

  -- Variables de trabajo
  v_cod_pais     IT.BA_PAISES.COD_PAIS%TYPE;
  v_cod_dpto     IT.BA_DEPARTAMENTOS.COD_DEPARTAMENTO%TYPE;
  v_cod_ciudad   IT.BA_CIUDADES.COD_CIUDAD%TYPE;
  v_cod_bcp_num  NUMBER;
  v_candidatos   NUMBER;

BEGIN

  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

  -- Metadata del archivo
  BEGIN
    SELECT ARCHIVO
      INTO v_archivo
      FROM IT.GE_ARCHIVOS
     WHERE REFERENCIA = 'BCP_CIUDADES'
       AND ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_archivo := 'CIUDADES_BCP.CSV';
  END;

  SELECT COUNT(*)
    INTO v_staging_cnt
    FROM IT.SB_BCP_CIU_TMP;

  SELECT COUNT(*)
    INTO v_ba_cnt
    FROM IT.BA_CIUDADES
   WHERE COD_PAIS = 1;

  -- Log inicio
  SELECT IT.SE_CF_ID_EJECUCION.NEXTVAL
    INTO v_id
    FROM DUAL;

  INSERT INTO IT.SB_CF_PRO_LOG
    (ID_EJECUCION, FEC_INICIO, ESTADO, TIPO_PROCESO, OBSERVACIONES)
  VALUES
    (v_id,
     SYSTIMESTAMP,
     'CORRIENDO',
     'ACT_CIUDADES',
     'Archivo: ' || v_archivo ||
     ' | Staging: ' || TO_CHAR(v_staging_cnt, '999,999,999') || ' filas' ||
     ' | BA_CIUDADES PY: ' || TO_CHAR(v_ba_cnt, '999,999,999') || ' filas');

  COMMIT;

  -- Abrir modulo 1 si estaba cerrado.
  -- No se confirma aqui para que un error posterior pueda revertir el estado.
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
  -- IMPORTANTE:
  -- Este proceso NO da de alta ciudades.
  --
  -- Resolucion:
  --   1) Si el codigo BCP ya esta vinculado de forma univoca y consistente,
  --      sincroniza DES_BCO_CENTRAL.
  --   2) Si no, intenta vincular por DESCRIPCION + PAIS y, para PY,
  --      tambien por DEPARTAMENTO.
  --   3) Solo actualiza cuando hay exactamente un candidato.
  --      Los casos sin match o ambiguos quedan sin modificar.
  --
  -- DES_BCO_CENTRAL no se utiliza para encontrar candidatos porque puede
  -- contener referencias historicas incorrectas y provocar falsos matches.
  -- ---------------------------------------------------------------------------
  FOR r IN (
    SELECT TRIM(t.COD_BCP)                 COD_BCP,
           UPPER(TRIM(t.COD_PAI_ISO))      COD_PAI_ISO,
           UPPER(TRIM(t.DESCRIPCION))      DES_BCP,
           UPPER(TRIM(t.DEPARTAMENTO))     DEP_BCP
      FROM IT.SB_BCP_CIU_TMP t
     WHERE t.COD_BCP IS NOT NULL
  ) LOOP

    -- Codigo BCP numerico
    BEGIN
      v_cod_bcp_num := TO_NUMBER(r.COD_BCP);
    EXCEPTION
      WHEN VALUE_ERROR THEN
        v_cnt_cod_invalido := v_cnt_cod_invalido + 1;
        CONTINUE;
    END;

    -- Resolver pais
    BEGIN
      SELECT p.COD_PAIS
        INTO v_cod_pais
        FROM IT.BA_PAISES p
       WHERE UPPER(TRIM(p.COD_PAI_ISO)) = r.COD_PAI_ISO;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_cnt_sin_pais := v_cnt_sin_pais + 1;
        CONTINUE;
      WHEN TOO_MANY_ROWS THEN
        v_cnt_sin_pais := v_cnt_sin_pais + 1;
        CONTINUE;
    END;

    -- Para PY el departamento forma parte del criterio de identidad.
    --
    -- IMPORTANTE:
    -- CIUDADES_BCP no trae el codigo de departamento, solo su descripcion.
    -- BA_CIUDADES guarda historicamente el codigo equivalente al catalogo BCP:
    --   01..15 -> 1..15
    --   BOQUERON -> 16
    --   ALTO PARAGUAY -> 17
    --   CAPITAL -> 18 (BCP informa 00 para Capital)
    --
    -- No se resuelve contra BA_DEPARTAMENTOS porque en esa tabla las
    -- descripciones 16/17 no coinciden semanticamente con la codificacion
    -- usada actualmente por BA_CIUDADES.
    --
    -- EXTERIOR es un caso especial: se valida por REF_EXTERNA/nombre sin
    -- restringir COD_DEPARTAMENTO.
    v_cod_dpto := NULL;

    IF v_cod_pais = 1 AND r.DEP_BCP IS NOT NULL THEN
      CASE TRANSLATE(r.DEP_BCP,
                     'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                     'AEIOUAEIOUAEIOUAONU')
        WHEN 'CONCEPCION'        THEN v_cod_dpto := 1;
        WHEN 'SAN PEDRO'         THEN v_cod_dpto := 2;
        WHEN 'CORDILLERA'        THEN v_cod_dpto := 3;
        WHEN 'GUAIRA'            THEN v_cod_dpto := 4;
        WHEN 'CAAGUAZU'          THEN v_cod_dpto := 5;
        WHEN 'CAAZAPA'           THEN v_cod_dpto := 6;
        WHEN 'ITAPUA'            THEN v_cod_dpto := 7;
        WHEN 'MISIONES'          THEN v_cod_dpto := 8;
        WHEN 'PARAGUARI'         THEN v_cod_dpto := 9;
        WHEN 'ALTO PARANA'       THEN v_cod_dpto := 10;
        WHEN 'CENTRAL'           THEN v_cod_dpto := 11;
        WHEN 'NEEMBUCU'          THEN v_cod_dpto := 12;
        WHEN 'AMAMBAY'           THEN v_cod_dpto := 13;
        WHEN 'CANINDEYU'         THEN v_cod_dpto := 14;
        WHEN 'PRESIDENTE HAYES'  THEN v_cod_dpto := 15;
        WHEN 'PDTE. HAYES'       THEN v_cod_dpto := 15;
        WHEN 'BOQUERON'          THEN v_cod_dpto := 16;
        WHEN 'ALTO PARAGUAY'     THEN v_cod_dpto := 17;
        WHEN 'CAPITAL'           THEN v_cod_dpto := 18;
        WHEN 'ASUNCION'          THEN v_cod_dpto := 18;
        WHEN 'EXTERIOR'          THEN v_cod_dpto := NULL;
        ELSE
          v_cnt_sin_dpto  := v_cnt_sin_dpto + 1;
          v_cnt_sin_match := v_cnt_sin_match + 1;
          CONTINUE;
      END CASE;
    END IF;

    -- -------------------------------------------------------------------------
    -- PASO 1: REF_EXTERNA ya vinculada de forma univoca y consistente.
    -- En PY se exige que el departamento coincida con el del archivo BCP.
    -- -------------------------------------------------------------------------
    SELECT COUNT(*), MIN(bc.COD_CIUDAD)
      INTO v_candidatos, v_cod_ciudad
      FROM IT.BA_CIUDADES bc
     WHERE bc.COD_PAIS    = v_cod_pais
       AND bc.REF_EXTERNA = v_cod_bcp_num
       AND (v_cod_pais != 1
            OR v_cod_dpto IS NULL
            OR bc.COD_DEPARTAMENTO = v_cod_dpto);

    IF v_candidatos = 1 THEN
      UPDATE IT.BA_CIUDADES bc
         SET bc.DES_BCO_CENTRAL = r.DES_BCP
       WHERE bc.COD_PAIS   = v_cod_pais
         AND bc.COD_CIUDAD = v_cod_ciudad;

      v_cnt_ref := v_cnt_ref + SQL%ROWCOUNT;
      CONTINUE;
    ELSIF v_candidatos > 1 THEN
      v_cnt_amb_ref := v_cnt_amb_ref + 1;
      CONTINUE;
    END IF;

    -- -------------------------------------------------------------------------
    -- PASO 2: buscar ciudad interna por nombre + pais + departamento.
    -- Solo DESCRIPCION Bankitti participa del matching.
    --
    -- Si la ciudad tenia una REF_EXTERNA historica/incorrecta pero el candidato
    -- por nombre+departamento es unico (ej. ASUNCION / BELLA VISTA ITAPUA),
    -- se reemplaza por el codigo vigente informado por BCP.
    -- -------------------------------------------------------------------------
    SELECT COUNT(*), MIN(bc.COD_CIUDAD)
      INTO v_candidatos, v_cod_ciudad
      FROM IT.BA_CIUDADES bc
     WHERE bc.COD_PAIS = v_cod_pais
       AND TRANSLATE(UPPER(TRIM(bc.DESCRIPCION)),
                     'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                     'AEIOUAEIOUAEIOUAONU') =
           TRANSLATE(r.DES_BCP,
                     'ÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕÑÜ',
                     'AEIOUAEIOUAEIOUAONU')
       AND (v_cod_pais != 1
            OR v_cod_dpto IS NULL
            OR bc.COD_DEPARTAMENTO = v_cod_dpto);

    IF v_candidatos = 1 THEN
      UPDATE IT.BA_CIUDADES bc
         SET bc.REF_EXTERNA     = v_cod_bcp_num,
             bc.DES_BCO_CENTRAL = r.DES_BCP
       WHERE bc.COD_PAIS   = v_cod_pais
         AND bc.COD_CIUDAD = v_cod_ciudad;

      v_cnt_nombre := v_cnt_nombre + SQL%ROWCOUNT;

    ELSIF v_candidatos = 0 THEN
      v_cnt_sin_match := v_cnt_sin_match + 1;

    ELSE
      v_cnt_amb_nombre := v_cnt_amb_nombre + 1;
    END IF;

  END LOOP;

  DELETE FROM IT.SB_BCP_CIU_TMP;

  IF v_est_previo != 2 THEN
    UPDATE IT.BA_MODULOS
       SET ESTADO = v_est_previo
     WHERE COD_MODULO = 1;
  END IF;

  SELECT COUNT(*)
    INTO v_ba_final
    FROM IT.BA_CIUDADES
   WHERE COD_PAIS = 1;

  UPDATE IT.SB_CF_PRO_LOG
     SET ESTADO          = 'OK',
         FEC_FIN         = SYSTIMESTAMP,
         TOTAL_REGISTROS = v_cnt_ref + v_cnt_nombre,
         OBSERVACIONES   = 'Archivo: ' || v_archivo ||
                           ' | Staging: ' || TO_CHAR(v_staging_cnt, '999,999,999') || ' filas' ||
                           ' | Por REF: ' || v_cnt_ref ||
                           ' | Por nombre/dpto: ' || v_cnt_nombre ||
                           ' | Sin match: ' || v_cnt_sin_match ||
                           ' | Ambigua REF: ' || v_cnt_amb_ref ||
                           ' | Ambigua nombre: ' || v_cnt_amb_nombre ||
                           ' | Sin pais: ' || v_cnt_sin_pais ||
                           ' | Sin dpto: ' || v_cnt_sin_dpto ||
                           ' | Cod BCP invalido: ' || v_cnt_cod_invalido ||
                           ' | Staging limpiada' ||
                           ' | BA_CIUDADES PY: ' || TO_CHAR(v_ba_final)
   WHERE ID_EJECUCION = v_id;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    DECLARE
      v_err VARCHAR2(4000) := SUBSTR(SQLERRM, 1, 4000);
    BEGIN
      ROLLBACK;

      -- El UPDATE de BA_MODULOS no fue confirmado: ROLLBACK restaura su estado.
      BEGIN
        UPDATE IT.SB_CF_PRO_LOG
           SET ESTADO          = 'ERROR',
               FEC_FIN         = SYSTIMESTAMP,
               OBSERVACIONES   = 'Archivo: ' || v_archivo ||
                                 ' | Staging: ' || TO_CHAR(v_staging_cnt, '999,999,999') || ' filas' ||
                                 ' | ERROR: ' || v_err
         WHERE ID_EJECUCION = v_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN NULL;
      END;

      RAISE_APPLICATION_ERROR(-20201, 'PRS_ACT_REF_CIUDADES: ' || v_err);
    END;
END PRS_ACT_REF_CIUDADES;
/
