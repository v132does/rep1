create or replace function it.fug_ver_sal_embargo
 (p_nro_cuenta ge_embargos_det.nro_cuenta%TYPE) return number
 is
 v_sal_embargo ge_embargos.sal_embargo%TYPE;
 --Devuelve el saldo de embargo pendiente de la cuenta
begin
   begin
     select sum(nvl(b.sal_embargo,0))
       into v_sal_embargo
       from ge_embargos a,
            ge_embargos_det b
      where a.cod_embargo = b.cod_embargo
        and b.sal_embargo > 0
        and b.nro_cuenta = p_nro_cuenta;
     return v_sal_embargo;
   exception
     when others then
       return 0;
   end;
end fug_ver_sal_embargo;
/

