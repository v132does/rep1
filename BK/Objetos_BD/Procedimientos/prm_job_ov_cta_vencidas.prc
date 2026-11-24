create or replace procedure it.prm_job_ov_cta_vencidas is

  cursor ve is
    select replace(translate(nro_cuenta,
                             'ABCDEFGHIJLAMNOPQRSTUVWYXXZabcdefghijklmnopqrstuvwyz*Ç}°-,/-.\+|',
                             ' '),
                   ' ',
                   '') nro_cuenta,
             cod_modulo,
             cod_modalidad,
             cod_oficina,
             nro_cta_origen,
             cod_moneda,
             denominacion,
             fec_apertura,
             estado,
             fec_cam_estado,
             fec_ult_movimiento,
             hor_ult_movimiento,
             mto_origen,
             sal_tot_batch,
             dia_atraso,
             dia_atr_inicial,
             dig_verificador,
             fec_ini_mora,
             val_tasa,
             est_batch,
             en_juicio,
             fec_juicio,
             cod_ent_juicio,
             est_anterior,
             sal_total,
             sal_anterior,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion
      from it.ov_cta_vencidas a
      where not exists (select * from ov_cta_vencidas b 
                        where a.nro_cuenta = b.nro_cuenta);

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
  sql_util.ejecute_dml('alter table it.ov_cta_vencidas disable all triggers',v_err);

  delete mi_logs where proceso = 'OV_CTA_VENCIDAS';

  sql_util.ejecute_dml('alter table ge_cuentas disable all triggers', v_err);
  
  sql_util.ejecute_dml('alter table ge_cta_clientes disable all triggers',v_err);
 
  if v_err is not null then
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  end if;

 --Habilitar trigger 
  sql_util.ejecute_dml('alter trigger ta_ov_cta_vencidas enable', v_err);
  
  if v_err is not null then
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  end if;
  
  

  for a in ve loop
    begin
      insert into it.ov_cta_vencidas ov
        (    ov.nro_cuenta,
             ov.cod_modulo,
             ov.cod_modalidad,
             ov.cod_oficina,
             ov.nro_cta_origen,
             ov.cod_moneda,
             ov.denominacion,
             ov.fec_apertura,
             ov.estado,
             ov.fec_cam_estado,
             ov.fec_ult_movimiento,
             ov.hor_ult_movimiento,
             ov.mto_origen,
             ov.sal_tot_batch,
             ov.dia_atraso,
             ov.dia_atr_inicial,
             ov.dig_verificador,
             ov.fec_ini_mora,
             ov.val_tasa,
             ov.est_batch,
             ov.en_juicio,
             ov.fec_juicio,
             ov.cod_ent_juicio,
             ov.est_anterior,
             ov.sal_total,
             ov.sal_anterior,
             ov.usu_insercion,
             ov.fec_insercion,
             ov.usu_modificacion,
             ov.fec_modificacion)
      values
        (    a.nro_cuenta,
             a.cod_modulo,
             a.cod_modalidad,
             a.cod_oficina,
             a.nro_cta_origen,
             a.cod_moneda,
             a.denominacion,
             a.fec_apertura,
             a.estado,
             a.fec_cam_estado,
             a.fec_ult_movimiento,
             a.hor_ult_movimiento,
             a.mto_origen,
             a.sal_tot_batch,
             a.dia_atraso,
             a.dia_atr_inicial,
             a.dig_verificador,
             a.fec_ini_mora,
             a.val_tasa,
             a.est_batch,
             a.en_juicio,
             a.fec_juicio,
             a.cod_ent_juicio,
             a.est_anterior,
             a.sal_total,
             a.sal_anterior,
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
          (1, v_error, v_ermsj, a.nro_cuenta, 'OV_CTA_VENCIDAS', v_fecha);
    end;

  
  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table it.ov_cta_vencidas enable all triggers', v_err);
  
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
       'verif_job_ov_cta_vencidas',
       'OV_CTA_VENCIDAS',
       v_fecha);
    commit;
end prm_job_ov_cta_vencidas;
/

