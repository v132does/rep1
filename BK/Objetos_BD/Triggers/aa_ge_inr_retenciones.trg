CREATE OR REPLACE TRIGGER IT.AA_GE_INR_RETENCIONES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_INR_RETENCIONES
 FOR EACH ROW

DECLARE
r_eaudi ge_auditorias%rowtype;
BEGIN
   r_eaudi.tabla := 'GE_INR_RETENCIONES';
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
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_FACTURA', :old.nro_factura,:new.nro_factura);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_FACTURA', :old.mto_factura,:new.mto_factura);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MONEDA', :old.cod_moneda,:new.cod_moneda);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_RETENCION', :old.mto_retencion,:new.mto_retencion,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO', :old.estado,:new.estado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COTIZACION', :old.cotizacion,:new.cotizacion,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_RENTA', :old.mto_renta,:new.mto_renta,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'MTO_RET_RENTA', :old.mto_ret_renta,:new.mto_ret_renta,'M');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'TIPO_RET', :old.tipo_ret,:new.tipo_ret);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_CUENTA', :old.nro_cuenta,:new.nro_cuenta);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_CUPON', :old.nro_cupon,:new.nro_cupon);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FECHA', :old.fecha,:new.fecha,'F');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'HORA', :old.hora,:new.hora);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_USUARIO', :old.cod_usuario,:new.cod_usuario);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_SECUENCIA', :old.nro_secuencia,:new.nro_secuencia);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_RETENCION', :old.fec_retencion,:new.fec_retencion,'F');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VIG_TIMBRADO', :old.fec_vig_timbrado,:new.fec_vig_timbrado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_TIMBRADO', :old.nro_timbrado,:new.nro_timbrado);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'POR_RETENCION', :old.por_retencion,:new.por_retencion,'N');
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'DET_ERROR', :old.det_error,:new.det_error);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'PRO_ERROR', :old.pro_error,:new.pro_error);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_RET_TESAKA',:old.nro_ret_tesaka,:new.nro_ret_tesaka);
    r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_CTA_CREDITO',:old.nro_cta_credito,:new.nro_cta_credito);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/

