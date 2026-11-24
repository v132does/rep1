create or replace procedure IT.PRS_CAR_PERSONAS_REF IS
  v_insertados  NUMBER;
  v_id          NUMBER;
  v_archivo     VARCHAR2(100);
  v_staging_cnt NUMBER;
BEGIN
  -- Metadata del archivo: nombre configurado en GE_ARCHIVOS + filas actuales en staging
  BEGIN
    SELECT ARCHIVO INTO v_archivo
      FROM IT.GE_ARCHIVOS
     WHERE REFERENCIA = 'BCP_PERSONAS_REF'
       AND ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN v_archivo := 'PERSONAS_BCP.DAT';
  END;
  SELECT COUNT(*) INTO v_staging_cnt FROM IT.SB_PER_REF_TMP;

  -- Log inicio
  SELECT IT.SE_CF_ID_EJECUCION.NEXTVAL INTO v_id FROM DUAL;
  INSERT INTO IT.SB_CF_PRO_LOG(ID_EJECUCION, FEC_INICIO, ESTADO, TIPO_PROCESO, OBSERVACIONES)
  VALUES(v_id, SYSTIMESTAMP, 'CORRIENDO', 'CAR_PERSONAS',
         'Archivo: ' || v_archivo || ' | Staging cargada: ' || TO_CHAR(v_staging_cnt, '999,999,999') || ' filas');
  COMMIT;

  -- INSERT-SELECT bulk: una sola operacion SQL, usa indice IN_SBPR_NRO_DOCUMENTO
  -- para el NOT EXISTS y escribe directo sin row-by-row context switching.
  INSERT /*+ APPEND */ INTO IT.SB_BCP_PERSONAS_REF (
    rf_tipo_ident,
    rf_numero,
    rf_apellido,
    rf_nombre,
    rf_fecha_nac,
    rf_pais_swift,
    rf_tipo_per
  )
  SELECT t.tipo_ident,
         TRIM(t.nro_documento),
         SUBSTR(TRIM(t.apellido), 1, 30),
         SUBSTR(TRIM(t.nombre),   1, 30),
         CASE WHEN TRIM(t.fecha_nac) IS NULL OR TRIM(t.fecha_nac) = '00000000'
              THEN NULL
              ELSE TO_DATE(t.fecha_nac, 'YYYYMMDD')
         END,
         TRIM(t.pais_swift),
         TRIM(t.tipo_per)
    FROM IT.SB_PER_REF_TMP t
   WHERE NOT EXISTS (
             SELECT /*+ INDEX(r IN_SBPR_NRO_DOCUMENTO) */ 1
               FROM IT.SB_BCP_PERSONAS_REF r
              WHERE r.rf_tipo_ident = t.tipo_ident
                AND r.rf_numero     = TRIM(t.nro_documento)
         );

  v_insertados := SQL%ROWCOUNT;
  DELETE FROM IT.SB_PER_REF_TMP;
  -- Log resultado OK
  UPDATE IT.SB_CF_PRO_LOG
     SET ESTADO          = 'OK',
         FEC_FIN         = SYSTIMESTAMP,
         TOTAL_REGISTROS = v_insertados,
         OBSERVACIONES   = 'Archivo: ' || v_archivo ||
                           ' | Staging: ' || TO_CHAR(v_staging_cnt, '999,999,999') || ' filas' ||
                           ' | Insertados en SB_BCP_PERSONAS_REF: ' || v_insertados ||
                           ' | Staging SB_PER_REF_TMP limpiada'
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
           SET ESTADO='ERROR', FEC_FIN=SYSTIMESTAMP,
               OBSERVACIONES='Archivo: ' || v_archivo ||
                             ' | Staging: ' || TO_CHAR(v_staging_cnt, '999,999,999') || ' filas' ||
                             ' | ERROR: ' || v_err
         WHERE ID_EJECUCION=v_id;
        COMMIT;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
      RAISE_APPLICATION_ERROR(-20200, 'PRS_CAR_PERSONAS_REF: insertados=' ||
        NVL(TO_CHAR(v_insertados), '?') || ' error=' || v_err);
    END;
END PRS_CAR_PERSONAS_REF;
/
