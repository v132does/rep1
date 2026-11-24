CREATE OR REPLACE FUNCTION IT.FUG_OBT_TIP_DEUDOR (p_cod_persona in ge_clientes.cod_persona%type)
return number is

v_cod_tip_deudor ge_clientes.cod_tip_deudor%type;
begin
  select cod_tip_deudor
    into v_cod_tip_deudor
    from ge_clientes
   where cod_persona = p_cod_persona;
   return v_cod_tip_deudor;
exception
   when no_data_found then
      return null;
   when others then
      raise_Application_error(-20000,'Obt.TIP deudor cliente.'||sqlerrm);
end;
/

