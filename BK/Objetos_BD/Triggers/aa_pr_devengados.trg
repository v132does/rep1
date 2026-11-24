CREATE OR REPLACE TRIGGER IT.AA_PR_DEVENGADOS
 AFTER DELETE OR UPDATE
 ON PR_DEVENGADOS
 FOR EACH ROW

DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_DEVENGADOS';
   r_paudi.clave := :old.nro_cuenta||'#'||TO_CHAR(:old.nro_cuota)||'#'||:old.tipo ||'#'||:old.cod_moneda
                    ||'#'||:old.estado ||'#'||TO_CHAR(:old.categoria)||'#'||TO_CHAR(:old.capital)||'#'||TO_CHAR(:old.val_tasa);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_INICIO',:old.fec_inicio,:new.fec_inicio,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_ULT_DEVENGADO',:old.fec_ult_devengado,:new.fec_ult_devengado,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'CAN_DIA_INTERES',:old.can_dia_interes,:new.can_dia_interes,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'CAN_DIA_ANTERIOR',:old.can_dia_anterior,:new.can_dia_anterior,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_DEV_ANTERIOR',:old.mto_dev_anterior,:new.mto_dev_anterior,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_DEV_ACTUAL',:old.mto_dev_actual,:new.mto_dev_actual,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_AJUSTE',:old.mto_ajuste,:new.mto_ajuste,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_DEV_ACUMULADO',:old.mto_dev_acumulado,:new.mto_dev_acumulado,'M');
   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

