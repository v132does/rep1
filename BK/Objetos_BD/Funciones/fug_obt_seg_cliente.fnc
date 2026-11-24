CREATE OR REPLACE FUNCTION IT.FUG_OBT_SEG_CLIENTE (p_cod_persona in ge_clientes.cod_persona%type)
return number is

v_cod_seg_cliente ge_clientes.cod_seg_cliente%type;
begin
  select cod_seg_cliente
    into v_cod_seg_cliente
    from ge_clientes
   where cod_persona = p_cod_persona;
   return v_cod_seg_cliente;
exception
   when no_data_found then
      return null;
   when others then
      raise_Application_error(-20000,'Obt.Segmento.'||sqlerrm);
end;
/

