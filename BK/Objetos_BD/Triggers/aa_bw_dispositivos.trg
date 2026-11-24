CREATE OR REPLACE TRIGGER IT.AA_BW_DISPOSITIVOS
  AFTER DELETE OR UPDATE
     ON BW_DISPOSITIVOS
    FOR EACH ROW
DECLARE
  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_DISPOSITIVOS';
  v_registro.clave := :old.id_dispositivo;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OS', :old.os, :new.os );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OS_VERSION', :old.os_version, :new.os_version );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MARCA', :old.marca, :new.marca );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MODELO', :old.modelo, :new.modelo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EMULADOR', :old.emulador, :new.emulador );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ULT_ACCESO', :old.ult_acceso, :new.ult_acceso, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_CLI_DISPOSITIVO', :old.tip_cli_dispositivo, :new.tip_cli_dispositivo );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

