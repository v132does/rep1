CREATE OR REPLACE TRIGGER IT.AA_PR_GRU_LIN_TIP_GAR_MAD
  AFTER DELETE OR UPDATE
     ON PR_GRU_LIN_TIP_GAR_MAD
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 30/08/2005 a las 18:18:00 Hs.
  */
  v_registro PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  v_registro.tabla := 'PR_GRU_LIN_TIP_GAR_MAD';
  v_registro.clave := to_char( :old.nro_linea) || '#' || to_char( :old.cod_garantia)||'#'||to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_LIMITE', :old.mto_limite, :new.mto_limite, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_APLICADO', :old.mto_aplicado, :new.mto_aplicado, 'M' );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( v_registro );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( v_registro );
END;
/

