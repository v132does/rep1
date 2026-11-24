create or replace force view it.xv_dep_overnight as
select c.nro_cuenta, c.cod_moneda, c.cod_oficina, nvl(b.ind_grupo,'N') ind_grupo,
          a.cod_modulo, a.cod_modalidad, c.monto, c.fecha
   from   cc_cta_bancarias a, ge_bancos b, cx_dep_overnight c
   where  a.cod_banco = b.cod_banco
   and    a.nro_cuenta = c.nro_cuenta
   union
   select c.nro_cuenta, c.cod_moneda, c.cod_oficina, nvl(b.ind_grupo,'N') ind_grupo,
          a.cod_modulo, a.cod_modalidad, c.monto, c.fecha
   from   cc_cta_bancarias a, ge_bancos b, cx_dep_overnight_his c
   where  a.cod_banco = b.cod_banco
   and    a.nro_cuenta = c.nro_cuenta;

