CREATE OR REPLACE TRIGGER IT.AA_GE_PAR_FATCA
  AFTER DELETE OR UPDATE
     ON GE_PAR_FATCA
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 24/04/2014 a las 11:19:00 Hs.
  */
  r_gaudi BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  r_gaudi.tabla := 'GE_PAR_FATCA';
  r_gaudi.clave :=  :old.est_nuevo;

  r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_gaudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_gaudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'EST_NUEVO', :old.est_nuevo, :new.est_nuevo );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'EST_ANTERIOR', :old.est_anterior, :new.est_anterior );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TIP_INDICIO', :old.tip_indicio, :new.tip_indicio );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_SEC_CONTABLE', :old.cod_sec_contable, :new.cod_sec_contable );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_NRO_IDENTIFICADOR', :old.ind_nro_identificador, :new.ind_nro_identificador );
  r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'IND_NOMINA', :old.ind_nomina, :new.ind_nomina );  


  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( r_gaudi );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( r_gaudi );
END;
/

