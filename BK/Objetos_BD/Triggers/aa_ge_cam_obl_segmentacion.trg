CREATE OR REPLACE TRIGGER IT."AA_GE_CAM_OBL_SEGMENTACION"
 AFTER DELETE OR UPDATE
 ON GE_CAM_OBL_SEGMENTACION
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CAM_OBL_SEGMENTACION';
   r_gaudi.clave := to_char(:old.cod_rub_primario);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_TIP_ACTIVIDAD',:old.cod_tip_actividad,:new.cod_tip_actividad);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MANDATORIO',:old.mandatorio,:new.mandatorio);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'PLZ_VIGENCIA',:old.plz_vigencia,:new.plz_vigencia);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

