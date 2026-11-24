CREATE OR REPLACE TRIGGER IT.AA_BA_ONB_EMPRESAS
  AFTER DELETE OR UPDATE
     ON "IT"."BA_ONB_EMPRESAS"
    FOR EACH ROW
DECLARE
  v_registro BA_AUDITORIAS%ROWTYPE;
BEGIN
  v_registro.tabla := 'BA_ONB_EMPRESAS';
  v_registro.clave := :old.cod_onb_emp;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_REGISTRO', :old.fec_registro, :new.fec_registro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EMPRESA', :old.empresa, :new.empresa );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DAT_PERSONA', :old.dat_persona, :new.dat_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FIRMANTES', :old.firmantes, :new.firmantes );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DOCUMENTOS', :old.documentos, :new.documentos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'USUARIOS', :old.usuarios, :new.usuarios );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PRODUCTOS', :old.productos, :new.productos );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PANTALLA', :old.cod_pantalla, :new.cod_pantalla );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ONB_FINALIZADO', :old.onb_finalizado, :new.onb_finalizado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

