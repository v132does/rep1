CREATE OR REPLACE TRIGGER IT.aa_ta_cob_ajustes
  AFTER DELETE OR UPDATE
     ON "IT"."TA_COB_AJUSTES"
    FOR EACH ROW
DECLARE
  r_taudi ta_auditorias%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_COB_AJUSTES';
  r_taudi.clave := :old.nro_cuenta || '#' || :old.fec_movimiento || '#' || :old.nro_comprobante;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_REGISTRO', :old.TIP_REGISTRO, :new.TIP_REGISTRO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_OPERACION', :old.TIP_OPERACION, :new.TIP_OPERACION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ENT_EMISORA', :old.ENT_EMISORA, :new.ENT_EMISORA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SUC_ENT_EMISORA', :old.SUC_ENT_EMISORA, :new.SUC_ENT_EMISORA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ENT_COBRADORA', :old.ENT_COBRADORA, :new.ENT_COBRADORA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SUC_ENT_COBRADORA', :old.SUC_ENT_COBRADORA, :new.SUC_ENT_COBRADORA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MONEDA', :old.COD_MONEDA, :new.COD_MONEDA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_COMPROBANTE', :old.NRO_COMPROBANTE, :new.NRO_COMPROBANTE);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_MOVIMIENTO', :old.FEC_MOVIMIENTO, :new.FEC_MOVIMIENTO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.NRO_CUENTA, :new.NRO_CUENTA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMPORTE', :old.IMPORTE, :new.IMPORTE);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CONCEPTO', :old.CONCEPTO, :new.CONCEPTO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_MOVIMIENTO', :old.TIP_MOVIMIENTO, :new.TIP_MOVIMIENTO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PRESENTACION', :old.FEC_PRESENTACION, :new.FEC_PRESENTACION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_APLICACION', :old.FEC_APLICACION, :new.FEC_APLICACION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIERRE_CTA_CTE', :old.FEC_CIERRE_CTA_CTE, :new.FEC_CIERRE_CTA_CTE);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ORI_COB_AJUSTE', :old.ORI_COB_AJUSTE, :new.ORI_COB_AJUSTE);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_ENVIO', :old.NRO_ENVIO, :new.NRO_ENVIO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'GRU_CTA_CTE_SOCIO', :old.GRU_CTA_CTE_SOCIO, :new.GRU_CTA_CTE_SOCIO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ERROR', :old.COD_ERROR, :new.COD_ERROR);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DESC_ERROR', :old.DESC_ERROR, :new.DESC_ERROR);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_PRODUCTO', :old.COD_PRODUCTO, :new.COD_PRODUCTO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CAJA', :old.NRO_CAJA, :new.NRO_CAJA);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USUARIO', :old.USUARIO, :new.USUARIO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER', :old.FILLER, :new.FILLER);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USU_INSERCION', :old.USU_INSERCION, :new.USU_INSERCION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_INSERCION', :old.FEC_INSERCION, :new.FEC_INSERCION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'USU_MODIFICACION', :old.USU_MODIFICACION, :new.USU_MODIFICACION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_MODIFICACION', :old.FEC_MODIFICACION, :new.FEC_MODIFICACION);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PROCESO', :old.FEC_PROCESO, :new.FEC_PROCESO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PROCESADO', :old.PROCESADO, :new.PROCESADO);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ERROR', :old.ERROR, :new.ERROR);

  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

