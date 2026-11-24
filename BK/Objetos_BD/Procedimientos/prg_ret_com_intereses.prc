CREATE OR REPLACE PROCEDURE IT.prg_ret_com_intereses
(
   p_nro_devolucion  ge_ret_com_intereses.nro_devolucion%TYPE,
   p_cod_modulo      ge_ret_com_intereses.cod_modulo%TYPE,
   p_cod_modalidad   ge_ret_com_intereses.cod_modalidad%TYPE,
   p_cod_oficina     ge_ret_com_intereses.cod_oficina%TYPE,
   p_nro_cta_credito ge_ret_com_intereses.nro_cta_credito%TYPE,
   p_cod_moneda      ge_ret_com_intereses.cod_moneda%TYPE,
   p_cotizacion      ge_ret_com_intereses.cotizacion%TYPE
) IS

   CURSOR c_detalle IS
      SELECT *
        FROM ge_ret_com_intereses_det
       WHERE p_nro_devolucion = nro_devolucion;
   v_hora             ge_movimientos.hora%TYPE;
   v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE := 0;
   v_mto_credito      ge_movimientos.monto%TYPE;
   v_cod_tra_padre    ge_movimientos.cod_transaccion%TYPE := 2510;
   v_fec_actual       ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(1);
   v_cod_mon_local    ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_redondeo         NUMBER(5);
   rg_movs            ge_movimientos%ROWTYPE;
   v_es_nocturno      VARCHAR2(1) := 'N';
   v_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE;
   v_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE;
   v_val_tas_impuesto ge_movimientos.val_tasa%TYPE;
   v_mto_impuesto     ge_movimientos.monto%TYPE;
   v_mto_total        ge_movimientos.monto%TYPE := 0;
   v_sum_cotizacion   ge_movimientos.cotizacion%TYPE := 0;
   v_cantidad         NUMBER(5) := 0;
   v_cotizacion       ge_movimientos.cotizacion%TYPE := 0;
   v_mto_mon_local    ge_movimientos.monto%TYPE := 0;
BEGIN
   v_hora     := to_char(SYSDATE, 'HH24:MI:SS');
   v_hora     := fug_obt_hor_disponible(v_fec_actual, v_hora, USER, 'N');
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', p_cod_modulo, p_cod_modalidad,
                                     v_cod_mon_local);
   -- Movimientos contables
   FOR j IN c_detalle LOOP
      -- Obtener impuesto
      v_mto_credito := j.total;
      prg_obt_car_impuesto(p_cod_oficina, p_nro_cta_credito, p_cod_moneda, j.cod_modulo,
                           j.cod_modalidad, j.cod_transaccion, v_mto_credito, v_cod_tra_impuesto,
                           v_cod_tas_impuesto, v_val_tas_impuesto, v_mto_impuesto);
      ---
      IF v_nro_secuencia > 990 THEN
         v_hora          := pag_gen.fu_obt_sig_segundo(v_hora);
         v_nro_secuencia := -999;
      END IF;
      IF v_mto_credito <> 0 THEN
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.cod_transaccion := j.cod_transaccion;
         rg_movs.cod_modulo      := j.cod_modulo;
         rg_movs.cod_modalidad   := j.cod_modalidad;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_mod_padre   := p_cod_modulo;
         rg_movs.cod_mad_padre   := p_cod_modalidad;
         rg_movs.monto           := v_mto_credito;
         rg_movs.cod_moneda      := p_cod_moneda;
         --
         rg_movs.nro_cuenta     := NULL;
         rg_movs.cod_oficina    := p_cod_oficina;
         rg_movs.cod_usuario    := USER;
         rg_movs.hora           := v_hora;
         rg_movs.fecha          := v_fec_actual;
         rg_movs.nro_secuencia  := v_nro_secuencia;
         rg_movs.fec_valor      := v_fec_actual;
         rg_movs.nro_documento  := j.nro_devolucion;
         rg_movs.nro_documento2 := j.nro_linea;
         rg_movs.cod_tasa       := NULL;
         rg_movs.val_tasa       := v_val_tas_impuesto;
         rg_movs.cotizacion     := p_cotizacion;
         IF p_cod_moneda <> v_cod_mon_local THEN
            rg_movs.mto_equ_local := round(v_mto_credito * p_cotizacion, v_redondeo);
         ELSE
            rg_movs.mto_equ_local := 0;
         END IF;
         rg_movs.emi_aviso      := 'N';
         rg_movs.cod_ofi_origen := p_cod_oficina;
         rg_movs.concepto       := 'Devolución de Cargos o Intereses';
         rg_movs.estado         := 'N';
         rg_movs.est_cuenta     := 'N';
         rg_movs.reversado      := 'N';
         rg_movs.emi_aviso      := 'N';
         rg_movs.nro_caja       := NULL;
         rg_movs.cod_rubro      := NULL;
         rg_movs.tip_mov_rubro  := 'D';
         rg_movs.referencia     := j.nro_cta_operacion;
         pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         v_mto_total     := nvl(v_mto_total, 0) + nvl(v_mto_credito, 0);
         v_mto_mon_local := round(v_mto_mon_local) + nvl(rg_movs.mto_equ_local, 0);
      END IF;
      /*
      || IVA
      */
      IF v_mto_impuesto <> 0 THEN
         v_nro_secuencia         := v_nro_secuencia + 1;
         rg_movs.cod_transaccion := v_cod_tra_impuesto;
         rg_movs.cod_modulo      := j.cod_modulo;
         rg_movs.cod_modalidad   := j.cod_modalidad;
         rg_movs.cod_tra_padre   := v_cod_tra_padre;
         rg_movs.cod_mod_padre   := p_cod_modulo;
         rg_movs.cod_mad_padre   := p_cod_modalidad;
         rg_movs.monto           := v_mto_impuesto;
         rg_movs.cod_moneda      := p_cod_moneda;
         --
         rg_movs.nro_cuenta     := NULL;
         rg_movs.cod_oficina    := p_cod_oficina;
         rg_movs.cod_usuario    := USER;
         rg_movs.hora           := v_hora;
         rg_movs.fecha          := v_fec_actual;
         rg_movs.nro_secuencia  := v_nro_secuencia;
         rg_movs.fec_valor      := v_fec_actual;
         rg_movs.nro_documento  := j.nro_devolucion;
         rg_movs.nro_documento2 := j.nro_linea;
         rg_movs.cod_tasa       := v_cod_tas_impuesto;
         rg_movs.val_tasa       := v_val_tas_impuesto;
         rg_movs.cotizacion     := p_cotizacion;
         IF p_cod_moneda <> v_cod_mon_local THEN
            rg_movs.mto_equ_local := round(v_mto_impuesto * p_cotizacion, v_redondeo);
         ELSE
            rg_movs.mto_equ_local := 0;
         END IF;
         rg_movs.emi_aviso      := 'N';
         rg_movs.cod_ofi_origen := p_cod_oficina;
         rg_movs.concepto       := 'Devolución de Cargos o Intereses';
         rg_movs.estado         := 'N';
         rg_movs.est_cuenta     := 'N';
         rg_movs.reversado      := 'N';
         rg_movs.emi_aviso      := 'N';
         rg_movs.nro_caja       := NULL;
         rg_movs.cod_rubro      := NULL;
         rg_movs.tip_mov_rubro  := 'D';
         rg_movs.referencia     := j.nro_cta_operacion;
         pag_gen.pr_ins_ge_movimiento(rg_movs, v_es_nocturno);
         v_mto_total     := nvl(v_mto_total, 0) + nvl(v_mto_impuesto, 0);
         v_mto_mon_local := round(v_mto_mon_local) + nvl(rg_movs.mto_equ_local, 0);
      END IF;
      -- Acumula total a acreditar
      v_sum_cotizacion := nvl(v_sum_cotizacion, 0) + nvl(p_cotizacion, 0);
      v_cantidad       := nvl(v_cantidad, 0) + 1;
   END LOOP;
   ---
   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', p_cod_modulo, p_cod_modalidad,
                                     p_cod_moneda);
   IF v_cantidad = 0 THEN
      v_cantidad := 1; --Sin Detalle
   END IF;
   v_cotizacion := round(v_sum_cotizacion / v_cantidad, v_redondeo);
   -- Acreditar en la cuenta
   IF nvl(v_mto_total, 0) <> 0 THEN
      pag_cta.pr_act_operacion(p_nro_cta_credito, v_hora, 'C', p_cod_moneda, v_mto_total,
                               v_cod_tra_padre, 602, p_nro_devolucion, v_cotizacion, p_cod_oficina,
                               p_cod_modulo, p_cod_modalidad, NULL, NULL,
                               'Devolución de Cargos o Intereses', 'S', v_nro_secuencia,
                               v_fec_actual, NULL, NULL, v_mto_mon_local);
      IF pag_cta.g_cod_error <> 0 THEN
         raise_application_error(-20000,
                                 'Error Act.Operación.Cta.Crédito ' || p_nro_cta_credito || '-' ||
                                  pag_cta.g_msj_error);
      END IF;
   END IF;
END prg_ret_com_intereses;
/

