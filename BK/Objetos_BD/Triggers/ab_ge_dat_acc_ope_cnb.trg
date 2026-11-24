CREATE OR REPLACE TRIGGER IT.ab_ge_dat_acc_ope_cnb
  before delete or insert or update on it.ge_dat_acc_ope_cnb
  for each row
declare
  /* registrar campos de auditoria para insercion de datos. */
  procedure lp_reg_aud_ins;
  /* registrar campos de auditoria para modificacion del registro. */
  procedure lp_reg_aud_mod;
  /* registrar campos de auditoria para insercion de datos. */
  procedure lp_reg_aud_ins is
  begin
    :new.fec_insercion := sysdate;
    :new.usu_insercion := substr(user, 1, 10);
  end;
  /* registrar campos de auditoria para modificacion del registro. */
  procedure lp_reg_aud_mod is
  begin
    :new.fec_modificacion := sysdate;
    :new.usu_modificacion := substr(user, 1, 10);
  end;
begin
  -- verificar que se realice por programa
  if nvl(pae_cnf.g_aplicacion, 'N') = 'N' then
    raise_application_error(-20000, 'Solo pueden realizarse modificaciones a través del Sistema');
  end if;
  -- registrar campos de auditoria
  if inserting then
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  elsif updating then
    lp_reg_aud_mod;
  end if;
end;
/

