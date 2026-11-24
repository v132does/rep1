CREATE OR REPLACE TRIGGER IT.AB_CB_INF_DER_GASTOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON CB_INF_DER_GASTOS
 FOR EACH ROW


DECLARE

/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS;
/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD;

/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS
IS
BEGIN
   IF :new.fec_insercion IS NULL OR :new.usu_insercion IS NULL THEN
     :new.fec_insercion := SYSDATE;
     :new.usu_insercion := substr(USER,1,10);
   END IF;
END;

/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD
IS
BEGIN
   :new.fec_modificacion := SYSDATE;
   :new.usu_modificacion := substr(USER,1,10);
END;

BEGIN
   -- Verificar que se realice por programa
   IF nvl(pae_cnf.g_aplicacion,'N') = 'N' THEN
      raise_application_error(-20000,'Solo pueden realizarse modificaciones a través del Sistema');
   END IF;
   -- Registrar campos de auditoria
   IF inserting THEN
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   ELSIF updating THEN
      IF nvl(PAE_CNF.G_PROGRAMA,'x') <> 'GPPROFIN' THEN
         lp_reg_aud_mod;
      END IF;
   END IF;
END;
/

