CREATE OR REPLACE TRIGGER IT.aa_ta_car_dia_ing_det
  AFTER DELETE OR UPDATE
     ON "IT"."TA_CAR_DIA_ING_DET"
    FOR EACH ROW
DECLARE
  r_taudi ta_auditorias%ROWTYPE; -- Registro de la tabla TA_AUDITORIAS
BEGIN
  r_taudi.tabla := 'TA_CAR_DIA_ING_DET';
  r_taudi.clave := :old.nro_cuenta || '#' || :old.fec_movimiento || '#' || :old.comprobante;
  r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    r_taudi.tip_novedad := 'M';
  ELSIF deleting THEN
    r_taudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  r_taudi.detalle := pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CAR_DIA', :old.nro_car_dia, :new.nro_car_dia );
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_REGISTRO', :old.tip_registro, :new.tip_registro);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'TIP_OPERACION', :old.tip_operacion, :new.tip_operacion);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENT_EMISORA', :old.cod_ent_emisora, :new.cod_ent_emisora); 
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SUC_ENT_EMISORA', :old.suc_ent_emisora, :new.suc_ent_emisora);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_ENT_COBRADORA', :old.cod_ent_cobradora, :new.cod_ent_cobradora);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'SUC_ENT_COBRADORA', :old.suc_ent_cobradora, :new.suc_ent_cobradora);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COMPROBANTE', :old.comprobante, :new.comprobante);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_MOVIMIENTO', :old.fec_movimiento, :new.fec_movimiento);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'NRO_CUENTA', :old.nro_cuenta, :new.nro_cuenta);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'IMPORTE', :old.importe, :new.importe);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'CON_AJUSTE', :old.con_ajuste, :new.con_ajuste);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'DEB_O_CRED', :old.deb_o_cred, :new.deb_o_cred);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PRESENTACION', :old.fec_presentacion, :new.fec_presentacion);  
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_APLICACION', :old.fec_aplicacion, :new.fec_aplicacion);  
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_CIE_CTA_CTE', :old.fec_cie_cta_cte, :new.fec_cie_cta_cte);  
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER_1', :old.filler_1, :new.filler_1);   
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER_2', :old.filler_2, :new.filler_2);   
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'GRU_CIE_CODIGO', :old.gru_cie_codigo, :new.gru_cie_codigo);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER_3', :old.filler_3, :new.filler_3);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER_4', :old.filler_4, :new.filler_4);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FILLER_5', :old.filler_5, :new.filler_5);
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'PROCESADO', :old.procesado, :new.procesado);    
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'ERROR', :old.error, :new.error);   
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'FEC_PROCESO', :old.fec_proceso, :new.fec_proceso);   
  r_taudi.detalle := r_taudi.detalle || pae_cnf.fu_reg_auditoria( r_taudi.tip_novedad, 'COD_USUARIO', :old.cod_usuario, :new.cod_usuario);  
  
  -- Insertar tabla de auditoria
  prt_ins_ta_auditoria( r_taudi );
EXCEPTION
  when others then
    prt_ins_ta_auditoria( r_taudi );
END;
/

