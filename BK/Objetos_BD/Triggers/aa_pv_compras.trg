CREATE OR REPLACE TRIGGER IT.AA_PV_COMPRAS
  AFTER DELETE OR UPDATE
     ON PV_COMPRAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 23/05/2008 a las 09:16:34 Hs.
  */
  v_registro PV_AUDITORIAS%ROWTYPE; -- Registro de la tabla PV_AUDITORIAS
BEGIN
  v_registro.tabla := 'PV_COMPRAS';
  v_registro.clave := to_char( :old.cod_compra);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ENT_PROVEEDOR', :old.cod_ent_proveedor, :new.cod_ent_proveedor, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_PROVEEDOR', :old.nom_proveedor, :new.nom_proveedor );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_COMPROBANTE', :old.tip_comprobante, :new.tip_comprobante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_FACTURA', :old.nro_factura, :new.nro_factura );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIMBRADO', :old.timbrado, :new.timbrado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RUC', :old.ruc, :new.ruc );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_VENTA', :old.tip_venta, :new.tip_venta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IVA_INCLUIDO', :old.iva_incluido, :new.iva_incluido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FOR_PAGO', :old.for_pago, :new.for_pago );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONCEPTO', :old.concepto, :new.concepto );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_PAGADO', :old.ind_pagado, :new.ind_pagado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_COMPRA', :old.tot_compra, :new.tot_compra, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_IMPUESTO', :old.tot_impuesto, :new.tot_impuesto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CAM_ESTADO', :old.fec_cam_estado, :new.fec_cam_estado, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAU_ANULACION', :old.cod_cau_anulacion, :new.cod_cau_anulacion, 'N' );

  -- Insertar tabla de auditoria
  prk_ins_pv_auditoria( v_registro );
EXCEPTION
  when others then
    prk_ins_pv_auditoria( v_registro );
END;
/

