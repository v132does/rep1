CREATE OR REPLACE TRIGGER IT.AA_CJ_CONTROLES
 AFTER DELETE OR UPDATE
 ON CJ_CONTROLES
 FOR EACH ROW


DECLARE
r_jaudi cj_auditorias%rowtype; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
   r_jaudi.tabla := 'CJ_CONTROLES';
   r_jaudi.clave := to_char(:old.nro_caja)||'#'||:old.cod_moneda||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_jaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_jaudi.tip_novedad := 'M';
   elsif deleting then
      r_jaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_jaudi.detalle := pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'MTO_APERTURA',:old.mto_apertura,:new.mto_apertura,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'SAL_ACTUAL',:old.sal_actual,:new.sal_actual,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'MTO_CIERRE',:old.mto_cierre,:new.mto_cierre,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'TOT_DEBITOS',:old.tot_debitos,:new.tot_debitos,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'TOT_CREDITOS',:old.tot_creditos,:new.tot_creditos,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'CAN_DEBITOS',:old.can_debitos,:new.can_debitos,'N');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'CAN_CREDITOS',:old.can_creditos,:new.can_creditos,'N');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'TOT_CHE_NUE_BCO',:old.tot_che_nue_bco,:new.tot_che_nue_bco,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'DET_CHE_NUE_BCO',:old.det_che_nue_bco,:new.det_che_nue_bco,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'INI_CHE_OTR_BCO',:old.ini_che_otr_bco,:new.ini_che_otr_bco,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'TOT_CHE_OTR_BCO',:old.tot_che_otr_bco,:new.tot_che_otr_bco,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'DET_CHE_OTR_BCO',:old.det_che_otr_bco,:new.det_che_otr_bco,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'SAL_CHE_OTR_BCO',:old.sal_che_otr_bco,:new.sal_che_otr_bco,'M');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'ESTADO',:old.estado,:new.estado,'N');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'COD_USU_ACTUAL',:old.cod_usu_actual,:new.cod_usu_actual);

   --- Insertar tabla de auditoria
   PRJ_INS_CJ_AUDITORIA(r_jaudi);
END;
/

