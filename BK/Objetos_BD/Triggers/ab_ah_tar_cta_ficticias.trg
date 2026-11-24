CREATE OR REPLACE TRIGGER IT.AB_AH_TAR_CTA_FICTICIAS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AH_TAR_CTA_FICTICIAS
 REFERENCING OLD AS OLD NEW AS NEW
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
/* Registrar campos de auditoria para modificacion del registro. Creado en Proyecto SDBIN8TDD-1 */
PROCEDURE LP_REG_AUD_MOD
 IS
begin
   :new.fec_modificacion := sysdate;
   :new.usu_modificacion := substr(user,1,10);
end;
BEGIN
   -- Verificar que se realice por programa
   if nvl(pae_cnf.g_aplicacion,'N') = 'N' then
      raise_application_error(-20000,
      'Solo pueden realizarse modificaciones a traves del Sistema');
   end if;
   -- Controlar si el modulo se encuentra habilitado
   ---pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo); -- Se actualiza con el cierre
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
END;
/

