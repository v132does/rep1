CREATE OR REPLACE TRIGGER IT.AA_GE_CLIENTES_NOV
  AFTER DELETE OR UPDATE
     ON GE_CLIENTES_NOV
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 12/09/2013 a las 10:09:34 Hs.
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_CLIENTES_NOV';
  r_gaudi.clave := :old.cod_persona || '#' || to_char( :old.fec_cam_clasificacion, 'DD/MM/YYYY HH24:MI:SS');
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_CAM_CLASIFICACION', :old.fec_cam_clasificacion, :new.fec_cam_clasificacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'CAT_RIE_ANTERIOR', :old.cat_rie_anterior, :new.cat_rie_anterior );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'CAT_RIE_ACTUAL', :old.cat_rie_actual, :new.cat_rie_actual );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

