CREATE OR REPLACE TRIGGER IT.AB_CB_ASI_AUTOMATICOS_DET
 BEFORE DELETE OR INSERT OR UPDATE
 ON CB_ASI_AUTOMATICOS_DET
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
  --DESOPIMI-21 - FASE 2 - Optimización PRA_GEN_ASIENTOS
  if pae_cnf.g_programa <> 'GPPROFIN' then
    -- Verificar que se realice por programa
    if nvl(pae_cnf.g_aplicacion, 'N') = 'N' then
      raise_application_error(-20000,
                              'Solo pueden realizarse modificaciones a través del Sistema');
    end if;
    -- Controlar si el módulo se encuentra habilitado
    --- Comentado porque es actualizado por el cierre e inicio
    ---pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
    -- Registrar campos de auditoria
    if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
    elsif updating then
      lp_reg_aud_mod;
    end if;
  end if;
END;
/

