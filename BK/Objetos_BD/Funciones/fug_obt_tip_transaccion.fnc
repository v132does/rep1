create or replace function it.fug_obt_tip_transaccion(p_cod_transaccion in ge_transacciones.cod_transaccion%type,
                                                      p_cod_modulo      in ge_modalidades.cod_modulo%type,
                                                      p_cod_modalidad   in ge_modalidades.cod_modalidad%type)
  return varchar2 is
  v_cod_gru_transaccion ge_gru_transacciones_det.cod_gru_transaccion%type;
  v_tip_comprobante varchar2(3);
begin
  begin
  select t.cod_gru_transaccion
    into v_cod_gru_transaccion
    from ge_gru_transacciones_det t
   where t.cod_transaccion = p_cod_transaccion
     and t.cod_modulo = p_cod_modulo
     and t.cod_modalidad = p_cod_modalidad;
 exception
   when no_data_found then
     v_tip_comprobante:='OT';
 end;
   if fug_obt_pardinamico('COD_GRU_PAG_TARJETAS') = v_cod_gru_transaccion then
     v_tip_comprobante:='PT';
   elsif fug_obt_pardinamico('COD_GRU_TRA_TARJETAS') = v_cod_gru_transaccion then
     v_tip_comprobante:='TT';
   elsif fug_obt_pardinamico('COD_GRU_CAR_TARJETAS') = v_cod_gru_transaccion then
     v_tip_comprobante:='OTT';
   elsif fug_obt_pardinamico('COD_GRU_CAR_PREPAGA') = v_cod_gru_transaccion then
     v_tip_comprobante:='CTP';
   elsif fug_obt_pardinamico('COD_GRU_CRED_VARIOS') = v_cod_gru_transaccion then
     v_tip_comprobante:='CV';
   else
      v_tip_comprobante:='OT';
   end if;

   return v_tip_comprobante;

exception
  when no_data_found then
    return null;
  when others then
    return null;
end fug_obt_tip_transaccion;
/

