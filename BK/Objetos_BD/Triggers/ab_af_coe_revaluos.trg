CREATE OR REPLACE TRIGGER IT.AB_AF_COE_REVALUOS
 BEFORE DELETE OR INSERT OR UPDATE
     ON AF_COE_REVALUOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 10/08/2007 a las 11:40:17 Hs.
  */
  /* Registrar campos de auditoria para insercion de datos. */
  PROCEDURE lp_reg_aud_ins;

  /* Registrar campos de auditoria para modificacion del registro. */
  PROCEDURE lp_reg_aud_mod;

  /* Registrar campos de auditoria para insercion de datos. */
  PROCEDURE lp_reg_aud_ins IS
  BEGIN
    :new.fec_insercion := sysdate;
    :new.usu_insercion := substr( user, 1, 10 );
  END;

  /* Registrar campos de auditoria para modificacion del registro. */
  PROCEDURE lp_reg_aud_mod IS
  BEGIN
    :new.fec_modificacion := sysdate;
    :new.usu_modificacion := substr( user, 1, 10 );
  END;
BEGIN
  -- Verificar que se realice por programa
  IF nvl( pae_cnf.g_aplicacion, 'N' ) = 'N' THEN
    RAISE_APPLICATION_ERROR( -20000, 'Solo pueden realizarse modificaciones a través del Sistema.' );
  END IF;
  -- Controlar si el módulo se encuentra habilitado
  pae_cnf.pr_ctr_modulo( pae_cnf.g_cod_modulo );
  -- Registrar campos de auditoria
  IF inserting THEN
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  ELSIF updating THEN
    lp_reg_aud_mod;
  END IF;
END;
/

