CREATE OR REPLACE TRIGGER IT.AA_CB_DOC_ASOCIADO
 AFTER DELETE OR UPDATE
 ON CB_DOC_ASOCIADO
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'CB_DOC_ASOCIADO';
   r_gaudi.clave := to_char(:old.DE_ID);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'itipdocaso',:old.itipdocaso,:new.itipdocaso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ddestipdocaso',:old.ddestipdocaso,:new.ddestipdocaso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dcdcderef',:old.dcdcderef,:new.dcdcderef);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dntimdi',:old.dntimdi,:new.dntimdi);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'destdocaso',:old.destdocaso,:new.destdocaso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dpexpdocaso',:old.dpexpdocaso,:new.dpexpdocaso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dnumdocaso',:old.dnumdocaso,:new.dnumdocaso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'itipodocaso',:old.itipodocaso,:new.itipodocaso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ddtipodocaso',:old.ddtipodocaso,:new.ddtipodocaso);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dfecemidi',:old.dfecemidi,:new.dfecemidi);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dnumcomret',:old.dnumcomret,:new.dnumcomret);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dnumrescf',:old.dnumrescf,:new.dnumrescf);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'itipcons',:old.itipcons,:new.itipcons);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ddestipcons',:old.ddestipcons,:new.ddestipcons);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dnumcons',:old.dnumcons,:new.dnumcons);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'dnumcontrol',:old.dnumcontrol,:new.dnumcontrol);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

