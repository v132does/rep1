CREATE OR REPLACE TRIGGER IT.AA_CB_SAL_CONSOLIDADOS
 AFTER DELETE
 ON CB_SAL_CONSOLIDADOS
 FOR EACH ROW


DECLARE
r_baudi cb_auditorias%rowtype; -- Registro de la tabla CB_AUDITORIAS
BEGIN
   r_baudi.tabla := 'CB_SAL_CONSOLIDADOS';
   r_baudi.clave := :old.cod_rubro||'#'||to_char(:old.ano)||'#'||to_char(:old.mes);
   r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_baudi.tip_novedad := 'M';
   elsif deleting then
      r_baudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_baudi.detalle := pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_MON_LOC_ANT',:old.sal_mon_loc_ant,:new.sal_mon_loc_ant,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DEB_MON_LOCAL',:old.deb_mon_local,:new.deb_mon_local,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'CRE_MON_LOCAL',:old.cre_mon_local,:new.cre_mon_local,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_INI_MES_MON_LOCAL',:old.sal_ini_mes_mon_local,:new.sal_ini_mes_mon_local,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_MON_RUB_ANT',:old.sal_mon_rub_ant,:new.sal_mon_rub_ant,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'DEB_MON_RUBRO',:old.deb_mon_rubro,:new.deb_mon_rubro,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'CRE_MON_RUBRO',:old.cre_mon_rubro,:new.cre_mon_rubro,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'SAL_INI_MES_MON_RUBRO',:old.sal_ini_mes_mon_rubro,:new.sal_ini_mes_mon_rubro,'M');
    r_baudi.detalle := r_baudi.detalle||pae_cnf.fu_reg_auditoria(r_baudi.tip_novedad,'PROTEGIDO',:old.protegido,:new.protegido);

   --- Insertar tabla de auditoria
   IF nvl(pae_cnf.G_PROGRAMA,'X') <> 'GPPROFIN' THEN
      PRB_INS_CB_AUDITORIA(r_baudi);
   END IF;
END;
/

