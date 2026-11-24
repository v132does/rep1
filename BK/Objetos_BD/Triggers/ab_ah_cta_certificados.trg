CREATE OR REPLACE TRIGGER IT."AB_AH_CTA_CERTIFICADOS"
 BEFORE DELETE OR INSERT OR UPDATE OF COD_MODULO
, TIPO
, NRO_CUENTA
, COD_USU_PROMOTOR
, FEC_ULT_CAPITALIZACION
, COD_CANAL
, SERIE
, COD_CAMPANA
, DENOMINACION
, FEC_PAGO
, EST_BATCH
, SAL_TOTAL
, TAS_PERSONALIZADA
, EST_CER_BATCH
, AUT_PENDIENTE
, SAL_RET_BATCH
, TIP_CAPITALIZACION
, FEC_CAM_ESTADO
, FEC_VENCIMIENTO
, BENEFICIARIO
, SAL_BLO_BATCH
, TRA_PROHIBIDA
, FEC_APERTURA
, SAL_TOT_BATCH
, COD_MONEDA
, COD_TASA
, HOR_ULT_MOVIMIENTO
, NRO_CTA_RENOVADA
, COD_OFICINA
, FEC_ULT_MOVIMIENTO
, COD_MODALIDAD
, NRO_CERTIFICADO
, EST_CERTIFICADO
, SAL_RETENIDO
, DIG_VERIFICADOR
, CAPITAL
, ESTADO
, SAL_BLOQUEADO
, BLOQUEADO
 ON "IT"."AH_CTA_CERTIFICADOS"
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
      'Solo pueden realizarse modificaciones a trav¿s del Sistema');
   end if;
   -- Controlar si el m¿dulo se encuentra habilitado
   ------- Comentado porque modifica el cierre e inicio de dia
   ------- pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
END;
/

