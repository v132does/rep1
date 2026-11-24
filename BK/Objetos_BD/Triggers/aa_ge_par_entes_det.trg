CREATE OR REPLACE TRIGGER IT.AA_GE_PAR_ENTES_DET
  AFTER DELETE OR UPDATE
     ON GE_PAR_ENTES_DET
    FOR EACH ROW
DECLARE
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_PAR_ENTES_DET';
  r_gaudi.clave := to_char( :old.cod_ente)||'#'||:old.parametro||'#'||:old.val_parametro;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'REF_ADICIONAL', :old.ref_adicional, :new.ref_adicional );
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

