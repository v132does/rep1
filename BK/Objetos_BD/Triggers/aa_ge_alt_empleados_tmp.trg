CREATE OR REPLACE TRIGGER IT.AA_GE_ALT_EMPLEADOS_TMP
  AFTER DELETE OR UPDATE
     ON GE_ALT_EMPLEADOS_TMP
    FOR EACH ROW
DECLARE
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_ALT_EMPLEADOS_TMP';
  v_registro.clave := to_char( :old.cod_ENTE);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ENTE', :old.cod_ente, :new.cod_ente);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_LOTE', :old.NRO_LOTE, :new.NRO_LOTE);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_DOCUMENTO', :old.TIP_DOCUMENTO, :new.TIP_DOCUMENTO);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SOBREGIRO', :old.SOBREGIRO, :new.SOBREGIRO);

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

