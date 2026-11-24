CREATE OR REPLACE TRIGGER IT.AA_SB_SNP_MENSAJES
  AFTER DELETE OR UPDATE
     ON IT.SB_SNP_MENSAJES
    FOR EACH ROW
DECLARE
  rg_gaudi SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  rg_gaudi.tabla := 'SB_SNP_MENSAJES';
  rg_gaudi.clave := :old.cod_mensaje;
  rg_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_gaudi.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  rg_gaudi.detalle := pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'NRO_REFERENCIA ', :old.nro_referencia, :new.nro_referencia );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'NRO_LOTE', :old.nro_lote, :new.nro_lote );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'ORDEN', :old.orden, :new.orden );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'NRO_LINEA', :old.nro_linea, :new.nro_linea );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'CAMPO', :old.campo, :new.campo );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'VALOR', :old.valor, :new.valor );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'IND_REQUERIDO', :old.ind_requerido, :new.ind_requerido );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'NRO_DETALLE', :old.nro_detalle, :new.nro_detalle );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'ERR_FORMATO', :old.err_formato, :new.err_formato ); 
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'ERR_VALIDACION', :old.err_validacion, :new.err_validacion );
  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( rg_gaudi );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( rg_gaudi );
END;
/

