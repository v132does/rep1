CREATE OR REPLACE TRIGGER IT.AB_TA_CTA_TARJETAS
 BEFORE DELETE OR INSERT OR UPDATE OF SAL_CUO_PENDIENTES
, FEC_ULT_PAGO
, FEC_ULT_COMPRA
, SAL_FACTURAR
, FEC_ULT_EXTRACTO
, TAS_FINANCIACION
, NRO_SOLICITUD
, DENOMINACION
, LIN_CREDITO
, SAL_PAG_MINIMO
, DIA_MORA
, EN_JUICIO
, MTO_PAG_MINIMO
, MTO_MORA
, MAR_MORA
, NRO_CUENTA
, COD_USU_PROMOTOR
, SAL_ULT_EXTRACTO
, FEC_ULT_OPERACION
, TAS_MORA
, TIP_COBRO
, COD_CANAL
, COD_MODALIDAD
, ESTADO
, COB_GAS_FINANCIERO
, POR_PAG_MINIMO
, CAT_AUTOMATICA
, COD_MODULO
, TAS_ADELANTO
, TAS_CUOTAS
, COD_CAUSA
, EST_ADMINISTRADORA
, FEC_ULT_CIERRE
, FEC_VCT_ULT_CIERRE
, COD_CAMPANA
, LIN_CUOTAS
, COD_MONEDA
, SAL_FACTURADO
, MTO_GAS_MORA
, TIP_TAS_FINANCIACION
, NRO_CTA_DEBITO
, MAR_RECUPERADO
, SAL_FINANCIADO
, MAR_BLOQUEO
, COD_OFICINA
, MTO_PAG_MES
, DEB_AUTOMATICO
, CON_COSTO
, FEC_SOLICITUD
, TIP_COM_EMISION
, MAR_EXCEDIDO
, MTO_MIN_PAGO
, FEC_APERTURA
, COD_TIP_CIERRE
, MTO_AUTORIZACIONES
, MTO_INT_COMPRAS
 ON TA_CTA_TARJETAS
 FOR EACH ROW

DECLARE
 v_usu_excluido ge_par_dinamicos.val_parametro%TYPE:=fug_obt_pardinamico('TAR_COD_USU_EXCLUIDO');
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
   --pae_cnf.pr_ctr_modulo(pae_cnf.g_cod_modulo);
   -- Registrar campos de auditoria
   if inserting then
      lp_reg_aud_ins;
      lp_reg_aud_mod;
   elsif updating then
     IF instr(v_usu_excluido,USER) = 0 THEN
      lp_reg_aud_mod;
     END IF;
   end if;
END;
/
