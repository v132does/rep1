CREATE OR REPLACE TRIGGER IT.AA_BA_VINCULOS
 AFTER DELETE OR UPDATE
 ON BA_VINCULOS
 FOR EACH ROW
DECLARE
  r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_VINCULOS';
   r_eaudi.clave := :old.cod_persona||'#'||:old.cod_per_vinculo||'#'||:old.tipo;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'F');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERFIL',:old.cod_perfil,:new.cod_perfil);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ACTIVO',:old.activo,:new.activo);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/
