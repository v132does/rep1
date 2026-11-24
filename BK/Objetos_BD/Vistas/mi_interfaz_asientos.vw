create or replace force view it.mi_interfaz_asientos as
select c.fecha,
       to_number(to_char(c.fecha,'DD')) TDIA,
       c.cod_oficina TSUC,
       substr(trim(r.cod_rub_externo),0,6) TCTA,
       substr(trim(r.cod_rub_externo),(length(trim(r.cod_rub_externo)) - 5),6) TBSUB,
       4 TTIPO,
       decode(d.tip_movimiento,'C',01,'D',02) TCODOPE,
       70 TSER,
       d.mto_mon_local TIMPORTE,
       c.nro_asiento TNUMDOC,
       0 TVALOR,
        decode(r.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                  'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28) TDIVISA,
       trim(to_char(d.mto_mon_rubro, '999999999990.00')) TIMPORDIV,
       rownum TLINEA,
       substr(d.descripcion,0,30) TREF
  from cb_rubros r, cb_asi_automaticos c, cb_asi_automaticos_det d
 where c.fecha = d.fecha
   and c.cod_oficina= d.cod_oficina
   and c.nro_asiento= d.nro_asiento
   --and c.cod_modulo = 8 /* Solo COMEX p/Pruebas */
   and d.cod_rubro = r.cod_rubro
;

