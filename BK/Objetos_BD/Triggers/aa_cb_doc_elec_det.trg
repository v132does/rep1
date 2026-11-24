CREATE OR REPLACE TRIGGER IT.AA_CB_DOC_ELEC_DET
 AFTER DELETE OR UPDATE
 ON CB_DOC_ELEC_DET
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'CB_DOC_ELEC_DET';
   r_gaudi.clave := to_char(:old.DE_ID);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_ITEM',:old.NRO_ITEM,:new.NRO_ITEM);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DLIQIVAITEM',:old.DLIQIVAITEM,:new.DLIQIVAITEM);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTOPEITEM',:old.DTOTOPEITEM,:new.DTOTOPEITEM);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTOPEGS',:old.DTOTOPEGS,:new.DTOTOPEGS);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'IAFECIVA',:old.IAFECIVA,:new.IAFECIVA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDESAFECIVA',:old.DDESAFECIVA,:new.DDESAFECIVA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DPROPIVA',:old.DPROPIVA,:new.DPROPIVA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTASAIVA',:old.DTASAIVA,:new.DTASAIVA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DBASGRAVIVA',:old.DBASGRAVIVA,:new.DBASGRAVIVA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DCODINT',:old.DCODINT,:new.DCODINT);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDESPROSER',:old.DDESPROSER,:new.DDESPROSER);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CUNIMED',:old.CUNIMED,:new.CUNIMED);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDESUNIMED',:old.DDESUNIMED,:new.DDESUNIMED);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DCANTPROSER',:old.DCANTPROSER,:new.DCANTPROSER);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DPUNIPROSER',:old.DPUNIPROSER,:new.DPUNIPROSER);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTICAMIT',:old.DTICAMIT,:new.DTICAMIT);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTBRUOPEITEM',:old.DTOTBRUOPEITEM,:new.DTOTBRUOPEITEM);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDESCITEM',:old.DDESCITEM,:new.DDESCITEM);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DPORCDESIT',:old.DPORCDESIT,:new.DPORCDESIT);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDESCGLOITEM',:old.DDESCGLOITEM,:new.DDESCGLOITEM);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

