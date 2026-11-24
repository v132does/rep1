CREATE OR REPLACE TRIGGER IT.AB_BW_CANJES_DET
  BEFORE INSERT OR UPDATE
    ON BW_CANJES_DET
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
  -- Verificar que se realice por programa
  IF nvl( pae_cnf.g_aplicacion, 'N') = 'N' THEN
    RAISE_APPLICATION_ERROR( -20000, 'Solo pueden realizarse modificaciones a través del Sistema.' );
  END IF;

  IF inserting THEN
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  ELSIF updating THEN
    lp_reg_aud_mod;
  END IF;
END;
/

