CREATE OR REPLACE TRIGGER IT.AA_GE_TRA_FIRMAS
  AFTER DELETE OR UPDATE
     ON GE_TRA_FIRMAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 23/07/2014 a las 16:05:30 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_TRA_FIRMAS';
  v_registro.clave := to_char( :old.cod_transaccion) || '#' || to_char( :old.cod_modalidad) || '#' || to_char( :old.cod_modulo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_CONTROL', :old.tip_control, :new.tip_control );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_FACULTAD', :old.cod_facultad, :new.cod_facultad );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_ORD_IMPORTE', :old.nro_ord_importe, :new.nro_ord_importe, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

