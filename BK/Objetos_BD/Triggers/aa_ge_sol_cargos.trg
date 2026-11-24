CREATE OR REPLACE TRIGGER IT.AA_GE_SOL_CARGOS
 AFTER DELETE OR UPDATE
 ON GE_SOL_CARGOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SOL_CARGOS';
   r_gaudi.clave := to_char(:old.cod_canal)||'#'||to_char(:old.cod_campana)||'#'||
   to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||
   to_char(:old.cod_transaccion)||'#'||to_char(:old.cod_ent_seguro)||'#'||
   to_char(:old.cod_tip_canal);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_CANAL',:old.cod_canal,:new.cod_canal,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_CAMPANA',:old.cod_campana,:new.cod_campana,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_ENT_SEGURO',:old.cod_ent_seguro,:new.cod_ent_seguro,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TIP_CANAL',:old.cod_tip_canal,:new.cod_tip_canal,'N');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

