CREATE OR REPLACE TRIGGER IT.AA_BA_REL_PROGRAMAS
 AFTER DELETE OR UPDATE
 ON BA_REL_PROGRAMAS
 FOR EACH ROW
DECLARE
 r_eaudi ba_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'BA_REL_PROGRAMAS';
   r_eaudi.clave := :old.cod_programa||'#'||:old.cod_pro_relacionado;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PROGRAMA',:old.cod_programa,:new.cod_programa);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PRO_RELACIONADO',:old.cod_pro_relacionado,:new.cod_pro_relacionado);

   --- Insertar tabla de auditoria
   PAE_CNF.PR_INS_BA_AUDITORIA(r_eaudi);
END;
/

