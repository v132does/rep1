CREATE OR REPLACE TRIGGER IT.AA_AP_REQ_APROBACIONES
 AFTER DELETE OR UPDATE
 ON AP_REQ_APROBACIONES
 FOR EACH ROW


DECLARE
r_eaudi ap_auditorias%rowtype; -- Registro de la tabla AP_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'AP_REQ_APROBACIONES';
   r_eaudi.clave := to_char(:old.cod_requerimiento)||to_char(:old.orden);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';

   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_GRUPO',:old.cod_grupo,:new.cod_grupo,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VERIFICACION',:old.fec_verificacion,:new.fec_verificacion,'H');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NOTA',:old.nota,:new.nota);
   --- Insertar tabla de auditoria
   PRY_INS_AP_AUDITORIA(r_eaudi);
END;
/

