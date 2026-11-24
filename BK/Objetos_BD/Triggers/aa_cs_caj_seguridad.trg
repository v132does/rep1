CREATE OR REPLACE TRIGGER IT."AA_CS_CAJ_SEGURIDAD"
  AFTER DELETE OR UPDATE
     ON CS_CAJ_SEGURIDAD
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/03/2009 a las 13:21:44 Hs.
  */
  v_registro CS_AUDITORIAS%ROWTYPE; -- Registro de la tabla CS_AUDITORIAS
BEGIN
  v_registro.tabla := 'CS_CAJ_SEGURIDAD';
  v_registro.clave := :old.cod_caj_seguridad || '#' || to_char( :old.cod_oficina);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACIONES', :old.observaciones, :new.observaciones );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );

  -- Insertar tabla de auditoria
  prq_ins_cs_auditoria( v_registro );
EXCEPTION
  when others then
    prq_ins_cs_auditoria( v_registro );
END;
/

