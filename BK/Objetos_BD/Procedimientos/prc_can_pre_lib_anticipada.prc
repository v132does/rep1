CREATE OR REPLACE PROCEDURE IT.prc_can_pre_lib_anticipada
(
   p_nro_cuenta    cc_lib_ant_cheques.nro_cuenta%TYPE,
   p_nro_documento cc_lib_ant_cheques.nro_documento%TYPE,
   p_cod_retencion cc_lib_ant_cheques.cod_retencion%TYPE,
   p_fec_final     cc_lib_ant_cheques.fec_final%TYPE,
   p_hor_movimiento IN VARCHAR2 DEFAULT NULL,
   p_nro_secuencia  IN OUT VARCHAR2
) IS
   rg_lib_ant           cc_lib_ant_cheques%ROWTYPE;
   rg_pres              pr_cta_prestamos%ROWTYPE;
   v_fec_actual         DATE := pag_cal.fu_obt_fec_actual(4);
   v_error              NUMBER;
   v_mensaje            VARCHAR2(4000);
   v_tot_capital        pr_cta_prestamos.sal_capital%TYPE;
   v_tot_interes        pr_cta_prestamos.sal_interes%TYPE;
   v_tot_int_adelantado pr_cta_prestamos.sal_int_adelantado%TYPE;
   v_tot_mora           pr_cta_prestamos.sal_interes%TYPE;
   v_tot_mora_interes   pr_cta_prestamos.sal_interes%TYPE;
   v_tot_mora_int_ade   pr_cta_prestamos.sal_interes%TYPE;
   v_tot_punitorio      pr_cta_prestamos.sal_interes%TYPE;
   v_tot_impuesto       pr_cta_prestamos.sal_interes%TYPE;
   v_tot_cargo          pr_cta_prestamos.sal_capital%TYPE;
   v_tot_cargo_iva      pr_cta_prestamos.sal_capital%TYPE;
   v_tot_int_descontado pr_cuotas.sal_interes%TYPE;
   v_dia_mora           pr_cta_prestamos.dia_atraso%TYPE;
   c_cod_tra_padre      NUMBER := 359;
   v_tot_deuda          NUMBER;
   v_hora               ge_movimientos.hora%TYPE;
   v_nro_secuencia      ge_movimientos.nro_secuencia%TYPE;
   v_impuesto           NUMBER;
   v_est_movimiento     ge_movimientos.estado%TYPE := 'N';
   v_tip_cancelacion    varchar2(1) := 'T';
   v_cta_bancaria       ge_cuentas.nro_cuenta%TYPE;
   v_ofi_cta_ban        ba_oficinas.cod_oficina%TYPE;
BEGIN
   IF p_hor_movimiento IS NULL THEN
      v_hora := to_char(sysdate,'HH24:MI:SS');
      v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   ELSE
      v_hora := p_hor_movimiento;
   END IF;
   v_nro_secuencia := nvl(p_nro_secuencia, 0);
   pag_cta.pr_obt_cuenta(p_nro_cuenta);
   BEGIN
      SELECT *
        INTO rg_lib_ant
        FROM cc_lib_ant_cheques
       WHERE nro_cuenta = p_nro_cuenta
         AND nro_documento = p_nro_documento
         AND cod_retencion = p_cod_retencion
         AND fec_final = p_fec_final;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         raise_application_error(-20000, 'Sin liberacion anticipada. Cta:' || p_nro_cuenta
                                || ' Doc:' || p_nro_documento || ' Ret:' || p_cod_retencion);
      WHEN TOO_MANY_ROWS THEN
         raise_application_error(-20000, 'Mas de 1 liberacion anticipada. Cta: ' || v_mensaje);
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error Obt.CC_LIB_ANT_CHEQUES: ' || sqlerrm);
   end;
   v_cta_bancaria := fug_obt_pardinamico('CTA_LIB_ANT_CHEQUES', 4, 47, rg_lib_ant.cod_moneda,
                                         rg_lib_ant.cod_oficina);
   IF v_cta_bancaria IS NULL THEN
      raise_application_error(-20000, 'Cuenta Operativa de Desembolso no definida para Oficina '||rg_lib_ant.cod_oficina);
   ELSE
      BEGIN
         SELECT cod_oficina
           INTO v_ofi_cta_ban
           FROM ge_cuentas
          WHERE nro_cuenta = v_cta_bancaria;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'Cuenta Operativa de Desembolso no corresponde.');
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Al Obt.Cta.Operativa:' || SQLERRM);
      END;
      IF v_ofi_cta_ban <> rg_lib_ant.cod_oficina THEN
         raise_application_error(-20000, 'Cuenta Operativa de Desembolso no pertenece a oficina '||rg_lib_ant.cod_oficina);
      END IF;
   END IF;
   pap_pre.pr_obt_dat_prestamo(rg_lib_ant.nro_cta_prestamo, rg_pres);
   pap_pre.pr_obt_deu_prestamo(rg_lib_ant.nro_cta_prestamo, v_fec_actual, 1, rg_pres.can_cuotas,
                               rg_lib_ant.cod_oficina, null,
                               --out
                               v_error, v_mensaje, v_tot_capital, v_tot_interes,
                               v_tot_int_adelantado, v_tot_mora, v_tot_mora_interes,
                               v_tot_mora_int_ade, v_tot_punitorio, v_tot_impuesto, v_tot_cargo,
                               v_tot_cargo_iva, v_tot_int_descontado, v_dia_mora, c_cod_tra_padre);
   IF v_error <> 0 THEN
      raise_application_error(-20000, 'Error en PRP_CAN_PRESTAMO Al Buscar la Deuda. ' || v_mensaje);
   END IF;
   v_tot_deuda := nvl(v_tot_capital, 0) + nvl(v_tot_interes, 0) + nvl(v_tot_int_adelantado, 0) +
                  nvl(v_tot_mora, 0) + nvl(v_tot_mora_interes, 0) + nvl(v_tot_mora_int_ade, 0) +
                  nvl(v_tot_punitorio, 0) + nvl(v_tot_impuesto, 0) + nvl(v_tot_cargo, 0) +
                  nvl(v_tot_cargo_iva, 0) + nvl(v_tot_int_descontado, 0);
   IF v_tot_deuda > 0 THEN
      pag_cta.g_sobregira := 'S';
      --calcula impuesto si corresponde y genera movimiento
      prg_ver_cob_cargos(v_cta_bancaria, rg_pres.nro_cuenta, 6, rg_pres.cod_modalidad,
                         rg_pres.cod_oficina, rg_pres.cod_moneda, v_tot_deuda,
                         'Cancelación total de Préstamo Cta.: ' || rg_pres.nro_cuenta, p_nro_documento,
                         v_fec_actual, v_hora, v_impuesto, v_nro_secuencia, 'S'); --procesar

      -- Actualiza la Cuenta Crédito / Destino
      pag_cta.pr_act_operacion(v_cta_bancaria, v_hora,
                               --HORA
                               'D', rg_pres.cod_moneda,
                               --Moneda de la Operación
                               v_tot_deuda + nvl(v_impuesto, 0), 359,
                               -- Cobro de prestamos
                               503,
                               -- Debito
                               rg_pres.nro_cuenta, NULL,
                               --COTIZACION
                               rg_pres.cod_oficina,
                               --cod_ofi_origen
                               6,
                               --cod_mod_padre
                               rg_pres.cod_modalidad,
                               --cod_mad_padre
                               NULL,
                               --cod_tasa
                               NULL,
                               --val_tasa
                               'Cancelación de préstamo ' || rg_pres.nro_cuenta, 'S',
                               --emi_aviso
                               v_nro_secuencia, v_fec_actual, NULL, NULL, NULL, v_est_movimiento); -- C.D.Fase II

      IF pag_cta.fu_obt_cod_error() <> 0 THEN
         raise_application_error(-20000,
                                 pag_cta.fu_obt_cod_error() || ' - ' || pag_cta.fu_obt_msj_error());
      END IF;
      -- Realizar el cobro del prestamo ---
      pap_pre.pr_can_prestamo(rg_pres.nro_cuenta, v_tot_deuda + nvl(v_impuesto, 0), 'N',
                               --- Se pidio autorización
                              rg_lib_ant.cod_oficina,
                               --- oficina origen
                              v_tip_cancelacion, v_fec_actual, v_hora, v_nro_secuencia, NULL, 'N',
                              NULL, v_est_movimiento); --C.D.Fase II- ajuste nuevo parámetro de entrada
      pag_cta.g_sobregira := 'N';
      --- Cambiar el estado a cancelado
      UPDATE cc_lib_ant_cheques
         SET estado = 'C'
       WHERE p_nro_cuenta = nro_cuenta
         AND p_nro_documento = nro_documento
         AND p_cod_retencion = cod_retencion
         AND p_fec_final = fec_final;  
      ---
   END IF;
   p_nro_secuencia := nvl(v_nro_secuencia, 0);
END prc_can_pre_lib_anticipada;
/

