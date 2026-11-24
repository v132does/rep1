CREATE OR REPLACE TRIGGER IT.AA_BW_SOF_EMPRESAS
  AFTER DELETE OR UPDATE
     ON BW_SOF_EMPRESAS
    FOR EACH ROW
DECLARE

  v_registro BW_AUDITORIAS%ROWTYPE; -- Registro de la tabla BW_AUDITORIAS
BEGIN
  v_registro.tabla := 'BW_SOF_EMPRESAS';
  v_registro.clave := to_char( :old.sof_ser_id) || '#' || :old.cod_per_vinculada;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ENROLADO', :old.enrolado, :new.enrolado );

  -- Insertar tabla de auditoria
  prw_ins_bw_auditoria( v_registro );
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

