CREATE OR REPLACE TRIGGER IT.AA_CB_PAR_PRV_GENERICAS
  AFTER DELETE OR UPDATE
     ON CB_PAR_PRV_GENERICAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  */
  v_registro CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  v_registro.tabla := 'CB_PAR_PRV_GENERICAS';
  v_registro.clave := :old.TIP_RIESGO || '#' || :old.sec_riesgo || '#' || :old.sec_inversion;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_GRU_RUBRO', :old.COD_GRU_RUBRO, :new.COD_GRU_RUBRO, 'N');

  -- Insertar tabla de auditoria
  prb_ins_cb_auditoria( v_registro );
EXCEPTION
  when others then
    prb_ins_cb_auditoria( v_registro );
END;
/

