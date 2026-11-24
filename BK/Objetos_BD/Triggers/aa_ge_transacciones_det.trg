CREATE OR REPLACE TRIGGER IT.AA_GE_TRANSACCIONES_DET
 AFTER DELETE OR UPDATE
 ON GE_TRANSACCIONES_DET
 FOR EACH ROW

DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'GE_TRANSACCIONES_DET';
   r_eaudi.clave := to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||to_char(:old.cod_transaccion)||'#'||
                    to_char(:old.cod_mod_hijo)||'#'||to_char(:old.cod_mad_hijo)||'#'||to_char(:old.cod_tra_hijo);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_TRA_HIJO',:old.cod_tra_hijo,:new.cod_tra_hijo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MOD_HIJO',:old.cod_mod_hijo,:new.cod_mod_hijo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MAD_HIJO',:old.cod_mad_hijo,:new.cod_mad_hijo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_ORDEN',:old.nro_orden,:new.nro_orden,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OBLIGATORIO',:old.obligatorio,:new.obligatorio);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/

