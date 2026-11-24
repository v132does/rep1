CREATE OR REPLACE TRIGGER IT.AA_GE_CORREOS
 AFTER DELETE OR UPDATE
 ON GE_CORREOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CORREOS';
   r_gaudi.clave := :old.cod_usu_envio||'#'||to_char(:old.fec_envio,'ddmmrrrr')||'#'||:old.hor_envio;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_DESTINO',:old.cod_usu_destino,:new.cod_usu_destino);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MENSAJE',:old.mensaje,:new.mensaje);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EST_MENSAJE',:old.est_mensaje,:new.est_mensaje);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EST_RESPUESTA',:old.est_respuesta,:new.est_respuesta);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MTO_OPERACION',:old.mto_operacion,:new.mto_operacion,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_RECEPCION',:old.fec_recepcion,:new.fec_recepcion,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HOR_RECEPCION',:old.hor_recepcion,:new.hor_recepcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'RESPUESTA',:old.respuesta,:new.respuesta);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

