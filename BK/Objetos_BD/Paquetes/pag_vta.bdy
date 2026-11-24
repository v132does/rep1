CREATE OR REPLACE PACKAGE BODY IT."PAG_VTA" IS
  --Creado 13/08/2013-DI-WA: Requerimiento: Venta de Cartera
  -- Proceso Principal.
  PROCEDURE PR_GEN_VTA_CARTERA IS
  BEGIN
    NULL;
    /* ESTE PROCEDIMIENTO YA NO ES UTILIZADO DESPUES DE LA IMPLANTACION DEL PROYECTO
    DE AUTOMATIZACION DE VENTA DE CARTERA (CROPVNDC - HO)*/
    ---
    -- Proceso de Validación y Cancelación de Cuentas.
    --PR_VAL_VTA_CARTERA;
    --PR_VTA_CAR_PRESTAMOS;
    --PR_VTA_CAR_SOBREGIROS;
    --PR_VTA_CAR_OPE_VENCIDAS;
    -- Generación del Informe de Venta de Cartera.
    --PA_REP_AUT.PR_INF_VTA_CARTERA;
  END;

  -- Realiza la validación de las cuentas importadas.
  PROCEDURE PR_VAL_VTA_CARTERA IS
  
    -- Cursores.
    CURSOR c_clientes IS
      SELECT DISTINCT pr.cod_persona
      FROM pr_vta_cartera pr;
  
    -- Variables.
    v_cantidad            NUMBER := 0;
    v_nro_cuenta          ge_cuentas.nro_cuenta%TYPE := NULL;
    v_par_mod_vta_cartera ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('INV_VTA_CAR_TOT_RIESGO');
  
  BEGIN
  
    -- Verifico que las cuentas esten registradas en el sistema.
    BEGIN
      /*SELECT COUNT(1) CROPVNDC - HO - Se ajusta la logica de la query
       INTO v_cantidad
       FROM pr_vta_cartera pr
      WHERE NOT EXISTS (SELECT 1 FROM ge_cuentas ge WHERE ge.nro_cuenta = pr.nro_cuenta);*/
      SELECT COUNT(1)
      INTO v_cantidad
      FROM pr_vta_cartera pr, ge_cuentas g
      WHERE pr.nro_cuenta = g.nro_cuenta;
    
      IF v_cantidad = 0 THEN
        raise_application_error(-20000, 'Las cuentas no están registradas en el sistema. ' || ' ' ||
                                 SQLERRM);
      END IF;
    END;
  
    -- Verifico que las cuentas importadas correspondan al modulo de prestamo y cuenta corrientes.
    BEGIN
      SELECT COUNT(1)
      INTO v_cantidad
      FROM pr_vta_cartera pr, ge_cuentas ge
      WHERE pr.nro_cuenta = ge.nro_cuenta
      AND ge.cod_modulo NOT IN (4, 6, 15);
    
      IF v_cantidad > 0 THEN
        v_nro_cuenta := NULL;
        SELECT NVL(MIN(pr.nro_cuenta), ' ')
        INTO v_nro_cuenta
        FROM pr_vta_cartera pr, ge_cuentas ge
        WHERE pr.nro_cuenta = ge.nro_cuenta
        AND ge.cod_modulo NOT IN (4, 6, 15);
        raise_application_error(-20000, 'La cuenta importada ' ||
                                 v_nro_cuenta ||
                                 ' no corresponde al Módulo de Préstamos/Sobregiros/Op. Vencidas.' || ' ' ||
                                 SQLERRM);
      END IF;
    END;
  
    -- Verifica que no se importe cuentas canceladas.
    BEGIN
      SELECT COUNT(1)
      INTO v_cantidad
      FROM pr_vta_cartera pr, pr_cta_prestamos pc
      WHERE pr.nro_cuenta = pc.nro_cuenta
      AND pc.estado IN ('N', 'I');
    
      IF v_cantidad > 0 THEN
        raise_application_error(-20000, 'Existen cuentas del Modulo de Préstamos Canceladas. ' || ' ' ||
                                 SQLERRM);
      END IF;
    END;
  
    BEGIN
      SELECT COUNT(1)
      INTO v_cantidad
      FROM pr_vta_cartera pr, cc_cta_corrientes cc
      WHERE pr.nro_cuenta = cc.nro_cuenta
      AND cc.estado IN ('C', 'P', 'A', 'X');
    
      IF v_cantidad > 0 THEN
        raise_application_error(-20000, 'Existen cuentas del Modulo de Cuentas Corrientes Canceladas. ' || ' ' ||
                                 SQLERRM);
      END IF;
    END;
  
    BEGIN
      SELECT COUNT(1)
      INTO v_cantidad
      FROM pr_vta_cartera pr, cc_cta_corrientes cc
      WHERE pr.nro_cuenta = cc.nro_cuenta
      AND nvl(cc.sal_total, 0) - nvl(cc.sal_retenido, 0) -
            nvl(cc.sal_bloqueado, 0) > 0;
    
      IF v_cantidad > 0 THEN
        raise_application_error(-20000, 'Existen cuentas del Modulo de Cuentas Corrientes con Saldo Acreedor. ' || ' ' ||
                                 SQLERRM);
      END IF;
    END;
  
    BEGIN
      SELECT COUNT(1)
      INTO v_cantidad
      FROM pr_vta_cartera pr, ov_cta_vencidas ov
      WHERE pr.nro_cuenta = ov.nro_cuenta
      AND ov.estado IN ('C', 'I');
    
      IF v_cantidad > 0 THEN
        raise_application_error(-20000, 'Existen cuentas del Modulo de Operaciones Vencidas Canceladas. ' || ' ' ||
                                 SQLERRM);
      END IF;
    END;
  
    FOR reg IN c_clientes
    LOOP
    
      -- Verifico que el cliente no posea operaciones distintas a los módulos parametrizados en el parámetro dinámico INV_VTA_CAR_TOT_RIESGO.
      BEGIN
        SELECT COUNT(1)
        INTO v_cantidad
        FROM pr_vta_cartera pr, ge_cta_clientes ge
        WHERE pr.nro_cuenta = ge.nro_cuenta
        AND ge.cod_persona = reg.cod_persona
        AND ge.relacion = 'P'
        AND instr(ge.cod_modulo, v_par_mod_vta_cartera) > 0;
      
        IF v_cantidad > 0 THEN
          raise_application_error(-20000, 'El cliente posee cuentas vigentes distintos a los Modulos de Préstamos/Sobregiros/Tarjetas/Operaciones Vencidas: ' ||
                                   reg.cod_persona || ' ' || SQLERRM);
        END IF;
      END;
    
      -- Verifico que el cliente o codeudor del cliente no deberá poseer garantías reales activas.
      BEGIN
        SELECT COUNT(1)
        INTO v_cantidad
        FROM pr_garantias pr, pr_gar_tipos pg
        WHERE pr.cod_persona = reg.cod_persona
        AND pr.estado IN ('C', 'V', 'T')
        AND pr.cod_garantia = pg.cod_garantia
        AND pg.computable = 'S';
      
        IF v_cantidad > 0 THEN
          raise_application_error(-20000, 'El cliente posee garantías reales vigentes. ' ||
                                   reg.cod_persona || ' ' || SQLERRM);
        END IF;
      END;
    
    END LOOP;
  
    -- Asigno el valor al campo TIP_DEUDA por la incorrecta asignación de valores.
    BEGIN
      UPDATE pr_vta_cartera pr
      SET pr.tipo_deuda = 'P'
      WHERE EXISTS (SELECT 1
             FROM pr_cta_prestamos pc
             WHERE pc.nro_cuenta = pr.nro_cuenta);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    BEGIN
      UPDATE pr_vta_cartera pr
      SET pr.tipo_deuda = 'S'
      WHERE EXISTS (SELECT 1
             FROM cc_cta_corrientes cc
             WHERE cc.nro_cuenta = pr.nro_cuenta);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    BEGIN
      UPDATE pr_vta_cartera pr
      SET pr.tipo_deuda = 'V'
      WHERE EXISTS (SELECT 1
             FROM ov_cta_vencidas ov
             WHERE ov.nro_cuenta = pr.nro_cuenta);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20000, 'Validación de Cuentas. ' || SQLERRM);
  END;

  -- Realiza la venta de cartera de cuentas corrientes en sobregiro.
  PROCEDURE PR_VTA_CAR_SOBREGIROS(P_REF_LOTE IN NUMBER) IS
  
    -- Cursores.
    -- Recuperar datos de la cuenta a cancelar
    CURSOR c_cta_corrientes IS
      SELECT cc.cod_modulo,
             cc.cod_modalidad,
             cc.nro_cuenta,
             cc.cod_oficina,
             NVL(cc.cta_combinada, 'N') cta_combinada,
             ABS(NVL(sal_total, 0) - NVL(sal_bloqueado, 0) -
                 NVL(sal_retenido, 0)) sal_actual,
             cc.estado,
             cc.cod_moneda,
             nvl((SELECT MAX(cs.sit_deuda)
                 FROM cc_sobregiros_res cs
                 WHERE cs.nro_cuenta = cc.nro_cuenta), cc.estado) situacion
      FROM cc_cta_corrientes cc, pr_vta_cartera prv
      WHERE cc.nro_cuenta = prv.nro_cuenta
      AND cc.estado <> 'C';
  
    CURSOR c_mov_pendientes(p_nro_cuenta IN ge_movimientos.nro_cuenta%TYPE) IS
      SELECT gm.nro_cuenta, gm.rowid
      FROM ge_mov_pendientes gm
      WHERE gm.nro_cuenta = p_nro_cuenta
      AND NVL(gm.saldo, 0) > 0
      AND estado = 'I'
      AND NVL(mto_exonerado, 0) = 0;
  
    -- Variables.
    r_gmovi               ge_movimientos%ROWTYPE;
    v_impuesto            ge_movimientos.monto%TYPE := 0;
    v_interes             ge_movimientos.monto%TYPE := 0;
    v_mto_sobregiro       ge_movimientos.monto%TYPE := 0;
    v_mto_prevision       ge_movimientos.monto%TYPE := 0;
    v_nro_secuencia       ge_movimientos.nro_secuencia%TYPE := 0;
    v_fecha               ge_movimientos.fecha%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(1);
    v_hora                ge_movimientos.hora%TYPE;
    v_cotizacion          ge_movimientos.cotizacion%TYPE := 0;
    v_nro_cuenta          cc_cta_corrientes.nro_cuenta%TYPE;
    v_sec_lin_sobregiro   cc_lin_sobregiros.nro_sec_padre%TYPE := NULL;
    v_nro_linea           cc_lin_sobregiros.nro_linea%TYPE := NULL;
    v_cod_cau_cancelacion ge_causales.cod_causa%TYPE := fug_obt_pardinamico('COD_CAU_CAN_VTA_CARTERA');
    v_cod_mon_local       ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_redondeo_ml         NUMBER(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 4, NULL, pag_gen.fu_obt_mon_local);
    v_cantidad            NUMBER(1) := 0;
    v_msj                 VARCHAR2(250);
  BEGIN
    FOR reg IN c_cta_corrientes
    LOOP
      -- Asigno el valor a la variable.
      v_nro_cuenta := reg.nro_cuenta;
      v_hora       := fug_obt_hor_disponible(v_fecha, to_char(SYSDATE, 'HH24:MI:SS'), USER, 'N');
    
      -- Obtengo la cotizacion del día.
      IF reg.cod_moneda = v_cod_mon_local THEN
        v_cotizacion := NULL;
      ELSE
        v_cotizacion := pag_gen.fu_obt_cotizacion(reg.cod_moneda);
      END IF;
    
      -- Liquidación de los gastos por sobregiros.
      v_impuesto := 0;
      v_interes  := 0;
      BEGIN
        pae_cnf.G_HORA := v_hora;
        pac_sob.pr_pro_liq_sob(P_NRO_CUENTA => reg.nro_cuenta, P_PROCESAR => 'S', P_IMPUESTO => v_impuesto, P_INTERES => v_interes);
      
        pac_sob.pr_act_liq_sob(reg.nro_cuenta);
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- Exonera los movimientos pendientes que posee la cuenta.
      FOR reg_mov IN c_mov_pendientes(reg.nro_cuenta)
      LOOP
      
        UPDATE ge_mov_pendientes gm
        SET gm.estado             = 'E',
            gm.mto_exonerado      = gm.saldo,
            gm.saldo              = 0,
            gm.cod_usu_exonerador = upper(USER),
            gm.motivo             = 'EXONERACION POR VENTA DE CARTERA'
        WHERE gm.rowid = reg_mov.rowid;
      END LOOP;
    
      -- Acredito el monto sobregirado de la cuenta.
      v_mto_sobregiro := NVL(reg.sal_actual, 0) + NVL(v_interes, 0) +
                         NVL(v_impuesto, 0);
      --
      v_nro_secuencia := nvl(pae_cnf.G_NRO_SECUENCIA, 0);
      v_nro_secuencia := v_nro_secuencia + 1;
      --
      pag_cta.pr_act_operacion(reg.nro_cuenta, v_hora, 'C', reg.cod_moneda, --Moneda de la Operacion.
                               v_mto_sobregiro, 5604, -- Transacción Padre.
                               5604, -- Transacción Hijo.
                               NULL, v_cotizacion, reg.cod_oficina, -- Oficina Origen
                               reg.cod_modulo, -- Modulo Padre
                               reg.cod_modalidad, -- Modalidad Padre
                               NULL, -- Código Tasa
                               NULL, -- Valor Tasa
                               'Cancelación por Vta. de Cartera', 'S', v_nro_secuencia, v_fecha);
    
      -- Elimina la cuenta combinada.
      IF NVL(reg.cta_combinada, 'N') = 'S' THEN
        DELETE cc_cta_combinadas cc
        WHERE cc.nro_cta_cte = reg.nro_cuenta;
      END IF;
    
      -- Elimino la vinculación a la tarjeta de debito.
      BEGIN
        UPDATE ah_tar_debitos
        SET cod_est_solicitud = 16
        WHERE nro_cuenta = reg.nro_cuenta
        AND cod_est_solicitud NOT IN (1, 2, 3, 16);
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      BEGIN
        UPDATE ah_tar_debitos
        SET cod_est_solicitud = 1
        WHERE nro_cuenta = reg.nro_cuenta
        AND cod_est_solicitud < 4;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      BEGIN
        DELETE ah_tar_deb_cuentas
        WHERE nro_cta_relacionada = reg.nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- Elimina la vinculación a débitos automaticos.
      BEGIN
        UPDATE pr_cta_prestamos pr
        SET pr.cob_automatico = 'N', pr.nro_cta_debito = NULL
        WHERE pr.nro_cta_debito = reg.nro_cuenta
        AND pr.estado != 'N'; -- Préstamos no CANCELADOS;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      BEGIN
        UPDATE ta_cta_tarjetas ta
        SET ta.deb_automatico = 'N', ta.nro_cta_debito = NULL
        WHERE ta.nro_cta_debito = reg.nro_cuenta
        AND estado != 'C'; -- Tarjetas no Canceladas;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      BEGIN
        UPDATE ah_cta_certificados ac
        SET ac.nro_cta_credito = NULL
        WHERE ac.nro_cta_credito = reg.nro_cuenta
        AND ac.estado NOT IN ('T', 'C'); -- (T)otalmente Pagada y (C)ancelada;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      BEGIN
        UPDATE cs_contratos cs
        SET cs.nro_cta_debito = NULL
        WHERE cs.nro_cta_debito = reg.nro_cuenta
        AND cs.estado NOT IN ('C', 'R'); -- (C)ancelados y (R)echazados;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- Se elimina la línea de sobregiro vigente vinculada a la cuenta.
      pag_cta.pr_obt_cuenta(reg.nro_cuenta);
      IF pag_cta.fu_acu_sobregiro = 'S' THEN
        --
        BEGIN
          -- Obtener el número de secuencia padre.
          SELECT cl.nro_sec_padre, cl.nro_linea
          INTO v_sec_lin_sobregiro, v_nro_linea
          FROM cc_lin_sobregiros cl
          WHERE cl.nro_cuenta = reg.nro_cuenta;
        
          -- Actualizo el estado de la línea de sobregiro.
          UPDATE cc_lin_sobregiros cl
          SET cl.estado           = 'C',
              cl.observacion      = 'CANCELACION POR VENTA DE CARTERA',
              cl.cod_usu_autoriza = upper(USER),
              cl.niv_aprobacion   = 31
          WHERE cl.nro_sec_padre = v_sec_lin_sobregiro;
        
          -- Elimino la línea de sobregiro y actualizo los datos del historico.
          prc_eli_lin_sobregiro(v_sec_lin_sobregiro, v_nro_linea);
        
        EXCEPTION
          WHEN OTHERS THEN
            raise_application_error(-20000, 'Cuenta posee línea de sobregiro vigente: ' ||
                                     v_nro_cuenta || ' ' || SQLERRM);
        END;
      
      END IF;
    
      -- Verifica si la cuenta posee cheques en custodía.
      BEGIN
        SELECT 1
        INTO v_cantidad
        FROM ge_che_custodias
        WHERE nro_referencia = reg.nro_cuenta
        AND estado IN ('C');
      
        raise_application_error(-20000, 'Cuenta posee cheques en custodía vigentes: ' ||
                                 v_nro_cuenta || ' ' || SQLERRM);
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- Verifica que no posea movimientos pendientes registrados en caja.
      BEGIN
        SELECT 1
        INTO v_cantidad
        FROM ge_movimientos
        WHERE nro_cuenta = reg.nro_cuenta
        AND reversado = 'N'
        AND estado IN ('J', 'X', 'P')
        AND rownum = 1;
      
        raise_application_error(-20000, 'Cuenta posee pendientes registrados en caja: ' ||
                                 v_nro_cuenta || ' ' || SQLERRM);
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- Elimina transacciones prohibidas.
      BEGIN
        DELETE ge_tra_prohibidas
        WHERE nro_cuenta = reg.nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- Verifica que la cuenta no tenga bloqueo.
      BEGIN
        SELECT 1
        INTO v_cantidad
        FROM ge_bloqueos
        WHERE nro_cuenta = reg.nro_cuenta;
      
        raise_application_error(-20000, 'Cuenta posee bloqueos: ' ||
                                 v_nro_cuenta || ' ' || SQLERRM);
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      -- Cancelo la cuenta corriente.
      UPDATE cc_cta_corrientes
      SET tra_prohibida = 'N', cod_cau_cancelacion = v_cod_cau_cancelacion
      WHERE nro_cuenta = reg.nro_cuenta;
      --actualizar el estado con el pag_cta para poder reversar
      pag_cta.pr_set_variables(upper(USER), v_fecha, '406', --cancelación
                               'N', --estado mvto
                               'N', --reversado
                               v_nro_secuencia, 'C', -- estado
                               reg.cod_oficina, reg.cod_modulo, reg.cod_modalidad);
      --
      pag_cta.pr_act_estado(reg.nro_cuenta, 'C', v_fecha, v_hora, NULL, 'S'); --genera movimiento trans406
      IF pag_cta.fu_obt_cod_error() <> 0 THEN
        raise_application_error(-20000, 'Act.Est.' ||
                                 pag_cta.fu_obt_msj_error());
      END IF;
    
      -- Aplicación de la previsión.
      v_nro_secuencia   := v_nro_secuencia + 1;
      pac_mes.v_fcdehoy := v_fecha;
      v_mto_prevision   := pac_mes.FU_OBT_PREVISION(reg.nro_cuenta);
      IF nvl(v_mto_prevision, 0) > 0 THEN
        -- Genero el movimiento.
        -- Genero movimiento de aplicación de la previsión.
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := upper(USER);
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.cod_modulo      := reg.cod_modulo;
        r_gmovi.cod_modalidad   := reg.cod_modalidad;
        r_gmovi.cod_oficina     := reg.cod_oficina;
        r_gmovi.nro_cuenta      := reg.nro_cuenta;
        r_gmovi.cod_moneda      := reg.cod_moneda;
        r_gmovi.est_cuenta := (CASE
                                WHEN reg.situacion = 'S' THEN
                                 'N'
                                ELSE
                                 reg.situacion
                              END);
        r_gmovi.cod_persona     := NULL;
        r_gmovi.cod_tra_padre   := 957;
        r_gmovi.cod_transaccion := 957;
        r_gmovi.concepto        := 'PREVISION VENTA CARTERA';
        r_gmovi.monto           := nvl(v_mto_prevision, 0);
        r_gmovi.fec_valor       := v_fecha;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := reg.cod_oficina;
        r_gmovi.cod_mod_padre   := reg.cod_modulo;
        r_gmovi.cod_mad_padre   := reg.cod_modalidad;
        r_gmovi.referencia      := '8843';
        r_gmovi.nro_documento   := NULL;
        IF reg.cod_moneda = v_cod_mon_local THEN
          r_gmovi.cotizacion    := NULL;
          r_gmovi.mto_equ_local := NULL;
        ELSE
          r_gmovi.cotizacion    := v_cotizacion;
          r_gmovi.mto_equ_local := round(trunc(nvl(v_mto_prevision, 0), 2) *
                                         v_cotizacion, v_redondeo_ml);
        END IF;
        IF r_gmovi.monto <> 0 THEN
          --
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
        
          -- Cero las previsiones
          INSERT INTO cc_previsiones
            (fecha,
             nro_cuenta,
             monto,
             saldo,
             linea,
             porcentaje,
             situacion,
             tot_gar_computable,
             tot_pri_prevision,
             tot_prv_contingencia)
          VALUES
            (v_fecha, reg.nro_cuenta, 0, 0, 0, 0, 1, 0, 0, 0);
        END IF;
      END IF;
    
      -- Genero movimiento de cancelacion por venta de cartera.
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := upper(USER);
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.cod_modulo      := reg.cod_modulo;
      r_gmovi.cod_modalidad   := reg.cod_modalidad;
      r_gmovi.cod_oficina     := reg.cod_oficina;
      r_gmovi.nro_cuenta      := reg.nro_cuenta;
      r_gmovi.cod_moneda      := reg.cod_moneda;
      r_gmovi.est_cuenta      := NULL;
      r_gmovi.cod_persona     := NULL;
      r_gmovi.cod_tra_padre   := 8843;
      r_gmovi.cod_transaccion := 8843;
      r_gmovi.concepto        := 'Cancelación por Vta. de Cartera';
      r_gmovi.monto           := nvl(v_mto_sobregiro, 0) -
                                 nvl(v_mto_prevision, 0);
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := reg.cod_oficina;
      r_gmovi.cod_mod_padre   := reg.cod_modulo;
      r_gmovi.cod_mad_padre   := reg.cod_modalidad;
      r_gmovi.referencia      := '8843';
      r_gmovi.nro_documento   := NULL;
      IF reg.cod_moneda = v_cod_mon_local THEN
        r_gmovi.cotizacion    := NULL;
        r_gmovi.mto_equ_local := NULL;
      ELSE
        r_gmovi.cotizacion    := v_cotizacion;
        r_gmovi.mto_equ_local := round(trunc(nvl(v_mto_sobregiro, 0) -
                                             nvl(v_mto_prevision, 0), 2) *
                                       v_cotizacion, v_redondeo_ml);
      END IF;
      IF r_gmovi.monto <> 0 THEN
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
    
      -- Modificado 14/07/2016- CNFICRC-275
      -- Genero movimiento cta de orden alta por venta de cartera.
      v_nro_secuencia         := v_nro_secuencia + 1;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := upper(USER);
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.cod_modulo      := reg.cod_modulo;
      r_gmovi.cod_modalidad   := reg.cod_modalidad;
      r_gmovi.cod_oficina     := reg.cod_oficina;
      r_gmovi.nro_cuenta      := reg.nro_cuenta;
      r_gmovi.cod_moneda      := reg.cod_moneda;
      r_gmovi.est_cuenta      := NULL;
      r_gmovi.cod_persona     := NULL;
      r_gmovi.cod_tra_padre   := 8846;
      r_gmovi.cod_transaccion := 8846;
      r_gmovi.concepto        := 'Alta por Vta. de Cartera Cta. Orden';
      r_gmovi.monto           := nvl(v_mto_sobregiro, 0);
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := reg.cod_oficina;
      r_gmovi.cod_mod_padre   := reg.cod_modulo;
      r_gmovi.cod_mad_padre   := reg.cod_modalidad;
      r_gmovi.referencia      := '8846';
      r_gmovi.nro_documento   := NULL;
      IF reg.cod_moneda = v_cod_mon_local THEN
        r_gmovi.cotizacion    := NULL;
        r_gmovi.mto_equ_local := NULL;
      ELSE
        r_gmovi.cotizacion    := v_cotizacion;
        r_gmovi.mto_equ_local := round(trunc(nvl(v_mto_sobregiro, 0), 2) *
                                       v_cotizacion, v_redondeo_ml);
      END IF;
      IF r_gmovi.monto <> 0 THEN
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
    
      v_nro_secuencia := 0;
      --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora); --CROPVNDC -HO
      r_gmovi.referencia := NULL;
      --CROPVNDC -HO -Se guarda en el historial de venta de cartera la hora de cancelacion y se cambia de Estado a V-endido
      UPDATE ge_sal_inv_vta_cartera_tmp
      SET hor_cancelacion = v_hora, estado = 'V'
      WHERE nro_cuenta = reg.nro_cuenta
      AND ref_lote = P_REF_LOTE
      AND cod_modulo = 4
      AND estado = 'N';
    END LOOP;
    -- Elimina los registros de la tabla de venta de cartera con tipo de saldo "S".
    DELETE pr_vta_cartera pv
    WHERE UPPER(pv.tipo_deuda) = 'S';
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      -- Se elimina los datos importados.
      sql_util.ejecute_dml('TRUNCATE TABLE PR_VTA_CARTERA', v_msj);
      IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
      END IF;
      -- Se despliega el mensaje de error.
      raise_application_error(-20000, 'Error al ejecutar procedimiento: ' ||
                               v_nro_cuenta || ' ' || SQLERRM);
  END;

  -- Realiza la venta de cartera de préstamos.
  PROCEDURE PR_VTA_CAR_PRESTAMOS(P_REF_LOTE IN NUMBER) IS
  
    -- Recuperar datos de la cuenta a cancelar
    -->21/06/2013-DI-MB: Req. Venta de Cartera (Préstamos)
    CURSOR c_cancelar IS
      SELECT pr.nro_cuenta,
             pr.cod_oficina,
             nvl(pr.mto_capital, 0) mto_capital,
             pr.nro_solicitud,
             pr.cod_moneda,
             nvl(pr.sal_capital, 0) sal_capital,
             nvl(pr.val_int_devengar, 0) val_int_devengar,
             nvl(pr.dev_suspenso, 0) dev_suspenso,
             pr.estado,
             pr.tipo,
             pr.tip_interes,
             pr.tip_renovacion,
             pr.cod_modalidad,
             nvl(pr.dev_no_cobrado, 0) dev_no_cobrado
      FROM pr_cta_prestamos pr, pr_vta_cartera prv
      WHERE pr.nro_cuenta = prv.nro_cuenta
      AND pr.estado <> 'N';
  
    -- Variables de tipo registro.
    r_gmovi     ge_movimientos%ROWTYPE;
    r_psoli     pr_solicitudes%ROWTYPE;
    r_pcpre     pr_cta_prestamos%ROWTYPE;
    r_gauto     ge_autorizaciones%ROWTYPE;
    r_pcpre_vta pr_cta_prestamos%ROWTYPE;
  
    v_fecha           ge_calendarios.fec_actual%TYPE;
    v_hora            ge_movimientos.hora%TYPE;
    v_cod_usuario     ge_movimientos.cod_usuario%TYPE;
    v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
    v_cod_modulo      ba_modulos.cod_modulo%TYPE;
    v_sal_capital     pr_cuotas.sal_capital%TYPE;
    v_sal_interes     pr_cuotas.sal_interes%TYPE;
    v_sal_int_ade     pr_cuotas.sal_int_documentado%TYPE;
    v_mora            pr_cuotas.sal_interes%TYPE;
    v_mora_interes    pr_cuotas.sal_interes%TYPE;
    v_mora_int_ade    pr_cuotas.sal_interes%TYPE;
    v_impuesto        pr_cuotas.sal_interes%TYPE;
    v_cargo           pr_cuotas.sal_interes%TYPE;
    v_cargo_iva       pr_cuotas.sal_interes%TYPE;
    v_punitorio       pr_cuotas.sal_interes%TYPE;
    v_int_descontado  pr_cuotas.sal_interes%TYPE;
    v_tot_deuda       pr_cta_prestamos.monto%TYPE;
    v_cotizacion      ge_cotizaciones.val_conversion%TYPE := NULL;
    v_cuenta          pr_cta_prestamos.nro_cuenta%TYPE;
    v_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
    v_mto_prevision   ge_movimientos.monto%TYPE;
    v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_redondeo_ml     NUMBER(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, NULL, pag_gen.fu_obt_mon_local);
    v_dias_mora       NUMBER(05);
    v_car_seguro      NUMBER;
    v_error           VARCHAR2(10);
    v_mensaje         VARCHAR2(1000);
    v_msj             VARCHAR2(250);
    v_mto_dif         ge_movimientos.monto%type;
  
    -- Procedimientos Internos.
    PROCEDURE pp_ins_autorizacion(p_gauto ge_autorizaciones%ROWTYPE) IS
    BEGIN
      INSERT INTO ge_autorizaciones
        (cod_autorizacion,
         nro_cuenta,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_transaccion,
         cod_modulo,
         cod_modalidad,
         valor,
         fec_vencimiento,
         cod_usu_autorizador,
         observacion)
      VALUES
        (s_cod_autorizacion.nextval,
         p_gauto.nro_cuenta,
         p_gauto.cod_tra_padre,
         p_gauto.cod_mod_padre,
         p_gauto.cod_mad_padre,
         p_gauto.cod_transaccion,
         p_gauto.cod_modulo,
         p_gauto.cod_modalidad,
         p_gauto.valor,
         p_gauto.fec_vencimiento,
         p_gauto.cod_usu_autorizador,
         p_gauto.observacion);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20005, 'Error al insertar autorizacion: ' ||
                                 SQLERRM);
    END;
  
    PROCEDURE pp_cob_car_adicionales(p_cuenta pr_cta_prestamos.nro_cuenta%TYPE) IS
    BEGIN
      UPDATE pr_cta_gastos gas
      SET gas.fec_ult_pago = trunc(SYSDATE),
          gas.hor_ult_pago = to_char(SYSDATE, 'hh24:mi:ss')
      WHERE gas.nro_cuenta = p_cuenta
      AND gas.cod_transaccion NOT IN (1520, 1521) /*Seguro cuotizados.*/
      AND gas.fec_ult_pago IS NULL;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20006, 'Error al eliminar cargos adicionales: ' ||
                                 p_cuenta || ' ' || SQLERRM);
    END;
  
  BEGIN
    -- Variables.
    v_cod_modulo := 6;
    v_fecha      := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
    --v_hora           := to_char(sysdate,'HH24:MI:SS'); --CROPVNDC -HO
  
    -- Cursor.
    FOR ren IN c_cancelar
    LOOP
      v_cuenta := ren.nro_cuenta;
      pap_pre.PR_OBT_DAT_PRESTAMO(ren.nro_cuenta, r_pcpre_vta); --DYDMR-21789 se agrego por incidencia en consolidacion de asientos G.O. 
      v_hora := fug_obt_hor_disponible(v_fecha, to_char(SYSDATE, 'HH24:MI:SS'), USER, 'N');
    
      -->21/06/2013-DI-MB: Req. Venta de Cartera (Préstamos). Obtengo la cotizacion del día.
      IF ren.cod_moneda = v_cod_mon_local THEN
        v_cotizacion := NULL;
      ELSE
        v_cotizacion := pag_gen.fu_obt_cotizacion(ren.cod_moneda);
      END IF;
    
      --Marcar como pagados cargos adicionales de las cuentas que se van a vender.
      pp_cob_car_adicionales(v_cuenta);
    
      --- Recuperar datos de la solicitud
      BEGIN
        SELECT *
        INTO r_psoli
        FROM pr_solicitudes psol
        WHERE psol.nro_solicitud = ren.nro_solicitud;
      EXCEPTION
        WHEN OTHERS THEN
          raise_application_error(-20002, 'Error al cargar datos de solicitud:' ||
                                   ren.nro_solicitud);
      END;
    
      --- Recuperar datos de la deuda
      pap_pre.pr_ini_autorizacion;
      pap_pre.PR_INI_VAR_COBRO;
      pap_pre.pr_obt_deu_prestamo(ren.nro_cuenta, v_fecha, 0, 999, ren.cod_oficina, NULL, v_error, v_mensaje, v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes, v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado, v_dias_mora, 359, 'T', 'S');
      IF v_error <> 0 THEN
        raise_application_error(-20001, v_mensaje);
      END IF;
      IF r_psoli.tip_renovacion = 'D' THEN
        -- desembolso en etapas
        pap_pre.pr_obt_car_seg_cuotas(ren.nro_cuenta, v_car_seguro);
      END IF;
      --- Generar autorizaciones por conceptos a no cobrarse
      -->21/06/2013-DI-MB: Req. Venta de Cartera (Préstamos).
      /*if nvl(v_sal_interes,0) <> 0 then --Interes
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('IN', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := ren.nro_cuenta;
         r_gauto.cod_tra_padre       := 359;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := ren.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := ren.cod_modalidad;
         r_gauto.valor               := nvl(v_sal_interes,0) - ren.dev_no_cobrado;
         r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
         r_gauto.observacion         := 'Venta de Cartera';
         --- insertar ge_autorizaciones
         pp_ins_autorizacion(r_gauto);
      end if;
      v_cod_transaccion := null;
      
      if nvl(v_sal_int_ade,0) <> 0 then --Interes Adelantado
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('IA', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := ren.nro_cuenta;
         r_gauto.cod_tra_padre       := 359;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := ren.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := ren.cod_modalidad;
         r_gauto.valor               := nvl(v_sal_int_ade,0) - ren.dev_no_cobrado;
         r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
         r_gauto.observacion         := 'Venta de Cartera';
         --- insertar ge_autorizaciones
         pp_ins_autorizacion(r_gauto);
      end if;*/
      v_cod_transaccion := NULL;
    
      IF nvl(v_mora, 0) <> 0 THEN
        --Mora sobre capital
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MO', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_mora, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_mora_interes, 0) <> 0 THEN
        --Mora sobre interes
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MI', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_mora_interes, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_mora_int_ade, 0) <> 0 THEN
        --Mora sobre interes adelantado
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MA', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_mora_int_ade, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_punitorio, 0) <> 0 THEN
        --Punitorio
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('PU', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_punitorio, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_impuesto, 0) <> 0 THEN
        --Impuestos
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('IM', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_impuesto, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_cargo, 0) <> 0 THEN
        --Cargos
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('CG', ren.estado, ren.tipo, ren.tip_interes, ren.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_cargo, 0) -
                                       nvl(v_car_seguro, 0)/* -
                                       nvl(v_cargo_iva, 0)*/;
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
      ---
      --- Recuperar datos de la deuda post-autorizaciones
      pap_pre.pr_ini_autorizacion;
      pap_pre.PR_INI_VAR_COBRO;
      pap_pre.pr_obt_deu_prestamo(ren.nro_cuenta, v_fecha, 0, 999, ren.cod_oficina, NULL, v_error, v_mensaje, v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes, v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado, v_dias_mora, 359, 'T', 'S');
      IF v_error <> 0 THEN
        raise_application_error(-20001, v_mensaje);
      END IF;
      IF r_psoli.tip_renovacion = 'D' THEN
        -- desembolso en etapas
        pap_pre.pr_obt_car_seg_cuotas(ren.nro_cuenta, v_car_seguro);
      END IF;
      v_tot_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_int_ade, 0) +
                     nvl(v_sal_interes, 0) + nvl(v_mora, 0) +
                     nvl(v_mora_interes, 0) + nvl(v_mora_int_ade, 0) +
                     nvl(v_punitorio, 0) + nvl(v_impuesto, 0) +
                     nvl(v_cargo, 0);
      --(nvl(v_cargo,0)-nvl(v_car_seguro,0));
      pap_pre.pr_ini_var_cobro;
      --- Realizar cobro
      pap_pre.pr_ini_autorizacion;
      pap_pre.pr_can_prestamo(ren.nro_cuenta, v_tot_deuda, 'N', --- Se pidio autorizacion
                              ren.cod_oficina, --- oficina origen
                              'T', v_fecha, v_hora, v_nro_secuencia, r_pcpre.cod_modalidad, 'S', r_psoli.tip_renovacion);
      pap_pre.pr_ini_var_cobro;
      ---
      -- Modificado 21/06/2013-DI-MB: Req. Venta de Cartera (Préstamos).
      -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
      -- Se genera el movimiento por el devengado en suspenso.
      IF nvl(ren.dev_suspenso, 0) <> 0 THEN
        v_nro_secuencia         := v_nro_secuencia + 1;
        v_cod_usuario           := upper(USER);
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.cod_modulo      := r_psoli.cod_modulo;
        r_gmovi.cod_modalidad   := ren.cod_modalidad;
        r_gmovi.cod_oficina     := ren.cod_oficina;
        r_gmovi.nro_cuenta      := ren.nro_cuenta;
        r_gmovi.cod_moneda      := r_psoli.cod_moneda;
        r_gmovi.est_cuenta      := ren.estado;
        r_gmovi.cod_persona     := NULL;
        r_gmovi.cod_tra_padre   := 359;
        r_gmovi.cod_transaccion := 948;
        r_gmovi.concepto        := 'DEV. SUSPENSO VENTA CARTERA';
        r_gmovi.monto           := nvl(ren.dev_suspenso, 0);
        r_gmovi.fec_valor       := v_fecha;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := ren.cod_oficina;
        r_gmovi.cod_mod_padre   := r_psoli.cod_modulo;
        r_gmovi.cod_mad_padre   := ren.cod_modalidad;
        r_gmovi.nro_documento   := NULL;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(trunc(nvl(ren.dev_suspenso, 0), 2) *
                                         v_cotizacion, v_redondeo_ml);
        IF r_gmovi.monto <> 0 THEN
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
        END IF;
      END IF;
    
      -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
      -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
      -- Aplicación de la Previsión.
      pap_mes.v_fcdehoy := v_fecha;
      v_mto_prevision   := pap_mes.FU_OBT_PREVISION(ren.nro_cuenta);
      IF nvl(v_mto_prevision, 0) > 0 THEN
        -- Genero movimiento de aplicación de la previsión.
        v_nro_secuencia         := v_nro_secuencia + 1;
        v_cod_usuario           := upper(USER);
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.cod_modulo      := r_pcpre_vta.cod_modulo;
        r_gmovi.cod_modalidad   := r_pcpre_vta.cod_modalidad;
        r_gmovi.cod_oficina     := ren.cod_oficina;
        r_gmovi.nro_cuenta      := ren.nro_cuenta;
        r_gmovi.cod_moneda      := r_psoli.cod_moneda;
        r_gmovi.est_cuenta      := ren.estado;
        r_gmovi.cod_persona     := NULL;
        r_gmovi.cod_tra_padre   := 359;
        r_gmovi.cod_transaccion := 957;
        r_gmovi.concepto        := 'PREVISION VENTA CARTERA';
        r_gmovi.monto           := nvl(v_mto_prevision, 0);
        r_gmovi.fec_valor       := v_fecha;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := ren.cod_oficina;
        r_gmovi.cod_mod_padre   := r_pcpre_vta.cod_modulo;
        r_gmovi.cod_mad_padre   := r_pcpre_vta.cod_modalidad;
        r_gmovi.referencia      := '8843';
        r_gmovi.nro_documento   := NULL;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(trunc(nvl(v_mto_prevision, 0), 2) *
                                         v_cotizacion, v_redondeo_ml);
        IF r_gmovi.monto <> 0 THEN
          --
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
        
          -- Cero las previsiones
          INSERT INTO pr_previsiones
            (fecha,
             nro_cuenta,
             monto,
             sal_capital,
             dev_no_cobrado,
             porcentaje,
             tot_gar_computables,
             tot_pri_prevision)
          VALUES
            (v_fecha, ren.nro_cuenta, 0, 0, 0, 0, 0, 0);
        END IF;
      END IF;
    
      -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
      -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
      -- Genero movimiento de cancelacion por venta de cartera.
      
      --Para Baja de Venta de Cartera
      --si la venta tiene relacionado el IVA 
      v_mto_dif:=0;
      begin
        select sum(w.monto)
          into v_mto_dif
         from ge_movimientos w
           where w.nro_Cuenta = ren.nro_cuenta
             and w.fecha = v_fecha
             and w.hora = v_hora
             and w.cod_usuario = v_cod_usuario
             and w.cod_tra_padre = 359
             and w.cod_transaccion in (2517,1708);
      exception
        when others then
            v_mto_dif:=0;
      end;
      
      v_tot_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_int_ade, 0) +
                     nvl(v_sal_interes, 0) /*+ nvl(v_cargo, 0)*/ -
                     nvl(ren.dev_suspenso, 0) - nvl(v_mto_dif, 0);
    
      v_nro_secuencia         := v_nro_secuencia + 1;
      v_cod_usuario           := USER;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.cod_modulo      := r_psoli.cod_modulo;
      r_gmovi.cod_modalidad   := ren.cod_modalidad;
      r_gmovi.cod_oficina     := ren.cod_oficina;
      r_gmovi.nro_cuenta      := ren.nro_cuenta;
      r_gmovi.cod_moneda      := r_psoli.cod_moneda;
      r_gmovi.est_cuenta      := NULL;
      r_gmovi.cod_persona     := NULL;
      r_gmovi.cod_tra_padre   := 359;
      r_gmovi.cod_transaccion := 8843;
      r_gmovi.concepto        := 'Cancelación Anticipada por Vta. de Cartera';
      r_gmovi.monto           := nvl(v_tot_deuda, 0) -
                                 nvl(v_mto_prevision, 0);
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := ren.cod_oficina;
      r_gmovi.cod_mod_padre   := r_psoli.cod_modulo;
      r_gmovi.cod_mad_padre   := ren.cod_modalidad;
      r_gmovi.referencia      := '8843';
      r_gmovi.nro_documento   := NULL;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(trunc(nvl(v_tot_deuda, 0) -
                                             nvl(v_mto_prevision, 0), 2) *
                                       v_cotizacion, v_redondeo_ml);
      IF r_gmovi.monto <> 0 THEN
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
    
      -- Modificado 14/07/2016- CNFICRC-275
      -- Genero movimiento cta de orden alta por venta de cartera.
    
      v_tot_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_int_ade, 0) +
                     nvl(v_sal_interes, 0) - nvl(ren.dev_suspenso, 0);
    
      v_nro_secuencia         := v_nro_secuencia + 1;
      v_cod_usuario           := USER;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.cod_modulo      := r_pcpre_vta.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcpre_vta.cod_modalidad;
      r_gmovi.cod_oficina     := ren.cod_oficina;
      r_gmovi.nro_cuenta      := ren.nro_cuenta;
      r_gmovi.cod_moneda      := r_psoli.cod_moneda;
      r_gmovi.est_cuenta      := NULL;
      r_gmovi.cod_persona     := NULL;
      r_gmovi.cod_tra_padre   := 359;
      r_gmovi.cod_transaccion := 8846;
      r_gmovi.concepto        := 'Alta por Vta. de Cartera. Cta. Orden';
      r_gmovi.monto           := nvl(v_tot_deuda, 0);
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := ren.cod_oficina;
      r_gmovi.cod_mod_padre   := r_pcpre_vta.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcpre_vta.cod_modalidad;
      r_gmovi.referencia      := '8846';
      r_gmovi.nro_documento   := NULL;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(trunc(nvl(v_tot_deuda, 0), 2) *
                                       v_cotizacion, v_redondeo_ml);
      IF r_gmovi.monto <> 0 THEN
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
    
      v_nro_secuencia := 0;
      --pag_gen.FU_OBT_SIG_SEGUNDO(v_hora); --CROPVNDC -HO
      r_gmovi.referencia := NULL;
      --CROPVNDC -HO -Se guarda en el historial de venta de cartera la hora de cancelacion y se cambia de Estado a V-endido
      UPDATE ge_sal_inv_vta_cartera_tmp
      SET hor_cancelacion = v_hora, estado = 'V'
      WHERE nro_cuenta = ren.nro_cuenta
      AND ref_lote = P_REF_LOTE
      AND cod_modulo = 6
      AND estado = 'N';
    
    END LOOP;
    -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
    -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
    -- Se elimina los datos importados del modulo de prestamos, tipo de deuda:P.
    DELETE pr_vta_cartera pv
    WHERE UPPER(pv.tipo_deuda) = 'P';
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
      -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
      -- Se elimina los datos importados.
      sql_util.ejecute_dml('TRUNCATE TABLE PR_VTA_CARTERA', v_msj);
      IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
      END IF;
      -- Se despliega el mensaje de error.
      raise_application_error(-20000, 'Error al ejecutar procedimiento: ' ||
                               v_cuenta || ' ' || SQLERRM);
  END;

  -- Realiza la venta de cartera de Operaciones Vencidas.
  PROCEDURE PR_VTA_CAR_OPE_VENCIDAS(P_REF_LOTE IN NUMBER) IS
  
    -- Recuperar datos de la cuenta a cancelar
    -->30/07/2013-DI-MB: Req. Venta de Cartera (Operaciones Vencidas)
    CURSOR c_cancelar IS
      SELECT ov.nro_cuenta,
             ov.cod_oficina,
             nvl(ov.mto_origen, 0) mto_origen,
             ov.cod_moneda,
             nvl(ov.sal_total, 0) sal_total,
             ov.estado,
             ov.cod_modulo,
             ov.cod_modalidad
      FROM ov_cta_vencidas ov, pr_vta_cartera prv
      WHERE ov.nro_cuenta = prv.nro_cuenta
      AND ov.estado <> 'C';
  
    -- Variables de tipo registro.
    r_gmovi ge_movimientos%ROWTYPE;
    r_pcpre ov_cta_vencidas%ROWTYPE;
    r_gauto ge_autorizaciones%ROWTYPE;
  
    v_fecha           ge_calendarios.fec_actual%TYPE;
    v_hora            ge_movimientos.hora%TYPE;
    v_cod_usuario     ge_movimientos.cod_usuario%TYPE;
    v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
    v_cod_modulo      ba_modulos.cod_modulo%TYPE;
    v_sal_capital     pr_cuotas.sal_capital%TYPE;
    v_mora            pr_cuotas.sal_interes%TYPE;
    v_impuesto        pr_cuotas.sal_interes%TYPE;
    v_cargo           pr_cuotas.sal_interes%TYPE;
    v_cargo_iva       pr_cuotas.sal_interes%TYPE;
    v_punitorio       pr_cuotas.sal_interes%TYPE;
    v_tot_deuda       pr_cta_prestamos.monto%TYPE;
    v_cotizacion      ge_cotizaciones.val_conversion%TYPE := NULL;
    v_cuenta          pr_cta_prestamos.nro_cuenta%TYPE;
    v_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
    v_mto_prevision   ge_movimientos.monto%TYPE;
    v_nro_operacion   ge_movimientos.nro_documento%TYPE;
    v_dia_mora        ov_cta_vencidas.dia_atraso%TYPE;
    v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_redondeo_ml     NUMBER(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, NULL, pag_gen.fu_obt_mon_local);
    v_error           VARCHAR2(10);
    v_mensaje         VARCHAR2(1000);
    v_msj             VARCHAR2(250);
  
    -- Procedimientos Internos.
    PROCEDURE pp_ins_autorizacion(p_gauto ge_autorizaciones%ROWTYPE) IS
    BEGIN
      INSERT INTO ge_autorizaciones
        (cod_autorizacion,
         nro_cuenta,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_transaccion,
         cod_modulo,
         cod_modalidad,
         valor,
         fec_vencimiento,
         cod_usu_autorizador,
         observacion)
      VALUES
        (s_cod_autorizacion.nextval,
         p_gauto.nro_cuenta,
         p_gauto.cod_tra_padre,
         p_gauto.cod_mod_padre,
         p_gauto.cod_mad_padre,
         p_gauto.cod_transaccion,
         p_gauto.cod_modulo,
         p_gauto.cod_modalidad,
         p_gauto.valor,
         p_gauto.fec_vencimiento,
         p_gauto.cod_usu_autorizador,
         p_gauto.observacion);
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20005, 'Error al insertar autorizacion: ' ||
                                 SQLERRM);
    END;
  
  BEGIN
    -- Variables.
    v_cod_modulo := 15;
    v_fecha      := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
    --v_hora           := to_char(sysdate,'HH24:MI:SS'); --CROPVNDC -HO
  
    -- Cursor.
    FOR ren IN c_cancelar
    LOOP
      v_cuenta := ren.nro_cuenta;
      v_hora   := fug_obt_hor_disponible(v_fecha, to_char(SYSDATE, 'HH24:MI:SS'), USER, 'N');
    
      -->30/07/2013-DI-MB: Req. Venta de Cartera (Operaciones Vencidas). Obtengo la cotizacion del día.
      IF ren.cod_moneda = v_cod_mon_local THEN
        v_cotizacion := NULL;
      ELSE
        v_cotizacion := pag_gen.fu_obt_cotizacion(ren.cod_moneda);
      END IF;
    
      --- Recuperar datos de la deuda
      pav_ove.pr_obt_dat_ope_vencida(ren.nro_cuenta, r_pcpre);
      pav_ove.pr_ini_autorizacion;
      pav_ove.pr_obt_deu_ope_vencida(ren.nro_cuenta, v_fecha, NULL, v_error, v_mensaje, v_sal_capital, v_mora, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_dia_mora);
      IF v_error <> 0 THEN
        raise_application_error(-20001, v_mensaje);
      END IF;
    
      --- Generar autorizaciones por conceptos a no cobrarse
      -->30/07/2013-DI-MB: Req. Venta de Cartera (Operaciones Vencidas).
      v_cod_transaccion := NULL;
    
      IF nvl(v_mora, 0) <> 0 THEN
        --Mora sobre capital
        v_cod_transaccion := pav_ove.fu_obt_tra_concepto('MO', ren.estado);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 139;
        r_gauto.cod_mod_padre       := 15;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 15;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_mora, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(15);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_punitorio, 0) <> 0 THEN
        --Punitorio
        v_cod_transaccion := pav_ove.fu_obt_tra_concepto('PU', ren.estado);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 139;
        r_gauto.cod_mod_padre       := 15;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 15;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_punitorio, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(15);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_impuesto, 0) <> 0 THEN
        --Impuestos
        v_cod_transaccion := pav_ove.fu_obt_tra_concepto('IM', ren.estado);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 139;
        r_gauto.cod_mod_padre       := 15;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 15;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_impuesto, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(15);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_cargo, 0) <> 0 THEN
        --Cargos
        v_cod_transaccion := pav_ove.fu_obt_tra_concepto('CG', ren.estado);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := ren.nro_cuenta;
        r_gauto.cod_tra_padre       := 139;
        r_gauto.cod_mod_padre       := 15;
        r_gauto.cod_mad_padre       := ren.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 15;
        r_gauto.cod_modalidad       := ren.cod_modalidad;
        r_gauto.valor               := nvl(v_cargo, 0) -
                                       nvl(v_cargo_iva, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(15);
        r_gauto.observacion         := 'Venta de Cartera';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
      ---
      --- Recuperar datos de la deuda post-autorizaciones
      -->30/07/2013-DI-MB: Req. Venta de Cartera (Operaciones Vencidas).
      pav_ove.pr_ini_autorizacion;
      pav_ove.pr_obt_deu_ope_vencida(ren.nro_cuenta, v_fecha, NULL, v_error, v_mensaje, v_sal_capital, v_mora, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_dia_mora);
      IF v_error <> 0 THEN
        raise_application_error(-20001, v_mensaje);
      END IF;
    
      v_tot_deuda := nvl(v_sal_capital, 0) + nvl(v_mora, 0) +
                     nvl(v_punitorio, 0) + nvl(v_impuesto, 0) +
                     nvl(v_cargo, 0);
    
      --- Realizar cobro
      -->30/07/2013-DI-MB: Req. Venta de Cartera (Operaciones Vencidas).
      pav_ove.pr_ini_autorizacion;
      v_nro_secuencia := 0;
      --Asignar el número de operación.
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', ren.cod_modulo, ren.cod_modalidad, ren.cod_moneda, ren.cod_oficina) + 1;
      prg_act_par_dinamico('NRO_RECIBO', ren.cod_modulo, ren.cod_modalidad, ren.cod_moneda, ren.cod_oficina, v_nro_operacion);
      -- Genera los movimientos x el detalle de cobro y actualiza los saldos de la operación vencida.
      pav_ove.pr_cob_ope_vencida(ren.nro_cuenta, v_tot_deuda, ren.cod_oficina, 'Cobro - Venta de Cartera', v_fecha, v_hora, v_nro_secuencia, 139, ren.cod_modulo, ren.cod_modalidad, v_nro_operacion);
    
      -- Aplicación de la Previsión.
      -->30/07/2013-DI-MB: Req. Venta de Cartera (Operaciones Vencidas).
      pav_mes.v_fcdehoy := v_fecha;
      v_mto_prevision   := pav_mes.FU_OBT_PREVISION(ren.nro_cuenta);
      IF nvl(v_mto_prevision, 0) > 0 THEN
        -- Genero movimiento de aplicación de la previsión.
        v_nro_secuencia         := v_nro_secuencia + 1;
        v_cod_usuario           := upper(USER);
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.cod_usuario     := v_cod_usuario;
        r_gmovi.hora            := v_hora;
        r_gmovi.fecha           := v_fecha;
        r_gmovi.cod_modulo      := ren.cod_modulo;
        r_gmovi.cod_modalidad   := ren.cod_modalidad;
        r_gmovi.cod_oficina     := ren.cod_oficina;
        r_gmovi.nro_cuenta      := ren.nro_cuenta;
        r_gmovi.cod_moneda      := ren.cod_moneda;
        r_gmovi.est_cuenta      := ren.estado;
        r_gmovi.cod_persona     := NULL;
        r_gmovi.cod_tra_padre   := 139;
        r_gmovi.cod_transaccion := 957;
        r_gmovi.concepto        := 'PREVISION VENTA CARTERA';
        r_gmovi.monto           := nvl(v_mto_prevision, 0);
        r_gmovi.fec_valor       := v_fecha;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.reversado       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := ren.cod_oficina;
        r_gmovi.cod_mod_padre   := ren.cod_modulo;
        r_gmovi.cod_mad_padre   := ren.cod_modalidad;
        r_gmovi.referencia      := '8843';
        r_gmovi.nro_documento   := NULL;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := round(trunc(nvl(v_mto_prevision, 0), 2) *
                                         v_cotizacion, v_redondeo_ml);
        IF r_gmovi.monto <> 0 THEN
          --
          pag_gen.pr_ins_ge_movimiento(r_gmovi);
        
          -- Cero las previsiones
          INSERT INTO ov_previsiones
            (fecha,
             nro_cuenta,
             monto,
             saldo,
             porcentaje,
             tot_gar_computables,
             tot_pri_prevision)
          VALUES
            (v_fecha, ren.nro_cuenta, 0, 0, 0, 0, 0);
        END IF;
      END IF;
    
      -- Genero movimiento de cancelacion por venta de cartera.
      -->30/07/2013-DI-MB: Req. Venta de Cartera (Operaciones Vencidas).
      v_tot_deuda := nvl(v_sal_capital, 0) + nvl(v_cargo, 0) -
                     nvl(v_mto_prevision, 0);
    
      v_nro_secuencia         := v_nro_secuencia + 1;
      v_cod_usuario           := USER;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.cod_modulo      := ren.cod_modulo;
      r_gmovi.cod_modalidad   := ren.cod_modalidad;
      r_gmovi.cod_oficina     := ren.cod_oficina;
      r_gmovi.nro_cuenta      := ren.nro_cuenta;
      r_gmovi.cod_moneda      := ren.cod_moneda;
      r_gmovi.est_cuenta      := NULL;
      r_gmovi.cod_persona     := NULL;
      r_gmovi.cod_tra_padre   := 139;
      r_gmovi.cod_transaccion := 8843;
      r_gmovi.concepto        := 'Cancelación Anticipada por Vta. de Cartera';
      r_gmovi.monto           := nvl(v_tot_deuda, 0);
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := ren.cod_oficina;
      r_gmovi.cod_mod_padre   := ren.cod_modulo;
      r_gmovi.cod_mad_padre   := ren.cod_modalidad;
      r_gmovi.referencia      := '8843';
      r_gmovi.nro_documento   := NULL;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(trunc(nvl(v_tot_deuda, 0), 2) *
                                       v_cotizacion, v_redondeo_ml);
      IF r_gmovi.monto <> 0 THEN
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
    
      -- Modificado 14/07/2016- CNFICRC-275
      -- Genero movimiento cta de orden alta por venta de cartera.
      v_tot_deuda := nvl(v_sal_capital, 0);
    
      v_nro_secuencia         := v_nro_secuencia + 1;
      v_cod_usuario           := USER;
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.cod_modulo      := ren.cod_modulo;
      r_gmovi.cod_modalidad   := ren.cod_modalidad;
      r_gmovi.cod_oficina     := ren.cod_oficina;
      r_gmovi.nro_cuenta      := ren.nro_cuenta;
      r_gmovi.cod_moneda      := ren.cod_moneda;
      r_gmovi.est_cuenta      := NULL;
      r_gmovi.cod_persona     := NULL;
      r_gmovi.cod_tra_padre   := 139;
      r_gmovi.cod_transaccion := 8846;
      r_gmovi.concepto        := 'Alta por Vta. de Cartera. Cta. Orden';
      r_gmovi.monto           := nvl(v_tot_deuda, 0);
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := ren.cod_oficina;
      r_gmovi.cod_mod_padre   := ren.cod_modulo;
      r_gmovi.cod_mad_padre   := ren.cod_modalidad;
      r_gmovi.referencia      := '8846';
      r_gmovi.nro_documento   := NULL;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(trunc(nvl(v_tot_deuda, 0), 2) *
                                       v_cotizacion, v_redondeo_ml);
      IF r_gmovi.monto <> 0 THEN
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
    
      v_nro_secuencia := 0;
      --pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);--CROPVNDC -HO
      r_gmovi.referencia := NULL;
      --CROPVNDC -HO -Se guarda en el historial de venta de cartera la hora de cancelacion y se cambia de Estado a V-endido
      UPDATE ge_sal_inv_vta_cartera_tmp
      SET hor_cancelacion = v_hora, estado = 'V'
      WHERE nro_cuenta = ren.nro_cuenta
      AND ref_lote = P_REF_LOTE
      AND cod_modulo = 15
      AND estado = 'N';
    END LOOP;
    -- Se elimina los datos importados del modulo de prestamos, tipo de deuda:P.
    DELETE pr_vta_cartera pv
    WHERE UPPER(pv.tipo_deuda) = 'V';
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      -- Se elimina los datos importados.
      sql_util.ejecute_dml('TRUNCATE TABLE PR_VTA_CARTERA', v_msj);
      IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
      END IF;
      -- Se despliega el mensaje de error.
      raise_application_error(-20000, 'Error al ejecutar procedimiento: ' ||
                               v_cuenta || ' ' || SQLERRM);
  END;

  PROCEDURE PR_VTA_CAR_PREAPROBADOS(P_NRO_CUENTA IN VARCHAR2,
                                    P_HORA       IN OUT VARCHAR2,
                                    P_NRO_SEQ    IN OUT VARCHAR2,
                                    P_EXONERA    IN VARCHAR2) IS
  
    -- Variables de tipo registro.
    r_gmovi ge_movimientos%ROWTYPE;
    r_psoli pr_solicitudes%ROWTYPE;
    r_pcpre pr_cta_prestamos%ROWTYPE;
    r_gauto ge_autorizaciones%ROWTYPE;
  
    v_fecha           ge_calendarios.fec_actual%TYPE;
    v_hora            ge_movimientos.hora%TYPE;
    v_cod_usuario     ge_movimientos.cod_usuario%TYPE;
    v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
    v_cod_modulo      ba_modulos.cod_modulo%TYPE;
    v_sal_capital     pr_cuotas.sal_capital%TYPE;
    v_sal_interes     pr_cuotas.sal_interes%TYPE;
    v_sal_int_ade     pr_cuotas.sal_int_documentado%TYPE;
    v_mora            pr_cuotas.sal_interes%TYPE;
    v_mora_interes    pr_cuotas.sal_interes%TYPE;
    v_mora_int_ade    pr_cuotas.sal_interes%TYPE;
    v_impuesto        pr_cuotas.sal_interes%TYPE;
    v_cargo           pr_cuotas.sal_interes%TYPE;
    v_cargo_iva       pr_cuotas.sal_interes%TYPE;
    v_punitorio       pr_cuotas.sal_interes%TYPE;
    v_int_descontado  pr_cuotas.sal_interes%TYPE;
    v_tot_deuda       pr_cta_prestamos.monto%TYPE;
    v_cotizacion      ge_cotizaciones.val_conversion%TYPE := NULL;
    v_cuenta          pr_cta_prestamos.nro_cuenta%TYPE;
    v_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
    v_mto_prevision   ge_movimientos.monto%TYPE;
    v_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
    v_redondeo_ml     NUMBER(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', 6, NULL, pag_gen.fu_obt_mon_local);
    v_dias_mora       NUMBER(05);
    v_car_seguro      NUMBER;
    v_error           VARCHAR2(10);
    v_mensaje         VARCHAR2(1000);
    v_msj             VARCHAR2(250);
    v_cod_oficina     ba_oficinas.cod_oficina%TYPE;
  
    -- Procedimientos Internos.
    PROCEDURE pp_ins_autorizacion(p_gauto ge_autorizaciones%ROWTYPE) IS
    BEGIN
    
      INSERT INTO ge_autorizaciones
        (cod_autorizacion,
         nro_cuenta,
         cod_tra_padre,
         cod_mod_padre,
         cod_mad_padre,
         cod_transaccion,
         cod_modulo,
         cod_modalidad,
         valor,
         fec_vencimiento,
         cod_usu_autorizador,
         observacion)
      VALUES
        (p_gauto.cod_autorizacion,
         p_gauto.nro_cuenta,
         p_gauto.cod_tra_padre,
         p_gauto.cod_mod_padre,
         p_gauto.cod_mad_padre,
         p_gauto.cod_transaccion,
         p_gauto.cod_modulo,
         p_gauto.cod_modalidad,
         p_gauto.valor,
         p_gauto.fec_vencimiento,
         p_gauto.cod_usu_autorizador,
         p_gauto.observacion);
    
      -- insertamos las exoneraciones
      PR_INS_EXO_CARGOS(p_gauto);
      --
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20005, 'Error al insertar autorizacion: ' ||
                                 SQLERRM);
    END;
  
    PROCEDURE pp_cob_car_adicionales(p_cuenta pr_cta_prestamos.nro_cuenta%TYPE) IS
    BEGIN
      UPDATE pr_cta_gastos gas
      SET gas.fec_ult_pago = trunc(SYSDATE),
          gas.hor_ult_pago = to_char(SYSDATE, 'hh24:mi:ss')
      WHERE gas.nro_cuenta = p_cuenta
      AND gas.cod_transaccion NOT IN (1520, 1521) /*Seguro cuotizados.*/
      AND gas.fec_ult_pago IS NULL;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20006, 'Error al eliminar cargos adicionales: ' ||
                                 p_cuenta || ' ' || SQLERRM);
    END;
  
  BEGIN
    -- Variables.
    v_cod_modulo  := 6;
    v_fecha       := pag_cal.FU_OBT_FEC_ACTUAL(v_cod_modulo);
    v_cod_oficina := fug_obt_ofi_usuario(USER);
    --v_hora           := to_char(sysdate,'HH24:MI:SS'); --CROPVNDC -HO
  
    -- datos del prestamo
    pap_pre.PR_OBT_DAT_PRESTAMO(P_NRO_CUENTA, r_pcpre);
    --
    v_cuenta        := r_pcpre.nro_cuenta;
    v_hora          := p_hora;
    v_nro_secuencia := P_NRO_SEQ + 1;
  
    -->21/06/2013-DI-MB: Req. Venta de Cartera (Préstamos). Obtengo la cotizacion del día.
    IF r_pcpre.cod_moneda = v_cod_mon_local THEN
      v_cotizacion := NULL;
    ELSE
      v_cotizacion := pag_gen.fu_obt_cotizacion(r_pcpre.cod_moneda);
    END IF;
  
    --- Recuperar datos de la solicitud
    BEGIN
      SELECT *
      INTO r_psoli
      FROM pr_solicitudes psol
      WHERE psol.nro_solicitud = r_pcpre.nro_solicitud;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20002, 'Error al cargar datos de solicitud:' ||
                                 r_pcpre.nro_solicitud);
    END;
  
    --PAG_VTA.PR_ELI_EXO_CARGOS(r_pcpre.nro_cuenta); -- se comenta porque ya hace en prp_can_preaprobados
  
    --- Recuperar datos de la deuda
    pap_pre.pr_ini_autorizacion;
    pap_pre.PR_INI_VAR_COBRO;
    pap_pre.pr_obt_deu_prestamo(r_pcpre.nro_cuenta, v_fecha, 0, 999, r_pcpre.cod_oficina, NULL, v_error, v_mensaje, v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes, v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado, v_dias_mora, 359, 'T', 'S');
    IF v_error <> 0 THEN
      raise_application_error(-20001, v_mensaje);
    END IF;
    IF r_psoli.tip_renovacion = 'D' THEN
      -- desembolso en etapas
      pap_pre.pr_obt_car_seg_cuotas(r_pcpre.nro_cuenta, v_car_seguro);
    END IF;
  
    v_cod_transaccion := NULL;
  
    -- si el parametro viene en Si va a insertar las exoneraciones por los moratorios, cargos, gastos adicionales
    IF nvl(P_EXONERA, 'N') = 'S' THEN
      --Marcar como pagados cargos adicionales de las cuentas que se van a vender.
      --pp_cob_car_adicionales(v_cuenta);
      --
      IF nvl(v_mora, 0) <> 0 THEN
        --Mora sobre capital
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MO', r_pcpre.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := r_pcpre.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := r_pcpre.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := r_pcpre.cod_modalidad;
        r_gauto.valor               := nvl(v_mora, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Pase a Sobregiro';
      
        SELECT s_cod_autorizacion.nextval
        INTO r_gauto.cod_autorizacion
        FROM dual;
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_mora_interes, 0) <> 0 THEN
        --Mora sobre interes
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MI', r_pcpre.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := r_pcpre.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := r_pcpre.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := r_pcpre.cod_modalidad;
        r_gauto.valor               := nvl(v_mora_interes, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Pase a Sobregiro';
      
        SELECT s_cod_autorizacion.nextval
        INTO r_gauto.cod_autorizacion
        FROM dual;
      
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_mora_int_ade, 0) <> 0 THEN
        --Mora sobre interes adelantado
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('MA', r_pcpre.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := r_pcpre.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := r_pcpre.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := r_pcpre.cod_modalidad;
        r_gauto.valor               := nvl(v_mora_int_ade, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Pase a Sobregiro';
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      IF nvl(v_punitorio, 0) <> 0 THEN
        --Punitorio
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('PU', r_pcpre.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := r_pcpre.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := r_pcpre.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := r_pcpre.cod_modalidad;
        r_gauto.valor               := nvl(v_punitorio, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Pase a Sobregiro';
      
        SELECT s_cod_autorizacion.nextval
        INTO r_gauto.cod_autorizacion
        FROM dual;
      
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
      v_cod_transaccion := NULL;
    
      --- impuestos no se exonera
      /* if nvl(v_impuesto,0) <> 0 then --Impuestos
         v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('IM', r_pcpre.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
         -- Cargar registro de autorizaciones
         r_gauto.cod_usu_autorizador := user;
         r_gauto.nro_cuenta          := r_pcpre.nro_cuenta;
         r_gauto.cod_tra_padre       := 359;
         r_gauto.cod_mod_padre       := 6;
         r_gauto.cod_mad_padre       := r_pcpre.cod_modalidad;
         r_gauto.cod_transaccion     := v_cod_transaccion;
         r_gauto.cod_modulo          := 6;
         r_gauto.cod_modalidad       := r_pcpre.cod_modalidad;
         r_gauto.valor               := nvl(v_impuesto,0);
         r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
         r_gauto.observacion         := 'Pase a Sobregiro';
         --- insertar ge_autorizaciones
         pp_ins_autorizacion(r_gauto);
      end if;*/
      v_cod_transaccion := NULL;
    
      IF nvl(v_cargo, 0) <> 0 THEN
        --Cargos
        v_cod_transaccion := pap_pre.FU_OBT_TRA_CONCEPTO('CG', r_pcpre.estado, r_pcpre.tipo, r_pcpre.tip_interes, r_pcpre.tip_renovacion);
        -- Cargar registro de autorizaciones
        r_gauto.cod_usu_autorizador := USER;
        r_gauto.nro_cuenta          := r_pcpre.nro_cuenta;
        r_gauto.cod_tra_padre       := 359;
        r_gauto.cod_mod_padre       := 6;
        r_gauto.cod_mad_padre       := r_pcpre.cod_modalidad;
        r_gauto.cod_transaccion     := v_cod_transaccion;
        r_gauto.cod_modulo          := 6;
        r_gauto.cod_modalidad       := r_pcpre.cod_modalidad;
        r_gauto.valor               := nvl(v_cargo, 0) -
                                       nvl(v_car_seguro, 0) -
                                       nvl(v_cargo_iva, 0);
        r_gauto.fec_vencimiento     := pag_cal.fu_obt_fec_actual(6);
        r_gauto.observacion         := 'Pase a Sobregiro';
      
        SELECT s_cod_autorizacion.nextval
        INTO r_gauto.cod_autorizacion
        FROM dual;
      
        --- insertar ge_autorizaciones
        pp_ins_autorizacion(r_gauto);
      END IF;
    
      v_cod_transaccion := NULL;
      ---
      --- Recuperar datos de la deuda post-autorizaciones
      pap_pre.pr_ini_autorizacion;
      pap_pre.PR_INI_VAR_COBRO;
      pap_pre.pr_obt_deu_prestamo(r_pcpre.nro_cuenta, v_fecha, 0, 999, r_pcpre.cod_oficina, NULL, v_error, v_mensaje, v_sal_capital, v_sal_interes, v_sal_int_ade, v_mora, v_mora_interes, v_mora_int_ade, v_punitorio, v_impuesto, v_cargo, v_cargo_iva, v_int_descontado, v_dias_mora, 359, 'T', 'S');
      IF v_error <> 0 THEN
        raise_application_error(-20001, v_mensaje);
      END IF;
    END IF; -- fin exoneraciones  
  
    IF r_psoli.tip_renovacion = 'D' THEN
      -- desembolso en etapas
      pap_pre.pr_obt_car_seg_cuotas(r_pcpre.nro_cuenta, v_car_seguro);
    END IF;
    v_tot_deuda := nvl(v_sal_capital, 0) + nvl(v_sal_int_ade, 0) +
                   nvl(v_sal_interes, 0) + nvl(v_mora, 0) +
                   nvl(v_mora_interes, 0) + nvl(v_mora_int_ade, 0) +
                   nvl(v_punitorio, 0) + nvl(v_impuesto, 0) +
                   nvl(v_cargo, 0);
    --(nvl(v_cargo,0)-nvl(v_car_seguro,0));
    pap_pre.pr_ini_var_cobro;
    --- Realizar cobro
    pap_pre.pr_ini_autorizacion;
    pap_pre.pr_can_prestamo(r_pcpre.nro_cuenta, v_tot_deuda, 'N', --- Se pidio autorizacion
                            v_cod_oficina, --r_pcpre.cod_oficina, --- oficina origen = ofi del usuario q está generando el movimiento
                            'T', v_fecha, v_hora, v_nro_secuencia, r_pcpre.cod_modalidad, 'S', r_psoli.tip_renovacion);
    pap_pre.pr_ini_var_cobro;
    ---
    -- Modificado 21/06/2013-DI-MB: Req. Venta de Cartera (Préstamos).
    -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
    -- Se genera el movimiento por el devengado en suspenso.
    -- ya que la deuda que se envia cuando tiene exoneracion es Sal Cap + Dev No cobrado
    IF nvl(r_pcpre.dev_suspenso, 0) <> 0
       AND nvl(P_EXONERA, 'N') = 'S' THEN
      v_nro_secuencia         := v_nro_secuencia + 1;
      v_cod_usuario           := upper(USER);
      r_gmovi.nro_secuencia   := v_nro_secuencia;
      r_gmovi.cod_usuario     := v_cod_usuario;
      r_gmovi.hora            := v_hora;
      r_gmovi.fecha           := v_fecha;
      r_gmovi.cod_modulo      := r_pcpre.cod_modulo;
      r_gmovi.cod_modalidad   := r_pcpre.cod_modalidad;
      r_gmovi.cod_oficina     := r_pcpre.cod_oficina;
      r_gmovi.nro_cuenta      := r_pcpre.nro_cuenta;
      r_gmovi.cod_moneda      := r_pcpre.cod_moneda;
      r_gmovi.est_cuenta      := r_pcpre.estado;
      r_gmovi.cod_persona     := NULL;
      r_gmovi.cod_tra_padre   := 359;
      r_gmovi.cod_transaccion := 948;
      r_gmovi.concepto        := 'DEV. SUSPENSO PREAPROBADO - ' ||
                                 fug_obt_des_canal(r_pcpre.cod_canal);
      r_gmovi.monto           := nvl(r_pcpre.dev_suspenso, 0);
      r_gmovi.fec_valor       := v_fecha;
      r_gmovi.emi_aviso       := 'N';
      r_gmovi.reversado       := 'N';
      r_gmovi.protegido       := 'N';
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina; -- r_pcpre.cod_oficina;
      r_gmovi.cod_mod_padre   := r_pcpre.cod_modulo;
      r_gmovi.cod_mad_padre   := r_pcpre.cod_modalidad;
      r_gmovi.nro_documento   := NULL;
      r_gmovi.cotizacion      := v_cotizacion;
      r_gmovi.mto_equ_local   := round(trunc(nvl(r_pcpre.dev_suspenso, 0), 2) *
                                       v_cotizacion, v_redondeo_ml);
      IF r_gmovi.monto <> 0 THEN
        pag_gen.pr_ins_ge_movimiento(r_gmovi);
      END IF;
    END IF;
  
    -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
    -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
    -- Aplicación de la Previsión.
    /*     pap_mes.v_fcdehoy := v_fecha;
          v_mto_prevision := pap_mes.FU_OBT_PREVISION(r_pcpre.nro_cuenta);
          IF nvl(v_mto_prevision,0) > 0 then
             -- Genero movimiento de aplicación de la previsión.
             v_nro_secuencia            := v_nro_secuencia + 1;
             v_cod_usuario              := upper(user);
             r_gmovi.nro_secuencia      := v_nro_secuencia;
             r_gmovi.cod_usuario        := v_cod_usuario;
             r_gmovi.hora               := v_hora;
             r_gmovi.fecha              := v_fecha;
             r_gmovi.cod_modulo         := r_psoli.cod_modulo;
             r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
             r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
             r_gmovi.nro_cuenta         := r_pcpre.nro_cuenta;
             r_gmovi.cod_moneda         := r_psoli.cod_moneda;
             r_gmovi.est_cuenta         := r_pcpre.estado;
             r_gmovi.cod_persona        := null;
             r_gmovi.cod_tra_padre      := 359;
             r_gmovi.cod_transaccion    := 957;
             r_gmovi.concepto           := 'PREVISION VENTA CARTERA';
             r_gmovi.monto              := nvl(v_mto_prevision,0);
             r_gmovi.fec_valor          := v_fecha;
             r_gmovi.emi_aviso          := 'N';
             r_gmovi.reversado          := 'N';
             r_gmovi.protegido          := 'N';
             r_gmovi.estado             := 'N';
             r_gmovi.cod_ofi_origen     := v_cod_oficina; -- r_pcpre.cod_oficina;
             r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
             r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
             r_gmovi.referencia         := '8843';
             r_gmovi.nro_documento      := null;
             r_gmovi.cotizacion         := v_cotizacion;
             r_gmovi.mto_equ_local      := round(trunc(nvl(v_mto_prevision,0),2)*v_cotizacion,v_redondeo_ml);
             IF r_gmovi.monto <> 0 THEN
                --
                pag_gen.pr_ins_ge_movimiento(r_gmovi);
    
                -- Cero las previsiones
                INSERT INTO pr_previsiones(fecha, nro_cuenta, monto, sal_capital, dev_no_cobrado, porcentaje, tot_gar_computables, tot_pri_prevision)
                     VALUES (v_fecha, r_pcpre.nro_cuenta, 0, 0, 0, 0, 0, 0);
             END IF;
          END IF;
    */
    -- Modificado 21/06/2013-DI-MB: Requerimiento: Venta de Cartera.
    -- Documento: REG-BBVA-0122-ETRA-DSIS-02-FATD.01-AJU_VTA_CARTERA.
    -- Genero movimiento de cancelacion por venta de cartera.
    /*   v_tot_deuda                := nvl(v_sal_capital,0) + nvl(v_sal_int_ade,0) + nvl(v_sal_interes,0) + nvl(v_cargo,0) - nvl(r_pcpre.dev_suspenso,0);
    
          v_nro_secuencia            := v_nro_secuencia + 1;
          v_cod_usuario              := user;
          r_gmovi.nro_secuencia      := v_nro_secuencia;
          r_gmovi.cod_usuario        := v_cod_usuario;
          r_gmovi.hora               := v_hora;
          r_gmovi.fecha              := v_fecha;
          r_gmovi.cod_modulo         := r_psoli.cod_modulo;
          r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
          r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
          r_gmovi.nro_cuenta         := r_pcpre.nro_cuenta;
          r_gmovi.cod_moneda         := r_psoli.cod_moneda;
          r_gmovi.est_cuenta         := null;
          r_gmovi.cod_persona        := null;
          r_gmovi.cod_tra_padre      := 359;
          r_gmovi.cod_transaccion    := 8843;
          r_gmovi.concepto           := 'Cancelación Anticipada por Pase a Sobregiro';
          r_gmovi.monto              := nvl(v_tot_deuda,0) - nvl(v_mto_prevision,0);
          r_gmovi.fec_valor          := v_fecha;
          r_gmovi.emi_aviso          := 'N';
          r_gmovi.reversado          := 'N';
          r_gmovi.protegido          := 'N';
          r_gmovi.estado             := 'N';
          r_gmovi.cod_ofi_origen     := r_pcpre.cod_oficina;
          r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
          r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
          r_gmovi.referencia         := '8843';
          r_gmovi.nro_documento      := null;
          r_gmovi.cotizacion         := v_cotizacion;
          r_gmovi.mto_equ_local      := round(trunc(nvl(v_tot_deuda,0)-nvl(v_mto_prevision,0),2)*v_cotizacion,v_redondeo_ml);
          IF r_gmovi.monto <> 0 THEN
             pag_gen.pr_ins_ge_movimiento(r_gmovi);
          END IF;
    
          -- Modificado 14/07/2016- CNFICRC-275
          -- Genero movimiento cta de orden alta por venta de cartera.
    
          v_tot_deuda                := nvl(v_sal_capital,0) + nvl(v_sal_int_ade,0) + nvl(v_sal_interes,0) - nvl(r_pcpre.dev_suspenso,0);
    
          v_nro_secuencia            := v_nro_secuencia + 1;
          v_cod_usuario              := user;
          r_gmovi.nro_secuencia      := v_nro_secuencia;
          r_gmovi.cod_usuario        := v_cod_usuario;
          r_gmovi.hora               := v_hora;
          r_gmovi.fecha              := v_fecha;
          r_gmovi.cod_modulo         := r_psoli.cod_modulo;
          r_gmovi.cod_modalidad      := r_psoli.cod_modalidad;
          r_gmovi.cod_oficina        := r_pcpre.cod_oficina;
          r_gmovi.nro_cuenta         := r_pcpre.nro_cuenta;
          r_gmovi.cod_moneda         := r_psoli.cod_moneda;
          r_gmovi.est_cuenta         := null;
          r_gmovi.cod_persona        := null;
          r_gmovi.cod_tra_padre      := 359;
          r_gmovi.cod_transaccion    := 8846;
          r_gmovi.concepto           := 'Alta por Vta. de Cartera. Cta. Orden';
          r_gmovi.monto              := nvl(v_tot_deuda,0);
          r_gmovi.fec_valor          := v_fecha;
          r_gmovi.emi_aviso          := 'N';
          r_gmovi.reversado          := 'N';
          r_gmovi.protegido          := 'N';
          r_gmovi.estado             := 'N';
          r_gmovi.cod_ofi_origen     := r_pcpre.cod_oficina;
          r_gmovi.cod_mod_padre      := r_psoli.cod_modulo;
          r_gmovi.cod_mad_padre      := r_psoli.cod_modalidad;
          r_gmovi.referencia         := '8846';
          r_gmovi.nro_documento      := null;
          r_gmovi.cotizacion         := v_cotizacion;
          r_gmovi.mto_equ_local      := round(trunc(nvl(v_tot_deuda,0),2)*v_cotizacion,v_redondeo_ml);
          IF r_gmovi.monto <> 0 THEN
             pag_gen.pr_ins_ge_movimiento(r_gmovi);
          END IF;
    */
    p_hora    := v_hora;
    p_nro_seq := v_nro_secuencia;
  
    r_gmovi.referencia := NULL;
  
  END;

  -- Procedimiento para eliminar descuentos o exoneraciones de mora/cargos, etc registradas para la cuenta.
  PROCEDURE PR_ELI_EXO_CARGOS(P_NRO_CUENTA IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    --elimina autorizaciones para obtener deuda original (sin descuentos)
    DELETE FROM ge_autorizaciones
    WHERE nro_cuenta = p_nro_cuenta
    AND cod_usu_utilizador IS NULL;
  
    DELETE FROM ge_autorizaciones
    WHERE nro_cuenta = p_nro_cuenta --:cuentas.nro_cuenta
    AND cod_autorizacion < 0;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      raise_application_error(-20002, 'Error al eliminar aut.previas de la cuenta: ' ||
                               p_nro_cuenta || '-' || SQLERRM);
  END;

  -- Procedimiento para insertar descuentos o exoneraciones de mora/cargos, etc registradas para la cuenta
  -- en el modulo de exoneraciones.
  PROCEDURE PR_INS_EXO_CARGOS(p_gauto IN ge_autorizaciones%ROWTYPE) IS
    v_cod_moneda ge_cuentas.cod_moneda%TYPE;
  BEGIN
    -- 
    SELECT cod_moneda
    INTO v_cod_moneda
    FROM pr_cta_prestamos
    WHERE nro_cuenta = p_gauto.nro_cuenta;
    --
    INSERT INTO ge_exoneraciones_tmp
      (nro_pedido,
       cod_transaccion,
       cod_modulo,
       cod_modalidad,
       cod_moneda,
       nro_cuenta,
       estado,
       mto_exoneracion,
       mto_a_cobrar)
    VALUES
      (p_gauto.cod_autorizacion,
       p_gauto.cod_transaccion,
       p_gauto.cod_modulo,
       p_gauto.cod_modalidad,
       v_cod_moneda,
       p_gauto.nro_cuenta,
       'P',
       p_gauto.valor,
       p_gauto.valor);
  END;
END PAG_VTA;
/
