CREATE OR REPLACE TRIGGER IT.AA_AF_BIENES
  AFTER DELETE OR UPDATE
     ON AF_BIENES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 22/08/2007 a las 09:33:44 Hs.
  */
  v_registro AF_AUDITORIAS%ROWTYPE; -- Registro de la tabla AF_AUDITORIAS
BEGIN
  v_registro.tabla := 'AF_BIENES';
  v_registro.clave := to_char( :old.cod_bien);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ARTICULO', :old.cod_articulo, :new.cod_articulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DESCRIPCION', :old.descripcion, :new.descripcion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_AREA', :old.cod_area, :new.cod_area, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_SERIE', :old.nro_serie, :new.nro_serie, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_COMPRA', :old.val_compra, :new.val_compra, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_COMPRA', :old.fec_compra, :new.fec_compra, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ENT_PROVEEDOR', :old.cod_ent_proveedor, :new.cod_ent_proveedor, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_FACTURA', :old.nro_factura, :new.nro_factura );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COEFICIENTE', :old.coeficiente, :new.coeficiente, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VTO_DEPRECIACION', :old.fec_vto_depreciacion, :new.fec_vto_depreciacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REV_ANTERIOR', :old.rev_anterior, :new.rev_anterior, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REV_ACTUAL', :old.rev_actual, :new.rev_actual, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEP_ANTERIOR', :old.dep_anterior, :new.dep_anterior, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEP_ANUAL', :old.dep_anual, :new.dep_anual, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEP_MENSUAL', :old.dep_mensual, :new.dep_mensual, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REV_DEPRECIACION', :old.rev_depreciacion, :new.rev_depreciacion, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REV_ANO_ANTERIOR', :old.rev_ano_anterior, :new.rev_ano_anterior, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REV_ANO_ACUMULADO', :old.rev_ano_Acumulado, :new.rev_ano_Acumulado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEP_ANO_ACU_ANTERIOR', :old.dep_ano_acu_anterior, :new.dep_ano_acu_anterior, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEP_ACTUAL', :old.dep_actual, :new.dep_actual, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DEP_ACUMULADA', :old.dep_acumulada, :new.dep_acumulada, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_NETO', :old.val_neto, :new.val_neto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_PROCESO', :old.tip_proceso, :new.tip_proceso );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_ENAJENACION', :old.fec_enajenacion, :new.fec_enajenacion, 'F' );

  -- Insertar tabla de auditoria
  prf_ins_af_auditoria( v_registro );
EXCEPTION
  when others then
    prf_ins_af_auditoria( v_registro );
END;
/

