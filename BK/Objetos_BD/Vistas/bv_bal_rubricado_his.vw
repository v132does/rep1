create or replace force view it.bv_bal_rubricado_his as
select cuenta, descripcion, moneda, saldo mo, saldo_mn mn, equ_dolares equivalente, rownum secuencia--, 3 orden, rownum fila
from (select xx.rub_btw as Cuenta,
       'Rubro ITGF' as Descripcion,
       case
         when xx.itgf_mon = 'GS' then
              'PYG'
          else xx.itgf_mon
            end moneda,
       case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         else
          sum(xx.saldo_me)
       end saldo,
       case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         else
           sum(xx.acum_cre_ml - xx.acum_deb_ml)
       end Saldo_MN,
       case
         when xx.btw_moneda = '6900' then
          round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', pag_cal.fu_obt_fec_anterior(2)),2)
         when xx.btw_moneda = '1' then
          sum(xx.saldo_me)
         else
          round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', pag_cal.fu_obt_fec_anterior(2)),2)
       end equ_dolares
  from (select '0' || substr(k.cod_rub_padre, 1, 5) bcp1,
               pac_mig.FU_OBT_RUB_BTW_INT(k.cod_rubro) as rub_int_btw,
               k.cod_rub_externo as rub_btw,
               pag_mig.FU_OBT_COD_BANTOTAL(k.cod_moneda,'BA_MONEDAS') as btw_moneda,
               decode(substr(k.cod_rubro, 1, 1), 6, 'PYG', 7, 'PYG', k.cod_moneda) as itgf_mon,
               k.Descripcion Descripcion,
               (nvl(s.sal_mon_rub_ant, 0) + nvl(s.deb_mon_rubro, 0) -
               nvl(s.cre_mon_rubro, 0)) * -1 saldo_me,
               case
                 when (nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0)) > 0 then
                  abs(nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0))
                 else
                  0
               end acum_deb_ml,
               case
                 when (nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0)) < 0 then
                  abs(nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0))
                 else
                  0
               end acum_cre_ml,
               k.cod_rubro,
               k.cod_rub_padre,
               k.cod_moneda,
               s.fecha,
               'Balance Abierto' Tip_Balance
          from cb_sal_consolidados_dia s, cb_rubros k
         where s.cod_rubro = k.cod_rubro
           and k.imputable = 'S'
           and s.fecha = pag_cal.fu_obt_fec_anterior(2)
           and abs(nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) - nvl(s.cre_mon_local, 0)) <> 0
         order by 3) xx
 group by xx.rub_btw, xx.btw_moneda, xx.itgf_mon
 having case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
        else
          sum(xx.saldo_me)
       end +
       case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         else
           sum(xx.acum_cre_ml - xx.acum_deb_ml)
       end  +
       case
         when xx.btw_moneda = '6900' then
          round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', pag_cal.fu_obt_fec_anterior(2)),2)
         when xx.btw_moneda = '1' then
          sum(xx.saldo_me)
         else
           round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                 fug_obt_cotizacion('USD', pag_cal.fu_obt_fec_anterior(2)),2)
       end <> 0) sc
;

