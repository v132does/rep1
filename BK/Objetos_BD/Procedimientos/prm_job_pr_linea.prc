CREATE OR REPLACE PROCEDURE IT.prm_job_pr_linea IS

  CURSOR c_lineas IS
    SELECT *
      FROM it.pr_lineas@uenodesg a
     WHERE not exists (select 1
              from pr_lineas aa
             where a.nro_linea = aa.nro_linea)
       and exists (select 1
              from ba_personas e
             WHERE e.cod_persona = a.cod_persona)
       and exists (select 1
              from ge_modalidades e
             WHERE e.cod_modulo = a.cod_modulo
               and e.cod_modalidad = a.cod_modalidad);


  v_error VARCHAR2(500);
  v_err   VARCHAR2(500);
  v_ermsj VARCHAR2(500);
  v_fecha DATE := SYSDATE;
  v_fec   DATE := pag_cal.fu_obt_fec_actual(1);

BEGIN
  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_lineas disable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,'Al desabilitar triggers pr_lineas ' ||v_err);
  END IF;

  DELETE mi_logs WHERE proceso = 'PR_LINEAS';
  FOR b IN c_lineas LOOP
    BEGIN
      INSERT INTO pr_lineas
         (nro_linea, cod_persona, cod_gru_economico, cod_modulo, cod_modalidad, cod_moneda, monto,
          fec_vencimiento, fec_otorgamiento, mto_aplicado, descripcion, usu_insercion, fec_insercion,
          usu_modificacion, fec_modificacion, estado, observacion, niv_aprobacion, cotizacion,
          fec_aprobacion, nro_acta/*, cod_campana*/)
      VALUES
         (b.nro_linea, b.cod_persona, b.cod_gru_economico, b.cod_modulo, b.cod_modalidad, b.cod_moneda,
          b.monto, b.fec_vencimiento, b.fec_otorgamiento, b.mto_aplicado, b.descripcion, b.usu_insercion, b.fec_insercion,
          b.usu_modificacion, b.fec_modificacion, b.estado, b.observacion, b.niv_aprobacion, b.cotizacion, b.fec_aprobacion,
          b.nro_acta/*, b.cod_campana*/);
    EXCEPTION
      WHEN OTHERS THEN
        v_error := SQLCODE;
        v_ermsj := SQLERRM;
        INSERT INTO mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        VALUES
          (1, v_error, v_ermsj, b.nro_linea, 'PR_LINEAS', v_fecha);
    END;
  END LOOP;

  sql_util.ejecute_dml('alter table pr_lineas enable all triggers',v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,'Al habilitar triggers pr_lineas ' ||v_err);
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
       'verif_job_pr_lineas',
       'pr_lineas',
       v_fecha);
    COMMIT;
END;
/

