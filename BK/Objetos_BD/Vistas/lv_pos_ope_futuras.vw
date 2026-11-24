create or replace force view it.lv_pos_ope_futuras as
select lofut.cod_moneda, lofut.cod_oficina, --DYDMR-4149--Se cambia la oficina que debe traer para operaciones futuras.24/06/2016
       nvl(pos_ini.total, 0) pos_inicial,
       round(nvl(pos_ini.tot_gs,0)) pos_inicial_gs,
       -- Compras
       nvl(ope_fut.tot_compra,0) compra,
       round(nvl(ope_fut.tot_equ_compra,0)) compra_gs,
       round(nvl(ope_fut.tot_equ_compra,0))/decode(nvl(ope_fut.tot_compra,0),0,1,nvl(ope_fut.tot_compra,0)) cot_compra,
       -- Ventas
       nvl(ope_fut.tot_venta,0) venta,
       round(nvl(ope_fut.tot_equ_venta,0)) venta_gs,
       round(nvl(ope_fut.tot_equ_venta,0))/decode(nvl(ope_fut.tot_venta,0),0,1,nvl(ope_fut.tot_venta,0)) cot_venta,
       -- Posición Actual
       nvl(pos_ini.total,0) + nvl(ope_fut.tot_compra,0)
       - nvl(ope_fut.tot_venta,0) + nvl(pos_dia.monto,0) pos_actual
       --
  from  (select distinct lofut.cod_moneda, lofut.cod_oficina
           from lc_ope_futuras lofut) lofut,
       ( select sum(decode(cod_mad_padre,71,monto,monto*-1)) total,
        --
        sum( fug_obt_cotizacion(cod_moneda, fug_obt_fec_anterior(7)) *
            (decode(cod_mad_padre,71,monto,monto*-1))
           ) tot_gs,
             cod_moneda, cod_oficina
           from lc_movimientos_his
          where fecha = fug_obt_fec_anterior(7)
            and cod_mod_padre = 7
            and cod_tra_padre in (189,1899)
            and nvl(monto,0) > 0
          group by cod_moneda, cod_oficina ) pos_ini,
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
         group by cod_moneda, pal_cam.fu_obt_ofi_cambio(a.cod_oficina) ) ope_fut,
       -- SDC AP 1171 para que tome en la posicion actual los Forward que se liquidan en el dia.
       ( select f.cod_moneda, pal_cam.fu_obt_ofi_cambio(f.cod_oficina) cod_oficina,
                nvl(sum( decode(f.cod_mad_transaccion,71,monto*-1,monto) ),0 ) monto
           from lc_ope_futuras f
          where f.estado = 'L'
            and f.fec_liquidacion = pae_cnf.fu_obt_fec_actual(7)
          group by cod_moneda, pal_cam.fu_obt_ofi_cambio(f.cod_oficina)) pos_dia
 WHERE lofut.cod_oficina = pos_ini.cod_oficina(+)
   and lofut.cod_moneda = pos_ini.cod_moneda(+)
   and lofut.cod_oficina = ope_fut.cod_oficina(+)
   and lofut.cod_moneda = ope_fut.cod_moneda(+)
   and lofut.cod_oficina = pos_dia.cod_oficina(+)
   and lofut.cod_moneda = pos_dia.cod_moneda(+)
   and  (nvl(pos_ini.total,0) + nvl(ope_fut.tot_compra,0)
       - nvl(ope_fut.tot_venta,0) + nvl(pos_dia.monto,0)) <> 0
;

