CREATE OR REPLACE TRIGGER IT.AA_GE_CAM_OBLIGATORIOS
 AFTER DELETE OR UPDATE
 ON GE_CAM_OBLIGATORIOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CAM_OBLIGATORIOS';
   r_gaudi.clave := to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad)||'#'||:old.tabla||'#'||:old.campo;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MSJ_ERROR',:old.msj_error,:new.msj_error);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

