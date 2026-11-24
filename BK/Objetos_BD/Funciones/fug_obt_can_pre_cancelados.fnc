create or replace function it.FUG_OBT_CAN_PRE_CANCELADOS
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_COD_MODALIDAD IN NUMBER DEFAULT NULL,     --- Modalidad de cuenta
   P_COD_MONEDA    IN VARCHAR2 DEFAULT NULL)   --- moneda de la cuenta
  return number is
  Result number;
begin
  -- Busca la cantidad de préstamos cancelados anticipadamente
select count(*)
  into Result
  from pr_cta_prestamos p, ge_cta_clientes g
 where nvl( p.estado, 'N' ) = 'N'
   and p.fec_cancelacion < p.fec_vencimiento
   and to_char( p.fec_cancelacion, 'MM/YYYY' ) = to_char( fue_obt_fec_calendar(6), 'MM/YYYY' )
   and nvl( g.relacion, 'P' ) = 'P'
   and g.cod_persona = p_cod_persona
   and p.cod_modalidad = nvl( p_cod_modalidad, p.cod_modalidad )
   and p.cod_moneda = nvl( p_cod_moneda, p.cod_moneda )
   and p.nro_cuenta = g.nro_cuenta ;
  return(Result);
exception
  when others then
     raise_application_error(-20000,'FUG_OBT_CAN_PRE_CANCELADOS '||sqlerrm);
end FUG_OBT_CAN_PRE_CANCELADOS;
/

