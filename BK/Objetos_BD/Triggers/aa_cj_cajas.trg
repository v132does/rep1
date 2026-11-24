CREATE OR REPLACE TRIGGER IT.AA_CJ_CAJAS
 AFTER DELETE OR UPDATE
 ON CJ_CAJAS
 FOR EACH ROW


DECLARE
r_jaudi cj_auditorias%rowtype; -- Registro de la tabla CJ_AUDITORIAS
BEGIN
   r_jaudi.tabla := 'CJ_CAJAS';
   r_jaudi.clave := to_char(:old.nro_caja);
   r_jaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_jaudi.tip_novedad := 'M';
   elsif deleting then
      r_jaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_jaudi.detalle := pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'COD_OFICINA',:old.cod_oficina,:new.cod_oficina,'N');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'COD_USU_RESPONSABLE',:old.cod_usu_responsable,:new.cod_usu_responsable);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'COD_USU_AUTORIZADOR',:old.cod_usu_autorizador,:new.cod_usu_autorizador);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'TIPO',:old.tipo,:new.tipo);
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'FEC_HOR_CIERRE',:old.fec_hor_cierre,:new.fec_hor_cierre,'F');
   r_jaudi.detalle := r_jaudi.detalle||pae_cnf.fu_reg_auditoria(r_jaudi.tip_novedad,'MTO_ASEGURADO',:old.mto_asegurado,:new.mto_asegurado,'M');

   --- Insertar tabla de auditoria
   PRJ_INS_CJ_AUDITORIA(r_jaudi);
END;
/

