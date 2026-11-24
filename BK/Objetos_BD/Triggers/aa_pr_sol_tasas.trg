CREATE OR REPLACE TRIGGER IT.AA_PR_SOL_TASAS
 AFTER DELETE OR UPDATE
 ON PR_SOL_TASAS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SOL_TASAS';
   r_paudi.clave := to_char(:old.nro_solicitud)||'#'||to_char(:old.fec_vigencia,'ddmmrrrr');
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_COBRO',:old.tip_cobro,:new.tip_cobro);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'PER_VENCIMIENTO',:old.per_vencimiento,:new.per_vencimiento,'N');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

