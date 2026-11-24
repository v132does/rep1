create or replace procedure it.prm_job_wf_tip_cir_tareas is

  cursor ca is
    select  a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.descripcion,
            a.detalle,
            a.estado,
            a.cod_gru_responsable,
            a.cod_tip_tar_siguiente,
            a.cod_tip_tar_rechazo,
            a.can_fir_requeridas,
            a.aut_conjunta,
            a.tip_tiempo,
            a.tie_estimado,
            a.tip_eti_siguiente,
            a.tip_eti_rechazo,
            a.tip_eti_cancelacion,
            a.det_sql,
            a.act_automatica,
            a.asi_responsable,
            a.env_mail,
            a.cod_tip_limite,
            a.ve_usuario,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
     from it.wf_tip_cir_tareas@uenodesg a
     where not exists (select * from it.wf_tip_cir_tareas b
                       where b.cod_tip_circuito = a.cod_tip_circuito
                       and   b.cod_tip_tarea    = a.cod_tip_tarea);

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


  delete mi_logs where proceso = 'WF_TIP_CIR_TAREAS';


  for a in ca loop
    begin
      insert into it.wf_tip_cir_tareas
          ( cod_tip_circuito,
            cod_tip_tarea,
            descripcion,
            detalle,
            estado,
            cod_gru_responsable,
            cod_tip_tar_siguiente,
            cod_tip_tar_rechazo,
            can_fir_requeridas,
            aut_conjunta,
            tip_tiempo,
            tie_estimado,
            tip_eti_siguiente,
            tip_eti_rechazo,
            tip_eti_cancelacion,
            det_sql,
            act_automatica,
            asi_responsable,
            env_mail,
            cod_tip_limite,
            ve_usuario,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion)
      values
        (  a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.descripcion,
            a.detalle,
            a.estado,
            a.cod_gru_responsable,
            a.cod_tip_tar_siguiente,
            a.cod_tip_tar_rechazo,
            a.can_fir_requeridas,
            a.aut_conjunta,
            a.tip_tiempo,
            a.tie_estimado,
            a.tip_eti_siguiente,
            a.tip_eti_rechazo,
            a.tip_eti_cancelacion,
            a.det_sql,
            a.act_automatica,
            a.asi_responsable,
            a.env_mail,
            a.cod_tip_limite,
            a.ve_usuario,
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
          (1, v_error, v_ermsj, a.cod_tip_circuito, 'WF_TIP_CIR_TAREAS', v_fecha);
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
       'verif_job_wf_tip_cir_tareas',
       'WF_TIP_CIR_TAREAS',
       v_fecha);
    commit;
end prm_job_wf_tip_cir_tareas;
/

