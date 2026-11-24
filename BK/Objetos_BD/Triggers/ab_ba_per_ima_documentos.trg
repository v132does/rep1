CREATE OR REPLACE TRIGGER IT.AB_BA_PER_IMA_DOCUMENTOS
 BEFORE DELETE OR INSERT OR UPDATE
     ON BA_PER_IMA_DOCUMENTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2015 - IT Consultores
  || Generado el 22/07/2015 a las 10:18:28 Hs.
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
  IF nvl( pae_cnf.g_aplicacion, 'N' ) = 'N' and fue_obt_des_refcodes('USU_ALT_PERSONA',user)<> user THEN
    RAISE_APPLICATION_ERROR( -20000, 'Solo pueden realizarse modificaciones a través del Sistema.' );
  END IF;
  if fue_obt_des_refcodes('USU_ALT_PERSONA',user)<> user then
  -- Controlar si el módulo se encuentra habilitado
  pae_cnf.pr_ctr_modulo( pae_cnf.g_cod_modulo );
 end if;
  -- Registrar campos de auditoria
  IF inserting THEN
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  ELSIF updating THEN
    lp_reg_aud_mod;
  END IF;
END;
/

