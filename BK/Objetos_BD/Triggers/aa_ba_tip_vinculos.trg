CREATE OR REPLACE TRIGGER IT.AA_BA_TIP_VINCULOS
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_TIP_VINCULOS
 FOR EACH ROW
DECLARE
r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_TIP_VINCULOS';
   r_eaudi.clave := :old.cod_tip_vinculo;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIP_PERSONA',:old.tip_persona,:new.tip_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'VEN_OBLIGATORIO',:old.ven_obligatorio,:new.ven_obligatorio);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/

