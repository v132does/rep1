CREATE OR REPLACE TRIGGER IT.AA_MD_TIP_OPERACIONES
  AFTER DELETE OR UPDATE
     ON MD_TIP_OPERACIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 21/07/2015 a las 16:23:47 Hs. 
  */
  v_registro MD_AUDITORIAS%ROWTYPE; -- Registro de la tabla MD_AUDITORIAS
  
BEGIN
  v_registro.tabla := 'MD_TIP_OPERACIONES';
  v_registro.clave := to_char( :old.cod_tip_operacion);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_OPERACION', :old.tip_operacion, :new.tip_operacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TIP_OPE_BCP', :old.cod_tip_ope_bcp, :new.cod_tip_ope_bcp );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MAD_PADRE', :old.cod_mad_padre, :new.cod_mad_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MAD_OPERACION', :old.cod_mad_operacion, :new.cod_mad_operacion, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TRA_PADRE', :old.cod_tra_padre, :new.cod_tra_padre, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_TRANSACCION', :old.cod_transaccion, :new.cod_transaccion, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PERSONA', :old.tip_persona, :new.tip_persona );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PRESTAMO', :old.tip_prestamo, :new.tip_prestamo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ACTIVO', :old.activo, :new.activo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico );

  -- Insertar tabla de auditoria
  prm_ins_md_auditoria( v_registro );
EXCEPTION
  when others then
    prm_ins_md_auditoria( v_registro );
END;
/

