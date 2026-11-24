CREATE OR REPLACE TRIGGER IT.AA_GE_SEP_TRANSACCIONES
 AFTER DELETE OR UPDATE OR INSERT
 ON GE_SEP_TRANSACCIONES
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   elsif inserting then
      r_gaudi.tip_novedad := 'I';
   end if;
   
   r_gaudi.tabla := 'GE_SEP_TRANSACCIONES';
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   
   if r_gaudi.tip_novedad in ('M','E') then
      r_gaudi.clave := to_char(:old.cod_tra_padre)||'#'||to_char(:old.cod_transaccion)||'#'||to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad);
   else
      r_gaudi.clave := to_char(:new.cod_tra_padre)||'#'||to_char(:new.cod_transaccion)||'#'||to_char(:new.cod_modulo)||'#'||to_char(:new.cod_modalidad);
   end if;
   
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'REF_ARCHIVO',:old.ref_archivo,:new.ref_archivo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'REF_DAT_REPORTAR',:old.ref_dat_reportar,:new.ref_dat_reportar);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRA_PADRE',:old.cod_tra_padre,:new.cod_tra_padre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MOD_PADRE',:old.cod_mod_padre,:new.cod_mod_padre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MAD_PADRE',:old.cod_mad_padre,:new.cod_mad_padre,'N');   
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');   
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_REPORTAR',:old.mto_reportar,:new.mto_reportar,'N');
   
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

