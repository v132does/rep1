create or replace procedure it.xx_inserta_mov_cred_atm is
/*Ingresar créditos x ATM a movimientos reversados por error, los débitos serán ingresados x débitos pendientes...
  Se utiliza la transacción 6662*/
 /* cursor c_cred_atm is
  select *
    from xx_falta_ingr_atm m
   where m.cod_tip_movimiento = 'C'; ---Solo se van a procesar los creditos*/

begin
/*  for x in c_cred_atm loop
     it.pag_cta.pr_act_operacion(x.nro_cuenta, to_char(sysdate,'hh24:mi:ss'), 'C', x.cod_moneda, x.monto, x.cod_tra_padre,
         6662, x.nro_documento, x.cotizacion, x.cod_ofi_origen, x.cod_mod_padre, x.cod_mad_padre, x.cod_tasa, x.val_tasa,
         trim(x.concepto)||'-Regul.Mov.ATM.'||to_char(x.fecha,'dd/mm'),
         x.emi_aviso, x.nro_secuencia, x.fecha, null, null, null);
  end loop;
  commit;
exception
  when others then
     raise_application_error(-20000, 'Error mov_cred:'||sqlerrm);*/
     null;
end;
/

