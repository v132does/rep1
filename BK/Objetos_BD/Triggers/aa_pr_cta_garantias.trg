CREATE OR REPLACE TRIGGER IT.AA_PR_CTA_GARANTIAS
  AFTER DELETE OR UPDATE
     ON PR_CTA_GARANTIAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 23/05/2013 a las 11:26:48 Hs.
  */
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_CTA_GARANTIAS';
  r_paudi.clave := :old.nro_cuenta || '#' || to_char( :old.nro_garantia) || '#' || to_char( :old.cod_garantia);
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_APLICADO', :old.mto_aplicado, :new.mto_aplicado, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_CON_COMPUTABLE', :old.mto_con_computable, :new.mto_con_computable, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_APL_COMPUTABLE', :old.mto_apl_computable, :new.mto_apl_computable, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_CON_NOCOMPUTABLE', :old.mto_con_nocomputable, :new.mto_con_nocomputable, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'PORCENTAJE', :old.porcentaje, :new.porcentaje, 'N' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'MTO_RIESGO', :old.mto_riesgo, :new.mto_riesgo, 'M' );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'IND_PAGARE', :old.ind_pagare, :new.ind_pagare );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

