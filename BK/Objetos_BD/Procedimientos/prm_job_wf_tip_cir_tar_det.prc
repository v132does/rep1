create or replace procedure it.prm_job_wf_tip_cir_tar_det is

  cursor ca is
    select  a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.cod_tip_tar_det,
            a.descripcion,
            a.detalle,
            a.estado,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
     from it.wf_tip_cir_tar_det@uenodesg a
     where not exists (select * from wf_tip_cir_tar_det b
                       where b.cod_tip_circuito = a.cod_tip_circuito
                       and   b.cod_tip_tarea    = a.cod_tip_tarea
                       and   b.cod_tip_tar_det  = a.cod_tip_tar_det);

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


  delete mi_logs where proceso = 'WF_TIP_CIR_TAR_DET';


  for a in ca loop
    begin
      insert into it.wf_tip_cir_tar_det
          ( cod_tip_circuito,
            cod_tip_tarea,
            cod_tip_tar_det,
            descripcion,
            detalle,
            estado,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion
                        )
      values
        (  a.cod_tip_circuito,
            a.cod_tip_tarea,
            a.cod_tip_tar_det,
            a.descripcion,
            a.detalle,
            a.estado,
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
          (1, v_error, v_ermsj, a.cod_tip_circuito, 'WF_TIP_CIR_TAR_DET', v_fecha);
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
       'verif_job_wf_tip_tar_det',
       'WF_TIP_CIR_TAR_DET',
       v_fecha);
    commit;
end prm_job_wf_tip_cir_tar_det;
/

