CREATE OR REPLACE TRIGGER IT.AA_PR_PAR_RRR_OPERACIONES
  AFTER DELETE OR UPDATE
     ON PR_PAR_RRR_OPERACIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/10/2012 a las 15:19:40 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_PAR_RRR_OPERACIONES';
  r_paudi.clave := to_char( :old.codigo);
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FOR_PAG_OPE_ORIGINAL', :old.for_pag_ope_original, :new.for_pag_ope_original );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'DIA_ATR_HASTA', :old.dia_atr_hasta, :new.dia_atr_hasta, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'PAG_CAPITAL', :old.pag_capital, :new.pag_capital );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'FOR_PAG_OPE_RENOVADA', :old.for_pag_ope_renovada, :new.for_pag_ope_renovada );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'TIP_RENOVACION', :old.tip_renovacion, :new.tip_renovacion );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

