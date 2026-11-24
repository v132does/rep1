CREATE OR REPLACE TRIGGER IT.AA_IN_UNI_MEDIDAS
  AFTER DELETE OR UPDATE
     ON IN_UNI_MEDIDAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 10/08/2007 a las 11:40:29 Hs.
  */
  v_registro IN_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  v_registro.tabla := 'IN_UNI_MEDIDAS';
  v_registro.clave := to_char( :old.cod_uni_medida);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );

  -- Insertar tabla de auditoria
  prz_ins_in_auditoria( v_registro );
EXCEPTION
  when others then
    prz_ins_in_auditoria( v_registro );
END;
/

