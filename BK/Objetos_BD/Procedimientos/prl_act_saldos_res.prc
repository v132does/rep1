create or replace procedure it.prl_act_saldos_res
is
/* acumula los tipos de operaciones */
cursor resumen is
   select a.cod_moneda cod_moneda,  b.afe_posicion tipo,
          sum(decode(b.cod_mad_hijo,71,monto,0)) tot_compra,
          sum(decode(b.cod_mad_hijo,72,monto,0)) tot_venta
     from lc_tip_operaciones b, ge_movimientos a
    where a.cod_tip_ope_cambio = b.cod_tip_operacion
      and cod_mod_padre = 7
      and cod_mad_padre in (71,72,73,74)
      and estado = 'N'
      and reversado = 'N'
      and cod_moneda <> pag_gen.fu_obt_mon_local
      and nro_secuencia in (1,2,3,4)/*AP-630 Agrego la sec. 3*/--DYDMR-7423.-
      and b.afe_posicion <> 'N'
    group by a.cod_moneda,  b.afe_posicion;
 v_fec_actual date := pag_cal.FU_OBT_FEC_ACTUAL(7);
begin 
  delete from lc_saldos_res where fecha = v_fec_actual;
  for res in resumen loop
      insert into lc_saldos_res
           (fecha, cod_moneda, tipo, tot_compra, tot_venta)
      values
           (v_fec_actual, res.cod_moneda, res.tipo, res.tot_compra, res.tot_venta);
  end loop;
end;
/

