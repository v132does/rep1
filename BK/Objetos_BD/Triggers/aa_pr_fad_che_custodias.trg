CREATE OR REPLACE TRIGGER IT.AA_PR_FAD_CHE_CUSTODIAS
  AFTER DELETE OR UPDATE
     ON PR_FAD_CHE_CUSTODIAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 26/11/2018 a las 17:27:07 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_FAD_CHE_CUSTODIAS';
  r_paudi.clave := to_char( :old.nro_solicitud) || '#' || to_char( :old.nro_cuota) || '#' || to_char( :old.nro_cheque) || '#' || to_char( :old.cod_banco) || '#' || :old.cta_libradora;
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_OFI_CAMARA', :old.cod_ofi_camara, :new.cod_ofi_camara, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_EMISION', :old.fec_emision, :new.fec_emision, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_SERVICIO', :old.tip_servicio, :new.tip_servicio );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_BOLETA', :old.nro_boleta, :new.nro_boleta, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_DEPOSITO', :old.fec_deposito, :new.fec_deposito, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MOT_ENTREGA', :old.mot_entrega, :new.mot_entrega, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_CAU_DEVOLUCION', :old.cod_cau_devolucion, :new.cod_cau_devolucion, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COMPENSADO', :old.compensado, :new.compensado );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

