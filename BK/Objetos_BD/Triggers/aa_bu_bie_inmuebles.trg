CREATE OR REPLACE TRIGGER IT.AA_BU_BIE_INMUEBLES
  AFTER DELETE OR UPDATE
     ON BU_BIE_INMUEBLES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 05/11/2010 a las 09:56:14 Hs.
  */
  v_registro BU_AUDITORIAS%ROWTYPE; -- Registro de la tabla BU_AUDITORIAS
BEGIN
  v_registro.tabla := 'BU_BIE_INMUEBLES';
  v_registro.clave := to_char( :old.cod_bien);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_DISTRITO', :old.cod_distrito, :new.cod_distrito, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_FINCA', :old.nro_finca, :new.nro_finca );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EDIFICADO', :old.edificado, :new.edificado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SUPERFICIE', :old.superficie, :new.superficie, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'UNI_MEDIDA', :old.uni_medida, :new.uni_medida );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'UBICACION', :old.ubicacion, :new.ubicacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BARRIO', :old.cod_barrio, :new.cod_barrio, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAIS', :old.cod_pais, :new.cod_pais, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CIUDAD', :old.cod_ciudad, :new.cod_ciudad, 'N' );

  -- Insertar tabla de auditoria
  pru_ins_bu_auditoria( v_registro );
EXCEPTION
  when others then
    pru_ins_bu_auditoria( v_registro );
END;
/

