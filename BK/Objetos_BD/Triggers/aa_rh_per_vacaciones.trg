CREATE OR REPLACE TRIGGER IT.AA_RH_PER_VACACIONES
 AFTER DELETE OR UPDATE
 ON RH_PER_VACACIONES
 FOR EACH ROW
DECLARE

  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 20/04/2007 a las 09:20:19 Hs.
  */
  v_registro RH_AUDITORIAS%ROWTYPE; -- Registro de la tabla RH_AUDITORIAS
BEGIN
  v_registro.tabla := 'RH_PER_VACACIONES';
  v_registro.clave := to_char( :old.ano_desde) || '#' || to_char( :old.ano_hasta);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIAS_VACACIONES', :old.dias_vacaciones, :new.dias_vacaciones, 'N' );

  -- Insertar tabla de auditoria
  prh_ins_rh_auditoria( v_registro );
EXCEPTION
  when others then
    prh_ins_rh_auditoria( v_registro );
END;
/

