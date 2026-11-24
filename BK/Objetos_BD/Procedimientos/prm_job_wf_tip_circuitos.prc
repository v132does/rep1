create or replace procedure it.prm_job_wf_tip_circuitos is

  cursor ca is
    select  a.cod_tip_circuito,
            a.descripcion,
            a.detalle,
            a.estado,
            a.cod_obj_base,
            a.cod_tar_inicial,
            a.referencia,
            a.det_sql,
            a.cod_programa,
            a.cod_modulo,
            a.cod_modalidad,
            a.nom_par_referencia,
            a.ref_val_limite,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
     from it.wf_tip_circuitos@uenodesg a
     where not exists (select * from wf_tip_circuitos b
                       where b.cod_tip_circuito = a.cod_tip_circuito );

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


  delete mi_logs where proceso = 'WF_TIP_CIRCUITOS';


  for a in ca loop
    begin
      insert into it.wf_tip_circuitos
          ( cod_tip_circuito,
            descripcion,
            detalle,
            estado,
            cod_obj_base,
            cod_tar_inicial,
            referencia,
            det_sql,
            cod_programa,
            cod_modulo,
            cod_modalidad,
            nom_par_referencia,
            ref_val_limite,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion
                        )
      values
        (   a.cod_tip_circuito,
            a.descripcion,
            a.detalle,
            a.estado,
            a.cod_obj_base,
            a.cod_tar_inicial,
            a.referencia,
            a.det_sql,
            a.cod_programa,
            a.cod_modulo,
            a.cod_modalidad,
            a.nom_par_referencia,
            a.ref_val_limite,
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
          (1, v_error, v_ermsj, a.cod_tip_circuito, 'WF_TIP_CIRCUITOS', v_fecha);
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
       'verif_job_wf_tip_circuitos',
       'WF_TIP_CIRCUITOS',
       v_fecha);
    commit;
end prm_job_wf_tip_circuitos;
/

