create or replace force view it.gv_cam_estados as
select a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_oficina,
       a.cod_moneda,
       a.fecha,
       a.hora,
       d.cod_telegrama,
       d.cod_causa,
       e.cod_usu_oficial
  from ge_movimientos     a,
       ge_telegramas      d,
       ge_clientes        e,
       ge_log_pag_nominas b
 where a.nro_documento   = d.cod_telegrama
   and d.cod_persona     = e.cod_persona
   and a.nro_cuenta      = b.nro_cuenta (+)
   and a.cod_modalidad   in (31, 41)
   and a.cod_transaccion in (405, 406)

union all

select a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_oficina,
       a.cod_moneda,
       a.fecha,
       a.hora,
       d.cod_telegrama,
       d.cod_causa,
       e.cod_usu_oficial
  from cc_movimientos_his a,
       ge_telegramas      d,
       ge_clientes        e,
       ge_log_pag_nominas b
 where a.nro_documento   = d.cod_telegrama
   and d.cod_persona     = e.cod_persona
   and a.nro_cuenta      = b.nro_cuenta (+)
   and a.cod_transaccion in (405, 406)

union all

select a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_oficina,
       a.cod_moneda,
       a.fecha,
       a.hora,
       d.cod_telegrama,
       d.cod_causa,
       e.cod_usu_oficial
  from ah_movimientos_his a,
       ge_telegramas      d,
       ge_clientes        e,
       ge_log_pag_nominas b
 where a.nro_documento   = d.cod_telegrama
   and d.cod_persona     = e.cod_persona
   and a.nro_cuenta      = b.nro_cuenta(+)
   and a.cod_transaccion in (405, 406)

union all

select a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_oficina,
       a.cod_moneda,
       a.fecha,
       a.hora,
       null cod_telegrama,
       decode(a.cod_modulo, 4, (select cod_cau_cancelacion from cc_cta_corrientes c where nro_cuenta = a.nro_cuenta),
                            3, (select cod_cau_cancelacion from ah_cta_vistas where nro_cuenta = a.nro_cuenta),
                            null) cod_causa,
       e.cod_usu_oficial
  from ah_movimientos_his a,
       ge_cta_clientes    c,
       ge_clientes        e
 where a.nro_cuenta      = c.nro_cuenta
   and c.cod_persona     = e.cod_persona
   and a.cod_modalidad   = 31
   and a.cod_transaccion in (405, 406)

union all

select a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_oficina,
       a.cod_moneda,
       a.fecha,
       a.hora,
       null cod_telegrama,
       decode(a.cod_modulo, 4, (select cod_cau_cancelacion from cc_cta_corrientes c where nro_cuenta = a.nro_cuenta),
                            3, (select cod_cau_cancelacion from ah_cta_vistas where nro_cuenta = a.nro_cuenta),
                            null) cod_causa,
       e.cod_usu_oficial
  from cc_movimientos_his a,
       ge_cta_clientes    c,
       ge_clientes        e
 where a.nro_cuenta      = c.nro_cuenta
   and c.cod_persona     = e.cod_persona
   and a.cod_modalidad   = 41
   and a.cod_transaccion in (405, 406)

union all

select a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_oficina,
       a.cod_moneda,
       a.fecha,
       a.hora,
       null cod_telegrama,
       decode(a.cod_modulo, 4, (select cod_cau_cancelacion from cc_cta_corrientes c where nro_cuenta = a.nro_cuenta),
                            3, (select cod_cau_cancelacion from ah_cta_vistas       where nro_cuenta = a.nro_cuenta),
                            null) cod_causa,
       e.cod_usu_oficial
  from ge_movimientos  a,
       ge_cta_clientes c,
       ge_clientes     e
 where a.nro_cuenta      = c.nro_cuenta
   and c.cod_persona     = e.cod_persona
   and a.cod_modalidad   in (31, 41)
   and a.cod_transaccion in (405, 406);

