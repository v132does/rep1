create or replace procedure it.prm_job_wf_cir_tar_detalles is

  cursor ca is
    select  a.cod_circuito,
            a.cod_tarea,
            a.cod_tar_detalle,
            a.descripcion,
            a.comentario,
            a.estado,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.wf_cir_tar_detalles@uenodesg a
      where not exists (select * from wf_cir_tar_detalles b
                        where b.cod_circuito = a.cod_circuito
                        and   b.cod_tarea    = a.cod_tarea
                        and   b.cod_tar_detalle = a.cod_tar_detalle);

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


  delete mi_logs where proceso = 'WF_CIR_TAR_DETALLES';


  for a in ca loop
    begin
      insert into it.wf_cir_tar_detalles
        (  cod_circuito,
            cod_tarea,
            cod_tar_detalle,
            descripcion,
            comentario,
            estado,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion

                        )
      values
        (   a.cod_circuito,
            a.cod_tarea,
            a.cod_tar_detalle,
            a.descripcion,
            a.comentario,
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
          (1, v_error, v_ermsj, a.cod_circuito, 'WF_CIR_TAR_DETALLES', v_fecha);
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
       'verif_job_wf_cir_tar_detalles',
       'WF_CIR_TAREAS',
       v_fecha);
    commit;
end prm_job_wf_cir_tar_detalles;
/

