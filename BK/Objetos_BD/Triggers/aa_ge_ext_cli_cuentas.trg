CREATE OR REPLACE TRIGGER IT."AA_GE_EXT_CLI_CUENTAS"
 AFTER DELETE OR UPDATE
 ON GE_EXT_CLI_CUENTAS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_EXT_CLI_CUENTAS';
   r_gaudi.clave := :old.cod_persona||'#'||to_char(:old.fec_extracto,'ddmmrrrr')||'#'||:old.fre_extracto||'#'||to_char(:old.cod_extracto)||'#'||:old.nro_cuenta;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_CUENTA',:old.tip_cuenta,:new.tip_cuenta);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_ANTERIOR',:old.sal_anterior,:new.sal_anterior,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_ACTUAL',:old.sal_actual,:new.sal_actual,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_A_CONFIRMAR',:old.sal_a_confirmar,:new.sal_a_confirmar,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_FOLIO',:old.nro_folio,:new.nro_folio,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TAS_RETORNO',:old.tas_retorno,:new.tas_retorno,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TAS_NOMINAL',:old.tas_nominal,:new.tas_nominal,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TAS_EFECTIVA',:old.tas_efectiva,:new.tas_efectiva,'N');
    
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_PROMEDIO',:old.sal_promedio,:new.sal_promedio,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CTA_COMBINADA',:old.nro_cta_combinada,:new.nro_cta_combinada);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CONCEPTO',:old.concepto,:new.concepto);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_PER_EMPRESA',:old.cod_per_empresa,:new.cod_per_empresa);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SAL_BLOQUEADO',:old.sal_bloqueado,:new.sal_bloqueado);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

