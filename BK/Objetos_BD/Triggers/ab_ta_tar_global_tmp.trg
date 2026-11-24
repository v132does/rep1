CREATE OR REPLACE TRIGGER IT.AB_TA_TAR_GLOBAL_TMP
 BEFORE DELETE OR INSERT OR UPDATE
 ON TA_TAR_GLOBAL_TMP
 FOR EACH ROW

DECLARE

/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS;
/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD;
/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS
 IS
BEGIN
   :new.fec_insercion := sysdate;
   :new.usu_insercion := substr(user,1,10);
END;
/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD
 IS
BEGIN 
   :new.fec_modificacion := sysdate;
   :new.usu_modificacion := substr(user,1,10);
END;
BEGIN
   -- Registrar campos de auditoria
   IF inserting THEN
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   ELSIF updating THEN
      lp_reg_aud_mod;
   END IF;
END;
/
