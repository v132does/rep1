CREATE OR REPLACE TRIGGER IT.AA_CR_PER_RECLAMOS
 AFTER DELETE OR UPDATE
 ON CR_PER_RECLAMOS
 FOR EACH ROW

DECLARE
   r_eaudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'CR_PER_RECLAMOS';
   r_eaudi.clave := to_char(:old.nro_reclamo);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_RECLAMO',:old.nro_reclamo,:new.nro_reclamo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_RECLAMO',:old.cod_reclamo,:new.cod_reclamo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SUB_TIP_RECLAMO',:old.sub_tip_reclamo,:new.sub_tip_reclamo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_RESPONSABLE',:old.cod_usu_responsable,:new.cod_usu_responsable);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_SOLUCION',:old.fec_solucion,:new.fec_solucion,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_REC_ESTADO',:old.cod_rec_estado,:new.cod_rec_estado,'N');
   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_eaudi);
END;
/

