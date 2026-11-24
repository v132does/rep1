CREATE OR REPLACE TRIGGER IT.AA_PR_RUB_ECONOMICOS
  AFTER DELETE OR UPDATE
     ON PR_RUB_ECONOMICOS
    FOR EACH ROW
DECLARE
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_RUB_ECONOMICOS';
  r_paudi.clave := :old.cod_rub_economico;
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'PREFERENCIAL', :old.preferencial, :new.preferencial );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_RUB_ECO_PADRE', :old.cod_rub_eco_padre, :new.cod_rub_eco_padre );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_BCO_CENTRAL', :old.cod_bco_central, :new.cod_bco_central );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'COD_SEC_RUBRO', :old.cod_sec_rubro, :new.cod_sec_rubro );
  r_paudi.detalle := r_paudi.detalle || pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia, 'N' );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

