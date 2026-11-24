create or replace function it.fug_monto_seguro(p_saldo_medio in number,
                                            p_nro_cta     in cc_cta_corrientes.nro_cuenta%type,
                                            p_moneda      in cc_cta_corrientes.cod_moneda%type,
                                            p_ofi         in ba_oficinas.cod_oficina%type)
  return Number is
  v_cod_tas_cargo    ge_tasas.cod_tasa%type;
  v_val_tas_cargo    number;
  v_val_cargo        number;
  v_cod_tra_impuesto ge_transacciones.cod_transaccion%type;
  v_cod_tas_impuesto ge_tasas.cod_tasa%type;
  v_val_tas_impuesto number;
  v_val_impuesto     number;
  v_porc             number;
  v_monto            number;
  v_iva              number;
  
 
begin
  
 
  v_porc  := to_number(nvl(fug_obt_pardinamico('POR_ASEGURADORA'),0), '999G999G999D999999', 'NLS_NUMERIC_CHARACTERS = ''.,''');
  
  v_monto := to_number( round((p_saldo_medio * v_porc) / 100));
  
             
  
  --
  -- Calcular el IVA
  prg_obt_cargos(p_ofi,
                 p_nro_cta,
                 p_moneda,
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
  ---
  v_iva := round(nvl(v_monto, 0) * nvl(v_val_tas_impuesto, 0) / 100,
                 fug_obt_redondeo_seg(p_moneda));
  return nvl(v_monto, 0) + nvl(v_iva, 0);
end;
/

