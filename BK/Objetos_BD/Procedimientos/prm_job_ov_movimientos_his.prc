create or replace procedure it.prm_job_ov_movimientos_his is

  cursor pr is
    select replace(translate(a.nro_cuenta,
                             'ABCDEFGHIJLAMNOPQRSTUVWYXXZabcdefghijklmnopqrstuvwyz*Ç}°-,/-.\+|',
                             ' '),
                   ' ',
                   '') nro_cuenta,            
                   a.fecha,
                   a.hora,
                   a.cod_usuario,
                   a.nro_secuencia,
                   a.fec_valor,
                   a.monto,
                   decode(a.cod_moneda,'ARP','ARS','RS','BRL', 'EUR','EUR','USD','USD','GS','GS') cod_moneda,
                   a.cod_oficina,
                   a.cod_error,
                   a.cod_retencion,
                   a.fec_fin_retencion,
                   a.est_cuenta,
                   a.estado,
                   a.cod_causa,
                   a.cod_banco,
                   a.cod_ofi_origen,
                   a.concepto,
                   a.cod_tasa,
                   a.val_tasa,
                   a.cod_rubro,
                   a.cod_ref_cambio,
                   a.reversado,
                   a.cod_usu_reversion,
                   a.hor_reversion,
                   a.emi_aviso,
                   a.cod_tra_padre,
                   a.cod_mod_padre,
                   a.cod_mad_padre,
                   a.cod_transaccion,
                   a.cod_modulo,
                   a.cod_modalidad,
                   a.mto_equ_local,
                   a.nro_caja,
                   a.cotizacion,
                   a.cod_bco_central,
                   a.nro_documento,
                   a.nro_documento2,
                   a.nro_documento3,
                   a.nro_documento4,
                   a.protegido,
                   a.tip_mov_rubro,
                   a.cod_autorizacion,
                   a.cod_usu_autorizador,
                   a.cod_tip_ope_cambio,
                   a.referencia,
                   a.cod_sit_contable,
                   a.cod_persona,
                   a.usu_insercion,
                   a.fec_insercion,
                   a.usu_modificacion,
                   a.fec_modificacion     
      from it.ov_movimientos_his@uenodesg a
      where not exists (select * from ov_movimientos_his b 
                        where a.fecha = b.fecha
                        and a.hora    = b.hora
                        and a.cod_usuario = b.cod_usuario
                        and a.nro_secuencia = b.nro_secuencia);
     -- where exists (select 1 from ge_cta_clientes g where a.nro_cuenta = g.nro_cuenta)
     -- order by a.nro_cuenta;
      
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
  sql_util.ejecute_dml('alter table it.ov_movimientos_his disable all triggers',v_err);

  delete mi_logs where proceso = 'OV_MOVIMIENTOS_HIS';

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
      insert into it.ov_movimientos_his 
        (   nro_cuenta,            
            fecha,
            hora,
            cod_usuario,
            nro_secuencia,
            fec_valor,
            monto,
            cod_moneda,
            cod_oficina,
            cod_error,
            cod_retencion,
            fec_fin_retencion,
            est_cuenta,
            estado,
            cod_causa,
            cod_banco,
            cod_ofi_origen,
            concepto,
            cod_tasa,
            val_tasa,
            cod_rubro,
            cod_ref_cambio,
            reversado,
            cod_usu_reversion,
            hor_reversion,
            emi_aviso,
            cod_tra_padre,
            cod_mod_padre,
            cod_mad_padre,
            cod_transaccion,
            cod_modulo,
            cod_modalidad,
            mto_equ_local,
            nro_caja,
            cotizacion,
            cod_bco_central,
            nro_documento,
            nro_documento2,
            nro_documento3,
            nro_documento4,
            protegido,
            tip_mov_rubro,
            cod_autorizacion,
            cod_usu_autorizador,
            cod_tip_ope_cambio,
            referencia,
            cod_sit_contable,
            cod_persona,
            usu_insercion,
            fec_insercion,
            usu_modificacion,
            fec_modificacion)
      values
        (    a.nro_cuenta,            
                   a.fecha,
                   a.hora,
                   a.cod_usuario,
                   a.nro_secuencia,
                   a.fec_valor,
                   a.monto,
                   a.cod_moneda,
                   a.cod_oficina,
                   a.cod_error,
                   a.cod_retencion,
                   a.fec_fin_retencion,
                   a.est_cuenta,
                   a.estado,
                   a.cod_causa,
                   a.cod_banco,
                   a.cod_ofi_origen,
                   a.concepto,
                   a.cod_tasa,
                   a.val_tasa,
                   a.cod_rubro,
                   a.cod_ref_cambio,
                   a.reversado,
                   a.cod_usu_reversion,
                   a.hor_reversion,
                   a.emi_aviso,
                   a.cod_tra_padre,
                   a.cod_mod_padre,
                   a.cod_mad_padre,
                   a.cod_transaccion,
                   a.cod_modulo,
                   a.cod_modalidad,
                   a.mto_equ_local,
                   a.nro_caja,
                   a.cotizacion,
                   a.cod_bco_central,
                   a.nro_documento,
                   a.nro_documento2,
                   a.nro_documento3,
                   a.nro_documento4,
                   a.protegido,
                   a.tip_mov_rubro,
                   a.cod_autorizacion,
                   a.cod_usu_autorizador,
                   a.cod_tip_ope_cambio,
                   a.referencia,
                   a.cod_sit_contable,
                   a.cod_persona,
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
          (1, v_error, v_ermsj, a.cod_rubro, 'OV_MOVIMIENTOS_HIS', v_fecha);
    end;

  
  end loop;

  --Habilitar los triggers
  sql_util.ejecute_dml('alter table ov_movimientos_his enable all triggers', v_err);
  
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
       'verif_job_ov_movimientos_his',
       'OV_MOVIMIENTOS_HIS',
       v_fecha);
    commit;
end prm_job_ov_movimientos_his;
/

