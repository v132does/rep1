CREATE OR REPLACE TRIGGER IT.AA_BW_CANJES_DET
  AFTER INSERT OR UPDATE OR DELETE
    ON BW_CANJES_DET
  FOR EACH ROW
DECLARE
  r_uaudi BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  
  r_uaudi.tabla := 'BW_CANJES_DET';
  r_uaudi.clave := to_char( :old.nro_tarjeta || '#' || :old.nro_canje );
  r_uaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  
  IF inserting THEN
    r_uaudi.tip_novedad := 'I';
  ELSIF updating THEN
    r_uaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_uaudi.tip_novedad := 'E';
  END IF;
  
  -- Registrar Detalle
  r_uaudi.detalle := pae_cnf.fu_reg_auditoria( r_uaudi.tip_novedad, 'PUNTOS', :old.puntos, :new.puntos );
  
  -- Insertar registro e tabla de auditoria
  prw_ins_bw_auditoria( r_uaudi );
  
EXCEPTION
  WHEN OTHERS THEN
    prw_ins_bw_auditoria( r_uaudi );
END;
/

