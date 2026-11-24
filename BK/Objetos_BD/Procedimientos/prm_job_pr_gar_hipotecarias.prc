CREATE OR REPLACE PROCEDURE IT.prm_job_pr_gar_hipotecarias IS

  CURSOR cli IS
    SELECT nro_garantia,
           nro_finca,
           cod_distrito,
           cta_catastral,
           direccion,
           val_edilicio,
           val_terreno,
           fec_ult_tasacion,
           fec_inicio,
           fec_vencimiento,
           cod_ent_seguro,
           nro_poliza,
           fec_vto_seguro,
           serie,
           nro_inscripcion,
           nro_folio,
           fec_inscripcion,
           val_vta_rapida,
           val_seguro,
           cod_ent_tasador,
           fec_ini_seguro,
           usu_insercion,
           usu_modificacion,
           fec_insercion,
           fec_modificacion
           --cod_ent_fiduciaria
      FROM it.pr_gar_hipotecarias@uenodesg h
     WHERE exists (select 1 from pr_garantias g
                    where h.nro_garantia = g.nro_garantia)
       AND not exists (select 1 from pr_gar_hipotecarias g
                        where h.nro_garantia = g.nro_garantia
                        and   h.nro_finca    = g.nro_finca);

  v_error VARCHAR2(500);
  v_err   VARCHAR2(500);
  v_ermsj VARCHAR2(500);
  v_fecha DATE := SYSDATE;
  v_fec   DATE := pag_cal.fu_obt_fec_actual(1);

BEGIN
  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_gar_hipotecarias disable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  END IF;

  DELETE mi_logs WHERE proceso = 'PR_GAR_HIPOTECARIAS';
  --DELETE PR_GAR_HIPOTECARIAS;

  FOR a IN cli LOOP
    BEGIN
      INSERT INTO PR_GAR_HIPOTECARIAS
        (nro_garantia,
         nro_finca,
         cod_distrito,
         cta_catastral,
         direccion,
         val_edilicio,
         val_terreno,
         fec_ult_tasacion,
         fec_inicio,
         fec_vencimiento,
         cod_ent_seguro,
         nro_poliza,
         fec_vto_seguro,
         serie,
         nro_inscripcion,
         nro_folio,
         fec_inscripcion,
         val_vta_rapida,
         val_seguro,
         cod_ent_tasador,
         fec_ini_seguro,
         --cod_ent_fiduciaria,
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      VALUES
        (a.nro_garantia,
         a.nro_finca,
         a.cod_distrito,
         a.cta_catastral,
         a.direccion,
         a.val_edilicio,
         a.val_terreno,
         a.fec_ult_tasacion,
         a.fec_inicio,
         a.fec_vencimiento,
         a.cod_ent_seguro,
         a.nro_poliza,
         a.fec_vto_seguro,
         a.serie,
         a.nro_inscripcion,
         a.nro_folio,
         a.fec_inscripcion,
         a.val_vta_rapida,
         a.val_seguro,
         a.cod_ent_tasador,
         a.fec_ini_seguro,
        -- a.cod_ent_fiduciaria,
         a.usu_insercion,
         a.usu_modificacion,
         a.fec_insercion,
         a.fec_modificacion);
    EXCEPTION
      WHEN OTHERS THEN
        v_error := SQLCODE;
        v_ermsj := SQLERRM;
        INSERT INTO mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        VALUES
          (1,
           v_error,
           v_ermsj,
           a.nro_garantia,
           'PR_GAR_HIPOTECARIAS',
           v_fecha);
    END;
  END LOOP;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_garantias enable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    v_error := SQLCODE;
    v_ermsj := nvl(v_err, SQLERRM);
    v_fecha := SYSDATE;
    INSERT INTO mi_logs
      (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
    VALUES
      (1,
       v_error,
       v_ermsj,
       'verif_pr_gar_hipotecarias',
       'PR_GAR_HIPOTECARIAS',
       v_fecha);
    COMMIT;
END;
/

