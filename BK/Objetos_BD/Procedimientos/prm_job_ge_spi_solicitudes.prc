create or replace procedure it.prm_job_ge_spi_solicitudes is

  cursor ca is
    select  a.cod_sol_spi,
            a.nro_referencia,
            a.cod_msj_swift,
            a.est_notificacion,
            a.est_solicitud,
            a.respuesta,
            a.nro_ref_externa,
            a.fec_recepcion,
            a.cod_moneda,
            a.monto,
            a.msj_mx,
            a.nom_solicitante,
            a.doc_solicitante,
            a.tip_doc_solicitante,
            a.cta_solicitante,
            a.nom_beneficiario,
            a.doc_beneficiario,
            a.tip_doc_beneficiario,
            a.cta_beneficiario,
            a.nro_ref_solicitud,
            a.uetr,
            a.cod_mot_solicitud,
            a.nro_ref_msj_original,
            a.cod_swi_solicitante,
            a.cod_swi_suc_solicitante,
            a.cod_swi_beneficiario,
            a.cod_swi_suc_beneficiario,
            a.sit_solicitud,
            a.identificacion,
            a.info_remesa,
            a.info_envio,
            a.tip_rechazo,
            a.cod_tip_operacion,
            a.cta_ben_recibido,
            a.fec_insercion,
            a.usu_insercion,
            a.fec_modificacion,
            a.usu_modificacion
      from it.ge_spi_solicitudes@uenodesg a
      where not exists (select * from ge_spi_solicitudes b
                        where a.cod_sol_spi = b.cod_sol_spi );

  v_error   varchar2(500);
  v_err     varchar2(500);
  v_ermsj   varchar2(500);
  v_fecha   date := sysdate;
  v_fec     date := sysdate;

begin

  begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := '1';
  end;

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_solicitudes disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SPI_SOLICITUDES';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_spi_solicitudes s
                  (cod_sol_spi,
                  nro_referencia,
                  cod_msj_swift,
                  est_notificacion,
                  est_solicitud,
                  respuesta,
                  nro_ref_externa,
                  fec_recepcion,
                  cod_moneda,
                  monto,
                  msj_mx,
                  nom_solicitante,
                  doc_solicitante,
                  tip_doc_solicitante,
                  cta_solicitante,
                  nom_beneficiario,
                  doc_beneficiario,
                  tip_doc_beneficiario,
                  cta_beneficiario,
                  nro_ref_solicitud,
                  uetr,
                  cod_mot_solicitud,
                  nro_ref_msj_original,
                  cod_swi_solicitante,
                  cod_swi_suc_solicitante,
                  cod_swi_beneficiario,
                  cod_swi_suc_beneficiario,
                  sit_solicitud,
                  identificacion,
                  info_remesa,
                  info_envio,
                  tip_rechazo,
                  cod_tip_operacion,
                  cta_ben_recibido,
                  fec_insercion,
                  usu_insercion,
                  fec_modificacion,
                  usu_modificacion)
      values
              ( a.cod_sol_spi,
                  a.nro_referencia,
                  a.cod_msj_swift,
                  a.est_notificacion,
                  a.est_solicitud,
                  a.respuesta,
                  a.nro_ref_externa,
                  a.fec_recepcion,
                  a.cod_moneda,
                  a.monto,
                  a.msj_mx,
                  a.nom_solicitante,
                  a.doc_solicitante,
                  a.tip_doc_solicitante,
                  a.cta_solicitante,
                  a.nom_beneficiario,
                  a.doc_beneficiario,
                  a.tip_doc_beneficiario,
                  a.cta_beneficiario,
                  a.nro_ref_solicitud,
                  a.uetr,
                  a.cod_mot_solicitud,
                  a.nro_ref_msj_original,
                  a.cod_swi_solicitante,
                  a.cod_swi_suc_solicitante,
                  a.cod_swi_beneficiario,
                  a.cod_swi_suc_beneficiario,
                  a.sit_solicitud,
                  a.identificacion,
                  a.info_remesa,
                  a.info_envio,
                  a.tip_rechazo,
                  a.cod_tip_operacion,
                  a.cta_ben_recibido,
                  a.fec_insercion,
                  a.usu_insercion,
                  a.fec_modificacion,
                  a.usu_modificacion);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;

        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1, v_error, v_ermsj, a.nro_referencia, 'GE_SPI_SOLICITUDES', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_solicitudes enable all triggers', v_err);

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;
exception
  when others then
    v_error := sqlcode;
    v_ermsj := nvl(v_err, sqlerrm);
    v_fecha := sysdate;
    insert into mi_logs
      (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
    values
      (1,
       v_error,
       v_ermsj,
       'verif_job_ge_spi_solicitudes',
       'GE_SPI_SOLICITUDES',
       v_fecha);
    commit;
end prm_job_ge_spi_solicitudes;
/

