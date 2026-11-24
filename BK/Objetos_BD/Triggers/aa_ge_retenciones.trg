CREATE OR REPLACE TRIGGER IT.AA_GE_RETENCIONES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_RETENCIONES
 FOR EACH ROW


DECLARE
r_gaudi pr_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_RETENCIONES';
   r_gaudi.clave := to_char(:old.cod_retencion);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

