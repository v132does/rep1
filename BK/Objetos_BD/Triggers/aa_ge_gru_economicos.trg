CREATE OR REPLACE TRIGGER IT.AA_GE_GRU_ECONOMICOS
 AFTER DELETE OR UPDATE
 ON GE_GRU_ECONOMICOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_GRU_ECONOMICOS';
   r_gaudi.clave := to_char(:old.cod_gru_economico);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CAT_SUBJETIVA',:old.cat_subjetiva,:new.cat_subjetiva);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CAT_AUTOMATICA',:old.cat_automatica,:new.cat_automatica,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TOT_DEU_REAL',:old.tot_deu_real,:new.tot_deu_real,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TOT_DEU_CONTINGENTE',:old.tot_deu_contingente,:new.tot_deu_contingente,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TOT_PREVISION',:old.tot_prevision,:new.tot_prevision,'M');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TOT_GAR_COMPUTABLES',:old.tot_gar_computables,:new.tot_gar_computables,'M');

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

