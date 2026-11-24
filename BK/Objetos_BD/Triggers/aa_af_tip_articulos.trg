CREATE OR REPLACE TRIGGER IT.AA_AF_TIP_ARTICULOS
  AFTER DELETE OR UPDATE
     ON AF_TIP_ARTICULOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 10/08/2007 a las 11:40:29 Hs.
  */
  v_registro AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  v_registro.tabla := 'AF_TIP_ARTICULOS';
  v_registro.clave := to_char( :old.cod_tip_articulo);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );

  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( v_registro );
EXCEPTION
  when others then
    prf_ins_af_auditoria( v_registro );
END;
/

