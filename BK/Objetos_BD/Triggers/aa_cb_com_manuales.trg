CREATE OR REPLACE TRIGGER IT.AA_CB_COM_MANUALES
  AFTER DELETE OR UPDATE
     ON CB_COM_MANUALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 27/09/2017 a las 15:13:23 Hs.
  */
  r_baudi CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  r_baudi.tabla := 'CB_COM_MANUALES';
  r_baudi.clave := to_char( :old.nro_comprobante);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NRO_FACTURA', :old.nro_factura, :new.nro_factura );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NRO_TIMBRADO', :old.nro_timbrado, :new.nro_timbrado );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_VIG_TIMBRADO', :old.fec_vig_timbrado, :new.fec_vig_timbrado, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'TIP_COMPROBANTE', :old.tip_comprobante, :new.tip_comprobante );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'TIP_VENTA', :old.tip_venta, :new.tip_venta );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NOM_COMPLETO', :old.nom_completo, :new.nom_completo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIRECCION', :old.direccion, :new.direccion );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DIR_TRANSACCION', :old.dir_transaccion, :new.dir_transaccion );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NRO_FAC_REFERENCIA', :old.nro_fac_referencia, :new.nro_fac_referencia );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_EXENTO', :old.mto_exento, :new.mto_exento, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_GRAVADO_5', :old.mto_gravado_5, :new.mto_gravado_5, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MTO_GRAVADO_10', :old.mto_gravado_10, :new.mto_gravado_10, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IMPUESTO_5', :old.impuesto_5, :new.impuesto_5, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IMPUESTO_10', :old.impuesto_10, :new.impuesto_10, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'COTIZACION', :old.cotizacion, :new.cotizacion, 'M' );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IMPRESO', :old.impreso, :new.impreso );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'PROCESADO', :old.procesado, :new.procesado );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'ANULADO', :old.anulado, :new.anulado );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FEC_AUT_TIMBRADO', :old.fec_aut_timbrado, :new.fec_aut_timbrado, 'F' );

  -- Insertar tabla de auditoria
  prb_ins_cb_auditoria( r_baudi );
EXCEPTION
  when others then
    prb_ins_cb_auditoria( r_baudi );
END;
/

