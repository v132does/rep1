CREATE OR REPLACE TRIGGER IT.AB_BW_NOT_CLI_SUSCRIPTOS
  before insert or update on bw_not_cli_suscriptos  
  for each row
DECLARE

   /*
   || Archivo creado por el Generador de Triggers de Auditoría
   || (c) 2005 - IT Consultores
   || Generado el 30/04/2015 a las 15:09:56 Hs.
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
      IF :new.activo = 'S' THEN
         lp_reg_aud_ins;
      END IF;
      :new.fec_modificacion := SYSDATE;
      :new.usu_modificacion := substr(USER, 1, 10);
   END;
BEGIN
   -- Verificar que se realice por programa
   /*IF nvl( pae_cnf.g_aplicacion, 'N' ) = 'N' THEN
     RAISE_APPLICATION_ERROR( -20000, 'Solo pueden realizarse modificaciones a través del Sistema.' );
   END IF;*/
   -- Controlar si el módulo se encuentra habilitado
   --pae_cnf.pr_ctr_modulo( pae_cnf.g_cod_modulo );
   -- Registrar campos de auditoria
   IF inserting THEN
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   ELSIF updating THEN
      lp_reg_aud_mod;
      IF :new.activo = 'N' THEN
         UPDATE bw_not_cli_destino
            SET activo = 'N'
          WHERE cod_persona = :new.cod_persona;
      END IF;
   END IF;
END AB_BW_NOT_CLI_SUSCRIPTOS;
/

