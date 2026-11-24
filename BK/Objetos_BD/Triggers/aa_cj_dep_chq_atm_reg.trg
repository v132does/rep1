CREATE OR REPLACE TRIGGER IT.AA_CJ_DEP_CHQ_ATM_REG
  AFTER DELETE OR UPDATE
     ON "IT"."CJ_DEP_CHQ_ATM_REG"
    FOR EACH ROW
DECLARE
  v_registro CJ_AUDITORIAS%ROWTYPE; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
  v_registro.tabla := 'CJ_DEP_CHQ_ATM_REG';
  v_registro.clave := to_char( :old.id_dep_cheque) || '#' || to_char( :old.fecha, 'DD/MM/YYYY HH24:MI:SS');
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_DOCUMENTO', :old.nro_documento, :new.nro_documento);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_DOCUMENTO', :old.tip_documento, :new.tip_documento);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NOM_COMPLETO', :old.nom_completo, :new.nom_completo);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_LOTE', :old.cod_lote, :new.cod_lote);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_TRANSACCION', :old.nro_transaccion, :new.nro_transaccion, 'N');
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ATM_ID', :old.atm_id, :new.atm_id);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CHEQUE', :old.cod_cheque, :new.cod_cheque);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BANCO', :old.cod_banco, :new.cod_banco);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CTA_LIBRADORA', :old.cta_libradora, :new.cta_libradora);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CHEQUE', :old.nro_cheque, :new.nro_cheque);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_TRANSACCION', :old.tip_transaccion, :new.tip_transaccion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO_CHEQUE', :old.monto_cheque, :new.monto_cheque,'M');
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_SOLICITUD', :old.nro_solicitud, :new.nro_solicitud,'N');
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ID_CREAR', :old.cod_id_crear, :new.cod_id_crear);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );


  -- Insertar tabla de auditoria
  prj_ins_cj_auditoria( v_registro );
EXCEPTION
  when others then
    prj_ins_cj_auditoria( v_registro );
END;
/

