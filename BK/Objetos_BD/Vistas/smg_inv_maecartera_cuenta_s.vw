create or replace force view it.smg_inv_maecartera_cuenta_s as
select
'S' tip_saldo,
cod_oficina sucursalfu,
'' nuries,
'' numero_cuenta_it_it,
'' numero_cuenta_it_as,
'GS'cod_moneda,
''nombre,
''rubro_as,
''cod_rub_externo,
0 saldo_maecartera,
0 saldo_maeicpc,
0 saldo_maecartera_maeicpc,
0 saldo_it,
0 dif_saldo,
'NO' diferencia_rubro

FROM ba_oficinas;

