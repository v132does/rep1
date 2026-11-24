create or replace function it.FUT_OBT_MON_CUO_TARJETAS
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_COD_MODALIDAD IN NUMBER DEFAULT NULL,     --- Modalidad de cuenta
   P_COD_MONEDA    IN VARCHAR2 DEFAULT NULL)   --- moneda de la cuenta
  return number is
  vmonto ta_cta_tarjetas.sal_cuo_pendientes%type ;
begin
  -- Recupera las compras hechas en cuotas con tarjetas de crédito
  select sum( t.sal_cuo_pendientes )
    into vmonto
    from ta_cta_tarjetas t, ge_cta_clientes g
   where to_char( nvl( t.fec_modificacion, t.fec_insercion ), 'MM/YYYY' ) = to_char( fue_obt_fec_calendar(5), 'MM/YYYY' )
     and nvl( g.relacion, 'P' ) = 'P'
     and g.cod_persona = p_cod_persona
     and t.cod_modalidad = nvl( p_cod_modalidad, t.cod_modalidad )
     and t.cod_moneda = nvl( p_cod_moneda, t.cod_moneda )
     and t.nro_cuenta = g.nro_cuenta;
  return(vmonto);
exception
  when others then
     raise_application_error(-20000,'FUT_OBT_MON_CUO_TARJETAS'||sqlerrm);
end FUT_OBT_MON_CUO_TARJETAS;
/

