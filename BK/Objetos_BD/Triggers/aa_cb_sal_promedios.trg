CREATE OR REPLACE TRIGGER IT.AA_CB_SAL_PROMEDIOS
 AFTER DELETE
 ON CB_SAL_PROMEDIOS
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_SAL_PROMEDIOS';
   r_baudi.clave := to_char(:old.cod_oficina)||'#'||:old.cod_rubro||'#'||to_char(:old.ano)||'#'||to_char(:old.mes);
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_ACUMULADO',:old.tot_acumulado,:new.tot_acumulado,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_ACU_MON_LOCAL',:old.tot_acu_mon_local,:new.tot_acu_mon_local,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_ACU_MON_FUERTE',:old.tot_acu_mon_fuerte,:new.tot_acu_mon_fuerte,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_ACU_DEBITOS',:old.tot_acu_debitos,:new.tot_acu_debitos,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_ACU_CREDITOS',:old.tot_acu_creditos,:new.tot_acu_creditos,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_ACU_DEB_MON_LOCAL',:old.tot_acu_deb_mon_local,:new.tot_acu_deb_mon_local,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TOT_ACU_CRE_MON_LOCAL',:old.tot_acu_cre_mon_local,:new.tot_acu_cre_mon_local,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'CAN_DIA_ACUMULADO',:old.can_dia_acumulado,:new.can_dia_acumulado,'N');

   --- Insertar tabla de auditoria
   PRB_INS_CB_AUDITORIA(r_baudi);
END;
/

