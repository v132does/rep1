create or replace procedure it.PRG_OBT_MTO_IMPUESTO
 (P_NRO_CUENTA     IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_COD_OFI_ORIGEN IN GE_CUENTAS.COD_OFICINA%TYPE
 ,P_MONTO          IN GE_MOVIMIENTOS.MONTO%TYPE
 ,P_IMPUESTO       OUT GE_MOVIMIENTOS.MONTO%TYPE
 ,P_COD_TASA       OUT GE_MOVIMIENTOS.COD_TASA%TYPE
 ,P_VAL_TASA       OUT GE_MOVIMIENTOS.VAL_TASA%TYPE)
 IS
 
 v_cod_tas_cargo    ge_movimientos.cod_tasa%type;
 v_val_tas_cargo    ge_movimientos.val_tasa%type;
 v_val_cargo        ge_movimientos.val_tasa%type;
 v_cod_tra_impuesto ge_movimientos.cod_transaccion%type;
 v_cod_tas_impuesto ge_movimientos.cod_tasa%type;
 v_val_tas_impuesto ge_movimientos.val_tasa%type;
 v_val_impuesto     ge_movimientos.val_tasa%type;
 
begin

  pag_cta.pr_obt_cuenta(p_nro_cuenta);
  
  PRG_OBT_CARGOS(p_cod_ofi_origen,
                 p_nro_cuenta,
                 pag_cta.g_ctas.cod_moneda,
                 p_monto,
                 pag_cta.g_ctas.cod_modulo,
                 pag_cta.g_ctas.cod_modalidad,
                 572,
                 v_cod_tas_cargo,
                 v_val_tas_cargo,
                 v_val_cargo,
                 v_cod_tra_impuesto,
                 v_cod_tas_impuesto,
                 v_val_tas_impuesto,
                 v_val_impuesto);
                 
   p_impuesto := v_val_cargo;
   p_cod_tasa := v_cod_tas_cargo;
   p_val_tasa := v_val_tas_cargo;
                 
end PRG_OBT_MTO_IMPUESTO;
/

