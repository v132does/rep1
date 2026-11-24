CREATE OR REPLACE TRIGGER IT.AA_BU_BIE_VEHICULOS
  AFTER DELETE OR UPDATE
     ON BU_BIE_VEHICULOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/11/2010 a las 09:57:01 Hs.
  */
  v_registro BU_AUDITORIAS%ROWTYPE; -- Registro de la tabla BU_AUDITORIAS
BEGIN
  v_registro.tabla := 'BU_BIE_VEHICULOS';
  v_registro.clave := to_char( :old.cod_bien);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MARCA', :old.cod_marca, :new.cod_marca, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_MOTOR', :old.nro_motor, :new.nro_motor );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CHASIS', :old.nro_chasis, :new.nro_chasis );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MODELO', :old.modelo, :new.modelo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ANO', :old.ano, :new.ano, 'N' );

  -- Insertar tabla de auditoria
  pru_ins_bu_auditoria( v_registro );
EXCEPTION
  when others then
    pru_ins_bu_auditoria( v_registro );
END;
/

