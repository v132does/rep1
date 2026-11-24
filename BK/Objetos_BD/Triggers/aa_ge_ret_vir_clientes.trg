CREATE OR REPLACE TRIGGER IT.AA_GE_RET_VIR_CLIENTES
 AFTER DELETE OR INSERT OR UPDATE
 ON ge_ret_vir_clientes
 FOR EACH ROW

DECLARE
r_eaudi ge_auditorias%rowtype;
BEGIN
   r_eaudi.tabla := 'GE_RET_VIR_CLIENTES';
   r_eaudi.clave := to_char(:old.cod_retencion);
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
    r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA', :old.cod_persona,:new.cod_persona);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_PAGO',:old.fec_pago,:new.fec_pago,'F');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'IMP_FACTURA', :old.imp_factura, :new.imp_factura );
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MONEDA', :old.cod_moneda, :new.cod_moneda);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_RETENCION', :old.cod_retencion, :new.cod_retencion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_IVA', :old.mto_iva, :new.mto_iva);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_RETENCION', :old.mto_retencion, :new.mto_retencion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO', :old.estado, :new.estado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COTIZACION', :old.cotizacion, :new.cotizacion);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_RENTA', :old.mto_renta, :new.mto_renta);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_RET_RENTA', :old.mto_ret_renta, :new.mto_ret_renta);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_CAM_ESTADO', :old.fec_cam_estado, :new.fec_cam_estado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_TIMBRADO', :old.nro_timbrado, :new.nro_timbrado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VIG_TIMBRADO', :old.fec_vig_timbrado,:new.fec_vig_timbrado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_LOTE', :old.nro_lote, :new.nro_lote);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_FACTURA', :old.nro_factura,:new.nro_factura);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_RET_TESAKA',:old.nro_ret_tesaka,:new.nro_ret_tesaka);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/

