CREATE OR REPLACE TRIGGER IT.AA_TA_CAL_CIERRES
  AFTER DELETE OR UPDATE
     ON TA_CAL_CIERRES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 23/06/2006 a las 11:34:43 Hs.
  */
  v_registro TA_AUDITORIAS%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  v_registro.tabla := 'TA_CAL_CIERRES';
  v_registro.clave := to_char( :old.cod_ent_procesadora) || '#' || to_char( :old.cod_modulo) || '#' || to_char( :old.cod_modalidad) || '#' || to_char( :old.ano) || '#' || to_char( :old.mes);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CIERRE', :old.fec_cierre, :new.fec_cierre, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TIP_CIERRE', :old.cod_tip_cierre, :new.cod_tip_cierre, 'N' );

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( v_registro );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( v_registro );
END;
/

