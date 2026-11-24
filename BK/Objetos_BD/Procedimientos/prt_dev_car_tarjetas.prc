CREATE OR REPLACE PROCEDURE it.prt_dev_car_tarjetas IS
  v_nro_cuenta     ge_cuentas.nro_cuenta%TYPE;
  v_cod_modulo     ge_cuentas.cod_modulo%TYPE;
  v_cod_modalidad  ge_cuentas.cod_modalidad%TYPE;
  v_cod_moneda     ge_cuentas.cod_moneda%TYPE;
  v_estado         ge_cuentas.estado%TYPE;
  v_fecha          DATE := trunc(SYSDATE);
  v_id             NUMBER;
  v_error          VARCHAR(1);
  v_mensaje        VARCHAR(1000);
  v_hora           ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_nro_secuencia  ge_movimientos.nro_secuencia%TYPE := 0;
  v_fec_actual     ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(3);
  v_nro_pedido     ge_mov_autorizaciones.nro_pedido%TYPE;
  v_est_movimiento ge_movimientos.estado%TYPE;
  v_nocturno       VARCHAR2(1);
  
  CURSOR c_cuentas IS
    SELECT t.nro_cuenta,
           t.tipo_movimiento,
           t.desc_movimiento,
           t.monto,
           t.cod_tra_padre,
           t.cod_transaccion,
           t.cod_ofi_origen,
           t.fecha,
           t.cod_usuario,
           t.procesado,
           t.id
      FROM tm_dev_car_tarjetas t
     WHERE nvl(t.procesado, 'N') = 'N'
       AND trunc(t.fecha) = v_fecha
       AND t.cod_usuario = USER
     ORDER BY t.id;
  --Actualiza registro procesado
  PROCEDURE pf_procesa_registro(p_cuenta  ge_cuentas.nro_cuenta%TYPE,
                                p_id      NUMBER,
                                p_mensaje VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE tm_dev_car_tarjetas t
       SET procesado = 'S', error = p_mensaje
     WHERE nro_cuenta = p_cuenta
       AND nvl(t.procesado, 'N') = 'N'
       AND trunc(t.fecha) = v_fecha
       AND t.cod_usuario = USER
       AND t.id = p_id;
    COMMIT;
  END;

BEGIN
  pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
  IF nvl(pag_cta.g_horario, 'D') = 'D' THEN
    v_nocturno := 'N';
  ELSE
    v_nocturno := 'S';
  END IF;
  
  FOR reg IN c_cuentas LOOP
    v_error      := 'N';
    v_mensaje    := NULL;
    v_nro_cuenta := reg.nro_cuenta;
    v_id         := reg.id;
    --Validar Cuenta
    BEGIN
      SELECT g.cod_modulo, g.cod_modalidad, g.estado, g.cod_moneda
        INTO v_cod_modulo, v_cod_modalidad, v_estado, v_cod_moneda
        FROM ge_cuentas g, ge_est_cuentas e
       WHERE g.nro_cuenta = v_nro_cuenta
         AND g.cod_modulo = e.cod_modulo
         AND g.cod_modalidad = e.cod_modalidad
         AND g.estado = e.estado
         AND e.activo = 'S';
      IF v_estado = 'C' THEN
        v_error   := 'S';
        v_mensaje := 'Nro de cuenta en estado cancelado o no valido para el credito.';
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        v_error   := 'S';
        v_mensaje := 'No se encontro Nro de cuenta ingresado.';
      WHEN OTHERS THEN
        v_error   := 'S';
        v_mensaje := substr(SQLERRM, 1, 1000);
    END;
    --Procesa movimiento para la Cuenta
    IF v_error = 'N' THEN
      v_nro_secuencia := v_nro_secuencia + 1;
      v_hora          := fug_obt_hor_disponible(v_fec_actual,
                                                v_hora,
                                                USER,
                                                v_nocturno);
      BEGIN
        SAVEPOINT before_insert;
        ----Genera pedido de autorización
        pag_rie.pr_ope_riesgo(v_fec_actual,
                              v_hora,
                              upper(USER),
                              reg.cod_transaccion, -- transacción padre 
                              v_cod_modulo, -- Módulo
                              v_cod_modalidad, -- Modalidad - Comercio Exterior
                              v_nro_cuenta, -- Nro_cuenta
                              NULL, -- Persona
                              'O', -- Tip_operacion 
                              reg.monto, -- Monto
                              NULL, -- Número de Documento
                              v_cod_moneda, -- Moneda
                              NULL, -- Cotización                       
                              v_nro_pedido);
        v_est_movimiento := 'P';
        pag_cta.pr_set_est_movimiento('P'); -- siempre queda en estado pendiente de aprobacion
        -- C.D. Fase II
        IF nvl(v_nro_pedido, 0) > 0 THEN
          UPDATE ge_mov_autorizaciones
             SET est_movimiento = 'N', est_cuenta = 'N'
           WHERE nro_pedido = v_nro_pedido;
        END IF;
        ----Inserción de movimientos
        it.pag_cta.pr_act_operacion(v_nro_cuenta, 
                                    v_hora,
                                    'C', --Tip_transaccion
                                    v_cod_moneda, -- cod moneda
                                    reg.monto, --Monto CURSOR
                                    reg.cod_tra_padre, --Cod_tra_padre
                                    reg.cod_transaccion, --Cod_transaccion
                                    v_nro_cuenta, --Nro documento
                                    NULL, --Cotizacion
                                    reg.cod_ofi_origen, --Cod_oficina
                                    v_cod_modulo, --Cod_modulo
                                    v_cod_modalidad, --Modalidad
                                    NULL, ---cod_tasa
                                    NULL, --Val_tasa
                                    reg.desc_movimiento, --Concepto
                                    'S', --Emi aviso
                                    v_nro_secuencia,
                                    v_fec_actual,
                                    NULL,
                                    NULL,
                                    NULL,
                                    v_est_movimiento);
                                    
        IF (pag_cta.g_cod_error <> 0) THEN
          v_error   := 'S';
          v_mensaje := substr(pag_cta.g_msj_error, 1, 1000);
        END IF;
        IF v_error = 'N' THEN
          COMMIT;
        ELSE
          ROLLBACK TO before_insert;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          v_error   := 'S';
          v_mensaje := substr(SQLERRM, 1, 1000);
          ROLLBACK TO before_insert;
      END;
    END IF;
    --Procesa registro
    pf_procesa_registro(v_nro_cuenta, v_id, v_mensaje);
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error prt_dev_car_tarjetas' || SQLERRM);
END;
/
