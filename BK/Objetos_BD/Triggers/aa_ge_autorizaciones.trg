CREATE OR REPLACE TRIGGER IT.AA_GE_AUTORIZACIONES
 AFTER DELETE OR UPDATE
 ON GE_AUTORIZACIONES
 FOR EACH ROW

DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_AUTORIZACIONES';
   r_gaudi.clave := to_char(:old.cod_autorizacion);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HORA',:old.hora,:new.hora);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_SECUENCIA',:old.nro_secuencia,:new.nro_secuencia,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CUENTA',:old.nro_cuenta,:new.nro_cuenta);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRA_PADRE',:old.cod_tra_padre,:new.cod_tra_padre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MOD_PADRE',:old.cod_mod_padre,:new.cod_mod_padre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MAD_PADRE',:old.cod_mad_padre,:new.cod_mad_padre,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TRANSACCION',:old.cod_transaccion,:new.cod_transaccion,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODULO',:old.cod_modulo,:new.cod_modulo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MODALIDAD',:old.cod_modalidad,:new.cod_modalidad,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VALOR',:old.valor,:new.valor,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_UTILIZADOR',:old.cod_usu_utilizador,:new.cod_usu_utilizador);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_UTILIZACION',:old.fec_utilizacion,:new.fec_utilizacion,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'HOR_UTILIZACION',:old.hor_utilizacion,:new.hor_utilizacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'EXIMIDO',:old.eximido,:new.eximido);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_AUTORIZADOR',:old.cod_usu_autorizador,:new.cod_usu_autorizador);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

