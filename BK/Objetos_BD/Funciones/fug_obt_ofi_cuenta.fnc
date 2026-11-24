create or replace function it.fug_obt_ofi_cuenta(p_nro_cuenta in varchar2)
  return varchar2 is
  voficina ge_cta_clientes.cod_oficina%type;
begin
  -- recupera la oficina a la que corresponde la cuenta
  select cod_oficina
    into voficina
    from ge_cta_clientes c
   where c.nro_cuenta = p_nro_cuenta
     and relacion = 'P';
  return(voficina);
exception
  when others then
    raise_application_error(-20000, 'FUG_OBT_OFI_CUENTA' || sqlerrm);
end fug_obt_ofi_cuenta;
/

