CREATE OR REPLACE TRIGGER IT.AA_GE_EQU_DATOS
  AFTER DELETE OR UPDATE
     ON GE_EQU_DATOS
    FOR EACH ROW
DECLARE
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_EQU_DATOS';
  v_registro.clave := to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS') || '#' || :old.tip_persona || '#' || :old.nom_archivo || '#' || to_char( :old.tip_operacion) || '#' || :old.tip_proceso || '#' || :old.estado;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NUM_CLIENTE', :old.num_cliente, :new.num_cliente );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DATOS', :old.datos, :new.datos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COMENTARIO', :old.comentario, :new.comentario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_ARCHIVO', :old.tip_archivo, :new.tip_archivo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DAT_BASE64', :old.dat_base64, :new.dat_base64 );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ERROR', :old.error, :new.error );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

