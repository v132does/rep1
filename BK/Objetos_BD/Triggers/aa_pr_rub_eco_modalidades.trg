CREATE OR REPLACE TRIGGER IT.AA_PR_RUB_ECO_MODALIDADES
  AFTER DELETE OR UPDATE
     ON PR_RUB_ECO_MODALIDADES
    FOR EACH ROW
DECLARE
  r_paudi PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  r_paudi.tabla := 'PR_RUB_ECO_MODALIDADES';
  r_paudi.clave := to_char( :old.cod_modulo) || '#' || to_char( :old.cod_modalidad) || '#' || :old.cod_rub_economico;
  r_paudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_paudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_paudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_paudi.detalle := pae_cnf.fu_reg_auditoria( r_paudi.tip_novedad, 'REFERENCIA', :old.referencia, :new.referencia, 'N' );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( r_paudi );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( r_paudi );
END;
/

