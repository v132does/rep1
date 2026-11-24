CREATE OR REPLACE TRIGGER IT.AB_PR_SIM_CARGOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_SIM_CARGOS
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
   if substr(user,1,3) != 'ATM' and user != 'HBANK' then --PCCDEEVO-214 06/2017.
     -- Controlar si el módulo se encuentra habilitado
     pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   end if;
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
END;
/

