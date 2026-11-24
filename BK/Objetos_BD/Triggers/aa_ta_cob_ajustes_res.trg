CREATE OR REPLACE TRIGGER IT.AA_TA_COB_AJUSTES_RES
  AFTER DELETE OR UPDATE
     ON IT.TA_COB_AJUSTES_RES
    FOR EACH ROW
DECLARE
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_COB_AJUSTES_RES';
  r_taudi.clave := to_char(:old.nro_cob_dia);
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'nro_cob_dia', :old.nro_cob_dia, :new.nro_cob_dia);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_REGISTRO', :old.tip_registro, :new.tip_registro);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENT_EMISORA', :old.cod_ent_emisora, :new.cod_ent_emisora);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_IDE_ARCHIVO', :old.cod_ide_archivo, :new.cod_ide_archivo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CAN_REGISTROS', :old.can_registros, :new.can_registros);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER', :old.filler, :new.filler);

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

