CREATE OR REPLACE TRIGGER IT.AA_CB_COM_MANUALES_DET
  AFTER DELETE OR UPDATE
     ON CB_COM_MANUALES_DET
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 27/09/2017 a las 15:15:21 Hs.
  */
  r_baudi CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  r_baudi.tabla := 'CB_COM_MANUALES_DET';
  r_baudi.clave := to_char( :old.nro_comprobante) || '#' || to_char( :old.nro_secuencia);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'VAL_TAS_IMPUESTO', :old.val_tas_impuesto, :new.val_tas_impuesto, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IMPUESTO', :old.impuesto, :new.impuesto, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_GRAVADA', :old.mto_gravada, :new.mto_gravada, 'M' );

  -- Insertar tabla de auditoria
  prb_ins_cb_auditoria( r_baudi );
EXCEPTION
  when others then
    prb_ins_cb_auditoria( r_baudi );
END;
/

