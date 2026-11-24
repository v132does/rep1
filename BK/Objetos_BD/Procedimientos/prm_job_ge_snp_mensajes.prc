create or replace procedure it.prm_job_ge_snp_mensajes is

  cursor ca is
    select  a.nro_referencia,
            a.nro_ref_externa,
            a.cod_msj_swift,
            a.fec_valor,
            a.msj_swift,
            a.cod_moneda,
            a.monto,
            a.error,
            a.fec_recepcion,
            a.msj_swi_original,
            a.situacion,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_snp_mensajes@uenodesg a
      where not exists (select * from ge_snp_mensajes b
                        where b.nro_referencia = a.nro_referencia
                        and   b.nro_ref_externa = a.nro_ref_externa
                        and   b.cod_msj_swift = a.cod_msj_swift
                        and   b.fec_valor     = a.fec_valor);

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
  sql_util.ejecute_dml('alter table it.ge_snp_mensajes disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SNP_MENSAJES';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_snp_mensajes s
                ( nro_referencia,
                  nro_ref_externa,
                  cod_msj_swift,
                  fec_valor,
                  msj_swift,
                  cod_moneda,
                  monto,
                  error,
                  fec_recepcion,
                  msj_swi_original,
                  situacion,
                  usu_insercion,
                  fec_insercion,
                  usu_modificacion,
                  fec_modificacion)
      values
              (   a.nro_referencia,
                  a.nro_ref_externa,
                  a.cod_msj_swift,
                  a.fec_valor,
                  a.msj_swift,
                  a.cod_moneda,
                  a.monto,
                  a.error,
                  a.fec_recepcion,
                  a.msj_swi_original,
                  a.situacion,
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
          (1, v_error, v_ermsj, a.nro_referencia, 'GE_SNP_MENSAJES', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_snp_mensajes enable all triggers', v_err);

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
       'verif_job_ge_snp_mensajes',
       'GE_SNP_MENSAJES',
       v_fecha);
    commit;
end prm_job_ge_snp_mensajes;
/

