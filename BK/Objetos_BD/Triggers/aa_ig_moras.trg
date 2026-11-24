CREATE OR REPLACE TRIGGER IT.AA_IG_MORAS
  AFTER DELETE OR UPDATE
     ON IG_MORAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 07/06/2007 a las 11:21:22 Hs.
  */
  v_registro IG_AUDITORIAS%ROWTYPE; -- Registro de la tabla IG_AUDITORIAS
BEGIN
  v_registro.tabla := 'IG_MORAS';
  v_registro.clave := to_char( :old.cod_mora);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA_HASTA', :old.dia_hasta, :new.dia_hasta, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MOROSIDAD', :old.morosidad, :new.morosidad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ABREVIATURA', :old.abreviatura, :new.abreviatura );

  -- Insertar tabla de auditoria
  pri_ins_ig_auditoria( v_registro );
EXCEPTION
  when others then
    pri_ins_ig_auditoria( v_registro );
END;
/

