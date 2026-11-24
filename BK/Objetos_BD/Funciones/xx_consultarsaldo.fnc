create or replace function it.xx_consultarSaldo(pcuenta in varchar2)
return  varchar2 is
v_saldo number;
begin
   select sal_contable
     into v_saldo
     from ge_cuentas
    where nro_cuenta = pcuenta;
  return v_saldo;
exception
   when others then
       return null;
end;
/

