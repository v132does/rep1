CREATE OR REPLACE TRIGGER IT.AA_AH_DEVENGADOS
 AFTER DELETE OR UPDATE
 ON AH_DEVENGADOS
 FOR EACH ROW


DECLARE
r_aaudi ah_auditorias%rowtype; -- Registro de la tabla AH_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_DEVENGADOS';
   r_aaudi.clave := :old.nro_cuenta||'#'||to_char(:old.fec_inicio,'ddmmrrrr');
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
end if;

   --- Registrar Detalle
    r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_TASA',:old.fec_tasa,:new.fec_tasa,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'CAN_DIA_INTERES',:old.can_dia_interes,:new.can_dia_interes,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_ACUMULADO',:old.sal_acumulado,:new.sal_acumulado,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'DIA_DEV_ANTERIOR',:old.dia_dev_anterior,:new.dia_dev_anterior,'N');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_DEV_ANTERIOR',:old.mto_dev_anterior,:new.mto_dev_anterior,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_DEV_ACUMULADO',:old.mto_dev_acumulado,:new.mto_dev_acumulado,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_AJUSTE',:old.mto_ajuste,:new.mto_ajuste,'M');

   --- Insertar tabla de auditoria
   PRA_INS_AH_AUDITORIA(r_aaudi);
END;
/

