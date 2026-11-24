CREATE OR REPLACE TRIGGER IT.AA_GE_PAR_POL_PRE_APR
  AFTER DELETE OR UPDATE
     ON "IT"."GE_PAR_POL_PRE_APR"
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2005 - IT Consultores
  || Generado el 24/03/2022 a las 16:13:36 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_PAR_POL_PRE_APR';
  v_registro.clave := to_char( :old.tip_politica);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPTION', :old.description, :new.description );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_APROBADO', :old.mto_aprobado, :new.mto_aprobado, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_DEU_CRC_DES', :old.mto_deu_crc_des, :new.mto_deu_crc_des, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_DEU_CRC_HAS', :old.mto_deu_crc_has, :new.mto_deu_crc_has, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ANT_INFOMERCIO', :old.ant_infomercio, :new.ant_infomercio );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FAJA', :old.faja, :new.faja );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_INGRESO', :old.tip_ingreso, :new.tip_ingreso, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAT_CRC', :old.cat_crc, :new.cat_crc );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONDICION', :old.condicion, :new.condicion );

  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( v_registro );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

