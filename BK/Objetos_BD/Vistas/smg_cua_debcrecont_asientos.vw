CREATE OR REPLACE FORCE VIEW IT.SMG_CUA_DEBCRECONT_ASIENTOS AS
select b.cod_oficina, a.cod_rubro,  monto_as, monto_it, monto_as - monto_it diff
  from (SELECT s.itsuc, r.cod_rubro, sum(s.itmonto) monto_as
    from simgia_debcrecont s, cb_rubros r
    where s.itsuc <> 0
    and s.itcta is not null
    and r.cod_rub_externo = to_char(s.itcta)
    and s.itmonto > 0
    group by s.itsuc, r.cod_rubro) a,
   (select c.cod_oficina, c.cod_rubro, sum(mto_mon_local) monto_it
   from cb_asientos_det c, cb_asientos o
   where o.cod_usuario = 'MIGRA'
   and o.nro_asiento = c.nro_asiento
   and o.cod_oficina = c.cod_oficina
   group by c.cod_oficina, c.cod_rubro) b
where a.cod_rubro = b.cod_rubro
and a.itsuc = b.cod_oficina;

