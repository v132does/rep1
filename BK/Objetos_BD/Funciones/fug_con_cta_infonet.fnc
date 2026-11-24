create or replace function it.fug_con_cta_infonet
(P_NRO_CUENTA   ge_cuentas.nro_cuenta%TYPE)
  return varchar2 is
  V_CTA_DEBITO VARCHAR2(50);
  V_TIP_CUENTA VARCHAR2(10);
begin
  V_CTA_DEBITO := substr('0000000000'||trim(P_NRO_CUENTA),-10);
  v_tip_cuenta := substr(v_cta_debito,4,1);
  if v_tip_cuenta in ('1','3') then
     v_tip_cuenta := '01';
     v_cta_debito := substr(v_cta_debito,2,2)||v_tip_cuenta||substr(v_cta_debito, -6);
  elsif v_tip_cuenta in ('2','4') then
     v_tip_cuenta := '02';
     V_cta_debito := substr(v_cta_debito,2,2)||v_tip_cuenta||substr(v_cta_debito, -6);
  end if;
  return v_cta_debito;
exception
  when others then
    return 'N';
end fug_con_cta_infonet;
/

