CREATE OR REPLACE TRIGGER IT.AA_CV_VAL_CUSTODIAS
  AFTER DELETE OR UPDATE
     ON "IT"."CV_VAL_CUSTODIAS"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 14/03/2016 a las 14:03:31 Hs.
  */
  v_registro CV_AUDITORIAS%ROWTYPE; -- Registro de la tabla CV_AUDITORIAS
BEGIN
  v_registro.tabla := 'CV_VAL_CUSTODIAS';
  v_registro.clave := to_char( :old.cod_val_custodia);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_VALOR', :old.tip_valor, :new.tip_valor );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INGRESO', :old.fec_ingreso, :new.fec_ingreso, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_PERSONA', :old.nom_persona, :new.nom_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_OPERACION', :old.nro_operacion, :new.nro_operacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUOTA', :old.nro_cuota, :new.nro_cuota, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CAM_ESTADO', :old.fec_cam_estado, :new.fec_cam_estado, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BANCO', :old.cod_banco, :new.cod_banco, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_VALOR', :old.nro_valor, :new.nro_valor);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CTA_LIBRADORA', :old.cta_libradora, :new.cta_libradora );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_ORIGEN', :old.cod_ofi_origen, :new.cod_ofi_origen, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_ORIGEN', :old.cod_usu_origen, :new.cod_usu_origen );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'UBICACION', :old.ubicacion, :new.ubicacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_ETIQUETA', :old.est_etiqueta, :new.est_etiqueta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_EST_ETIQUETA', :old.fec_est_etiqueta, :new.fec_est_etiqueta, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LIBRADOR', :old.librador, :new.librador );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_AREA', :old.cod_area, :new.cod_area, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SECTOR', :old.cod_sector, :new.cod_sector, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_NIVEL', :old.cod_nivel, :new.cod_nivel, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_HILERA', :old.cod_hilera, :new.cod_hilera, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SECCION', :old.cod_seccion, :new.cod_seccion, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ORDEN', :old.cod_orden, :new.cod_orden, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_SALIDA', :old.fec_salida, :new.fec_salida, 'F' );
  -- Insertar tabla de auditoria
  prv_ins_cv_auditoria( v_registro );
EXCEPTION
  when others then
    prv_ins_cv_auditoria( v_registro );
END;
/

