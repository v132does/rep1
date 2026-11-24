CREATE OR REPLACE PACKAGE BODY IT.PAW_BTS IS

  
  g_cod_mon_local   ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
     
  FUNCTION lf_ver_mov_duplicado(p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                                p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                                p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                                p_monto           IN ge_movimientos.monto%TYPE,
                                p_mov_nocturno    IN VARCHAR2) RETURN typ_mensajeRespuesta IS

     MSG_COD_MOV_YA_INGRESADO CONSTANT VARCHAR2(15) := 'G_MOV_YA_INGRE';
     v_existe  VARCHAR2(1);
     v_retorno typ_mensajeRespuesta := typ_mensajeRespuesta;
     v_min_transaccion NUMBER := nvl(to_number(fug_obt_pardinamico('PAW_BTS_TRANSACCION')), 10);
  BEGIN
     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

     BEGIN
        IF p_mov_nocturno = 'S' THEN
           SELECT 'S'
             INTO v_existe
             FROM ge_movimientos_noc
            WHERE nro_cuenta = p_nro_cuenta
              AND cod_transaccion = p_cod_transaccion
              AND cod_tra_padre = p_cod_tra_padre
              AND monto = p_monto
              AND reversado = 'N'
              AND ((SYSDATE) - fec_insercion) * 1440 <= v_min_transaccion
              AND rownum = 1;
        ELSE
           SELECT 'S'
             INTO v_existe
             FROM ge_movimientos
            WHERE nro_cuenta = p_nro_cuenta
              AND cod_transaccion = p_cod_transaccion
              AND cod_tra_padre = p_cod_tra_padre
              AND monto = p_monto
              AND reversado = 'N'
              AND ((SYSDATE) - fec_insercion) * 1440 <= v_min_transaccion
              AND rownum = 1;
        END IF;
        paw_uti.pr_mensajeUsuario(MSG_COD_MOV_YA_INGRESADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
     EXCEPTION
        WHEN no_data_found THEN
           NULL;
        WHEN too_many_rows THEN
           paw_uti.pr_mensajeUsuario(MSG_COD_MOV_YA_INGRESADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
     END;

     RETURN v_retorno;
  END;
   FUNCTION lf_ver_ref_duplicada(p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                                 p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
                                 p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                                 p_nro_referencia  IN ge_movimientos.nro_documento%TYPE) RETURN typ_mensajeRespuesta IS

     MSG_COD_MOV_YA_INGRESADO CONSTANT VARCHAR2(15) := 'G_MOV_YA_INGRE';
     v_existe  VARCHAR2(1) := 'N';
     v_retorno typ_mensajeRespuesta := typ_mensajeRespuesta;
  BEGIN
     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

     BEGIN
        BEGIN
           -- buscamos si existe movimiento con el mismo numero de documento
           SELECT 'S'
             INTO v_existe
             FROM ge_movimientos
            WHERE nro_cuenta = p_nro_cuenta
              AND cod_transaccion = p_cod_transaccion
              AND cod_tra_padre = p_cod_tra_padre
              AND nro_documento = p_nro_referencia
              AND reversado = 'N'
              AND rownum = 1;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
             -- buscamos si no esta en mov. nocturno
             SELECT 'S'
               INTO v_existe
               FROM ge_movimientos_noc
              WHERE nro_cuenta = p_nro_cuenta
                AND cod_transaccion = p_cod_transaccion
                AND cod_tra_padre = p_cod_tra_padre
                AND nro_documento = p_nro_referencia
                AND reversado = 'N'
                AND rownum = 1;
        END;
     EXCEPTION
        WHEN no_data_found THEN
           NULL;
        WHEN too_many_rows THEN
           v_existe := 'S';
     END;
     IF v_existe = 'S' THEN
        paw_uti.pr_mensajeUsuario(MSG_COD_MOV_YA_INGRESADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
     END IF;
     RETURN v_retorno;
  END;
  
  FUNCTION lf_ver_movimiento(p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                             p_nro_transaccion IN ge_movimientos.nro_documento%TYPE,
                             p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE) RETURN typ_mapa IS
     v_fecha      ge_movimientos.fecha%TYPE;
     v_cod_moneda ge_movimientos.cod_moneda%TYPE;
     v_monto      ge_movimientos.monto%TYPE;
     v_retorno    typ_mapa := typ_mapa();
  BEGIN
     v_retorno.datosAdicionales := typ_listaclavevalor();
     v_retorno.cantidad := 0;
     BEGIN
       -- buscamos en movimientos del dia hora abierta
       SELECT m.fecha, m.cod_moneda, m.monto
         INTO v_fecha, v_cod_moneda, v_monto
         FROM ge_movimientos m
        WHERE m.nro_cuenta = p_nro_cuenta
          AND m.cod_transaccion = 602
          AND m.cod_tra_padre = p_cod_tra_padre
          AND m.reversado = 'N'
          AND m.nro_documento = p_nro_transaccion;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN 
           -- buscamos en movimientos nocturnos
           BEGIN
              SELECT mn.fecha, mn.cod_moneda, mn.monto
                INTO v_fecha, v_cod_moneda, v_monto
                FROM ge_movimientos_noc mn
               WHERE mn.nro_cuenta = p_nro_cuenta
                 AND mn.cod_transaccion = 602
                 AND mn.cod_tra_padre = p_cod_tra_padre
                 AND reversado = 'N'
                 AND mn.nro_documento = p_nro_transaccion;
           EXCEPTION
             WHEN NO_DATA_FOUND THEN
                paw_uti.pr_mensajeUsuario('CTA_SMOV', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                RETURN v_retorno;
           END;
     END;
     
     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
     
     paw_uti.pr_add_value(v_retorno.datosAdicionales, 'COD_MONEDA', v_cod_moneda, 'STRING');
     paw_uti.pr_add_value(v_retorno.datosAdicionales, 'MONTO', paw_uti.lf_for_money(v_monto), 'NUMBER');
     paw_uti.pr_add_value(v_retorno.datosAdicionales, 'FECHA', paw_uti.lf_for_date(v_fecha), 'STRING');
     paw_uti.pr_add_value(v_retorno.datosAdicionales, 'NRO_CUENTA', p_nro_cuenta, 'STRING');
     paw_uti.pr_add_value(v_retorno.datosAdicionales, 'NRO_TRANSACCION', p_nro_transaccion, 'STRING');

     v_retorno.cantidad := v_retorno.datosAdicionales.count;
     RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      RETURN v_retorno;
  END;
  -- verificar mov. trans. interna
  FUNCTION fu_ver_movimiento(p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                             p_nro_transaccion IN ge_movimientos.nro_documento%TYPE) RETURN typ_mapa IS
  BEGIN
     RETURN lf_ver_movimiento(p_nro_cuenta, p_nro_transaccion, 411);
  END;
  -- traducir cuenta sipap
  FUNCTION lf_cta_verificada(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
     v_nro_cuenta VARCHAR2(20);
  BEGIN
     v_nro_cuenta := pas_snp.fu_val_cadena(p_nro_cuenta, 'N');
     IF length(v_nro_cuenta) > 10 THEN
        v_nro_cuenta := substr(v_nro_cuenta, length(v_nro_cuenta)-9,  length(v_nro_cuenta));
     END IF;
     RETURN v_nro_cuenta;
  EXCEPTION
     WHEN OTHERS THEN
        RETURN 'x';
  END;
  -- verificar movimiento sipap
  FUNCTION fu_ver_mov_snp(p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                          p_nro_transaccion IN ge_movimientos.nro_documento%TYPE) RETURN typ_mapa IS
  BEGIN
     RETURN lf_ver_movimiento(lf_cta_verificada(p_nro_cuenta), p_nro_transaccion, 309);

  END;
  -- validar cuenta credito
  FUNCTION fu_val_cta_credito(p_nro_cuenta    IN ge_cuentas.nro_cuenta%TYPE,
                              p_nro_documento IN ba_personas.nro_documento%TYPE DEFAULT NULL,
                              p_monto         IN ge_movimientos.monto%TYPE DEFAULT NULL) RETURN typ_mapa IS
     v_respuesta typ_mensajerespuesta;
     v_cod_tra_padre     ge_transacciones.cod_transaccion%TYPE := 411;
     v_retorno           typ_mapa := typ_mapa();
     v_cod_moneda        ge_cuentas.cod_moneda%TYPE;
     v_tip_cuenta        ge_modalidades.descripcion%TYPE;
     v_cod_persona       ba_personas.cod_persona%TYPE;
     v_nro_cuenta        ge_cuentas.nro_cuenta%TYPE;
  BEGIN
     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);                  
     
     -- validamos el documento con cuenta
     v_nro_cuenta := lf_cta_verificada(p_nro_cuenta);
     BEGIN
        SELECT gc.cod_moneda, per.cod_persona, paw_bce.fu_tip_cuenta(gc.cod_modulo, gc.cod_modalidad)
          INTO v_cod_moneda, v_cod_persona, v_tip_cuenta
          FROM ge_cta_clientes cta, ba_personas per, ge_cuentas gc
         WHERE cta.nro_cuenta = v_nro_cuenta
           AND cta.nro_cuenta = gc.nro_cuenta
           AND cta.cod_persona = per.cod_persona
           AND per.nro_documento = nvl(p_nro_documento, per.nro_documento)
           AND cta.relacion IN ('P', 'Y', 'O')
           AND rownum = 1;

        v_respuesta := paw_bas.fu_val_cta_credito(v_nro_cuenta, v_cod_tra_padre, 9, 91, p_monto);
        IF v_respuesta.error = 'S' THEN
           v_retorno.error := 'S';
           v_retorno.nombreRespuesta := v_respuesta.nombreRespuesta;
           v_retorno.descripcionRespuesta := v_respuesta.descripcionRespuesta;
           RETURN v_retorno;
        END IF;
        
        v_retorno.datosAdicionales := typ_listaclavevalor();
        IF pag_gen.fu_es_per_fisica(v_cod_persona) = 'S' THEN
           paw_uti.pr_add_value(v_retorno.datosAdicionales, 'TITULAR', fue_obt_nom_per_corto(v_cod_persona), 'STRING');
        ELSE
           paw_uti.pr_add_value(v_retorno.datosAdicionales, 'TITULAR', fue_obt_raz_social(v_cod_persona), 'STRING');
        END IF;
        paw_uti.pr_add_value(v_retorno.datosAdicionales, 'COD_MONEDA', v_cod_moneda, 'STRING');
        paw_uti.pr_add_value(v_retorno.datosAdicionales, 'TIP_CUENTA', v_tip_cuenta, 'STRING');
     EXCEPTION
        WHEN no_data_found THEN
           paw_uti.pr_mensajeUsuario('CTA_CRE_INVALID', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           RETURN v_retorno;
     END;
     v_retorno.cantidad := v_retorno.datosAdicionales.count;
     RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        RETURN v_retorno;
  END;
  -- procesar cuenta debito y acreditar en cuenta puente
  FUNCTION fu_pro_cta_debito(p_nro_operacion    IN ge_movimientos.nro_documento%TYPE,
                             p_nro_cta_debito   IN ge_movimientos.nro_cuenta%TYPE,
                             p_mto_debito       IN ge_movimientos.monto%TYPE,
                             p_mto_credito      IN ge_movimientos.monto%TYPE,
                             p_cod_mon_debito   IN ge_movimientos.cod_moneda%TYPE,
                             p_cod_mon_credito  IN ge_movimientos.cod_moneda%TYPE,
                             p_cot_debito       IN ge_movimientos.cotizacion%TYPE,
                             p_cot_credito      IN ge_movimientos.cotizacion%TYPE,
                             p_cod_usuario      IN ge_movimientos.cod_usuario%TYPE,
                             p_cod_ofi_origen   IN ge_movimientos.cod_ofi_origen%TYPE,
                             p_fec_actual       IN ge_movimientos.fecha%TYPE,
                             p_es_mov_noc       IN VARCHAR2,
                             p_concepto         IN ge_movimientos.concepto%TYPE,
                             p_nro_ope_cambio   IN lc_ope_pendientes.nro_operacion%TYPE DEFAULT NULL,
                             p_msj_error        OUT VARCHAR2) RETURN typ_mensajerespuesta IS
     v_retorno typ_mensajerespuesta := typ_mensajerespuesta;
     v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
     v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE := 411;
     v_fec_valor       ge_movimientos.fec_valor%TYPE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
     v_hor_actual      ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
     r_gmovi           ge_movimientos%rowtype := NULL;
     -- v_cod_rub_credito ge_movimientos.cod_rubro%TYPE;
     v_cod_mod_debito ge_cuentas.cod_modulo%TYPE;
     v_cod_mad_debito ge_cuentas.cod_modalidad%TYPE;
     v_cod_ofi_debito ge_cuentas.cod_oficina%TYPE;
     -- para lp_ver_operacion
     v_mto_equ_local   ge_movimientos.mto_equ_local%TYPE;
     v_pos_cam_tra_gnb varchar2(1);
     
  BEGIN
     v_nro_secuencia := 0;
     pag_cta.pr_set_variables(p_cod_usuario, v_fec_valor, v_cod_tra_padre, 'N', 'N', v_nro_secuencia, NULL, p_cod_ofi_origen, 9, 91);
               
     
     SELECT c.cod_modulo, c.cod_modalidad, c.cod_oficina
       INTO v_cod_mod_debito, v_cod_mad_debito, v_cod_ofi_debito
       FROM ge_cuentas c
      WHERE c.nro_cuenta = p_nro_cta_debito;
     --
     IF nvl(p_nro_ope_cambio, 0) = 0 THEN
        IF p_cod_mon_credito <> p_cod_mon_debito THEN
           v_mto_equ_local := NULL;
           IF p_cod_mon_debito <> g_cod_mon_local THEN
              IF p_cod_mon_credito = g_cod_mon_local THEN
                 v_mto_equ_local := p_mto_credito;
              ELSE
                 v_mto_equ_local := round(p_mto_debito * p_cot_debito, 0);
              END IF;
           END IF;
        END IF;
     END IF;
     
     v_hor_actual := fug_obt_hor_disponible(p_fec_actual, v_hor_actual, p_cod_usuario, p_es_mov_noc);
     pag_cta.PR_ACT_OPERACION(
                  p_nro_cta_debito,
                  v_hor_actual,
                  'D',
                  p_cod_mon_debito,
                  p_mto_debito,
                  v_cod_tra_padre,
                  503,
                  p_nro_operacion,
                  p_cot_debito,
                  p_cod_ofi_origen,
                  9,
                  91,
                  NULL,
                  NULL,
                  p_concepto,
                  'N',
                  v_nro_secuencia,
                  v_fec_valor,
                  NULL,
                  NULL,
                  v_mto_equ_local);

     IF nvl(pag_cta.g_cod_error, 0) = 0 THEN
        IF nvl(p_nro_ope_cambio, 0) = 0 THEN
           IF p_cod_mon_credito <> g_cod_mon_local AND p_cod_mon_debito <> p_cod_mon_credito THEN
              IF p_cod_mon_debito = g_cod_mon_local THEN
                 v_mto_equ_local := p_mto_debito;
              ELSE
                 v_mto_equ_local := round(p_mto_credito * p_cot_credito, 0);
              END IF;
           ELSE
              v_mto_equ_local := NULL;
           END IF;
        END IF;
        -- Aumento la secuencia
        v_nro_secuencia         := v_nro_secuencia + 1;
        r_gmovi.cod_modulo      := v_cod_mod_debito;
        r_gmovi.cod_modalidad   := v_cod_mad_debito;
        r_gmovi.cod_oficina     := v_cod_ofi_debito;
        r_gmovi.nro_cuenta      := NULL;
        r_gmovi.cod_transaccion := 74;
        r_gmovi.cod_moneda      := p_cod_mon_credito;
        r_gmovi.cod_usuario     := p_cod_usuario;
        r_gmovi.hora            := v_hor_actual;
        r_gmovi.fecha           := p_fec_actual;
        r_gmovi.nro_secuencia   := v_nro_secuencia;
        r_gmovi.fec_valor       := v_fec_valor;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_mod_padre   := 9;
        r_gmovi.cod_mad_padre   := 91;
        r_gmovi.monto           := p_mto_credito;
        r_gmovi.nro_documento   := p_nro_operacion;
        r_gmovi.cotizacion      := p_cot_credito;
        r_gmovi.mto_equ_local   := v_mto_equ_local;
        r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.concepto        := p_concepto;
        r_gmovi.estado          := 'N';
        r_gmovi.reversado       := 'N';
        -- insertamos  el mov. rubro  contable
        pag_gen.pr_ins_ge_movimiento(r_gmovi, p_es_mov_noc);
        -- --------------
        IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
           -- hubo error en el credito
           p_msj_error := substr(pag_cta.g_msj_error, 1, 1000);
           paw_uti.pr_mensajeUsuario('TRA_CTA_CRE_ERR', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
           RETURN v_retorno;
        ELSE
           IF nvl(p_nro_ope_cambio, 0) <> 0 then
              paw_bas.pr_liq_ope_cambio(p_cod_usuario, p_nro_cta_debito, p_mto_debito, p_cod_mon_debito, p_cod_mon_credito, p_nro_ope_cambio);
           END IF;
           
           --GENERAR MOVIMIENTO DE POSICIÓN DE CAMBIOS
            v_pos_cam_tra_gnb := fug_obt_pardinamico ('POS_CAMBIO_TRAN_GNB');
            
            IF v_pos_cam_tra_gnb = 'S' AND p_cod_mon_debito <> p_cod_mon_credito THEN

               --arbitraje
               IF ((p_cod_mon_debito <> g_cod_mon_local) AND (p_cod_mon_credito <> g_cod_mon_local)) THEN
                  --llamar compra--
                  prl_pro_ope_cam_tra_gnb(p_fec_actual,v_hor_actual, p_cod_usuario,p_nro_operacion,'C',p_es_mov_noc);
                       
                  --llamar venta--
                  prl_pro_ope_cam_tra_gnb(p_fec_actual,v_hor_actual, p_cod_usuario,p_nro_operacion,'V',p_es_mov_noc);
                 
               ELSE
                  IF p_cod_mon_debito = g_cod_mon_local THEN
                     --llamar venta--
                     prl_pro_ope_cam_tra_gnb(p_fec_actual,v_hor_actual, p_cod_usuario,p_nro_operacion,'V',p_es_mov_noc);

                  ELSE
                     --llamar compra--
                     prl_pro_ope_cam_tra_gnb(p_fec_actual,v_hor_actual, p_cod_usuario,p_nro_operacion,'C',p_es_mov_noc);

                  END IF;
               END IF;
           END IF;
         END IF;
      ELSE
         p_msj_error := substr(pag_cta.g_msj_error, 1, 1000);
         paw_uti.pr_mensajeUsuario('TRA_CTA_DEB_ERR', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;
      RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        p_msj_error := substr(sqlerrm, 1, 1000);
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        RETURN v_retorno;
  END;           

  -- procesar cuenta para acreditar cliente y debitar en cuenta puente                     
  FUNCTION fu_pro_cta_credito(p_nro_caja       IN cj_cajas.nro_caja%TYPE,
                              p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE,
                              p_monto          IN ge_movimientos.monto%TYPE,
                              p_nro_referencia IN VARCHAR2) RETURN typ_mapa IS
     v_retorno         typ_mapa := typ_mapa;
     v_error           typ_mensajeRespuesta := typ_mensajeRespuesta;
     v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE;
     v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE := 411;
     v_fec_valor       ge_movimientos.fec_valor%TYPE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
     v_hor_actual      ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS'); -- Hora actual
     v_mto_equ_local   ge_movimientos.mto_equ_local%TYPE := NULL;
     r_gmovi           ge_movimientos%rowtype := NULL;
     -- v_cod_rub_debito  ge_movimientos.cod_rubro%TYPE;
     v_cod_mod_credito ge_cuentas.cod_modulo%TYPE;
     v_cod_mad_credito ge_cuentas.cod_modalidad%TYPE;
     v_cod_ofi_credito ge_cuentas.cod_oficina%TYPE;
     v_cotizacion      ge_movimientos.cotizacion%TYPE := NULL;
     v_denominacion    ge_cuentas.denominacion%TYPE;
     v_msj_caja        typ_mensajeCaja;
     -- para lp_ver_operacion
     v_horario         VARCHAR2(1);
     v_es_mov_noc      VARCHAR2(1);
     v_es_cta_noc      VARCHAR2(1);
     v_fec_actual      DATE;
     v_nro_referencia  VARCHAR2(15);
     v_cod_moneda      ge_cuentas.cod_moneda%TYPE;
     v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
     v_nom_ordenante   VARCHAR2(150);
     v_ret            NUMBER;
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error); 
    
    v_nro_cuenta := lf_cta_verificada(p_nro_cuenta);
    v_retorno := fu_val_cta_credito(v_nro_cuenta, NULL, p_monto);
    /*IF v_retorno.error = 'S' THEN
       RETURN v_retorno;
    END IF;*/
    
    v_msj_caja := paw_seg.fu_val_caja(p_nro_caja);
    IF v_msj_caja.error = 'S' THEN
       v_retorno.error := 'S';
       v_retorno.nombreRespuesta := v_msj_caja.nombreRespuesta;
       v_retorno.descripcionRespuesta := v_msj_caja.descripcionRespuesta;
       RETURN v_retorno;
    END IF;
    v_nro_referencia := TRIM(substr(p_nro_referencia, 1, 15));
    v_nom_ordenante := TRIM(substr(p_nro_referencia, 16, 150));       
            
    -- esta la cuenta en condiciones, verifico el horario
    v_error := paw_uti.fu_ver_horario(v_horario, v_es_mov_noc, v_es_cta_noc, v_msj_caja.fechaUltimoCierre, v_msj_caja.codigoOficinaOrigen, v_fec_actual);
    IF v_error.error = 'S' THEN
       v_retorno.error := v_error.error;
       v_retorno.nombreRespuesta := v_error.nombreRespuesta;
       v_retorno.descripcionRespuesta := v_error.descripcionRespuesta;
       RETURN v_retorno;
    END IF;
    -- validar monto de credito
    IF nvl(p_monto, 0) <= 0 THEN
       paw_uti.pr_mensajeUsuario('MTO_INVALIDO', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       RETURN v_retorno;
    END IF;
    -- verificamos que no sea un posible mov. duplicado
    v_error := lf_ver_mov_duplicado(602, v_cod_tra_padre, v_nro_cuenta, p_monto, v_es_mov_noc);
    IF v_error.error = 'S' THEN
       v_retorno.error := v_error.error;
       v_retorno.nombreRespuesta := v_error.nombreRespuesta;
       v_retorno.descripcionRespuesta := v_error.descripcionRespuesta;
       RETURN v_retorno;
    END IF;
    v_error := lf_ver_ref_duplicada(602, v_cod_tra_padre, v_nro_cuenta, v_nro_referencia);
    IF v_error.error = 'S' THEN
       v_retorno.error := v_error.error;
       v_retorno.nombreRespuesta := v_error.nombreRespuesta;
       v_retorno.descripcionRespuesta := v_error.descripcionRespuesta;
       RETURN v_retorno;
    END IF;
    -- genero el numero de operacion
    SELECT c.cod_moneda, cod_modulo, cod_modalidad, cod_oficina, denominacion
      INTO v_cod_moneda, v_cod_mod_credito, v_cod_mad_credito, v_cod_ofi_credito, v_denominacion
      FROM ge_cuentas c
     WHERE c.nro_cuenta = v_nro_cuenta;
     
    IF v_cod_moneda != pag_gen.fu_obt_mon_local THEN
       v_cotizacion    := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
       v_mto_equ_local := round(p_monto * v_cotizacion, 0);
    END IF;

    v_nro_secuencia  := 1;
    pag_cta.pr_set_variables(v_msj_caja.codigoUsuario, v_fec_valor, v_cod_tra_padre, 'N', 'N', v_nro_secuencia, NULL, v_msj_caja.codigoOficinaOrigen, 9, 91);
    -- Se busca una hora disponible
    v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, v_msj_caja.codigoUsuario, v_es_mov_noc);
    v_nro_secuencia         := 1;
    r_gmovi.cod_modulo      := v_cod_mod_credito;
    r_gmovi.cod_modalidad   := v_cod_mad_credito;
    r_gmovi.cod_oficina     := v_cod_ofi_credito;
    r_gmovi.nro_cuenta      := NULL;
    r_gmovi.cod_transaccion := 75;
    r_gmovi.cod_moneda      := v_cod_moneda;
    r_gmovi.cod_usuario     := v_msj_caja.codigoUsuario;
    r_gmovi.hora            := v_hor_actual;
    r_gmovi.fecha           := v_fec_actual;
    r_gmovi.nro_secuencia   := v_nro_secuencia;
    r_gmovi.fec_valor       := v_fec_valor;
    r_gmovi.cod_tra_padre   := v_cod_tra_padre;
    r_gmovi.cod_mod_padre   := 9;
    r_gmovi.cod_mad_padre   := 91;
    r_gmovi.monto           := p_monto;
    r_gmovi.nro_documento   := v_nro_referencia;
    r_gmovi.cotizacion      := v_cotizacion;
    r_gmovi.mto_equ_local   := v_mto_equ_local;
    r_gmovi.cod_ofi_origen  := v_cod_ofi_credito;
    r_gmovi.emi_aviso       := 'N';
    r_gmovi.concepto        := substr('Transf. de GNBPy - cta: ' || v_nom_ordenante, 1, 100);
    r_gmovi.estado          := 'N';
    r_gmovi.reversado       := 'N';
    -- insertamos  el mov. rubro  contable
    pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_mov_noc);
    -- --------------
    IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
       -- hubo error en el credito
       paw_uti.pr_mensajeUsuario('TRA_CTA_DEB_ERR', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       paw_uti.pr_insertarbitacora('11198', 999, v_nro_referencia, '055',  NULL, 'pr_act_operacion(deb): ' || pag_cta.g_msj_error, paw_uti.bitacora_error);   
       RETURN v_retorno;
    END IF;
    pag_cta.pr_act_operacion(
                  v_nro_cuenta,
                  v_hor_actual,
                  'C',
                  v_cod_moneda,
                  p_monto,
                  v_cod_tra_padre,
                  602,
                  v_nro_referencia,
                  v_cotizacion,
                  v_cod_ofi_credito,
                  9,
                  91,
                  NULL,
                  NULL,
                  substr('Transf. de GNBPy - cta: ' || v_nom_ordenante, 1, 100),
                  'N',
                  v_nro_secuencia,
                  v_fec_valor,
                  NULL,
                  NULL,
                  v_mto_equ_local); -- mto_equ_local
    IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
       -- hubo error en el credito
       paw_uti.pr_mensajeUsuario('TRA_CTA_CRE_ERR', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       paw_uti.pr_insertarbitacora('11198', 999, v_nro_referencia, '055',  NULL, 'fu_pro_cta_credito: ' || pag_cta.g_msj_error, paw_uti.bitacora_error);   
       RETURN v_retorno;
    END IF;
    paw_uti.pr_add_value(v_retorno.datosAdicionales, 'NRO_OPERACION', v_nro_referencia, 'STRING');
    v_ret := paw_not.fu_not_tra_gnb(v_nom_ordenante, NULL, NULL, v_nro_cuenta, v_cod_moneda, p_monto, v_denominacion, NULL, v_nro_referencia, 'P');
    RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarbitacora('11198', 999, v_nro_referencia, '055',  NULL, 'fu_pro_cta_credito: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200), paw_uti.bitacora_error);
        RETURN v_retorno;
  END;
  
  FUNCTION fu_reg_error(p_nro_documento     IN VARCHAR2,
                        p_nro_cta_debito    IN ge_cuentas.nro_cuenta%TYPE,
                        p_nro_cta_credito   IN VARCHAR2, 
                        p_cod_mon_credito   IN ba_monedas.cod_moneda%TYPE, 
                        p_mto_credito       IN ge_movimientos.monto%TYPE,
                        p_nro_doc_pendiente IN bw_mov_pendientes.nro_documento%TYPE DEFAULT NULL) RETURN typ_mensajerespuesta IS
    v_fec_valor ge_movimientos.fec_valor%TYPE := pag_cal.fu_obt_fec_actual(9);
    v_retorno   typ_mensajerespuesta  := typ_mensajerespuesta;
    v_nro_documento bw_mov_bts.nro_documento%TYPE;
  BEGIN
     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error); 
     v_nro_documento := TRIM(substr(p_nro_documento, 1, 15));
     INSERT INTO bw_mov_bts
       (nro_documento, fec_valor, nro_cta_debito, nro_cta_credito, cod_mon_credito, mto_credito, nro_doc_pendiente)
     VALUES
       (v_nro_documento, v_fec_valor, p_nro_cta_debito, p_nro_cta_credito, p_cod_mon_credito, p_mto_credito, p_nro_doc_pendiente);
     -- se marca como encolado para que no se muestre confirmado mientras dure la verificacion
     IF p_nro_doc_pendiente IS NOT NULL THEN
        UPDATE bw_mov_pendientes p 
           SET p.estado = 'E'
         WHERE p.nro_documento = p_nro_doc_pendiente
           AND p.cod_tip_mensaje = '055';  
     END IF;  
     RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarbitacora('11198', 999, v_nro_documento, '055',  NULL, 'Error reg error' || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, 'Error: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200),  NULL), paw_uti.bitacora_error);
        RETURN v_retorno;
  END;
  
  PROCEDURE lp_obt_dat_reversa(p_nro_cuenta    IN ge_movimientos.nro_cuenta%TYPE,
                               p_nro_documento IN ge_movimientos.nro_documento%TYPE,
                               p_fecha         OUT ge_movimientos.fecha%TYPE,
                               p_hora          OUT ge_movimientos.hora%TYPE,
                               p_cod_usuario   OUT ge_movimientos.cod_usuario%TYPE,
                               p_cod_mod_padre OUT ge_movimientos.cod_mod_padre%TYPE,
                               p_cod_mad_padre OUT ge_movimientos.cod_mad_padre%TYPE,
                               p_cod_tra_padre OUT ge_movimientos.cod_tra_padre%TYPE) IS
  BEGIN
     SELECT m.fecha, m.hora, m.cod_usuario, m.cod_mod_padre, m.cod_mad_padre, m.cod_tra_padre
       INTO p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, p_cod_mad_padre, p_cod_tra_padre
       FROM ge_movimientos m
      WHERE m.nro_cuenta = p_nro_cuenta
        AND m.nro_documento = p_nro_documento
        AND m.cod_tra_padre = 411
        AND m.cod_transaccion = 503
        AND m.reversado = 'N';
  END;
  -- 
  PROCEDURE lp_act_est_mov(p_nro_documento IN bw_mov_bts.nro_documento%TYPE,
                           p_estado        IN bw_mov_bts.estado%TYPE) IS
     v_res             NUMBER;
     v_dir_mail        ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('DIR_MAIL_VER_CONSISTENCIA', '');
     v_nro_cta_debito  bw_mov_bts.nro_cta_debito%TYPE;
     v_nro_cta_credito bw_mov_bts.nro_cta_credito%TYPE; 
     v_cod_mon_credito bw_mov_bts.cod_mon_credito%TYPE; 
     v_mto_credito     bw_mov_bts.mto_credito%TYPE;
  BEGIN
     UPDATE bw_mov_bts a 
        SET a.estado = p_estado
      WHERE a.nro_documento = p_nro_documento
        AND a.estado = 'V'; -- se cambia el estado de una fila en verificacion
        
     IF p_estado = 'E' AND v_dir_mail IS NOT NULL THEN
       v_res := paw_not.fu_env_email_prueba(v_dir_mail, 'Error al procesar documento '||p_nro_documento||' de transf. internas a GNBPY', 'PAW_BTS');
     END IF;
     
     IF p_estado IN ('C', 'R') THEN
      
       BEGIN
          SELECT a.nro_cta_debito, a.nro_cta_credito, a.cod_mon_credito, a.mto_credito
            INTO v_nro_cta_debito, v_nro_cta_credito, v_cod_mon_credito, v_mto_credito
            FROM bw_mov_bts a
           WHERE a.nro_documento = p_nro_documento;
          
          v_res := paw_not.fu_not_tra_gnb_mail(v_nro_cta_debito,
                                               NULL, -- mon. debito
                                               NULL, -- mto. debito
                                               v_nro_cta_credito,
                                               v_cod_mon_credito,
                                               v_mto_credito,
                                               NULL, -- beneficiario
                                               NULL, -- concepto
                                               p_nro_documento,
                                               p_estado);
       EXCEPTION
         WHEN OTHERS THEN
           NULL;
       END;
     END IF;
  END;
  -- verificar rollback de mov. pendiente de empresa
  PROCEDURE lp_rev_pediente(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) IS
    v_nro_doc_pendiente bw_mov_bts.nro_doc_pendiente%TYPE;
    v_ult_autorizador   bw_autorizaciones.cod_persona%TYPE;
  BEGIN
     SELECT b.nro_doc_pendiente
       INTO v_nro_doc_pendiente
       FROM bw_mov_bts b
      WHERE b.nro_documento = p_nro_documento
        AND b.estado = 'R';
     
     IF v_nro_doc_pendiente IS NOT NULL THEN
        UPDATE bw_mov_pendientes p
           SET can_aut_faltantes = 1, estado = 'P'
         WHERE p.nro_documento = v_nro_doc_pendiente
           AND cod_tip_mensaje = '055'
           AND estado IN ('C', 'E')
           AND can_aut_faltantes = 0;
           
       SELECT a.cod_persona 
         INTO v_ult_autorizador
         FROM (SELECT * 
                 FROM bw_autorizaciones a 
                WHERE a.nro_documento = v_nro_doc_pendiente 
                  AND a.accion = 'A'
                ORDER BY a.fec_insercion DESC) a 
        WHERE rownum = 1;

        -- elimino la firma registrada
        DELETE FROM bw_autorizaciones
         WHERE nro_documento = v_nro_doc_pendiente
           AND cod_persona = v_ult_autorizador
           AND accion = 'A';
     END IF;
  EXCEPTION
     WHEN NO_DATA_FOUND THEN
        NULL;
     WHEN OTHERS THEN
        paw_uti.pr_insertarbitacora('11198', 999, p_nro_documento, '055',  NULL, 'lp_rev_pediente: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200), paw_uti.bitacora_error);
  END;
  --
  PROCEDURE pr_ver_pendiente(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) IS
  BEGIN
     UPDATE bw_mov_bts a 
        SET a.estado = 'V', 
            a.can_reintentos = a.can_reintentos + 1
      WHERE a.nro_documento = p_nro_documento
        AND a.estado = 'P';
  EXCEPTION
     WHEN OTHERS THEN
        paw_uti.pr_insertarbitacora('11198', 999, p_nro_documento, '055',  NULL, 'lp_act_est_mov: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200), paw_uti.bitacora_error);
  END;
  --
  PROCEDURE pr_pen_verificado(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) IS
  BEGIN
     UPDATE bw_mov_bts a 
        SET a.estado = 'P'
      WHERE a.nro_documento = p_nro_documento
        AND a.estado = 'V';
  END;
  
  FUNCTION lf_obt_cta_verificacion(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) RETURN VARCHAR2 IS
     v_nro_cta_debito ge_cuentas.nro_cuenta%TYPE;
  BEGIN
     SELECT a.nro_cta_debito
       INTO v_nro_cta_debito
       FROM bw_mov_bts a 
      WHERE a.nro_documento = p_nro_documento
        AND a.estado = 'V';
       
     RETURN v_nro_cta_debito;
  END;
  
  PROCEDURE lp_obt_dat_historico(p_nro_cuenta    IN  ge_cuentas.nro_cuenta%TYPE, 
                                 p_nro_documento IN  bw_mov_bts.nro_documento%TYPE,
                                 p_fecha         OUT ge_movimientos.fecha%TYPE,
                                 p_hora          OUT ge_movimientos.hora%TYPE,
                                 p_cod_usuario   OUT ge_movimientos.cod_usuario%TYPE,
                                 p_cod_mod_padre OUT ge_movimientos.cod_mod_padre%TYPE,
                                 p_cod_mad_padre OUT ge_movimientos.cod_mad_padre%TYPE,
                                 p_cod_tra_padre OUT ge_movimientos.cod_tra_padre%TYPE) IS 
    v_cod_modulo ge_cuentas.cod_modulo%TYPE;
  BEGIN
    SELECT c.cod_modulo
      INTO v_cod_modulo
      FROM ge_cuentas c
     WHERE c.nro_cuenta = p_nro_cuenta;
     
    IF v_cod_modulo = 4 THEN
       SELECT h.fecha, h.hora, h.cod_usuario, h.cod_mod_padre, h.cod_mad_padre, h.cod_tra_padre
         INTO p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, p_cod_mad_padre, p_cod_tra_padre
         FROM cc_movimientos_his h
        WHERE h.nro_cuenta = p_nro_cuenta
          AND h.fecha >= trunc(SYSDATE-3)
          AND h.nro_documento = p_nro_documento
          AND h.cod_tra_padre = 411
          AND h.cod_transaccion = 503
          AND h.nro_secuencia = 1
          AND h.reversado = 'N';
     ELSE
        SELECT h.fecha, h.hora, h.cod_usuario, h.cod_mod_padre, h.cod_mad_padre, h.cod_tra_padre
          INTO p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, p_cod_mad_padre, p_cod_tra_padre
          FROM ah_movimientos_his h
         WHERE h.nro_cuenta = p_nro_cuenta
           AND h.fecha >= trunc(SYSDATE-3)
           AND h.nro_documento = p_nro_documento
           AND h.cod_tra_padre = 411
           AND h.cod_transaccion = 503
           AND h.nro_secuencia = 1
           AND h.reversado = 'N';
     END IF;
  END;
  
  -- reversar operaciones nocturnas del dia anterior
  PROCEDURE pr_rev_tra_anteriores IS
     v_fecha          ge_movimientos.fecha%TYPE;
     v_fec_valor      ge_movimientos.fec_valor%TYPE := pag_cal.fu_obt_fec_actual(9);
     v_hora           ge_movimientos.hora%TYPE;
     v_hor_reversion  ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS');
     v_usu_reversion  ba_usuarios.cod_usuario%TYPE := USER;
     v_cod_usuario    ge_movimientos.cod_usuario%TYPE;
     v_cod_mod_padre  ge_movimientos.cod_mod_padre%TYPE;
     v_cod_mad_padre  ge_movimientos.cod_mad_padre%TYPE;
     v_cod_tra_padre  ge_movimientos.cod_tra_padre%TYPE;
     v_total          NUMBER := 0;
     v_error          NUMBER := 0;
     v_msj_error      VARCHAR2(4000);
     v_msj_respuesta  typ_mensajerespuesta;
     --
     v_hor_cierre     cj_cajas.fec_hor_cierre%TYPE;
     v_cod_ofi_origen cj_cajas.cod_oficina%TYPE;
     v_horario        VARCHAR2(1);
     v_es_mov_noc     VARCHAR2(1);
     v_es_cta_noc     VARCHAR2(1);
     v_fec_actual     DATE;
     v_fec_hab_ant    ge_calendarios.fec_anterior%TYPE := pag_cal.fu_obt_fec_ant_hab(trunc(sysdate), 31);
     -- buscar pendientes de reversa
     CURSOR c_pendientes IS
        SELECT t.nro_documento, t.nro_cta_debito
          FROM bw_mov_bts t
         WHERE t.estado = 'N'
           AND t.fec_insercion >= trunc(v_fec_hab_ant);
  BEGIN
    SELECT c.fec_hor_cierre, c.cod_oficina
      INTO v_hor_cierre, v_cod_ofi_origen
      FROM cj_cajas c
     WHERE c.nro_caja = '999';

    v_msj_respuesta := paw_uti.fu_ver_horario(v_horario, v_es_mov_noc, v_es_cta_noc, v_hor_cierre, v_cod_ofi_origen, v_fec_actual);
    IF v_msj_respuesta.error = 'S' OR v_es_mov_noc = 'S' THEN
       raise_application_error(-21000, 'Horario no abierto');
    END IF;
    -- 3 ahorros, 4 cta. corrientes
    FOR c IN c_pendientes LOOP
       BEGIN
          v_total := v_total + 1;
          -- creamos un punto para rollback
          prg_cre_savepoint(c.nro_documento||'-'||c.nro_cta_debito);
          
          -- se obtiene los datos principales para reversar
          BEGIN
             -- se busca del historico
             lp_obt_dat_historico(c.nro_cta_debito, c.nro_documento,
                               v_fecha, v_hora,  v_cod_usuario, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre);
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                -- se busca de ge_movimientos  
                lp_obt_dat_reversa(c.nro_cta_debito, c.nro_documento,
                       v_fecha, v_hora, v_cod_usuario, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre);
          END;
          -- se obtiene hora disponible
          v_hor_reversion := fug_obt_hor_disponible(v_fec_valor, v_hor_reversion, v_usu_reversion,'N');
          
          -- invocamos a la reversa
          prg_rev_operacion(v_fecha, 
                            v_hora, 
                            v_cod_usuario, 
                            v_cod_mod_padre, 
                            v_cod_mad_padre, 
                            v_cod_tra_padre,
                            v_usu_reversion, 
                            v_hor_reversion, 
                            'N',  'Reversado por proceso', c.nro_documento);
          UPDATE bw_mov_bts s
             SET s.estado = 'R'
           WHERE s.nro_documento = c.nro_documento
             AND s.estado = 'N';
          COMMIT;
       EXCEPTION
          WHEN OTHERS THEN
             v_error := v_error + 1;
             prg_rol_savepoint(c.nro_documento||'-'||c.nro_cta_debito);
             v_msj_error := substr(v_msj_error||c.nro_documento||'. ',1, 4000);
       END;
    END LOOP;
    
    IF v_error > 0 THEN
       raise_application_error(-21000, 'Total de errores: '||v_error||' de '||v_total||', documentos => '||v_msj_error);
    END IF;
  END;
   
  -- marcar transf. a reversada desde el scheduler de reintento
  FUNCTION fu_rev_transferencia(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) RETURN typ_mensajerespuesta IS
     v_nro_cta_debito bw_mov_bts.nro_cta_debito%TYPE;
     v_retorno        typ_mensajerespuesta  := typ_mensajerespuesta;
     v_fecha          ge_movimientos.fecha%TYPE;
     v_fec_valor      ge_movimientos.fec_valor%TYPE := pag_cal.fu_obt_fec_actual(9);
     v_hora           ge_movimientos.hora%TYPE;
     v_hor_reversion  ge_movimientos.hora%TYPE := to_char(SYSDATE, 'HH24:MI:SS');
     v_usu_reversion  ba_usuarios.cod_usuario%TYPE := USER;
     v_cod_usuario    ge_movimientos.cod_usuario%TYPE;
     v_cod_mod_padre  ge_movimientos.cod_mod_padre%TYPE;
     v_cod_mad_padre  ge_movimientos.cod_mad_padre%TYPE;
     v_cod_tra_padre  ge_movimientos.cod_tra_padre%TYPE;
     v_hor_cierre     cj_cajas.fec_hor_cierre%TYPE;
     v_cod_ofi_origen cj_cajas.cod_oficina%TYPE;
     v_error          typ_mensajerespuesta;
     --v_nro_doc_pendiente 
     v_horario         VARCHAR2(1);
     v_es_mov_noc      VARCHAR2(1);
     v_es_cta_noc      VARCHAR2(1);
     v_fec_actual      DATE;
     -- para reintento de reversa
     v_ins_reversion     VARCHAR2(1) := 'N';
     v_can_intentos      NUMBER := 0;
     v_men_respuesta     VARCHAR2(4000);
     v_temp              TIMESTAMP;
     C_CANT_INT_REV      NUMBER(1) := 3; -- Cantidad de Intentos para reversion
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error); 
    
    SELECT c.fec_hor_cierre, c.cod_oficina
      INTO v_hor_cierre, v_cod_ofi_origen
      FROM cj_cajas c
     WHERE c.nro_caja = '999';

    v_error := paw_uti.fu_ver_horario(v_horario, v_es_mov_noc, v_es_cta_noc, v_hor_cierre, v_cod_ofi_origen, v_fec_actual);
    IF v_error.error = 'S' THEN
       v_retorno.error := v_error.error;
       v_retorno.nombreRespuesta := v_error.nombreRespuesta;
       v_retorno.descripcionRespuesta := v_error.descripcionRespuesta;
       lp_act_est_mov(p_nro_documento, 'N');
       -- notificar a EP
       RETURN v_retorno;
    END IF;
    
    IF v_es_mov_noc = 'S' THEN
       lp_act_est_mov(p_nro_documento, 'N');
       -- notificar cliente
       RETURN v_retorno;
    END IF;
    
    -- verificar la operacion
    v_nro_cta_debito := lf_obt_cta_verificacion(p_nro_documento);
    
    -- se debe reversar, obtenemos los datos
    lp_obt_dat_reversa(v_nro_cta_debito, p_nro_documento,
                       v_fecha,
                       v_hora,
                       v_cod_usuario,
                       v_cod_mod_padre,
                       v_cod_mad_padre,
                       v_cod_tra_padre);
    
    v_hor_reversion := fug_obt_hor_disponible(v_fec_valor, v_hor_reversion, v_usu_reversion,'N');
    v_ins_reversion := 'N';
    v_can_intentos  := 0;
    WHILE v_ins_reversion = 'N' AND v_can_intentos <= C_CANT_INT_REV LOOP
       BEGIN
          prg_rev_operacion(v_fecha, 
                            v_hora, 
                            v_cod_usuario, 
                            v_cod_mod_padre, 
                            v_cod_mad_padre, 
                            v_cod_tra_padre,
                            v_usu_reversion, 
                            v_hor_reversion, 
                            'N', 
                            'Reversado por proceso automatico', 
                            p_nro_documento);
          v_ins_reversion := 'S';
       EXCEPTION
          WHEN OTHERS THEN
             ROLLBACK;
             v_temp          := pai_int.smg_sleep('0.5');
             v_hor_reversion := fug_obt_hor_disponible(v_fec_valor, v_hor_reversion, v_usu_reversion, 'N');
             v_ins_reversion := 'N';
             v_can_intentos  := v_can_intentos + 1;
             v_men_respuesta := substr(SQLERRM, 1, 4000);
       END;
    END LOOP;
    
    IF v_ins_reversion = 'N' THEN
      lp_act_est_mov(p_nro_documento, 'E');
      paw_uti.pr_insertarbitacora('11198', 999, p_nro_documento, '055',  NULL, 'Error reversar ' || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, 'Error: ' ||v_men_respuesta,  NULL), paw_uti.bitacora_error);
      RETURN v_retorno;
    END IF;
   
    -- marcamos como reversado
    lp_act_est_mov(p_nro_documento, 'R');
    
    -- dejar pendiente de vuelta un mov. de empresa si existe, para que solo se pueda volver a autorizar
    lp_rev_pediente(p_nro_documento);
    -- notificar cliente
    
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
       lp_act_est_mov(p_nro_documento, 'E');
       paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       paw_uti.pr_insertarbitacora('11198', 999, p_nro_documento, '055',  NULL, 'Error reversa ' || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, 'Error: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200),  NULL), paw_uti.bitacora_error);
       RETURN v_retorno;
  END;
  -- marcar transf. confirmada desde el scheduler de reintento
  FUNCTION fu_pro_transferencia(p_nro_documento IN bw_mov_bts.nro_documento%TYPE) RETURN typ_mensajerespuesta IS
     v_nro_cta_debito    bw_mov_bts.nro_cta_debito%TYPE;
     v_retorno           typ_mensajerespuesta  := typ_mensajerespuesta;
     v_nro_doc_pendiente bw_mov_bts.nro_doc_pendiente%TYPE;
  BEGIN
    paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error); 

    -- verificar la operacion
    v_nro_cta_debito := lf_obt_cta_verificacion(p_nro_documento);

    IF v_nro_cta_debito IS NOT NULL THEN
       -- accion de confirmar, se verifico que el movimiento se genero, solo marcamos como confirmado
       lp_act_est_mov(p_nro_documento, 'C');
       SELECT v.nro_doc_pendiente
         INTO v_nro_doc_pendiente
         FROM bw_mov_bts v
        WHERE v.nro_documento = p_nro_documento;
       -- regularizamos el estado de encolado a confirmado 
       IF v_nro_doc_pendiente IS NOT NULL THEN
           UPDATE bw_mov_pendientes p
              SET p.estado = 'C'
            WHERE p.nro_documento = v_nro_doc_pendiente
              AND p.cod_tip_mensaje = '055'
              AND p.estado = 'E';
       END IF;
    END IF;
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
       paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
       paw_uti.pr_insertarbitacora('11198', 999, p_nro_documento, '055',  NULL, 'Error confirmar ' || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, 'Error: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200),  NULL), paw_uti.bitacora_error);
       RETURN v_retorno;
  END;
  -- para recibo snp desde gnbpy
  FUNCTION fu_snp_recibido(p_nro_referencia  IN ge_movimientos.nro_documento%TYPE,
                           p_nro_cta_credito IN ge_movimientos.nro_cuenta%TYPE,
                           p_importe         IN ge_movimientos.monto%TYPE,
                           p_nro_ref_bcp     IN VARCHAR2 DEFAULT NULL) 
                           RETURN typ_mensajeRespuesta IS
     v_retorno         typ_mensajeRespuesta := typ_mensajeRespuesta();
     v_error           typ_mensajeRespuesta;
     v_nocturno        varchar2(1) := 'N';
     v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE := 0;
     -- v_mensajecaja     typ_mensajecaja;
     v_fec_actual      ge_movimientos.fec_valor%TYPE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
     v_hor_actual      ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss'); -- hora actual
     r_gmovi           ge_movimientos%ROWTYPE := NULL;
     v_mto_equ_local   ge_movimientos.mto_equ_local%TYPE;   
     v_cod_modulo      ge_modalidades.cod_modulo%TYPE;
     v_cod_modalidad   ge_modalidades.cod_modalidad%TYPE;
     v_cod_moneda      ge_cuentas.cod_moneda%TYPE;
     v_cotizacion      ge_movimientos.cotizacion%TYPE;
     v_nro_cta_credito ge_cuentas.nro_cuenta%TYPE;
     v_val_cuenta      typ_mapa;
  BEGIN
     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error); 
     
     v_nro_cta_credito := lf_cta_verificada(p_nro_cta_credito);
     SELECT c.cod_modulo, c.cod_modalidad, c.cod_moneda, c.nro_cuenta
      INTO v_cod_modulo, v_cod_modalidad, v_cod_moneda, v_nro_cta_credito
      FROM ge_cuentas c
     WHERE c.nro_cuenta = v_nro_cta_credito;
     
     v_val_cuenta := fu_val_cta_credito(v_nro_cta_credito, NULL, p_importe);
     IF v_val_cuenta.error = 'S' THEN
        v_retorno.error := v_val_cuenta.error;
        v_retorno.nombreRespuesta := v_val_cuenta.nombreRespuesta;
        v_retorno.descripcionRespuesta := v_val_cuenta.descripcionRespuesta;
        RETURN v_retorno;
     END IF;
     -- validar monto de credito
     IF nvl(p_importe, 0) <= 0 THEN
        paw_uti.pr_mensajeUsuario('MTO_INVALIDO', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        RETURN v_retorno;
     END IF;
     -- Si es diferente a Local, obtenemos cotizacion para movimiento
     if v_cod_moneda != pag_gen.fu_obt_mon_local then
        v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
        v_mto_equ_local := round(p_importe * v_cotizacion, 0);
     else
        v_cotizacion := null;
        v_mto_equ_local:= null;
     end if;
     v_error := lf_ver_ref_duplicada(602, 309, v_nro_cta_credito, p_nro_referencia);
     IF v_error.error = 'S' THEN
        v_retorno.error := v_error.error;
        v_retorno.nombreRespuesta := v_error.nombreRespuesta;
        v_retorno.descripcionRespuesta := v_error.descripcionRespuesta;
        RETURN v_retorno;
     END IF;
     --Insertamos Movimiento DÉBITO en Cuenta puente
     -- --------------
     -- Aumento la secuencia
     v_nro_secuencia         := v_nro_secuencia + 1;
     v_hor_actual            := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, USER, v_nocturno);

     r_gmovi.cod_modulo      := v_cod_modulo;
     r_gmovi.cod_modalidad   := v_cod_modalidad;
     r_gmovi.cod_oficina     := 31;
     r_gmovi.nro_cuenta      := NULL;
     r_gmovi.cod_transaccion := 77;
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.tip_mov_rubro   := NULL;
     r_gmovi.cod_moneda      := v_cod_moneda;
     r_gmovi.cod_usuario     := USER;
     r_gmovi.hora            := v_hor_actual;
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.nro_secuencia   := v_nro_secuencia;
     r_gmovi.fec_valor       := v_fec_actual;
     r_gmovi.cod_tra_padre   := 309;
     r_gmovi.cod_mod_padre   := v_cod_modulo;
     r_gmovi.cod_mad_padre   := v_cod_modalidad;
     r_gmovi.monto           := p_importe;
     r_gmovi.nro_documento   := p_nro_referencia;
     r_gmovi.cotizacion      := v_cotizacion;
     r_gmovi.mto_equ_local   := v_mto_equ_local;
     r_gmovi.cod_ofi_origen  := 31;
     r_gmovi.emi_aviso       := 'N';
     r_gmovi.concepto        := substr('Transf.GNB/GNB Fusión: '||nvl(p_nro_ref_bcp, p_nro_referencia), 1, 100);
     r_gmovi.estado          := 'N';
     r_gmovi.reversado       := 'N';
     r_gmovi.cod_rubro       := NULL;
     -- insertamos  el mov. rubro  contable
     pag_gen.pr_ins_ge_movimiento(r_gmovi, v_nocturno);
     
     IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
         raise_application_error(-20000,'Error -Deb.Cta.Puente: '||pag_cta.g_cod_error||' - '||pag_cta.G_MSJ_ERROR);
      end if;
  
     -- credito en cuenta GNB Fusión
      -- v_nro_secuencia         := v_nro_secuencia + 1;
     pag_cta.pr_act_operacion(
         v_nro_cta_credito, --cuenta credito
         v_hor_actual,
         'C',
         v_cod_moneda, --moneda
         p_importe,       --importe
         309, --
         602, --transaccion
         p_nro_referencia, --nro de ttr o referencia
         v_cotizacion,  -- ver cotizacion si es en moneda extranjera
         31, --siempre asumimos 31
         v_cod_modulo, --modulo de la cuenta
         v_cod_modalidad, --modalidad de la cuenta
         NULL,
         NULL,
         'Transf.GNB/GNB Fusión: '||nvl(p_nro_ref_bcp, p_nro_referencia),
         'N',
         v_nro_secuencia, --Secuencia
         v_fec_actual,    --fecha
         NULL,
         NULL,
         v_mto_equ_local); --mto equivalente

      IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
         raise_application_error(-20000,'Error -Cre.Cta.Cli: '||pag_cta.g_cod_error||' - '||pag_cta.G_MSJ_ERROR);
      END IF;
     RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarbitacora('11198', 999, p_nro_referencia, '055',  NULL, 'fu_snp_recibido: ' || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, 'Error: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200),  NULL), paw_uti.bitacora_error);
        RETURN v_retorno;
  END;
  
  -- para envio de snp a gnbpy
  FUNCTION fu_snp_envio(p_nro_referencia  IN ge_movimientos.nro_documento%TYPE,
                        p_nro_cta_ope     IN ge_cuentas.nro_cuenta%TYPE,
                        p_importe         IN ge_movimientos.monto%TYPE,
                        p_nro_ref_bcp     IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajeRespuesta IS
    v_retorno         typ_mensajeRespuesta := typ_mensajeRespuesta();
    v_error           typ_mensajeRespuesta;
    v_nocturno        VARCHAR2(1) := 'N';
    v_nro_secuencia   ge_movimientos.nro_secuencia%TYPE := 0;
    v_fec_actual      ge_movimientos.fec_valor%TYPE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
    v_hor_actual      ge_movimientos.hora%TYPE := to_char(SYSDATE, 'hh24:mi:ss'); -- hora actual
    r_gmovi           ge_movimientos%ROWTYPE := NULL;
    v_mto_equ_local   ge_movimientos.mto_equ_local%TYPE := NULL;
    v_cod_modulo      ge_cuentas.cod_modulo%TYPE; 
    v_cod_modalidad   ge_cuentas.cod_modalidad%TYPE;
    v_cotizacion      ge_movimientos.cotizacion%TYPE;
    v_cta_ope         ge_movimientos.nro_cuenta%TYPE;
    v_mon_ope         ge_movimientos.cod_moneda%TYPE;
    v_mto_ope         ge_movimientos.monto%TYPE;
    v_cta_credito     VARCHAR2(20);
    v_nro_doc_credito VARCHAR2(20);
    v_res             VARCHAR2(1);          
  BEGIN
     paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error); 
        
      SELECT w.mon_cta_cli_itbt, w.imp_cre, w.cotizacion, w.nro_cuenta, w.nro_documento
       INTO v_mon_ope, v_mto_ope, v_cotizacion, v_cta_credito, v_nro_doc_credito
       FROM GE_VAL_CTA_GNB w
      WHERE w.fecha = v_fec_actual  
        AND w.nro_ref_bt = p_nro_referencia;  
    
      v_cta_ope:= p_nro_cta_ope;  
     
     SELECT c.cod_modulo, c.cod_modalidad
       INTO v_cod_modulo, v_cod_modalidad
       FROM ge_cuentas c
      WHERE c.nro_cuenta = p_nro_cta_ope;
                  
     IF v_mto_ope <> p_importe THEN
        raise_application_error(-20000,'Error - Monto no Corresponde');
     END IF;
     IF nvl(v_cotizacion,0) > 0 THEN
        v_mto_equ_local := round(p_importe * v_cotizacion, 0);         
     END IF;
     --Si es en otra moneda, se agrega Mto_equ_local
     IF v_mon_ope <> pag_gen.fu_obt_mon_local AND v_mto_equ_local IS NULL THEN  
        v_cotizacion := pag_gen.fu_obt_cotizacion(v_mon_ope, v_fec_actual);
        v_mto_equ_local := round(p_importe * v_cotizacion, 0);
     END IF;
     v_error := lf_ver_ref_duplicada(503, 309, v_cta_ope, p_nro_referencia);
     IF v_error.error = 'S' THEN
        v_retorno.error := v_error.error;
        v_retorno.nombreRespuesta := v_error.nombreRespuesta;
        v_retorno.descripcionRespuesta := v_error.descripcionRespuesta;
        RETURN v_retorno;
     END IF;
     v_hor_actual := fug_obt_hor_disponible(v_fec_actual, v_hor_actual, USER, v_nocturno);
     --Débito en Cta Operativa***********************
     pag_cta.pr_act_operacion(
         v_cta_ope, --cuenta Debito
         v_hor_actual,
         'D',
         v_mon_ope,
         p_importe, 
         309,
         503, --transaccion
         p_nro_referencia, --nro de ttr o referencia
         v_cotizacion,  -- ver cotizacion si es en moneda extranjera
         31, --siempre asumimos 31
         v_cod_modulo, --modulo de la cuenta
         v_cod_modalidad, --modalidad de la cuenta
         NULL,
         NULL,
         'Transf.GNB Fusión/GNB: '||nvl(p_nro_ref_bcp, p_nro_referencia),
         'N',
         v_nro_secuencia, --Secuencia
         v_fec_actual,    --fecha
         NULL,
         NULL,
         v_mto_equ_local); --mto equivalente
          
     IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
        raise_application_error(-20000,'Error -Deb.Cta.Cli: '||pag_cta.g_cod_error||' - '||pag_cta.G_MSJ_ERROR);
     END IF;
       
     -- Crédito en Puente --------------
     -- Aumento la secuencia
     v_nro_secuencia         := v_nro_secuencia + 1;
     r_gmovi.cod_modulo      := v_cod_modulo;
     r_gmovi.cod_modalidad   := v_cod_modalidad;
     r_gmovi.cod_oficina     := 31;
     r_gmovi.nro_cuenta      := NULL;
     r_gmovi.cod_transaccion := 76; 
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.tip_mov_rubro   := NULL;--'C';
     r_gmovi.cod_moneda      := v_mon_ope;
     r_gmovi.cod_usuario     := USER;
     r_gmovi.hora            := v_hor_actual;
     r_gmovi.fecha           := v_fec_actual;
     r_gmovi.nro_secuencia   := v_nro_secuencia;
     r_gmovi.fec_valor       := v_fec_actual;
     r_gmovi.cod_tra_padre   := 309;
     r_gmovi.cod_mod_padre   := v_cod_modulo;
     r_gmovi.cod_mad_padre   := v_cod_modalidad;
     r_gmovi.monto           := p_importe;
     r_gmovi.nro_documento   := p_nro_referencia;
     r_gmovi.cotizacion      := v_cotizacion;
     r_gmovi.mto_equ_local   := v_mto_equ_local;
     r_gmovi.cod_ofi_origen  := 31;
     r_gmovi.emi_aviso       := 'N';
     r_gmovi.concepto        := substr('Transf.GNB Fusión/GNB: '||nvl(p_nro_ref_bcp, p_nro_referencia) , 1, 100);
     r_gmovi.estado          := 'N';
     r_gmovi.reversado       := 'N';
     r_gmovi.cod_rubro       := NULL;
     -- insertamos  el mov. rubro  contable
     pag_gen.pr_ins_ge_movimiento(r_gmovi, v_nocturno);
     IF nvl(pag_cta.g_cod_error, 0) <> 0 THEN
        raise_application_error(-20000,'Error -Deb.Cta.Cli: '||pag_cta.g_cod_error||' - '||pag_cta.G_MSJ_ERROR);
     END IF;
     
     v_res := fuw_env_snp_gnb(p_nro_transaccion => p_nro_referencia,
                             p_nro_cuenta => v_cta_credito,
                             p_nro_documento => v_nro_doc_credito,
                             p_monto => p_importe);
     IF v_res <> 'S' THEN
       raise_application_error(-20000, 'No se pudo enviar pago '||p_nro_referencia);
     END IF;
     
     COMMIT;
     RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        ROLLBACK;
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
        paw_uti.pr_insertarbitacora('11198', 999, p_nro_referencia, '055',  NULL, 'fu_snp_envio: ' || paw_uti.fu_generarbitacora(v_retorno.error, v_retorno.nombrerespuesta, 'Error: ' || SQLCODE || ' => ' ||  substr(SQLERRM, 1, 200),  NULL), paw_uti.bitacora_error);
        RETURN v_retorno;  
  END;
  
  --- Unificación Código BIC SWIFT
  PROCEDURE pr_val_cta_mensajes
   (  p_nro_cuenta IN VARCHAR2,
      p_modo       IN NUMBER,
      p_respuesta  OUT VARCHAR2,
      p_error      OUT VARCHAR2
   ) IS
      v_cod_modalidad ge_modalidades.cod_modalidad%TYPE;
  BEGIN
     IF p_modo = 103 THEN
        BEGIN
           SELECT cod_modalidad
             INTO v_cod_modalidad
             FROM ge_cuentas
            WHERE to_number(nro_cuenta) = to_number(p_nro_cuenta); --- por si tenga ceros
        EXCEPTION
           WHEN no_data_found THEN
              v_cod_modalidad := NULL;
           WHEN OTHERS THEN
              p_respuesta := 'fail';
              p_error     := SQLERRM;
              RETURN;
        END;
        IF v_cod_modalidad IS NULL THEN
           p_respuesta := 'fail';
           p_error     := 'Sin Datos para Cuenta ' || p_nro_cuenta;
           RETURN;
        ELSIF v_cod_modalidad NOT IN (31, 41) THEN
           p_respuesta := 'fail';
           p_error     := 'No es Cuenta valida para transferencia';
           RETURN;
        END IF;
     ELSIF p_modo IN (940, 950) THEN
        BEGIN
           SELECT a.cod_modalidad
             INTO v_cod_modalidad
             FROM cc_cta_bancarias a
            WHERE a.nro_cta_bancaria = p_nro_cuenta;
        EXCEPTION
           WHEN no_data_found THEN
              p_respuesta := 'fail';
              p_error     := 'Sin Datos para Cuenta Bancaria ' || p_nro_cuenta;
              RETURN;
           WHEN OTHERS THEN
              p_respuesta := 'fail';
              p_error     := SQLERRM;
              RETURN;
        END;
     ELSE
        p_respuesta := 'fail';
        p_error     := 'Tipo de MT no soportado';
        RETURN;
     END IF;
     p_respuesta := 'ok';
  END;

BEGIN  
   pre_cam_for_numerico('.,');
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 9; --Modulo caja
END PAW_BTS;
/

