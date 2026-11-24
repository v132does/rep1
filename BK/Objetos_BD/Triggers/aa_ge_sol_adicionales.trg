CREATE OR REPLACE TRIGGER IT.AA_GE_SOL_ADICIONALES
 AFTER DELETE OR UPDATE
 ON GE_SOL_ADICIONALES
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_SOL_ADICIONALES';
   r_gaudi.clave := to_char(:old.nro_solicitud)||'#'||:old.cod_persona;
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NOM_EMBOZADO',:old.nom_embozado,:new.nom_embozado);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

