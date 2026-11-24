CREATE OR REPLACE TRIGGER IT."AA_GE_CUO_SEGUROS"
 AFTER DELETE OR UPDATE
 ON GE_CUO_SEGUROS
 FOR EACH ROW
DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_CUO_SEGUROS';
   r_eaudi.clave := :old.nro_seguro;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_ULT_PAGO',:old.fec_ult_pago,:new.fec_ult_pago);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/

