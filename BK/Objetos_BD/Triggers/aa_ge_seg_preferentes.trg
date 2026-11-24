CREATE OR REPLACE TRIGGER IT.AA_GE_SEG_PREFERENTES
  AFTER DELETE OR UPDATE
     ON GE_SEG_PREFERENTES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 27/05/2011 a las 17:02:36 Hs.
  */
  r_baudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_baudi.tabla := 'GE_SEG_PREFERENTES';
  r_baudi.clave := to_char( :old.cod_seg_preferente);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'RGB', :old.rgb, :new.rgb );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'FIN_NOM_ARCHIVO', :old.fin_nom_archivo, :new.fin_nom_archivo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'NOM_CAM_COLOR', :old.nom_cam_color, :new.nom_cam_color );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_baudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_baudi );
END;
/

