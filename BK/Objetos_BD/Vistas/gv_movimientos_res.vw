create or replace force view it.gv_movimientos_res as
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       mo.nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from ah_movimientos_his mo
 union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       mo.nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from cc_movimientos_his mo
 union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from pr_movimientos_his mo
 union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from ta_movimientos_his mo
 union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from lc_movimientos_his mo
 union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'D' tipo, 'DEL DIA' des_tipo -- MOVIMIENTO DIARIO
  from ba_modulos md, ge_movimientos mo
 where md.cod_modulo = 3 -- Ahorros
   and md.estado != 4
 union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from ov_movimientos_his mo
Union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from cx_movimientos_his mo
union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'N' tipo, 'FUERA DE HORA' des_tipo -- NOCTURNO O FUERA DE HORA
  from ge_movimientos_noc mo
union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from af_movimientos_his mo
union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from bu_movimientos_his mo
union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from md_movimientos_his mo
union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, null referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from rh_movimientos_his mo
union all
select mo.fecha, mo.hora, mo.cod_usuario, mo.nro_secuencia, mo.fec_valor,
       mo.monto, mo.nro_cuenta, mo.cod_moneda, mo.cod_oficina, mo.cod_error,
       mo.cod_retencion, mo.fec_fin_retencion, mo.est_cuenta, mo.estado,
       mo.cod_causa, mo.cod_banco, mo.cod_ofi_origen, mo.concepto, mo.cod_tasa,
       mo.val_tasa, mo.cod_rubro, mo.cod_ref_cambio, mo.reversado, mo.cod_usu_reversion,
       mo.hor_reversion, mo.emi_aviso, mo.cod_tra_padre, mo.cod_mod_padre, mo.cod_mad_padre,
       mo.cod_transaccion, mo.cod_modulo, mo.cod_modalidad, mo.mto_equ_local, mo.nro_caja,
       mo.cotizacion, mo.cod_bco_central, mo.nro_documento, mo.nro_documento2, mo.nro_documento3,
       mo.nro_documento4, mo.protegido, mo.tip_mov_rubro, mo.cod_autorizacion, mo.cod_usu_autorizador,
       mo.usu_insercion, mo.fec_insercion, mo.usu_modificacion, mo.fec_modificacion, mo.cod_tip_ope_cambio,
       to_number(null) nro_folio, mo.referencia,
       'H' tipo, 'HISTORICO' des_tipo -- HISTORICO
  from ge_movimientos_his mo
;

