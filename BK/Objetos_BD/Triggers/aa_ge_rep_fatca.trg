CREATE OR REPLACE TRIGGER IT."aa_ge_rep_fatca"
  AFTER DELETE OR UPDATE
     ON ge_rep_fatca
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2015 - IT Consultores
  || Generado el 03/02/2015
  */
  r_gaudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_REP_FATCA';
  r_gaudi.clave :=  :old.cod_persona;

  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'NRO_REF_LOTE', :old.nro_ref_lote, :new.nro_ref_lote );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona);
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PAI_DESTINO', :old.pai_destino, :new.pai_destino, 'F');
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PAI_ORIGEN', :old.pai_origen, :new.pai_origen );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PER_REPORTE', :old.per_reporte, :new.per_reporte );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'PRO_SUSTANCIAL', :old.pro_sustancial, :new.pro_sustancial );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'SAL_CUENTA', :old.sal_cuenta, :new.sal_cuenta );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_GENERACION', :old.ind_generacion, :new.ind_generacion );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_GENERADO', :old.ind_generado, :new.ind_generado );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( r_gaudi );
  
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( r_gaudi );
END;
/

