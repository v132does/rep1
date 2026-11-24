create or replace force view it.bv_inv_car_dif as
select fecha,
       modulo,
       modalidad,
       oficina,
       moneda,
       tipo_saldo,
       cod_rubro,
       cod_rubro_deb,
       cod_cargo,
       fec_desde,
       fec_hasta,
       nro_factura,
       monto,
       saldo_contable,
       devengado_total,
       dias_restantes,
       fecha_devengado,
       monto_devengado
from tmp_inv_carg_diferidos
order by cod_cargo asc, fecha_devengado asc;

