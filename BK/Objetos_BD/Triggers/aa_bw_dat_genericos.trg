CREATE OR REPLACE TRIGGER IT.AA_BW_DAT_GENERICOS
  AFTER DELETE OR UPDATE
     ON BW_DAT_GENERICOS
    FOR EACH ROW
DECLARE
  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_DAT_GENERICOS';
  v_registro.clave := to_char( :old.cod_dato);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;
  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_EMPRESA', :old.cod_empresa, :new.cod_empresa );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DATOS_GENERICOS', :old.datos_genericos, :new.datos_genericos );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

