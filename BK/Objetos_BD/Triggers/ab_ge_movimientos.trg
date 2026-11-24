CREATE OR REPLACE TRIGGER IT.AB_GE_MOVIMIENTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_MOVIMIENTOS
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
   if :new.fec_insercion is null or :new.usu_insercion is null then
     :new.fec_insercion := sysdate;
     :new.usu_insercion := substr(user,1,10);
   end if;
end;
/* Registrar campos de auditoria para modificacion del registro. */
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
      'Solo pueden realizarse modificaciones a través del Sistema');
   end if;
   -- Controlar si el módulo se encuentra habilitado
   ------- Comentado porque modifica el cierre e inicio de dia
   ------- pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      if nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' then
         lp_reg_aud_mod;
      end if;   
   end if;
END;
/

