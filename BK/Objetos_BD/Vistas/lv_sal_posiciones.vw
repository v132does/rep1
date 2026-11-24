create or replace force view it.lv_sal_posiciones as
select a.cod_moneda cod_moneda, 'MOVIMIENTOS' referencia, b.afe_posicion tipo,
          (decode(b.cod_mad_hijo,71,monto,0)) mto_compra,
          (decode(b.cod_mad_hijo,72,monto,0)) mto_venta,
          a.hora,a.cod_usuario,a.nro_secuencia,a.cod_oficina,a.nro_documento
     from lc_tip_operaciones b, gv_movimientos a
    where a.FECHA = pag_cal.FU_OBT_FEC_ANTERIOR(1)--FU_OBT_FEC_ACTUAL(1)
      --and a.TIPO = 'H'
      and a.cod_tip_ope_cambio = b.cod_tip_operacion
      and cod_mod_padre = 7
      and cod_mad_padre in (71,72,73,74)
      and estado = 'N'
      and reversado = 'N'
      and cod_moneda <> pag_gen.fu_obt_mon_local
      and nro_secuencia in (1,2,3)
      and b.afe_posicion <> 'N'
union all
select cod_moneda, 'ANTERIOR' referencia, tip_posicion, mto_nef_compra, mto_nef_venta,
       null, null, null, null, null
  from lc_sal_posiciones_ant b
 where tip_posicion = 'O'
union all
select cod_moneda, 'ANTERIOR' referencia, tip_posicion, mto_efe_compra, mto_efe_venta,
       null, null, null, null, null
 from lc_sal_posiciones_ant b
where tip_posicion = 'E'
;

