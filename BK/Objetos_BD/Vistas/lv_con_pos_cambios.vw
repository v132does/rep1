create or replace force view it.lv_con_pos_cambios as
select pos_ini.cod_moneda, pos_ini.cod_oficina,
       pos_ini.total pos_inicial,
       round(pos_ini.tot_gs) pos_inicial_gs,
       -- Compras --
       nvl(con.tot_compra,0) + nvl(pen.tot_compra,0) + nvl(ope_fut.tot_compra,0)+ nvl(hb_con.tot_compra,0) compra,
       round(nvl(con.tot_equ_compra,0) + nvl(pen.tot_equ_compra,0) + nvl(ope_fut.tot_equ_compra,0)+ nvl(hb_con.tot_equ_compra,0)) compra_gs,
       -- Ventas
       nvl(con.tot_venta,0) + nvl(pen.tot_venta,0) + nvl(ope_fut.tot_venta,0)+ nvl(hb_con.tot_venta,0) venta,
       round(nvl(con.tot_equ_venta,0) + nvl(pen.tot_equ_venta,0) + nvl(ope_fut.tot_equ_venta,0)+nvl(hb_con.tot_equ_venta,0)) venta_gs,
       -- Posición Actual
       nvl(pos_ini.total,0) + nvl(con.tot_compra,0) + nvl(pen.tot_compra,0)+ nvl(ope_fut.tot_compra,0)+ nvl(hb_con.tot_compra,0)
       - nvl(con.tot_venta,0) - nvl(pen.tot_venta,0) - nvl(ope_fut.tot_venta,0)- nvl(hb_con.tot_venta,0) pos_act
       --
  from ( select mo.cod_moneda, pal_cam.fu_obt_ofi_cambio(mo.cod_ofi_origen) cod_oficina,
                nvl(sum( decode(o.cod_mad_hijo,71,monto) ),0 ) tot_compra,
                nvl(sum( decode(o.cod_mad_hijo,72,monto) ),0 ) tot_venta,
                --
                nvl(sum( decode(o.cod_mad_hijo,71,monto*cotizacion) ),0 ) tot_equ_compra,
                nvl(sum( decode(o.cod_mad_hijo,72,monto*cotizacion) ),0 ) tot_equ_venta
           from ge_movimientos mo, lc_tip_operaciones o
          where mo.cod_mod_padre = 7
            and mo.cod_mad_padre in (71,72,73)
            and mo.reversado = 'N'
            and mo.nro_secuencia in (1,2)
            and mo.estado in ('N','J','H','X','P')
            and o.afe_posicion <> 'N'
            and mo.cod_tip_ope_cambio = o.cod_tip_operacion
          group by mo.cod_moneda, pal_cam.fu_obt_ofi_cambio(mo.cod_ofi_origen)) con,
      -- Operaciones del homebanking--
      ( select mo.cod_moneda, pal_cam.fu_obt_ofi_cambio(mo.cod_ofi_origen) cod_oficina,
                      nvl(sum( decode(mo.cod_transaccion,503,mo.monto) ),0 ) tot_compra,
                      nvl(sum( decode(mo.cod_transaccion,602,mo.monto) ),0 ) tot_venta,
                      --
                      nvl(sum( decode(mo.cod_transaccion,503,mo.monto*mo.cotizacion) ),0 ) tot_equ_compra,
                      nvl(sum( decode(mo.cod_transaccion,602,mo.monto*mo.cotizacion) ),0 ) tot_equ_venta
                 from ge_movimientos mo, ge_movimientos mo2
                where mo.cod_mod_padre = 9
                  and mo.cod_mad_padre in (91)
                  and mo.reversado = 'N'
                 and mo.cod_tra_padre=388
                  and mo.cod_moneda<>pag_gen.FU_OBT_MON_LOCAL
                  and mo.estado in ('N','J','H','X','P')
                  and mo.fecha=mo2.fecha
                  and mo.hora=mo2.hora
                  and mo.cod_usuario=mo2.cod_usuario
                  and mo.cod_moneda<>mo2.cod_moneda
                  and mo.nro_secuencia<>mo2.nro_secuencia
                  and mo.cod_tra_padre=mo2.cod_tra_padre -- DYDMR-2073
                  and mo2.monto <> 0  -- DYDMR-3777
        group by mo.cod_moneda, pal_cam.fu_obt_ofi_cambio(mo.cod_ofi_origen)) hb_con,

       --
       (
         select x.cod_moneda, x.cod_oficina,
                sum(nvl(x.tot_compra,0)) tot_compra,
                sum(nvl(x.tot_venta,0)) tot_venta,
                sum(nvl(x.tot_equ_compra,0)) tot_equ_compra,
                sum(nvl(x.tot_equ_venta,0)) tot_equ_venta
         from
         (select cod_moneda, pal_cam.fu_obt_ofi_cambio(ope.cod_oficina) cod_oficina,
                nvl(sum( decode(cod_mad_hijo,71,monto) ),0) tot_compra,
                nvl(sum( decode(cod_mad_hijo,72,monto) ),0) tot_venta,
                --
                nvl(sum( decode(cod_mad_hijo,71,monto*cotizacion) ),0) tot_equ_compra,
                nvl(sum( decode(cod_mad_hijo,72,monto*cotizacion) ),0) tot_equ_venta
           from lc_ope_pendientes ope,
                lc_tip_operaciones o
          where ope.cod_tip_operacion = o.cod_tip_operacion
            and ope.liquidado = 'N'
             and o.cod_modulo = 7
            and o.afe_posicion <> 'N'
          group by cod_moneda, pal_cam.fu_obt_ofi_cambio(ope.cod_oficina)
          union all
         select cod_moneda, pal_cam.fu_obt_ofi_cambio(ope.cod_oficina) cod_oficina,
                nvl(sum( decode(cod_mad_hijo,71,monto) ),0) tot_compra,
                nvl(sum( decode(cod_mad_hijo,72,monto) ),0) tot_venta,
                --
                nvl(sum( decode(cod_mad_hijo,71,monto*cotizacion) ),0) tot_equ_compra,
                nvl(sum( decode(cod_mad_hijo,72,monto*cotizacion) ),0) tot_equ_venta
           from lc_ope_pen_cambios ope,
                lc_tip_operaciones o
          where ope.cod_tip_operacion = o.cod_tip_operacion
            and ope.liquidado = 'N'
             and o.cod_modulo = 7
            and o.afe_posicion <> 'N'
          group by cod_moneda, pal_cam.fu_obt_ofi_cambio(ope.cod_oficina)) x
          group by x.cod_moneda, x.cod_oficina
           ) pen,
       --
       ( select sum( decode(lc_sal_posiciones.tip_posicion,'E',
                     (nvl(lc_sal_posiciones.mto_efe_compra,0) - nvl(lc_sal_posiciones.mto_efe_venta,0)),
                     (nvl(lc_sal_posiciones.mto_nef_compra,0) - nvl(lc_sal_posiciones.mto_nef_venta,0)))
                   ) total,
                 --
                 sum(decode(lc_sal_posiciones.tip_posicion,'E',nvl(lc_sal_posiciones.cot_efectivo,0),
                     nvl(lc_sal_posiciones.cot_no_efectivo,0)) *
                    decode(lc_sal_posiciones.tip_posicion,'E',
                     (nvl(lc_sal_posiciones.mto_efe_compra,0) - nvl(lc_sal_posiciones.mto_efe_venta,0)),
                     (nvl(lc_sal_posiciones.mto_nef_compra,0) - nvl(lc_sal_posiciones.mto_nef_venta,0)))
                    ) tot_gs,
                cod_moneda, cod_ofi_cambio cod_oficina
           from lc_sal_posiciones
          group by cod_moneda, cod_ofi_cambio ) pos_ini,
        --
       ( select cod_moneda, pal_cam.fu_obt_ofi_cambio(a.cod_oficina) cod_oficina,
               nvl(sum( decode(a.cod_mad_transaccion,71,monto) ),0 ) tot_compra,
               nvl(sum( decode(a.cod_mad_transaccion,72,monto) ),0 ) tot_venta,
               --
               nvl(sum( decode(a.cod_mad_transaccion,71,monto*cotizacion) ),0 ) tot_equ_compra,
               nvl(sum( decode(a.cod_mad_transaccion,72,monto*cotizacion) ),0 ) tot_equ_venta
          from lc_ope_futuras a
         where a.estado = 'N'
           and a.fec_est_activo = pae_cnf.fu_obt_fec_actual(7)
         group by cod_moneda, pal_cam.fu_obt_ofi_cambio(a.cod_oficina) ) ope_fut
 WHERE pos_ini.cod_moneda = pen.cod_moneda (+)
   and pos_ini.cod_oficina = pen.cod_oficina (+)
   and pos_ini.cod_moneda = con.cod_moneda (+)
   and pos_ini.cod_oficina = con.cod_oficina(+)
   and pos_ini.cod_oficina = ope_fut.cod_oficina(+)
   and pos_ini.cod_moneda = ope_fut.cod_moneda(+)
	 and pos_ini.cod_oficina = hb_con.cod_oficina(+)
   and pos_ini.cod_moneda = hb_con.cod_moneda(+)
;

