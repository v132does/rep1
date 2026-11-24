CREATE OR REPLACE TRIGGER "IT".AB_TA_PRODUCTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON "IT".TA_PRODUCTOS
 FOR EACH ROW
DECLARE
    /* Registrar campos de auditoria para insercion de datos. */
    PROCEDURE LP_REG_AUD_INS IS
    BEGIN
       :new.fec_insercion := sysdate;
       :new.usu_insercion := substr(user,1,10);
    END;

    /* Registrar campos de auditoria para modificacion del registro. */
    PROCEDURE LP_REG_AUD_MOD IS
    BEGIN
       :new.fec_modificacion := sysdate;
       :new.usu_modificacion := substr(user,1,10);
    END;

BEGIN
   -- Verificar que se realice por programa
   if nvl(pae_cnf.g_aplicacion,'N') = 'N' then
      raise_application_error(-20000,
      'Solo pueden realizarse modificaciones a través del Sistema');
   end if;
   
   -- Controlar si el módulo se encuentra habilitado
   pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
END;
/