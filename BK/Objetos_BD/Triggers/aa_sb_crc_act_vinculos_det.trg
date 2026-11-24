CREATE OR REPLACE TRIGGER IT.AA_SB_CRC_ACT_VINCULOS_DET
  AFTER DELETE OR UPDATE
     ON SB_CRC_ACT_VINCULOS_DET
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2015 - IT Consultores
  || Generado el 10/11/2015 a las 15:10:51 Hs.
  */
  r_saudi SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
BEGIN
  r_saudi.tabla := 'SB_CRC_ACT_VINCULOS_DET';
  r_saudi.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.nom_referencia || '#' || to_char( :old.nro_operacion);
  r_saudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_saudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_saudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_saudi.detalle := pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_FORMULARIO', :old.nro_formulario, :new.nro_formulario );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'TIP_OPERACION', :old.tip_operacion, :new.tip_operacion, 'N' );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_OPERACION', :old.nro_operacion, :new.nro_operacion );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_MON_ISO', :old.cod_mon_iso, :new.cod_mon_iso );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'TIP_DOCUMENTO', :old.tip_documento, :new.tip_documento );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'EVENTO', :old.evento, :new.evento );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_saudi.detalle := r_saudi.detalle || pae_cnf.fu_reg_auditoria( r_saudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );

  -- Insertar tabla de auditoria
  prs_ins_sb_auditoria( r_saudi );
EXCEPTION
  when others then
    prs_ins_sb_auditoria( r_saudi );
END;
/

