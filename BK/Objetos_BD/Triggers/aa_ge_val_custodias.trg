CREATE OR REPLACE TRIGGER IT.AA_GE_VAL_CUSTODIAS
 AFTER DELETE OR UPDATE
 ON GE_VAL_CUSTODIAS
 FOR EACH ROW


DECLARE
   r_gaudi ge_auditorias%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla          := 'GE_VAL_CUSTODIAS';
   r_gaudi.clave          := to_char(:old.cod_val_custodia);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   IF updating THEN
      r_gaudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_gaudi.tip_novedad := 'E';
   END IF;

   --- Registrar Detalle
   r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion,
                                               :new.descripcion);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_ENTE', :old.cod_ente,
                                               :new.cod_ente, 'N');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda,
                                               :new.cod_moneda);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'VAL_NOMINAL', :old.val_nominal,
                                               :new.val_nominal, 'N');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'MTO_TOTAL', :old.mto_total,
                                               :new.mto_total, 'N');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'CAN_TOTAL', :old.can_total,
                                               :new.can_total, 'N');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'OBSERVACION', :old.observacion,
                                               :new.observacion);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_INGRESO', :old.fec_ingreso,
                                               :new.fec_ingreso, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_PAG_ANTERIOR',
                                               :old.fec_pag_anterior, :new.fec_pag_anterior, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_ULT_PAGO',
                                               :old.fec_ult_pago, :new.fec_ult_pago, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_VENCIMIENTO',
                                               :old.fec_vencimiento, :new.fec_vencimiento, 'F');
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'NRO_CTA_DEBITO',
                                               :old.nro_cta_debito, :new.nro_cta_debito);
   r_gaudi.detalle := r_gaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'ESTADO', :old.estado,
                                               :new.estado);

   --- Insertar tabla de auditoria
   prg_ins_ge_auditoria(r_gaudi);
END;
/

