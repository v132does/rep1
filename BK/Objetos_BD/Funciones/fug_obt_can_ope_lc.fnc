CREATE OR REPLACE FUNCTION IT.FUG_OBT_CAN_OPE_LC
  ( P_COD_PERSONA IN VARCHAR2,              -- Código de la persona
    P_TIPO        IN VARCHAR2 )             -- Tipo de Operación
  return number is
  v_resultado  number;
  v_fec_desde     date;
  v_fec_hasta     date;
  v_cod_mon_local varchar2(4) := pag_gen.FU_OBT_MON_LOCAL;

BEGIN
   pag_cal.PR_OBT_DAT_CALENDAR(1);
   v_fec_desde := pag_cal.G_PRI_DIA_MES;
   v_fec_hasta := pag_cal.G_FEC_ACTUAL;

   IF p_tipo = 'C' THEN
      select sum(nvl(cantidad,0))
        into v_resultado
        from (
            select count(*) cantidad
              from  lc_movimientos_his b, lc_movimientos_his a
             where b.COD_TIP_OPE_CAMBIO not in ( '14', '59', '89', '29', '74' )
               and b.cod_moneda <> v_cod_mon_local
               and b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.hora = a.hora
               and b.nro_secuencia = 1
               and a.cod_transaccion = 760
               and a.estado = 'N'
               and a.reversado = 'N'
               and a.NRO_DOCUMENTO2 = to_number(p_cod_persona)
               and a.COD_MODULO = 7
               and a.cod_mod_padre = 7
               and a.FECHA between v_fec_desde and v_fec_hasta
             union all
             select count(*)
              from  cc_movimientos_his b, lc_movimientos_his a
             where b.COD_TIP_OPE_CAMBIO not in ( '14', '59', '89', '29', '74' )
               and b.cod_moneda <> v_cod_mon_local
               and b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.hora = a.hora
               and b.nro_secuencia = 1
               and a.cod_transaccion = 760
               and a.estado = 'N'
               and a.reversado = 'N'
               and a.NRO_DOCUMENTO2 = to_number(p_cod_persona)
               and a.COD_MODULO = 7
               and a.cod_mod_padre = 7
               and a.FECHA between v_fec_desde and v_fec_hasta
             union all
             select count(*)
              from  ah_movimientos_his b, lc_movimientos_his a
             where b.COD_TIP_OPE_CAMBIO not in ( '14', '59', '89', '29', '74' )
               and b.cod_moneda <> v_cod_mon_local
               and b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.hora = a.hora
               and b.nro_secuencia = 1
               and a.cod_transaccion = 760
               and a.estado = 'N'
               and a.reversado = 'N'
               and a.NRO_DOCUMENTO2 = to_number(p_cod_persona)
               and a.COD_MODULO = 7
               and a.cod_mod_padre = 7
               and a.FECHA between v_fec_desde and v_fec_hasta
               );

   ELSIF p_tipo = 'R' THEN
      select sum(nvl(cantidad,0))
        into v_resultado
        from (
            select count(*) cantidad
              from  lc_movimientos_his b, lc_movimientos_his a
             where b.COD_TIP_OPE_CAMBIO in ( '14', '59', '89' )
               and b.cod_moneda <> v_cod_mon_local
               and b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.hora = a.hora
               and b.nro_secuencia = 1
               and a.cod_transaccion = 760
               and a.estado = 'N'
               and a.reversado = 'N'
               and a.NRO_DOCUMENTO2 = to_number(p_cod_persona)
               and a.COD_MODULO = 7
               and a.cod_mod_padre = 7
               and a.FECHA between v_fec_desde and v_fec_hasta
             union all
             select count(*)
              from  cc_movimientos_his b, lc_movimientos_his a
             where b.COD_TIP_OPE_CAMBIO in ( '14', '59', '89' )
               and b.cod_moneda <> v_cod_mon_local
               and b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.hora = a.hora
               and b.nro_secuencia = 1
               and a.cod_transaccion = 760
               and a.estado = 'N'
               and a.reversado = 'N'
               and a.NRO_DOCUMENTO2 = to_number(p_cod_persona)
               and a.COD_MODULO = 7
               and a.cod_mod_padre = 7
               and a.FECHA between v_fec_desde and v_fec_hasta
               );

   ELSIF p_tipo = 'E' THEN

      select sum(nvl(cantidad,0))
        into v_resultado
        from (
            select count(*) cantidad
              from  lc_movimientos_his b, lc_movimientos_his a
             where b.COD_TIP_OPE_CAMBIO in ( '29', '74' )
               and b.cod_moneda <> v_cod_mon_local
               and b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.hora = a.hora
               and b.nro_secuencia = 1
               and a.cod_transaccion = 760
               and a.estado = 'N'
               and a.reversado = 'N'
               and a.NRO_DOCUMENTO2 = to_number(p_cod_persona)
               and a.COD_MODULO = 7
               and a.cod_mod_padre = 7
               and a.FECHA between v_fec_desde and v_fec_hasta
             union all
             select count(*)
              from  cc_movimientos_his b, lc_movimientos_his a
             where b.COD_TIP_OPE_CAMBIO in ( '29', '74' )
               and b.cod_moneda <> v_cod_mon_local
               and b.fecha = a.fecha
               and b.cod_usuario = a.cod_usuario
               and b.hora = a.hora
               and b.nro_secuencia = 1
               and a.cod_transaccion = 760
               and a.estado = 'N'
               and a.reversado = 'N'
               and a.NRO_DOCUMENTO2 = to_number(p_cod_persona)
               and a.COD_MODULO = 7
               and a.cod_mod_padre = 7
               and a.FECHA between v_fec_desde and v_fec_hasta
               );

   END IF;


   return(v_resultado);

exception
  when others then
     raise_application_error(-20000,'FUG_OBT_CAN_OPE_LC '||sqlerrm);
end FUG_OBT_CAN_OPE_LC;
/

