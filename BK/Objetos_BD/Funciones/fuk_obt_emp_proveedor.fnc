create or replace function it.fuk_obt_emp_proveedor( p_cod_moneda in varchar2)
return number is
  v_proveedor ge_entes.cod_ente%type;
begin
   select e.cod_ente
   into   v_proveedor
   from   ge_par_generales g, ge_entes e
   where  g.cod_persona = e.cod_persona
   and    e.tipo = 'PR'
   	AND   ( EXISTS (SELECT 0 FROM CB_RUBROS X
	                WHERE X.COD_RUBRO = FUG_OBT_PARENTES(E.COD_ENTE,'COD_RUB_PPROV')
	                  AND X.COD_MONEDA = p_cod_moneda)
	   OR  EXISTS (SELECT 0 FROM GE_CUENTAS X
	                WHERE X.NRO_CUENTA = FUG_OBT_PARENTES(E.COD_ENTE,'CTA_DEB_PPROV')
	                  AND X.COD_MONEDA = p_cod_moneda));   
   return v_proveedor;
end;
/

