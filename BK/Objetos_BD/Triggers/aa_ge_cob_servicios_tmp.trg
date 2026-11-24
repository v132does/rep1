CREATE OR REPLACE TRIGGER IT.AA_GE_COB_SERVICIOS_TMP
  AFTER DELETE OR UPDATE
     ON GE_COB_SERVICIOS_TMP
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/09/2006 a las 14:16:59 Hs.
  */
  v_registro GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  v_registro.tabla := 'GE_COB_SERVICIOS_TMP';
  v_registro.clave := to_char( :old.cod_servicio) || '#' || :old.tip_cobro || '#' || to_char( :old.nro_operacion);
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  --sólo modificación guarda auditoría
  IF updating THEN
    v_registro.tip_novedad := 'M';

/*  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;*/

     -- Registrar Detalle
     v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_COBRO', :old.tip_cobro, :new.tip_cobro );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_OPERACION', :old.nro_operacion, :new.nro_operacion, 'N' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'HORA', :old.hora, :new.hora );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFI_ORIGEN', :old.cod_ofi_origen, :new.cod_ofi_origen, 'N' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CAJA', :old.nro_caja, :new.nro_caja, 'N' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_DEBITO', :old.mto_debito, :new.mto_debito, 'M' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_EFECTIVO', :old.mto_efectivo, :new.mto_efectivo, 'M' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CHE_NUE_BANCO', :old.mto_che_nue_banco, :new.mto_che_nue_banco, 'M' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CHE_OTR_BANCO', :old.mto_che_otr_banco, :new.mto_che_otr_banco, 'M' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REMISION', :old.nro_remision, :new.nro_remision, 'N' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_REMISION', :old.fec_remision, :new.fec_remision, 'F' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_COMISION', :old.mto_comision, :new.mto_comision, 'M' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_IMPUESTO', :old.mto_impuesto, :new.mto_impuesto, 'M' );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ERROR', :old.cod_error, :new.cod_error );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REFERENCIA1', :old.referencia1, :new.referencia1 );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'REFERENCIA2', :old.referencia2, :new.referencia2 );
     v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COMENTARIOS', :old.comentarios, :new.comentarios );
   
     -- Insertar tabla de auditoria
     prg_ins_ge_auditoria( v_registro );

  end if;
EXCEPTION
  when others then
    prg_ins_ge_auditoria( v_registro );
END;
/

