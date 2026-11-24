create or replace procedure it.prm_job_sb_snp_lim_depo is

  cursor ca is
    select  a.cod_moneda,
            a.fecha,
            a.monto,
            a.tasa,
            a.transaccion,
            a.val_parametro,
            a.estado,
            a.usu_insercion,
            a.fec_insercion,
            a.usu_modificacion,
            a.fec_modificacion
      from it.sb_snp_lim_depo@uenodesg a
      where not exists (select * from sb_snp_lim_depo b 
                        where a.cod_moneda = b.cod_moneda
                        and   a.fecha      = b.fecha
                        and   a.monto      = b.monto );

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
  sql_util.ejecute_dml('alter table it.sb_snp_lim_depo disable all triggers',v_err);

  delete mi_logs where proceso = 'SB_SNP_LIM_DEPO';

  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;



  for a in ca loop
    begin
      insert into it.sb_snp_lim_depo s
                  (cod_moneda,
                    fecha,
                    monto,
                    tasa,
                    transaccion,
                    val_parametro,
                    estado,
                    usu_insercion,
                    fec_insercion,
                    usu_modificacion,
                    fec_modificacion)
      values
              (  a.cod_moneda,
                  a.fecha,
                  a.monto,
                  a.tasa,
                  a.transaccion,
                  a.val_parametro,
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
          (1, v_error, v_ermsj, a.cod_moneda||'-'||a.fecha||'-'||a.monto, 'SB_SNP_LIM_DEPO', v_fecha);
    end;


  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.sb_snp_lim_depo enable all triggers', v_err);

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
       'verif_job_sb_snp_lim_depo',
       'SB_SNP_LIM_DEPO',
       v_fecha);
    commit;
end prm_job_sb_snp_lim_depo;
/

