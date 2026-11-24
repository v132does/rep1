CREATE OR REPLACE FUNCTION IT.FUG_OBT_RES_CLIENTE (p_cod_persona in ge_clientes.cod_persona%type)
return varchar2 is

v_residente ge_clientes.residente%type;
begin
  select residente
    into v_residente
    from ge_clientes
   where cod_persona = p_cod_persona;
   return v_residente;
exception
   when no_data_found then
      return null;
   when others then
      raise_Application_error(-20000,'Obt.Res cliente.'||sqlerrm);
end;
/

