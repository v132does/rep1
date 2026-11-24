create or replace force view it.simgia_olfitok as
select a.cod_usuario ITOKUSU, a.hora ITOKHORA, a.nro_secuencia ITOKSEQ
/*, to_char(a.fecha,'yymmdd') fecha ,
TRIM(TO_CHAR(COD_MAD_PADRE,'000'))||SUBSTR(TRIM(TO_CHAR(cod_tra_padre,'0000')),2,3) transaccion,
a.nro_cuenta,
substr(a.nro_cuenta, -6) subcuenta,
case
when a.cod_modalidad = 41 and a.cod_moneda = 'GS' then
     '210100'
when a.cod_modalidad = 31 and a.cod_moneda = 'GS' then
     '210500'
when a.cod_modalidad = 41 and a.cod_moneda <> 'GS' then
     '215000'
when a.cod_modalidad = 31 and a.cod_moneda <> 'GS' then
     '215500'
end cta,
lpad(a.COD_OFICINA,2,'0') suc,
decode(a.cod_moneda,'GS','0','USD','5','EUR','17') cod_moneda,
b.tipo, a.monto, a.nro_documento,  a.cotizacion, a.mto_equ_local,
a.concepto, a.referencia, a.estado*/
from ge_transacciones b, ge_movimientos a
where a.cod_modalidad in (31,41)
and a.nro_cuenta is not null
and a.monto <> 0
and a.reversado = 'N'
and a.estado = 'N'
and a.cod_transaccion not in (515,565)
and a.cod_modulo = b.cod_modulo
and a.cod_modalidad = b.cod_modalidad
and a.cod_transaccion = b.cod_transaccion
and b.tipo in ('D','C')
and b.afecta = 'S';

