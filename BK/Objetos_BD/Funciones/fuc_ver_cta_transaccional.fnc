create or replace function it.FUC_VER_CTA_TRANSACCIONAL
(P_NRO_CUENTA   ge_cuentas.nro_cuenta%TYPE)
  return varchar2 is
--verifica si es una cuentra transaccional
  v_exi_cta_tran varchar2(1) := 'N';
  v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_est_modulo ba_modulos.cod_modulo%type := pae_cnf.fu_obt_est_modulo(3);
  v_fec_proceso date;
begin
  if v_est_modulo = 2 then
     v_Fec_proceso := v_fec_actual;
  else
     v_fec_proceso := pag_cal.FU_OBT_FEC_HABIL(v_fec_actual+1, 1, 31);
  end if;
  
  begin
    select 'S'
      into v_exi_cta_tran
      from cc_cta_transaccionales
     where nro_cuenta = p_nro_cuenta
       and (activo = 'S' or (activo = 'N' and fec_inactivacion > v_fec_proceso))
       and fec_activacion <= v_fec_proceso;
   exception
      when others then
        v_exi_cta_tran := 'N';
   end;
   return nvl(v_exi_cta_tran, 'N');
exception
  when others then
    return 'N';
end FUC_VER_CTA_TRANSACCIONAL;
/

