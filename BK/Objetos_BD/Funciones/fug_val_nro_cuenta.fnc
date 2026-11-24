CREATE OR REPLACE FUNCTION IT.FUG_VAL_NRO_CUENTA(p_nro_cuenta IN ge_cuentas.nro_cuenta%type)
  RETURN VARCHAR2 IS
  v_existe varchar2(1);
BEGIN
  select 'S'
    into v_existe
    from ge_cuentas a
   where a.nro_cuenta = p_nro_cuenta;
  return v_existe;
exception
  when others then
    return 'N';
END;
/

