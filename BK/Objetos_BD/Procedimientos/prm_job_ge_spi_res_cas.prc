create or replace procedure it.prm_job_ge_spi_res_cas is

  cursor ca is
    select  a.nro_referencia,
            a.tip_identificador,
            a.val_identificador,
            a.cod_persona,
            a.tip_consulta,
            a.fecha,
            a.hora,
            a.val_cli_recordid,
            a.val_cta_recordid,
            a.val_alias_recordid,
            a.fec_vto_documento,
            a.nombre,
            a.apellido,
            a.nro_cuenta,
            a.tip_cuenta,
            a.cod_mon_cta,
            a.fec_apertura,
            a.fec_cancelacion,
            a.cta_defecto,
            a.error,
            a.fec_registro,
            a.fec_venc_registro,
            a.cod_swi_participante,
            a.tip_doc_cliente,
            a.nro_doc_cliente,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_spi_res_cas a
      where not exists (select * from ge_spi_res_cas b
                        where a.nro_referencia = b.nro_referencia);

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
  sql_util.ejecute_dml('alter table it.ge_spi_res_cas disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SPI_RES_CAS';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_spi_res_cas s
                  (nro_referencia,
                    tip_identificador,
                    val_identificador,
                    cod_persona,
                    tip_consulta,
                    fecha,
                    hora,
                    val_cli_recordid,
                    val_cta_recordid,
                    val_alias_recordid,
                    fec_vto_documento,
                    nombre,
                    apellido,
                    nro_cuenta,
                    tip_cuenta,
                    cod_mon_cta,
                    fec_apertura,
                    fec_cancelacion,
                    cta_defecto,
                    error,
                    fec_registro,
                    fec_venc_registro,
                    cod_swi_participante,
                    tip_doc_cliente,
                    nro_doc_cliente,
                    usu_insercion,
                    fec_insercion,
                    usu_modificacion,
                    fec_modificacion)
      values
              ( a.nro_referencia,
                a.tip_identificador,
                a.val_identificador,
                a.cod_persona,
                a.tip_consulta,
                a.fecha,
                a.hora,
                a.val_cli_recordid,
                a.val_cta_recordid,
                a.val_alias_recordid,
                a.fec_vto_documento,
                a.nombre,
                a.apellido,
                a.nro_cuenta,
                a.tip_cuenta,
                a.cod_mon_cta,
                a.fec_apertura,
                a.fec_cancelacion,
                a.cta_defecto,
                a.error,
                a.fec_registro,
                a.fec_venc_registro,
                a.cod_swi_participante,
                a.tip_doc_cliente,
                a.nro_doc_cliente,
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
          (1, v_error, v_ermsj, a.nro_referencia, 'GE_SPI_RES_CAS', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_res_cas enable all triggers', v_err);

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
       'verif_job_ge_spi_res_cas',
       'GE_SPI_RES_CAS',
       v_fecha);
    commit;
end prm_job_ge_spi_res_cas;
/

