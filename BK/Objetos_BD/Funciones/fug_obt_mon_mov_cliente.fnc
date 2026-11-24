CREATE OR REPLACE FUNCTION IT.FUG_OBT_MON_MOV_CLIENTE( P_COD_PERSONA IN VARCHAR2 )
RETURN NUMBER IS
       v_cod_mon_fuerte    ba_monedas.cod_moneda%type;
       v_monto             gv_movimientos.MONTO%type;
       v_fec_desde         date;
       v_fec_hasta         date;
       v_cod_gru_tra       ge_gru_transacciones.cod_gru_transaccion%type;
       v_monto2            number;
cursor grupo is
  select distinct cod_modulo
    from ge_gru_transacciones_det
   where cod_gru_transaccion = v_cod_gru_tra and cod_modulo =7;--prueba
BEGIN
   v_cod_mon_fuerte := pag_gen.FU_OBT_MON_FUERTE;
   v_fec_desde      := to_date( '01/'||to_char( fue_obt_fec_calendar(1), 'MM/YYYY' ), 'DD/MM/YYYY' );
   v_fec_hasta      := last_day(v_fec_desde);
   v_cod_gru_tra    := fug_obt_pardinamico('GRU_TRA_MRC');
   for rg in grupo loop
      if rg.cod_modulo = 3 then
        select sum( decode( m.COD_MONEDA, v_cod_mon_fuerte, m.MONTO, pag_gen.fu_con_mon_a_moneda( m.COD_MONEDA,
                                                                                           v_cod_mon_fuerte,
                                                                                           m.MONTO,
                                                                                           null) ) )
          into v_monto2
          from ah_movimientos_his m,  ge_gru_transacciones_det t, ge_cta_clientes c
         where m.FECHA between v_fec_desde and v_fec_hasta
           and c.cod_persona = p_cod_persona
           and c.relacion = 'P'
           and t.cod_gru_transaccion = v_cod_gru_tra
           and t.cod_modulo = rg.cod_modulo
           and m.REVERSADO = 'N'
           and m.estado = 'N'
           and m.nro_cuenta = c.nro_cuenta
           and m.COD_MODULO = t.cod_modulo
           and m.COD_MODALIDAD = t.cod_modalidad
           and m.COD_TRANSACCION = t.cod_transaccion;
      elsif rg.cod_modulo = 4 then
        select sum( decode( m.COD_MONEDA, v_cod_mon_fuerte, m.MONTO, pag_gen.fu_con_mon_a_moneda( m.COD_MONEDA,
                                                                                           v_cod_mon_fuerte,
                                                                                           m.MONTO,
                                                                                           null) ) )
          into v_monto2
          from cc_movimientos_his m,  ge_gru_transacciones_det t, ge_cta_clientes c
         where m.FECHA between v_fec_desde and v_fec_hasta
           and c.cod_persona = p_cod_persona
           and c.relacion = 'P'
           and t.cod_gru_transaccion = v_cod_gru_tra
           and t.cod_modulo = rg.cod_modulo
           and m.REVERSADO = 'N'
           and m.estado = 'N'
           and m.nro_cuenta = c.nro_cuenta
           and m.COD_MODULO = t.cod_modulo
           and m.COD_MODALIDAD = t.cod_modalidad
           and m.COD_TRANSACCION = t.cod_transaccion;
      elsif rg.cod_modulo = 5 then
        select sum( decode( m.COD_MONEDA, v_cod_mon_fuerte, m.MONTO, pag_gen.fu_con_mon_a_moneda( m.COD_MONEDA,
                                                                                           v_cod_mon_fuerte,
                                                                                           m.MONTO,
                                                                                           null) ) )
          into v_monto2
          from ta_movimientos_his m,  ge_gru_transacciones_det t, ge_cta_clientes c
         where m.FECHA between v_fec_desde and v_fec_hasta
           and c.cod_persona = p_cod_persona
           and c.relacion = 'P'
           and t.cod_gru_transaccion = v_cod_gru_tra
           and t.cod_modulo = rg.cod_modulo
           and m.REVERSADO = 'N'
           and m.estado = 'N'
           and m.nro_cuenta = c.nro_cuenta
           and m.COD_MODULO = t.cod_modulo
           and m.COD_MODALIDAD = t.cod_modalidad
           and m.COD_TRANSACCION = t.cod_transaccion;
      elsif rg.cod_modulo = 6 then
        select sum( decode( m.COD_MONEDA, v_cod_mon_fuerte, m.MONTO, pag_gen.fu_con_mon_a_moneda( m.COD_MONEDA,
                                                                                           v_cod_mon_fuerte,
                                                                                           m.MONTO,
                                                                                           null) ) )
          into v_monto2
          from pr_movimientos_his m,  ge_gru_transacciones_det t, ge_cta_clientes c
         where m.FECHA between v_fec_desde and v_fec_hasta
           and c.cod_persona = p_cod_persona
           and c.relacion = 'P'
           and t.cod_gru_transaccion = v_cod_gru_tra
           and t.cod_modulo = rg.cod_modulo
           and m.REVERSADO = 'N'
           and m.estado = 'N'
           and m.nro_cuenta = c.nro_cuenta
           and m.COD_MODULO = t.cod_modulo
           and m.COD_MODALIDAD = t.cod_modalidad
           and m.COD_TRANSACCION = t.cod_transaccion;
      elsif rg.cod_modulo = 7 then
        select sum( decode( m.COD_MONEDA, v_cod_mon_fuerte, m.MONTO, pag_gen.fu_con_mon_a_moneda( m.COD_MONEDA,
                                                                                           v_cod_mon_fuerte,
                                                                                           m.MONTO,
                                                                                           null) ) )
          into v_monto2
          from lc_movimientos_his m,  ge_gru_transacciones_det t, ge_cta_clientes c
         where m.FECHA between v_fec_desde and v_fec_hasta
           and c.cod_persona = p_cod_persona
           and c.relacion = 'P'
           and t.cod_gru_transaccion = v_cod_gru_tra
           and t.cod_modulo = rg.cod_modulo
           and m.REVERSADO = 'N'
           and m.estado = 'N'
           and m.nro_cuenta = c.nro_cuenta
           and m.COD_MODULO = t.cod_modulo
           and m.COD_MODALIDAD = t.cod_modalidad
           and m.COD_TRANSACCION = t.cod_transaccion;
      elsif rg.cod_modulo = 9 then
        select sum( decode( m.COD_MONEDA, v_cod_mon_fuerte, m.MONTO, pag_gen.fu_con_mon_a_moneda( m.COD_MONEDA,
                                                                                           v_cod_mon_fuerte,
                                                                                           m.MONTO,
                                                                                           null) ) )
          into v_monto2
          from cj_movimientos_his m,  ge_gru_transacciones_det t, ge_cta_clientes c
         where m.FECHA between v_fec_desde and v_fec_hasta
           and c.cod_persona = p_cod_persona
           and c.relacion = 'P'
           and t.cod_gru_transaccion = v_cod_gru_tra
           and t.cod_modulo = rg.cod_modulo
           and m.estado = 'N'
           and m.nro_cuenta = c.nro_cuenta
           and m.COD_MOD_PADRE = t.cod_modulo
           and m.COD_MAD_PADRE = t.cod_modalidad
           and m.COD_TRA_PADRE = t.cod_transaccion;
      end if;
      v_monto := nvl(v_monto,0) + nvl(v_monto2,0);
   end loop;
   return( v_monto );
END;
/

