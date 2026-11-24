create or replace function it.FUG_CAL_MTO_IMP_IVA_SD (p_mto_transferencia number, p_cod_moneda varchar2) return number is
  v_por_cob_iva number := fug_obt_pardinamico('POR_COB_IVA_SD');
  v_mto_cob_iva number;
  v_redondeo number;
begin
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',NULL,NULL,p_cod_moneda);
   v_mto_cob_iva := round((p_mto_transferencia * (v_por_cob_iva/100)),v_redondeo);
  return(v_mto_cob_iva);
end FUG_CAL_MTO_IMP_IVA_SD;
/

