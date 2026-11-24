create or replace procedure it.prg_obt_dat_transaccion
 (p_cod_modulo      in  ge_transacciones.cod_modulo%type,
  p_cod_modalidad   in  ge_transacciones.cod_modalidad%type,
  p_cod_transaccion in  ge_transacciones.cod_transaccion%type,
  p_tipo            out ge_transacciones.afecta%type,
  p_descripcion     out ge_transacciones.descripcion%type,
  p_cod_tip_asiento out ge_transacciones.cod_tip_asiento%type,
  p_cod_tasa        out ge_transacciones.cod_tasa%type
 )
IS
Begin
  --Obtiene el Nombre de la Transaccion
  select tipo, descripcion, cod_tip_asiento, cod_tasa
    into p_tipo, p_descripcion, p_cod_tip_asiento, p_cod_tasa
    from ge_transacciones
   where cod_transaccion = p_cod_transaccion
     and cod_modulo      = p_cod_modulo
     and cod_modalidad   = p_cod_modalidad;
  --
exception
    when no_data_found then
      raise_application_error(-20000,'Transaccion inexistente en el Sistema');
    when others then
      raise_application_error(-20001,'ERROR: en fue_obt_des_transaccion '||sqlerrm);
end;
/

