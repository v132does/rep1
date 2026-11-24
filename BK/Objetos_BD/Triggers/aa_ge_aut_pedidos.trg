CREATE OR REPLACE TRIGGER IT.AA_GE_AUT_PEDIDOS
 AFTER DELETE OR UPDATE
 ON GE_AUT_PEDIDOS
 FOR EACH ROW

DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_AUT_PEDIDOS';
   r_gaudi.clave := :old.cod_usuario||'#'||to_char(:old.fecha,'ddmmrrrr')||'#'||:old.hora;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_AUTORIZADOR',:old.cod_usu_autorizador,:new.cod_usu_autorizador);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'RESPUESTA',:old.respuesta,:new.respuesta);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

