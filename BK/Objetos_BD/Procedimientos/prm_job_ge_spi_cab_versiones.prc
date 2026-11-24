create or replace procedure it.prm_job_ge_spi_cab_versiones is

  cursor ca is
    select  a.tipo_msj,
            a.version,
            a.estado,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_spi_cab_versiones@uenodesg a
      where not exists (select * from ge_spi_cab_versiones b
                        where b.tipo_msj = a.tipo_msj);

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
  sql_util.ejecute_dml('alter table it.ge_spi_cab_versiones disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SPI_CAB_VERSIONES';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_spi_cab_versiones s
                  (tipo_msj,
                    version,
                    estado,
                    usu_insercion,
                    fec_insercion,
                    usu_modificacion,
                    fec_modificacion)
      values
              (     a.tipo_msj,
                    a.version,
                    a.estado,
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
          (1, v_error, v_ermsj, a.tipo_msj, 'GE_SPI_CAB_VERSIONES', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_cab_versiones enable all triggers', v_err);

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
       'verif_job_ge_spi_cab_versiones',
       'GE_SPI_CAB_VERSIONES',
       v_fecha);
    commit;
end prm_job_ge_spi_cab_versiones;
/

