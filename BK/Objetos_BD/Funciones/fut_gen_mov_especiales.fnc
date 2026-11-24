CREATE OR REPLACE FUNCTION IT.fut_gen_mov_especiales(p_nro_cuenta ta_can_aut_tarjetas.nro_cuenta%TYPE)
   RETURN VARCHAR2 IS
   CURSOR c_saldos IS
      SELECT t.mto_saldo, t.cod_tip_saldo, t.tip_saldo, nvl(t.tip_movimiento,'X') tip_movimiento
        FROM tv_cta_sal_tarjetas_tmp t
       WHERE t.nro_cuenta = p_nro_cuenta
         --AND t.tip_movimiento IN ('T', 'C')
       ORDER BY t.tip_movimiento DESC, t.cod_tip_saldo;
   v_error           VARCHAR2(4000);
   v_val_minimo      NUMBER(18, 2);
   v_val_maximo      NUMBER(18, 2);
   r_log             ta_logs%ROWTYPE;
   rg_movs           ge_movimientos%ROWTYPE;
   v_hora            ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS');
   v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE := -999;
   v_max_hora        ge_movimientos.hora%TYPE;
   v_max_nro_sec     ge_movimientos.nro_secuencia%TYPE;
   v_mto_cancelacion ge_movimientos.monto%TYPE := 0;
   v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE := 1213; --MOVIMIENTOS ESPECIALES DE TARJETAS
   v_cod_tip_saldo   ta_cta_sal_tarjetas_tmp.cod_tip_saldo%TYPE;
   v_fec_cancelacion DATE;
   PROCEDURE lp_gen_movimiento
   (
      p_cod_transaccion ge_transacciones.cod_transaccion%TYPE,
      p_monto           ge_movimientos.mto_equ_local%TYPE,
      p_cod_tip_saldo   ta_cta_sal_tarjetas_tmp.cod_tip_saldo%TYPE
   ) IS
      v_cod_ofi_origen ba_usuarios.cod_oficina%TYPE := fug_obt_ofi_usuario(USER);
      v_concepto       ge_movimientos.concepto%TYPE;
   BEGIN
      IF p_cod_transaccion IS NOT NULL THEN
         v_concepto := fug_obt_des_transaccion(pag_cta.g_ctas.cod_modulo,
                                               pag_cta.g_ctas.cod_modalidad, p_cod_transaccion);
         --- inserta datos en ge_movimientos
         v_nro_secuencia := v_nro_secuencia + 1;
         IF v_nro_secuencia > 990 THEN
            v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
            v_nro_secuencia := -999;
         END IF;
         rg_movs.nro_secuencia   := v_nro_secuencia;
         rg_movs.hora            := v_hora;
         rg_movs.cod_mod_padre   := pag_cta.g_ctas.cod_modulo;
         rg_movs.cod_mad_padre   := pag_cta.g_ctas.cod_modalidad;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_modulo      := pag_cta.g_ctas.cod_modulo;
         rg_movs.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
         rg_movs.cod_transaccion := p_cod_transaccion;
         rg_movs.cod_moneda      := pag_cta.g_ctas.cod_moneda;
         rg_movs.nro_cuenta      := p_nro_cuenta;
         rg_movs.cod_oficina     := v_cod_ofi_origen;
         rg_movs.monto           := p_monto;
         rg_movs.nro_documento   := NULL;
         rg_movs.nro_documento2  := p_cod_tip_saldo;
         rg_movs.cod_tasa        := NULL;
         rg_movs.val_tasa        := NULL;
         rg_movs.cotizacion      := NULL;
         rg_movs.emi_aviso       := 'N';
         rg_movs.cod_ofi_origen  := v_cod_ofi_origen;
         --- Campo Concepto de la tabla ta_env_debcre
         rg_movs.concepto := substr(v_concepto, 1, 20);
         --- Bancard Soporta solo 20 caracteres
         rg_movs.estado        := 'N';
         rg_movs.est_cuenta    := 'N';
         rg_movs.reversado     := 'N';
         rg_movs.emi_aviso     := 'N';
         rg_movs.nro_caja      := NULL;
         rg_movs.cod_rubro     := NULL;
         rg_movs.tip_mov_rubro := NULL;
         ---
         pag_gen.pr_ins_ge_movimiento(rg_movs, 'N');
      END IF;
   END;
BEGIN
   v_error             := NULL;
   r_log.nom_proceso   := 'FUT_GEN_MOV_ESPECIALES';
   r_log.fec_hor_ini   := SYSDATE;
   r_log.nro_reg       := 0;
   rg_movs.fecha       := pag_cal.fu_obt_fec_actual(5);
   rg_movs.fec_valor   := rg_movs.fecha;
   rg_movs.cod_usuario := USER;
   --- Verificar si es la misma hora del registro anterior
   SELECT nvl(MAX(hora), '23:59:59'), nvl(MAX(nro_secuencia), 0)
     INTO v_max_hora, v_max_nro_sec
     FROM ge_movimientos
    WHERE fecha = rg_movs.fecha
      AND cod_usuario = rg_movs.cod_usuario
      AND cod_tra_padre = v_cod_tra_padre;
   IF v_max_hora = v_hora THEN
      v_nro_secuencia := v_max_nro_sec;
   END IF;
   ---
   pag_cta.pr_obt_cuenta(p_nro_cuenta);
   BEGIN
      SELECT to_number(val_minimo), to_number(val_maximo)
        INTO v_val_minimo, v_val_maximo
        FROM ba_cod_referencias
       WHERE dominio = 'VAL_MTO_FINANCIADO'
         AND abreviatura = pag_cta.g_ctas.cod_moneda;
   EXCEPTION
      WHEN no_data_found THEN
         v_error := nvl(v_error, '') || 'No se parametrizó el dominio VAL_MTO_FINANCIADO';
      WHEN too_many_rows THEN
         v_error := nvl(v_error, '') || 'Más de una definición para el dominio VAL_MTO_FINANCIADO';
      WHEN OTHERS THEN
         v_error := nvl(v_error, '') || 'Al obt. dominio VAL_MTO_FINANCIADO:' || SQLERRM;
   END;
   ---
   BEGIN
      SELECT to_number(val_minimo)
        INTO v_cod_tip_saldo
        FROM ba_cod_referencias
       WHERE dominio = 'TIP_SAL_BANCARD'
         AND val_maximo = 'C';
   EXCEPTION
      WHEN no_data_found THEN
         v_error := nvl(v_error, '') || 'No se parametrizó el tipo de Saldo para Cancelación';
      WHEN too_many_rows THEN
         v_error := nvl(v_error, '') ||
                    'Más de una definición para el tipo de Saldo para Cancelación';
      WHEN OTHERS THEN
         v_error := nvl(v_error, '') || 'Al obt. tipo de Saldo para Cancelación:' || SQLERRM;
   END;
   IF v_error IS NULL THEN
      FOR j IN c_saldos LOOP
         --- El movimiento especial se debe realizar solo si los demás tipos de saldos
         --- (4, 13, 17, 32, 33, 34) son igual a 0 
         IF j.tip_movimiento = 'X' THEN
            IF nvl(j.mto_saldo, 0) <> 0 THEN
               v_error := nvl(v_error, '') || 'Tipo de Saldo ' || j.tip_saldo
                       || ' debe ser cero y su valor actual es '
                       || to_char(nvl(j.mto_saldo, 0),'999g999g999g999g999d99')
                       || ' ' || pag_cta.g_ctas.cod_moneda;
            END IF;
         ELSE
            v_mto_cancelacion := nvl(v_mto_cancelacion, 0) + nvl(j.mto_saldo, 0);
         END IF;
      END LOOP;
   END IF;
   IF v_error IS NULL THEN
      --- El movimiento especial se debe realizar si la suma algebraica de los saldos
      --- 1, 2 y 3 esta dentro del valor a lo parametrizado.
      IF nvl(v_mto_cancelacion, 0) < v_val_minimo THEN
         v_error := nvl(v_error, '') || 'Monto a Cancelar '
                 || to_char(nvl(v_mto_cancelacion, 0),'999g999g999g999g999d99')
                 || ' inferior al monto minimo '
                 || to_char(nvl(v_val_minimo, 0),'999g999g999g999g999d99')
                 || ' ' || pag_cta.g_ctas.cod_moneda;
      END IF;
      IF nvl(v_mto_cancelacion, 0) > v_val_maximo THEN
         v_error := nvl(v_error, '') || 'Monto a Cancelar '
                 || to_char(nvl(v_mto_cancelacion, 0),'999g999g999g999g999d99')
                 || ' superior al monto máximo '
                 || to_char(nvl(v_val_maximo, 0),'999g999g999g999g999d99')
                 || ' ' || pag_cta.g_ctas.cod_moneda;
      END IF;
   END IF;
   IF v_error IS NULL THEN
      --- Valida que la tarjeta tenga saldo O
      FOR j IN c_saldos LOOP
         --- Movimientos por Transferencia
         IF j.tip_movimiento = 'T' THEN
            IF nvl(j.mto_saldo, 0) > 0 THEN
               --- Movimiento por el Credito;
               lp_gen_movimiento(6564, abs(j.mto_saldo), j.cod_tip_saldo);
               lp_gen_movimiento(6563, abs(j.mto_saldo), v_cod_tip_saldo);
            ELSIF nvl(j.mto_saldo, 0) < 0 THEN
               --- Movimiento por el Debito;
               lp_gen_movimiento(6563, abs(j.mto_saldo), j.cod_tip_saldo);
               lp_gen_movimiento(6564, abs(j.mto_saldo), v_cod_tip_saldo);
            END IF;
         END IF;
         --- Movimientos por Cancelación
         IF j.tip_movimiento = 'C' THEN
            IF nvl(v_mto_cancelacion, 0) > 0 THEN
               --- Movimiento por el Credito;
               lp_gen_movimiento(6597, abs(v_mto_cancelacion), j.cod_tip_saldo);
            ELSIF nvl(v_mto_cancelacion, 0) < 0 THEN
               --- Movimiento por el Debito;
               lp_gen_movimiento(6596, abs(v_mto_cancelacion), j.cod_tip_saldo);
            END IF;
         END IF;
      END LOOP;
      SELECT MAX(nvl(fecha, rg_movs.fecha))
        INTO v_fec_cancelacion
        FROM ta_can_aut_tarjetas
       WHERE nro_cuenta = p_nro_cuenta
         AND estado = 'P';
      UPDATE ta_can_aut_tarjetas
         SET hora          = v_hora,
             cod_mod_padre = pag_cta.g_ctas.cod_modulo,
             cod_mad_padre = pag_cta.g_ctas.cod_modalidad,
             cod_tra_padre = v_cod_tra_padre
       WHERE nro_cuenta = p_nro_cuenta
         AND fecha = v_fec_cancelacion;
   ELSE
      --- Inserta en el log de Tarjetas
      r_log.comentario := v_error;
      prt_ins_log(r_log, FALSE);
   END IF;
   RETURN v_error;
END fut_gen_mov_especiales;
/

