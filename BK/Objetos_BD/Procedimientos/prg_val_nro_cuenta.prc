CREATE OR REPLACE PROCEDURE IT.PRG_VAL_NRO_CUENTA(P_VALOR IN VARCHAR2) IS
 v_exi_cuenta varchar2(1) := 'N';
begin
  select decode(nvl(count(*),0),0,'N','S')
    into v_exi_cuenta
    from ge_cuentas a
   where a.nro_cuenta = P_VALOR;

  If v_exi_cuenta = 'N' then
    raise_application_error(-20000,'Nro. de Cuenta '||P_VALOR||' Incorrecto o No Existe. Verifique.');
  end if;
end;
/

