create or replace function it.FUC_OBT_MTO_LIN_SOB(p_nro_cuenta in varchar2,
 p_tip_sobregiro in varchar2 default null) return number is
  v_mto_lin_sobregiro number;
begin

  SELECT nvl(sum(SOB.MONTO),0)
    into v_mto_lin_sobregiro
  FROM CC_LIN_SOBREGIROS SOB,
       cc_cta_corrientes cta
  WHERE cta.nro_cuenta = sob.nro_cuenta
    AND SOB.ESTADO = 'A'
    and CTA.estado not in ('X', 'A', 'C')
    AND CTA.NRO_CUENTA = P_NRO_CUENTA
    and fec_vencimiento >= pag_cal.FU_OBT_FEC_ACTUAL(4);

  return(v_mto_lin_sobregiro);
exception
   when others then
       return 0;
end FUC_OBT_MTO_LIN_SOB;
/

