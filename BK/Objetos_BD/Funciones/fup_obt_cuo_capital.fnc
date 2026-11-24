create or replace function it.fup_obt_cuo_capital (p_nro_cuenta pr_cuotas.nro_cuenta%type)
return Number is
v_cuo number(10);
begin
  Select count(*)
  into v_cuo
  from pr_cuotas
  where nro_cuenta = p_nro_cuenta
  and mto_capital <> 0 ;

return v_cuo;

end;
/

