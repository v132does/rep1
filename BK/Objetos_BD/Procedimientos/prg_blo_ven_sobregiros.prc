CREATE OR REPLACE PROCEDURE IT.PRG_BLO_VEN_SOBREGIROS is

  v_impuesto                  NUMBER default 0;
  v_interes                   NUMBER default 0;
  v_tot_debito                NUMBER default 0;
  v_fcdehoy                   DATE;
  v_nro_secuencia             ge_movimientos.nro_secuencia%TYPE := 0;
  v_hora                      ge_movimientos.hora%TYPE := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
  v_nvo_cuenta                ge_cuentas.nro_cuenta%TYPE;
  v_cod_persona               ba_personas.cod_persona%TYPE;
  v_dia_sob                   NUMBER(10);
  v_cod_can                   NUMBER(10);
  v_val_tasa                  ov_cta_vencidas.val_tasa%TYPE;
  r_gmovi                     ge_movimientos%ROWTYPE;
  v_cotizacion                ge_cotizaciones.val_conversion%TYPE;
  v_cod_actividad             cr_age_actividades.cod_actividad%TYPE;
  v_cod_mot_actividad         cr_age_mot_actividades.cod_mot_actividad%TYPE;
  v_nro_referencia            cr_agendas.nro_referencia%TYPE;
  v_est_cuenta                ge_movimientos.est_cuenta%TYPE;
  r_gbloq                     ge_bloqueos%ROWTYPE;
  p_nro_cuenta                GE_CUENTAS.NRO_CUENTA%TYPE;
  P_NRO_DOCUMENTO             GE_MOVIMIENTOS.NRO_DOCUMENTO%TYPE;
  P_CAU_CANCELACION           CC_CTA_CORRIENTES.COD_CAU_CANCELACION%TYPE;
  P_CONCEPTO                  GE_MOVIMIENTOS.CONCEPTO%TYPE;
  P_VER_ERROR                 VARCHAR2(500);
  P_NRO_LOTE                  NUMBER(18);
  v_cta_error                 cc_cta_corrientes.nro_cuenta%TYPE;

  CURSOR sobregiros IS
  SELECT cta.nro_cuenta,
       res.can_dias,
       res.sit_deuda,
       cta.cod_modulo,
       cta.cod_modalidad,
       cta.cod_oficina,
       cta.denominacion,
       cta.sal_total,
       cta.sal_bloqueado,
       cta.sal_retenido,
       cta.mto_cre_pendientes,
       cta.mto_deb_pendientes,
       cta.mto_cre_a_confirmar,
       cta.tas_personalizada,
       cta.aut_pendiente,
       cta.tra_prohibida,
       cta.cod_moneda,
       cta.cta_combinada,
       cta.reg_firma,
       cta.max_atraso,
       cta.pro_atraso,
       ge.dig_verificador,
       ge.cod_persona
  FROM cc_cta_corrientes cta
  INNER JOIN ge_cta_clientes ge
    ON ge.nro_cuenta = cta.nro_cuenta
     AND ge.relacion = 'P' 
  LEFT JOIN cc_sobregiros_res res
    ON res.nro_cuenta = cta.nro_cuenta
  WHERE ( cta.sal_total - cta.sal_retenido ) < 0
    AND cta.estado NOT IN ('C', 'T')
    AND EXISTS (
      SELECT 1
      FROM cc_pro_tmp_vencidos pro
      WHERE pro.nro_cuenta = cta.nro_cuenta
    );

  PROCEDURE lp_ins_ge_bloqueos(rp_gbloq IN ge_bloqueos%ROWTYPE) IS
    v_nro_documento ge_bloqueos.nro_documento%TYPE;
  BEGIN
    INSERT INTO ge_bloqueos
      (nro_cuenta, fec_inicio, nro_documento, cod_causa, monto, hor_inicio, fec_fin, tipo,
       observacion, tip_bloqueo)
    VALUES
      (rp_gbloq.nro_cuenta, rp_gbloq.fec_inicio, rp_gbloq.nro_documento, rp_gbloq.cod_causa,
       rp_gbloq.monto, rp_gbloq.hor_inicio, rp_gbloq.fec_fin, rp_gbloq.tipo, rp_gbloq.observacion,
       r_gbloq.tip_bloqueo);
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
      SELECT MAX(a.nro_documento) + 1
        INTO v_nro_documento
        FROM ge_bloqueos a
       WHERE a.nro_cuenta = rp_gbloq.nro_cuenta
         AND a.fec_inicio = rp_gbloq.fec_inicio;

      INSERT INTO ge_bloqueos
        (nro_cuenta, fec_inicio, nro_documento, cod_causa, monto, hor_inicio, fec_fin, tipo,
         observacion, tip_bloqueo)
      VALUES
        (rp_gbloq.nro_cuenta, rp_gbloq.fec_inicio, v_nro_documento, rp_gbloq.cod_causa,
         rp_gbloq.monto, rp_gbloq.hor_inicio, rp_gbloq.fec_fin, rp_gbloq.tipo, rp_gbloq.observacion,
         r_gbloq.tip_bloqueo);
  END;


BEGIN
  BEGIN
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := 4;
  END;

  -- Obtener el parametro de cantidad de dias1
  v_dia_sob := fug_obt_pardinamico('DIA_SOB_VEN');
  v_cod_can := fug_obt_pardinamico('COD_CAU_CAN_SOBREGIRO');
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  v_hora    := PAG_GEN.FU_OBT_SIG_SEGUNDO(v_hora);


  -- Obtener la(s) cuenta(s) que pasa(ran) a sobregiros vencidos
  v_nro_secuencia := 0;
  FOR cta IN sobregiros LOOP

     IF v_nro_secuencia + 10 > 999 THEN
               v_nro_secuencia := 0;
               v_hora          := fug_ini_hora(SYSDATE); --PDSB-531
               v_hora          := fug_obt_hor_disponible(v_fcdehoy,v_hora,user,'N');
               r_gmovi.hora    := v_hora;
      END IF;

    v_cta_error := cta.nro_cuenta;


    BEGIN
      pag_cta.PR_SET_EST_MOVIMIENTO('N');
      
      IF (p_nro_cuenta IS NULL AND
         NVL(cta.sal_bloqueado, 0) = 0 AND
         NVL(cta.sal_retenido, 0) = 0 AND
         NVL(cta.mto_cre_pendientes, 0) = 0 AND
         NVL(cta.mto_deb_pendientes, 0) = 0 AND
         NVL(cta.mto_cre_a_confirmar, 0) = 0 AND -- cuando es automatico
         cta.cta_combinada = 'N') OR p_nro_cuenta IS NOT NULL THEN -- cuando es manual


        IF cta.can_dias < 61 THEN
          v_est_cuenta := 'N'; -- DYDMR-4007 NAD 03/06/2016
          -- C.B. 20/08/2012 - BBVASOP-1150
        ELSIF cta.can_dias > 60 AND cta.can_dias < 91 THEN
          v_est_cuenta := 'V';
        ELSIF cta.can_dias > 90 AND cta.can_dias < 181 THEN
          v_est_cuenta := 'G';
        ELSIF cta.can_dias > 180 THEN
          v_est_cuenta := 'M';
        ELSE
          v_est_cuenta := 'N'; -- PCCRPDNE-153
        END IF;

        -- recuperar interes e impuesto para acreditar luego
        pac_sob.PR_PRO_LIQ_SOB(cta.nro_cuenta,
                               'N', -- (N) no va a procesar, sólo calcula
                               v_impuesto,
                               v_interes);
        v_tot_debito := ABS(cta.sal_total) + NVL(v_impuesto, 0) + NVL(v_interes, 0);

        pae_cnf.PR_SET_VARIABLES(v_hora, v_nro_secuencia);

        -- Realizar la liquidacion del sobregiro
        prc_liq_sobregiros(cta.nro_cuenta);

        -- Credito a la cuenta
        v_nro_secuencia := NVL(v_nro_secuencia, 0) + 1;

        pae_cnf.PR_SET_VARIABLES(v_hora, v_nro_secuencia);

        IF cta.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL THEN
          SELECT pag_gen.FU_OBT_COTIZACION(pag_gen.FU_OBT_MON_FUERTE)
            INTO v_cotizacion
            FROM DUAL;
        ELSE
          v_cotizacion := NULL;
        END IF;

        v_nro_secuencia := NVL(v_nro_secuencia, 0) + 1;

        pag_cta.pr_act_operacion(cta.nro_cuenta,
                                 v_hora,   -- HORA
                                 'C',
                                 cta.cod_moneda,
                                 v_tot_debito,
                                 602,      -- COD_TRA_PADRE
                                 602,
                                 NVL(p_nro_documento, cta.nro_cuenta),
                                 v_cotizacion, -- COTIZACION
                                 cta.cod_oficina, -- cod_ofi_origen
                                 4,        -- cod_mod_padre
                                 41,       -- cod_mad_padre
                                 NULL,     -- cod_tasa
                                 NULL,     -- val_tasa
                                 NVL(p_concepto, 'Traspaso a sobregiro vencido'),
                                 'N',      -- emi_aviso
                                 v_nro_secuencia,
                                 TRUNC(v_fcdehoy));

        IF pag_cta.fu_obt_cod_error() <> 0 THEN
          IF NVL(P_VER_ERROR, 'X') = 'S' THEN
            pag_nom.pr_ins_log(p_nro_cuenta,
                               pag_cta.fu_obt_cod_error(),
                               pag_cta.fu_obt_msj_error(),
                               NULL,
                               NULL,
                               NULL);
          ELSE
            RAISE_APPLICATION_ERROR(-20001, pag_cta.fu_obt_cod_error() || ' - ' || pag_cta.fu_obt_msj_error());
          END IF;
        END IF;

        -- Actualizar la causa de cancelación
        UPDATE cc_cta_corrientes
           SET cod_cau_cancelacion = v_cod_can
         WHERE nro_cuenta = cta.nro_cuenta;
        /*
        || DYDMR-21 - SPI 2509
        || La cuenta corriente ya no tiene sobregiros.
        || Los sobregiros en suspenso no deben considerarse en el procedimiento PRC_REV_SOB_SUSPENSO
        || xpy0038 - 06/mayo/2014
        */
        UPDATE cc_sob_suspenso
           SET fec_regularizacion = v_fcdehoy
         WHERE nro_cuenta = cta.nro_cuenta
           AND fec_regularizacion IS NULL;
        --- Fin modificaciones DYDMR-21

        v_nro_secuencia := NVL(v_nro_secuencia, 0) + 1;

        -- pae_cnf.PR_SET_VARIABLES(v_hora,v_nro_secuencia);
        pag_cta.PR_SET_VARIABLES(USER, v_fcdehoy, '358', 'N', 'N', v_nro_secuencia);
        -- Pasar al estado cancelado
        pag_cta.PR_ACT_ESTADO(cta.nro_cuenta, 'T', v_fcdehoy, v_hora, NVL(p_nro_documento, cta.nro_cuenta)); -- CAMBIO EV Para prueba de pase a vencida
        --- DYDMR-21: Cuenta puede tener débitos automáticos u otro
        IF pag_cta.fu_obt_cod_error() <> 0 THEN
          RAISE_APPLICATION_ERROR(-20001, pag_cta.fu_obt_cod_error() || ' - ' || pag_cta.fu_obt_msj_error());
        END IF;
        -- Obtener el nvo nro de cuenta
        v_nvo_cuenta := fug_obt_sig_nro_cuenta(15,
                                               153,
                                               cta.cod_oficina,
                                               cta.cod_moneda,
                                               v_cod_persona);
        -- Obtener el valor de la tasa
        v_val_tasa := fug_obt_val_tasa(cta.cod_modulo,
                                       cta.cod_modalidad,
                                       cta.cod_oficina,
                                       cta.nro_cuenta,
                                       cta.cod_moneda,
                                       0,    -- monto
                                       cta.tas_personalizada,
                                       NULL, -- cod_tasa
                                       550,  -- Transaccion de sobregiro
                                       v_fcdehoy);


        -- Insertar ge_bloqueos
        r_gbloq.nro_cuenta    := cta.nro_cuenta;
        r_gbloq.fec_inicio    := v_fcdehoy;
        r_gbloq.nro_documento := 1;
        r_gbloq.cod_causa     := fug_obt_pardinamico('COD_CAU_CAN_SOBREGIRO');
        r_gbloq.hor_inicio    := v_hora;
        r_gbloq.fec_fin       := NULL;
        r_gbloq.tipo          := 'T'; -- Bloqueo Total
        r_gbloq.tip_bloqueo   := 'M'; -- Manual
        r_gbloq.monto         := 0;
        r_gbloq.observacion   := 'BLOQUEO TOTAL POR PASE A OPE VENCIDA';
        lp_ins_ge_bloqueos(r_gbloq);

        -- Inserta el registro operacion vencida

        BEGIN
          INSERT INTO ov_cta_vencidas
            (cod_modulo, cod_modalidad,
             cod_oficina, nro_cuenta,
             nro_cta_origen, cod_moneda,
             denominacion, fec_apertura,
             estado, fec_cam_estado,
             mto_origen, sal_total,
             dia_atr_inicial, dia_atraso,
             fec_ini_mora,
             val_tasa, fec_ult_movimiento,
             est_batch)
          VALUES
            (15, 153,
             cta.cod_oficina, v_nvo_cuenta,
             cta.nro_cuenta, cta.cod_moneda,
             cta.denominacion, v_fcdehoy,
             v_est_cuenta, v_fcdehoy,
             v_tot_debito, v_tot_debito,
             cta.can_dias, cta.can_dias,
             v_fcdehoy - NVL(cta.can_dias, 0), -- DYDMR-4894 Se elimina el formateo de fechas
             v_val_tasa, v_fcdehoy,
             v_est_cuenta);
        END;

        --- Insertar relacion PRINCIPAL cliente cuentas

        BEGIN
          INSERT INTO ge_cta_clientes
            (cod_persona, nro_cuenta, dig_verificador,
             cod_oficina, cod_modulo, cod_modalidad, relacion)
          VALUES
            (cta.cod_persona, v_nvo_cuenta, cta.dig_verificador,
             cta.cod_oficina, 15, 153, 'P');

        END;

        --Borrar Linea de Contingenia de cuentas que pasan a Vencida
        BEGIN
            DELETE FROM cc_lin_sobregiros c
            where c.nro_cuenta=cta.nro_cuenta ;

        END;



        pag_cta.PR_SET_VARIABLES(USER, NULL, '358', 'C', 'N', v_nro_secuencia);

        r_gmovi.nro_secuencia    := v_nro_secuencia;
        r_gmovi.cod_usuario      := USER;
        r_gmovi.hora             := v_hora;
        r_gmovi.fecha            := v_fcdehoy;
        r_gmovi.cod_modulo       := 15;
        r_gmovi.cod_modalidad    := 153;
        r_gmovi.cod_oficina      := cta.cod_oficina;
        r_gmovi.nro_cuenta       := v_nvo_cuenta;
        r_gmovi.cod_moneda       := cta.cod_moneda;
        r_gmovi.tip_mov_rubro    := 'C';
        r_gmovi.cod_tra_padre    := 358;
        r_gmovi.cod_transaccion  := 711;
        r_gmovi.monto            := v_tot_debito;
        r_gmovi.fec_valor        := v_fcdehoy;
        r_gmovi.emi_aviso        := 'S';
        r_gmovi.reversado        := 'N';
        r_gmovi.protegido        := 'N';
        r_gmovi.estado           := 'N';
        r_gmovi.cod_ofi_origen   := cta.cod_oficina;
        r_gmovi.cod_mod_padre    := 4;
        r_gmovi.cod_mad_padre    := 41;
        r_gmovi.nro_documento    := NVL(p_nro_documento, cta.nro_cuenta);
        r_gmovi.concepto         := NVL(p_concepto, 'Pasar a vencido la cta.=' || cta.nro_cuenta);
        r_gmovi.est_cuenta       := v_est_cuenta;



        pag_gen.pr_ins_ge_movimiento(r_gmovi);

      END IF;

    EXCEPTION
      -- MODIFICACIÓN: Captura cualquier error de la cuenta actual
      WHEN OTHERS THEN

        PRG_INS_LOG_ERRORES('PASE SOBREGIRO A VENCIDO',
                           'ERROR EN CUENTA (' || v_cta_error || '): ' || SQLERRM,
                           cta.nro_cuenta,
                           NULL,
                           NULL,
                           null);

    END;
   commit;
  END LOOP;
END;
/
