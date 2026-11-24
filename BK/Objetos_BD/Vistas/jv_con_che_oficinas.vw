create or replace force view it.jv_con_che_oficinas as
select fecha, cod_oficina, tot_caja, tot_camara, nvl(tot_caja,0) - nvl(tot_camara,0) diferencia
from
(
select fecha, cod_oficina, sum(decode(tipo,'CAJA', tot_caja,0)) tot_caja,
sum(decode(tipo,'CAMARA', tot_caja,0)) tot_camara
from (
select 'CAJA' tipo,cod_oficina,  fecha, /*nro_caja,*/ sum(monto) tot_caja
from
(
select fecha, cod_oficina, /*nro_caja,*/ cod_moneda, tip_monto, sum(monto) monto
from cj_movimientos_his
where estado = 'N'
and tipo = 'D'
and tip_monto in ('O')
and cod_moneda = 'GS'
group by fecha,cod_oficina, /*nro_caja,*/ cod_moneda, tip_monto
union
select pag_cal.FU_OBT_FEC_SIG_HAB(fecha,cod_oficina,1) fecha,cod_oficina, /*nro_caja,*/ cod_moneda, tip_monto, sum(monto) monto
from cj_movimientos_his
where estado = 'N'
and tipo = 'D'
and tip_monto in ('T','S')
and cod_moneda = 'GS'
group by  fecha, cod_oficina, /*nro_caja,*/ cod_moneda, tip_monto
)
group by fecha, cod_oficina /*nro_caja*/
UNION ALL
select 'CAMARA', a.cod_ofi_origen cod_oficina,   fecha, /*nro_caja caj_lectora,*/ sum(monto) tot_lectora
from cc_che_remitidos_res a
group by cod_ofi_origen, fecha /*nro_caja*/
)
group by fecha, cod_oficina /*nro_caja*/
)
order by cod_oficina;

