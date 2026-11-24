create or replace procedure it.prm_job_wf_cir_tareas is

  cursor ca is
    select  a.cod_circuito,
            a.cod_tarea,
            a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.descripcion,
            a.comentario,
            a.documento,
            a.ind_anexo,
            a.estado,
            a.fec_asignacion,
            a.fec_finalizacion,
            a.cod_usuario,
            a.cod_gru_responsable,
            a.cod_causa,
            a.cod_usu_responsable,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.wf_cir_tareas@uenodesg a
      where not exists (select * from wf_cir_tareas b
                        where b.cod_circuito = a.cod_circuito
                        and   b.cod_tarea    = a.cod_tarea
                        and   b.cod_tip_circuito = a.cod_tip_circuito
                        and   b.cod_tip_tarea = a.cod_tip_tarea);

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
  sql_util.ejecute_dml('alter table it.wf_cir_tareas disable all triggers',v_err);
 
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  delete mi_logs where proceso = 'WF_CIR_TAREAS';


  for a in ca loop
    begin
      insert into it.wf_cir_tareas
        (   cod_circuito,
            cod_tarea,
            cod_tip_circuito,
            cod_tip_tarea,
            descripcion,
            comentario,
            documento,
            ind_anexo,
            estado,
            fec_asignacion,
            fec_finalizacion,
            cod_usuario,
            cod_gru_responsable,
            cod_causa,
            cod_usu_responsable,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion
            )
      values
        (   a.cod_circuito,
            a.cod_tarea,
            a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.descripcion,
            a.comentario,
            a.documento,
            a.ind_anexo,
            a.estado,
            a.fec_asignacion,
            a.fec_finalizacion,
            a.cod_usuario,
            a.cod_gru_responsable,
            a.cod_causa,
            a.cod_usu_responsable,
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
          (1, v_error, v_ermsj, a.cod_circuito, 'WF_CIR_TAREAS', v_fecha);
    end;


  end loop;
    --Habilitar los triggers
  sql_util.ejecute_dml('alter table wf_cir_tareas enable all triggers', v_err);
                
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
       'verif_job_wf_cir_tareas',
       'WF_CIR_TAREAS',
       v_fecha);
    commit;
end prm_job_wf_cir_tareas;
/

