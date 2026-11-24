CREATE OR REPLACE TRIGGER IT.AA_CC_CTA_BANCARIAS
 AFTER DELETE OR UPDATE
 ON CC_CTA_BANCARIAS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CTA_BANCARIAS';
   r_caudi.clave := :old.nro_cuenta;
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'DIG_VERIFICADOR',:old.dig_verificador,:new.dig_verificador,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'DENOMINACION',:old.denominacion,:new.denominacion);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_MINIMO',:old.sal_minimo,:new.sal_minimo,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_ACUERDO',:old.mto_acuerdo,:new.mto_acuerdo,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'EST_BATCH',:old.est_batch,:new.est_batch);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_ULT_CONCILIACION',:old.fec_ult_conciliacion,:new.fec_ult_conciliacion,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_ULT_CONCILIACION',:old.sal_ult_conciliacion,:new.sal_ult_conciliacion,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_FOLIO',:old.nro_folio,:new.nro_folio,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_CAM_ESTADO',:old.fec_cam_estado,:new.fec_cam_estado,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_ULT_MOVIMIENTO',:old.fec_ult_movimiento,:new.fec_ult_movimiento,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'HOR_ULT_MOVIMIENTO',:old.hor_ult_movimiento,:new.hor_ult_movimiento);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_RET_BATCH',:old.sal_ret_batch,:new.sal_ret_batch,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_RETENIDO',:old.sal_retenido,:new.sal_retenido,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_BLO_BATCH',:old.sal_blo_batch,:new.sal_blo_batch,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_BLOQUEADO',:old.sal_bloqueado,:new.sal_bloqueado,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_TOT_BATCH',:old.sal_tot_batch,:new.sal_tot_batch,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_TOTAL',:old.sal_total,:new.sal_total,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_BANCO',:old.cod_banco,:new.cod_banco,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CTA_BANCARIA',:old.nro_cta_bancaria,:new.nro_cta_bancaria);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_PROGRAMA',:old.cod_programa,:new.cod_programa);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_RUBRO',:old.cod_rubro,:new.cod_rubro);

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/

