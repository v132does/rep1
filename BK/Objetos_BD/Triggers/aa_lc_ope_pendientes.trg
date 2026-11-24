CREATE OR REPLACE TRIGGER IT.AA_LC_OPE_PENDIENTES
 AFTER DELETE OR UPDATE
 ON LC_OPE_PENDIENTES
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_OPE_PENDIENTES';
   r_laudi.clave := :old.cod_tip_operacion||'#'||to_char(:old.nro_operacion);
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TIP_OPERACION',:old.cod_tip_operacion,:new.cod_tip_operacion);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'REFERENCIADO',:old.referenciado,:new.referenciado);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TIP_REFERENCIA',:old.cod_tip_referencia,:new.cod_tip_referencia);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_REFERENCIA',:old.nro_referencia,:new.nro_referencia,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TIP_OPE_BCP',:old.cod_tip_ope_bcp,:new.cod_tip_ope_bcp);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_OPERACION',:old.fec_operacion,:new.fec_operacion,'F');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COTIZACION',:old.cotizacion,:new.cotizacion,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_EQU_LOCAL',:old.mto_equ_local,:new.mto_equ_local,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO1',:old.cod_tra_cargo1,:new.cod_tra_cargo1,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CARGO1',:old.mto_cargo1,:new.mto_cargo1,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO2',:old.cod_tra_cargo2,:new.cod_tra_cargo2,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CARGO2',:old.mto_cargo2,:new.mto_cargo2,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO3',:old.cod_tra_cargo3,:new.cod_tra_cargo3,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CARGO3',:old.mto_cargo3,:new.mto_cargo3,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_TRA_CARGO4',:old.cod_tra_cargo4,:new.cod_tra_cargo4,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CARGO4',:old.mto_cargo4,:new.mto_cargo4,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_CTA_BANCARIA',:old.nro_cta_bancaria,:new.nro_cta_bancaria);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CTA_REFERENCIA',:old.cta_referencia,:new.cta_referencia);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CTA_REF_CONTRA1',:old.cta_ref_contra1,:new.cta_ref_contra1);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CONTRA1',:old.mto_contra1,:new.mto_contra1,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CTA_REF_CONTRA2',:old.cta_ref_contra2,:new.cta_ref_contra2);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CONTRA2',:old.mto_contra2,:new.mto_contra2,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CTA_REF_CONTRA3',:old.cta_ref_contra3,:new.cta_ref_contra3);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CONTRA3',:old.mto_contra3,:new.mto_contra3,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CTA_REF_CONTRA4',:old.cta_ref_contra4,:new.cta_ref_contra4);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CONTRA4',:old.mto_contra4,:new.mto_contra4,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_CHEQUE',:old.nro_cheque,:new.nro_cheque);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_BOLETA',:old.nro_boleta,:new.nro_boleta,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CONCEPTO',:old.concepto,:new.concepto);
   if r_laudi.tip_novedad = 'M' then
      r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'OBSERVACION',substr(:old.observacion,1,200),substr(:new.observacion,1,200));
   end if;
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'LIQUIDADO',:old.liquidado,:new.liquidado);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_USU_LIQUIDACION',:old.cod_usu_liquidacion,:new.cod_usu_liquidacion);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'FEC_LIQUIDACION',:old.fec_liquidacion,:new.fec_liquidacion,'F');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'CTA_REF_CONTRA5',:old.cta_ref_contra5,:new.cta_ref_contra5);
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CONTRA5',:old.mto_contra5,:new.mto_contra5,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_RETENCION',:old.cod_retencion,:new.cod_retencion,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'NRO_DIARIO',:old.nro_diario,:new.nro_diario,'N');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'OPE_HOMEBANKING',:old.ope_homebanking,:new.ope_homebanking);
	 r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'COD_MON_DESTINO',:old.cod_mon_destino,:new.cod_mon_destino);

   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/

