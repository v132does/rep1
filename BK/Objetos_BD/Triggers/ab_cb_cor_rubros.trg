CREATE OR REPLACE TRIGGER IT.AB_CB_COR_RUBROS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CB_COR_RUBROS
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
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
END;
/

