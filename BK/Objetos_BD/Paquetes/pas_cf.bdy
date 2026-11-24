
create or replace PACKAGE BODY    IT.PAS_CF AS

  /*
    Refactor PAS_CF - CF Alta Personas
    Version: universo CRC02 + R31 optimizado + R21 variantes CRC/CRP + validacion RUC DV modulo 11
    Objetivo:
      - Mantener la especificacion publica existente: PR_GENERAR y PR_LIMPIAR_LOGS.
      - Dejar todas las reglas dentro del mismo package body.
      - Separar: candidatos, normalizaciones, correcciones seguras, validaciones BCP,
        duplicados, generacion CSV y renumeracion.
      - Usar las tablas existentes: SB_CF_ALT_PERSONAS, SB_CF_EXCL_DETALLE,
        SB_CF_PRO_LOG y SB_CF_REG_LOG.

    Fuentes funcionales consideradas:
      - Manual Tecnico Archivo CF - PERSONAS, version 2.1, noviembre 2025.
      - Circular SB.SG. Nro 00586/2010.
      - Circular SB.SG. Nro 00057/2021.
      - Errores reales BCP CK_TMP_CF_01_*.
  */

  ------------------------------------------------------------------------------
  -- UTILITARIOS
  ------------------------------------------------------------------------------
  FUNCTION fn_ruc_dv_esperado(p_numero IN VARCHAR2) RETURN NUMBER IS
    v_base   VARCHAR2(50);
    v_total  NUMBER := 0;
    v_factor NUMBER := 2;
    v_char   VARCHAR2(1);
    v_val    NUMBER;
    v_resto  NUMBER;
  BEGIN
    -- Algoritmo modulo 11 utilizado para RUC Paraguay.
    -- Entrada esperada: base sin digito verificador ni guion.
    v_base := REGEXP_REPLACE(TRIM(p_numero), '[^0-9]', '');

    IF v_base IS NULL THEN
      RETURN NULL;
    END IF;

    FOR i IN REVERSE 1 .. LENGTH(v_base) LOOP
      v_char := SUBSTR(v_base, i, 1);
      v_val  := TO_NUMBER(v_char);
      v_total := v_total + (v_val * v_factor);

      v_factor := v_factor + 1;
      IF v_factor > 11 THEN
        v_factor := 2;
      END IF;
    END LOOP;

    v_resto := MOD(v_total, 11);
    IF v_resto > 1 THEN
      RETURN 11 - v_resto;
    ELSE
      RETURN 0;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END fn_ruc_dv_esperado;

  FUNCTION fn_ruc_dv_valido(p_ruc IN VARCHAR2) RETURN NUMBER IS
    v_txt      VARCHAR2(50) := TRIM(REPLACE(p_ruc, CHR(160), ' '));
    v_base     VARCHAR2(50);
    v_dv_txt   VARCHAR2(2);
    v_dv_calc  NUMBER;
  BEGIN
    IF NOT REGEXP_LIKE(v_txt, '^[0-9]+-[0-9]$') THEN
      RETURN 0;
    END IF;

    v_base    := REGEXP_SUBSTR(v_txt, '^[0-9]+');
    v_dv_txt  := REGEXP_SUBSTR(v_txt, '[0-9]$');
    v_dv_calc := fn_ruc_dv_esperado(v_base);

    IF v_dv_calc IS NOT NULL AND v_dv_calc = TO_NUMBER(v_dv_txt) THEN
      RETURN 1;
    END IF;

    RETURN 0;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END fn_ruc_dv_valido;

  ------------------------------------------------------------------------------
  -- LOGGING
  ------------------------------------------------------------------------------
  PROCEDURE pr_log_regla(
    p_id_ejec     IN NUMBER,
    p_cod         IN VARCHAR2,
    p_descripcion IN VARCHAR2,
    p_normativa   IN VARCHAR2,
    p_afectados   IN NUMBER,
    p_accion      IN VARCHAR2
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    MERGE INTO IT.SB_CF_REG_LOG tgt
    USING (
      SELECT p_id_ejec id_ejecucion,
             SUBSTR(p_cod,1,10) cod_regla,
             SUBSTR(p_descripcion,1,500) descripcion,
             SUBSTR(p_normativa,1,200) normativa,
             NVL(p_afectados,0) total_afectados,
             SUBSTR(p_accion,1,200) accion
        FROM DUAL
    ) src
    ON (tgt.ID_EJECUCION = src.id_ejecucion AND tgt.COD_REGLA = src.cod_regla)
    WHEN MATCHED THEN UPDATE SET
         tgt.DESCRIPCION     = src.descripcion,
         tgt.NORMATIVA       = src.normativa,
         tgt.TOTAL_AFECTADOS = src.total_afectados,
         tgt.ACCION          = src.accion,
         tgt.FEC_LOG         = SYSTIMESTAMP
    WHEN NOT MATCHED THEN INSERT
         (ID_EJECUCION, COD_REGLA, DESCRIPCION, NORMATIVA,
          TOTAL_AFECTADOS, ACCION, FEC_LOG)
    VALUES
         (src.id_ejecucion, src.cod_regla, src.descripcion, src.normativa,
          src.total_afectados, src.accion, SYSTIMESTAMP);

    COMMIT;
  END pr_log_regla;

  PROCEDURE pr_upd_estado(
    p_id_ejec IN NUMBER,
    p_estado  IN VARCHAR2,
    p_total   IN NUMBER   DEFAULT NULL,
    p_obs     IN VARCHAR2 DEFAULT NULL
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE IT.SB_CF_PRO_LOG
       SET ESTADO          = p_estado,
           FEC_FIN         = SYSTIMESTAMP,
           TOTAL_REGISTROS = NVL(p_total, TOTAL_REGISTROS),
           OBSERVACIONES   = SUBSTR(p_obs,1,4000)
     WHERE ID_EJECUCION = p_id_ejec;
    COMMIT;
  END pr_upd_estado;

  PROCEDURE pr_registrar_correccion(
    p_id                 IN NUMBER,
    p_cod_regla          IN VARCHAR2,
    p_descripcion        IN VARCHAR2,
    p_normativa          IN VARCHAR2,
    p_motivo             IN VARCHAR2,
    p_where              IN VARCHAR2,
    p_val_original_sql   IN VARCHAR2,
    p_val_corregido_sql  IN VARCHAR2
  ) IS
    v_cnt NUMBER;
  BEGIN
    EXECUTE IMMEDIATE
      'SELECT COUNT(*)
         FROM IT.SB_CF_ALT_PERSONAS a
        WHERE a.ID_EJECUCION = :id
          AND (' || p_where || ')'
      INTO v_cnt
      USING p_id;

    IF v_cnt = 0 THEN
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      p_cod_regla,
      p_descripcion,
      p_normativa,
      v_cnt,
      'CORREGIR: ' || p_motivo || ' - ' || v_cnt || ' registros'
    );

    EXECUTE IMMEDIATE
      'INSERT INTO IT.SB_CF_EXCL_DETALLE
         (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
          TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
          PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
          MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
       SELECT :id,
              :cod,
              ''CORREGIR'',
              a.COD_PERSONA,
              a.TIPO_IDENT,
              a.NRO_DOCUMENTO,
              a.TIPO_PER,
              a.NOMBRE,
              a.APELLIDO,
              a.PAIS_NACIMIENTO,
              a.FECHA_NAC,
              a.FECHA_VENC_DOC,
              a.GENERO,
              :motivo,
              SUBSTR(' || p_val_original_sql || ',1,200),
              SUBSTR(' || p_val_corregido_sql || ',1,200)
         FROM IT.SB_CF_ALT_PERSONAS a
        WHERE a.ID_EJECUCION = :id2
          AND (' || p_where || ')'
      USING p_id, SUBSTR(p_cod_regla,1,10), SUBSTR(p_motivo,1,500), p_id;

    COMMIT;
  END pr_registrar_correccion;

  PROCEDURE pr_excluir_regla(
    p_id          IN NUMBER,
    p_cod_regla   IN VARCHAR2,
    p_descripcion IN VARCHAR2,
    p_normativa   IN VARCHAR2,
    p_motivo      IN VARCHAR2,
    p_where       IN VARCHAR2
  ) IS
    v_cnt NUMBER;
  BEGIN
    EXECUTE IMMEDIATE
      'SELECT COUNT(*)
         FROM IT.SB_CF_ALT_PERSONAS a
        WHERE a.ID_EJECUCION = :id
          AND (' || p_where || ')'
      INTO v_cnt
      USING p_id;

    IF v_cnt = 0 THEN
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      p_cod_regla,
      p_descripcion,
      p_normativa,
      v_cnt,
      'EXCLUIR: ' || p_motivo || ' - ' || v_cnt || ' registros'
    );

    EXECUTE IMMEDIATE
      'INSERT INTO IT.SB_CF_EXCL_DETALLE
         (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
          TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
          PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
          MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
       SELECT :id,
              :cod,
              ''EXCLUIR'',
              a.COD_PERSONA,
              a.TIPO_IDENT,
              a.NRO_DOCUMENTO,
              a.TIPO_PER,
              a.NOMBRE,
              a.APELLIDO,
              a.PAIS_NACIMIENTO,
              a.FECHA_NAC,
              a.FECHA_VENC_DOC,
              a.GENERO,
              :motivo,
              SUBSTR(NVL(a.TIPO_IDENT,'''') || ''/'' || NVL(a.NRO_DOCUMENTO,''''),1,200),
              NULL
         FROM IT.SB_CF_ALT_PERSONAS a
        WHERE a.ID_EJECUCION = :id2
          AND (' || p_where || ')'
      USING p_id, SUBSTR(p_cod_regla,1,10), SUBSTR(p_motivo,1,500), p_id;

    EXECUTE IMMEDIATE
      'DELETE FROM IT.SB_CF_ALT_PERSONAS a
        WHERE a.ID_EJECUCION = :id
          AND (' || p_where || ')'
      USING p_id;

    COMMIT;
  END pr_excluir_regla;

  ------------------------------------------------------------------------------
  -- INICIO / PREPARACION
  ------------------------------------------------------------------------------
  PROCEDURE pr_obtener_fecha_cierre(p_cierre OUT DATE) IS
  BEGIN
    SELECT fec_anterior
      INTO p_cierre
      FROM IT.GE_CALENDARIOS
     WHERE cod_modulo = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20300,
        'PAS_CF.PR_GENERAR: GE_CALENDARIOS sin fila cod_modulo=1');
  END pr_obtener_fecha_cierre;

  PROCEDURE pr_iniciar_ejecucion(
    p_id     OUT NUMBER,
    p_cierre IN  DATE
  ) IS
  BEGIN
    SELECT IT.SE_CF_ID_EJECUCION.NEXTVAL INTO p_id FROM DUAL;

    INSERT INTO IT.SB_CF_PRO_LOG
      (ID_EJECUCION, FEC_INICIO, ESTADO, TIPO_PROCESO, FEC_CIERRE)
    VALUES
      (p_id, SYSTIMESTAMP, 'CORRIENDO', 'CF_ALTA', p_cierre);

    COMMIT;
  END pr_iniciar_ejecucion;

  PROCEDURE pr_preparar_ejecucion(p_id IN NUMBER, p_cierre IN DATE) IS
  BEGIN
    -- Borrar datos de ejecuciones previas con la misma fecha de cierre.
    -- Se conservan todas las demas fechas para permitir generacion de archivos historicos.
    DELETE FROM IT.SB_CF_EXCL_DETALLE
     WHERE ID_EJECUCION IN (
             SELECT ID_EJECUCION FROM IT.SB_CF_PRO_LOG
              WHERE TRUNC(FEC_CIERRE) = TRUNC(p_cierre)
                AND ID_EJECUCION    != p_id
           );

    DELETE FROM IT.SB_CF_ALT_PERSONAS
     WHERE ID_EJECUCION IN (
             SELECT ID_EJECUCION FROM IT.SB_CF_PRO_LOG
              WHERE TRUNC(FEC_CIERRE) = TRUNC(p_cierre)
                AND ID_EJECUCION    != p_id
           );

    COMMIT;

    pr_log_regla(
      p_id,
      'INI',
      'Inicio de generacion CF Alta Personas',
      'PAS_CF.PR_GENERAR',
      0,
      'INICIO: datos de ejecuciones previas para ' || TO_CHAR(p_cierre,'DD/MM/YYYY') || ' eliminados'
    );
  END pr_preparar_ejecucion;

  ------------------------------------------------------------------------------
  -- CONSTRUCCION DE CANDIDATOS
  ------------------------------------------------------------------------------
  PROCEDURE pr_construir_candidatos(
    p_id    IN NUMBER,
    p_fecha IN DATE
  ) IS
    v_cnt         NUMBER := 0;
    v_crc02_total NUMBER := 0;
    v_r06_cnt     NUMBER := 0;
  BEGIN
    /*
      CAMBIO DE UNIVERSO - CRC02
      --------------------------------------------------------------------------
      El CF de Alta de Personas se construye desde las personas efectivamente
      informadas en el archivo diario de vinculos CRC 02:
        SB_CRC_VINCULOS_DET
        NOM_REFERENCIA = 'VINCULOS'
        NRO_FORMULARIO = '002'
        FECHA = fecha de cierre/proceso

      Se mantiene SB_BCP_PERSONAS_REF completo como padron BCP para excluir existentes.
      Los datos finales de persona se toman de BA_PERSONAS/BA_PER_FISICAS para
      conservar la fuente Bankiti y luego se aplican las validaciones/correcciones
      del package.
    */

    SELECT COUNT(*)
      INTO v_crc02_total
      FROM (
        SELECT DISTINCT v.cod_persona
          FROM IT.SB_CRC_VINCULOS_DET v
         WHERE v.fecha >= TRUNC(p_fecha)
           AND v.fecha <  TRUNC(p_fecha) + 1
           AND v.nom_referencia = 'VINCULOS'
           AND v.nro_formulario IN ('002','2')
           AND v.cod_persona IS NOT NULL
      );

    pr_log_regla(
      p_id,
      'U01',
      'Personas unicas informadas en CRC 02',
      'Universo CF: SB_CRC_VINCULOS_DET formulario 002',
      v_crc02_total,
      'CONTROL: personas unicas CRC02 para fecha ' || TO_CHAR(TRUNC(p_fecha),'DD/MM/YYYY')
    );

    IF v_crc02_total = 0 THEN
      RAISE_APPLICATION_ERROR(
        -20310,
        'PAS_CF.PR_GENERAR: no existen vinculos CRC 02 para la fecha ' ||
        TO_CHAR(TRUNC(p_fecha),'DD/MM/YYYY')
      );
    END IF;

    -- R06 informativo: CRC02 que ya existe por match exacto en SB_BCP_PERSONAS_REF.
    -- Se evita usar funciones sobre SB_BCP_PERSONAS_REF para no degradar performance.
    SELECT COUNT(DISTINCT v.cod_persona)
      INTO v_r06_cnt
      FROM IT.SB_CRC_VINCULOS_DET v
      JOIN IT.BA_PERSONAS per
        ON per.cod_persona = v.cod_persona
      JOIN IT.BA_TIP_DOCUMENTOS doc
        ON doc.cod_tip_documento = per.cod_tip_documento
      JOIN IT.SB_BCP_PERSONAS_REF r
        ON r.rf_tipo_ident = CASE UPPER(TRIM(doc.abreviatura))
                               WHEN 'RUC' THEN 'RU'
                               WHEN 'CRC' THEN 'CR'
                               WHEN 'CRP' THEN 'CR'
                               WHEN 'PAS' THEN 'CR'
                               ELSE UPPER(TRIM(doc.abreviatura))
                             END
       AND r.rf_numero = TRIM(per.nro_documento)
     WHERE v.fecha >= TRUNC(p_fecha)
       AND v.fecha <  TRUNC(p_fecha) + 1
       AND v.nom_referencia = 'VINCULOS'
       AND v.nro_formulario IN ('002','2')
       AND v.cod_persona IS NOT NULL;

    pr_log_regla(
      p_id,
      'R06',
      'Personas CRC02 ya en padron BCP - excluidas del lote inicial',
      'Alta CF: CRC02 vs SB_BCP_PERSONAS_REF completo',
      v_r06_cnt,
      'EXCLUIR: existentes por match exacto tipo/documento en SB_BCP_PERSONAS_REF'
    );

    INSERT /*+ APPEND */ INTO IT.SB_CF_ALT_PERSONAS(
      NRO_LINEA,
      TIPO_IDENT,
      NRO_DOCUMENTO,
      TIPO_PER,
      APELLIDO,
      NOMBRE,
      FECHA_NAC,
      GENERO,
      PAIS_NACIMIENTO,
      CIUDAD_NACIMIENTO,
      FECHA_VENC_DOC,
      COD_PERSONA,
      RELACION,
      NATURALEZA,
      LINEA_CSV,
      ID_EJECUCION,
      FEC_GENERADO
    )
    SELECT ROW_NUMBER() OVER (ORDER BY z.apellido NULLS LAST, z.nombre NULLS LAST, z.nro_documento) nro_linea,
           z.tipo_ident,
           z.nro_documento,
           z.tipo_per,
           z.apellido,
           z.nombre,
           z.fecha_nac,
           z.genero,
           z.pais_nacimiento,
           z.ciudad_nacimiento,
           z.fecha_venc_doc,
           z.cod_persona,
           z.relacion,
           z.naturaleza,
           NULL linea_csv,
           p_id,
           SYSTIMESTAMP
      FROM (
        SELECT tipo_ident,
               nro_documento,
               tipo_per,
               apellido,
               nombre,
               fecha_nac,
               genero,
               pais_nacimiento,
               ciudad_nacimiento,
               fecha_venc_doc,
               cod_persona,
               relacion,
               naturaleza
          FROM (
            SELECT y.*,
                   ROW_NUMBER() OVER (
                     PARTITION BY y.tipo_ident, TRIM(y.nro_documento)
                     ORDER BY CASE y.relacion
                                WHEN '1' THEN 1
                                WHEN 'P' THEN 1
                                WHEN '2' THEN 2
                                WHEN 'C' THEN 2
                                ELSE 9
                              END,
                              y.cod_persona
                   ) rn
              FROM (
                SELECT DISTINCT
                       NVL(CAST(v.tip_vinculo AS VARCHAR2(10)), '1') AS relacion,
                       UPPER(TRIM(doc.abreviatura)) AS tipo_ident,
                       TRIM(per.nro_documento) AS nro_documento,
                       CASE WHEN per.tipo = 'F' THEN '002' ELSE '001' END AS tipo_per,
                       CASE WHEN per.tipo = 'F'
                            THEN TRIM(TRIM(bf.pri_apellido) || ' ' || TRIM(bf.seg_apellido))
                            ELSE NULL
                       END AS apellido,
                       CASE WHEN per.tipo = 'F'
                            THEN TRIM(TRIM(bf.pri_nombre) || ' ' || TRIM(bf.seg_nombre))
                            ELSE TRIM(per.nom_completo)
                       END AS nombre,
                       CASE WHEN per.tipo = 'F' THEN bf.fec_nacimiento ELSE NULL END AS fecha_nac,
                       CASE WHEN per.tipo = 'F'
                            THEN CASE UPPER(TRIM(bf.cod_sexo))
                                   WHEN 'F' THEN 'F'
                                   WHEN 'M' THEN 'M'
                                   ELSE UPPER(TRIM(bf.cod_sexo))
                                 END
                            ELSE 'N'
                       END AS genero,
                       UPPER(TRIM(pai.cod_pai_iso)) AS pais_nacimiento,
                       bci.ref_externa AS ciudad_nacimiento,
                       per.fec_vto_documento AS fecha_venc_doc,
                       per.cod_persona AS cod_persona,
                       bpj.naturaleza  AS naturaleza
                  FROM (
                    SELECT DISTINCT cod_persona,
                           MIN(CAST(tip_vinculo AS VARCHAR2(10))) KEEP (DENSE_RANK FIRST ORDER BY NVL(CAST(tip_vinculo AS VARCHAR2(10)),'999')) tip_vinculo
                      FROM IT.SB_CRC_VINCULOS_DET
                     WHERE fecha >= TRUNC(p_fecha)
                       AND fecha <  TRUNC(p_fecha) + 1
                       AND nom_referencia = 'VINCULOS'
                       AND nro_formulario IN ('002','2')
                       AND cod_persona IS NOT NULL
                     GROUP BY cod_persona
                  ) v
                  JOIN IT.BA_PERSONAS per
                    ON per.cod_persona = v.cod_persona
                  JOIN IT.BA_TIP_DOCUMENTOS doc
                    ON doc.cod_tip_documento = per.cod_tip_documento
                  LEFT JOIN IT.BA_PER_FISICAS bf
                    ON bf.cod_persona = per.cod_persona
                  LEFT JOIN IT.BA_PAISES pai
                    ON pai.cod_pais = bf.cod_pai_nacionalidad
                  LEFT JOIN IT.BA_CIUDADES bci
                    ON bci.cod_ciudad = bf.cod_ciu_nacimiento
                   AND bci.cod_pais = pai.cod_pais
                  LEFT JOIN IT.BA_PER_JURIDICAS bpj
                    ON bpj.cod_persona = per.cod_persona
                 WHERE NOT EXISTS (
                         SELECT 1
                           FROM IT.SB_BCP_PERSONAS_REF r
                          WHERE r.rf_tipo_ident = CASE UPPER(TRIM(doc.abreviatura))
                                                     WHEN 'RUC' THEN 'RU'
                                                     WHEN 'CRC' THEN 'CR'
                                                     WHEN 'CRP' THEN 'CR'
                                                     ELSE UPPER(TRIM(doc.abreviatura))
                                                   END
                            AND r.rf_numero = TRIM(per.nro_documento)
                       )
              ) y
          )
         WHERE rn = 1
      ) z;

    v_cnt := SQL%ROWCOUNT;
    COMMIT;

    pr_log_regla(
      p_id,
      'U02',
      'Personas candidatas luego de cruce exacto CRC02 vs SB_BCP_PERSONAS_REF',
      'Universo CF: CRC02 menos SB_BCP_PERSONAS_REF exacto',
      v_cnt,
      'CONTROL: candidatas CF antes de normalizaciones/validaciones'
    );

    pr_log_regla(
      p_id,
      'R00',
      'Candidatos CF construidos desde CRC 02 y BA_PERSONAS',
      'Universo: SB_CRC_VINCULOS_DET formulario 002 para la fecha de cierre',
      v_cnt,
      'CANDIDATOS: ' || v_cnt || ' personas CRC02 luego de deduplicacion por tipo/doc'
    );
  END pr_construir_candidatos;

  ------------------------------------------------------------------------------
  -- NORMALIZACIONES Y CORRECCIONES SEGURAS
  ------------------------------------------------------------------------------
  PROCEDURE pr_normalizar_textos(p_id IN NUMBER) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_cnt
      FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id;

    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.TIPO_IDENT      = UPPER(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.TIPO_IDENT,CHR(160),' '),CHR(9),' '),CHR(10),' '),CHR(13),' '),';',' '))),
           a.NRO_DOCUMENTO   = TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.NRO_DOCUMENTO,CHR(160),' '),CHR(9),' '),CHR(10),' '),CHR(13),' '),';',' ')),
           a.TIPO_PER        = TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.TIPO_PER,CHR(160),' '),CHR(9),' '),CHR(10),' '),CHR(13),' '),';',' ')),
           a.APELLIDO        = SUBSTR(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.APELLIDO,CHR(160),' '),CHR(38)||'AMP;',CHR(38)),CHR(38)||'amp;',CHR(38)),CHR(9),' '),CHR(10),' '),CHR(13),' '),';',' ')),1,120),
           a.NOMBRE          = SUBSTR(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.NOMBRE,CHR(160),' '),CHR(38)||'AMP;',CHR(38)),CHR(38)||'amp;',CHR(38)),CHR(9),' '),CHR(10),' '),CHR(13),' '),';',' ')),1,120),
           a.GENERO          = UPPER(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.GENERO,CHR(160),' '),CHR(9),' '),CHR(10),' '),CHR(13),' '),';',' '))),
           a.PAIS_NACIMIENTO = UPPER(TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(a.PAIS_NACIMIENTO,CHR(160),' '),CHR(9),' '),CHR(10),' '),CHR(13),' '),';',' ')))
     WHERE a.ID_EJECUCION = p_id;

    COMMIT;

    pr_log_regla(
      p_id,
      'C00',
      'Normalizacion tecnica de textos',
      'Manual Tecnico CF Personas: sin espacios al inicio/final y sin separador interno',
      v_cnt,
      'NORMALIZAR: trim, limpieza CHR(160), saltos/tabs, ; internos y entidad &AMP;'
    );
  END pr_normalizar_textos;

  PROCEDURE pr_corr_pas_a_crc(p_id IN NUMBER) IS
  BEGIN
    pr_registrar_correccion(
      p_id,
      'C01',
      'Tipo documento PAS informado como CRC',
      'Circular SB.SG. Nro 57/2021 - personas no residentes se informan como CRC',
      'Se cambia TIPO_IDENT PAS a CRC',
      'a.TIPO_IDENT = ''PAS''',
      'a.TIPO_IDENT',
      '''CRC'''
    );

    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.TIPO_IDENT = 'CRC'
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'PAS';

    COMMIT;
  END pr_corr_pas_a_crc;

  PROCEDURE pr_corr_juridicas(p_id IN NUMBER) IS
  BEGIN
    pr_registrar_correccion(
      p_id,
      'C02',
      'Persona juridica debe tener solo nombre, genero N y fecha vencimiento vacia',
      'BCP CK_TMP_CF_01_PERS_JUR_APE / CK_TMP_CF_01_FECHA_VENC_JURIDICO',
      'Se vacian apellidos y fecha de vencimiento; genero se fuerza a N',
      'a.TIPO_PER = ''001'' AND (a.APELLIDO IS NOT NULL OR NVL(a.GENERO,''X'') <> ''N'' OR a.FECHA_VENC_DOC IS NOT NULL)',
      'NVL(a.APELLIDO,'''') || ''|'' || NVL(a.GENERO,'''') || ''|'' || NVL(TO_CHAR(a.FECHA_VENC_DOC,''YYYYMMDD''),'''')',
      '''APELLIDO=NULL|GENERO=N|FECHA_VENC_DOC=NULL'''
    );

    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.APELLIDO      = NULL,
           a.GENERO        = 'N',
           a.FECHA_VENC_DOC = NULL
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_PER = '001'
       AND (a.APELLIDO IS NOT NULL OR NVL(a.GENERO,'X') <> 'N' OR a.FECHA_VENC_DOC IS NOT NULL);

    COMMIT;
  END pr_corr_juridicas;

  PROCEDURE pr_corr_ruc_pais_py(p_id IN NUMBER) IS
  BEGIN
    pr_registrar_correccion(
      p_id,
      'C03',
      'RUC sin pais de nacimiento se informa como PY',
      'Regla funcional: RUC corresponde a persona juridica residente Paraguay',
      'Se defaulta PAIS_NACIMIENTO a PY para RUC sin pais',
      'a.TIPO_IDENT = ''RUC'' AND (a.PAIS_NACIMIENTO IS NULL OR TRIM(a.PAIS_NACIMIENTO) IS NULL)',
      'NVL(a.PAIS_NACIMIENTO,''NULL'')',
      '''PY'''
    );

    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.PAIS_NACIMIENTO = 'PY'
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'RUC'
       AND (a.PAIS_NACIMIENTO IS NULL OR TRIM(a.PAIS_NACIMIENTO) IS NULL);

    COMMIT;
  END pr_corr_ruc_pais_py;

  PROCEDURE pr_corr_ruc_guion(p_id IN NUMBER) IS
  BEGIN
    pr_registrar_correccion(
      p_id,
      'C04',
      'RUC numerico sin guion se normaliza con digito verificador',
      'Manual Tecnico BCP: RUC debe incluir digito verificador con guion',
      'Se inserta guion antes del ultimo digito',
      'a.TIPO_IDENT = ''RUC'' AND REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), ''^[0-9]{2,}$'')',
      'a.NRO_DOCUMENTO',
      'SUBSTR(TRIM(a.NRO_DOCUMENTO),1,LENGTH(TRIM(a.NRO_DOCUMENTO))-1) || ''-'' || SUBSTR(TRIM(a.NRO_DOCUMENTO),-1)'
    );

    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.NRO_DOCUMENTO = SUBSTR(TRIM(a.NRO_DOCUMENTO),1,LENGTH(TRIM(a.NRO_DOCUMENTO))-1)
                             || '-' ||
                             SUBSTR(TRIM(a.NRO_DOCUMENTO),-1)
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'RUC'
       AND REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), '^[0-9]{2,}$');

    COMMIT;
  END pr_corr_ruc_guion;


  PROCEDURE pr_corr_ci_guion_sufijo(p_id IN NUMBER) IS
  BEGIN
    -- C06: CI con guion y un digito final (ej. 6128113-4) no debe informarse
    -- quitando solo el guion. En SB_BCP_PERSONAS_REF/BCP la CI existe como 6128113,
    -- por lo tanto se elimina el sufijo -D completo.
    pr_registrar_correccion(
      p_id,
      'C06',
      'CI con guion final se normaliza quitando sufijo verificador',
      'BCP CK_TMP_CF_01_DOC_VALIDO_AP - CI debe informarse como numero de cedula sin sufijo',
      'Se transforma CI N-D a N',
      'a.TIPO_IDENT = ''CI'' AND REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), ''^[0-9]+-[0-9]$'')',
      'a.NRO_DOCUMENTO',
      'REGEXP_REPLACE(TRIM(a.NRO_DOCUMENTO), ''-[0-9]$'', '''')'
    );

    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.NRO_DOCUMENTO = REGEXP_REPLACE(TRIM(a.NRO_DOCUMENTO), '-[0-9]$', '')
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'CI'
       AND REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), '^[0-9]+-[0-9]$');

    COMMIT;
  END pr_corr_ci_guion_sufijo;

  PROCEDURE pr_corr_crc_documento(p_id IN NUMBER) IS
  BEGIN
    pr_registrar_correccion(
      p_id,
      'C05',
      'CRC normalizado con prefijo pais, sin puntos y sin ceros iniciales',
      'Circular SB.SG. Nro 57/2021: CRC = codigo pais + numero documento sin puntos ni ceros al frente',
      'Se normaliza documento CRC cuando la correccion es deterministica',
      'a.TIPO_IDENT = ''CRC'' AND NVL(TRIM(a.NRO_DOCUMENTO),''#'') <> NVL(TRIM(CASE WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),''.'',''''), ''^[A-Z]{2}'') THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),''.'',''''), ''^([A-Z]{2})0+'', ''\1'') WHEN a.PAIS_NACIMIENTO IS NOT NULL THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),''.'',''''),''0'') ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),''.'','''') END),''#'')',
      'a.NRO_DOCUMENTO',
      'CASE WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),''.'',''''), ''^[A-Z]{2}'') THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),''.'',''''), ''^([A-Z]{2})0+'', ''\1'') WHEN a.PAIS_NACIMIENTO IS NOT NULL THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),''.'',''''),''0'') ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),''.'','''') END'
    );

    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.NRO_DOCUMENTO = CASE
                               WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^[A-Z]{2}')
                               THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^([A-Z]{2})0+', '\1')
                               WHEN a.PAIS_NACIMIENTO IS NOT NULL
                               THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
                               ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),'.','')
                             END
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'CRC'
       AND NVL(TRIM(a.NRO_DOCUMENTO),'#') <>
           NVL(TRIM(CASE
                      WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^[A-Z]{2}')
                      THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^([A-Z]{2})0+', '\1')
                      WHEN a.PAIS_NACIMIENTO IS NOT NULL
                      THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
                      ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),'.','')
                    END),'#');

    COMMIT;
  END pr_corr_crc_documento;

  PROCEDURE pr_aplicar_correcciones_seguras(p_id IN NUMBER) IS
  BEGIN
    -- C00 se ejecuta antes de los pre-checks contra SB_BCP_PERSONAS_REF para conservar
    -- R09x/R12x con el tipo original de documento (CRC/PAS) y evitar regresiones
    -- de performance en R31.
    pr_corr_pas_a_crc(p_id);
    pr_corr_juridicas(p_id);
    pr_corr_ruc_pais_py(p_id);
    pr_corr_ruc_guion(p_id);
    pr_corr_ci_guion_sufijo(p_id);
    pr_corr_crc_documento(p_id);
  END pr_aplicar_correcciones_seguras;

  ------------------------------------------------------------------------------
  -- VALIDACIONES BCP / REGLAS DE NEGOCIO
  ------------------------------------------------------------------------------
  PROCEDURE pr_val_tipo_documento(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V01',
      'Tipo de documento de identidad incorrecto',
      'BCP CK_TMP_CF_01_TIPO_DOC',
      'Tipo documento fuera de CI/CRC/CRP/RUC',
      'a.TIPO_IDENT IS NULL OR a.TIPO_IDENT NOT IN (''CI'',''CRC'',''CRP'',''RUC'')'
    );
  END pr_val_tipo_documento;

  PROCEDURE pr_val_documento_obligatorio(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V02',
      'Numero de documento obligatorio',
      'Manual Tecnico CF Personas campo numero_documento',
      'Numero de documento nulo o vacio',
      'a.NRO_DOCUMENTO IS NULL OR TRIM(a.NRO_DOCUMENTO) IS NULL'
    );
  END pr_val_documento_obligatorio;

  PROCEDURE pr_val_tipo_persona(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V03',
      'Codigo de Tipo de personas invalido',
      'BCP CK_TMP_CF_01_TIPO_PER',
      'Tipo persona fuera de 001/002/003',
      'a.TIPO_PER IS NULL OR a.TIPO_PER NOT IN (''001'',''002'',''003'')'
    );
  END pr_val_tipo_persona;

  PROCEDURE pr_val_pais_nacimiento(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V04',
      'Pais de nacimiento no puede ser nulo o vacio',
      'BCP CK_TMP_CF_01_PAIS_NACIMIENTO',
      'PAIS_NACIMIENTO vacio',
      'a.PAIS_NACIMIENTO IS NULL OR TRIM(a.PAIS_NACIMIENTO) IS NULL'
    );
  END pr_val_pais_nacimiento;

  PROCEDURE pr_val_ciudad_nacimiento(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V05A',
      'Ciudad de nacimiento obligatoria para pais PY',
      'BCP CK_TMP_CF_01_CIUDAD_NACIMIENTO',
      'PAIS_NACIMIENTO=PY sin CIUDAD_NACIMIENTO; requiere completar o gestionar alta de ciudad BCP',
      'a.PAIS_NACIMIENTO = ''PY'' AND a.CIUDAD_NACIMIENTO IS NULL'
    );

    pr_excluir_regla(
      p_id,
      'V05B',
      'Codigo de Ciudad de nacimiento inexistente en Pais de nacimiento',
      'BCP CK_TMP_CF_01_CIUDAD_NACIMIENTO',
      'CIUDAD_NACIMIENTO no existe para el PAIS_NACIMIENTO informado',
      'a.CIUDAD_NACIMIENTO IS NOT NULL
       AND NOT EXISTS (
             SELECT 1
               FROM IT.BA_PAISES p
               JOIN IT.BA_CIUDADES c ON c.cod_pais = p.cod_pais
              WHERE p.cod_pai_iso = a.PAIS_NACIMIENTO
                AND c.ref_externa = a.CIUDAD_NACIMIENTO
           )'
    );
  END pr_val_ciudad_nacimiento;

  PROCEDURE pr_val_persona_fisica(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V06',
      'Persona fisica debe tener nombre y apellido',
      'BCP CK_TMP_CF_01_PERS_FIS_NOM_APE',
      'Persona fisica sin nombre o sin apellido',
      'a.TIPO_PER IN (''002'',''003'')
       AND (a.NOMBRE IS NULL OR TRIM(a.NOMBRE) IS NULL OR a.APELLIDO IS NULL OR TRIM(a.APELLIDO) IS NULL)'
    );

    pr_excluir_regla(
      p_id,
      'V07',
      'Persona fisica no puede tener tipo de documento RUC',
      'BCP CK_TMP_CF_01_PERS_FIS_TIPO_DOC',
      'Persona fisica con documento RUC',
      'a.TIPO_PER IN (''002'',''003'') AND a.TIPO_IDENT = ''RUC'''
    );

    pr_excluir_regla(
      p_id,
      'V07B',
      'RUC de persona fisica registrado en BA_PERSONAS',
      'BCP CK_TMP_CF_01_PERS_FIS_TIPO_DOC / PERS_JUR_TIPO_DOC',
      'COD_PERSONA registrado como F en Bankiti con tipo documento RUC',
      'a.TIPO_IDENT = ''RUC''
       AND EXISTS (
             SELECT 1
               FROM IT.BA_PERSONAS p
               JOIN IT.BA_TIP_DOCUMENTOS d ON d.cod_tip_documento = p.cod_tip_documento
              WHERE p.cod_persona = a.COD_PERSONA
                AND p.tipo = ''F''
                AND UPPER(TRIM(d.abreviatura)) = ''RUC''
           )'
    );

    pr_excluir_regla(
      p_id,
      'V08',
      'Persona fisica con genero invalido',
      'Manual Tecnico CF Personas Anexo Genero',
      'Genero de persona fisica fuera de F/M',
      'a.TIPO_PER IN (''002'',''003'') AND (a.GENERO IS NULL OR a.GENERO NOT IN (''F'',''M''))'
    );

    pr_excluir_regla(
      p_id,
      'V09',
      'Persona fisica con fecha de nacimiento nula o futura',
      'BCP: fecha_nacimiento obligatoria para persona fisica y menor a fecha actual',
      'FECHA_NAC nula o mayor/igual a hoy',
      'a.TIPO_PER IN (''002'',''003'') AND (a.FECHA_NAC IS NULL OR a.FECHA_NAC >= TRUNC(SYSDATE))'
    );

    pr_excluir_regla(
      p_id,
      'V10',
      'Fecha de vencimiento debe ser mayor a la fecha actual',
      'BCP CK_TMP_CF_01_FECHA_VENC_MAYOR',
      'FECHA_VENC_DOC informada y menor/igual a hoy',
      'a.TIPO_PER IN (''002'',''003'') AND a.FECHA_VENC_DOC IS NOT NULL AND a.FECHA_VENC_DOC <= TRUNC(SYSDATE)'
    );
  END pr_val_persona_fisica;

  PROCEDURE pr_val_persona_juridica(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V11',
      'Persona juridica debe tener solo nombre',
      'BCP CK_TMP_CF_01_PERS_JUR_APE',
      'Persona juridica con apellido informado luego de correcciones',
      'a.TIPO_PER = ''001'' AND a.APELLIDO IS NOT NULL'
    );

    pr_excluir_regla(
      p_id,
      'V12',
      'Persona juridica debe tener tipo de documento RUC o CRC',
      'BCP CK_TMP_CF_01_PERS_JUR_TIPO_DOC',
      'Persona juridica con tipo documento distinto de RUC/CRC',
      'a.TIPO_PER = ''001'' AND a.TIPO_IDENT NOT IN (''RUC'',''CRC'')'
    );

    pr_excluir_regla(
      p_id,
      'V13',
      'Fecha de vencimiento debe ser vacia para personas juridicas',
      'BCP CK_TMP_CF_01_FECHA_VENC_JURIDICO',
      'Persona juridica con FECHA_VENC_DOC informada luego de correcciones',
      'a.TIPO_PER = ''001'' AND a.FECHA_VENC_DOC IS NOT NULL'
    );

    pr_excluir_regla(
      p_id,
      'V14',
      'Persona juridica debe tener genero N',
      'Manual Tecnico CF Personas Anexo Genero',
      'Persona juridica con genero distinto de N',
      'a.TIPO_PER = ''001'' AND NVL(a.GENERO,''X'') <> ''N'''
    );
  END pr_val_persona_juridica;

  PROCEDURE pr_val_crc(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V14C',
      'CRC con espacios internos no debe informarse',
      'BCP CK_TMP_CF_01_DOC_VALIDO_AP - numero de documento CRC invalido',
      'CRC contiene espacios internos; requiere revision documental o correccion en origen',
      'a.TIPO_IDENT = ''CRC'' AND REGEXP_LIKE(a.NRO_DOCUMENTO, ''[[:space:]]'')'
    );

    pr_excluir_regla(
      p_id,
      'V15',
      'Para documento CRC, SWIFT no puede ser PY',
      'BCP CK_TMP_CF_01_CRC_SWIFT',
      'CRC con PAIS_NACIMIENTO PY',
      'a.TIPO_IDENT = ''CRC'' AND a.PAIS_NACIMIENTO = ''PY'''
    );

    pr_excluir_regla(
      p_id,
      'V16',
      'CRC debe iniciar con prefijo pais valido y coincidir con PAIS_NACIMIENTO',
      'BCP CK_TMP_CF_01_PAIS_DOC_NRO_VALIDO_AP',
      'CRC sin prefijo pais o con prefijo distinto al pais informado',
      'a.TIPO_IDENT = ''CRC''
       AND (NOT REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), ''^[A-Z]{2}.+'')
            OR SUBSTR(TRIM(a.NRO_DOCUMENTO),1,2) <> a.PAIS_NACIMIENTO)'
    );
  END pr_val_crc;

  PROCEDURE pr_val_crp(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V17',
      'Formato CRP debe ser numerico o 9999-999999-XXX',
      'BCP CK_TMP_CF_01_CRP_FORMATO',
      'CRP con formato invalido',
      'a.TIPO_IDENT = ''CRP''
       AND NOT REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), ''^[0-9]+$'')
       AND NOT REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), ''^[0-9]{4}-[0-9]{6}-[A-Z0-9]{3}$'')'
    );
  END pr_val_crp;

  PROCEDURE pr_val_ruc_dv(p_id IN NUMBER) IS
    v_cnt NUMBER := 0;
  BEGIN
    -- V18B: el formato con guion no alcanza; BCP valida que el digito verificador
    -- del RUC corresponda al modulo 11. Se evalua row-by-row solo sobre el lote
    -- sobreviviente y solo para RUC ya formateados, por lo que no impacta performance.
    FOR r IN (
      SELECT a.ROWID rid,
             a.COD_PERSONA,
             a.TIPO_IDENT,
             a.NRO_DOCUMENTO,
             a.TIPO_PER,
             a.NOMBRE,
             a.APELLIDO,
             a.PAIS_NACIMIENTO,
             a.FECHA_NAC,
             a.FECHA_VENC_DOC,
             a.GENERO
        FROM IT.SB_CF_ALT_PERSONAS a
       WHERE a.ID_EJECUCION = p_id
         AND a.TIPO_IDENT = 'RUC'
         AND REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), '^[0-9]+-[0-9]$')
    ) LOOP
      IF fn_ruc_dv_valido(r.NRO_DOCUMENTO) = 0 THEN
        INSERT INTO IT.SB_CF_EXCL_DETALLE
          (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
           TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
           PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
           MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
        VALUES
          (p_id, 'V18B', 'EXCLUIR', r.COD_PERSONA,
           r.TIPO_IDENT, r.NRO_DOCUMENTO, r.TIPO_PER, r.NOMBRE, r.APELLIDO,
           r.PAIS_NACIMIENTO, r.FECHA_NAC, r.FECHA_VENC_DOC, r.GENERO,
           'RUC con digito verificador invalido segun modulo 11',
           SUBSTR(NVL(r.TIPO_IDENT,'') || '/' || NVL(r.NRO_DOCUMENTO,''),1,200),
           NULL);

        DELETE FROM IT.SB_CF_ALT_PERSONAS a
         WHERE a.ROWID = r.rid;

        v_cnt := v_cnt + 1;
      END IF;
    END LOOP;

    IF v_cnt > 0 THEN
      pr_log_regla(
        p_id,
        'V18B',
        'RUC con digito verificador invalido',
        'BCP CK_TMP_CF_01_DOC_VALIDO_AP / algoritmo RUC modulo 11',
        v_cnt,
        'EXCLUIR: RUC con DV invalido - ' || v_cnt || ' registros'
      );
      COMMIT;
    END IF;
  END pr_val_ruc_dv;

  PROCEDURE pr_val_ruc(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'V18',
      'RUC con formato invalido',
      'Manual Tecnico BCP: RUC debe incluir digito verificador con guion',
      'RUC no cumple formato numerico con guion y digito verificador',
      'a.TIPO_IDENT = ''RUC'' AND NOT REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), ''^[0-9]+-[0-9]$'')'
    );

    pr_val_ruc_dv(p_id);

    pr_excluir_regla(
      p_id,
      'V19',
      'Este RUC no debe ser informado',
      'BCP CK_TMP_CF_01_RUC_BCP',
      'RUC correspondiente al Banco Central del Paraguay',
      'a.TIPO_IDENT = ''RUC''
       AND (REPLACE(TRIM(a.NRO_DOCUMENTO),''-'','''') = ''800097696''
            OR UPPER(TRIM(a.NOMBRE)) = ''BANCO CENTRAL DEL PARAGUAY'')'
    );
  END pr_val_ruc;

  PROCEDURE pr_validar_reglas_bcp(p_id IN NUMBER) IS
  BEGIN
    pr_val_tipo_documento(p_id);
    pr_val_documento_obligatorio(p_id);
    pr_val_tipo_persona(p_id);
    -- V04/V05 deshabilitados - Pedido Anghelo: incluir registros con pais/ciudad nacimiento vacios
    -- pr_val_pais_nacimiento(p_id);
    -- pr_val_ciudad_nacimiento(p_id);
    pr_val_persona_fisica(p_id);
    pr_val_persona_juridica(p_id);
    pr_val_crc(p_id);
    pr_val_crp(p_id);
    pr_val_ruc(p_id);
  END pr_validar_reglas_bcp;

  ------------------------------------------------------------------------------
  -- PRE-CHECKS CONTRA SB_BCP_PERSONAS_REF
  --
  -- Estos controles mantienen la idea de R09x/R12x/R21 del setup original:
  -- resolver los casos corregibles contra SB_BCP_PERSONAS_REF antes del R31 final.
  -- R31 queda solo con match exacto indexable por RF_TIPO_IDENT/RF_NUMERO.
  ------------------------------------------------------------------------------
  -- R07C: Empresario individual (NATURALEZA=21) cuyo CI-equivalente (RUC sin DV)
  -- ya existe en SB_BCP_PERSONAS_REF como CI -> excluir (persona natural ya registrada en BCP).
  PROCEDURE pr_precheck_r07c_nat21_ci(p_id IN NUMBER) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_cnt
      FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'RUC'
       AND a.NATURALEZA = 21
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CI'
                AND r.rf_numero = REGEXP_REPLACE(TRIM(a.NRO_DOCUMENTO), '-[0-9]+$', '')
           );

    IF v_cnt = 0 THEN
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      'R07C',
      'Empresario individual (NATURALEZA=21): CI-equivalente ya en padron BCP',
      'Inteligencia adicional: RUC de persona natural coincide con CI en SB_BCP_PERSONAS_REF',
      v_cnt,
      'EXCLUIR: CI-equivalente ya en BCP como CI - ' || v_cnt || ' registros'
    );

    INSERT INTO IT.SB_CF_EXCL_DETALLE
      (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
       TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
       PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
       MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
    SELECT p_id,
           'R07C',
           'EXCLUIR',
           a.COD_PERSONA,
           a.TIPO_IDENT,
           a.NRO_DOCUMENTO,
           a.TIPO_PER,
           a.NOMBRE,
           a.APELLIDO,
           a.PAIS_NACIMIENTO,
           a.FECHA_NAC,
           a.FECHA_VENC_DOC,
           a.GENERO,
           'Empresario individual (NATURALEZA=21): CI ' ||
             REGEXP_REPLACE(TRIM(a.NRO_DOCUMENTO), '-[0-9]+$', '') ||
             ' ya registrado en padron BCP como CI',
           a.TIPO_IDENT || '/' || a.NRO_DOCUMENTO,
           'CI/' || REGEXP_REPLACE(TRIM(a.NRO_DOCUMENTO), '-[0-9]+$', '')
      FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'RUC'
       AND a.NATURALEZA = 21
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CI'
                AND r.rf_numero = REGEXP_REPLACE(TRIM(a.NRO_DOCUMENTO), '-[0-9]+$', '')
           );

    DELETE FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'RUC'
       AND a.NATURALEZA = 21
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CI'
                AND r.rf_numero = REGEXP_REPLACE(TRIM(a.NRO_DOCUMENTO), '-[0-9]+$', '')
           );

    COMMIT;
  END pr_precheck_r07c_nat21_ci;

  PROCEDURE pr_precheck_r09x_crc_sin_prefijo(p_id IN NUMBER) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_cnt
      FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'CRC'
       AND a.PAIS_NACIMIENTO IS NOT NULL
       AND NOT REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), '^[A-Z]{2}')
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CR'
                AND r.rf_numero = a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
           );

    IF v_cnt = 0 THEN
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      'R09x',
      'CRC sin prefijo: doc corregido ya existe en padron BCP',
      'R06 diferido: pais_nacimiento||LTRIM(nro_doc) ya registrado como CR en SB_BCP_PERSONAS_REF',
      v_cnt,
      'EXCLUIR: pre-check exacto antes de normalizar CRC - ' || v_cnt || ' registros'
    );

    INSERT INTO IT.SB_CF_EXCL_DETALLE
      (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
       TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
       PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
       MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
    SELECT p_id,
           'R09x',
           'EXCLUIR',
           a.COD_PERSONA,
           a.TIPO_IDENT,
           a.NRO_DOCUMENTO,
           a.TIPO_PER,
           a.NOMBRE,
           a.APELLIDO,
           a.PAIS_NACIMIENTO,
           a.FECHA_NAC,
           a.FECHA_VENC_DOC,
           a.GENERO,
           'CRC sin prefijo corregido ya registrado en SB_BCP_PERSONAS_REF como CR',
           SUBSTR(a.NRO_DOCUMENTO,1,200),
           SUBSTR(a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0'),1,200)
      FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'CRC'
       AND a.PAIS_NACIMIENTO IS NOT NULL
       AND NOT REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), '^[A-Z]{2}')
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CR'
                AND r.rf_numero = a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
           );

    DELETE FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'CRC'
       AND a.PAIS_NACIMIENTO IS NOT NULL
       AND NOT REGEXP_LIKE(TRIM(a.NRO_DOCUMENTO), '^[A-Z]{2}')
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CR'
                AND r.rf_numero = a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
           );

    COMMIT;
  END pr_precheck_r09x_crc_sin_prefijo;

  PROCEDURE pr_precheck_r12x_pas_a_crc(p_id IN NUMBER) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_cnt
      FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'PAS'
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CR'
                AND r.rf_numero =
                    CASE
                      WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^[A-Z]{2}')
                      THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^([A-Z]{2})0+', '\1')
                      WHEN a.PAIS_NACIMIENTO IS NOT NULL
                      THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
                      ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),'.','')
                    END
           );

    IF v_cnt = 0 THEN
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      'R12x',
      'PAS convertido a CRC: doc corregido ya existe en padron BCP',
      'R06 diferido: pasaporte como CRC ya registrado como CR en SB_BCP_PERSONAS_REF',
      v_cnt,
      'EXCLUIR: pre-check exacto antes de convertir PAS a CRC - ' || v_cnt || ' registros'
    );

    INSERT INTO IT.SB_CF_EXCL_DETALLE
      (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
       TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
       PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
       MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
    SELECT p_id,
           'R12x',
           'EXCLUIR',
           a.COD_PERSONA,
           a.TIPO_IDENT,
           a.NRO_DOCUMENTO,
           a.TIPO_PER,
           a.NOMBRE,
           a.APELLIDO,
           a.PAIS_NACIMIENTO,
           a.FECHA_NAC,
           a.FECHA_VENC_DOC,
           a.GENERO,
           'PAS convertido a CRC ya registrado en SB_BCP_PERSONAS_REF como CR',
           SUBSTR('PAS/' || a.NRO_DOCUMENTO,1,200),
           SUBSTR('CRC/' ||
             CASE
               WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^[A-Z]{2}')
               THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^([A-Z]{2})0+', '\1')
               WHEN a.PAIS_NACIMIENTO IS NOT NULL
               THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
               ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),'.','')
             END,1,200)
      FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'PAS'
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CR'
                AND r.rf_numero =
                    CASE
                      WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^[A-Z]{2}')
                      THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^([A-Z]{2})0+', '\1')
                      WHEN a.PAIS_NACIMIENTO IS NOT NULL
                      THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
                      ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),'.','')
                    END
           );

    DELETE FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND a.TIPO_IDENT = 'PAS'
       AND EXISTS (
             SELECT 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = 'CR'
                AND r.rf_numero =
                    CASE
                      WHEN REGEXP_LIKE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^[A-Z]{2}')
                      THEN REGEXP_REPLACE(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''), '^([A-Z]{2})0+', '\1')
                      WHEN a.PAIS_NACIMIENTO IS NOT NULL
                      THEN a.PAIS_NACIMIENTO || LTRIM(REPLACE(TRIM(a.NRO_DOCUMENTO),'.',''),'0')
                      ELSE REPLACE(TRIM(a.NRO_DOCUMENTO),'.','')
                    END
           );

    COMMIT;
  END pr_precheck_r12x_pas_a_crc;

  PROCEDURE pr_precheck_personas_ref_pre_correccion(p_id IN NUMBER) IS
  BEGIN
    pr_precheck_r07c_nat21_ci(p_id);
    pr_precheck_r09x_crc_sin_prefijo(p_id);
    pr_precheck_r12x_pas_a_crc(p_id);
  END pr_precheck_personas_ref_pre_correccion;

  PROCEDURE pr_precheck_r21_guion_cr(p_id IN NUMBER) IS
    v_cnt NUMBER := 0;
  BEGIN
    /*
      R21 OPTIMIZADO
      Versión anterior: REPLACE(r.rf_numero,'-','') = REPLACE(a.nro_documento,'-','')
      sobre SB_BCP_PERSONAS_REF. Aunque se filtre por rf_tipo_ident='CR', puede forzar
      escaneo/range scan grande y se ejecutaba más de una vez.

      Versión optimizada:
        - Se generan variantes probables del documento del lote chico.
        - Se busca SB_BCP_PERSONAS_REF por igualdad exacta r.rf_numero = variante.
        - Usa índice (RF_TIPO_IDENT, RF_NUMERO).
        - SB_BCP_PERSONAS_REF se consulta una sola vez para registrar el detalle.
        - El DELETE se hace contra SB_CF_EXCL_DETALLE, sin volver a consultar SB_BCP_PERSONAS_REF.
    */
    INSERT INTO IT.SB_CF_EXCL_DETALLE
      (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
       TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
       PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
       MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
    WITH cand AS (
      SELECT /*+ MATERIALIZE */
             a.ROWID rid,
             a.COD_PERSONA,
             a.TIPO_IDENT,
             TRIM(a.NRO_DOCUMENTO) NRO_DOCUMENTO,
             a.TIPO_PER,
             a.NOMBRE,
             a.APELLIDO,
             a.PAIS_NACIMIENTO,
             a.FECHA_NAC,
             a.FECHA_VENC_DOC,
             a.GENERO,
             REPLACE(TRIM(a.NRO_DOCUMENTO), '-', '') NRO_NORM
        FROM IT.SB_CF_ALT_PERSONAS a
       WHERE a.ID_EJECUCION = p_id
         AND a.TIPO_IDENT IN ('CRC','CRP')
         AND a.NRO_DOCUMENTO IS NOT NULL
    ), variantes AS (
      -- Variante 1: documento sin guiones
      SELECT rid, NRO_NORM variante
        FROM cand
       WHERE NRO_NORM IS NOT NULL
      UNION ALL
      -- Variante 2: guion antes del último caracter. Cubre casos tipo UY44660545 -> UY4466054-5.
      SELECT rid,
             SUBSTR(NRO_NORM, 1, LENGTH(NRO_NORM) - 1) || '-' || SUBSTR(NRO_NORM, -1) variante
        FROM cand
       WHERE LENGTH(NRO_NORM) > 1
      UNION ALL
      -- Variante 3: guion antes de los últimos 2 caracteres.
      -- Cubre casos reales BCP: BR1235898946 -> BR12358989-46.
      SELECT rid,
             SUBSTR(NRO_NORM, 1, LENGTH(NRO_NORM) - 2) || '-' || SUBSTR(NRO_NORM, -2) variante
        FROM cand
       WHERE LENGTH(NRO_NORM) > 2
      UNION ALL
      -- Variante 4: espacio luego del código país ISO de 2 letras.
      -- Cubre representaciones con separador país/documento.
      SELECT rid,
             SUBSTR(NRO_NORM, 1, 2) || ' ' || SUBSTR(NRO_NORM, 3) variante
        FROM cand
       WHERE REGEXP_LIKE(NRO_NORM, '^[A-Z]{2}.+')
      UNION ALL
      -- Variante 5: espacio luego de los primeros 3 caracteres.
      -- Cubre caso real: ITB700454 -> ITB 700454.
      SELECT rid,
             SUBSTR(NRO_NORM, 1, 3) || ' ' || SUBSTR(NRO_NORM, 4) variante
        FROM cand
       WHERE REGEXP_LIKE(NRO_NORM, '^[A-Z]{3}.+')
      UNION ALL
      -- Variante 6: CRP oficial 9999-999999-XXX desde valor corrido de 13 caracteres.
      SELECT rid,
             SUBSTR(NRO_NORM, 1, 4) || '-' || SUBSTR(NRO_NORM, 5, 6) || '-' || SUBSTR(NRO_NORM, 11) variante
        FROM cand
       WHERE LENGTH(NRO_NORM) = 13
    ), hit AS (
      SELECT /*+ LEADING(v) USE_NL(r) INDEX(r IN_SBPR_NRO_DOCUMENTO) */
             c.COD_PERSONA,
             c.TIPO_IDENT,
             c.NRO_DOCUMENTO,
             c.TIPO_PER,
             c.NOMBRE,
             c.APELLIDO,
             c.PAIS_NACIMIENTO,
             c.FECHA_NAC,
             c.FECHA_VENC_DOC,
             c.GENERO,
             MIN(r.rf_numero) RF_NUMERO_BCP
        FROM variantes v
        JOIN cand c
          ON c.rid = v.rid
        JOIN IT.SB_BCP_PERSONAS_REF r
          ON r.rf_tipo_ident = 'CR'
         AND r.rf_numero     = v.variante
       WHERE v.variante <> c.NRO_DOCUMENTO
       GROUP BY c.COD_PERSONA,
                c.TIPO_IDENT,
                c.NRO_DOCUMENTO,
                c.TIPO_PER,
                c.NOMBRE,
                c.APELLIDO,
                c.PAIS_NACIMIENTO,
                c.FECHA_NAC,
                c.FECHA_VENC_DOC,
                c.GENERO
    )
    SELECT p_id,
           'R21',
           'EXCLUIR',
           h.COD_PERSONA,
           h.TIPO_IDENT,
           h.NRO_DOCUMENTO,
           h.TIPO_PER,
           h.NOMBRE,
           h.APELLIDO,
           h.PAIS_NACIMIENTO,
           h.FECHA_NAC,
           h.FECHA_VENC_DOC,
           h.GENERO,
           'Ya existe en SB_BCP_PERSONAS_REF como CR con guion/formato distinto',
           SUBSTR(h.NRO_DOCUMENTO,1,200),
           SUBSTR(h.RF_NUMERO_BCP,1,200)
      FROM hit h;

    v_cnt := SQL%ROWCOUNT;

    IF v_cnt = 0 THEN
      COMMIT;
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      'R21',
      'CRC/CRP con guion/formato distinto en SB_BCP_PERSONAS_REF - ya en padron BCP',
      'Pre-check optimizado por variantes exactas contra índice RF_TIPO_IDENT/RF_NUMERO',
      v_cnt,
      'EXCLUIR: documento variante ya existe como CR - ' || v_cnt || ' registros'
    );

    DELETE FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND EXISTS (
             SELECT 1
               FROM IT.SB_CF_EXCL_DETALLE e
              WHERE e.ID_EJECUCION = p_id
                AND e.COD_REGLA    = 'R21'
                AND e.COD_PERSONA  = a.COD_PERSONA
                AND e.TIPO_IDENT   = a.TIPO_IDENT
                AND e.NRO_DOCUMENTO = a.NRO_DOCUMENTO
           );

    COMMIT;
  END pr_precheck_r21_guion_cr;

  PROCEDURE pr_precheck_r31_exacto(p_id IN NUMBER) IS
    v_cnt NUMBER := 0;
  BEGIN
    /*
      R31 OPTIMIZADO
      Match exacto contra SB_BCP_PERSONAS_REF usando igualdad sobre RF_TIPO_IDENT/RF_NUMERO.
      No usa funciones sobre SB_BCP_PERSONAS_REF y consulta el padrón una sola vez para
      registrar detalle; luego borra contra SB_CF_EXCL_DETALLE.
    */
    INSERT INTO IT.SB_CF_EXCL_DETALLE
      (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
       TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
       PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
       MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
    SELECT /*+ LEADING(a) USE_NL(r) INDEX(r IN_SBPR_NRO_DOCUMENTO) */
           p_id,
           'R31',
           'EXCLUIR',
           a.COD_PERSONA,
           a.TIPO_IDENT,
           a.NRO_DOCUMENTO,
           a.TIPO_PER,
           a.NOMBRE,
           a.APELLIDO,
           a.PAIS_NACIMIENTO,
           a.FECHA_NAC,
           a.FECHA_VENC_DOC,
           a.GENERO,
           'Tipo/documento final exacto ya registrado en SB_BCP_PERSONAS_REF',
           SUBSTR(a.TIPO_IDENT || '/' || a.NRO_DOCUMENTO,1,200),
           SUBSTR(r.rf_tipo_ident || '/' || r.rf_numero,1,200)
      FROM IT.SB_CF_ALT_PERSONAS a
      JOIN IT.SB_BCP_PERSONAS_REF r
        ON r.rf_tipo_ident = CASE a.TIPO_IDENT
                               WHEN 'RUC' THEN 'RU'
                               WHEN 'CRC' THEN 'CR'
                               WHEN 'CRP' THEN 'CR'
                               ELSE a.TIPO_IDENT
                             END
       AND r.rf_numero = a.NRO_DOCUMENTO
     WHERE a.ID_EJECUCION = p_id;

    v_cnt := SQL%ROWCOUNT;

    IF v_cnt = 0 THEN
      COMMIT;
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      'R31',
      'Documento final ya existe en padron BCP',
      'BCP CK_TMP_CF_01_DOC_EXISTE / CK_TMP_CF_01_EXISTE_PERSONA',
      v_cnt,
      'EXCLUIR: match exacto indexable en SB_BCP_PERSONAS_REF - ' || v_cnt || ' registros'
    );

    DELETE FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ID_EJECUCION = p_id
       AND EXISTS (
             SELECT 1
               FROM IT.SB_CF_EXCL_DETALLE e
              WHERE e.ID_EJECUCION = p_id
                AND e.COD_REGLA    = 'R31'
                AND e.COD_PERSONA  = a.COD_PERSONA
                AND e.TIPO_IDENT   = a.TIPO_IDENT
                AND e.NRO_DOCUMENTO = a.NRO_DOCUMENTO
           );

    COMMIT;
  END pr_precheck_r31_exacto;

  ------------------------------------------------------------------------------
  -- DUPLICADOS CONTRA PADRON Y DENTRO DEL LOTE
  ------------------------------------------------------------------------------
  PROCEDURE pr_excluir_duplicados_lote(p_id IN NUMBER) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_cnt
      FROM (
        SELECT a.ROWID rid,
               ROW_NUMBER() OVER (
                 PARTITION BY a.TIPO_IDENT, TRIM(a.NRO_DOCUMENTO)
                 ORDER BY CASE a.RELACION WHEN 'P' THEN 1 WHEN 'C' THEN 2 ELSE 3 END,
                          a.NRO_LINEA
               ) rn
          FROM IT.SB_CF_ALT_PERSONAS a
         WHERE a.ID_EJECUCION = p_id
      )
     WHERE rn > 1;

    IF v_cnt = 0 THEN
      RETURN;
    END IF;

    pr_log_regla(
      p_id,
      'R08',
      'Documentos duplicados dentro del lote luego de normalizaciones',
      'Control interno: un registro por tipo/documento final',
      v_cnt,
      'EXCLUIR: se conserva prioridad P>C y menor NRO_LINEA'
    );

    INSERT INTO IT.SB_CF_EXCL_DETALLE
      (ID_EJECUCION, COD_REGLA, ACCION, COD_PERSONA,
       TIPO_IDENT, NRO_DOCUMENTO, TIPO_PER, NOMBRE, APELLIDO,
       PAIS_NACIMIENTO, FECHA_NAC, FECHA_VENC_DOC, GENERO,
       MOTIVO, VALOR_ORIGINAL, VALOR_CORREGIDO)
    SELECT p_id,
           'R08',
           'EXCLUIR',
           x.COD_PERSONA,
           x.TIPO_IDENT,
           x.NRO_DOCUMENTO,
           x.TIPO_PER,
           x.NOMBRE,
           x.APELLIDO,
           x.PAIS_NACIMIENTO,
           x.FECHA_NAC,
           x.FECHA_VENC_DOC,
           x.GENERO,
           'Duplicado dentro del lote CF; se conserva el primer registro por prioridad P>C',
           SUBSTR(x.TIPO_IDENT || '/' || x.NRO_DOCUMENTO,1,200),
           NULL
      FROM (
        SELECT a.*,
               ROW_NUMBER() OVER (
                 PARTITION BY a.TIPO_IDENT, TRIM(a.NRO_DOCUMENTO)
                 ORDER BY CASE a.RELACION WHEN 'P' THEN 1 WHEN 'C' THEN 2 ELSE 3 END,
                          a.NRO_LINEA
               ) rn
          FROM IT.SB_CF_ALT_PERSONAS a
         WHERE a.ID_EJECUCION = p_id
      ) x
     WHERE x.rn > 1;

    DELETE FROM IT.SB_CF_ALT_PERSONAS a
     WHERE a.ROWID IN (
       SELECT rid
         FROM (
           SELECT a2.ROWID rid,
                  ROW_NUMBER() OVER (
                    PARTITION BY a2.TIPO_IDENT, TRIM(a2.NRO_DOCUMENTO)
                    ORDER BY CASE a2.RELACION WHEN 'P' THEN 1 WHEN 'C' THEN 2 ELSE 3 END,
                             a2.NRO_LINEA
                  ) rn
             FROM IT.SB_CF_ALT_PERSONAS a2
            WHERE a2.ID_EJECUCION = p_id
         )
        WHERE rn > 1
     );

    COMMIT;
  END pr_excluir_duplicados_lote;

  PROCEDURE pr_controlar_duplicados_bcp(p_id IN NUMBER) IS
  BEGIN
    -- Marca de progreso: si el último log visible era V17 y luego aparece D00,
    -- ya sabemos que las validaciones BCP terminaron y comenzó el bloque de duplicados.
    pr_log_regla(
      p_id,
      'D00',
      'Inicio control de duplicados contra SB_BCP_PERSONAS_REF',
      'Control técnico de progreso',
      0,
      'INICIO: R21 variantes indexables, R31 exacto y duplicados internos'
    );

    pr_precheck_r21_guion_cr(p_id);
    pr_precheck_r31_exacto(p_id);
    pr_excluir_duplicados_lote(p_id);
  END pr_controlar_duplicados_bcp;

  ------------------------------------------------------------------------------
  -- CSV Y VALIDACION FINAL
  ------------------------------------------------------------------------------
  PROCEDURE pr_generar_linea_csv(p_id IN NUMBER) IS
    v_cnt NUMBER;
  BEGIN
    UPDATE IT.SB_CF_ALT_PERSONAS a
       SET a.LINEA_CSV =
             '14' || ';' ||
             NVL(TRIM(a.TIPO_IDENT),'') || ';' ||
             NVL(TRIM(a.NRO_DOCUMENTO),'') || ';' ||
             NVL(TRIM(a.TIPO_PER),'') || ';' ||
             NVL(TRIM(a.APELLIDO),'') || ';' ||
             NVL(TRIM(a.NOMBRE),'') || ';' ||
             NVL(TO_CHAR(a.FECHA_NAC,'YYYYMMDD'),'') || ';' ||
             NVL(TRIM(a.GENERO),'') || ';' ||
             NVL(TRIM(a.PAIS_NACIMIENTO),'') || ';' ||
             CASE
               WHEN a.CIUDAD_NACIMIENTO IS NULL THEN ''
               WHEN a.PAIS_NACIMIENTO = 'PY' THEN LPAD(TO_CHAR(a.CIUDAD_NACIMIENTO),4,'0')
               ELSE TO_CHAR(a.CIUDAD_NACIMIENTO)
             END || ';' ||
             NVL(TO_CHAR(a.FECHA_VENC_DOC,'YYYYMMDD'),'') || ';' ||
             TO_CHAR(a.NRO_LINEA)
     WHERE a.ID_EJECUCION = p_id;

    v_cnt := SQL%ROWCOUNT;
    COMMIT;

    pr_log_regla(
      p_id,
      'CSV',
      'Generacion LINEA_CSV final',
      'Manual Tecnico CF Personas: 12 campos separados por punto y coma',
      v_cnt,
      'GENERAR: LINEA_CSV armado sobre datos ya normalizados y validados'
    );
  END pr_generar_linea_csv;

  PROCEDURE pr_validar_linea_csv_final(p_id IN NUMBER) IS
  BEGIN
    pr_excluir_regla(
      p_id,
      'VF01',
      'Control final: linea CSV con cantidad incorrecta de separadores',
      'Control tecnico interno previo a exportacion',
      'LINEA_CSV no posee 12 campos separados por ;',
      'a.LINEA_CSV IS NULL OR REGEXP_COUNT(a.LINEA_CSV, '';'') <> 11'
    );

    pr_excluir_regla(
      p_id,
      'VF02',
      'Control final: linea CSV contiene espacios al inicio o final',
      'Manual Tecnico CF Personas: no se permiten espacios al inicio/final',
      'LINEA_CSV posee espacios al inicio o al final',
      'a.LINEA_CSV <> TRIM(a.LINEA_CSV)'
    );
  END pr_validar_linea_csv_final;

  PROCEDURE pr_renumerar_lineas(p_id IN NUMBER) IS
    v_total NUMBER;
  BEGIN
    MERGE INTO IT.SB_CF_ALT_PERSONAS tgt
    USING (
      SELECT ROWID rid,
             ROW_NUMBER() OVER (ORDER BY NRO_LINEA) new_linea
        FROM IT.SB_CF_ALT_PERSONAS
       WHERE ID_EJECUCION = p_id
    ) src
    ON (tgt.ROWID = src.rid)
    WHEN MATCHED THEN UPDATE SET
      tgt.NRO_LINEA = src.new_linea,
      tgt.LINEA_CSV = REGEXP_REPLACE(tgt.LINEA_CSV, ';[^;]*$', ';' || TO_CHAR(src.new_linea));

    SELECT COUNT(*)
      INTO v_total
      FROM IT.SB_CF_ALT_PERSONAS
     WHERE ID_EJECUCION = p_id;

    pr_log_regla(
      p_id,
      'R20',
      'Renumeracion NRO_LINEA 1..N tras eliminaciones',
      'Control interno: campo 12 correlativo sin huecos',
      v_total,
      'CORRECCION: campo 12 actualizado en ' || v_total || ' filas'
    );

    COMMIT;
  END pr_renumerar_lineas;

  ------------------------------------------------------------------------------
  -- PUBLICOS
  ------------------------------------------------------------------------------
  PROCEDURE PR_GENERAR(p_fecha_cierre IN DATE DEFAULT NULL) IS
    v_id     NUMBER := NULL;
    v_cierre DATE;
    v_total  NUMBER := 0;
  BEGIN
    IF p_fecha_cierre IS NOT NULL THEN
      v_cierre := TRUNC(p_fecha_cierre);
    ELSE
      pr_obtener_fecha_cierre(v_cierre);
    END IF;
    pr_iniciar_ejecucion(v_id, v_cierre);
    pr_preparar_ejecucion(v_id, v_cierre);

    pr_construir_candidatos(v_id, v_cierre);

    -- C00 primero: limpia textos pero conserva tipo original PAS/CRC para R09x/R12x.
    pr_normalizar_textos(v_id);

    -- Pre-checks exactos contra SB_BCP_PERSONAS_REF antes de transformar PAS/CRC.
    -- Evitan que R31 tenga que hacer OR/REPLACE/TRIM sobre millones de filas.
    pr_precheck_personas_ref_pre_correccion(v_id);

    pr_aplicar_correcciones_seguras(v_id);
    pr_validar_reglas_bcp(v_id);
    pr_controlar_duplicados_bcp(v_id);
    pr_generar_linea_csv(v_id);
    pr_validar_linea_csv_final(v_id);
    pr_renumerar_lineas(v_id);

    SELECT COUNT(*)
      INTO v_total
      FROM IT.SB_CF_ALT_PERSONAS
     WHERE ID_EJECUCION = v_id;

    pr_log_regla(
      v_id,
      'R07',
      'Total personas incluidas en el lote CF Alta',
      'Resultado final CF Alta Personas',
      v_total,
      'RESULTADO: ' || v_total || ' personas -> CF-1046-' || TO_CHAR(v_cierre,'YYYYMMDD') || '.csv'
    );

    pr_upd_estado(
      v_id,
      'OK',
      v_total,
      'Fecha cierre: ' || TO_CHAR(v_cierre,'DD/MM/YYYY') ||
      ' | Archivo: CF-1046-' || TO_CHAR(v_cierre,'YYYYMMDD') || '.csv'
    );

  EXCEPTION
    WHEN OTHERS THEN
      IF v_id IS NOT NULL THEN
        pr_upd_estado(v_id, 'ERROR', NULL, SQLERRM);
      END IF;
      RAISE;
  END PR_GENERAR;

  PROCEDURE PR_LIMPIAR_LOGS(p_dias_retener IN NUMBER DEFAULT 90) IS
    v_hasta  DATE := TRUNC(SYSDATE) - p_dias_retener;
    v_ultima NUMBER;
  BEGIN
    SELECT NVL(MAX(ID_EJECUCION),0)
      INTO v_ultima
      FROM IT.SB_CF_PRO_LOG
     WHERE ESTADO = 'OK'
       AND TIPO_PROCESO = 'CF_ALTA';

    DELETE FROM IT.SB_CF_EXCL_DETALLE
     WHERE ID_EJECUCION IN (
       SELECT ID_EJECUCION
         FROM IT.SB_CF_PRO_LOG
        WHERE FEC_INICIO < v_hasta
          AND ID_EJECUCION != v_ultima
     );

    DELETE FROM IT.SB_CF_ALT_PERSONAS
     WHERE ID_EJECUCION IN (
       SELECT ID_EJECUCION
         FROM IT.SB_CF_PRO_LOG
        WHERE FEC_INICIO < v_hasta
          AND ID_EJECUCION != v_ultima
     );

    DELETE FROM IT.SB_CF_REG_LOG
     WHERE ID_EJECUCION IN (
       SELECT ID_EJECUCION
         FROM IT.SB_CF_PRO_LOG
        WHERE FEC_INICIO < v_hasta
          AND ID_EJECUCION != v_ultima
     );

    DELETE FROM IT.SB_CF_PRO_LOG
     WHERE FEC_INICIO < v_hasta
       AND ID_EJECUCION != v_ultima;

    COMMIT;
  END PR_LIMPIAR_LOGS;

END PAS_CF;

/