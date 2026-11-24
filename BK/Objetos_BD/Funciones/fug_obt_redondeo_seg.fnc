create or replace function it.fug_obt_redondeo_seg(p_cod_moneda in ge_cuentas.cod_moneda%type) return Number is
 v_redondeo number;
begin
  v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,p_cod_moneda);
  return v_redondeo;
end;
/

