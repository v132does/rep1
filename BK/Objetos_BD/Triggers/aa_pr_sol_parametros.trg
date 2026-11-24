CREATE OR REPLACE TRIGGER IT.AA_PR_SOL_PARAMETROS
 AFTER DELETE OR UPDATE
 ON PR_SOL_PARAMETROS
 FOR EACH ROW


DECLARE
r_paudi pr_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_paudi.tabla := 'PR_SOL_PARAMETROS';
   r_paudi.clave := to_char(:old.cod_canal)||'#'||to_char(:old.cod_campana)||'#'||
   to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad);
   r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_paudi.tip_novedad := 'M';
   elsif deleting then
      r_paudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_paudi.detalle := pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_INTERES',:old.tip_interes,:new.tip_interes);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_AMORTIZACION',:old.tip_amortizacion,:new.tip_amortizacion);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'AJU_ULT_CUOTA',:old.aju_ult_cuota,:new.aju_ult_cuota);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_AJU_FECHA',:old.tip_aju_fecha,:new.tip_aju_fecha);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_MONTO',:old.tip_monto,:new.tip_monto);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'AJU_GRACIA',:old.aju_gracia,:new.aju_gracia);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_SEC_CREDITO',:old.cod_sec_credito,:new.cod_sec_credito,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'COD_DEPARTAMENTO',:old.cod_departamento,:new.cod_departamento,'N');
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIP_DOCUMENTO',:old.tip_documento,:new.tip_documento);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
    r_paudi.detalle := r_paudi.detalle||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad,'VAL_TASA',:old.val_tasa,:new.val_tasa,'M');
    r_paudi.detalle := r_paudi.detalle ||pae_cnf.fu_reg_auditoria(r_paudi.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico);
   --- Insertar tabla de auditoria
   PRP_INS_PR_AUDITORIA(r_paudi);
END;
/

