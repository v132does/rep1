CREATE OR REPLACE TRIGGER IT.AA_CB_RUB_AREAS
  AFTER DELETE OR UPDATE
     ON CB_RUB_AREAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 03/05/2013 a las 17:20:13 Hs.
  */
  r_baudi CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  r_baudi.tabla := 'CB_RUB_AREAS';
  r_baudi.clave := to_char( :old.cod_area);
  r_baudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_baudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_baudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_baudi.detalle := pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'SEC_CAPITULO', :old.sec_capitulo, :new.sec_capitulo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IND_SEC_CAPITULO', :old.ind_sec_capitulo, :new.ind_sec_capitulo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'MOD_INF_RUBRO', :old.mod_inf_rubro, :new.mod_inf_rubro );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IND_MOD_INF_RUBRO', :old.ind_mod_inf_rubro, :new.ind_mod_inf_rubro );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'PLAZO', :old.plazo, :new.plazo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IND_PLAZO', :old.ind_plazo, :new.ind_plazo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'SEC_PRESTAMO', :old.sec_prestamo, :new.sec_prestamo );
  r_baudi.detalle := r_baudi.detalle || pae_cnf.fu_reg_auditoria( r_baudi.tip_novedad, 'IND_SEC_PRESTAMO', :old.ind_sec_prestamo, :new.ind_sec_prestamo );

  -- Insertar tabla de auditoria
  prb_ins_cb_auditoria( r_baudi );
EXCEPTION
  when others then
    prb_ins_cb_auditoria( r_baudi );
END;
/

