CREATE OR REPLACE TRIGGER IT.AA_GE_CAM_PRODUCTOS
  AFTER DELETE OR UPDATE
     ON GE_CAM_PRODUCTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 20/09/2012 a las 09:47:46 Hs.
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_CAM_PRODUCTOS';
  r_gaudi.clave := to_char( :old.cod_modulo) || '#' || to_char( :old.cod_modalidad) || '#' || :old.nom_tabla || '#' || :old.nom_campo || '#' || to_char( :old.nro_orden);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ETIQUETA', :old.etiqueta, :new.etiqueta );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ORIGEN', :old.origen, :new.origen );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NOM_TAB_ORIGEN', :old.nom_tab_origen, :new.nom_tab_origen );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NOM_CAM_ORIGEN', :old.nom_cam_origen, :new.nom_cam_origen );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'DOMINIO', :old.dominio, :new.dominio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PROGRAMA', :old.cod_programa, :new.cod_programa );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PAR_AMPLIADO', :old.par_ampliado, :new.par_ampliado );
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

