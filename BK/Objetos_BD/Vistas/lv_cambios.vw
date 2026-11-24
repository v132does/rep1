create or replace force view it.lv_cambios as
select fecha, hora, cod_usuario, monto, cod_moneda,
mto_equ_local equ_loc, cotizacion cot_ope,
pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) cot_bcp,
round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0) equ_bcp,
decode(cod_modalidad,71,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0)),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0)-mto_equ_local),
72,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) *
monto,0)),mto_equ_local,mto_equ_local-round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0))) ganancia,
decode(cod_modalidad,71,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) *
monto,0)),mto_equ_local,mto_equ_local-round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0)),
72,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0)),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0)-mto_equ_local)) perdida,
nro_caja, cod_oficina, cod_rubro, cod_ofi_origen, cod_transaccion,
cod_modalidad, concepto,
cod_modulo, cod_mod_padre, cod_mad_padre, cod_tra_padre, estado, reversado,
cod_tip_ope_cambio, nro_documento, nro_documento3
from ge_movimientos
where cod_mod_padre = 7
and cod_modalidad in (71,72)
and cod_moneda <> pag_gen.fu_obt_mon_local
and reversado = 'N'
UNION
select fecha, hora, cod_usuario, monto, cod_moneda,
mto_equ_local equ_loc, cotizacion cot_ope,
pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) cot_bcp,
round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0) equ_bcp,
decode(cod_modalidad,71,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0)),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0)-mto_equ_local),
72,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) *
monto,0)),mto_equ_local,mto_equ_local-round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0))) ganancia,
decode(cod_modalidad,71,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) *
monto,0)),mto_equ_local,mto_equ_local-round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0)),
72,
decode(greatest(mto_equ_local,round(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha) * monto,0)),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0),round(nvl(pag_gen.FU_OBT_COTIZACION(cod_moneda,fecha),0) *
monto,0)-mto_equ_local)) perdida,
nro_caja, cod_oficina, cod_rubro, cod_ofi_origen, cod_transaccion,
cod_modalidad, concepto,
cod_modulo, cod_mod_padre, cod_mad_padre, cod_tra_padre, estado, reversado,
cod_tip_ope_cambio, nro_documento, nro_documento3
from LC_movimientos_HIS
where cod_mod_padre = 7
and cod_modalidad in (71,72)
and cod_moneda <> pag_gen.fu_obt_mon_local
and reversado = 'N'
order by 1,2,3;

