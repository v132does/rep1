CREATE OR REPLACE TRIGGER IT."AA_CX_CTA_EXPORTACIONES"
  AFTER DELETE OR UPDATE
   OF nro_cuenta, 
      cod_modulo, 
      cod_modalidad, 
      cod_oficina, 
      denominacion, 
      cod_moneda, 
      fec_solicitud, 
      fec_aprobacion, 
      fec_vencimiento, 
      fec_cancelacion, 
      tip_monto, 
      monto, 
      mto_equ_local, 
      saldo, 
      cod_bco_emisor, 
      cod_bco_corresponsal, 
      cod_per_beneficiario, 
      tip_utilizacion, 
      nro_referencia, 
      mercaderia, 
      nro_cta_reembolso, 
      confirmado, 
      fec_ven_embarque, 
      cobrado, 
      estado, 
      tip_cobro, 
      nro_sol_prestamo, 
      nro_cta_prestamo, 
      observacion, 
      fec_cam_estado, 
      cod_cau_cancelacion, 
      cod_bco_reembolsante, 
      ordenante,
      con_aladi,
      mto_utilizado,
      discrepado,
      por_var_monto,
      mto_original,
      cod_rub_economico
   ON CX_CTA_EXPORTACIONES
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoría
  || (c) 2005 - IT Consultores
  || Generado el 19/01/2008 a las 18:16:26 Hs.
  */
  v_registro CX_AUDITORIAS%ROWTYPE; -- Registro de la tabla CX_AUDITORIAS
BEGIN
  v_registro.tabla := 'CX_CTA_EXPORTACIONES';
  v_registro.clave := :old.nro_cuenta;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DENOMINACION', :old.denominacion, :new.denominacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_SOLICITUD', :old.fec_solicitud, :new.fec_solicitud, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CANCELACION', :old.fec_cancelacion, :new.fec_cancelacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_MONTO', :old.tip_monto, :new.tip_monto );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_EQU_LOCAL', :old.mto_equ_local, :new.mto_equ_local, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SALDO', :old.saldo, :new.saldo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_BATCH', :old.sal_batch, :new.sal_batch, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_EMISOR', :old.cod_bco_emisor, :new.cod_bco_emisor, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_CORRESPONSAL', :old.cod_bco_corresponsal, :new.cod_bco_corresponsal, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PER_BENEFICIARIO', :old.cod_per_beneficiario, :new.cod_per_beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_UTILIZACION', :old.tip_utilizacion, :new.tip_utilizacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MERCADERIA', :old.mercaderia, :new.mercaderia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_REEMBOLSO', :old.nro_cta_reembolso, :new.nro_cta_reembolso );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONFIRMADO', :old.confirmado, :new.confirmado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VEN_EMBARQUE', :old.fec_ven_embarque, :new.fec_ven_embarque, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COBRADO', :old.cobrado, :new.cobrado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_BATCH', :old.est_batch, :new.est_batch );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_COBRO', :old.tip_cobro, :new.tip_cobro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_SOL_PRESTAMO', :old.nro_sol_prestamo, :new.nro_sol_prestamo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_PRESTAMO', :old.nro_cta_prestamo, :new.nro_cta_prestamo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OBSERVACION', :old.observacion, :new.observacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CAM_ESTADO', :old.fec_cam_estado, :new.fec_cam_estado, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CAU_CANCELACION', :old.cod_cau_cancelacion, :new.cod_cau_cancelacion, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_REEMBOLSANTE', :old.cod_bco_reembolsante, :new.cod_bco_reembolsante, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ORDENANTE', :old.ordenante, :new.ordenante );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_ALADI', :old.con_aladi, :new.con_aladi );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_UTILIZADO', :old.mto_utilizado, :new.mto_utilizado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DISCREPADO', :old.discrepado, :new.discrepado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_ALADI_ANT', :old.con_aladi_ant, :new.con_aladi_ant );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_CORRESPONSAL_ANT', :old.cod_bco_corresponsal_ant, :new.cod_bco_corresponsal_ant, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'UBI_BCO_EMISOR_ANT', :old.ubi_bco_emisor_ant, :new.ubi_bco_emisor_ant );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SIT_CONTABLE', :old.cod_sit_contable, :new.cod_sit_contable, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_DEBITO', :old.nro_cta_debito, :new.nro_cta_debito );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'POR_VAR_MONTO', :old.por_var_monto, :new.por_var_monto,'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_ORIGINAL', :old.mto_original, :new.mto_original,'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico);
      
  -- Insertar tabla de auditoria
  prx_ins_cx_auditoria( v_registro );
EXCEPTION
  when others then
    prx_ins_cx_auditoria( v_registro );
END;
/

