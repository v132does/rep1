create or replace function it.fug_obt_nom_cuenta(p_nro_cuenta in varchar2)
return varchar2 is
v_denominacion ge_cuentas.denominacion%type;
begin
  select denominacion
    into v_denominacion
    from ge_cuentas
   where nro_cuenta = p_nro_cuenta;
  return v_denominacion;
exception
   when others then
       return null;
end;
/

