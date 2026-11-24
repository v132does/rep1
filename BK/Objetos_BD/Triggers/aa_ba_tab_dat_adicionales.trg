CREATE OR REPLACE TRIGGER IT.AA_BA_TAB_DAT_ADICIONALES
  AFTER DELETE OR UPDATE
     ON BA_TAB_DAT_ADICIONALES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 20/05/2014 a las 14:49:35 Hs.
  */
  v_registro BA_AUDITORIAS%ROWTYPE; -- Registro de la tabla BA_AUDITORIAS
BEGIN
  v_registro.tabla := 'BA_TAB_DAT_ADICIONALES';
  v_registro.clave := :old.tab_relacion || '#' || :old.parametro || '#' || :old.referencia;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_PARAMETRO', :old.val_parametro, :new.val_parametro );

  -- Insertar tabla de auditoria
  pae_cnf.pr_ins_ba_auditoria( v_registro );
EXCEPTION
  when others then
    pae_cnf.pr_ins_ba_auditoria( v_registro );
END;
/

