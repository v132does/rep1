CREATE OR REPLACE TRIGGER IT.AA_BA_CLI_OCASIONALES
  AFTER DELETE OR UPDATE
     ON BA_CLI_OCASIONALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2014 - IT Consultores
  || Generado el 03/12/2014 a las 15:51:20 Hs.
  */
  r_eaudi BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  r_eaudi.tabla := 'BA_CLI_OCASIONALES';
  r_eaudi.clave := to_char( :old.cod_tip_documento) || '#' || :old.nro_documento;
  r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_eaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_eaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_eaudi.detalle := pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'PRI_NOMBRE', :old.pri_nombre, :new.pri_nombre );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'SEG_NOMBRE', :old.seg_nombre, :new.seg_nombre );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'PRI_APELLIDO', :old.pri_apellido, :new.pri_apellido );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'SEG_APELLIDO', :old.seg_apellido, :new.seg_apellido );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'COD_PAI_NACIONALIDAD', :old.cod_pai_nacionalidad, :new.cod_pai_nacionalidad, 'N' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'COP_DOCUMENTO', :old.cop_documento, :new.cop_documento );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_NACIMIENTO', :old.fec_nacimiento, :new.fec_nacimiento, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'OCUPACION', :old.ocupacion, :new.ocupacion );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'DOMICILIO', :old.domicilio, :new.domicilio );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'EST_INFORMACION', :old.est_informacion, :new.est_informacion );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_GENERACION', :old.fec_generacion, :new.fec_generacion, 'F' );
  r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria( r_eaudi.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso, 'F' );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( r_eaudi );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( r_eaudi );
END;
/

