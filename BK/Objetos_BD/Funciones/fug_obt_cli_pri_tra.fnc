create or replace function it.fug_obt_cli_pri_tra ( p_nro_cuenta in varchar2,
                                                   p_relacion varchar2 default null)
return varchar2 is
  v_cod_cliente ge_cta_clientes.cod_persona%type;
begin
  select cod_persona
    into v_cod_cliente
    from ge_cta_clientes
   where nro_cuenta = p_nro_cuenta
     and relacion   = nvl(p_relacion,'P'); 
  return v_cod_cliente;
exception
   when others then
      return '0';
end;
/

