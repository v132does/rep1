CREATE OR REPLACE TRIGGER IT.AB_CC_CHE_DEVUELTOS
 BEFORE DELETE OR INSERT OR UPDATE
     ON CC_CHE_DEVUELTOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2006 a las 17:49:09 Hs.
  */
  /* Registrar campos de auditoria para insercion de datos. */
  --
  l_tipo     cc_che_devueltos.tipo%TYPE;
  --
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
    if :new.fec_modificacion is null  then
       :new.fec_modificacion := sysdate;
    end if;
    :new.usu_modificacion := substr( user, 1, 10 );
  END;
BEGIN
  -- Verificar que se realice por programa
  IF nvl( pae_cnf.g_aplicacion, 'N' ) = 'N' THEN
    RAISE_APPLICATION_ERROR( -20000, 'Solo pueden realizarse modificaciones a través del Sistema.' );
  END IF;
  --
  IF UPDATING
    THEN
      --
      IF :NEW.Cod_Causa != :OLD.Cod_Causa
        THEN
          --
           SELECT NVL(MAX(par_causales.val_parametro),:OLD.Tipo)
             INTO l_tipo
            FROM ge_par_causales par_causales, ge_causales causales
           WHERE par_causales.parametro = 'TIP_DEVOLUCION'
            AND par_causales.cod_causa = causales.cod_causa
            AND par_causales.Cod_Causa = :NEW.Cod_Causa;
          --
           :NEW.Tipo := l_tipo;
          --
      END IF;
      --
  END IF;
  --
  -- Controlar si el módulo se encuentra habilitado
  --pae_cnf.pr_ctr_modulo( pae_cnf.g_cod_modulo );
  -- Registrar campos de auditoria
  IF inserting THEN
    lp_reg_aud_ins;
    lp_reg_aud_mod;
  ELSIF updating THEN
    lp_reg_aud_mod;
  END IF;
END;
/
