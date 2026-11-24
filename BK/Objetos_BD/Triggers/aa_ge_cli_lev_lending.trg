CREATE OR REPLACE TRIGGER IT.AA_GE_CLI_LEV_LENDING
  AFTER DELETE OR UPDATE
     ON GE_CLI_LEV_LENDING
    FOR EACH ROW
DECLARE
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  ----
  r_gaudi.tabla := 'GE_CLI_LEV_LENDING';
  r_gaudi.clave := :old.nro_documento || '#' || :old.cod_persona || '#' || to_char( :old.anho) || '#' || to_char( :old.mes);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'RATIO', :old.ratio, :new.ratio );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

