create or replace function it.fug_es_cli_vip_principal(p_nro_cuenta IN VARCHAR2) return varchar2 is
  v_cli_especial VARCHAR2(1) := 'N';
begin
  -- Verifico si el cliente es vip
  Select 'S'
    into v_cli_especial
    from ge_clientes a, ge_cta_clientes b
   where a.cod_persona = b.cod_persona
     and b.nro_cuenta = p_nro_cuenta
     and b.relacion = 'P'
     and cli_especial = 'S';
  return(v_cli_especial);
exception
  when no_data_found then
     return ('N');
  when others then
     raise_application_error(-20000,'FUG_ES_CLI_VIP_PRINCIPAL '||sqlerrm);
end fug_es_cli_vip_principal;
/

