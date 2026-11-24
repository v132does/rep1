create or replace procedure it.prm_job_pr_rel_chq_lib is

  cursor cli is
     select *
       from it.pr_rel_chq_lib@uenodesg a
      where not exists (select 1 from pr_rel_chq_lib p
                         where p.cod_banco = a.cod_banco
                           and p.nro_cheque = a.nro_cheque
                           and p.cta_libradora = a.cta_libradora
                           and p.cod_tip_documento = a.cod_tip_documento
                           and p.nro_documento = a.nro_documento);

  v_error varchar2(500);
  v_err   varchar2(500);
  v_ermsj varchar2(500);
  v_fecha date := sysdate;
	v_fec date := pag_cal.fu_obt_fec_actual(1);


begin
  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_rel_chq_lib disable all triggers', v_err);
  if v_err is not null then
    raise_application_error(-20000,'Al desabilitar triggers '||v_err);
  end if;

  delete mi_logs where proceso = 'pr_rel_chq_lib';
  /*
  sql_util.ejecute_dml('truncate table pr_rel_chq_lib', v_err);
  if v_err is not null then
    raise_application_error(-20000,'Al truncar pr_rel_chq_lib '||v_err);
  end if;*/

  for a in cli loop

       begin
           insert into pr_rel_chq_lib
                  (cod_banco, nro_cheque, cta_libradora, nro_documento, cod_tip_documento,usu_insercion,usu_modificacion,fec_insercion, fec_modificacion)
           values
                  (a.cod_banco, a.nro_cheque, a.cta_libradora, a.nro_documento, decode(a.cod_tip_documento,'62',1,a.cod_tip_documento),a.usu_insercion, a.usu_modificacion, a.fec_insercion, a.fec_modificacion);
       exception
          when others then
            v_error := sqlcode;
            v_ermsj := sqlerrm;
            insert into mi_logs(nro_reg,nro_error,men_error,comentario,proceso,fec_proceso)
            values(1,v_error,v_ermsj, a.nro_cheque ,'pr_rel_chq_lib',v_fecha);
       end;
   end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_rel_chq_lib enable all triggers', v_err);
  if v_err is not null then
    raise_application_error(-20000,'Al habilitar triggers '||v_err);
  end if;
    exception
  when others then
    v_error := sqlcode;
    v_ermsj := nvl(v_err, sqlerrm);
    v_fecha := sysdate;
    insert into mi_logs(nro_reg,nro_error,men_error,comentario,proceso,fec_proceso)
    values(1,v_error,v_ermsj,'verif_job_pr_rel_chq_lib','pr_rel_chq_lib',v_fecha);
    commit;
end;
/

