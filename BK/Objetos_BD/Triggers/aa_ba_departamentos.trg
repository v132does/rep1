CREATE OR REPLACE TRIGGER IT.AA_BA_DEPARTAMENTOS
 AFTER DELETE OR UPDATE
 ON BA_DEPARTAMENTOS
 FOR EACH ROW


DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_DEPARTAMENTOS';
   r_eaudi.clave := to_char(:old.cod_departamento);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
   r_eaudi.detalle := r_eaudi.detalle || pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'REF_BCO_CENTRAL',:old.ref_bco_central,:new.ref_bco_central);

   --- Insertar tabla de auditoria
   pae_cnf.pr_ins_ba_auditoria(r_eaudi);
END;
/

