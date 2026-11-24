create or replace procedure it.prm_job_ge_spi_informes is

  cursor ca is
    select  a.nro_referencia, 
            a.nro_ref_externa, 
            a.cod_msj_mx, 
            a.fecha, 
            a.hora, 
            a.tipo_limite, 
            a.tipo_informe, 
            a.nro_cta_solicitante, 
            a.cod_swi_solicitante, 
            a.cod_moneda, 
            a.monto, 
            a.msj_mx, 
            a.fec_recepcion, 
            a.situacion, 
            a.estado, 
            a.error, 
            a.par_rec_consulta, 
            a.inf_suplementaria, 
            a.nro_ref_msj_original, 
            a.tip_msj_original, 
            a.fec_ins_msj_original, 
            a.hor_ins_msj_original, 
            a.cod_swi_sol_original, 
            a.fec_valor_msj_original,
            a.usu_insercion, 
            a.fec_insercion, 
            a.usu_modificacion, 
            a.fec_modificacion
      from it.ge_spi_informes@uenodesg a
      where not exists (select * from ge_spi_informes b
                        where a.nro_referencia = b.nro_referencia
                        and a.nro_ref_externa = b.nro_ref_externa );

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
  sql_util.ejecute_dml('alter table it.ge_spi_informes disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SPI_INFORMES';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_spi_informes s
                  (nro_referencia, 
                    nro_ref_externa, 
                    cod_msj_mx, 
                    fecha, 
                    hora, 
                    tipo_limite, 
                    tipo_informe, 
                    nro_cta_solicitante, 
                    cod_swi_solicitante, 
                    cod_moneda, 
                    monto, 
                    msj_mx, 
                    fec_recepcion, 
                    situacion, 
                    estado, 
                    error, 
                    par_rec_consulta, 
                    inf_suplementaria, 
                    nro_ref_msj_original, 
                    tip_msj_original, 
                    fec_ins_msj_original, 
                    hor_ins_msj_original, 
                    cod_swi_sol_original, 
                    fec_valor_msj_original, 
                    usu_insercion, 
                    fec_insercion, 
                    usu_modificacion, 
                    fec_modificacion )
      values
              (  a.nro_referencia, 
                  a.nro_ref_externa, 
                  a.cod_msj_mx, 
                  a.fecha, 
                  a.hora, 
                  a.tipo_limite, 
                  a.tipo_informe, 
                  a.nro_cta_solicitante, 
                  a.cod_swi_solicitante, 
                  a.cod_moneda, 
                  a.monto, 
                  a.msj_mx, 
                  a.fec_recepcion, 
                  a.situacion, 
                  a.estado, 
                  a.error, 
                  a.par_rec_consulta, 
                  a.inf_suplementaria, 
                  a.nro_ref_msj_original, 
                  a.tip_msj_original, 
                  a.fec_ins_msj_original, 
                  a.hor_ins_msj_original, 
                  a.cod_swi_sol_original, 
                  a.fec_valor_msj_original,
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
          (1, v_error, v_ermsj, a.nro_referencia, 'GE_SPI_INFORMES', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_spi_informes enable all triggers', v_err);

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
       'verif_job_ge_spi_informes',
       'GE_SPI_INFORMES',
       v_fecha);
    commit;
end prm_job_ge_spi_informes;
/

