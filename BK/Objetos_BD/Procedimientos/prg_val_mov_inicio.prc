create or replace procedure it.prg_val_mov_inicio is
  v_can_mov_noc number default 0;
  v_mov_fec_ant number default 0;
  v_fec_actual  date default pag_cal.fu_obt_fec_actual(1);
begin
  begin
    select count(1) into v_can_mov_noc
      from it.ge_movimientos_noc;
  exception
    when no_data_found then
      v_can_mov_noc := 0;
  end;
  begin
    select count(1) into v_mov_fec_ant
      from it.ge_movimientos a
     where a.fecha < v_fec_actual;
  exception
    when no_data_found then
      v_mov_fec_ant := 0;
  end;
  if v_can_mov_noc > 0 then
   begin  
   INSERT INTO ge_movimientos
      (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, nro_cuenta, cod_moneda,
       cod_oficina, cod_error, cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa,
       cod_banco, cod_ofi_origen, concepto, cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado,
       cod_usu_reversion, hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
       cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja, cotizacion,
       cod_bco_central, nro_documento, nro_documento2, nro_documento3, nro_documento4, protegido,
       cod_autorizacion, cod_usu_autorizador, usu_insercion, fec_insercion, usu_modificacion,
       fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio)
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
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
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio
        FROM ge_movimientos_noc a;
        delete from ge_movimientos_noc;
        commit;
       exception
         when others then
            raise_application_error(-20000,'Error al realizar traspaso de ge_movimientos_noc '||sqlerrm);
      end;        
  end if;
  if v_mov_fec_ant > 0 then
     begin
      update ge_movimientos c
      set c.fecha = v_fec_actual
      where c.fecha < v_fec_actual;
      commit;
      exception
     when others then
            raise_application_error(-20000,'Error al actualizar fechas inconsistentes en ge_movimientos '||sqlerrm);
      end;
   end if;
   if v_mov_fec_ant > 0 or v_can_mov_noc > 0 then
     it_mail.mail (fug_obt_dir_correo,
                     fug_obt_pardinamico('ENV_EMA_GUA_CIERRE'),
                     'Actualizacion en programa PRG_VAL_MOV_INICIO(420)', 
                     'Cantidad de inconsistencias corregidas en ge_movimientos_noc: '||v_can_mov_noc||' Cantidad de inconsistencias corregidas de fechas en ge_movimientos: '||v_mov_fec_ant);
     end if;
end;
/
