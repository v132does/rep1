CREATE OR REPLACE TRIGGER IT.AA_BA_FERIADOS
 AFTER DELETE OR UPDATE
 ON BA_FERIADOS
 FOR EACH ROW


DECLARE
r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_FERIADOS';
   r_eaudi.clave := to_char(:old.fecha,'ddmmrrrr')||'#'||to_char(:old.cod_oficina);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MOTIVO',:old.motivo,:new.motivo);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/

