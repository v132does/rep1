CREATE OR REPLACE TRIGGER IT.AA_GE_COM_ADHERIDOS
  AFTER DELETE OR UPDATE
     ON it.GE_COM_ADHERIDOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2014 - IT Consultores
  || Generado el 05/08/2014 a las 18:15:58 Hs.
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_COM_ADHERIDOS';
  r_gaudi.clave := to_char( :old.cod_cli_comercio) || '#' || to_char( :old.cod_comercio) || '#' || to_char( :old.cod_suc_comercio);
  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NOM_COMERCIO', :old.nom_comercio, :new.nom_comercio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'POR_REINTEGRO', :old.por_reintegro, :new.por_reintegro );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MON_MAXIMO', :old.mon_maximo, :new.mon_maximo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_FIN', :old.fec_fin, :new.fec_fin );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( r_gaudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( r_gaudi );
END;
/

