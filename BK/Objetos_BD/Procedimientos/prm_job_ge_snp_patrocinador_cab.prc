create or replace procedure it.prm_job_ge_snp_patrocinador_cab is

  cursor ca is
    select  a.cod_banco,
            a.cod_swift,
            a.cod_moneda,
            a.nro_cta_bancaria,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.ge_snp_patrocinador_cab@uenodesg a
      where not exists (select * from ge_snp_patrocinador_cab b
                        where b.cod_banco = a.cod_banco 
                        and b.cod_swift   = a.cod_swift
                        and b.cod_moneda  = a.cod_moneda);

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
  sql_util.ejecute_dml('alter table it.ge_snp_patrocinador_cab disable all triggers',v_err);

  delete mi_logs where proceso = 'GE_SNP_PATROCINADOR_CAB';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.ge_snp_patrocinador_cab s
                ( cod_banco,
                  cod_swift,
                  cod_moneda,
                  nro_cta_bancaria,
                  usu_insercion,
                  fec_insercion,
                  usu_modificacion,
                  fec_modificacion)
      values
              (  a.cod_banco,
                  a.cod_swift,
                  a.cod_moneda,
                  a.nro_cta_bancaria,
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
          (1, v_error, v_ermsj, a.cod_banco||'-'||a.cod_swift, 'GE_SNP_PATROCINADOR_CAB', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ge_snp_patrocinador_cab enable all triggers', v_err);

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
       'verif_job_ge_snp_patrocinador_cab',
       'GE_SNP_PATROCINADOR_CAB',
       v_fecha);
    commit;
end prm_job_ge_snp_patrocinador_cab;
/

