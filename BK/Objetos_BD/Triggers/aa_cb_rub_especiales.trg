CREATE OR REPLACE TRIGGER IT.AA_CB_RUB_ESPECIALES
 AFTER DELETE OR UPDATE
 ON CB_RUB_ESPECIALES
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_RUB_ESPECIALES';
   r_baudi.clave := :old.cod_rub_origen;
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUB_DESTINO',:old.cod_rub_destino,:new.cod_rub_destino);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'TIP_SALDO',:old.tip_saldo,:new.tip_saldo);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUB_TRA_ORIGEN',:old.cod_rub_tra_origen,:new.cod_rub_tra_origen);
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'COD_RUB_TRA_DESTINO',:old.cod_rub_tra_destino,:new.cod_rub_tra_destino);

   --- Insertar tabla de auditoria
   PRB_INS_CB_AUDITORIA(r_baudi);
END;
/

