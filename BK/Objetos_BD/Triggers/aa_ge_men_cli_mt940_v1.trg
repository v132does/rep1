CREATE OR REPLACE TRIGGER IT.AA_GE_MEN_CLI_MT940_V1
  AFTER DELETE OR UPDATE
     ON it.GE_MEN_CLI_MT940_V1
    FOR EACH ROW
DECLARE
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_MEN_CLI_MT940_V1';
  v_registro.clave := :old.cod_persona;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'FEC_EXTRACTO',:old.fec_extracto,:new.fec_extracto);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'NRO_EXTRACTO',:old.nro_extracto,:new.nro_extracto);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'NRO_SECUENCIA',:old.nro_secuencia,:new.nro_secuencia);
  --v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'EXTRACTO',:old.extracto,:new.extracto); Se comenta por el tipo de dato
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'ESTADO',:old.estado,:new.estado);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'TIP_GENERACION',:old.tip_generacion,:new.tip_generacion);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'PERIODICIDAD',:old.periodicidad,:new.periodicidad);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'FEC_DESDE',:old.fec_desde,:new.fec_desde);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'FEC_HASTA',:old.fec_hasta,:new.fec_hasta);
  v_registro.detalle:=v_registro.detalle||pae_cnf.fu_reg_auditoria(v_registro.tip_novedad,'COD_SWIFT_DEST',:old.cod_swift_dest,:new.cod_swift_dest);

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
