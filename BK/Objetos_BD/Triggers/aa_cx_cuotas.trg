CREATE OR REPLACE TRIGGER IT.aa_cx_cuotas
   AFTER DELETE OR UPDATE ON cx_cuotas
   REFERENCING OLD AS OLD NEW AS NEW
   FOR EACH ROW
DECLARE

   r_xaudi cx_auditorias%ROWTYPE; -- Registro de la tabla CX_AUDITORIAS
BEGIN
   r_xaudi.tabla          := 'CX_CUOTAS';
   r_xaudi.clave          := :old.nro_cuenta || '#' || to_char(:old.nro_cuota);
   r_xaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   IF updating THEN
      r_xaudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_xaudi.tip_novedad := 'E';
   
   END IF;

   --- Registrar Detalle
   r_xaudi.detalle := pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'MONTO', :old.monto, :new.monto,
                                               'M');
   r_xaudi.detalle := r_xaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'FEC_VENCIMIENTO',
                                               :old.fec_vencimiento, :new.fec_vencimiento, 'F');
   r_xaudi.detalle := r_xaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'ESTADO', :old.estado,
                                               :new.estado);
   r_xaudi.detalle := r_xaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'SALDO', :old.saldo, :new.saldo,
                                               'M');

   r_xaudi.detalle := r_xaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'NRO_SOL_PRESTAMO',
                                               :old.nro_sol_prestamo, :new.nro_sol_prestamo, 'N');
   r_xaudi.detalle := r_xaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'NRO_CTA_PRESTAMO',
                                               :old.nro_cta_prestamo, :new.nro_cta_prestamo);
   r_xaudi.detalle := r_xaudi.detalle ||
                      pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'NRO_EMBARQUE',
                                               :old.nro_embarque, :new.nro_embarque, 'N');

   IF deleting OR (updating AND :old.observacion <> :new.observacion) THEN
      r_xaudi.detalle := r_xaudi.detalle ||
                         pae_cnf.fu_reg_auditoria(r_xaudi.tip_novedad, 'OBSERVACION',
                                                  :old.observacion, :new.observacion);
   END IF;

   --- Insertar tabla de auditoria
   prx_ins_cx_auditoria(r_xaudi);
END;
/

