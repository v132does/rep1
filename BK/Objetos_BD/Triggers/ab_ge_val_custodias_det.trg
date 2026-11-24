CREATE OR REPLACE TRIGGER IT.AB_GE_VAL_CUSTODIAS_DET
 BEFORE DELETE OR INSERT OR UPDATE
     ON GE_VAL_CUSTODIAS_DET
    FOR EACH ROW
DECLARE
   /*
   || Archivo creado por el Generador de Triggers de Auditoría
   || (c) 2005 - IT Consultores
   || Generado el 28/07/2011 a las 10:28:32 Hs.
   */
   /* Registrar campos de auditoria para insercion de datos. */
   PROCEDURE lp_reg_aud_ins;

   /* Registrar campos de auditoria para modificacion del registro. */
   PROCEDURE lp_reg_aud_mod;

   /* Registrar campos de auditoria para insercion de datos. */
   PROCEDURE lp_reg_aud_ins IS
   BEGIN
      :new.fec_insercion := SYSDATE;
      :new.usu_insercion := substr(USER, 1, 10);
   END;

   /* Registrar campos de auditoria para modificacion del registro. */
   PROCEDURE lp_reg_aud_mod IS
   BEGIN
      :new.fec_modificacion := SYSDATE;
      :new.usu_modificacion := substr(USER, 1, 10);
   END;
BEGIN
   -- Verificar que se realice por programa
   IF nvl(pae_cnf.g_aplicacion, 'N') = 'N' THEN
      raise_application_error(-20000, 'Solo pueden realizarse modificaciones a través del Sistema.');
   END IF;
   -- Controlar si el módulo se encuentra habilitado
   pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   -- Registrar campos de auditoria
   IF inserting THEN
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   ELSIF updating THEN
      lp_reg_aud_mod;
   END IF;
END;
/

