CREATE OR REPLACE FUNCTION IT.FUG_OBT_SEC_CONTABLE (p_cod_persona in ge_clientes.cod_persona%type)
return varchar2 is

v_cod_sec_contable ge_clientes.cod_sec_contable%type;
begin
  select cod_sec_contable
    into v_cod_sec_contable
    from ge_clientes
   where cod_persona = p_cod_persona;
   return v_cod_sec_contable;
exception
   when no_data_found then
      return null;
   when others then
      raise_Application_error(-20000,'Obt.Sec Contble.'||sqlerrm);
end;
/

