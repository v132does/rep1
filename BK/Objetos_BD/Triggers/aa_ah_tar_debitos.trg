CREATE OR REPLACE TRIGGER IT."AA_AH_TAR_DEBITOS"
 AFTER DELETE OR UPDATE
 ON AH_TAR_DEBITOS
 FOR EACH ROW


DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_TAR_DEBITOS';
   r_aaudi.clave := :old.nro_cuenta;
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TAR_ACTIVA',:old.tar_activa,:new.tar_activa);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_INGRESO',:old.fec_ingreso,:new.fec_ingreso,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'EMBOZADO',:old.embozado,:new.embozado);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_GRABACION',:old.fec_grabacion,:new.fec_grabacion,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ADHERENTE',:old.adherente,:new.adherente);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_EMISION',:old.nro_emision,:new.nro_emision);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_EST_SOLICITUD',:old.cod_est_solicitud,:new.cod_est_solicitud,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_OFI_ORIGEN',:old.cod_ofi_origen,:new.cod_ofi_origen,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_RECEPCION',:old.fec_recepcion,:new.fec_recepcion,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ENTREGA',:old.fec_entrega,:new.fec_entrega,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_IMPRESION',:old.fec_ult_impresion,:new.fec_ult_impresion,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_CANCELACION',:old.fec_cancelacion,:new.fec_cancelacion,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_PLANILLA',:old.nro_planilla,:new.nro_planilla,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_PLANILLA',:old.tip_planilla,:new.tip_planilla,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MOTIVO',:old.motivo,:new.motivo);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_PLA_ANTERIOR',:old.nro_pla_anterior,:new.nro_pla_anterior,'N');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ENVIO',:old.fec_envio,:new.fec_envio,'F');
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_ENVIO',:old.tip_envio,:new.tip_envio);
   r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'REFERENCIA',:old.referencia,:new.referencia);

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/

