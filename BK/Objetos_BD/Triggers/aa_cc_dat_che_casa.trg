CREATE OR REPLACE TRIGGER IT.AA_CC_DAT_CHE_CASA
  AFTER DELETE OR UPDATE
     ON CC_DAT_CHE_CASA
    FOR EACH ROW
DECLARE
  r_caudi AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  r_caudi.tabla := 'CC_DAT_CHE_CASA';
  r_caudi.clave := :old.cod_per_principal || '#' || to_char( :old.cod_tip_documento) || '#' || :old.nro_documento;
  r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_caudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_caudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_caudi.detalle := pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'COD_PER_AUTORIZADA', :old.cod_per_autorizada, :new.cod_per_autorizada );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'NOM_COMPLETO', :old.nom_completo, :new.nom_completo );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'TIP_LINEA', :old.tip_linea, :new.tip_linea );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'NRO_TELEFONO', :old.nro_telefono, :new.nro_telefono );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'INTERNO', :old.interno, :new.interno );
  r_caudi.detalle := r_caudi.detalle || pae_cnf.fu_reg_auditoria( r_caudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );

  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( r_caudi );
EXCEPTION
  when others then
    prf_ins_af_auditoria( r_caudi );
END;
/

