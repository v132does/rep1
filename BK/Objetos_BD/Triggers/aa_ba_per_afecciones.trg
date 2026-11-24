CREATE OR REPLACE TRIGGER IT.AA_BA_PER_AFECCIONES
 AFTER DELETE OR UPDATE
 ON BA_PER_AFECCIONES
 FOR EACH ROW
DECLARE

  /*
  || Archivo creado por el Generador de Triggers de Auditoria
  || (c) 2005 - IT Consultores
  || Generado el 13/03/2007 a las 14:31:48 Hs.
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_PER_AFECCIONES';
  v_registro.clave := :old.cod_persona || '#' || to_char( :old.cod_afeccion);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_AFECCION', :old.cod_afeccion, :new.cod_afeccion, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );

  -- Insertar tabla de auditoria
  pra_ins_ah_auditoria( v_registro );
EXCEPTION
  when others then
    pra_ins_ah_auditoria( v_registro );
END;
/

