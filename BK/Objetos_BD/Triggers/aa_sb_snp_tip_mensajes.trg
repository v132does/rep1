CREATE OR REPLACE TRIGGER IT.AA_SB_SNP_TIP_MENSAJES
  AFTER DELETE OR UPDATE
     ON IT.SB_SNP_TIP_MENSAJES
    FOR EACH ROW
DECLARE
  rg_gaudi SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  rg_gaudi.tabla := 'SB_SNP_TIP_MENSAJES';
  rg_gaudi.clave := :old.cod_mensaje;
  rg_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_gaudi.detalle := pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'TIP_MSJ_CAMPO', :old.tip_msj_campo, :new.tip_msj_campo );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'OBJ_PROCESO', :old.obj_proceso, :new.obj_proceso );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( rg_gaudi );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( rg_gaudi );
END;
/

