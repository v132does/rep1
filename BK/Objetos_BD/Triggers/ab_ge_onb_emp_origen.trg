CREATE OR REPLACE TRIGGER IT.AB_GE_ONB_EMP_ORIGEN
  BEFORE DELETE OR INSERT OR UPDATE ON it.GE_ONB_EMP_ORIGEN
  FOR EACH ROW

DECLARE

  /* Registrar campos de auditoria para insercion de datos. */
  PROCEDURE LP_REG_AUD_INS;
  /* Registrar campos de auditoria para modificacion del registro. */
  PROCEDURE LP_REG_AUD_MOD;

  /* Registrar campos de auditoria para insercion de datos. */
  PROCEDURE LP_REG_AUD_INS IS
  begin
    :new.fec_insercion := sysdate;
    :new.usu_insercion := substr(user, 1, 10);
  end;
  /* Registrar campos de auditoria para modificacion del registro. */
  PROCEDURE LP_REG_AUD_MOD IS
  begin
    :new.fec_modificacion := sysdate;
    :new.usu_modificacion := substr(user, 1, 10);
  end;
BEGIN
  -- Registrar campos de auditoria
  if inserting then
    select it.s_ge_onb_emp_origen.nextval
      into :new.cod_origen
      from dual;
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  elsif updating then
    lp_reg_aud_mod;
  end if;
END;
/

