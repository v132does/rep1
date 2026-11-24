CREATE OR REPLACE TRIGGER IT.aa_bw_otp_seriales
   AFTER DELETE OR UPDATE ON bw_otp_seriales
   FOR EACH ROW
DECLARE
   r_waudi bw_auditorias%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
   r_waudi.tabla          := 'BW_OTP_SERIALES';
   r_waudi.clave          := :old.nro_serial;
   r_waudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   IF updating THEN
      r_waudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_waudi.tip_novedad := 'E';
   END IF;

   -- Registrar Detalle
   r_waudi.detalle := pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'NRO_LOTE', :old.nro_lote,
                                               :new.nro_lote);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'ESTADO', :old.estado,
                                               :new.estado);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina,
                                               :new.cod_oficina, 'N');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'COD_OFI_ORIGEN',
                                               :old.cod_ofi_origen, :new.cod_ofi_origen, 'N');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'COD_CAUSA', :old.cod_causa,
                                               :new.cod_causa, 'N');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'COD_PERSONA', :old.cod_persona,
                                               :new.cod_persona);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'COD_PER_VINCULADA',
                                               :old.cod_per_vinculada, :new.cod_per_vinculada);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'FEC_EST_OTP', :old.fec_est_otp,
                                               :new.fec_est_otp, 'F');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'EXPORTADO', :old.exportado,
                                               :new.exportado);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'CAN_INTENTOS',
                                               :old.can_intentos, :new.can_intentos, 'N');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'USU_ASIGNACION',
                                               :old.usu_asignacion, :new.usu_asignacion);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'FEC_ASIGNACION',
                                               :old.fec_asignacion, :new.fec_asignacion, 'F');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'USU_IMPRESION',
                                               :old.usu_impresion, :new.usu_impresion);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'FEC_IMPRESION',
                                               :old.fec_impresion, :new.fec_impresion, 'F');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'COD_OFI_IMPRESION',
                                               :old.cod_ofi_impresion, :new.cod_ofi_impresion, 'N');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'USU_ENTREGA', :old.usu_entrega,
                                               :new.usu_entrega);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'FEC_ENTREGA', :old.fec_entrega,
                                               :new.fec_entrega, 'F');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'COD_OFI_ENTREGA',
                                               :old.cod_ofi_entrega, :new.cod_ofi_entrega, 'N');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'USU_ACTIVACION',
                                               :old.usu_activacion, :new.usu_activacion);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'FEC_ACTIVACION',
                                               :old.fec_activacion, :new.fec_activacion, 'F');
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'OBSERVACION', :old.observacion,
                                               :new.observacion);
   r_waudi.detalle := r_waudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_waudi.tip_novedad, 'EST_ANTERIOR', :old.est_anterior,
                                               :new.est_anterior);
   -- Insertar tabla de auditoria
   prw_ins_bw_auditoria(r_waudi);
EXCEPTION
   WHEN OTHERS THEN
      prw_ins_bw_auditoria(r_waudi);
END;
/

