CREATE OR REPLACE TRIGGER IT.aa_ge_snp_patrocinador_det
 AFTER DELETE OR UPDATE
 ON ge_snp_patrocinador_det
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'ge_snp_patrocinador_det';
   r_eaudi.clave := to_char(:old.cod_swift_padre);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_SWIFT_PADRE',:old.cod_swift_padre,:new.cod_swift_padre);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SUBPARTICIPANTE',:old.subparticipante,:new.subparticipante);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_SWIFT_SUB',:old.cod_swift_sub,:new.cod_swift_sub);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CTA_INTERNA_SUB',:old.cta_interna_sub,:new.cta_interna_sub);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'USU_INSERCION',:old.usu_insercion,:new.usu_insercion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_MODIFICACION',:old.fec_modificacion,:new.fec_modificacion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'USU_MODIFICACION',:old.usu_modificacion,:new.usu_modificacion);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/

