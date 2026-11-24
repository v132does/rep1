CREATE OR REPLACE TRIGGER IT.AA_PR_SIM_CUOTAS
 AFTER DELETE OR UPDATE
 ON PR_SIM_CUOTAS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SIM_CUOTAS';
   r_paudi.clave := to_char(:old.nro_simulacion)||'#'||to_char(:old.nro_cuota);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PER_DIAS',:old.per_dias,:new.per_dias,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_ANTERIOR',:old.sal_anterior,:new.sal_anterior,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_CAPITAL',:old.mto_capital,:new.mto_capital,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_REFUERZO',:old.mto_refuerzo,:new.mto_refuerzo,'M');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

