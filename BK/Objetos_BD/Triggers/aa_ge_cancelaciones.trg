CREATE OR REPLACE TRIGGER IT.AA_GE_CANCELACIONES
 AFTER DELETE OR UPDATE
 ON GE_CANCELACIONES
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CANCELACIONES';
   r_gaudi.clave := :old.nro_cuenta||'#'||to_char(:old.fec_hora,'ddmmrrrr');
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USUARIO',:old.cod_usuario,:new.cod_usuario);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBSERVACION',:old.observacion,:new.observacion);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

