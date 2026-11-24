CREATE OR REPLACE TRIGGER IT.AB_GE_GRU_ECONOMICOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_GRU_ECONOMICOS
 FOR EACH ROW

DECLARE

/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS;
/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD;

/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS
 IS
begin
   :new.fec_insercion := sysdate;
   :new.usu_insercion := substr(user,1,10);
end;
/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD
 IS
begin
   :new.fec_modificacion := sysdate;
   :new.usu_modificacion := substr(user,1,10);
end;
BEGIN
   -- Verificar que se realice por programa
   IF nvl(pae_cnf.g_aplicacion,'N') = 'N' THEN
      raise_application_error(-20000,
      'Solo pueden realizarse modificaciones a través del Sistema');
   END IF;
   -- Controlar si el módulo se encuentra habilitado
   ---pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   -- Registrar campos de auditoria
   IF inserting THEN
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   ELSIF updating THEN
      lp_reg_aud_mod;
   END IF;
END;
/

