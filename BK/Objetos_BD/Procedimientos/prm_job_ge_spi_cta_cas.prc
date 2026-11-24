create or replace procedure it.prm_job_ge_spi_cta_cas is

  cursor ca is
    select  a.nro_referencia,
            a.nro_cta_solicitante,
            a.cli_recordid,
            a.cta_recordid,
            a.ali_recordid,
            a.cod_persona,
            a.tip_cuenta,
            a.fec_apertura,
            a.fec_cancelacion,
            a.moneda,
            a.cta_por_defecto,
            a.error,
            a.est_solicitud,
            a.tip_identificador,
            a.identificador,
            a.tip_accion,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_spi_cta_cas@uenodesg a
      where not exists (select * from ge_spi_cta_cas b
                         where b.nro_referencia = a.nro_referencia);

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
  sql_util.ejecute_dml('alter table it.ge_spi_cta_cas disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SPI_CTA_CAS';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_spi_cta_cas s
                  (nro_referencia,
                    nro_cta_solicitante,
                    cli_recordid,
                    cta_recordid,
                    ali_recordid,
                    cod_persona,
                    tip_cuenta,
                    fec_apertura,
                    fec_cancelacion,
                    moneda,
                    cta_por_defecto,
                    error,
                    est_solicitud,
                    tip_identificador,
                    identificador,
                    tip_accion,
                    usu_insercion,
                    fec_insercion,
                    usu_modificacion,
                    fec_modificacion
                    )
      values
              (  a.nro_referencia,
            a.nro_cta_solicitante,
            a.cli_recordid,
            a.cta_recordid,
            a.ali_recordid,
            a.cod_persona,
            a.tip_cuenta,
            a.fec_apertura,
            a.fec_cancelacion,
            a.moneda,
            a.cta_por_defecto,
            a.error,
            a.est_solicitud,
            a.tip_identificador,
            a.identificador,
            a.tip_accion,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;

        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1, v_error, v_ermsj, a.nro_referencia, 'GE_SPI_CTA_CAS', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_cta_cas enable all triggers', v_err);

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
       'verif_job_ge_spi_cta_cas',
       'GE_SPI_CTA_CAS',
       v_fecha);
    commit;
end prm_job_ge_spi_cta_cas;
/

