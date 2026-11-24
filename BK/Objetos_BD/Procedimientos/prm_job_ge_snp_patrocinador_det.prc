create or replace procedure it.prm_job_ge_snp_patrocinador_det is

  cursor ca is
    select  a.cod_swift_padre,
            a.cod_persona,
            a.subparticipante,
            a.cod_swift_sub,
            a.cta_interna_sub,
            a.estado,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_snp_patrocinador_det@uenodesg a
      where not exists (select * from ge_snp_patrocinador_det b
                        where b.cod_swift_padre = a.cod_swift_padre 
                        and b.cod_persona       = a.cod_persona
                        and b.subparticipante   = a.subparticipante
                        and b.cta_interna_sub   = a.cta_interna_sub);

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
  sql_util.ejecute_dml('alter table it.ge_snp_patrocinador_det disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SNP_PATROCINADOR_DET';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_snp_patrocinador_det s
                (cod_swift_padre,
                  cod_persona,
                  subparticipante,
                  cod_swift_sub,
                  cta_interna_sub,
                  estado,
                  usu_insercion,
                  fec_insercion,
                  usu_modificacion,
                  fec_modificacion)
      values
              (   a.cod_swift_padre,
                  a.cod_persona,
                  a.subparticipante,
                  a.cod_swift_sub,
                  a.cta_interna_sub,
                  a.estado,
                  a.usu_insercion,
                  a.fec_insercion,
                  a.usu_modificacion,
                  a.fec_modificacion);
    exception
      when others then
        v_error := sqlcode;
        v_ermsj := sqlerrm;

        insert into mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        values
          (1, v_error, v_ermsj, a.cod_swift_padre||'-'||a.cod_persona, 'GE_SNP_PATROCINADOR_DET', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_snp_patrocinador_det enable all triggers', v_err);

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
       'verif_job_ge_snp_patrocinador_det',
       'GE_SNP_PATROCINADOR_DET',
       v_fecha);
    commit;
end prm_job_ge_snp_patrocinador_det;
/

