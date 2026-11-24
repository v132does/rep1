create or replace procedure it.prm_job_sb_snp_mensajes is

  cursor ca is
    select  a.cod_mensaje,
            a.nro_referencia,
            a.nro_lote,
            a.orden,
            a.nro_linea,
            a.campo,
            a.valor,
            a.descripcion,
            a.ind_requerido,
            a.nro_detalle,
            a.err_formato,
            a.err_validacion,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.sb_snp_mensajes@uenodesg a
      where not exists (select * from sb_snp_mensajes b
                        where a.cod_mensaje = b.cod_mensaje
                        and   a.nro_referencia = b.nro_referencia );

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
  sql_util.ejecute_dml('alter table it.sb_snp_mensajes disable all triggers',v_err);

  delete mi_logs where proceso = 'sb_snp_mensajes';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.sb_snp_mensajes s
                  (cod_mensaje,
                    nro_referencia,
                    nro_lote,
                    orden,
                    nro_linea,
                    campo,
                    valor,
                    descripcion,
                    ind_requerido,
                    nro_detalle,
                    err_formato,
                    err_validacion,
                    usu_insercion,
                    fec_insercion,
                    usu_modificacion,
                    fec_modificacion
                    )
      values
              ( a.cod_mensaje,
                a.nro_referencia,
                a.nro_lote,
                a.orden,
                a.nro_linea,
                a.campo,
                a.valor,
                a.descripcion,
                a.ind_requerido,
                a.nro_detalle,
                a.err_formato,
                a.err_validacion,
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
          (1, v_error, v_ermsj, a.nro_referencia, 'SB_SNP_MENSAJES', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.sb_snp_mensajes enable all triggers', v_err);

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
       'verif_job_sb_snp_mensajes',
       'SB_SNP_MENSAJES',
       v_fecha);
    commit;
end prm_job_sb_snp_mensajes;
/

