create or replace function it.FUP_OBT_DIA_ATRASO
                            (P_COD_PERSONA           IN BA_PERSONAS.COD_PERSONA%TYPE,-- Código de la persona
                             P_NRO_CUENTA            IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL,  --Número de Cuenta
                             P_COD_MODULO            IN BA_MODULOS.COD_MODULO%TYPE DEFAULT NULL,  --- Módulo de la cuenta
                             P_COD_MODALIDAD         IN GE_MODALIDADES.COD_MODALIDAD%TYPE DEFAULT NULL,  --- Modalidad de la cuenta
                             P_COD_MONEDA            IN GE_CUENTAS.COD_MONEDA%TYPE DEFAULT NULL)--- moneda de la cuenta
                             return number is
  ---El objetivo de esta función retornar días de atraso
  v_dia_atraso      ge_cuentas.dia_atraso%type;
begin
  begin
   -- Busco los datos de atrasos en las cuentas que tiene el cliente
   IF p_cod_modalidad is not NULL then
      select max(g.dia_atraso)
        into v_dia_atraso
        from GE_CUENTAS g, GE_CTA_CLIENTES B
       where g.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and b.cod_persona = p_cod_persona
         and g.nro_cuenta = nvl(p_nro_cuenta, g.nro_cuenta)
         and g.cod_modulo = nvl(p_cod_modulo, 6) -- préstamos por defecto
         and b.cod_modalidad = p_cod_modalidad
         and g.cod_moneda = nvl(p_cod_moneda, g.cod_moneda)
         and nvl(g.dia_atraso,0) >= 0
         and exists (Select 0
                       from ge_est_cuentas c
                      where c.cod_modulo = b.cod_modulo
                        and c.cod_modalidad = b.cod_modalidad
                        and c.estado = g.estado
                        and c.activo = 'S');
   ELSE
      select max(g.dia_atraso)
        into v_dia_atraso
        from GE_CUENTAS g, GE_CTA_CLIENTES B
       where g.nro_cuenta = b.nro_cuenta
         and b.relacion = 'P'
         and b.cod_persona = p_cod_persona
         and g.nro_cuenta = nvl(p_nro_cuenta, g.nro_cuenta)
         and g.cod_modulo = nvl(p_cod_modulo, 6) -- préstamos por defecto
         and b.cod_modalidad != 608
         and g.cod_moneda = nvl(p_cod_moneda, g.cod_moneda)
         and nvl(g.dia_atraso,0) >= 0
         and exists (Select 0
                       from ge_est_cuentas c
                      where c.cod_modulo = b.cod_modulo
                        and c.cod_modalidad = b.cod_modalidad
                        and c.estado = g.estado
                        and c.activo = 'S');
   END IF;
  exception
    when no_data_found then
      v_dia_atraso := 0;
    when others then
      v_dia_atraso := 0;
  end;

  return nvl(v_dia_atraso, 0);

exception
  when no_data_found then
    v_dia_atraso := 0;
  when others then
    v_dia_atraso := 0;
end FUP_OBT_DIA_ATRASO;
/

