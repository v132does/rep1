CREATE OR REPLACE TRIGGER IT.AA_GE_DEB_CRE_BATCH_DET
 AFTER DELETE OR UPDATE
 ON GE_DEB_CRE_BATCH_DET
 FOR EACH ROW
DECLARE

  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 09/10/2007 a las 15:47:29 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_DEB_CRE_BATCH_DET';
  v_registro.clave := to_char( :old.cod_deb_cre_batch)||'#'|| :old.cod_moneda;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUBRO', :old.cod_rubro, :new.cod_rubro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TRANSACCION', :old.cod_transaccion, :new.cod_transaccion, 'N' );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

