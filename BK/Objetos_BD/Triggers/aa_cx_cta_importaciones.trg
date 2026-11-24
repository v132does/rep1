CREATE OR REPLACE TRIGGER IT.AA_CX_CTA_IMPORTACIONES
 AFTER DELETE OR UPDATE
 ON CX_CTA_IMPORTACIONES
 REFERENCING OLD AS OLD NEW AS NEW
 FOR EACH ROW
DECLARE

  /*
  || Archivo creado por el Generador de Triggers de Auditoria
  || (c) 2005 - IT Consultores
  || Generado el 19/08/2005 a las 11:40:04 Hs.
  */
  v_registro CX_AUDITORIAS%ROWTYPE; -- Registro de la tabla CX_AUDITORIAS
BEGIN
  v_registro.tabla := 'CX_CTA_IMPORTACIONES';
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
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DENOMINACION', :old.denominacion, :new.denominacion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_SOLICITUD', :old.fec_solicitud, :new.fec_solicitud, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_APROBACION', :old.fec_aprobacion, :new.fec_aprobacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_CANCELACION', :old.fec_cancelacion, :new.fec_cancelacion, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MONTO', :old.monto, :new.monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NVO_MONTO', :old.nvo_monto, :new.nvo_monto, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_MONTO', :old.tip_monto, :new.tip_monto );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_EQU_LOCAL', :old.mto_equ_local, :new.mto_equ_local, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SALDO', :old.saldo, :new.saldo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'SAL_BATCH', :old.sal_batch, :new.sal_batch, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_PREPAGO', :old.mto_prepago, :new.mto_prepago, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'BENEFICIARIO', :old.beneficiario, :new.beneficiario );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIRECCION', :old.direccion, :new.direccion );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PAIS', :old.cod_pais, :new.cod_pais, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CIUDAD', :old.cod_ciudad, :new.cod_ciudad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_CORRESPONSAL', :old.cod_bco_corresponsal, :new.cod_bco_corresponsal, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIP_COBRO', :old.tip_cobro, :new.tip_cobro );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VTO_PLAZO', :old.fec_vto_plazo, :new.fec_vto_plazo, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_BATCH', :old.est_batch, :new.est_batch );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MERCADERIA', :old.mercaderia, :new.mercaderia );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CONFIRMADO', :old.confirmado, :new.confirmado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NVO_CONFIRMADO', :old.nvo_confirmado, :new.nvo_confirmado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_SOL_PRESTAMO', :old.nro_sol_prestamo, :new.nro_sol_prestamo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'POR_VAR_MONTO', :old.por_var_monto, :new.por_var_monto, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_ORIGINAL', :old.mto_original, :new.mto_original, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_LINEA', :old.nro_linea, :new.nro_linea, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_ALADI', :old.con_aladi, :new.con_aladi );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_UTILIZADO', :old.mto_utilizado, :new.mto_utilizado, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DISCREPADO', :old.discrepado, :new.discrepado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SIT_CONTABLE', :old.cod_sit_contable, :new.cod_sit_contable, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'STAND_BY', :old.stand_by, :new.stand_by );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CON_ALADI_ANT', :old.con_aladi_ant, :new.con_aladi_ant );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'STAND_BY_ANT', :old.stand_by_ant, :new.stand_by_ant );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_BCO_CORRESPONSAL_ANT', :old.cod_bco_corresponsal_ant, :new.cod_bco_corresponsal_ant, 'N' );      
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'UBI_BCO_NEGOCIADOR_ANT', :old.ubi_bco_negociador_ant, :new.ubi_bco_negociador_ant );  
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'NRO_CTA_CREDITO', :old.nro_cta_credito, :new.nro_cta_credito );  
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_RUB_ECONOMICO', :old.cod_rub_economico, :new.cod_rub_economico );
        

  -- Insertar tabla de auditoria
  prx_ins_cx_auditoria( v_registro );
EXCEPTION
  when others then
    prx_ins_cx_auditoria( v_registro );
END;
/

