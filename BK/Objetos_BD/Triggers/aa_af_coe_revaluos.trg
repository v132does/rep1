CREATE OR REPLACE TRIGGER IT.AA_AF_COE_REVALUOS
  AFTER DELETE OR UPDATE
     ON AF_COE_REVALUOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 10/08/2007 a las 11:40:17 Hs.
  */
  v_registro AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  v_registro.tabla := 'AF_COE_REVALUOS';
  v_registro.clave := to_char( :old.fec_proceso, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.tipo;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COEFICIENTE', :old.coeficiente, :new.coeficiente, 'M' );
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COE_HACIENDA', :old.coe_hacienda, :new.coe_hacienda, 'M' );
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COE_FIN_DEPRECIACION', :old.coe_fin_depreciacion, :new.coe_fin_depreciacion, 'M' );
  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( v_registro );
EXCEPTION
  when others then
    prf_ins_af_auditoria( v_registro );
END;
/

