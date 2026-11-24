create or replace procedure it.prm_job_ge_snp_par_mensajes is

  cursor ca is
    select  a.cod_msj_swift,
            a.cod_tip_operacion,
            a.cod_sub_tip_operacion,
            a.prioridad,
            a.descripcion,
            a.cod_periodo,
            a.cod_periodo2,
            a.cod_periodo3,
            a.cod_modulo,
            a.cod_modalidad,
            a.cod_tra_emitido,
            a.cod_tra_recibido,
            a.cod_tip_cir_emitido,
            a.cod_tip_cir_recibido,
            a.cod_tip_cir_rec_reversado,
            a.cod_tra_padre,
            a.tipo
      from it.mi_ge_snp_par_mensajes a;

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
  sql_util.ejecute_dml('alter table it.ge_snp_par_mensajes disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SNP_PAR_MENSAJES';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_snp_par_mensajes s
                  (cod_msj_swift,
                  cod_tip_operacion,
                  cod_sub_tip_operacion,
                  prioridad,
                  descripcion,
                  cod_periodo,
                  cod_periodo2,
                  cod_periodo3,
                  cod_modulo,
                  cod_modalidad,
                  cod_tra_emitido,
                  cod_tra_recibido,
                  cod_tip_cir_emitido,
                  cod_tip_cir_recibido,
                  cod_tip_cir_rec_reversado,
                  cod_tra_padre,
                  tipo,
                  usu_insercion,
                  fec_insercion,
                  usu_modificacion,
                  fec_modificacion)
      values
              (  a.cod_msj_swift,
                  a.cod_tip_operacion,
                  a.cod_sub_tip_operacion,
                  a.prioridad,
                  a.descripcion,
                  a.cod_periodo,
                  a.cod_periodo2,
                  a.cod_periodo3,
                  a.cod_modulo,
                  a.cod_modalidad,
                  a.cod_tra_emitido,
                  a.cod_tra_recibido,
                  a.cod_tip_cir_emitido,
                  a.cod_tip_cir_recibido,
                  a.cod_tip_cir_rec_reversado,
                  a.cod_tra_padre,
                  a.tipo,
                   'MIGRA',
                   v_fec,
                   'MIGRA',
                   v_fec);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;

        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1, v_error, v_ermsj, a.cod_msj_swift||'-'||a.cod_tip_operacion, 'GE_SNP_PAR_MENSAJES', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_snp_par_mensajes enable all triggers', v_err);

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
       'verif_job_ge_snp_par_mensajes',
       'GE_SNP_PAR_MENSAJES',
       v_fecha);
    commit;
end prm_job_ge_snp_par_mensajes;
/

