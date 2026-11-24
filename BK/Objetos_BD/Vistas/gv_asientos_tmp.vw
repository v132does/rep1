create or replace force view it.gv_asientos_tmp as
select a.fecha,
a.hora,
a.cod_usuario,
a.nro_secuencia,
a.cod_ofi_origen,
a.cod_mod_padre,
a.cod_mad_padre,
a.tip_mov_rubro,
a.cod_rubro,
a.cod_moneda,
a.monto,
a.cotizacion,
a.mto_equ_local,
a.observacion,
a.usu_insercion,
a.nro_asiento,
a.nro_linea,
a.cod_tra_padre,
b.descripcion des_tra_padre,
a.cod_modulo,
a.cod_modalidad,
a.cod_oficina,
a.cod_transaccion,
c.descripcion des_transaccion,
a.nro_cuenta,
fue_obt_des_oficina(a.cod_ofi_origen) des_ofi_origen,
fub_obt_des_cta_contable(a.cod_rubro) des_rubro,
fue_obt_nom_usuario(a.cod_usuario) nom_usuario
from ge_transacciones c, ge_transacciones b, ge_asientos_tmp a
where a.cod_tra_padre = b.cod_transaccion(+)
and a.cod_mod_padre = b.cod_modulo(+)
and a.cod_mad_padre = b.cod_modalidad(+)
and a.cod_transaccion = c.cod_transaccion(+)
and a.cod_modulo = c.cod_modulo(+)
and a.cod_modalidad = c.cod_modalidad(+);

