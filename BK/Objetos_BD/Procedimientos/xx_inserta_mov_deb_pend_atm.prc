create or replace procedure it.xx_inserta_mov_deb_pend_atm is
/*Ingresar débitos pendientes para descontar al cliente los movimientos que fueron reversados x error
  Se utiliza la transacción 5513 - DEBITO POR REGULARIZACION TRANSAC. INFONET*/
/*  cursor c_deb_atm is
  select *
    from xx_falta_ingr_atm m
   where m.cod_tip_movimiento = 'D'; ---Solo se van a procesar los débitos
*/
begin
/*  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1 ; end;
  for x in c_deb_atm loop
     insert into it.ge_mov_pendientes(nro_cuenta, fecha, cod_modulo, cod_modalidad, cod_transaccion, cod_mod_padre,
       cod_mad_padre, cod_tra_padre, monto,
       hora, cod_movimiento, cod_usuario, cod_moneda, cod_oficina, cod_error, estado, cod_ofi_origen, concepto,
       cod_tasa, val_tasa, nro_documento, saldo, mto_exonerado, cod_usu_exonerador, motivo, observacion, cod_persona,
       referencia, car_manual)
     values(x.nro_cuenta, x.fecha, x.cod_modulo, x.cod_modalidad, 5513, x.cod_mod_padre,
       x.cod_mad_padre, x.cod_tra_padre, x.monto,
       x.hora, null, x.cod_usuario, x.cod_moneda, x.cod_oficina, null, 'I', x.cod_ofi_origen, substr(x.concepto,1,15)||'-Regul.Mov.ATM.'||to_char(x.fecha,'dd/mm'),
       x.cod_tasa, x.val_tasa, x.nro_documento, x.monto, 0, null, null, null, null,
       null, 'N');
  end loop;
  commit;
exception
  when others then
     raise_application_error(-20000, 'Error mov_deb:'||sqlerrm);*/
     null;
end;
/

