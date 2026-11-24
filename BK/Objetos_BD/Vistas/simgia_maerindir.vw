create or replace force view it.simgia_maerindir as
select w.nro_garantia RIESGO,
'O' FILE_,
r.nuries DEUDOR,
r.congru CUENTA,
r.vencim,
r.nudoc DOCUM,
r.guaranies MONTO,
r.sucursalfu SUCURSAL,
r.propuesta PROPUE
from simgia_maecartera_f4_bkp r,
(select * from pr_cta_garantias w where w.cod_garantia = 2) w
where r.tipo in ('prestamo','afd1','afd2')
and w.nro_cuenta = r.nro_cuenta;

