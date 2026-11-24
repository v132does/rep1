CREATE OR REPLACE TRIGGER IT.AA_AP_REQ_CAMBIOS
 AFTER DELETE OR UPDATE
 ON AP_REQ_CAMBIOS
 FOR EACH ROW


DECLARE
     r_eaudi ap_auditorias%rowtype; -- Registro de la tabla AP_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'AP_REQ_CAMBIOS';
   r_eaudi.clave := to_char(:old.cod_requerimiento)||to_char(:old.cod_cambio);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';

   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USU_SUPERVISOR',:old.cod_usu_supervisor,:new.cod_usu_supervisor);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha, 'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DES_JUS_CAMBIO',:old.des_jus_cambio,:new.des_jus_cambio);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
   --- Insertar tabla de auditoria
  PRY_INS_AP_AUDITORIA(r_eaudi);
END;
/

