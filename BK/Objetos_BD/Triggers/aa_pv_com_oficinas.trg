CREATE OR REPLACE TRIGGER IT.AA_PV_COM_OFICINAS
  AFTER DELETE OR UPDATE
     ON PV_COM_OFICINAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/05/2008 a las 18:19:34 Hs.
  */
  v_registro PV_AUDITORIAS%ROWTYPE; -- Registro de la tabla PV_AUDITORIAS
BEGIN
  v_registro.tabla := 'PV_COM_OFICINAS';
  v_registro.clave := to_char( :old.cod_compra) || '#' || to_char( :old.nro_linea) || '#' || to_char( :old.cod_oficina) || '#' || to_char( :old.cod_area);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CANTIDAD', :old.cantidad, :new.cantidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_UNITARIO', :old.val_unitario, :new.val_unitario, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TOTAL', :old.val_total, :new.val_total, 'M' );

  -- Insertar tabla de auditoria
  prk_ins_pv_auditoria( v_registro );
EXCEPTION
  when others then
    prk_ins_pv_auditoria( v_registro );
END;
/

