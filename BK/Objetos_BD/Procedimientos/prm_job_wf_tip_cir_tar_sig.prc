create or replace procedure it.prm_job_wf_tip_cir_tar_sig is

  cursor ca is
    select  a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.cod_tip_tar_siguiente,
            a.descripcion,
            a.tar_excepcion,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
     from it.wf_tip_cir_tar_sig@uenodesg a;

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


  delete mi_logs where proceso = 'WF_TIP_CIR_TAR_SIG';


  for a in ca loop
    begin
      insert into it.wf_tip_cir_tar_sig
          ( cod_tip_circuito,
            cod_tip_tarea,
            cod_tip_tar_siguiente,
            descripcion,
            tar_excepcion,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion
                        )
      values
        (  a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.cod_tip_tar_siguiente,
            a.descripcion,
            a.tar_excepcion,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
            );
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;
        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1, v_error, v_ermsj, a.cod_tip_circuito, 'WF_TIP_CIR_TAR_SIG', v_fecha);
    end;


  end loop;

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
       'verif_wf_tip_cir_tar_sig',
       'WF_TIP_CIR_TAR_SIG',
       v_fecha);
    commit;
end prm_job_wf_tip_cir_tar_sig;
/

