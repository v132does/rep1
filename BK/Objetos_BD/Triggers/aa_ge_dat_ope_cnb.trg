CREATE OR REPLACE TRIGGER IT.aa_ge_dat_ope_cnb
  after delete or update on it.ge_dat_ope_cnb
  for each row
declare
  v_registro ba_auditorias%rowtype; -- registro de la tabla ba_auditorias
begin
  v_registro.tabla          := 'GE_DAT_OPE_CNB';
  v_registro.clave          := :old.id_operacion;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
  if updating then
    v_registro.tip_novedad := 'M';
  elsif deleting then
    v_registro.tip_novedad := 'E';
  end if;
  -- registrar detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'ID_OPERACION', :old.id_operacion, :new.id_operacion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'TIP_OPERACION', :old.tip_operacion, :new.tip_operacion);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria(v_registro.tip_novedad, 'DAT_OPERACION', :old.dat_operacion, :new.dat_operacion);
  -- insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria(v_registro);
exception
  when others then
    pae_cnf.pr_ins_ba_auditoria(v_registro);
end;
/

