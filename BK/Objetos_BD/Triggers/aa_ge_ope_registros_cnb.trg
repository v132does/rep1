CREATE OR REPLACE TRIGGER IT.aa_ge_ope_registros_cnb
  after delete or update on it.ge_ope_registros_cnb
  for each row
declare
  v_registro ba_auditorias%rowtype; -- registro de la tabla ba_auditorias
begin
  v_registro.tabla          := 'GE_OPE_REGISTROS_CNB';
  v_registro.clave          := :old.id_acceso;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
  if updating then
    v_registro.tip_novedad := 'M';
  elsif deleting then
    v_registro.tip_novedad := 'E';
  end if;
  -- registrar detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'ID_ACCESO', :old.id_acceso, :new.id_acceso);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'REF_OPERACION', :old.ref_operacion, :new.ref_operacion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'NRO_CUOTAS', :old.nro_cuotas, :new.nro_cuotas);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'FEC_OPERACION', :old.fec_operacion, :new.fec_operacion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'EMPRESA', :old.empresa, :new.empresa);
  -- insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria(v_registro);
exception
  when others then
    pae_cnf.pr_ins_ba_auditoria(v_registro);
end;
/

