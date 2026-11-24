create or replace procedure it.prm_job_wf_circuitos is

  cursor ca is
    select  a.cod_circuito,
            a.cod_tip_circuito,
            a.fec_inicio,
            a.referencia,
            a.cod_tar_actual,
            a.descripcion,
            upper(a.estado)estado,
            a.documento,
            a.ind_anexo,
            a.fec_fin,
            a.cod_persona,
            a.cod_gru_res_actual,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.wf_circuitos@uenodesg a
      where not exists (select * from it.wf_circuitos b
                        where b.cod_circuito = a.cod_circuito
                        and   b.cod_tip_circuito = a.cod_tip_circuito);

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


  delete mi_logs where proceso = 'WF_CIRCUITOS';


  for a in ca loop
    begin
      insert into it.wf_circuitos s
        (   cod_circuito,
            cod_tip_circuito,
            fec_inicio,
            referencia,
            cod_tar_actual,
            descripcion,
            estado,
            documento,
            ind_anexo,
            fec_fin,
            cod_persona,
            cod_gru_res_actual,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion
            )
      values
        (   a.cod_circuito,
            a.cod_tip_circuito,
            a.fec_inicio,
            a.referencia,
            a.cod_tar_actual,
            a.descripcion,
            a.estado,
            a.documento,
            a.ind_anexo,
            a.fec_fin,
            a.cod_persona,
            a.cod_gru_res_actual,
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
          (1, v_error, v_ermsj, a.cod_circuito, 'WF_CIRCUITOS', v_fecha);
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
       'verif_job_wf_circuitos',
       'WF_CIRCUITOS',
       v_fecha);
    commit;
end prm_job_wf_circuitos;
/

