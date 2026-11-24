create or replace function it.FUG_OBT_LIN_CREDITO
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_COD_MODALIDAD IN NUMBER DEFAULT NULL)     --- Modalidad de cuenta
  return number is
  Result number;
begin
  select nvl(c.lin_credito,0)
    into Result
    from ta_tarjetas t, ta_cta_tarjetas c, ge_cta_clientes a
   where t.nro_cuenta = c.nro_cuenta
     and t.cod_persona = p_cod_persona
     and c.cod_modalidad = p_cod_modalidad
     and a.cod_persona = P_COD_PERSONA
     and a.nro_cuenta =c.nro_cuenta
     and a.relacion='P'
     and c.estado <> 'C'
     /*FB. 25.06.2010 Agregado para tomar solo las tarjetas en estado
     0-Generada
     1-En Administradora
     2-Recibidad de Adm
     3-Ent. por Currier
     4-Ent. personalmente
     5-Env.a Adm.
     6-Activa*/
     and t.cod_estado <= 6
     and t.fec_vencimiento > trunc(sysdate)
     and t.vigente='S'
     and fug_obt_can_cuentas(P_COD_PERSONA,P_COD_MODALIDAD)> 0;
  return(to_char(Result));
exception
  when no_data_found then
    return 0;
  when too_many_rows then
    return 0;
  when others then
     return 0;
end FUG_OBT_LIN_CREDITO;
/

