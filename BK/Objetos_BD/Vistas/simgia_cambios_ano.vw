create or replace force view it.simgia_cambios_ano as
select xx.cod_persona,
       sum(xx.compra) compra,
       sum(xx.venta) venta,
       sum(xx.can_compra) can_compra,
       sum(xx.can_venta) can_venta,
       sum(xx.acumulado_ano) acumulado_ano,
       xx.cod_moneda,
       xx.ano,
       xx.tipo
  from (
        -- CC_MOVIMIENTOS_HIS - ITGF
        select lm.cod_persona cod_persona,
                sum(decode(o.cod_mad_hijo, 71, lm.monto, 0)) compra,
                sum(decode(o.cod_mad_hijo, 72, lm.monto, 0)) venta,
                sum(decode(o.cod_mad_hijo, 71, 1, 0)) can_compra,
                sum(decode(o.cod_mad_hijo, 72, 1, 0)) can_venta,
                sum(lm.monto) acumulado_ano,
                lm.cod_moneda cod_moneda,
                to_char(lm.fecha, 'yyyy') ano,
                'ITGF' tipo
          from cc_movimientos_his lm, lc_tip_operaciones o
         where lm.cod_tip_ope_cambio = o.cod_tip_operacion
           and lm.cod_persona is not null
           and lm.cod_mad_padre in (71, 72, 73)
           and lm.cod_mod_padre = 7
           and lm.nro_secuencia in (1, 2)
           and lm.reversado = 'N'
           and lm.estado = 'N'
         group by lm.cod_persona, lm.cod_moneda, to_char(lm.fecha, 'yyyy')
        union all
        -- AH_MOVIMIENTOS_HIS - ITGF
        select lm.cod_persona cod_persona,
                sum(decode(o.cod_mad_hijo, 71, lm.monto, 0)) compra,
                sum(decode(o.cod_mad_hijo, 72, lm.monto, 0)) venta,
                sum(decode(o.cod_mad_hijo, 71, 1, 0)) can_compra,
                sum(decode(o.cod_mad_hijo, 72, 1, 0)) can_venta,
                sum(lm.monto) acumulado_ano,
                lm.cod_moneda cod_moneda,
                to_char(lm.fecha, 'yyyy') ano,
                'ITGF' tipo
          from ah_movimientos_his lm, lc_tip_operaciones o
         where lm.cod_tip_ope_cambio = o.cod_tip_operacion
           and lm.cod_persona is not null
           and lm.cod_mad_padre in (71, 72, 73)
           and lm.cod_mod_padre = 7
           and lm.nro_secuencia in (1, 2)
           and lm.reversado = 'N'
           and lm.estado = 'N'
         group by lm.cod_persona, lm.cod_moneda, to_char(lm.fecha, 'yyyy')
        union all
        -- LC_MOVIMIENTOS_HIS - ITGF
        select lm.cod_persona cod_persona,
                sum(decode(o.cod_mad_hijo, 71, lm.monto, 0)) compra,
                sum(decode(o.cod_mad_hijo, 72, lm.monto, 0)) venta,
                sum(decode(o.cod_mad_hijo, 71, 1, 0)) can_compra,
                sum(decode(o.cod_mad_hijo, 72, 1, 0)) can_venta,
                sum(lm.monto) acumulado_ano,
                lm.cod_moneda cod_moneda,
                to_char(lm.fecha, 'yyyy') ano,
                'ITGF' tipo
          from lc_movimientos_his lm, lc_tip_operaciones o
         where lm.cod_tip_ope_cambio = o.cod_tip_operacion
           and lm.cod_persona is not null
           and lm.cod_mad_padre in (71, 72, 73)
           and lm.cod_mod_padre = 7
           and lm.nro_secuencia in (1, 2)
           and lm.reversado = 'N'
           and lm.estado = 'N'
         group by lm.cod_persona, lm.cod_moneda, to_char(lm.fecha, 'yyyy')
        ) xx
 group by xx.cod_persona, xx.cod_moneda, xx.ano, xx.tipo
;

