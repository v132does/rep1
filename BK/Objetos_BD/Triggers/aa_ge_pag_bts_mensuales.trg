CREATE OR REPLACE TRIGGER IT.AA_GE_PAG_BTS_MENSUALES
  AFTER DELETE OR UPDATE
     ON GE_PAG_BTS_MENSUALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 13/10/2009 a las 13:23:00 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_PAG_BTS_MENSUALES';
  v_registro.clave := to_char( :old.nro_orden) || '#' || to_char( :old.nro_doc_beneficiario);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_ORDEN', :old.nro_orden, :new.nro_orden );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOC_BENEFICIARIO', :old.nro_doc_beneficiario, :new.nro_doc_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ANO', :old.ano, :new.ano );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MES', :old.mes, :new.mes );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_OPERACIONES', :old.can_operaciones, :new.can_operaciones );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MON_OPERACIONES', :old.mon_operaciones, :new.mon_operaciones );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

