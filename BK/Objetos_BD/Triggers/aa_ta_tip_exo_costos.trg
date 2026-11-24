CREATE OR REPLACE TRIGGER IT.AA_TA_TIP_EXO_COSTOS
  AFTER DELETE OR UPDATE
     ON TA_TIP_EXO_COSTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/05/2013 a las 18:30:45 Hs.
  */
  r_taudi TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_TIP_EXO_COSTOS';
  r_taudi.clave := to_char( :old.cod_modalidad);
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'AFINIDAD', :old.afinidad, :new.afinidad );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SUB_AFINIDAD', :old.sub_afinidad, :new.sub_afinidad );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_COSTO', :old.cod_costo, :new.cod_costo, 'N' );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

