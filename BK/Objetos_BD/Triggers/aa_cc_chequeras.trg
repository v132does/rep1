CREATE OR REPLACE TRIGGER IT.AA_CC_CHEQUERAS
 AFTER DELETE OR UPDATE
 ON CC_CHEQUERAS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHEQUERAS';
   r_caudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_che_inicial);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'SERIE',:old.serie,:new.serie);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'NRO_CHE_FINAL',:old.nro_che_final,:new.nro_che_final,'M');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'CAN_CHEQUES',:old.can_cheques,:new.can_cheques,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_CAM_ESTADO',:old.fec_cam_estado,:new.fec_cam_estado,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'ULT_CHE_EMITIDO',:old.ult_che_emitido,:new.ult_che_emitido,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_SOLICITUD',:old.fec_solicitud,:new.fec_solicitud,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'HOR_SOLICITUD',:old.hor_solicitud,:new.hor_solicitud);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_OFI_RETIRO',:old.cod_ofi_retiro,:new.cod_ofi_retiro,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_GRU_ENVIO',:old.cod_gru_envio,:new.cod_gru_envio,'N');

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
END;
/

