create or replace function it.FUG_OBT_SAL_DIARIO
  (P_NRO_CUENTA IN VARCHAR2,   --- Número de cuenta
   P_FECHA IN DATE)            --- Fecha
  return number is
  Result NUMBER;
begin
  select t.sal_tot_cap
    into Result
    from ge_sal_diarios t
   where t.nro_cuenta = p_nro_cuenta
     and t.fecha = p_fecha;
  return(Result);
exception
  when no_data_found then
    return 0;
  when too_many_rows then
    return 0;
  when others then
     return 0;
end FUG_OBT_SAL_DIARIO;
/

