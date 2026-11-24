CREATE OR REPLACE TRIGGER IT.AA_TA_SAL_CIERRES
 AFTER DELETE OR UPDATE
 ON TA_SAL_CIERRES
 FOR EACH ROW


DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_SAL_CIERRES';
   r_taudi.clave := :old.nro_cuenta||'#'||to_char(:old.fec_cierre,'ddmmrrrr');
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'SAL_FINANCIADO',:old.sal_financiado,:new.sal_financiado,'M');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'SAL_FACTURADO',:old.sal_facturado,:new.sal_facturado,'M');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'SAL_FACTURAR',:old.sal_facturar,:new.sal_facturar,'M');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'LIN_CREDITO',:old.lin_credito,:new.lin_credito,'M');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'MTO_PAG_MINIMO',:old.mto_pag_minimo,:new.mto_pag_minimo,'M');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_VTO_PAGO',:old.fec_vto_pago,:new.fec_vto_pago,'F');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'LIN_CUOTAS',:old.lin_cuotas,:new.lin_cuotas,'M');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'SAL_CUO_PENDIENTES',:old.sal_cuo_pendientes,:new.sal_cuo_pendientes,'M');

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/

