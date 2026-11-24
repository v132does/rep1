create or replace function it.FUG_OBT_OFI_CLIENTE
  ( P_COD_PERSONA IN VARCHAR2 )
  return varchar2 is
  voficina ge_clientes.cod_oficina%type;
  -- DYDMR-15674 NAF AGO/2021 - Se incluye opcion de oficina por defecto:
  -- El parametro dinamico FUG_OBT_OFI_CLIENTE_DEF_OFI permite establecer la oficina por defecto
  --    Si el parametro tiene un valor numerico, se utiliza ese valor en caso de no recuperar oficina en la consulta principal
  --    Si el parametro tiene valor X, se omite el valor por defecto y se genera el error
  v_ofi_default ge_par_dinamicos.val_parametro%type;
  FUNCTION is_numeric(p_valor IN VARCHAR2)
      RETURN NUMBER IS
      v_numero NUMBER;
    BEGIN
      v_numero := to_number(p_valor);
      RETURN 1;
    EXCEPTION
      WHEN value_error THEN
        RETURN 0;
    END;
begin
  voficina := null;
  -- Recupera la oficina en la que se encuentra el cliente
  select cod_oficina
    into voficina
    from ge_clientes c
   where c.cod_persona = p_cod_persona ;
    return(voficina);
exception
  when NO_DATA_FOUND THEN
    v_ofi_default := trim(fug_obt_pardinamico('FUG_OBT_OFI_CLIENTE_DEF_OFI'));
    --si el parametro tiene un valor numerico se devuelve el valor del parametro
    if is_numeric(v_ofi_default) = 1 then
       return(to_number(v_ofi_default));
    else
    -- si el parametro es un valor no numerico se genera el error
       raise_application_error(-20000,'FUG_OBT_OFI_CLIENTE: COD_PERSONA '||P_COD_PERSONA||' - NO TIENE OFICINA. '||
       'UTILICE par dinamico FUG_OBT_OFI_CLIENTE_DEF_OFI para establecer valor por defecto.');
    end if;
  when others then
     raise_application_error(-20000,'FUG_OBT_OFI_CLIENTE: '||P_COD_PERSONA||' - '||sqlerrm);
end FUG_OBT_OFI_CLIENTE;
/

