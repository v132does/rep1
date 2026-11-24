create or replace procedure it.prm_job_wf_grupos is

  cursor ca is
    select  a.cod_grupo,
            a.descripcion,
            a.estado,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.wf_grupos@uenodesg a
      where not exists (select * from it.wf_grupos b
                       where b.cod_grupo = a.cod_grupo);

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


  delete mi_logs where proceso = 'WF_GRUPOS';


  for a in ca loop
    begin
      insert into it.wf_grupos
          (  cod_grupo,
              descripcion,
              estado,
              usu_insercion,
              fec_insercion,
              usu_modificacion,
              fec_modificacion
                        )
      values
        (   a.cod_grupo,
            a.descripcion,
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
          (1, v_error, v_ermsj, a.cod_grupo, 'WF_GRUPOS', v_fecha);
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
       'verif_job_wf_grupos',
       'WF_GRUPOS',
       v_fecha);
    commit;
end prm_job_wf_grupos;
/

