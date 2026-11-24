CREATE OR REPLACE FUNCTION IT.FUC_OBT_MON_SEGURO(p_nro_cuenta     in ge_cuentas.nro_cuenta%type,
                                                p_fecha          in ge_movimientos.fecha%type,
                                                p_cod_moneda     in ba_monedas.cod_moneda%type,
                                                p_cod_ofi_origen in ba_oficinas.cod_oficina%type)
  return Number is
  v_cod_tas_cargo    ge_tasas.cod_tasa%type;
  v_val_tas_cargo    number;
  v_val_cargo        number;
  v_cod_tra_impuesto ge_transacciones.cod_transaccion%type;
  v_cod_tas_impuesto ge_tasas.cod_tasa%type;
  v_val_tas_impuesto number;
  v_val_impuesto     number;

  v_monto number;
  v_iva   number;
begin
  /* antes el sal_medio era multiplicado por 0.05%, luego por 0,038%, actualmente por 0,050%*/
  v_monto := round((fuc_obt_sal_medio(p_nro_cuenta, p_fecha, p_cod_moneda) *
                   0.05 / 100),
                   fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                       NULL,
                                       NULL,
                                       p_cod_moneda));

  -- Calcular el IVA
  prg_obt_cargos(p_cod_ofi_origen,
                 p_nro_cuenta,
                 p_cod_moneda,
                 999999,
                 4,
                 41,
                 983,
                 v_cod_tas_cargo,
                 v_val_tas_cargo,
                 v_val_cargo,
                 v_cod_tra_impuesto,
                 v_cod_tas_impuesto,
                 v_val_tas_impuesto,
                 v_val_impuesto);

  v_iva := round(nvl(v_monto, 0) * nvl(v_val_tas_impuesto, 0) / 100,
                 fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                                     NULL,
                                     NULL,
                                     p_cod_moneda));
  --return nvl(v_monto,0)+nvl(v_iva,0); --comentado para que salga bien el premio 25.03.2013
  return nvl(v_monto, 0);
end;
/

