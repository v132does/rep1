create or replace procedure it.prm_job_ge_spi_res_reportes is

  cursor ca is
    select  a.nro_referencia,
            a.id_peticion,
            a.estado,
            a.respuesta,
            a.fec_ult_consulta,
            a.error,
            a.formato,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_spi_res_reportes a
      where not exists (select * from ge_spi_res_reportes b
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
  sql_util.ejecute_dml('alter table it.ge_spi_res_reportes disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SPI_RES_REPORTES';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_spi_res_reportes s
                  (nro_referencia,
                    id_peticion,
                    estado,
                    respuesta,
                    fec_ult_consulta,
                    error,
                    formato,
                    usu_insercion,
                    fec_insercion,
                    usu_modificacion,
                    fec_modificacion)
      values
              ( a.nro_referencia,
                  a.id_peticion,
                  a.estado,
                  a.respuesta,
                  a.fec_ult_consulta,
                  a.error,
                  a.formato,
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
          (1, v_error, v_ermsj, a.nro_referencia, 'GE_SPI_RES_REPORTES', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_res_reportes enable all triggers', v_err);

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
       'verif_ge_spi_res_reportes',
       'GE_SPI_RES_REPORTES',
       v_fecha);
    commit;
end prm_job_ge_spi_res_reportes;
/

