CREATE OR REPLACE TRIGGER IT.AB_CC_CTA_CORRIENTES_NOC
 BEFORE DELETE OR INSERT OR UPDATE OF COD_MONEDA
, COD_ENTE
, FEC_APERTURA
, ESTADO
, MTO_DEB_PENDIENTES
, COD_CANAL
, CAN_FIR_REGISTRADAS
, TAS_PERSONALIZADA
, CTA_COMBINADA
, SAL_TOT_BATCH
, REG_FIRMA
, SAL_ULT_EXTRACTO
, SAL_BLOQUEADO
, DENOMINACION
, CAN_FIR_REQUERIDAS
, COD_USU_PROMOTOR
, NOM_CHEQUERA
, DIG_VERIFICADOR
, COD_MODALIDAD
, AUT_PENDIENTE
, SAL_RETENIDO
, SAL_TOTAL
, FRE_EXTRACTO
, SAL_MINIMO
, MTO_CRE_PENDIENTES
, RET_PERSONALIZADA
, TRA_PROHIBIDA
, NRO_FOLIO
, MTO_APERTURA
, EN_JUICIO
, COD_CAMPANA
, NRO_CUENTA
, FEC_CAM_ESTADO
, SAL_RET_BATCH
, ACU_SOBREGIRO
, FEC_ULT_MOVIMIENTO
, HOR_ULT_MOVIMIENTO
, SAL_BLO_BATCH
, COD_MODULO
, COD_OFICINA
, FEC_ULT_EXTRACTO
, MTO_CRE_A_CONFIRMAR
 ON CC_CTA_CORRIENTES_NOC
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
   -- Controlar si el módulo se encuentra habilitado
   ---pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo); --- Se utiliza en el cierre
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
      lp_reg_aud_mod;
   end if;
END;
/

