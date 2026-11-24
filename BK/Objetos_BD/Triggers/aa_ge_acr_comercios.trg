CREATE OR REPLACE TRIGGER IT.AA_GE_ACR_COMERCIOS
  AFTER DELETE OR UPDATE
     ON GE_ACR_COMERCIOS
    FOR EACH ROW
DECLARE
   r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla          := 'GE_ACR_COMERCIOS';
   r_gaudi.clave          := to_char(:old.nro_referencia);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   IF updating THEN
      r_gaudi.tip_novedad := 'M';
   ELSIF deleting THEN
      r_gaudi.tip_novedad := 'E';
   END IF;

   -- Registrar Detalle
   r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'COD_ENTE', :old.cod_ente, :new.cod_ente, 'N');
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'NRO_BOLETA', :old.nro_boleta, :new.nro_boleta, 'N');
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_MOVIMIENTO', :old.fec_movimiento, :new.fec_movimiento, 'F');
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'HOR_MOVIMIENTO', :old.hor_movimiento, :new.hor_movimiento);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'FEC_TRANSACCION', :old.fec_transaccion, :new.fec_transaccion);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'HOR_TRANSACCION', :old.hor_transaccion, :new.hor_transaccion);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'TIP_TRANSACCION', :old.tip_transaccion, :new.tip_transaccion);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'TIP_OPERACION', :old.tip_operacion, :new.tip_operacion);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'CTA_DEBITO', :old.cta_debito, :new.cta_debito);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'BCO_DEBITO', :old.bco_debito, :new.bco_debito, 'N');
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'CTA_CREDITO', :old.cta_credito, :new.cta_credito);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'BCO_CREDITO', :old.bco_debito, :new.bco_debito, 'N');
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M');
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'MONEDA', :old.moneda, :new.moneda);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'BENEFICIARIO', :old.beneficiario, :new.beneficiario);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'TIP_TARJETA', :old.tip_tarjeta, :new.Tip_Tarjeta);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'NRO_LOTE', :old.nro_lote, :new.nro_lote);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'PROCESADO', :old.procesado, :new.procesado);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'EXTORNADO', :old.extornado, :new.extornado);
   r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad, 'NRO_BOL_EXTORNO', :old.nro_bol_extorno, :new.nro_bol_extorno, 'N');

   -- Insertar tabla de auditoria
   prg_ins_ge_auditoria(r_gaudi);
   
EXCEPTION
   WHEN OTHERS THEN
      prg_ins_ge_auditoria(r_gaudi);
END;
/

