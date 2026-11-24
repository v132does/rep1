create or replace function it.fuc_obt_dia_atraso(p_nro_cuenta ge_cuentas.nro_cuenta%type)
  return number is
  v_dia_atraso cc_sobregiros_res.can_dias%type;
begin
  Select s.can_dias
    into v_dia_atraso
    from cc_sobregiros_res s
   where s.nro_cuenta = p_nro_cuenta;
  -- Retorna los dias de atraso --
  return v_dia_atraso;
exception
  when others then
    return 0;
end fuc_obt_dia_atraso;
/

