CREATE OR REPLACE TRIGGER IT.AA_TA_TAR_NOMINADAS
  AFTER DELETE OR UPDATE
     ON TA_TAR_NOMINADAS
    FOR EACH ROW
DECLARE
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_TAR_NOMINADAS';
  r_taudi.clave := to_char( :old.nro_cuenta) || '#' || to_char( :old.nro_tarjeta);
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( 5 );

  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_TIP_DOCUMENTO', :old.cod_tip_documento, :new.cod_tip_documento );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ENV_CUENTA', :old.env_cuenta, :new.env_cuenta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ENV_TARJETA', :old.env_tarjeta, :new.env_tarjeta );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ENV_ACTIVACION', :old.env_activacion, :new.env_activacion );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

