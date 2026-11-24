CREATE OR REPLACE TRIGGER IT.AA_PR_SOL_CUOTAS
 AFTER DELETE OR UPDATE
 ON PR_SOL_CUOTAS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SOL_CUOTAS';
   r_paudi.clave := to_char(:old.nro_solicitud)||'#'||to_char(:old.nro_cuota);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_CAPITAL',:old.mto_capital,:new.mto_capital,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_VTO_HABIL',:old.fec_vto_habil,:new.fec_vto_habil,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_VTO_EXACTO',:old.fec_vto_exacto,:new.fec_vto_exacto,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_INTERES',:old.val_interes,:new.val_interes,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_CAPITAL',:old.sal_capital,:new.sal_capital,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_CAP_ANTERIOR',:old.sal_cap_anterior,:new.sal_cap_anterior,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DIA_PERIODO',:old.dia_periodo,:new.dia_periodo,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DIA_TRANSCURRIDOS',:old.dia_transcurridos,:new.dia_transcurridos,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DIA_INTERES',:old.dia_interes,:new.dia_interes,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_CALCULO',:old.tip_calculo,:new.tip_calculo);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_INT_ORIGINAL',:old.val_int_original,:new.val_int_original,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_INT_ADELANTADO',:old.val_int_adelantado,:new.val_int_adelantado,'M');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

