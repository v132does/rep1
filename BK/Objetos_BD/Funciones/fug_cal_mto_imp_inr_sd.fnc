create or replace function it.FUG_CAL_MTO_IMP_INR_SD(p_mto_transferencia number, p_cod_moneda varchar2) return number is
  v_por_ret_inr number := fug_obt_pardinamico('POR_RET_INR_SD');
  v_mto_ret_inr number;
  v_redondeo number;
begin
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,p_cod_moneda);
   v_mto_ret_inr := round((p_mto_transferencia * (v_por_ret_inr/100)),v_redondeo);
  return(v_mto_ret_inr);
end FUG_CAL_MTO_IMP_INR_SD;
/

