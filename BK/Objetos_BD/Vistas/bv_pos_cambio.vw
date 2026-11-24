create or replace force view it.bv_pos_cambio as
select --activo es negativo
 decode(x.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                  'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28) cod_divisa,
x.cod_oficina,fue_obt_des_oficina(x.cod_oficina) ofi_descripcion,
x.cod_moneda,
sum(nvl(x.activo_ext,0)) total_activo,
sum(nvl(x.pasivo_ext,0)) total_pasivo,
decode(abs(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),
(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),0) saldo_deudor,--es negativo
decode(abs(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),0,
(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0)))) saldo_acreedor,--es positivo
fug_obt_cotizacion(x.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(2)-1) cotiz,
decode(x.cod_moneda,'GS',(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),round(fug_obt_cotizacion(x.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(2)-1)*(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))))) cv_Guaranies,
--fub_con_mon_a_moneda (x.cod_moneda,'GS',(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),null,pag_cal.FU_OBT_FEC_ACTUAL(2)-1) cv_Guaranies,
sum(nvl(y.posicion_ext,0)) posicion_me,
nvl(fub_con_mon_a_moneda (y.cod_moneda,'GS',(sum(nvl(y.posicion_ext,0))),null,pag_cal.FU_OBT_FEC_ACTUAL(2)-1),0) posicion_gs

from (
        select d.cod_oficina, r.cod_moneda,r.cod_rub_externo,r.cod_rubro,

        case when substr(r.cod_rubro,1,1)=1 then--para los activos
                        (sum(nvl(d.sal_mon_rub_ant,0)+nvl(d.deb_mon_rubro,0)-nvl(d.cre_mon_rubro,0)))
                        else
                        0 end activo_ext,

        case when substr(r.cod_rubro,1,1)=2 or substr(r.cod_rubro,1,1)=3 then ---para los pasivos
                        (sum(nvl(d.sal_mon_rub_ant,0)+nvl(d.deb_mon_rubro,0)-nvl(d.cre_mon_rubro,0)))
                        else
                        0 end pasivo_ext
        from cb_sal_oficinas d, cb_rubros r
        where d.cod_rubro=r.cod_rubro
        and d.COD_RUBRO in (select r.cod_rubro ---solos los rubros activos y pasivos, son rangos que tiene la AS400
                            from cb_rubros r
                            where substr(r.cod_rubro,1,1) IN (1,2)
                            and r.imputable = 'S'
                            )
         and r.cod_moneda<>'GS'--distinto a moneda local
         group by d.cod_oficina,r.tipo ,r.cod_moneda,r.cod_rub_externo,r.cod_rubro)x,

      (
        select d.cod_oficina, r.cod_moneda,r.cod_rubro,
          (sum(nvl(d.sal_mon_loc_ant,0)+nvl(d.deb_mon_local,0)-nvl(d.cre_mon_local,0)))*-1 posicion_loc,
          (sum(nvl(d.sal_mon_rub_ant,0)+nvl(d.deb_mon_rubro,0)-nvl(d.cre_mon_rubro,0)))*-1 posicion_ext
          from cb_sal_oficinas d, cb_rubros r
          where d.cod_rubro=r.cod_rubro
          and d.COD_RUBRO in (select r.cod_rubro
                              from cb_rubros r
                              where substr(r.cod_rubro,1,8) = '51040691'
                              and r.imputable = 'S'

                             )
         and r.cod_moneda<>'GS'
         group by d.cod_oficina,r.cod_moneda,r.cod_rubro)y
 where x.cod_rubro=y.cod_rubro(+)
 and x.cod_oficina=y.cod_oficina(+)
 and x.cod_moneda=y.cod_moneda(+)
 group by x.cod_oficina,x.cod_moneda,y.cod_oficina,y.cod_moneda/*,y.posicion_ext*/
union
select --activo es negativo
decode(y.cod_moneda, 'GS', 0, 'XXX', 1, 'XXX', 2, 'XXX', 3, 'XXX', 4, 'USD', 5, 'XXX', 6, 'CHF', 7, 'XXX', 8, 'XXX', 9, 'GBP', 10,
                                  'XXX', 11, 'XXX', 12, 'XXX', 13, 'JPY', 14, 'ARS', 15, 'XXX', 16, 'EUR', 17, 'UYU', 20, 'CAD', 28) cod_divisa,
y.cod_oficina,fue_obt_des_oficina(y.cod_oficina) ofi_descripcion,
y.cod_moneda,
sum(nvl(x.activo_ext,0)) total_activo,
sum(nvl(x.pasivo_ext,0)) total_pasivo,
decode(abs(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),
(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),0) saldo_deudor,--es negativo
decode(abs(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),0,
(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0)))) saldo_acreedor,--es positivo
fug_obt_cotizacion(x.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(2)-1) cotiz,
decode(x.cod_moneda,'GS',(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),round(fug_obt_cotizacion(x.cod_moneda,pag_cal.FU_OBT_FEC_ACTUAL(2)-1)*(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))))) cv_Guaranies,
--fub_con_mon_a_moneda (x.cod_moneda,'GS',(sum(nvl(x.activo_ext,0))+sum(nvl(x.pasivo_ext,0))),null,pag_cal.FU_OBT_FEC_ACTUAL(2)-1) cv_Guaranies,
sum(nvl(y.posicion_ext,0)) posicion_me,---no se puede traer la posicion aca
fub_con_mon_a_moneda (y.cod_moneda,'GS',(sum(nvl(y.posicion_ext,0))),null,pag_cal.FU_OBT_FEC_ACTUAL(2)-1) posicion_gs

from (
        select d.cod_oficina, r.cod_moneda,r.cod_rubro,

        case when substr(r.cod_rubro,1,1)=1 then--para los activos
                        (sum(nvl(d.sal_mon_rub_ant,0)+nvl(d.deb_mon_rubro,0)-nvl(d.cre_mon_rubro,0)))
                        else
                        0 end activo_ext,

        case when substr(r.cod_rubro,1,1)=2 or substr(r.cod_rubro,1,1)=3 then ---para los pasivos
                        (sum(nvl(d.sal_mon_rub_ant,0)+nvl(d.deb_mon_rubro,0)-nvl(d.cre_mon_rubro,0)))
                        else
                        0 end pasivo_ext
        from cb_sal_oficinas d, cb_rubros r
        where d.cod_rubro=r.cod_rubro
        and d.COD_RUBRO in (select r.cod_rubro ---solos los rubros activos y pasivos, son rangos que tiene la AS400
                            from cb_rubros r
                            where substr(r.cod_rubro,1,1) IN (1,2)
                            and r.imputable = 'S'
                            )
         and r.cod_moneda<>'GS'--distinto a moneda local
         group by d.cod_oficina,r.tipo ,r.cod_moneda,r.cod_rubro)x,

      (
        select d.cod_oficina, r.cod_moneda, r.cod_rubro,
          (sum(nvl(d.sal_mon_loc_ant,0)+nvl(d.deb_mon_local,0)-nvl(d.cre_mon_local,0)))*-1 posicion_loc,
          (sum(nvl(d.sal_mon_rub_ant,0)+nvl(d.deb_mon_rubro,0)-nvl(d.cre_mon_rubro,0)))*-1 posicion_ext
          from cb_sal_oficinas d, cb_rubros r
          where d.cod_rubro=r.cod_rubro
          and d.COD_RUBRO in (select r.cod_rubro ---solos los rubros activos y pasivos, son rangos que tiene la AS400
                            from cb_rubros r
                            where substr(r.cod_rubro,1,8) = '51040691'
                            and r.imputable = 'S'

                            )
         and r.cod_moneda<>'GS'
         group by d.cod_oficina,r.cod_moneda,r.cod_rubro)y
 where x.cod_rubro(+)=y.cod_rubro
 and x.cod_oficina(+)=y.cod_oficina
 and x.cod_moneda(+)=y.cod_moneda
 group by x.cod_oficina,x.cod_moneda,y.cod_oficina,y.cod_moneda
;

