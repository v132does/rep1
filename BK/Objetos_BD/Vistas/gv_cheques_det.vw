create or replace force view it.gv_cheques_det as
select cod_banco,
       nro_cheque,
       cta_libradora,
       cod_moneda,
       monto,
       nro_cuenta,
       --nro_cuota,
       estado,
       fecha,--fec_ingreso,
       nro_boleta,
       --cod_ofi_camara,
       fec_env_corresponsal,--fec_deposito,
       cod_bco_corresponsal,--cod_ban_deposito,
       --nro_bol_deposito,
       cod_cau_devolucion,
       cod_retencion
  from ge_che_exterior
union all
  select cod_banco,
       to_char(nro_cheque),
       cta_libradora,
       cod_moneda,
       monto,
       nro_cuenta,
       --nro_cuota,
       estado,
       fecha,--fec_ingreso,
       nro_boleta,
       --cod_ofi_camara,
       null,--fec_env_corresponsal,--fec_deposito,
       null,--cod_bco_corresponsal,--cod_ban_deposito,
       --nro_bol_deposito,
       cod_cau_devolucion,
       cod_retencion
  from cc_che_enviados
;

