create or replace force view it.gv_rem_copaco as
select registro,fec_remision, nro_remision, cod_servicio, tipo
  from
--CABECERA
(
select 'C'||
       lpad(a.cod_servicio,5,0)||--servicio
       lpad(b.cod_ofi_origen,4,0)||--centro de cobro
       lpad(b.nro_remision,4,0)||-- nro remisión
       lpad(b.cod_ofi_origen,4,0)||--agencia
       lpad(b.cod_ofi_origen,4,0)||--sucursal
       to_char(fec_remision,'yyyymmdd')||--fecha remisión
       to_char(fec_remision,'yyyymmdd')||--fecha devolución
       --cant remitidos contar de ge_cob_servicios
/*       lpad((select count(*)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision and z.fec_remision= b.fec_remision),7,0)||
       --tot remitidos sumar de ge_cob_servicios
       lpad((select sum(monto)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision and z.fec_remision= b.fec_remision),13,0)||
       --cant no procesados de contar ge_cob_servicios con error
       lpad((select count(*)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision and z.fec_remision= b.fec_remision and estado = 'E'),7,0)||
       --tot no procesado de sumar ge_cob_servicios con error
       lpad((select sum(monto)from ge_cob_servicios z
             where z.nro_remision = b.nro_remision and z.fec_remision= b.fec_remision and estado = 'E'),13,0)||*/
       lpad(cantidad,7,0)|| --cant debitados
       lpad(tot_monto,13,0)|| --tot debitados
       lpad(tot_comision,13,0) registro,
       fec_remision,
       b.nro_remision,
       b.cod_servicio,
       'C' tipo
  from ge_cob_ser_parametros a, ge_cob_servicios_res b
  where a.cod_servicio = b.cod_servicio
--group by fec_remision
union --DETALLE
select 'D'||
       lpad(a.cod_servicio,5,0)||
       lpad(a.cod_ofi_origen,4,0)||--agencia
       lpad(a.cod_ofi_origen,4,0)||--sucursal
       to_char(fecha,'yyyymmdd')||
       lpad(monto,13,0)||
       lpad(' ',16,' ')||
      /* rpad(fug_cta_formateada(cta.cod_modulo, --no se envía la cta, sólo para pruebas, enviar 16 esp en blanco
                               cta.cod_modalidad,
                               cta.cod_oficina,
                               cta.nro_cuenta,
                               cta.cod_moneda),16,' ')||*/
       lpad(cod_persona,10,0)||
       lpad(b.nro_remision,1,0)||--ver, no puede ser de 1
       to_char(b.fec_remision,'yyyymmdd')||
       lpad(to_char(referencia1),10,0) registro,
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
-- order by nro_documento
)
order by tipo
;

