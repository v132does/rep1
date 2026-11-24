CREATE OR REPLACE TRIGGER IT.AA_CB_RUB_BCP
 AFTER DELETE OR UPDATE
 ON CB_RUB_BCP
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_RUB_BCP';
   r_baudi.clave := :old.cod_rub_bcp;
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'NRO_ORDEN',:old.nro_orden,:new.nro_orden,'N');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'AJUSTABLE',:old.ajustable,:new.ajustable);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MON_NACIONAL',:old.mon_nacional,:new.mon_nacional);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'MON_EXTRANJERA',:old.mon_extranjera,:new.mon_extranjera);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'EQU_MON_NACIONAL',:old.equ_mon_nacional,:new.equ_mon_nacional);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SUM_MON_NACIONAL',:old.sum_mon_nacional,:new.sum_mon_nacional);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PRO_MON_NACIONAL',:old.pro_mon_nacional,:new.pro_mon_nacional);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PRO_MON_USD',:old.pro_mon_usd,:new.pro_mon_usd);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PRO_MON_EQU_EXTRANJERA',:old.pro_mon_equ_extranjera,:new.pro_mon_equ_extranjera);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SUM_PRO_MON_NACIONAL',:old.sum_pro_mon_nacional,:new.sum_pro_mon_nacional);

   --- Insertar tabla de auditoria
   PRB_INS_CB_AUDITORIA(r_baudi);
END;
/

