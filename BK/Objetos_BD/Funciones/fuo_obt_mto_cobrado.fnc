CREATE OR REPLACE FUNCTION IT.FUO_OBT_MTO_COBRADO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,P_FECHA1 IN GE_CUENTAS.FEC_APERTURA%TYPE
 ,P_FECHA2 IN GE_CUENTAS.FEC_APERTURA%TYPE
 ,P_COD_MODULO IN BA_MODULOS.COD_MODULO%TYPE
 )
 RETURN NUMBER
 IS
 v_mto_cobro ge_cuentas.sal_contable%type;
BEGIN
   IF P_COD_MODULO = 6 THEN
      select
         sum (nvl(pr_cobros.mto_capital, 0) +
              nvl(pr_cobros.mto_interes, 0) +
              nvl(pr_cobros.mto_int_documentado,0))
          into v_mto_cobro
          from pr_cobros
          where nro_cuenta = P_NRO_CUENTA
          AND fecha BETWEEN P_FECHA1 AND
NVL(P_FECHA2,TO_DATE('01/01/5000','DD/MM/YYYY'))
          and nvl(pr_cobros.dia_mora,0) > 0
          group by pr_cobros.nro_cuenta;
   END IF;
   IF P_COD_MODULO = 5 THEN
      select SUM(nvl(ta_cobros.monto,0)) mto_cobro
      into v_mto_cobro
      from ta_cobros
      where ta_cobros.nro_cuenta = P_NRO_CUENTA
      AND   ta_cobros.Fec_Valor BETWEEN P_FECHA1 AND
NVL(P_FECHA2,TO_DATE('01/01/5000','DD/MM/YYYY'))
      group by nro_cuenta;
  END IF;
  RETURN v_mto_cobro;
exception
   when no_data_found then
      return NULL;
END;
          /*union
          -- para cta_ctes en mora el mto_mora es el mto a pagar
             select cc_cta_corrientes.nro_cuenta,
               1,
             cc_cta_corrientes.fec_ult_movimiento,
           --cc_cta_corrientes.dia_atraso,
             cc_cta_corrientes.mto_mora
            from cc_cta_corrientes
              where nro_cuenta = :P_NRO_CUETA
              AND cc_cta_corrientes.fec_ult_movimiento >= :P_FECHA
              union
             select cc_cta_corrientes.nro_cuenta,
             1,ge_movimientos.fecha,cc_cta_corrientes.mto_mora
             from ge_movimientos, ge_transacciones, cc_cta_corrientes
             where ge_movimientos.cod_modulo = ge_transacciones.cod_modulo
             and ge_movimientos.cod_modalidad =
ge_transacciones.cod_modalidad
             and ge_movimientos.cod_transaccion =
ge_transacciones.cod_transaccion
             and ge_transacciones.tipo = 'C'
             and cc_cta_corrientes.nro_cuenta = ge_movimientos.nro_cuenta
             and cc_cta_corrientes.nro_cuenta = :P_NRO_CUENTA
             union
             select cc_cta_corrientes.nro_cuenta,
             1,cc_movimientos_his.fecha,cc_cta_corrientes.mto_mora
             from ge_transacciones, cc_movimientos_his, cc_cta_corrientes
             where cc_movimientos_his.cod_modulo =
ge_transacciones.cod_modulo
             and cc_movimientos_his.cod_modalidad =
ge_transacciones.cod_modalidad
             and cc_movimientos_his.cod_transaccion =
ge_transacciones.cod_transaccion
             and cc_cta_corrientes.nro_cuenta =
cc_movimientos_his.nro_cuenta
             and tipo = 'C'
             --and cc_cta_corrientes.nro_cuenta in (120,387,388)*/
/

