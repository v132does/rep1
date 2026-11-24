CREATE OR REPLACE TRIGGER IT.AA_CC_CTA_CORRIENTES_NOC
 AFTER DELETE OR UPDATE
 OF cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, dig_verificador,
    cod_moneda, denominacion, can_fir_requeridas, can_fir_registradas,
    fec_apertura, ret_personalizada, tas_personalizada, aut_pendiente,
    acu_sobregiro, tra_prohibida, cta_combinada, cod_usu_promotor,
    estado, fec_ult_extracto, nro_folio, fec_cam_estado, nom_chequera,
    cod_canal, cod_campana,  fre_extracto, cod_ente, reg_firma, cod_sub_modalidad
 ON CC_CTA_CORRIENTES_NOC
 FOR EACH ROW
DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CTA_CORRIENTES_NOC';
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
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CAN_FIR_REQUERIDAS',:old.can_fir_requeridas,:new.can_fir_requeridas,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CAN_FIR_REGISTRADAS',:old.can_fir_registradas,:new.can_fir_registradas,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'RET_PERSONALIZADA',:old.ret_personalizada,:new.ret_personalizada);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'TAS_PERSONALIZADA',:old.tas_personalizada,:new.tas_personalizada);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_MINIMO',:old.sal_minimo,:new.sal_minimo,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'AUT_PENDIENTE',:old.aut_pendiente,:new.aut_pendiente);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ACU_SOBREGIRO',:old.acu_sobregiro,:new.acu_sobregiro);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'TRA_PROHIBIDA',:old.tra_prohibida,:new.tra_prohibida);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CTA_COMBINADA',:old.cta_combinada,:new.cta_combinada);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_USU_PROMOTOR',:old.cod_usu_promotor,:new.cod_usu_promotor);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_ULT_EXTRACTO',:old.fec_ult_extracto,:new.fec_ult_extracto,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SAL_ULT_EXTRACTO',:old.sal_ult_extracto,:new.sal_ult_extracto,'M');
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
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NOM_CHEQUERA',:old.nom_chequera,:new.nom_chequera);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_APERTURA',:old.mto_apertura,:new.mto_apertura,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_CANAL',:old.cod_canal,:new.cod_canal,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_CAMPANA',:old.cod_campana,:new.cod_campana,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'EST_BATCH',:old.est_batch,:new.est_batch);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FRE_EXTRACTO',:old.fre_extracto,:new.fre_extracto);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_CRE_PENDIENTES',:old.mto_cre_pendientes,:new.mto_cre_pendientes,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_CRE_A_CONFIRMAR',:old.mto_cre_a_confirmar,:new.mto_cre_a_confirmar,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_ENTE',:old.cod_ente,:new.cod_ente,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'MTO_DEB_PENDIENTES',:old.mto_deb_pendientes,:new.mto_deb_pendientes,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');
    if updating then
       r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'REG_FIRMA',substr(:old.reg_firma,1,400),substr(:new.reg_firma,1,400));
    end if;
   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
EXCEPTION
   WHEN OTHERS THEN
         PRC_INS_CC_AUDITORIA(r_caudi);  -- inserto hasta donde puedo
END;
/

