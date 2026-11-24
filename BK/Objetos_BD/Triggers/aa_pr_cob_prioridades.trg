CREATE OR REPLACE TRIGGER IT.AA_PR_COB_PRIORIDADES
 AFTER DELETE OR INSERT OR UPDATE
 ON PR_COB_PRIORIDADES
 FOR EACH ROW


DECLARE
   r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_COB_PRIORIDADES';
   r_paudi.clave := to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||to_char(:old.secuencia);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'CONCEPTO',:old.concepto,:new.concepto);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'FUN_CALCULO',:old.fun_calculo,:new.fun_calculo);
   r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'ETIQUETA',:old.etiqueta,:new.etiqueta);

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

