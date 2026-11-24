CREATE OR REPLACE TRIGGER IT.AB_GE_PAG_SUE_IPS
 BEFORE DELETE OR INSERT OR UPDATE
     ON GE_PAG_SUE_IPS
    FOR EACH ROW
DECLARE
   /*
   || Archivo creado por el Generador de Triggers de Auditoría
   */
   /* Registrar campos de auditoria para insercion de datos. */
   PROCEDURE lp_reg_aud_ins;

   /* Registrar campos de auditoria para modificacion del registro. */
   PROCEDURE lp_reg_aud_mod;

   /* Registrar campos de auditoria para insercion de datos. */
   PROCEDURE lp_reg_aud_ins IS
   BEGIN
      :NEW.fec_insercion := SYSDATE;
      :NEW.usu_insercion := substr(USER, 1, 10);
   END;

   /* Registrar campos de auditoria para modificacion del registro. */
   PROCEDURE lp_reg_aud_mod IS
   BEGIN
      :NEW.fec_modificacion := SYSDATE;
      :NEW.usu_modificacion := substr(USER, 1, 10);
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

