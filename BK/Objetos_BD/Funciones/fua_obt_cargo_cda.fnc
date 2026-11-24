CREATE OR REPLACE FUNCTION IT.FUA_OBT_CARGO_CDA
 (P_VAL_TASA   IN NUMBER,
  P_COD_MONEDA IN VARCHAR2,
  P_CAPITAL IN AH_CTA_CERTIFICADOS.CAPITAL%TYPE)
 RETURN NUMBER
 IS
v_monto  number(18,2);
v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
BEGIN
   v_monto := p_capital * p_val_tasa * 30 /*dias*/ / 36500;
   if p_cod_moneda = v_cod_mon_local then
      v_monto := round(v_monto,fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',3,33,v_cod_mon_local,null));
   end if;
   return v_monto;
END;
/

