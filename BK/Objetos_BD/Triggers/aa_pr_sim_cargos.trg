CREATE OR REPLACE TRIGGER IT.AA_PR_SIM_CARGOS
 AFTER DELETE OR UPDATE
 ON PR_SIM_CARGOS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SIM_CARGOS';
   r_paudi.clave := to_char(:old.nro_simulacion)||'#'||to_char(:old.cod_transaccion);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_ENT_SEGURO',:old.cod_ent_seguro,:new.cod_ent_seguro,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_TASA',:old.cod_tasa,:new.cod_tasa,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'MTO_EQUIVALENTE',:old.mto_equivalente,:new.mto_equivalente,'M');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');

   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

