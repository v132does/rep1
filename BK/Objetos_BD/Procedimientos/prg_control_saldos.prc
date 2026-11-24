CREATE OR REPLACE PROCEDURE IT.prg_control_saldos IS
   v_fec_actual ge_calendarios.fec_actual%TYPE := pag_cal.fu_obt_fec_actual(1);
   
   -- Types para FORALL
   TYPE typ_saldos IS TABLE OF tm_cont_saldos%ROWTYPE;
   TYPE typ_logs IS TABLE OF tm_log_controles%ROWTYPE;
   
   v_sal_cc typ_saldos := typ_saldos(); 
   v_cc_logs typ_logs  := typ_logs();
   v_sal_ah typ_saldos := typ_saldos();
   v_ah_logs typ_logs := typ_logs();

   CURSOR cta_corriente IS
      SELECT av.nro_cuenta,
             av.cod_moneda,
             av.sal_total,
             av.sal_retenido,
             av.sal_bloqueado,
             av.sal_ult_extracto sal_ult_extracto,
             SUM(decode(ge_transacciones.cod_transaccion, 515, 0, 560, 0,
                        decode(ge_transacciones.tipo, 'D', nvl(cc_movimientos_his.monto, 0), 0))) debitos,
             SUM(decode(ge_transacciones.cod_transaccion, 515, nvl(cc_movimientos_his.monto, 0), 560,
                        nvl(cc_movimientos_his.monto, 0),
                        decode(ge_transacciones.tipo, 'C', nvl(cc_movimientos_his.monto, 0), 0))) creditos,
             v_fec_actual fecha
        FROM ge_transacciones, cc_movimientos_his, cc_cta_corrientes av, cc_sal_mensuales m
       WHERE cc_movimientos_his.cod_modulo = av.cod_modulo
         AND cc_movimientos_his.cod_modalidad = av.cod_modalidad
         AND cc_movimientos_his.cod_oficina = av.cod_oficina
         AND cc_movimientos_his.nro_cuenta = av.nro_cuenta
         AND cc_movimientos_his.fecha >= trunc(SYSDATE, 'MM') --Primer día del mes
         AND cc_movimientos_his.fecha <= v_fec_actual --Fecha del cierre
            --AND cc_movimientos_his.REVERSADO = 'N'
         AND (cc_movimientos_his.reversado = 'N' OR
             (cc_movimientos_his.reversado = 'S' AND
             to_char(cc_movimientos_his.fecha, 'YYYYMM') >
             to_char(cc_movimientos_his.fec_valor, 'YYYYMM')))
         AND cc_movimientos_his.estado = 'N'
         AND m.nro_cuenta = av.nro_cuenta
         AND m.ano = to_char(SYSDATE, 'YYYY') --Año Actual
         AND m.mes = to_char(SYSDATE, 'MM') --Mes Actual
         AND cc_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
         AND cc_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
         AND cc_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
         AND ge_transacciones.ve_cliente = 'S'
         AND ge_transacciones.tipo IN ('C', 'D')
         AND ge_transacciones.afecta IN ('S', 'R') -- Solo los que afectan saldo y retenidos
       GROUP BY av.nro_cuenta,
                av.cod_moneda,
                av.sal_total,
                av.sal_bloqueado,
                av.sal_retenido,
                av.sal_ult_extracto;

   CURSOR ah_vistas IS
      SELECT av.nro_cuenta,
             av.cod_moneda,
             av.sal_total,
             av.sal_retenido,
             av.sal_bloqueado,
             av.sal_ult_extracto sal_ult_extracto,
             av.cod_modalidad,
             SUM(decode(ge_transacciones.cod_transaccion, 515, 0, 560, 0,
                        decode(ge_transacciones.tipo, 'D', nvl(ah_movimientos_his.monto, 0), 0))) debitos,
             SUM(decode(ge_transacciones.cod_transaccion, 515, nvl(ah_movimientos_his.monto, 0), 560,
                        nvl(ah_movimientos_his.monto, 0),
                        decode(ge_transacciones.tipo, 'C', nvl(ah_movimientos_his.monto, 0), 0))) creditos,
             v_fec_actual fecha
        FROM ge_transacciones, ah_movimientos_his, ah_cta_vistas av, ah_sal_mensuales m
       WHERE ah_movimientos_his.cod_modulo = av.cod_modulo
         AND ah_movimientos_his.cod_modalidad = av.cod_modalidad
         AND ah_movimientos_his.cod_oficina = av.cod_oficina
         AND ah_movimientos_his.nro_cuenta = av.nro_cuenta
         AND ah_movimientos_his.fecha >= trunc(SYSDATE, 'MM') --Primer día del mes
         AND ah_movimientos_his.fecha <= v_fec_actual --Fecha del cierre
            --AND AH_MOVIMIENTOS_HIS.REVERSADO = 'N'
         AND (ah_movimientos_his.reversado = 'N' OR
             (ah_movimientos_his.reversado = 'S' AND
             to_char(ah_movimientos_his.fecha, 'YYYYMM') >
             to_char(ah_movimientos_his.fec_valor, 'YYYYMM')))
         AND ah_movimientos_his.estado = 'N'
         AND m.nro_cuenta = av.nro_cuenta
         AND m.ano = to_char(SYSDATE, 'YYYY') --Año Actual
         AND m.mes = to_char(SYSDATE, 'MM') --Mes Actual
         AND ah_movimientos_his.cod_modulo = ge_transacciones.cod_modulo
         AND ah_movimientos_his.cod_modalidad = ge_transacciones.cod_modalidad
         AND ah_movimientos_his.cod_transaccion = ge_transacciones.cod_transaccion
         AND ge_transacciones.ve_cliente = 'S'
         AND ge_transacciones.tipo IN ('C', 'D')
         AND ge_transacciones.afecta IN ('S', 'R') -- Solo los que afectan saldo y retenidos
       GROUP BY av.nro_cuenta,
                av.cod_moneda,
                av.sal_total,
                av.sal_bloqueado,
                av.sal_retenido,
                av.sal_ult_extracto,
                av.cod_modalidad;
BEGIN
   -- Procesar CUENTAS CORRIENTES
   FOR x IN cta_corriente LOOP
      -- Agregar a saldos
      v_sal_cc.EXTEND;
      v_sal_cc(v_sal_cc.LAST).fecha := x.fecha;
      v_sal_cc(v_sal_cc.LAST).tip_control := 'CC';
      v_sal_cc(v_sal_cc.LAST).nro_cuenta := x.nro_cuenta;
      v_sal_cc(v_sal_cc.LAST).sal_total := x.sal_total;
      v_sal_cc(v_sal_cc.LAST).sal_retenido := x.sal_retenido;
      v_sal_cc(v_sal_cc.LAST).sal_bloqueado := x.sal_bloqueado;
      v_sal_cc(v_sal_cc.LAST).sal_ult_extracto := x.sal_ult_extracto;
      v_sal_cc(v_sal_cc.LAST).debito := x.debitos;
      v_sal_cc(v_sal_cc.LAST).credito := x.creditos;
      v_sal_cc(v_sal_cc.LAST).saldo_calculado := (nvl(x.sal_ult_extracto, 0) - nvl(x.debitos, 0) + nvl(x.creditos, 0));
      v_sal_cc(v_sal_cc.LAST).diferencia := (nvl(x.sal_total, 0) - nvl(x.sal_retenido, 0)) - (nvl(x.sal_ult_extracto, 0) - nvl(x.debitos, 0) + nvl(x.creditos, 0));
      v_sal_cc(v_sal_cc.LAST).fec_insercion := SYSDATE;

      -- Si hay diferencia, agregar a logs
      IF (nvl(x.sal_total, 0) - nvl(x.sal_retenido, 0)) - (nvl(x.sal_ult_extracto, 0) - nvl(x.debitos, 0) + nvl(x.creditos, 0)) <> 0 THEN
         v_cc_logs.EXTEND;
         v_cc_logs(v_cc_logs.LAST).fecha := v_fec_actual;
         v_cc_logs(v_cc_logs.LAST).tip_control := 'DIFERENCIA EN SALDOS';
         v_cc_logs(v_cc_logs.LAST).clave := x.nro_cuenta;
         v_cc_logs(v_cc_logs.LAST).cod_modalidad := 41;
         v_cc_logs(v_cc_logs.LAST).observacion := 
            'Cta: ' || x.nro_cuenta || ' Saldo Calculado: ' ||
            to_char(nvl(x.sal_ult_extracto, 0) - nvl(x.debitos, 0) + nvl(x.creditos, 0)) ||
            ' Saldo Total - Saldo Retenido: ' ||
            to_char(nvl(x.sal_total, 0) - nvl(x.sal_retenido, 0)) || ' Dif: ' ||
            to_char((nvl(x.sal_total, 0) - nvl(x.sal_retenido, 0)) -
                    (nvl(x.sal_ult_extracto, 0) - nvl(x.debitos, 0) + nvl(x.creditos, 0)));
      END IF;
   END LOOP;

   -- Procesar CAJAS DE AHORRO
   FOR y IN ah_vistas LOOP
      -- Agregar a saldos
      v_sal_ah.EXTEND;
      v_sal_ah(v_sal_ah.LAST).fecha := y.fecha;
      v_sal_ah(v_sal_ah.LAST).tip_control := 'AH';
      v_sal_ah(v_sal_ah.LAST).nro_cuenta := y.nro_cuenta;
      v_sal_ah(v_sal_ah.LAST).sal_total := y.sal_total;
      v_sal_ah(v_sal_ah.LAST).sal_retenido := y.sal_retenido;
      v_sal_ah(v_sal_ah.LAST).sal_bloqueado := y.sal_bloqueado;
      v_sal_ah(v_sal_ah.LAST).sal_ult_extracto := y.sal_ult_extracto;
      v_sal_ah(v_sal_ah.LAST).debito := y.debitos;
      v_sal_ah(v_sal_ah.LAST).credito := y.creditos;
      v_sal_ah(v_sal_ah.LAST).saldo_calculado := (nvl(y.sal_ult_extracto, 0) - nvl(y.debitos, 0) + nvl(y.creditos, 0));
      v_sal_ah(v_sal_ah.LAST).diferencia := (nvl(y.sal_total, 0) - nvl(y.sal_retenido, 0)) - (nvl(y.sal_ult_extracto, 0) - nvl(y.debitos, 0) + nvl(y.creditos, 0));
      v_sal_ah(v_sal_ah.LAST).fec_insercion := SYSDATE;

      -- Si hay diferencia, agregar a logs
      IF (nvl(y.sal_total, 0) - nvl(y.sal_retenido, 0)) - (nvl(y.sal_ult_extracto, 0) - nvl(y.debitos, 0) + nvl(y.creditos, 0)) <> 0 THEN
         v_ah_logs.EXTEND;
         v_ah_logs(v_ah_logs.LAST).fecha := v_fec_actual;
         v_ah_logs(v_ah_logs.LAST).tip_control := 'DIFERENCIA EN SALDOS';
         v_ah_logs(v_ah_logs.LAST).clave := y.nro_cuenta;
         v_ah_logs(v_ah_logs.LAST).cod_modalidad := y.cod_modalidad;
         v_ah_logs(v_ah_logs.LAST).observacion := 
            'Cta: ' || y.nro_cuenta || ' Saldo Calculado: ' ||
            to_char(nvl(y.sal_ult_extracto, 0) - nvl(y.debitos, 0) + nvl(y.creditos, 0)) ||
            ' Saldo Total - Saldo Retenido: ' ||
            to_char(nvl(y.sal_total, 0) - nvl(y.sal_retenido, 0)) || ' Dif: ' ||
            to_char((nvl(y.sal_total, 0) - nvl(y.sal_retenido, 0)) -
                    (nvl(y.sal_ult_extracto, 0) - nvl(y.debitos, 0) + nvl(y.creditos, 0)));
      END IF;
   END LOOP;

   -- Insertar saldos de Cuentas Corrientes
   IF v_sal_cc.COUNT > 0 THEN
      FORALL i IN 1..v_sal_cc.COUNT
         INSERT INTO tm_cont_saldos VALUES v_sal_cc(i);
   END IF;
   COMMIT;
   -- Insertar logs de Cuentas Corrientes
   IF v_cc_logs.COUNT > 0 THEN
      FORALL i IN 1..v_cc_logs.COUNT
         INSERT INTO tm_log_controles VALUES v_cc_logs(i);
   END IF;
   COMMIT;
   -- Insertar saldos de Cajas de Ahorro
   IF v_sal_ah.COUNT > 0 THEN
      FORALL i IN 1..v_sal_ah.COUNT
         INSERT INTO tm_cont_saldos VALUES v_sal_ah(i);
   END IF;
   COMMIT;
   -- Insertar logs de Cajas de Ahorro
   IF v_ah_logs.COUNT > 0 THEN
      FORALL i IN 1..v_ah_logs.COUNT
         INSERT INTO tm_log_controles VALUES v_ah_logs(i);
   END IF;
   COMMIT;
   
   BEGIN
      DELETE tm_cont_saldos c WHERE trunc(c.fecha) < trunc(SYSDATE, 'MM');
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20001,
                                 'ERROR: PRG_CONTROL_SALDOS, Borrado de Saldos de 7 días:' ||
                                  SQLERRM);
   END;  

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20001, 'ERROR: PRG_CONTROL_SALDOS:' || SQLERRM);
END prg_control_saldos;