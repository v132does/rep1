create or replace function it.FUG_OBT_DIA_A_VENCER
  (P_COD_PERSONA IN VARCHAR2,                  --- Codigo de la persona
   P_COD_MODALIDAD IN NUMBER DEFAULT NULL,     --- Modalidad de cuenta  
   P_COD_MONEDA    IN VARCHAR2 DEFAULT NULL)   --- moneda de la cuenta
  return number is
  v_dia_a_vencer    number;  -- dia a vencer de la operacion
begin
  -- Busco los datos de atrasos en las cuentas que tiene el cliente
  SELECT  NVL(a.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(1),0) dias_a_vencer
    INTO v_dia_a_vencer
    from GE_CUENTAS a, GE_CTA_CLIENTES B
   WHERE a.nro_cuenta = b.nro_cuenta
     and b.relacion = 'P'
     and b.cod_persona = p_cod_persona
     and b.cod_modalidad = nvl(p_cod_modalidad,b.cod_modalidad)
     and a.cod_moneda = nvl(p_cod_moneda,a.cod_moneda)
     and exists (Select 0
                   from ge_est_cuentas c
                  where c.cod_modulo = b.cod_modulo
                    and c.cod_modalidad = b.cod_modalidad
                    and c.estado = a.estado
                    and c.activo = 'S');
  return v_dia_a_vencer;
exception
  when no_data_found then
     return null;
  when others then
     return null;
end FUG_OBT_DIA_A_VENCER;
/

