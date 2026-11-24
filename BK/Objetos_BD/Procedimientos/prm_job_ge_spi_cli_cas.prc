create or replace procedure it.prm_job_ge_spi_cli_cas is

  cursor ca is
    select  a.nro_referencia,
            a.cli_recordid,
            a.tip_identificador,
            a.val_identificador,
            a.fec_vto_documento,
            a.residencia,
            a.nombre,
            a.apellido,
            a.apodo,
            a.genero,
            a.fec_nacimiento,
            a.lugar_nacimiento,
            a.direccion,
            a.pais,
            a.ciudad,
            a.departamento,
            a.inf_adicional,
            a.det_adicional_pv,
            a.est_cliente,
            a.est_solicitud,
            a.error,
            a.cod_persona,
            a.tip_accion,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_spi_cli_cas@uenodesg a
      where not exists (select * from ge_spi_cli_cas b
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
  sql_util.ejecute_dml('alter table it.ge_spi_cli_cas disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SPI_CLI_CAS';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_spi_cli_cas s
                  (nro_referencia,
                    cli_recordid,
                    tip_identificador,
                    val_identificador,
                    fec_vto_documento,
                    residencia,
                    nombre,
                    apellido,
                    apodo,
                    genero,
                    fec_nacimiento,
                    lugar_nacimiento,
                    direccion,
                    pais,
                    ciudad,
                    departamento,
                    inf_adicional,
                    det_adicional_pv,
                    est_cliente,
                    est_solicitud,
                    error,
                    cod_persona,
                    tip_accion,
                    usu_insercion,
                    fec_insercion,
                    usu_modificacion,
                    fec_modificacion)
      values
              (     a.nro_referencia,
                    a.cli_recordid,
                    a.tip_identificador,
                    a.val_identificador,
                    a.fec_vto_documento,
                    a.residencia,
                    a.nombre,
                    a.apellido,
                    a.apodo,
                    a.genero,
                    a.fec_nacimiento,
                    a.lugar_nacimiento,
                    a.direccion,
                    a.pais,
                    a.ciudad,
                    a.departamento,
                    a.inf_adicional,
                    a.det_adicional_pv,
                    a.est_cliente,
                    a.est_solicitud,
                    a.error,
                    a.cod_persona,
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
          (1, v_error, v_ermsj, a.nro_referencia, 'GE_SPI_CLI_CAS', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_cli_cas enable all triggers', v_err);

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
       'verif_job_ge_spi_cli_cas',
       'GE_SPI_CLI_CAS',
       v_fecha);
    commit;
end prm_job_ge_spi_cli_cas;
/

