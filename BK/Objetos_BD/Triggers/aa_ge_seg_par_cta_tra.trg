CREATE OR REPLACE TRIGGER IT.AA_GE_SEG_PAR_CTA_TRA
 AFTER DELETE OR UPDATE
 ON GE_SEG_PAR_CTA_TRA
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SEG_PAR_CTA_TRA';
   r_gaudi.clave := to_char(:old.cod_transaccion)||'#'||to_char(:old.cod_seg_cliente)
   ||'#'||to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||:old.cod_moneda;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MOD_TRANSACCION',:old.cod_mod_transaccion,:new.cod_mod_transaccion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MAD_TRANSACCION',:old.cod_mad_transaccion,:new.cod_mad_transaccion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SUB_MODALIDAD',:old.cod_sub_modalidad,:new.cod_sub_modalidad,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

