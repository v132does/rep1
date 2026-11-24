create or replace function it.FUP_OBT_SAL_MENSUAL
  (P_NRO_CUENTA IN VARCHAR2,   ---Número de cuenta
   P_FECHA IN DATE)            ---Fecha
  return number is
  Result NUMBER;
  v_ano pr_sal_mensuales.ano%type;
  v_mes pr_sal_mensuales.mes%type;
begin
  v_ano := to_char(p_fecha,'YYYY');
  v_mes := to_char(p_fecha,'MM');
  select t.sal_cap_actual
    into Result
    from pr_sal_mensuales t
   where t.nro_cuenta = p_nro_cuenta
     and t.ano = v_ano
     and t.mes = v_mes;
  return(Result);
exception
  when no_data_found then
    return 0;
  when too_many_rows then
    return 0;
  when others then
     return 0;
end FUP_OBT_SAL_MENSUAL;
/

