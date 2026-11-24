CREATE OR REPLACE TRIGGER IT."AA_CS_CON_PERSONAS"
  AFTER DELETE OR UPDATE
     ON CS_CON_PERSONAS
    FOR EACH ROW
DECLARE 
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/03/2009 a las 14:04:08 Hs.
  */
  v_registro CS_AUDITORIAS%ROWTYPE; -- Registro de la tabla CS_AUDITORIAS
BEGIN
  v_registro.tabla := 'CS_CON_PERSONAS';
  v_registro.clave := :old.nro_contrato || '#' || :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_RELACION', :old.tip_relacion, :new.tip_relacion );

  -- Insertar tabla de auditoria
  prq_ins_cs_auditoria( v_registro );
EXCEPTION
  when others then
    prq_ins_cs_auditoria( v_registro );
END;
/

