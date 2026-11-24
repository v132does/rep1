CREATE OR REPLACE PROCEDURE IT.prm_job_pr_gar_vehiculos IS

  CURSOR gar IS
    SELECT nro_garantia,
           nro_contrato,
           cod_marca,
           modelo,
           ano,
           nro_motor,
           nro_chasis,
           nro_chapa,
           nro_cedula,
           fec_inscripcion,
           cod_ent_seguro,
           nro_poliza,
           fec_vto_seguro,
           tip_prenda,
           cod_ent_tasador,
           val_tasacion,
           fec_inicio,
           fec_vencimiento,
           movil,
           val_seguro,
           val_vta_rapida,
           nro_inscripcion,
           nro_folio,
           fec_ini_seguro,
           usu_insercion,
           usu_modificacion,
           fec_insercion,
           fec_modificacion
      FROM it.pr_gar_vehiculos@uenodesg v
     WHERE exists (select 1 from pr_garantias g
                    where v.nro_garantia = g.nro_garantia)
       AND not exists (select 1 from pr_gar_vehiculos g
                        where v.nro_garantia = g.nro_garantia
                        and   v.nro_contrato = g.nro_contrato);

           v_error VARCHAR2(500);
  v_err   VARCHAR2(500);
  v_ermsj VARCHAR2(500);
  v_fecha DATE := SYSDATE;
  v_fec   DATE := pag_cal.fu_obt_fec_actual(1);

BEGIN
  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_gar_vehiculos disable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  END IF;

  DELETE mi_logs WHERE proceso = 'PR_GAR_VEHICULOS';
  --DELETE pr_gar_vehiculos;

  FOR a IN gar LOOP
    BEGIN
      INSERT INTO PR_GAR_VEHICULOS
        (nro_garantia,
         nro_contrato,
         cod_marca,
         modelo,
         ano,
         nro_motor,
         nro_chasis,
         nro_chapa,
         nro_cedula,
         fec_inscripcion,
         cod_ent_seguro,
         nro_poliza,
         fec_vto_seguro,
         tip_prenda,
         cod_ent_tasador,
         val_tasacion,
         fec_inicio,
         fec_vencimiento,
         movil,
         val_seguro,
         val_vta_rapida,
         nro_inscripcion,
         nro_folio,
         fec_ini_seguro,
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      VALUES
        (a.nro_garantia,
         a.nro_contrato,
         a.cod_marca,
         a.modelo,
         a.ano,
         a.nro_motor,
         a.nro_chasis,
         a.nro_chapa,
         a.nro_cedula,
         a.fec_inscripcion,
         a.cod_ent_seguro,
         a.nro_poliza,
         a.fec_vto_seguro,
         a.tip_prenda,
         a.cod_ent_tasador,
         a.val_tasacion,
         a.fec_inicio,
         a.fec_vencimiento,
         a.movil,
         a.val_seguro,
         a.val_vta_rapida,
         a.nro_inscripcion,
         a.nro_folio,
         a.fec_ini_seguro,
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
           'PR_GAR_VEHICULOS',
           v_fecha);
    END;
  END LOOP;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table PR_GAR_VEHICULOS enable all triggers',
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
       'verif_job_pr_gar_vehiculos',
       'PR_GAR_VEHICULOS',
       v_fecha);
    COMMIT;
END;
/

