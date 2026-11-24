CREATE OR REPLACE TRIGGER IT.AA_PR_CUOTAS
 AFTER DELETE OR UPDATE OF MTO_INTERES
, FEC_VENCIMIENTO
, MTO_CAPITAL
, NRO_DOCUMENTO
, MTO_INT_DOCUMENTADO
, NRO_CUENTA
, NRO_CUOTA
, ESTADO --DYDMR-1943-ITGF-Problemas con el registro de Auditorias de Cuotas SC 17036-EGC-17/06/2015
 ON PR_CUOTAS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_CUOTAS';
   r_paudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_cuota);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_CAPITAL',:old.mto_capital,:new.mto_capital,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_CAPITAL',:old.sal_capital,:new.sal_capital,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_INTERES',:old.sal_interes,:new.sal_interes,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PRIORIDAD',:old.prioridad,:new.prioridad);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_ULT_PAGO',:old.fec_ult_pago,:new.fec_ult_pago,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_RECARGO',:old.val_recargo,:new.val_recargo,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_INT_DOCUMENTADO',:old.mto_int_documentado,:new.mto_int_documentado,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'NRO_DOCUMENTO',:old.nro_documento,:new.nro_documento,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_INT_DOCUMENTADO',:old.sal_int_documentado,:new.sal_int_documentado,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DEV_NO_COBRADO',:old.dev_no_cobrado,:new.dev_no_cobrado,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DEV_SUSPENSO',:old.dev_suspenso,:new.dev_suspenso,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'DEV_ACUMULADO',:old.dev_acumulado,:new.dev_acumulado,'M');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

