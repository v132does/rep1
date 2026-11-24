CREATE OR REPLACE PROCEDURE IT.PRG_ACT_REC_DEPOSITANTES IS
  v_msj_error VARCHAR2(100) default null;
  v_cod_dep   number;
  CURSOR c_dat IS
  SELECT *
    FROM ge_rec_depositantes_tmp
   WHERE nvl(procesado,'N') = 'N'
     AND nvl(activo,'S') = 'S'
     FOR UPDATE;
BEGIN
  FOR k IN c_dat LOOP
    v_msj_error := null;
    IF k.cod_tip_documento not in (1,6) THEN
      v_msj_error := 'Valor no válido para el Tipo de Documento.';
    END IF;

    IF v_msj_error IS NULL THEN
      IF nvl(k.activo,'S') = 'S' THEN
        --
        IF k.cod_depositante IS NULL THEN
          v_cod_dep := nvl(v_cod_dep,0) + 1;
        END IF;
        --
        BEGIN
          INSERT INTO ge_rec_depositantes
          (cod_ente, cod_depositante, cod_tip_documento, nro_documento, nom_depositante, activo)
          VALUES
          (k.cod_ente, nvl(k.cod_depositante,v_cod_dep), k.cod_tip_documento, k.nro_documento, k.nom_depositante, nvl(k.activo,'S'));
        EXCEPTION
          WHEN OTHERS THEN
            IF INSTR(SQLERRM,'PK_GE_REC_') > 0 THEN
              v_msj_error := 'Código de Depositante ya Registrado.';
            ELSE
              v_msj_error := SQLERRM;
            END IF;
        END;
      ELSIF k.activo IS NOT NULL THEN
        BEGIN
          UPDATE ge_rec_depositantes a
             SET a.activo = k.activo
           WHERE a.cod_ente = k.cod_ente
             AND a.cod_depositante = k.cod_depositante;
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;

      END IF;
    END IF;
    --
    IF v_msj_error IS NOT NULL THEN
      UPDATE ge_rec_depositantes_tmp a
         SET a.error = v_msj_error
       WHERE CURRENT OF c_dat;
    ELSE
      UPDATE ge_rec_depositantes_tmp a
         SET a.procesado = 'S'
       WHERE CURRENT OF c_dat;

    END IF;
  END LOOP;
END;
/

