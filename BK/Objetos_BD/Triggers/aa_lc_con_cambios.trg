CREATE OR REPLACE TRIGGER IT.AA_LC_CON_CAMBIOS
  AFTER DELETE OR UPDATE
     ON LC_CON_CAMBIOS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2014 - IT Consultores
  || Generado el 01/08/2014 a las 11:20:48 Hs.
  */
  r_laudi LC_AUDITORIAS%ROWTYPE; -- Registro de la tabla LC_AUDITORIAS
BEGIN
  r_laudi.tabla := 'LC_CON_CAMBIOS';
  r_laudi.clave := to_char( :old.nro_contrato);
  r_laudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_laudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_laudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_laudi.detalle := pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'COD_MON_COMPRA', :old.cod_mon_compra, :new.cod_mon_compra );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'COT_COMPRA', :old.cot_compra, :new.cot_compra, 'M' );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'MTO_COMPRA', :old.mto_compra, :new.mto_compra, 'M' );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'COD_MON_VENTA', :old.cod_mon_venta, :new.cod_mon_venta );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'COT_VENTA', :old.cot_venta, :new.cot_venta, 'M' );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'MTO_VENTA', :old.mto_venta, :new.mto_venta, 'M' );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'PARIDAD', :old.paridad, :new.paridad, 'N' );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'NRO_CTA_CREDITO', :old.nro_cta_credito, :new.nro_cta_credito );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia, 'N' );
  r_laudi.detalle := r_laudi.detalle || pae_cnf.fu_reg_auditoria( r_laudi.tip_novedad, 'COD_TIP_REFERENCIA', :old.cod_tip_referencia, :new.cod_tip_referencia );

  -- Insertar tabla de auditoria
  prl_ins_lc_auditoria( r_laudi );
EXCEPTION
  when others then
    prl_ins_lc_auditoria( r_laudi );
END;
/

