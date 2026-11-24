CREATE OR REPLACE TRIGGER IT.AA_GE_CHEQUES_DET
 AFTER DELETE OR UPDATE
 ON GE_CHEQUES_DET
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CHEQUES_DET';
   r_gaudi.clave := to_char(:old.cod_banco)||'#'||to_char(:old.nro_cheque);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CTA_LIBRADORA',:old.cta_libradora,:new.cta_libradora);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CUOTA',:old.nro_cuota,:new.nro_cuota,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_INGRESO',:old.fec_ingreso,:new.fec_ingreso,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_DOCUMENTO',:old.nro_documento,:new.nro_documento,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFI_CAMARA',:old.cod_ofi_camara,:new.cod_ofi_camara,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_DEPOSITO',:old.fec_deposito,:new.fec_deposito,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_BAN_DEPOSITO',:old.cod_ban_deposito,:new.cod_ban_deposito,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_BOL_DEPOSITO',:old.nro_bol_deposito,:new.nro_bol_deposito,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_RETENCION',:old.cod_retencion,:new.cod_retencion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LIB_POSTERIOR',:old.lib_posterior,:new.lib_posterior);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LIBERADO',:old.liberado,:new.liberado);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

