CREATE OR REPLACE TRIGGER IT.AA_CB_RUB_GENERICAS
  AFTER DELETE OR UPDATE
     ON "IT"."CB_RUB_GENERICAS"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2005 - IT Consultores
  */
  v_registro CB_AUDITORIAS%ROWTYPE; -- Registro de la tabla CB_AUDITORIAS
BEGIN
  v_registro.tabla := 'CB_RUB_GENERICAS';
  v_registro.clave := to_char(:old.COD_GRU_RUBRO) || '#' || :old.COD_MONEDA;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_GENERICA', :old.cod_RUB_GENERICA, :new.cod_RUB_GENERICA);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_PERDIDA', :old.cod_RUB_PERDIDA, :new.cod_RUB_PERDIDA);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_GANANCIA', :old.cod_RUB_GANANCIA, :new.cod_RUB_GANANCIA);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.DESCRIPCION, :new.DESCRIPCION);

  -- Insertar tabla de auditoria
  prb_ins_cb_auditoria( v_registro );
EXCEPTION
  when others then
    prb_ins_cb_auditoria( v_registro );
END;
/

