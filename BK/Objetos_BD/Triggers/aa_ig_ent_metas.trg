CREATE OR REPLACE TRIGGER IT.AA_IG_ENT_METAS
  AFTER DELETE OR UPDATE
     ON IG_ENT_METAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 07/06/2007 a las 10:53:13 Hs.
  */
  v_registro IG_AUDITORIAS%ROWTYPE; -- Registro de la tabla IG_AUDITORIAS
BEGIN
  v_registro.tabla := 'IG_ENT_METAS';
  v_registro.clave := to_char( :old.cod_concepto) || '#' || to_char( :old.cod_sub_concepto) || '#' || to_char( :old.cod_periodo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'META', :old.meta, :new.meta, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LIQUIDADO', :old.liquidado, :new.liquidado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'LOGRO', :old.logro, :new.logro, 'M' );

  -- Insertar tabla de auditoria
  pri_ins_ig_auditoria( v_registro );
EXCEPTION
  when others then
    pri_ins_ig_auditoria( v_registro );
END;
/

