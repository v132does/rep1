CREATE OR REPLACE FUNCTION IT.FUG_OBT_VAL_TAS_ACT(p_cod_modulo      in ge_cuentas.cod_modulo%type,
                                               p_cod_modalidad   in ge_cuentas.cod_modalidad%type,
                                               p_monto           in ge_movimientos.cod_transaccion%type,
                                               p_can_dias        in ge_movimientos.val_tasa%type,
                                               p_cod_moneda      in ge_movimientos.cod_moneda%type)
  return number is
v_tasa number;
Begin
      Begin
          SELECT MAX(p.tas_interes)
              INTO v_tasa
              FROM cr_piz_montos m, cr_piz_plazos p
             WHERE m.cod_moneda = p.cod_moneda
               AND m.cod_moneda = p_cod_moneda
               AND m.mto_desde = p.mto_desde
               AND m.cod_modulo = p.cod_modulo
               AND m.cod_modalidad = p.cod_modalidad
               AND NVL(m.cod_sub_modalidad, -1) = NVL(p.cod_sub_modalidad, -1)
               AND m.cod_modulo = p_cod_modulo
               AND m.cod_modalidad = p_cod_modalidad
               AND p_can_dias BETWEEN p.plz_desde AND p.plz_hasta
               AND p_monto BETWEEN m.mto_desde AND m.mto_hasta;
          Exception
            When no_data_found then
               v_tasa := 0;
            When too_many_rows then
               raise_application_error(-20001,'TASA INTERES Duplicada en la Pizarra de Productos. Módulo: '||p_cod_modulo||'; Modalidad: '||p_cod_modalidad);
            When others then
               raise_application_error(-20001,'Error en FUG_OBT_VAL_TAS_MAX: '||sqlerrm);
      End;
      return v_tasa;
End;
/

