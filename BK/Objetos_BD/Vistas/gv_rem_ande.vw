create or replace force view it.gv_rem_ande as
select registro,fec_remision, nro_remision, cod_servicio, tipo
  from
--CABECERA
(select 'C'||
       lpad(a.cod_servicio,5,0)||--servicio
       c.referencia||
       to_char(fec_remision,'yyyymmdd')||--fecha devolución
       --cant remitidos contar de ge_cob_servicios
       lpad((select count(*)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision
             and z.fec_remision = b.fec_remision
             and z.cod_servicio = b.cod_servicio),7,0)||
       --tot remitidos sumar de ge_cob_servicios
       lpad((select sum(monto-mto_comision-mto_impuesto)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision
             and z.fec_remision= b.fec_remision
             and z.cod_servicio = b.cod_servicio),13,0)||
       --cant no procesados de contar ge_cob_servicios con error
       lpad((select count(*)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision
             and z.fec_remision= b.fec_remision
             and z.estado = 'E'
             and z.cod_servicio = b.cod_servicio),7,0)||
       --tot no procesado de sumar ge_cob_servicios con error
       lpad((select sum(monto-mto_comision-mto_impuesto)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision
             and z.fec_remision= b.fec_remision
             and z.estado = 'E'
             and z.cod_servicio = b.cod_servicio),13,0)||
       lpad(b.cantidad,7,0)|| --cant debitados
       lpad(b.tot_debito,13,0) registro,
       fec_remision,
       b.nro_remision,
       b.cod_servicio,
       'C' tipo
  from ge_cob_ser_parametros a, ge_cob_servicios_res b, ge_cob_servicios_cab c
  where a.cod_servicio = b.cod_servicio
  and c.cod_servicio = a.cod_servicio
  and b.fec_remision = c.fecha
 union --DETALLE
select a.referencia3||
       to_char(fecha,'yyyymmdd')||--fecha cobro
       lpad(monto-mto_comision-mto_impuesto,13,0)||--importe debitado
       '0'||--importe debitado
       lpad(' ',15,' ')||--nro cuenta
       a.referencia4||
       (case when nvl(cod_error,'0') in ('0') then 0 --mot devolución
             when cod_error in ('-20679') then 2
             else 1 end)||
       lpad(to_char(referencia1),10,0) registro, --nir
       b.fec_remision fec_remision,
       b.nro_remision,
       b.cod_servicio,
       'D' tipo
  from ge_cob_servicios a,
       ge_cob_servicios_res b,
       ge_cuentas cta,
       ge_cta_clientes c
 where a.nro_cta_debito = cta.nro_cuenta(+)
   and cta.nro_cuenta = c.nro_cuenta(+)
   and c.relacion(+) = 'P'
   and a.cod_servicio = b.cod_servicio
   and a.nro_remision = b.nro_remision
   and a.fec_remision = b.fec_remision
order by fec_remision
)
order by tipo
;

