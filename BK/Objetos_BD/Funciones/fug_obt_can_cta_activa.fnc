create or replace function it.FUG_OBT_CAN_CTA_ACTIVA
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_COD_MODALIDAD IN NUMBER DEFAULT NULL,     --- Modalidad de cuenta
   P_COD_MONEDA    IN VARCHAR2 DEFAULT NULL)   --- moneda de la cuenta
  return number is
  Result NUMBER;
begin
  -- Busco la cantidad de cuentas que posee el cliente
  SELECT COUNT(*)
    INTO Result
    from GE_CUENTAS a, GE_CTA_CLIENTES B
   WHERE a.nro_cuenta = b.nro_cuenta
     and b.relacion ='P'
     and b.cod_persona = p_cod_persona
     and b.cod_modalidad = nvl(p_cod_modalidad,b.cod_modalidad)
     and a.cod_moneda = nvl(p_cod_moneda,a.cod_moneda)
     and exists (Select 0
                   from ge_est_cuentas c
                  where c.cod_modulo = b.cod_modulo
                    and c.cod_modalidad = b.cod_modalidad
                    and c.estado = a.estado
                    and c.activo = 'S');
  return(Result);
exception
  when others then
     raise_application_error(-20000,'FUG_OBT_CAN_CTA_ACTIVA '||sqlerrm);
end FUG_OBT_CAN_CTA_ACTIVA;
/

