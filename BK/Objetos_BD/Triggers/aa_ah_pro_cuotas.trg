CREATE OR REPLACE TRIGGER IT.AA_AH_PRO_CUOTAS
 BEFORE DELETE OR UPDATE ON AH_PRO_CUOTAS
 FOR EACH ROW

DECLARE
   r_aaudi ah_auditorias%rowtype; -- Registro de la tabla PR_AUDITORIAS
BEGIN
   r_aaudi.tabla := 'AH_PRO_CUOTAS';
   r_aaudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_cuota);
   r_aaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_aaudi.tip_novedad := 'M';
   elsif deleting then
      r_aaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_aaudi.detalle := pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_CUOTA',:old.mto_cuota,:new.mto_cuota,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'MTO_INTERES',:old.mto_interes,:new.mto_interes,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'FEC_ULT_PAGO',:old.fec_ult_pago,:new.fec_ult_pago,'F');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'PERIODO',:old.periodo,:new.periodo);
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'SAL_ACUMULADO',:old.sal_acumulado,:new.sal_acumulado,'M');
    r_aaudi.detalle := r_aaudi.detalle||pae_cnf.fu_reg_auditoria(r_aaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
   
   --- Insertar tabla de auditoria
    PRA_INS_AH_AUDITORIA(r_aaudi);
EXCEPTION
   WHEN OTHERS THEN
     PRA_INS_AH_AUDITORIA(r_aaudi); -- para insertar hasta donde puede
END;
/
