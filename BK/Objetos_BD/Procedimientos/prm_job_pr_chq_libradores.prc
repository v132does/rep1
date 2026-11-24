create or replace procedure it.prm_job_pr_chq_libradores is

  cursor cli is
    select nro_documento,
           nom_completo,
           trunc(fec_ingreso) fec_ingreso,
           est_informconf,
           fec_ven_informconf,
           cod_tip_documento,
           usu_insercion,
           usu_modificacion,
           fec_insercion,
           fec_modificacion
      from it.pr_chq_libradores@uenodesg a
     where not exists
     (select *
              from pr_chq_libradores b
             where a.nro_documento = b.nro_documento
               and a.cod_tip_documento = b.cod_tip_documento);

  v_error varchar2(500);
  v_err   varchar2(500);
  v_ermsj varchar2(500);
  v_fecha date := sysdate;
  v_fec   date := pag_cal.fu_obt_fec_actual(1);

begin
  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_chq_libradores disable all triggers',
                       v_err);
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  delete mi_logs where proceso = 'pr_chq_libradores';
  /*
  sql_util.ejecute_dml('truncate table pr_chq_libradores', v_err);
  if v_err is not null then
    raise_application_error(-20000,'Al truncar pr_chq_libradores '||v_err);
  end if;*/

  for a in cli loop
  
    begin
      insert into pr_chq_libradores
        (nro_documento,
         nom_completo,
         fec_ingreso,
         est_informconf,
         fec_ven_informconf,
         cod_tip_documento,
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      values
        (a.nro_documento,
         a.nom_completo,
         a.fec_ingreso,
         a.est_informconf,
         a.fec_ven_informconf,
         DECODE(a.cod_tip_documento, '62', '1', a.cod_tip_documento),
         a.usu_insercion,
         a.usu_modificacion,
         a.fec_insercion,
         a.fec_modificacion);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;
        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1,
           v_error,
           v_ermsj,
           a.nro_documento,
           'pr_chq_libradores',
           v_fecha);
    end;
  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_chq_libradores enable all triggers',
                       v_err);
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
       'verif_job_pr_chq_libradores',
       'pr_chq_libradores',
       v_fecha);
    commit;
end;
/

