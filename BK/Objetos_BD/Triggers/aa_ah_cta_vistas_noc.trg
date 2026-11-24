CREATE OR REPLACE TRIGGER IT.AA_AH_CTA_VISTAS_NOC
 AFTER DELETE OR UPDATE
 ON AH_CTA_VISTAS_NOC
 FOR EACH ROW


DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_CTA_VISTAS_NOC';
   r_aaudi.clave := :old.nro_cuenta;
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'DIG_VERIFICADOR',:old.dig_verificador,:new.dig_verificador,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'DENOMINACION',:old.denominacion,:new.denominacion);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FRE_EXTRACTO',:old.fre_extracto,:new.fre_extracto);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_FIR_REQUERIDAS',:old.can_fir_requeridas,:new.can_fir_requeridas,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_FIR_REGISTRADAS',:old.can_fir_registradas,:new.can_fir_registradas,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIP_CAPITALIZACION',:old.tip_capitalizacion,:new.tip_capitalizacion,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TAS_PERSONALIZADA',:old.tas_personalizada,:new.tas_personalizada);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CAU_CANCELACION',:old.cod_cau_cancelacion,:new.cod_cau_cancelacion);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_TASA',:old.cod_tasa,:new.cod_tasa,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'RET_PERSONALIZADA',:old.ret_personalizada,:new.ret_personalizada);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_MINIMO',:old.sal_minimo,:new.sal_minimo,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_USU_PROMOTOR',:old.cod_usu_promotor,:new.cod_usu_promotor);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'NRO_FOLIO',:old.nro_folio,:new.nro_folio,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_EXTRACTO',:old.fec_ult_extracto,:new.fec_ult_extracto,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_ULT_EXTRACTO',:old.sal_ult_extracto,:new.sal_ult_extracto,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_CAM_ESTADO',:old.fec_cam_estado,:new.fec_cam_estado,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_MOVIMIENTO',:old.fec_ult_movimiento,:new.fec_ult_movimiento,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'HOR_ULT_MOVIMIENTO',:old.hor_ult_movimiento,:new.hor_ult_movimiento);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_CAPITALIZACION',:old.fec_ult_capitalizacion,:new.fec_ult_capitalizacion,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_ULT_CAPITALIZACION',:old.sal_ult_capitalizacion,:new.sal_ult_capitalizacion,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_RETENIDO',:old.sal_retenido,:new.sal_retenido,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_BLOQUEADO',:old.sal_bloqueado,:new.sal_bloqueado,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_TOTAL',:old.sal_total,:new.sal_total,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TRA_PROHIBIDA',:old.tra_prohibida,:new.tra_prohibida);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CTA_COMBINADA',:old.cta_combinada,:new.cta_combinada);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'AUT_PENDIENTE',:old.aut_pendiente,:new.aut_pendiente);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_DEB_PENDIENTES',:old.mto_deb_pendientes,:new.mto_deb_pendientes,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_CRE_PENDIENTES',:old.mto_cre_pendientes,:new.mto_cre_pendientes,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_CRE_A_CONFIRMAR',:old.mto_cre_a_confirmar,:new.mto_cre_a_confirmar,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_ENTE',:old.cod_ente,:new.cod_ente,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_APERTURA',:old.mto_apertura,:new.mto_apertura,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CANAL',:old.cod_canal,:new.cod_canal,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_CAMPANA',:old.cod_campana,:new.cod_campana,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');
    if updating then
       r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'EST_BATCH',:old.est_batch,:new.est_batch);
       r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_RET_BATCH',:old.sal_ret_batch,:new.sal_ret_batch,'M');
       r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_BLO_BATCH',:old.sal_blo_batch,:new.sal_blo_batch,'M');
       r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_TOT_BATCH',:old.sal_tot_batch,:new.sal_tot_batch,'M');
       r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'REG_FIRMA',substr(:old.reg_firma,1,400),substr(:new.reg_firma,1,400));
    end if;
   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/

