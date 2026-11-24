create or replace force view it.simgia_cc_cta_bancarias as
select ccb.nro_cuenta, ccb.cod_modulo, ccb.cod_modalidad, ccb.cod_oficina, ccb.dig_verificador, ccb.cod_moneda, ccb.denominacion, ccb.fec_apertura, ccb.sal_minimo,
ccb.mto_acuerdo, ccb.est_batch, ccb.estado, ccb.fec_ult_conciliacion, ccb.sal_ult_conciliacion, ccb.nro_folio, ccb.fec_cam_estado,
ccb.fec_ult_movimiento, ccb.hor_ult_movimiento, ccb.sal_ret_batch, to_number(ccb.sal_retenido) sal_retenido, ccb.sal_blo_batch, ccb.sal_bloqueado,
ccb.sal_tot_batch, to_number(ccb.sal_total) sal_total, ccb.cod_banco, ccb.nro_cta_bancaria, ccb.cod_programa, ccb.usu_insercion, ccb.fec_insercion,
ccb.usu_modificacion, ccb.fec_modificacion, ccb.cod_rubro, ccb.fec_ult_extracto, ccb.fre_extracto, ccb.mto_deb_pendientes,
ccb.mto_cre_pendientes,  pai_int.FU_OBT_CTA_CONTABLE(ccb.cod_rubro) cod_rub_externo
from cc_cta_bancarias ccb
--Desarrollado por Simgia, programador Juan Bauer.
;

