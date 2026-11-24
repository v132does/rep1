create or replace function it.fug_obt_nro_cta_bt(
   p_nro_cuenta ge_cuentas.nro_cuenta%type)
   return varchar2
is
  v_nro_cta_bt ge_cta_clientes.nro_cta_cli_btw%type;
begin
   begin
      select nro_cta_cli_btw
        into v_nro_cta_bt
        from ge_cta_clientes a
       where nro_cuenta = p_nro_cuenta
         and relacion = 'P';
   exception
      when others then
         return null;
   end;
   ---
   if v_nro_cta_bt is not null then
      return('Cuenta '||p_nro_cuenta||' migrada a BTW '||v_nro_cta_bt);
   else
      return null;
   end if;
end;
/

