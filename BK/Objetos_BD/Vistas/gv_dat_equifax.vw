create or replace force view it.gv_dat_equifax as
Select a.fecha, 'F' tip_persona, decode(a.tip_accion,'I',14,15) tip_accion, decode(a.tip_accion,'I','ALT_PER_FISICAS','ACT_PER_FISICAS') nom_archivo,
       a.nro_cliente, a.nro_secuencia, a.nro_documento, a.pri_nombre||' '||a.pri_apellido nombre, c.nro_cuenta, 'Préstamos' tip_producto, c.cod_moneda,
       a.tip_proceso
From ge_equ_per_fisicas a, ge_equ_prestamos c
where a.fecha         = c.fecha
  and c.nro_secuencia = a.nro_secuencia(+)
union all
Select a.fecha, 'F' tip_persona, decode(a.tip_accion,'I',14,15) tip_accion, decode(a.tip_accion,'I','ALT_PER_FISICAS','ACT_PER_FISICAS') nom_archivo,
       a.nro_cliente, a.nro_secuencia, a.nro_documento, a.pri_nombre||' '||a.pri_apellido nombre, d.nro_cuenta, 'Tarjetas' tip_producto, d.cod_moneda,
       a.tip_proceso
From ge_equ_per_fisicas a, ge_equ_tarjetas d
where a.fecha         = d.fecha
  and a.nro_secuencia = d.nro_secuencia(+)
union all
Select a.fecha, 'J' tip_persona, decode(a.tip_accion,'I',14,15) tip_accion, decode(a.tip_accion,'I','ALT_PER_JURIDICAS','ACT_PER_JURIDICAS') nom_archivo,
       a.nro_cliente, a.nro_secuencia, a.nro_documento, a.nom_empresa nombre, c.nro_cuenta, 'Préstamos' tip_producto, c.cod_moneda, a.tip_proceso
From ge_equ_per_juridicas a, ge_equ_prestamos c
where a.fecha         = c.fecha
  and c.nro_secuencia = a.nro_secuencia(+)
union all
Select a.fecha, 'J' tip_persona, decode(a.tip_accion,'I',14,15) tip_accion, decode(a.tip_accion,'I','ALT_PER_JURIDICAS','ACT_PER_JURIDICAS') nom_archivo,
       a.nro_cliente, a.nro_secuencia, a.nro_documento, a.nom_empresa nombre, d.nro_cuenta, 'Tarjetas' tip_producto, d.cod_moneda, a.tip_proceso
From ge_equ_per_juridicas a, ge_equ_tarjetas d
where a.fecha         = d.fecha
  and a.nro_secuencia = d.nro_secuencia(+);

