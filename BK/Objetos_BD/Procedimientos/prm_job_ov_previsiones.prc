create or replace procedure it.prm_job_ov_previsiones is

  cursor pr is
    select replace(translate(nro_cuenta,
                             'ABCDEFGHIJLAMNOPQRSTUVWYXXZabcdefghijklmnopqrstuvwyz*Ç}°-,/-.\+|',
                             ' '),
                   ' ',
                   '') nro_cuenta,
                     fecha,
                     monto,
                     saldo,
                     porcentaje,
                     tot_gar_computables,
                     tot_pri_prevision,
                     usu_insercion,
                     fec_insercion,
                     usu_modificacion,
                     fec_modificacion
      from it.ov_previsiones a
      where not exists (select * from ov_previsiones b
                       where a.fecha      = b.fecha
                       and   a.nro_cuenta = b.nro_cuenta
                       and   a.monto      = b.monto);

  v_error   varchar2(500);
  v_err     varchar2(500);
  v_ermsj   varchar2(500);
  v_fecha   date := sysdate;
  v_fec     date := sysdate;
  v_cod_mod NUMBER;

begin

  begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := '1';
  end;

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table it.ov_previsiones disable all triggers',v_err);

  delete mi_logs where proceso = 'OV_PREVISIONES';

  sql_util.ejecute_dml('alter table ge_cuentas disable all triggers', v_err);
  
  sql_util.ejecute_dml('alter table ge_cta_clientes disable all triggers',v_err);
 
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

 --Habilitar trigger 
 /* sql_util.ejecute_dml('alter trigger ta_ov_previsiones enable', v_err);
  
  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;*/
  
  

  for a in pr loop
    begin
      insert into it.ov_previsiones 
        (    nro_cuenta,
             fecha,
             monto,
             saldo,
             porcentaje,
             tot_gar_computables,
             tot_pri_prevision,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion)
      values
        (    a.nro_cuenta,
             a.fecha,
             a.monto,
             a.saldo,
             a.porcentaje,
             a.tot_gar_computables,
             a.tot_pri_prevision,
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
          (1, v_error, v_ermsj, a.nro_cuenta, 'OV_PREVISIONES', v_fecha);
    end;

  
  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ov_previsiones enable all triggers', v_err);
  
  sql_util.ejecute_dml('alter table ge_cuentas enable all triggers', v_err);
  
  sql_util.ejecute_dml('alter table ge_cta_clientes enable all triggers', v_err);
   
 -- sql_util.ejecute_dml('alter trigger ta_ov_cta_vencidas enable', v_err);        
                
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
       'verif_job_ov_previsiones',
       'OV_PREVISIONES',
       v_fecha);
    commit;
end prm_job_ov_previsiones;
/

