CREATE OR REPLACE TRIGGER IT."AB_AH_CTA_VISTAS"
 BEFORE DELETE OR INSERT OR UPDATE OF COD_TASA
, SAL_MINIMO
, SAL_ULT_EXTRACTO
, FEC_CAM_ESTADO
, MTO_CRE_PENDIENTES
, SAL_RET_BATCH
, COD_MODALIDAD
, COD_MODULO
, FRE_EXTRACTO
, FEC_APERTURA
, NRO_FOLIO
, TRA_PROHIBIDA
, HOR_ULT_MOVIMIENTO
, CTA_COMBINADA
, COD_OFICINA
, EST_BATCH
, FEC_ULT_MOVIMIENTO
, SAL_BLOQUEADO
, MTO_APERTURA
, CAN_FIR_REQUERIDAS
, TIP_CAPITALIZACION
, MTO_CRE_A_CONFIRMAR
, CAN_FIR_REGISTRADAS
, REG_FIRMA
, DIG_VERIFICADOR
, DENOMINACION
, FEC_ULT_CAPITALIZACION
, SAL_BLO_BATCH
, COD_USU_PROMOTOR
, TAS_PERSONALIZADA
, NRO_CUENTA
, COD_MONEDA
, RET_PERSONALIZADA
, SAL_TOTAL
, ESTADO
, SAL_TOT_BATCH
, FEC_ULT_EXTRACTO
, SAL_RETENIDO
, COD_CAMPANA
, AUT_PENDIENTE
, COD_ENTE
, COD_CANAL
, SAL_ULT_CAPITALIZACION
, MTO_DEB_PENDIENTES
 ON "IT"."AH_CTA_VISTAS"
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

