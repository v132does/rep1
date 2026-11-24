CREATE OR REPLACE TRIGGER IT.AA_PR_GAR_VEHICULOS
  AFTER DELETE OR UPDATE
     ON PR_GAR_VEHICULOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 23/05/2013 a las 11:45:43 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_GAR_VEHICULOS';
  r_paudi.clave := to_char( :old.nro_garantia) || '#' || to_char( :old.nro_contrato);
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_MARCA', :old.cod_marca, :new.cod_marca, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MODELO', :old.modelo, :new.modelo );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'ANO', :old.ano, :new.ano, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_MOTOR', :old.nro_motor, :new.nro_motor );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_CHASIS', :old.nro_chasis, :new.nro_chasis );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_CHAPA', :old.nro_chapa, :new.nro_chapa );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_CEDULA', :old.nro_cedula, :new.nro_cedula );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_INSCRIPCION', :old.fec_inscripcion, :new.fec_inscripcion, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_ENT_SEGURO', :old.cod_ent_seguro, :new.cod_ent_seguro, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_POLIZA', :old.nro_poliza, :new.nro_poliza );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_VTO_SEGURO', :old.fec_vto_seguro, :new.fec_vto_seguro, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_PRENDA', :old.tip_prenda, :new.tip_prenda );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_ENT_TASADOR', :old.cod_ent_tasador, :new.cod_ent_tasador, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'VAL_TASACION', :old.val_tasacion, :new.val_tasacion, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MOVIL', :old.movil, :new.movil );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'VAL_SEGURO', :old.val_seguro, :new.val_seguro, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'VAL_VTA_RAPIDA', :old.val_vta_rapida, :new.val_vta_rapida, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_FIR_ESCRITURA', :old.fec_fir_escritura, :new.fec_fir_escritura, 'F' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_INSCRIPCION', :old.nro_inscripcion, :new.nro_inscripcion );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'NRO_FOLIO', :old.nro_folio, :new.nro_folio, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FEC_INI_SEGURO', :old.fec_ini_seguro, :new.fec_ini_seguro, 'F' );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

