CREATE OR REPLACE PROCEDURE IT.prm_job_pr_gar_cash IS

  CURSOR cli IS
    SELECT nro_garantia,
           nro_cta_referencia,
           cod_emisor,
           cod_cas_tipo,
           serie,
           nro_certificado,
           cod_moneda,
           monto,
           observacion,
           beneficiario,
           fec_inicio,
           fec_vencimiento,
           observacion_his,
           usu_insercion,
           usu_modificacion,
           fec_insercion,
           fec_modificacion
      FROM it.pr_gar_cash@uenodesg c
     WHERE exists (select 1 from pr_garantias x
                    where c.nro_garantia = x.nro_garantia)
       AND not exists (select 1 from pr_gar_cash g
                        where c.nro_garantia = g.nro_garantia
                        and   c.serie        = g.serie
                        and   c.nro_certificado = g.nro_certificado
                        and   c.nro_cta_referencia = g.nro_cta_referencia);

  v_error VARCHAR2(500);
  v_err   VARCHAR2(500);
  v_ermsj VARCHAR2(500);
  v_fecha DATE := SYSDATE;
  v_fec   DATE := pag_cal.fu_obt_fec_actual(1);

BEGIN
  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_gar_cash disable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  END IF;

  DELETE mi_logs WHERE proceso = 'PR_GAR_CASH';
  --DELETE pr_gar_cash;

  FOR a IN cli LOOP
    BEGIN
      INSERT INTO pr_gar_cash
        (nro_garantia,
         nro_cta_referencia,
         cod_emisor,
         cod_cas_tipo,
         serie,
         nro_certificado,
         cod_moneda,
         monto,
         observacion,
         beneficiario,
         fec_inicio,
         fec_vencimiento,
         observacion_his,
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      VALUES
        (a.nro_garantia,
         a.nro_cta_referencia,
         a.cod_emisor,
         a.cod_cas_tipo,
         a.serie,
         a.nro_certificado,
         a.cod_moneda,
         a.monto,
         a.observacion,
         a.beneficiario,
         a.fec_inicio,
         a.fec_vencimiento,
         a.observacion_his,
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
          (1, v_error, v_ermsj, a.nro_garantia, 'PR_GAR_CASH', v_fecha);
    END;
  END LOOP;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_gar_cash enable all triggers',
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
      (1, v_error, v_ermsj, 'verif_job_pr_gar_cash', 'PR_GAR_CASH', v_fecha);
    COMMIT;
END;
/

