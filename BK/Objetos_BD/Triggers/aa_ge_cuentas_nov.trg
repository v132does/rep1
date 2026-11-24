CREATE OR REPLACE TRIGGER IT.AA_GE_CUENTAS_NOV
 AFTER DELETE OR UPDATE
 ON GE_CUENTAS_NOV
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CUENTAS_NOV';
   r_gaudi.clave := :old.cod_usuario||'#'||to_char(:old.fecha,'ddmmrrrr')||'#'||
   :old.hora||'#'||:old.nro_cuenta||'#'||to_char(:old.nro_detalle);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EST_ANTERIOR',:old.est_anterior,:new.est_anterior);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EST_ACTUAL',:old.est_actual,:new.est_actual);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_CAM_EST_ANT',:old.fec_cam_est_ant,:new.fec_cam_est_ant,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ULT_MOV_ANT',:old.fec_ult_mov_ant,:new.fec_ult_mov_ant,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HOR_ULT_MOV_ANT',:old.hor_ult_mov_ant,:new.hor_ult_mov_ant);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ULT_CAP_ANT',:old.fec_ult_cap_ant,:new.fec_ult_cap_ant,'F');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

