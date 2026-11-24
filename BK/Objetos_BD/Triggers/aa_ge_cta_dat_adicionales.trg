CREATE OR REPLACE TRIGGER IT.AA_GE_CTA_DAT_ADICIONALES
 AFTER DELETE OR UPDATE
 ON GE_CTA_DAT_ADICIONALES
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CTA_DAT_ADICIONALES';
   r_gaudi.clave := :old.nro_cuenta||'#'||:old.parametro;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_PARAMETRO',:old.val_parametro,:new.val_parametro);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

