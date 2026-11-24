CREATE OR REPLACE TRIGGER IT.AA_CB_DOC_ELEC_CAB
 AFTER DELETE OR UPDATE
 ON CB_DOC_ELEC_CAB
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'CB_DOC_ELEC_CAB';
   r_gaudi.clave := to_char(:old.ID_DOCUMENTO);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DEST',:old.DEST,:new.DEST);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DPUNEXP',:old.DPUNEXP,:new.DPUNEXP);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DNUMDOC',:old.DNUMDOC,:new.DNUMDOC);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DFEEMIDE',:old.DFEEMIDE,:new.DFEEMIDE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DNUMTIM',:old.DNUMTIM,:new.DNUMTIM);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'CMONEOPE',:old.CMONEOPE,:new.CMONEOPE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDESMONEOPE',:old.DDESMONEOPE,:new.DDESMONEOPE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DRUCREC',:old.DRUCREC,:new.DRUCREC);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDVREC',:old.DDVREC,:new.DDVREC);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DNOMREC',:old.DNOMREC,:new.DNOMREC);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DNOMFANREC',:old.DNOMFANREC,:new.DNOMFANREC);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDIRREC',:old.DDIRREC,:new.DDIRREC);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTGRALOPE',:old.DTOTGRALOPE,:new.DTOTGRALOPE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIVA5',:old.DIVA5,:new.DIVA5);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIVA10',:old.DIVA10,:new.DIVA10);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DLIQTOTIVA5',:old.DLIQTOTIVA5,:new.DLIQTOTIVA5);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DLIQTOTIVA10',:old.DLIQTOTIVA10,:new.DLIQTOTIVA10);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DIVACOMI',:old.DIVACOMI,:new.DIVACOMI);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTIVA',:old.DTOTIVA,:new.DTOTIVA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DBASEGRAV5',:old.DBASEGRAV5,:new.DBASEGRAV5);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DBASEGRAV10',:old.DBASEGRAV10,:new.DBASEGRAV10);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTBASGRAIVA',:old.DTBASGRAIVA,:new.DTBASGRAIVA);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTALGS',:old.DTOTALGS,:new.DTOTALGS);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DSUBEXE',:old.DSUBEXE,:new.DSUBEXE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DSUBEXO',:old.DSUBEXO,:new.DSUBEXO);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DSUB5',:old.DSUB5,:new.DSUB5);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DSUB10',:old.DSUB10,:new.DSUB10);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTOPE',:old.DTOTOPE,:new.DTOTOPE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DTOTDESC',:old.DTOTDESC,:new.DTOTDESC);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ICONDOPE',:old.ICONDOPE,:new.ICONDOPE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DDCONDOPE',:old.DDCONDOPE,:new.DDCONDOPE);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DCODCLIENTE',:old.DCODCLIENTE,:new.DCODCLIENTE);
   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

