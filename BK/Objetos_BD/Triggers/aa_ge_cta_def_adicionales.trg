CREATE OR REPLACE TRIGGER IT.AA_GE_CTA_DEF_ADICIONALES
 AFTER DELETE OR UPDATE
 ON GE_CTA_DEF_ADICIONALES
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_CTA_DEF_ADICIONALES';
   r_gaudi.clave := :old.parametro||'#'||to_char(:old.cod_modulo)||'#'||
   to_char(:old.cod_modalidad)||'#'||to_char(:old.cod_oficina)||'#'||:old.cod_moneda||'#'||
   to_char(:old.cod_banca);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'OBLIGATORIO',:old.obligatorio,:new.obligatorio);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MODIFICABLE',:old.modificable,:new.modificable);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

