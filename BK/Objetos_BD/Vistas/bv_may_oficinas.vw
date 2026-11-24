create or replace force view it.bv_may_oficinas as
select e.cod_rubro, x.cod_rub_externo, e.fecha, e.cod_oficina, 0 nro_asiento, 0 nro_linea, 0 ref, 'SALDO ANTERIOR' descripcion,
       case when nvl(e.sal_mon_rub_ant,0) >= 0 then ABS(nvl(e.sal_mon_rub_ant,0)) end deb_rubro,
       case when nvl(e.sal_mon_rub_ant,0)  < 0 then ABS(nvl(e.sal_mon_rub_ant,0)) end cre_rubro,
       case when nvl(e.sal_mon_loc_ant,0) >= 0 then ABS(nvl(e.sal_mon_loc_ant,0)) end deb_local,
       case when nvl(e.sal_mon_loc_ant,0)  < 0 then ABS(nvl(e.sal_mon_loc_ant,0)) end cre_local,
       e.sal_mon_rub_ant, e.sal_mon_loc_ant,' ' cod_usuario
  from cb_sal_oficinas_dia e, cb_rubros x
 where e.cod_rubro=x.cod_rubro
   and e.fecha=pab_may.FU_OBT_MIN_FEC

union all
select d.cod_rubro, r.cod_rub_externo, d.fecha, d.cod_oficina oficina,
       d.nro_asiento asiento, d.nro_linea lin, d.ref_movimiento ref, d.descripcion,
       (decode(d.tip_movimiento,'D',d.mto_mon_rubro,0)) deb_rubro,
       (decode(d.tip_movimiento,'C',d.mto_mon_rubro,0)) cre_rubro,
       (decode(d.tip_movimiento,'D',d.mto_mon_local,0)) deb_local,
       (decode(d.tip_movimiento,'C',d.mto_mon_local,0)) cre_local, 0,0,c.cod_usuario
 from cb_asientos_det_his d, cb_rubros r,cb_asientos_his c
where r.cod_rubro=d.cod_rubro
  and c.fecha= d.fecha
  and c.cod_oficina=d.cod_oficina
  and c.nro_asiento=d.nro_asiento

union all
--se agrega datos del día
select d.cod_rubro, r.cod_rub_externo, d.fecha, d.cod_oficina oficina,
       d.nro_asiento asiento, d.nro_linea lin, d.ref_movimiento ref, d.descripcion,
       (decode(d.tip_movimiento,'D',d.mto_mon_rubro,0)) deb_rubro,
       (decode(d.tip_movimiento,'C',d.mto_mon_rubro,0)) cre_rubro,
       (decode(d.tip_movimiento,'D',d.mto_mon_local,0)) deb_local,
       (decode(d.tip_movimiento,'C',d.mto_mon_local,0)) cre_local, 0,0,c.cod_usuario
from cb_asientos_det d, cb_rubros r,cb_asientos c
where r.cod_rubro=d.cod_rubro
  and c.fecha= d.fecha
  and c.cod_oficina=d.cod_oficina
  and c.nro_asiento=d.nro_asiento
;

