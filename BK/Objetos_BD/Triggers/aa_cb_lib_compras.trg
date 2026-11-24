CREATE OR REPLACE TRIGGER IT."AA_CB_LIB_COMPRAS"
  AFTER DELETE OR UPDATE
     ON CB_LIB_COMPRAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Lic. Julio Cesar Leguizamon G.
  || (c) 2008
  || Generado el 08/09/2008 a las 18:44:30 Hs.
  */
  v_registro CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  v_registro.tabla := 'CB_LIB_COMPRAS';
  v_registro.clave := :old.nro_factura || '#' || :old.cod_persona || '#' || :old.nro_documento;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_EXENTO', :old.mto_exento, :new.mto_exento, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_GRAVADO_10', :old.mto_gravado_10, :new.mto_gravado_10, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMPUESTO_10', :old.impuesto_10, :new.impuesto_10, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_GRAVADO_5', :old.mto_gravado_5, :new.mto_gravado_5, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMPUESTO_5', :old.impuesto_5, :new.impuesto_5, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RAZ_SOCIAL', :old.raz_social, :new.raz_social );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_ORIGEN', :old.cod_ofi_origen, :new.cod_ofi_origen, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ENT_PROVEEDOR', :old.cod_ent_proveedor, :new.cod_ent_proveedor, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PROCESADO', :old.procesado, :new.procesado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_TIMBRADO', :old.nro_timbrado, :new.nro_timbrado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PAGO', :old.fec_pago, :new.fec_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_CUOTA', :old.can_cuota, :new.can_cuota );

  -- Insertar tabla de auditoria
  prb_ins_cb_auditoria( v_registro );
EXCEPTION
  when others then
    prb_ins_cb_auditoria( v_registro );
END;
/

