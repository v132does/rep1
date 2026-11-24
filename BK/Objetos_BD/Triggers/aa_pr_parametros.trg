CREATE OR REPLACE TRIGGER IT.AA_PR_PARAMETROS
 AFTER DELETE OR UPDATE
 ON PR_PARAMETROS
 FOR EACH ROW

DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_PARAMETROS';
   r_paudi.clave := :old.por_riesgo_1a;
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_RIESGO_1A',:old.por_riesgo_1a,:new.por_riesgo_1a,'N');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_RIESGO_1B',:old.por_riesgo_1b,:new.por_riesgo_1b,'N');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_RIESGO_2',:old.por_riesgo_2,:new.por_riesgo_2,'N');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_RIESGO_3',:old.por_riesgo_3,:new.por_riesgo_3,'N');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_RIESGO_4',:old.por_riesgo_4,:new.por_riesgo_4,'N');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_RIESGO_5',:old.por_riesgo_5,:new.por_riesgo_5,'N');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'POR_RIESGO_6',:old.por_riesgo_6,:new.por_riesgo_6,'N');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'SAL_MIN_VIGENTE',:old.sal_min_vigente,:new.sal_min_vigente,'M');
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'CAP_MIN_EXIGIDO',:old.cap_min_exigido,:new.cap_min_exigido,'M');
   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

