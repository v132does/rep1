CREATE OR REPLACE TRIGGER IT.AA_MD_GARANTIAS
  AFTER DELETE OR UPDATE
     ON MD_GARANTIAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 18/07/2008 a las 15:13:54 Hs.
  */
  v_registro MD_AUDITORIAS%ROWTYPE; -- Registro de la tabla MD_AUDITORIAS
BEGIN
  v_registro.tabla := 'MD_GARANTIAS';
  v_registro.clave := :old.nro_cuenta || '#' || to_char( :old.nro_garantia);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_GARANTIA', :old.cod_garantia, :new.cod_garantia, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );

  -- Insertar tabla de auditoria
  prm_ins_md_auditoria( v_registro );
EXCEPTION
  when others then
    prm_ins_md_auditoria( v_registro );
END;
/

