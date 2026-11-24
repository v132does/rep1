create or replace function it.FUG_OBT_SAL_DISPONIBLE
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_COD_MODALIDAD IN NUMBER DEFAULT NULL)   --- moneda de la cuenta
  return number is
  Result NUMBER;
begin
  select (NVL(c.LIN_CREDITO,0) - ( NVL(c.SAL_FACTURAR,0) + NVL(c.SAL_FACTURADO,0)+ nvl(c.sal_financiado,0)))
    into Result
    from ta_tarjetas t, ta_cta_tarjetas c, ge_cta_clientes a
   where t.nro_cuenta = c.nro_cuenta
     and t.cod_persona = p_cod_persona
     and c.cod_modalidad = p_cod_modalidad
     and a.cod_persona = P_COD_PERSONA
     and a.nro_cuenta =c.nro_cuenta
     and a.relacion ='P'
     and t.vigente ='S'
     and t.fec_vencimiento > trunc(sysdate)
     and c.estado <> 'C'
     and fug_obt_can_cuentas(P_COD_PERSONA,P_COD_MODALIDAD)> 0;
  return(Result);
exception
  when no_data_found then
    return 0;
  when too_many_rows then
    return 0;
  when others then
     return 0;
end FUG_OBT_SAL_DISPONIBLE;
/

