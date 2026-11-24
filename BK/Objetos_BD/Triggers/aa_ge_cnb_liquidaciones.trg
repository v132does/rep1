CREATE OR REPLACE TRIGGER IT.AA_GE_CNB_LIQUIDACIONES
 AFTER DELETE OR UPDATE
 ON it.GE_CNB_LIQUIDACIONES
 FOR EACH ROW

DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_CNB_LIQUIDACIONES';
   r_eaudi.clave := :old.nro_operacion||'#'||:old.nro_transaccion;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_ENTE',:old.cod_ente,:new.cod_ente);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_OPERACION',:old.nro_operacion,:new.nro_operacion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_TRANSACCION',:old.nro_transaccion,:new.nro_transaccion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_LIQUIDAR',:old.mto_liquidar,:new.mto_liquidar);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_TOTAL',:old.mto_total,:new.mto_total);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MOT_ERROR',:old.mot_error,:new.mot_error);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIP_OPE',:old.tip_ope,:new.tip_ope);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_PROCESO',:old.fec_proceso,:new.fec_proceso);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/

