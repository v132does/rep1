CREATE OR REPLACE TRIGGER IT.AA_GE_COB_SER_PARAMETROS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_COB_SER_PARAMETROS
 FOR EACH ROW

DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla AUDITORIA
BEGIN
   r_gaudi.tabla := 'GE_COB_SER_PARAMETROS';
   r_gaudi.clave := to_char(:old.cod_servicio);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HAB_CAJA',:old.hab_caja,:new.hab_caja);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ETI_CAMPO1',:old.eti_campo1,:new.eti_campo1);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FOR_CAMPO1',:old.for_campo1,:new.for_campo1);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_CAMPO1',:old.val_campo1,:new.val_campo1);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ETI_CAMPO2',:old.eti_campo1,:new.eti_campo2);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FOR_CAMPO2',:old.for_campo1,:new.for_campo2);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_CAMPO2',:old.val_campo1,:new.val_campo2);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SIG_NRO_REMISION',:old.sig_nro_remision,:new.sig_nro_remision,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ULT_REMISION',:old.fec_ult_remision,:new.fec_ult_remision,'F');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRA_COMISION',:old.cod_tra_comision,:new.cod_tra_comision,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DEB_AUTOMATICO',:old.deb_automatico,:new.deb_automatico);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MOD_CTA_REMISION',:old.cod_mod_cta_remision,:new.cod_mod_cta_remision,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MAD_CTA_REMISION',:old.cod_mad_cta_remision,:new.cod_mad_cta_remision,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFI_CTA_REMISION',:old.cod_ofi_cta_remision,:new.cod_ofi_cta_remision,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CTA_REMISION',:old.nro_cta_remision,:new.nro_cta_remision);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CENTRALIZADO',:old.centralizado,:new.centralizado);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COM_INCLUIDA',:old.com_incluida,:new.com_incluida);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COB_COMISION',:old.cob_comision,:new.cob_comision);
    --- Insertar tabla de auditoria
    PRG_INS_GE_AUDITORIA(r_gaudi);
EXCEPTION
  when others then
    PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

