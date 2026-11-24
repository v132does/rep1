CREATE OR REPLACE TRIGGER IT.AA_GE_PAG_PRO_HUB_GLOBAL
  AFTER DELETE OR UPDATE
     ON GE_PAG_PRO_HUB_GLOBAL
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/04/2018 a las 11:24:31 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_PAG_PRO_HUB_GLOBAL';
  v_registro.clave := to_char( :old.cod_ente) || '#' || to_char( :old.nro_archivo) || '#' || :old.hub_nom_agrupado || '#' || to_char( :old.nro_orden);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_FACTURA', :old.nro_factura, :new.nro_factura );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_COMPROBANTE', :old.tip_comprobante, :new.tip_comprobante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FOR_PAGO', :old.for_pago, :new.for_pago );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CHEQUE', :old.nro_cheque, :new.nro_cheque, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_CREDITO', :old.nro_cta_credito, :new.nro_cta_credito );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INGRESO', :old.fec_ingreso, :new.fec_ingreso, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PAGO', :old.fec_pago, :new.fec_pago, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_RECIBO', :old.nro_recibo, :new.nro_recibo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BENEFICIARIO', :old.beneficiario, :new.beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONCEPTO', :old.concepto, :new.concepto );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_OPERADOR', :old.cod_usu_operador, :new.cod_usu_operador );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PROCESO', :old.cod_proceso, :new.cod_proceso, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_CARGA', :old.tip_carga, :new.tip_carga );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MON_RECIBIDO', :old.cod_mon_recibido, :new.cod_mon_recibido );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REF_FACTURAS', :old.ref_facturas, :new.ref_facturas );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MON_TOT_RECIBO', :old.mon_tot_recibo, :new.mon_tot_recibo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RET_FAC_PROVEEDOR', :old.ret_fac_proveedor, :new.ret_fac_proveedor, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DES_FAC_PROVEEDOR', :old.des_fac_proveedor, :new.des_fac_proveedor, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'RET_FACTURAS', :old.ret_facturas, :new.ret_facturas, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DES_SUCURSAL', :old.des_sucursal, :new.des_sucursal );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_SECUENCIA', :old.nro_secuencia, :new.nro_secuencia, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TIP_DOC_BENEFICIARIO', :old.cod_tip_doc_beneficiario, :new.cod_tip_doc_beneficiario, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOC_BENEFICIARIO', :old.nro_doc_beneficiario, :new.nro_doc_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_BENEFICIARIO', :old.nro_cta_beneficiario, :new.nro_cta_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ENT_BCA_BENEFICIARIO', :old.ent_bca_beneficiario, :new.ent_bca_beneficiario, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IND_VALOR', :old.ind_valor, :new.ind_valor );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIR_BENEFICIARIO', :old.dir_beneficiario, :new.dir_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_FACTURA', :old.tip_factura, :new.tip_factura );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CON_CAMBIO', :old.nro_con_cambio, :new.nro_con_cambio, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BEN_DIR_CORREO', :old.ben_dir_correo, :new.ben_dir_correo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_ORD_ARCHIVO', :old.nro_ord_archivo, :new.nro_ord_archivo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ONE_BANK', :old.cod_one_bank, :new.cod_one_bank );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_ACREDITAMIENTO', :old.tip_acreditamiento, :new.tip_acreditamiento );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_TRANSFERENCIA', :old.tip_transferencia, :new.tip_transferencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RESPUESTA', :old.cod_respuesta, :new.cod_respuesta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MSJ_RESPUESTA', :old.msj_respuesta, :new.msj_respuesta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DES_RESPUESTA', :old.des_respuesta, :new.des_respuesta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HUB_AGRUPADO', :old.hub_agrupado, :new.hub_agrupado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HUB_NOM_FICHERO', :old.hub_nom_fichero, :new.hub_nom_fichero );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HUB_ISO_ERR_CODIGO', :old.hub_iso_err_codigo, :new.hub_iso_err_codigo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HUB_ISO_ERR_MENSAJE', :old.hub_iso_err_mensaje, :new.hub_iso_err_mensaje );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

