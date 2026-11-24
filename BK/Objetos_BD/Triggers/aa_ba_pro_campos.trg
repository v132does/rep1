CREATE OR REPLACE TRIGGER IT.AA_BA_PRO_CAMPOS
 AFTER DELETE OR UPDATE
 ON BA_PRO_CAMPOS
 FOR EACH ROW
DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_PRO_CAMPOS';
   r_eaudi.clave := :old.cod_programa||'#'||:old.cod_campo;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'REFERENCIA',:old.referencia,:new.referencia);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'VAL_DEFECTO',:old.val_defecto,:new.val_defecto);

   --- Insertar tabla de auditoria
   PAE_CNF.PR_INS_BA_AUDITORIA(r_eaudi);
END;
/

