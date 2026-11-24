CREATE OR REPLACE TRIGGER IT.AB_GE_MEN_CLI_MT940_V1
  BEFORE DELETE OR INSERT OR UPDATE ON it.GE_MEN_CLI_MT940_V1
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
     -- Verificar que se realice por programa
/*   if nvl(pae_cnf.g_aplicacion,'N') = 'N' then
      raise_application_error(-20000,
      'Solo pueden realizarse modificaciones a través del Sistema');
   end if;*/ -- se comenta la linea porque se estaria ejecutando desde un servicio.
  if inserting then
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  elsif updating then
    lp_reg_aud_mod;
  end if;
END;
/
