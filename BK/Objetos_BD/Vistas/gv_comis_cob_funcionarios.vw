create or replace force view it.gv_comis_cob_funcionarios as
select m.fecha, m.hora, m.cod_usuario, m.nro_cuenta, m.denominacion, m.concepto,
       m.cod_tasa, tas.descripcion desc_tasa, m.val_tasa,
       it.fug_obt_des_transaccion(m.cod_mod_padre, m.cod_mad_padre, m.cod_tra_padre) desc_transaccion,
       m.cod_moneda, m.monto, m.reversado, m.fec_valor, m.hor_reversion, m.cod_usu_reversion
from it.gv_movimientos m, it.ge_cuentas c, it.ge_tasas tas
where m.nro_cuenta = c.nro_cuenta
and m.cod_tasa = tas.cod_tasa
and c.cod_sub_modalidad = 5 /*Empleados*/
and m.cod_tasa is not null --- Es cobro de Comisiones
and m.reversado = 'N' --- no esta reversado, pero puede estar devuelto
;

