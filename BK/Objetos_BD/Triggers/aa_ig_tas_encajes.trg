CREATE OR REPLACE TRIGGER IT.AA_IG_TAS_ENCAJES
  AFTER DELETE OR UPDATE
     ON IG_TAS_ENCAJES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 25/06/2007 a las 17:41:19 Hs.
  */
  v_registro IG_AUDITORIAS%ROWTYPE; -- Registro de la tabla IG_AUDITORIAS
BEGIN
  v_registro.tabla := 'IG_TAS_ENCAJES';
  v_registro.clave := to_char( :old.cod_modulo) || '#' || to_char( :old.cod_modalidad) || '#' || :old.cod_moneda || '#' || to_char( :old.plz_desde) || '#' || to_char( :old.plz_hasta);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TASA', :old.tasa, :new.tasa, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion, 'F' );

  -- Insertar tabla de auditoria
  pri_ins_ig_auditoria( v_registro );
EXCEPTION
  when others then
    pri_ins_ig_auditoria( v_registro );
END;
/

