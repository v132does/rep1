CREATE OR REPLACE PROCEDURE IT.prp_cob_car_liberacion
(
   p_nro_solicitud IN pr_solicitudes.nro_solicitud%TYPE,
   p_fec_actual    IN ge_calendarios.fec_actual%TYPE,
   p_hor_actual    IN ge_movimientos.hora%TYPE,
   p_nro_secuencia IN ge_movimientos.nro_secuencia%TYPE,
   p_cod_oficina   IN ge_cuentas.cod_oficina%TYPE
) IS
   v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
   v_nro_documento    ge_movimientos.nro_documento%TYPE;
   v_nro_secuencia    ge_movimientos.nro_secuencia%TYPE;
   v_monto            ge_movimientos.monto%TYPE;
   v_mto_impuesto     ge_movimientos.monto%TYPE;
   v_cod_retencion    cc_lib_ant_cheques.cod_retencion%TYPE;
   v_fec_final        cc_lib_ant_cheques.fec_final%TYPE;
BEGIN
   BEGIN
      SELECT a.nro_cuenta, a.nro_documento, a.cod_retencion, a.fec_final
        INTO v_nro_cuenta, v_nro_documento, v_cod_retencion, v_fec_final
        FROM cc_lib_ant_cheques a
       WHERE a.nro_sol_prestamo = p_nro_solicitud;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                                 'No existe solicitud ' || p_nro_solicitud ||
                                  'en CC_LIB_ANT_CHEQUES');
      WHEN too_many_rows THEN
         raise_application_error(-20000,
                                 'Mas de 1 solicitud ' || p_nro_solicitud ||
                                  'en CC_LIB_ANT_CHEQUES');
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al Obt.CC_LIB_ANT_CHEQUES ' || SQLERRM);
   END;
   ---
   v_nro_secuencia := nvl(p_nro_secuencia, 0);
   pag_cta.pr_obt_cuenta(v_nro_cuenta);
   -- Libera saldo retenido
   UPDATE ah_retenciones
      SET lib_posterior = 'S'
    WHERE nro_cuenta = v_nro_cuenta
      AND nro_documento = v_nro_documento
      AND cod_retencion = v_cod_retencion
      AND fec_final = v_fec_final;
   pae_cnf.g_nro_secuencia := nvl(v_nro_secuencia, 0);
   pra_lib_retencion(v_nro_cuenta, v_nro_cuenta, 'S', NULL, v_nro_documento, NULL, p_hor_actual,
                     USER);
   UPDATE ge_movimientos
      SET cod_tra_padre = 358,
          cod_mod_padre = 6,
          cod_mad_padre = 699,
          cod_ofi_origen = p_cod_oficina
    WHERE cod_usuario = user
      AND hora = p_hor_actual
      AND cod_tra_padre = 515
      AND cod_mod_padre = 4
      AND cod_mad_padre = 41;
   v_nro_secuencia := nvl(pae_cnf.g_nro_secuencia, 0);
   ---
   --- Monto del Interés y del Impuesto
   BEGIN
      SELECT t.mto_interes, t.mto_cargo
        INTO v_monto, v_mto_impuesto
        FROM pr_solicitudes t
       WHERE t.nro_solicitud = p_nro_solicitud;
   EXCEPTION
      WHEN no_data_found THEN
         v_monto        := 0;
         v_mto_impuesto := 0;
      WHEN too_many_rows THEN
         raise_application_error(-20000, 'Mas de 1 Solicitud');
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Al Obt.Solicitud: ' || SQLERRM);
   END;
   IF nvl(v_monto, 0) + nvl(v_mto_impuesto, 0) > 0 THEN
  	   pag_cta.g_sobregira := 'S';
      pag_cta.g_cod_error := 0;
      pag_cta.pr_act_operacion(v_nro_cuenta, p_hor_actual, 'D',
                               -- debito a la cuenta del cliente
                               pag_cta.g_ctas.cod_moneda,
                               nvl(v_monto, 0) + nvl(v_mto_impuesto, 0),405, 503,
                               -- trans. hijo
                               v_nro_documento, NULL,
                               -- cotizacion
                               p_cod_oficina, 6, 699, NULL,
                               -- tasa
                               NULL,
                               -- valor de tasa
                               'Cobro Cargo x Lib.Ant.C/O/B',
                               --concepto
                               'N',
                               -- emitir aviso
                               v_nro_secuencia,
                               -- nro de secuencia
                               p_fec_actual);
      IF pag_cta.g_cod_error <> 0 THEN
         raise_application_error(-20000,
                                 'Error: Cta.' || v_nro_cuenta || '-' || pag_cta.g_msj_error);
      END IF;
      ---
      pag_cta.g_sobregira := 'N';
      pag_cta.g_cod_error := 0;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'En obtener cargos' || ' - ' || SQLERRM);
      END IF;
END prp_cob_car_liberacion;
/

