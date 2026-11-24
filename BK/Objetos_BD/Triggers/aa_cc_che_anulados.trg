CREATE OR REPLACE TRIGGER IT.AA_CC_CHE_ANULADOS
 AFTER DELETE OR UPDATE
 ON CC_CHE_ANULADOS
 FOR EACH ROW


DECLARE
r_caudi cc_auditorias%rowtype; -- Registro de la tabla CC_AUDITORIAS
BEGIN
   r_caudi.tabla := 'CC_CHE_ANULADOS';
   r_caudi.clave := :old.nro_cuenta||'#'||to_char(:old.nro_cheque);
   r_caudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_caudi.tip_novedad := 'M';
   elsif deleting then
      r_caudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_caudi.detalle := pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FECHA',:old.fecha,:new.fecha,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'HORA',:old.hora,:new.hora);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'FEC_HOR_DESTRUCCION',:old.fec_hor_destruccion,:new.fec_hor_destruccion,'F');
    r_caudi.detalle := r_caudi.detalle||pae_cnf.fu_reg_auditoria(r_caudi.tip_novedad,'COD_USU_DESTRUCCION',:old.cod_usu_destruccion,:new.cod_usu_destruccion);

   --- Insertar tabla de auditoria
   PRC_INS_CC_AUDITORIA(r_caudi);
EXCEPTION
   WHEN OTHERS THEN   
     PRC_INS_CC_AUDITORIA(r_caudi);

END;
/

