CREATE OR REPLACE TRIGGER IT.AB_BW_LOG_INTENCION
  BEFORE INSERT OR UPDATE
    ON "IT"."BW_LOG_INTENCION"
  FOR EACH ROW
DECLARE
  /* Registra campos de auditoría para inserción de datos. */
  PROCEDURE lp_reg_aud_ins;
  
  /* Registra campos de auditoría para modificación del registro. */
  PROCEDURE lp_reg_aud_mod;
  
  /* Registra campos de auditoría para inserción de datos. */
  PROCEDURE lp_reg_aud_ins IS
  BEGIN
    :new.fec_insercion := sysdate;
    :new.usu_insercion := substr( user, 1, 10 );
  END;
  
  /* Registra campos de auditoría para modificación del registro. */
  PROCEDURE lp_reg_aud_mod IS
  BEGIN
    :new.fec_modificacion := sysdate;
    :new.usu_modificacion := substr( user, 1, 10 );
  END;
BEGIN
  
  IF inserting THEN
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  ELSIF updating THEN
    lp_reg_aud_mod;
  END IF;
END;
