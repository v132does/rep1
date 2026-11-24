CREATE OR REPLACE PROCEDURE IT.prg_pro_incobrables
(
   p_nro_cuenta  IN ge_cuentas.nro_cuenta%TYPE,
   p_observacion IN VARCHAR2,
   p_secuencia   IN OUT NUMBER
) IS
   v_modulo        ba_modulos.cod_modulo%TYPE;
   v_modalidad     ge_modalidades.cod_modalidad%TYPE;
   v_mto_prevision ge_movimientos.monto%TYPE;
   v_mto_trans     ge_movimientos.monto%TYPE;
   v_trans         ge_transacciones.cod_transaccion%TYPE;
   v_concepto      ge_movimientos.concepto%TYPE;
   v_cod_tra_pad   ge_transacciones.cod_transaccion%TYPE;
   v_estado_cta    pr_cta_prestamos.estado%TYPE;
   v_est_anterior  pr_cta_prestamos.estado%TYPE;
   v_cod_tra_hij   ge_transacciones.cod_transaccion%TYPE;
   v_sal_cap       pr_cuotas.sal_capital%TYPE;
   v_sal_int       pr_cuotas.sal_capital%TYPE;

   v_sal_int_cuota      pr_cuotas.sal_interes%TYPE; --ISSUE-2013
   v_sal_interes        pr_cta_prestamos.sal_interes%TYPE; --ISSUE-2013
   v_sal_int_adelantado pr_cta_prestamos.sal_int_adelantado%TYPE; --ISSUE-2013

   v_sal_intautor pr_cuotas.sal_capital%TYPE;
   v_adevengar    pr_cuotas.sal_capital%TYPE;
   rv_pres        pr_cta_prestamos%ROWTYPE;
   v_diferencia   ge_movimientos.monto%TYPE;
   v_fecha        DATE;
   v_mensaje      VARCHAR2(2000);
   no_procesa EXCEPTION;
   v_error EXCEPTION;

BEGIN
   -- tiene que verificar si esta previsionado ?
   -- tiene que poner estado I incobrable a cta prestamo y cuotas
   -- tiene que generar asientos (sacar de cartera y pasar a ctas. de orden )
   -- cerar las previsiones

   -- Controlar si el módulo se encuentra habilitado
   pae_cnf.pr_ctr_modulo(nvl(pae_cnf.g_cod_modulo, 6));

   BEGIN
      SELECT cod_modulo, cod_modalidad, estado
        INTO v_modulo, v_modalidad, v_est_anterior
        FROM ge_cuentas
       WHERE nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN OTHERS THEN
         v_mensaje := 'No se pudo obtener los datos de la cuenta ' || to_char(p_nro_cuenta) || '; ' ||
                      SQLERRM;
         RAISE v_error;
   END;

   v_fecha      := pag_cal.fu_obt_fec_actual(v_modulo);
   v_estado_cta := 'I';

   IF v_modulo IN (3, 4) THEN
      -- Cuenta de AHORROS
      v_mensaje := 'No se puede pasar a Incobrables tipo de cta.';
      RAISE v_error;
   ELSIF v_modulo = 6 THEN
      -- Cuenta de PRESTAMOS y CUOTAS
      pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, rv_pres);
      --- Se suma el interes a devengar.
      v_adevengar := nvl(rv_pres.val_int_devengar, 0);
      --
      
      pap_mes.pr_obt_cap_int_pres(p_nro_cuenta, v_sal_cap, v_sal_int, v_sal_intautor); -- DYDMR-291. CB.
      pap_mes.pr_act_est_cuotas(p_nro_cuenta, v_estado_cta); --actualiza estado de cuotas
      pap_mes.pr_act_est_prestamo(p_nro_cuenta, v_estado_cta); --actualiza estado de prestamo
         
      pap_mes.v_fcdehoy       := v_fecha;
      pap_mes.v_horamovim     := to_char(SYSDATE, 'HH24:MI:SS');
      pap_mes.v_secuencia     := p_secuencia;
      pap_mes.rv_pres         := rv_pres;
      pap_mes.v_cod_oficina   := rv_pres.cod_oficina;
      pap_mes.v_cod_modulo    := rv_pres.cod_modulo;
      pap_mes.v_cod_modalidad := rv_pres.cod_modalidad;
      pap_mes.v_nro_cuenta    := rv_pres.nro_cuenta;
   
      --generar novedades de cambio de estado para poder reversar
      INSERT INTO ge_cuentas_nov
         (fecha, hora, cod_usuario, nro_cuenta, nro_detalle, cod_modulo, cod_modalidad,
          est_anterior, est_actual)
      VALUES
         (v_fecha, pap_mes.v_horamovim, USER, p_nro_cuenta, NULL, rv_pres.cod_modulo,
          rv_pres.cod_modalidad, rv_pres.estado, v_estado_cta);
   END IF;

   -- GENERACION DE ASIENTOS A INCOBRABLE
   v_cod_tra_pad := 945;
   v_cod_tra_hij := 954; ---929;
   -- x saldo capital
   v_mto_trans := v_sal_cap;
   v_concepto  := nvl(p_observacion, 'TRANSF.CAPITAL A INCOBR.');
   pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto, v_est_anterior);
   /* Asiento por el Devengado No Cobrado, Saldo del Interes */
   IF nvl(v_sal_int, 0) > 0 THEN
      v_cod_tra_hij := 955; ---922;
      v_mto_trans   := nvl(v_sal_int, 0);
      v_concepto    := nvl(p_observacion, 'TRANSF.PR.FIN. A INCOB.');
      pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                v_est_anterior);
      IF nvl(v_adevengar, 0) > 0 THEN
         v_cod_tra_hij := 956; ---910;
         v_mto_trans   := nvl(v_adevengar, 0);
         v_concepto    := nvl(p_observacion, 'TRANSF.PR.FIN.ADEV. INCOBRAB.');
         pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_cod_tra_hij, v_mto_trans, v_concepto,
                                   v_est_anterior);
      END IF;
   END IF;
   -- A PREVISION
   v_mto_prevision := pap_mes.fu_obt_prevision(p_nro_cuenta);
   IF nvl(v_mto_prevision, 0) > 0 THEN
      v_mto_trans := v_mto_prevision;
      v_trans     := 957;
      v_concepto  := nvl(p_observacion, 'TRANSF.A PREVISION INCOB.');
      pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_est_anterior);
   END IF;
   -- EN SUSPENSO
   IF nvl(rv_pres.dev_suspenso, 0) > 0 THEN
      v_trans     := 958;
      v_mto_trans := rv_pres.dev_suspenso;
      v_concepto  := nvl(p_observacion, 'TRANSF.DEV.EN SUSPENSO A INCOB.');
      pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, v_est_anterior);
   END IF;
   -- Por la diferencia debo.
   v_diferencia := (nvl(rv_pres.dev_suspenso, 0) + nvl(v_mto_prevision, 0) + nvl(v_adevengar, 0)) -
                   (nvl(v_sal_cap, 0) + nvl(v_sal_int, 0));
   ---
   IF v_diferencia < 0 THEN
   
      v_mto_trans := v_diferencia * -1;
      v_trans     := 953;
      v_concepto  := nvl(p_observacion, 'TRANSF. A PERDIDA');
   
      pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I');
   
   ELSIF v_diferencia > 0 THEN
   
      v_mto_trans := v_diferencia;
      v_trans     := 952;
      v_concepto  := nvl(p_observacion, 'TRANSF. A GANANCIA');
   
      pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I');
   
   END IF;
   --- GENERA ASIENTO PARA CTAS. DE ORDEN
   v_mto_trans := v_sal_cap + nvl(rv_pres.dev_no_cobrado, 0); --AP 2666
   v_trans     := 959;
   v_concepto  := nvl(p_observacion, 'TRANSF. A DEUDORES INCOBRABLES');

   pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I');

   v_trans    := 960;
   v_concepto := nvl(p_observacion, 'TRANSF. A CREDITOS INCOBRABLES');

   pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I');

   -----* FIN ASIENTOS
   --- genera cambio de estado de prestamos ---------
   v_cod_tra_pad := 945;
   v_trans       := 438;

   pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, NULL, p_observacion, 'I');

   p_secuencia := pap_mes.v_secuencia;
   -- Cera los montos de Devengado.
   -- No toca pr_devengados para que quede como historia.   

   /**ISSUE-2013: 
   || Recuperar el saldo del Interes de las Cuotas, para actualizar la Cabecera del Prestamo.
   || Recuperar los Saldos de Interes e Interes Adelantado para calcula el montodel Movimiento.
   || Insertar el Movimiento por el Ajuste del saldo Batch.
   **/
   v_mto_trans := 0;
   BEGIN
      SELECT SUM(nvl(sal_interes, 0))
        INTO v_sal_int_cuota
        FROM pr_cuotas
       WHERE nro_cuenta = p_nro_cuenta;
   
      SELECT nvl(p.sal_interes, 0), nvl(p.sal_int_adelantado, 0)
        INTO v_sal_interes, v_sal_int_adelantado
        FROM pr_cta_prestamos p
       WHERE p.nro_cuenta = p_nro_cuenta;
   
      IF v_sal_interes <> 0 OR v_sal_int_adelantado <> 0 THEN
         v_mto_trans := (v_sal_interes + v_sal_int_adelantado) - v_sal_int_cuota;
      END IF;
   
      v_trans       := 9981;
      v_cod_tra_pad := 9981;
      v_concepto    := nvl(p_observacion, 'AJUSTE DE SALDO BATCH');
   
      IF v_mto_trans <> 0 THEN
         pap_mes.pr_ins_asie_cames(v_cod_tra_pad, v_trans, v_mto_trans, v_concepto, 'I');
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
         v_mensaje := 'Error al Generar el Movimiento de Ajuste Batch ' || to_char(p_nro_cuenta) || '; ' ||
                      SQLERRM;
         RAISE v_error;
   END;
   ---<

   UPDATE pr_cta_prestamos
      SET dev_acumulado      = nvl(dev_acumulado, 0) + nvl(val_int_devengar, 0),
          dev_no_cobrado     = 0,
          dev_suspenso       = 0,
          val_int_devengar   = 0,
          sal_int_adelantado = decode(tip_interes, 'A', v_sal_int_cuota, 0), --ISSUE-2013
          sal_interes        = decode(tip_interes, 'V', v_sal_int_cuota, 0) --ISSUE-2013
    WHERE nro_cuenta = p_nro_cuenta;

   UPDATE pr_cuotas
      SET dev_acumulado = nvl(mto_interes, 0)
    WHERE nro_cuenta = p_nro_cuenta
      AND nvl(dev_acumulado, 0) != nvl(mto_interes, 0);

   -- Cero las previsiones
   INSERT INTO pr_previsiones
      (fecha, nro_cuenta, monto, sal_capital, dev_no_cobrado)
   VALUES
      (v_fecha, p_nro_cuenta, 0, 0, 0);

EXCEPTION
   WHEN v_error THEN
      raise_application_error(-20000,
                              'Pro_Incobrables: ' ||
                               REPLACE(nvl((v_mensaje), SQLERRM), 'ORA-', 'XXX'));
   WHEN no_procesa THEN
      NULL;
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'Pro_Incobrables: ' ||
                               REPLACE(nvl((v_mensaje), SQLERRM), 'ORA-', 'XXX'));
END;
/

