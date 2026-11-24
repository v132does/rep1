CREATE OR REPLACE TRIGGER IT.AB_GE_PAR_FATCA
 BEFORE DELETE OR INSERT OR UPDATE
     ON GE_PAR_FATCA
   FOR EACH ROW

DECLARE
  /*
  Generado el 24/04/2014 a las 11:23:01 Hs.
  */
  /* Registrar campos de auditoria para insercion de datos. */
  PROCEDURE lp_reg_aud_ins;

  /* Registrar campos de auditoria para modificacion del registro. */
  PROCEDURE lp_reg_aud_mod;

/* Registrar campos de auditoria para insercion de datos. */
  PROCEDURE lp_reg_aud_ins IS
begin
   :new.fec_insercion := sysdate;
   :new.usu_insercion := substr(user,1,10);
end;
/* Registrar campos de auditoria para modificacion del registro. */
  PROCEDURE lp_reg_aud_mod IS
begin
   :new.fec_modificacion := sysdate;
   :new.usu_modificacion := substr(user,1,10);
end;
BEGIN
   -- Verificar que se realice por programa
   if nvl(pae_cnf.g_aplicacion,'N') = 'N' then
    RAISE_APPLICATION_ERROR( -20000, 'Solo pueden realizarse modificaciones a través del Sistema.' );
   end if;
   -- Controlar si el módulo se encuentra habilitado
  pae_cnf.pr_ctr_modulo( pae_cnf.g_cod_modulo );
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
END;
/

