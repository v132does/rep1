CREATE OR REPLACE TRIGGER IT.AA_SB_SNP_FORMATOS
  AFTER DELETE OR UPDATE
     ON IT.SB_SNP_FORMATOS
    FOR EACH ROW
DECLARE
  rg_gaudi SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  rg_gaudi.tabla := 'SB_SNP_FORMATOS';
  rg_gaudi.clave := :old.formato;
  rg_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_gaudi.detalle := pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  rg_gaudi.detalle := rg_gaudi.detalle || pae_cnf.fu_reg_auditoria( rg_gaudi.tip_novedad, 'EXP_REGULAR', :old.exp_regular, :new.exp_regular );

  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( rg_gaudi );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( rg_gaudi );
END;
/

