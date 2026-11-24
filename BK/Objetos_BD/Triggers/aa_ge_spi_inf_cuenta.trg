CREATE OR REPLACE TRIGGER IT.AA_GE_SPI_INF_CUENTA
  AFTER DELETE OR UPDATE
     ON it.GE_SPI_INF_CUENTA
    FOR EACH ROW
DECLARE
  /*
  || Archivo creado por el Generador de Triggers de Auditorka
  || (c) 2021 - ITTI DIGITAL
  || Generado el 15/12/2021 a las 12:03:19 Hs.
  */
  rg_raudi GE_AUDITORIAS%ROWTYPE; -- Registro de la tabla GE_AUDITORIAS
BEGIN
  rg_raudi.tabla := 'GE_SPI_INFORMES';
  rg_raudi.clave := to_char( :old.nro_referencia);
  rg_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  IF updating THEN
    rg_raudi.tip_novedad := 'M';
  ELSIF deleting THEN
    rg_raudi.tip_novedad := 'E';
  END IF;

  -- Registrar Detalle
  rg_raudi.detalle := pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REFERENCIA', :old.nro_referencia, :new.nro_referencia );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'FEC_INFORME', :old.fec_informe, :new.fec_informe );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_REF_EXTERNA', :old.nro_ref_externa, :new.nro_ref_externa );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'NRO_CTA_INFORME', :old.nro_cta_informe, :new.nro_cta_informe );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'IMP_SALDO_CTA', :old.imp_saldo_cta, :new.imp_saldo_cta );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CANT_TOT_OP_SESION', :old.cant_tot_op_sesion, :new.cant_tot_op_sesion );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MON_TOT_OP_SESION', :old.mon_tot_op_sesion, :new.mon_tot_op_sesion );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MON_RES_DEB_CRE', :old.mon_res_deb_cre, :new.mon_res_deb_cre );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CANT_LIQ_CREDITO', :old.cant_liq_credito, :new.cant_liq_credito );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MON_LIQ_CREDITO', :old.mon_liq_credito, :new.mon_liq_credito );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'CANT_LIQ_DEBITO', :old.cant_liq_debito, :new.cant_liq_debito );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'MON_LIQ_DEBITO', :old.mon_liq_debito, :new.mon_liq_debito );
  rg_raudi.detalle := rg_raudi.detalle || pae_cnf.fu_reg_auditoria( rg_raudi.tip_novedad, 'ID_SESION', :old.id_sesion, :new.id_sesion );
  -- Insertar tabla de auditoria
  prg_ins_ge_auditoria( rg_raudi );
EXCEPTION
  when others then
    prg_ins_ge_auditoria( rg_raudi );
END;
/

