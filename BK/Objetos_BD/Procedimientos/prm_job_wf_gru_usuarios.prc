create or replace procedure it.prm_job_wf_gru_usuarios is

  cursor ca is
    select  a.cod_grupo,
            a.cod_usuario,
            a.estado,
            --a.ve_oficinas,
            a.ver_otr_oficina,
            a.exc_usuario,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
     from it.wf_gru_usuarios@uenodesg a
     where not exists (select * from wf_gru_usuarios b
                      where b.cod_grupo = a.cod_grupo
                      and   b.cod_usuario = a.cod_usuario) ;

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


  delete mi_logs where proceso = 'WF_GRU_USUARIOS';


  for a in ca loop
    begin
      insert into it.wf_gru_usuarios
          (  cod_grupo,
              cod_usuario,
              estado,
             -- ve_oficinas,
              ver_otr_oficina,
              exc_usuario,
              usu_insercion,
              fec_insercion,
              usu_modificacion,
              fec_modificacion
                        )
      values
        (  a.cod_grupo,
            a.cod_usuario,
            a.estado,
           -- a.ve_oficinas,
            a.ver_otr_oficina,
            a.exc_usuario,
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
          (1, v_error, v_ermsj, a.cod_grupo, 'WF_GRU_USUARIOS', v_fecha);
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
       'verif_job_wf_gru_usuarios',
       'WF_GRU_USUARIOS',
       v_fecha);
    commit;
end prm_job_wf_gru_usuarios;
/

