CREATE OR REPLACE TRIGGER IT.aa_ge_dat_acc_ope_cnb
  after delete or update on it.ge_dat_acc_ope_cnb
  for each row
declare

  v_registro ba_auditorias%rowtype; -- registro de la tabla ba_auditorias
begin
  v_registro.tabla          := 'GE_DAT_ACC_OPE_CNB';
  v_registro.clave          := :old.id_acceso;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
  if updating then
    v_registro.tip_novedad := 'M';
  elsif deleting then
    v_registro.tip_novedad := 'E';
  end if;

  -- registrar detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'ID_ACCESO', :old.id_acceso, :new.id_acceso);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'TOKEN', :old.token, :new.token);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'TIP_OPERACION', :old.tip_operacion, :new.tip_operacion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_HOR_CONEXION', :old.fec_hor_conexion, :new.fec_hor_conexion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_HOR_ULT_CONEXION', :old.fec_hor_ult_conexion, :new.fec_hor_ult_conexion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'EMPRESA', :old.empresa, :new.empresa);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'USU_ACCESO', :old.usu_acceso, :new.usu_acceso);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'ID_OPERACION', :old.id_operacion, :new.id_operacion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'TOK_REQ_ID', :old.tok_req_id, :new.tok_req_id);

  -- insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria(v_registro);
exception
  when others then
    pae_cnf.pr_ins_ba_auditoria(v_registro);
end;
/

