CREATE OR REPLACE TRIGGER IT.AA_BW_LOT_TRA_CONTACTOS
  AFTER DELETE OR UPDATE
     ON BW_LOT_TRA_CONTACTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/11/2018 a las 15:25:16 Hs.
  */
  r_gaudi AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'BW_LOT_TRA_CONTACTOS';
  r_gaudi.clave := :old.cod_persona || '#' || :old.cta_contacto;
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NOM_CONTACTO', :old.nom_contacto, :new.nom_contacto );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_CONTACTO', :old.nro_contacto, :new.nro_contacto );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ORI_CONTACTO', :old.ori_contacto, :new.ori_contacto );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'BAN_CONTACTO', :old.ban_contacto, :new.ban_contacto );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_SWIFT', :old.cod_swift, :new.cod_swift );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_DOCUMENTO', :old.tip_documento, :new.tip_documento );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_ESTADO', :old.cod_estado, :new.cod_estado );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_CUENTA', :old.tip_cuenta, :new.tip_cuenta );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MAIL', :old.mail, :new.mail );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA_CONTACTO', :old.mail, :new.mail );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion, 'F' );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion, 'F' );

  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( r_gaudi );
EXCEPTION
  when others then
    prf_ins_af_auditoria( r_gaudi );
END;
/

