CREATE OR REPLACE TRIGGER IT.AA_SB_SNP_CAMPOS
  AFTER DELETE OR UPDATE
     ON IT.SB_SNP_CAMPOS
    FOR EACH ROW
DECLARE
  rg_gaudi SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  rg_gaudi.tabla := 'SB_SNP_CAMPOS';
  rg_gaudi.clave := :old.campo || :old.cod_mensaje || to_char( :old.orden );
  rg_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_gaudi.detalle := pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion);
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'IND_REQUERIDO', :old.ind_requerido, :new.ind_requerido );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'IND_DETALLE', :old.ind_detalle, :new.ind_detalle );  
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'FORMATO', :old.formato, :new.formato );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'CAN_MAX_LINEAS', :old.can_max_lineas, :new.can_max_lineas );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DET_SQL_RECIBIDO', :old.det_sql_recibido, :new.det_sql_recibido );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DET_SQL_ENVIADO', :old.det_sql_enviado, :new.det_sql_enviado );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DET_SQL_VAL_DEFECTO', :old.det_sql_val_defecto, :new.det_sql_val_defecto );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DET_SQL_CAMPO', :old.det_sql_campo, :new.det_sql_campo );

  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( rg_gaudi );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( rg_gaudi );
END;
/

