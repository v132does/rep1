CREATE OR REPLACE TRIGGER IT.AA_CV_VAL_CUS_MOVIMIENTOS
  AFTER DELETE OR UPDATE
     ON "IT"."CV_VAL_CUS_MOVIMIENTOS"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 14/03/2016 a las 16:58:11 Hs.
  */
  v_registro CV_AUDITORIAS%ROWTYPE; -- Registro de la tabla CV_AUDITORIAS
BEGIN
  v_registro.tabla := 'CV_VAL_CUS_MOVIMIENTOS';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.hora || '#' || :old.cod_usuario || '#' || to_char( :old.nro_secuencia);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_VAL_CUSTODIA', :old.cod_val_custodia, :new.cod_val_custodia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_CUSTODIA', :old.est_custodia, :new.est_custodia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BANCO', :old.cod_banco, :new.cod_banco, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_DESTINO', :old.cod_ofi_destino, :new.cod_ofi_destino, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_DESTINO', :old.cod_usu_destino, :new.cod_usu_destino );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'UBICACION', :old.ubicacion, :new.ubicacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REVERSADO', :old.reversado, :new.reversado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USU_REVERSION', :old.cod_usu_reversion, :new.cod_usu_reversion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HOR_REVERSION', :old.hor_reversion, :new.hor_reversion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );

  -- Insertar tabla de auditoria
  prv_ins_cv_auditoria( v_registro );
EXCEPTION
  when others then
    prv_ins_cv_auditoria( v_registro );
END;
/

