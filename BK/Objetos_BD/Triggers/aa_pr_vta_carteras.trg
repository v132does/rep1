CREATE OR REPLACE TRIGGER IT.AA_PR_VTA_CARTERAS
  AFTER DELETE OR UPDATE
     ON IT.PR_VTA_CARTERAS
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditoria
  || (c) 2005 - IT Consultores
  || Generado el 10/08/2011 a las 13:48:24 Hs.
  */
  v_registro PR_AUDITORIAS%ROWTYPE; -- Registro de la tabla PR_AUDITORIAS
BEGIN
  v_registro.tabla := 'PR_VTA_CARTERAS';
  v_registro.clave := :old.nro_cuenta;
  v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    v_registro.tip_novedad := 'M';
  ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_ENTE', :old.cod_ente, :new.cod_ente, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_OPE_ENTE', :old.fec_ope_ente, :new.fec_ope_ente, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_OFICINA', :old.cod_oficina, :new.cod_oficina, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODULO', :old.cod_modulo, :new.cod_modulo, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MODALIDAD', :old.cod_modalidad, :new.cod_modalidad, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_INICIO', :old.fec_inicio, :new.fec_inicio, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FEC_VENCIMIENTO', :old.fec_vencimiento, :new.fec_vencimiento, 'F' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'MTO_CAPITAL', :old.mto_capital, :new.mto_capital, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAN_CUOTAS', :old.can_cuotas, :new.can_cuotas, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_SEC_CREDITO', :old.cod_sec_credito, :new.cod_sec_credito, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'VAL_TASA', :old.val_tasa, :new.val_tasa, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona);
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'ESTADO', :old.estado, :new.estado );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'EST_BATCH', :old.est_batch, :new.est_batch );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'CAT_CLIENTE', :old.cat_cliente, :new.cat_cliente, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'DIA_ATRASO', :old.dia_atraso, :new.dia_atraso, 'N' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TOT_RIESGO', :old.tot_riesgo, :new.tot_riesgo, 'M' );
  v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'OPE_RECAPTADA', :old.ope_recaptada, :new.ope_recaptada );

  -- Insertar tabla de auditoria
  prp_ins_pr_auditoria( v_registro );
EXCEPTION
  when others then
    prp_ins_pr_auditoria( v_registro );
END;
/

