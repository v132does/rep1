CREATE OR REPLACE TRIGGER IT.AA_GE_PER_INFORMES
 AFTER DELETE OR UPDATE
 ON GE_PER_INFORMES
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_PER_INFORMES';
   r_gaudi.clave := :old.cod_persona||'#'||to_char(:old.fecha,'ddmmrrrr');
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DEMANDA',:old.demanda,:new.demanda);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_INI_DEMANDA',:old.fec_ini_demanda,:new.fec_ini_demanda,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_FIN_DEMANDA',:old.fec_fin_demanda,:new.fec_fin_demanda,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'INHIBICION',:old.inhibicion,:new.inhibicion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_INHIBICION',:old.fec_inhibicion,:new.fec_inhibicion,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'INH_CTACTE',:old.inh_ctacte,:new.inh_ctacte);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CONVOCATORIA',:old.convocatoria,:new.convocatoria);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_FIN_CONVOCATORIA',:old.fec_fin_convocatoria,:new.fec_fin_convocatoria,'F');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'REMATE',:old.remate,:new.remate);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MOROSO',:old.moroso,:new.moroso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'INF_ADICIONAL',:old.inf_adicional,:new.inf_adicional);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

