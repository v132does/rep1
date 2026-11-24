create or replace view it.sv_salida_de_efectivo as
select c.fecha, r.cod_persona, p.tipo, CASE WHEN p.tipo = 'F' THEN 1 ELSE 2 END deposito,
       sum(case when c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) > 30 then 0 else
           round((d.sal_actual * nvl((select cot.val_conversion
                                            from ge_cotizaciones cot
                                            where cot.cod_moneda = c.cod_moneda
                                              and cot.fecha = c.fecha),1)),0) end) saldo_total,
       sum(case when c.cod_moneda = 'GS' and c.cod_modalidad IN ('31', '39', '334', '41') THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                                                                  from ge_cotizaciones cot
                                                                                                  where cot.cod_moneda = c.cod_moneda
                                                                                                    and cot.fecha = c.fecha),1)),0) else 0 end) sal_vista_gs,
       sum(case when c.cod_moneda <> 'GS' and c.cod_modalidad IN ('31', '39', '334', '41') THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                                                                  from ge_cotizaciones cot
                                                                                                  where cot.cod_moneda = c.cod_moneda
                                                                                                    and cot.fecha = c.fecha),1)),0) else 0 end) sal_vista_ext,
       sum(case when c.cod_moneda = 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) <= 30
                   THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                    from ge_cotizaciones cot
                                                    where cot.cod_moneda = c.cod_moneda
                                                      and cot.fecha = c.fecha),1)),0) else 0 end) sal_plazo_gs,
       sum(case when c.cod_moneda <> 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) <= 30
                   THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                    from ge_cotizaciones cot
                                                    where cot.cod_moneda = c.cod_moneda
                                                      and cot.fecha = c.fecha),1)),0) else 0 end) sal_plazo_ext,
       sum(case when c.cod_moneda = 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) > 30
                   THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                    from ge_cotizaciones cot
                                                    where cot.cod_moneda = c.cod_moneda
                                                      and cot.fecha = c.fecha),1)),0) else 0 end) sal_res_gs,
       sum(case when c.cod_moneda <> 'GS' and c.cod_modalidad IN (33,36,37,38) and it.fub_obt_venc_aplazo(d.nro_cuenta, c.fecha) > 30
                   THEN round((d.sal_actual * nvl((select cot.val_conversion
                                                    from ge_cotizaciones cot
                                                    where cot.cod_moneda = c.cod_moneda
                                                      and cot.fecha = c.fecha),1)),0) else 0 end) sal_res_ext
from cb_sal_inventarios_his c, cb_sal_inventarios_det_his d, ge_cta_clientes r, ba_personas p, ge_clientes cl, ge_cuentas cu
where c.cod_modalidad  in (31,334,41,39,33,36,37,38)
  and ((c.cod_modalidad = 41 and c.tip_saldo in ('C','Q')) or (c.tip_saldo = 'C' ))
  and c.situacion      not in ('A','T')
  and d.fecha          = c.fecha
  and d.nro_referencia = c.nro_referencia
  and d.nro_cuenta     = r.nro_cuenta
  and r.relacion       = 'P'
  and p.cod_persona    = r.cod_persona
  and p.cod_persona    <> '1'
  and cl.cod_persona   = p.cod_persona
  and (cl.cod_seg_cliente is null or cl.cod_seg_cliente <> 12)
  and d.sal_actual     > 0
  and cu.nro_cuenta    = r.nro_cuenta
  and cu.estado        <> 'T'
group by c.fecha, r.cod_persona, p.tipo;
