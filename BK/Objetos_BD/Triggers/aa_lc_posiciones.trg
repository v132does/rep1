CREATE OR REPLACE TRIGGER IT.AA_LC_POSICIONES
 AFTER DELETE OR UPDATE
 ON LC_POSICIONES
 FOR EACH ROW

DECLARE
r_laudi lc_auditorias%rowtype; -- Registro de la tabla LC_AUDITORIAS
BEGIN
   r_laudi.tabla := 'LC_POSICIONES';
   r_laudi.clave := to_char(:old.cod_ofi_cambio)||'#'||:old.cod_moneda||'#'||:old.cod_tip_ope_bcp;
   r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_laudi.tip_novedad := 'M';
   elsif deleting then
      r_laudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_laudi.detalle := pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_COM_EFE_ANT',:old.mto_com_efe_ant,:new.mto_com_efe_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_COM_NEF_ANT',:old.mto_com_nef_ant,:new.mto_com_nef_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_COM_EFE_ACT',:old.mto_com_efe_act,:new.mto_com_efe_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_COM_NEF_ACT',:old.mto_com_nef_act,:new.mto_com_nef_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_VTA_EFE_ANT',:old.mto_vta_efe_ant,:new.mto_vta_efe_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_VTA_NEF_ANT',:old.mto_vta_nef_ant,:new.mto_vta_nef_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_VTA_EFE_ACT',:old.mto_vta_efe_act,:new.mto_vta_efe_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_VTA_NEF_ACT',:old.mto_vta_nef_act,:new.mto_vta_nef_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_COM_EFE_ANT',:old.mto_arb_com_efe_ant,:new.mto_arb_com_efe_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_COM_NEF_ANT',:old.mto_arb_com_nef_ant,:new.mto_arb_com_nef_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_COM_EFE_ACT',:old.mto_arb_com_efe_act,:new.mto_arb_com_efe_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_COM_NEF_ACT',:old.mto_arb_com_nef_act,:new.mto_arb_com_nef_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_VTA_EFE_ANT',:old.mto_arb_vta_efe_ant,:new.mto_arb_vta_efe_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_VTA_NEF_ANT',:old.mto_arb_vta_nef_ant,:new.mto_arb_vta_nef_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_VTA_EFE_ACT',:old.mto_arb_vta_efe_act,:new.mto_arb_vta_efe_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_ARB_VTA_NEF_ACT',:old.mto_arb_vta_nef_act,:new.mto_arb_vta_nef_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_COM_EFE_ANT',:old.mto_cje_com_efe_ant,:new.mto_cje_com_efe_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_COM_NEF_ANT',:old.mto_cje_com_nef_ant,:new.mto_cje_com_nef_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_COM_EFE_ACT',:old.mto_cje_com_efe_act,:new.mto_cje_com_efe_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_COM_NEF_ACT',:old.mto_cje_com_nef_act,:new.mto_cje_com_nef_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_VTA_EFE_ANT',:old.mto_cje_vta_efe_ant,:new.mto_cje_vta_efe_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_VTA_NEF_ANT',:old.mto_cje_vta_nef_ant,:new.mto_cje_vta_nef_ant,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_VTA_EFE_ACT',:old.mto_cje_vta_efe_act,:new.mto_cje_vta_efe_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_CJE_VTA_NEF_ACT',:old.mto_cje_vta_nef_act,:new.mto_cje_vta_nef_act,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_COM_EFE_LOC',:old.mto_com_efe_loc,:new.mto_com_efe_loc,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_COM_NEF_LOC',:old.mto_com_nef_loc,:new.mto_com_nef_loc,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_VTA_EFE_LOC',:old.mto_vta_efe_loc,:new.mto_vta_efe_loc,'M');
   r_laudi.detalle := r_laudi.detalle||pae_cnf.fu_reg_auditoria(r_laudi.tip_novedad,'MTO_VTA_NEF_LOC',:old.mto_vta_nef_loc,:new.mto_vta_nef_loc,'M');
   --- Insertar tabla de auditoria
   PRL_INS_LC_AUDITORIA(r_laudi);
END;
/

