CREATE OR REPLACE PACKAGE BODY IT.PAG_IPS IS
   p_cierre VARCHAR2(1); --averiguar donde se actualiza esta variable.
   /* BSEVOCORE-426 NAF 03/2020 
   variables pare envio de emails de notificaciones
   */
   v_dir_para              varchar2(400);
   v_dir_de                varchar2(400);
   v_dir_err               varchar2(400);
   v_pk_error              varchar2(1000);
   
   /**
   Estructura interna para verificar el estado de la caja
   */
   TYPE typ_mensajeCaja IS RECORD(
      error                VARCHAR2(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      estadoCaja           VARCHAR2(1),
      tipoCaja             VARCHAR2(1),
      codigoOficinaOrigen  NUMBER(3),
      codigoUsuario        VARCHAR2(10),
      fechaUltimoCierre    DATE);

   /** Inserta registro en la tabla GE_PAG_SUE_IPS_LOG
   * @param p_cod_ge_pag_sue_ips PK del registro de lote de pago (cabecera)
   * @param p_cod_pag_sue_ips_det PK del registro de pago (detalle)
   * @param p_mensaje Evento a registrar en la Bitácora.
   */
   PROCEDURE PR_INS_BITACORA(p_cod_ge_pag_sue_ips     IN GE_PAG_SUE_IPS_LOG.nro_lote%TYPE DEFAULT NULL,
                             p_cod_ge_pag_sue_ips_det IN GE_PAG_SUE_IPS_LOG.nro_orden%TYPE DEFAULT NULL,
                             p_mensaje                IN VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      v_linea    VARCHAR2(1000);
      v_paquete  VARCHAR2(1000);
      v_llamador VARCHAR2(1000);
      v_duenho   VARCHAR2(1000);
   BEGIN
      OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
   
      INSERT INTO GE_PAG_SUE_IPS_LOG
         (FECHA, nro_lote, nro_orden, MENSAJE)
      VALUES
         (SYSDATE, p_cod_ge_pag_sue_ips, p_cod_ge_pag_sue_ips_det, v_paquete || '.' || v_linea || ': ' || p_mensaje);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END pr_ins_bitacora;

   /*
   Procedimiento para actualizar los comentarios y estado de los pagos posterior a la validación.
   */
   PROCEDURE LP_ACT_LOTE(p_lote     typ_lotepagosueldoips,
                         p_act_tipo BOOLEAN) IS
   BEGIN
      --si se debe actualizar el Tipo de Operación V -> P
      IF p_act_tipo THEN
         UPDATE ge_pag_sue_ips c
            SET c.comentarios = p_lote.comentarios,
                c.estado      = p_lote.estado,
                c.tip_proceso = p_lote.tipoProceso --se agenda el lote para acreditación.
          WHERE c.nro_lote = p_lote.nroLote;
      ELSE
         UPDATE ge_pag_sue_ips c
            SET c.comentarios = p_lote.comentarios,
                c.estado      = p_lote.estado
          WHERE c.nro_lote = p_lote.nroLote;
      
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         pr_ins_bitacora(p_lote.nroLote, NULL, 'LP_ACT_LOTE: No se pudo actualizar el lote con ID: ' || p_lote.nroLote || '. Error: ' || SQLERRM);
      
   END LP_ACT_LOTE;

   /*
   Procedimiento para actualizar los comentarios y estado de los pagos posterior a la validación.
   */
   PROCEDURE LP_ACT_PAGO(p_pago      typ_pagosueldoips,
                         p_acreditar BOOLEAN DEFAULT FALSE) IS
   
   BEGIN
      IF p_acreditar THEN
         UPDATE ge_pag_sue_ips_det d
            SET d.comentarios      = p_pago.comentarios,
                d.estado           = p_pago.estado,
                d.fec_acreditacion = p_pago.fechaAcreditacion
          WHERE d.nro_orden = p_pago.nroOrden
                AND d.nro_lote = p_pago.nroLote;
      ELSE
         UPDATE ge_pag_sue_ips_det d
            SET d.comentarios = p_pago.comentarios,
                d.estado      = p_pago.estado
          WHERE d.nro_orden = p_pago.nroOrden
                AND d.nro_lote = p_pago.nroLote;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         pr_ins_bitacora(p_pago.nroLote, p_pago.nroOrden, 'PR_ACT_PAGO: No se pudo actualizar el registro de pago con ID: ' || p_pago.nroOrden || '. Error: ' || SQLERRM);
      
   END LP_ACT_PAGO;

   /**
   * Función que verifica el estado de los modulos para saber el tipo de horario Normal o Nocturno.
   * @param p_fecUltCierre Fecha del ultimo cierre
   * @param p_codOficina Codigo de Oficina.
   * @param p_horario Si es día Normal o Nocturno.
   * @param p_es_mov_noc Para saber si es movimiento en la tabla nocturan ->
   * @param p_es_cta_noc Para bloquear la cuenta nocturna -> salida
   * @param p_fec_actual Fecha actual -> salida
   * return typ_MensajeRespuesta
   */
   FUNCTION LP_VER_HORARIO(p_fecUltCierre IN DATE,
                           p_codOficina   IN NUMBER,
                           p_horario      OUT VARCHAR2,
                           p_es_mov_noc   OUT VARCHAR2,
                           p_es_cta_noc   OUT VARCHAR2,
                           p_fec_actual   OUT DATE) RETURN typ_MensajeRespuesta IS
   
      v_cod_ofi_origen NUMBER;
      v_est_modulo     ba_modulos.estado%TYPE;
      v_retorno        typ_MensajeRespuesta := typ_MensajeRespuesta;
   BEGIN
      paw_uti.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
   
      v_retorno.error := 'N';
      p_horario       := 'D'; -- Dia normal
      p_es_mov_noc    := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc    := 'N';
      p_fec_actual    := pag_cal.FU_OBT_FEC_ACTUAL(3);
      v_est_modulo    := pae_cnf.FU_OBT_EST_MODULO(3);
   
      IF v_est_modulo IN (1, 6) THEN
         pr_ins_bitacora(NULL, NULL, 'lp_ver_horario: Sistema en cierre. No se puede operar');
      
         v_retorno.error                := 'S';
         v_retorno.nombreRespuesta      := 'EN_CIERRE';
         v_retorno.descripcionRespuesta := 'Sistema en Cierre. Reintentar de vuelta.';
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto
         -- Verifica la hora --
         IF SYSDATE > p_fecUltCierre AND trunc(p_fecUltCierre) = p_fec_actual THEN
            p_horario    := 'T'; -- Tarde
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_codOficina);
            p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         END IF;
      ELSE
         p_horario := 'N'; -- Noche
         IF v_est_modulo <> 1 THEN
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, v_cod_ofi_origen);
         END IF;
         p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         p_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
   
      pag_cta.g_horario := p_horario;
      RETURN v_retorno;
   END LP_VER_HORARIO;

   /**
   * Funcion que valida la cuenta de débito
   */
   FUNCTION LF_VAL_CTA_DEBITO(p_lote             IN ge_pag_sue_ips.nro_lote%TYPE,
                              p_nro_cta_debito   IN VARCHAR2,
                              p_cod_tra_padre    IN NUMBER,
                              p_monto            IN NUMBER,
                              p_codOficinaOrigen IN NUMBER,
                              p_cod_mon_debito   OUT VARCHAR2,
                              p_cod_mod_debito   OUT NUMBER,
                              p_cod_mad_debito   OUT NUMBER,
                              p_cod_ofi_debito   OUT NUMBER,
                              p_cta_for_debito   OUT VARCHAR2) RETURN typ_mensajeRespuesta IS
   
      v_est_cta_debito  VARCHAR2(1);
      v_nvo_estado      VARCHAR2(1) := NULL; -- cambio de estado de cuenta
      v_procesa         VARCHAR2(1) := 'N';
      v_sal_disponible  NUMBER(18, 2);
      v_retorno         typ_mensajeRespuesta := typ_mensajeRespuesta;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE := 503;
   BEGIN
   
      paw_uti.pr_mensajeUsuario('OP_APROBADA', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
   
      SELECT a.cod_moneda, a.estado, cod_modalidad, cod_modulo, cod_oficina, fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, a.nro_cuenta, cod_moneda) cta_formateada
        INTO p_cod_mon_debito, v_est_cta_debito, p_cod_mad_debito, p_cod_mod_debito, p_cod_ofi_debito, p_cta_for_debito
        FROM ge_cuentas a
       WHERE a.nro_cuenta = p_nro_cta_debito; -- contiene el nro de cuenta debito
   
      pag_cta.PR_OBT_CUENTA(p_nro_cta_debito);
   
      v_est_cta_debito := pag_cta.FU_OBT_EST_CUENTA;
      --monto inválido
      IF p_monto <= 0 THEN
         v_retorno.error                := 'S';
         v_retorno.descripcionRespuesta := 'monto<= 0';
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: Monto inválido: ' || p_monto);
         --modalidad inválida
      ELSIF p_cod_mad_debito NOT IN (31, 41) THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
         --estados inválidos
      ELSIF v_est_cta_debito NOT IN ('P', 'I', 'N', 'S') THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
      ELSIF pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito, p_cod_tra_padre, 9,
                                         --p_cod_mod_debito
                                         91
                                         --p_cod_mad_debito
                                         ) = 'S' THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_TRA_PROHIBIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_TRA_PROHIBIDA || '. ' || v_retorno.descripcionRespuesta);
      ELSE
         pag_cta.pr_ver_operacion(p_nro_cta_debito, p_cod_tra_padre, 9,
                                  --p_cod_mod_debito
                                  91,
                                  --p_cod_mad_debito
                                  'D', p_cod_mon_debito, p_monto, p_codOficinaOrigen, p_cod_mod_debito, p_cod_mad_debito,
                                  --
                                  v_nvo_estado, v_sal_disponible, v_procesa, v_cod_transaccion);
         IF v_procesa = 'N' THEN
            -- no se puede debitar
            IF instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
               -- saldo insuficiente
               PAW_UTI.pr_mensajeUsuario(MSG_COD_SAL_INSUF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_SAL_INSUF || '. ' || v_retorno.descripcionRespuesta);
            ELSE
               PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
            END IF;
         END IF;
      END IF;
   
      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_CTA_INEXISTENTE || '. ' || v_retorno.descripcionRespuesta);
         RETURN v_retorno;
      WHEN too_many_rows THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_DUPLICADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_CTA_DUPLICADA || '. ' || v_retorno.descripcionRespuesta);
         RETURN v_retorno;
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_debito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
         RETURN v_retorno;
   END;

   /**
   ****  Procedimientos de Control de Datos Recibidos --> Caja ***
   * @Fecha : 30-01-2019
   */
   FUNCTION LF_VAL_CAJA(p_lote IN ge_pag_sue_ips.nro_lote%TYPE,
                        p_caja IN NUMBER) RETURN typ_mensajeCaja IS
      -- Verifico la situacion del numero de caja
      v_est_caja       cj_cajas.estado%TYPE;
      v_tip_caja       cj_cajas.tipo%TYPE;
      v_cod_ofi_origen cj_cajas.cod_oficina%TYPE;
      v_cod_usuario    cj_cajas.cod_usuario%TYPE;
      v_ult_cierre     cj_cajas.fec_hor_cierre%TYPE;
      v_retorno        typ_mensajeCaja;
   BEGIN
      SELECT estado, tipo, cod_oficina, cod_usuario, fec_hor_cierre
        INTO v_est_caja, v_tip_caja, v_cod_ofi_origen, v_cod_usuario, v_ult_cierre
        FROM cj_cajas
       WHERE nro_caja = p_caja;
   
      IF v_tip_caja NOT IN ('C', 'I', 'S') THEN
         -- tipo de caja no permitido
         v_retorno.error                := 'S';
         v_retorno.descripcionRespuesta := 'lf_val_caja: Tipo de Caja no permitido.';
      
         pr_ins_bitacora(p_lote, NULL, 'lf_val_caja: Tipo de Caja no permitido.');
      END IF;
   
      IF v_est_caja <> 'A' THEN
         v_retorno.error                := 'S';
         v_retorno.descripcionRespuesta := 'lf_val_caja: Caja inválida, no se puede operar.';
      
         pr_ins_bitacora(p_lote, NULL, 'lf_val_caja: Caja inválida, no se puede operar.');
      END IF;
   
      v_retorno.estadoCaja          := v_est_caja;
      v_retorno.tipoCaja            := v_tip_caja;
      v_retorno.codigoOficinaOrigen := v_cod_ofi_origen;
      v_retorno.codigoUsuario       := v_cod_usuario;
      v_retorno.fechaUltimoCierre   := v_ult_cierre;
   
      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         v_retorno.error                := 'S';
         v_retorno.descripcionRespuesta := 'lf_val_caja: Caja no encontrada';
      
         pr_ins_bitacora(p_lote, NULL, 'lf_val_caja: Caja no encontrada');
         RETURN v_retorno;
   END;

   /**
   * Funcion que valida la cuenta de crédito
   */
   FUNCTION LF_VAL_CTA_CREDITO(p_lote              IN ge_pag_sue_ips.nro_lote%TYPE,
                               p_nro_cta_credito   IN VARCHAR2,
                               p_cod_tra_padre     IN NUMBER,
                               p_monto             IN NUMBER,
                               p_codOficinaOrigen  IN NUMBER,
                               p_cod_mon_credito   OUT VARCHAR2,
                               p_cod_mod_credito   OUT NUMBER,
                               p_cod_mad_credito   OUT NUMBER,
                               p_cod_ofi_credito   OUT NUMBER,
                               p_cta_for_credito   OUT VARCHAR2,
                               p_est_cta_credito   OUT VARCHAR2,
                               pio_nvo_est_credito IN OUT VARCHAR2,
                               pio_sal_dis_credito IN OUT NUMBER)
   
    RETURN typ_mensajeRespuesta IS
   
      v_procesa         VARCHAR2(1) := 'N';
      v_retorno         typ_mensajeRespuesta := typ_mensajeRespuesta;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE := 602;
   BEGIN
   
      paw_uti.pr_mensajeUsuario('OP_APROBADA', v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
   
      SELECT a.cod_moneda, a.estado, cod_modalidad, cod_modulo, cod_oficina, fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda) cta_formateada
        INTO p_cod_mon_credito, p_est_cta_credito, p_cod_mad_credito, p_cod_mod_credito, p_cod_ofi_credito, p_cta_for_credito
        FROM ge_cuentas a
       WHERE a.nro_cuenta = p_nro_cta_credito; -- contiene el nro de cuenta
   
      --monto inválido
      IF p_monto <= 0 THEN
         v_retorno.error                := 'S';
         v_retorno.descripcionRespuesta := 'monto<= 0';
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: Monto inválido: ' || p_monto);
      ELSIF p_cod_mad_credito NOT IN (31, 41) THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
      
      ELSIF p_est_cta_credito NOT IN ('A', 'I', 'N', 'S') THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
      
      ELSIF pag_cta.fu_ver_tra_prohibida(p_nro_cta_credito, p_cod_tra_padre, 9, 91) = 'S' THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_TRA_PROHIBIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: ' || MSG_COD_TRA_PROHIBIDA || '. ' || v_retorno.descripcionRespuesta);
      
      ELSE
         pag_cta.pr_ver_operacion(p_nro_cta_credito, p_cod_tra_padre, 9, 91, 'C', p_cod_mon_credito,
                                  --
                                  p_monto, p_codOficinaOrigen, p_cod_mod_credito, p_cod_mad_credito, pio_nvo_est_credito,
                                  --
                                  pio_sal_dis_credito, v_procesa, v_cod_transaccion);
      
         IF v_procesa = 'N' THEN
            PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
         END IF;
      END IF;
   
      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: ' || MSG_COD_CTA_INEXISTENTE || '. ' || v_retorno.descripcionRespuesta);
         RETURN v_retorno;
      WHEN too_many_rows THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_DUPLICADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: ' || MSG_COD_CTA_DUPLICADA || '. ' || v_retorno.descripcionRespuesta);
         RETURN v_retorno;
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_ins_bitacora(p_lote, NULL, 'lf_val_cta_credito: ' || MSG_COD_CTA_INVALIDA || '. ' || v_retorno.descripcionRespuesta);
         RETURN v_retorno;
   END;

   /**
   ****  Funcion que controla la Cuenta Origen corresponda a la persona ***
   * @Fecha : 30-01-2019
   */
   FUNCTION LF_VAL_CTA_ORIGEN(p_nro_cuenta  IN VARCHAR2,
                              p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
      v_sino VARCHAR(1) := 'N';
   BEGIN
      SELECT 'S'
        INTO v_sino
        FROM ge_cta_clientes
       WHERE nro_cuenta = p_nro_cuenta
             AND cod_persona = p_cod_persona
             AND rownum = 1;
      RETURN v_sino;
   EXCEPTION
      WHEN OTHERS THEN
         v_sino := 'N';
         RETURN v_sino;
   END;

   /**
   * Valida si una cuenta pertenece a un documento dado
   * @Fecha : 30-01-2019
   */
   FUNCTION LF_CTA_VALIDA(p_nro_cuenta    IN VARCHAR2,
                          p_nro_documento IN VARCHAR2) RETURN VARCHAR2 IS
      v_retorno       VARCHAR2(2) := '';
      v_tip_persona   VARCHAR2(1);
      v_cod_persona   ba_personas.cod_persona%TYPE;
      v_nro_cuenta    ge_cuentas.nro_cuenta%TYPE;
      v_nro_documento VARCHAR2(20) := p_nro_documento;
   BEGIN
      BEGIN
         SELECT cod_persona
           INTO v_cod_persona
           FROM ba_personas
          WHERE nro_documento = v_nro_documento;
      EXCEPTION
         WHEN no_Data_found THEN
            v_retorno := '1'; --no existe Nro. Documento
            RETURN v_retorno;
         WHEN OTHERS THEN
            v_retorno := '-1';
            RETURN v_retorno;
      END;
   
      BEGIN
         SELECT nro_cuenta
           INTO v_nro_cuenta
           FROM ge_cuentas
          WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN no_Data_found THEN
            v_retorno := '2'; --no existe Nro. Cuenta
            RETURN v_retorno;
         WHEN OTHERS THEN
            v_retorno := '-2';
            RETURN v_retorno;
      END;
   
      BEGIN
         SELECT tipo, a.cod_persona
           INTO v_tip_persona, v_cod_persona
           FROM ba_personas b, ge_cta_clientes a
          WHERE a.nro_cuenta = p_nro_cuenta
                AND a.relacion = 'P'
                AND a.cod_persona = b.cod_persona;
      
         IF v_tip_persona = 'J' THEN
            -- empresa
            -- busqueda por principal para ver si es el documento de la empresa
            SELECT '0'
              INTO v_retorno
              FROM ba_personas a
             WHERE a.cod_persona = v_cod_persona
                   AND a.nro_documento = v_nro_documento;
                   
             return v_retorno;
         ELSE
            -- la cuenta es de una persona fisica
            SELECT '0'
              INTO v_retorno
              FROM ba_personas b
             WHERE b.nro_documento = v_nro_documento
                   AND b.cod_persona IN (SELECT x.cod_persona
                                           FROM ge_cta_clientes x
                                          WHERE x.nro_cuenta = p_nro_cuenta
                                                AND x.cod_persona = b.cod_persona)
                   AND rownum = 1; -- primero que encuentre
         
         	return v_retorno;
         END IF;
      EXCEPTION
         WHEN no_Data_found THEN
            v_retorno := '3'; --Nro. Cta. no asociada a Nro. de Documento
            RETURN v_retorno;
         WHEN OTHERS THEN
            v_retorno := '-3';
            RETURN v_retorno;
      END;
   EXCEPTION
      WHEN OTHERS THEN
         v_retorno := '-4';
         RETURN v_retorno;
   END;

   -- funcion que obtiene la transaccion padre de acuerdo al tipo de transaccion
   FUNCTION LF_OBT_TRA_SUELDO(p_cod_ente         IN ge_entes.cod_ente%TYPE,
                              p_tip_remuneracion IN ge_pag_sueldos_tmp.tip_remuneracion%TYPE) RETURN NUMBER IS
      v_cod_tra_padre ge_transacciones.cod_transaccion%TYPE := NULL;
   BEGIN
      IF p_tip_remuneracion = 'S' THEN
         v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_SUELDO');
      ELSIF p_tip_remuneracion = 'A' THEN
         v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_AGUINALDO');
      ELSIF p_tip_remuneracion = 'C' THEN
         v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_COMISION');
      ELSIF p_tip_remuneracion = 'T' THEN
         v_cod_tra_padre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_CREDITO');
      END IF;
      RETURN v_cod_tra_padre;
   END;

   /**
   * Función que calcula el nro. de secuencia para los registros en GE_PAG_SUELDOS,
   * en base a los anteriores lotes registrados en ge_pag_sueldos y ge_pag_sueldos_err.
   */
   FUNCTION LF_OBT_NRO_SECUENCIA(p_cod_ente   IN ge_pag_sueldos.cod_ente%TYPE,
                                 p_fec_actual IN ge_pag_sueldos.fec_envio%TYPE) RETURN NUMBER IS
      v_nro_archivo     NUMBER := 1;
      v_aux_nro_archivo NUMBER := 1;
   BEGIN
      BEGIN
         -- obtenemos la maxima secuencia del pago
         SELECT DISTINCT nvl(MAX(gs.nro_secuencia), 0) + 1
           INTO v_aux_nro_archivo
           FROM ge_pag_sueldos gs
          WHERE gs.cod_ente = p_cod_ente
                AND gs.fec_proceso = p_fec_actual;
      EXCEPTION
         WHEN OTHERS THEN
            v_aux_nro_archivo := 1;
      END;
      --
      IF v_aux_nro_archivo > v_nro_archivo THEN
         v_nro_archivo := v_aux_nro_archivo;
      END IF;
   
      BEGIN
         -- obtenemos la maxima secuencia de errores
         SELECT DISTINCT nvl(MAX(se.nro_secuencia), 0) + 1
           INTO v_aux_nro_archivo
           FROM ge_pag_sueldos_err se
          WHERE se.cod_ente = p_cod_ente
                AND se.fec_proceso = p_fec_actual;
      EXCEPTION
         WHEN OTHERS THEN
            v_aux_nro_archivo := 1;
      END;
   
      IF v_aux_nro_archivo > v_nro_archivo THEN
         v_nro_archivo := v_aux_nro_archivo;
      END IF;
      RETURN v_nro_archivo;
   END;

   /**
   * Procedimiento que retorna los datos de la Empresa para el servicio de Pago de Salarios.
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_OBT_DAT_EMPRESA(p_cod_ente         IN ge_pag_sue_ips.cod_ente%TYPE,
                                p_lote             IN ge_pag_sue_ips.nro_lote%TYPE,
                                P_DESCRIP          IN OUT VARCHAR2,
                                P_CTADBSU          IN OUT VARCHAR2,
                                P_TRANPDB          IN OUT NUMBER,
                                P_TRANCOM          IN OUT NUMBER,
                                P_TRANEXC          IN OUT NUMBER,
                                P_TRANPCOM         IN OUT NUMBER,
                                P_TRANPCRE         IN OUT NUMBER,
                                P_TRANPGRA         IN OUT NUMBER -- agregado para pago de gratificación
                               ,
                                P_DEB_EXCESO       IN OUT VARCHAR2,
                                P_FEC_INICIO       IN OUT DATE,
                                P_FEC_VENCIMIENTO  IN OUT DATE,
                                P_SER_ACTIVO       IN OUT VARCHAR2,
                                P_CAN_MAX_TRANS    IN OUT NUMBER,
                                P_NRO_CTA_CONTABLE IN OUT VARCHAR2,
                                P_REFERENCIA_TXT   IN OUT VARCHAR2,
                                P_LUGAR            OUT VARCHAR2,
                                P_FEC_HOY          IN DATE DEFAULT SYSDATE) IS
   BEGIN
   
      p_lugar := 'LP_OBT_DAT_EMPRESA';
   
      SELECT descripcion
        INTO p_descrip
        FROM GE_ENTES
       WHERE cod_ente = p_cod_ente;
      ------------------------------------------
      -- Se debe obtener los demás parametros...
      ------------------------------------------
      --Se toma la cuenta de debito que viene en el archivo de IPS,
      --si no viene nada entonces se toma el parametro
      BEGIN
         SELECT c.nro_cta_pag_salario
           INTO p_ctadbsu
           FROM ge_pag_sue_ips c
          WHERE c.nro_lote = p_lote;
      EXCEPTION
         WHEN no_Data_found THEN
            BEGIN
               SELECT nro_cuenta
                 INTO p_ctadbsu
                 FROM ge_pag_sueldos t
                WHERE cod_ente = p_cod_ente
                      AND trunc(nvl(fec_proceso, fec_insercion)) = trunc(p_fec_hoy)
                      AND tipo = 'D'
                      AND nro_Secuencia = (SELECT MAX(nro_Secuencia)
                                             FROM ge_pag_sueldos t2
                                            WHERE t2.cod_ente = p_cod_ente
                                                  AND trunc(fec_insercion) = trunc(p_fec_hoy)
                                                  AND t2.fec_proceso = p_fec_hoy
                                                  AND t2.tipo = 'D');
            EXCEPTION
               WHEN OTHERS THEN
                  p_ctadbsu := NULL;
            END;
         WHEN OTHERS THEN
            p_ctadbsu := NULL;
      END;
   
      IF p_ctadbsu IS NULL THEN
         --traemos de los parámetros del ente.
         p_ctadbsu := fug_obt_parentes(p_cod_ente, 'NRO_CTA_DEBITO');
      END IF;
   
      --cod. transaccion padre
      p_tranpdb := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_SUELDO');
   
      IF p_tranpdb IS NULL THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_EMPRESA: ATENCION. La empresa no posee Transacción Padre de Débito. Verifique!!!');
      END IF;
   
      --cod. transaccion comision
      p_trancom := fug_obt_parentes(p_cod_ente, 'COD_TRA_COMISION');
      --cod. transaccion comision por exceso
      p_tranexc := fug_obt_parentes(p_cod_ente, 'COD_TRA_COM_EXCESO');
      --cod. transaccion padre comision
      p_tranpcom := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_COMISION');
      --cod. transaccion padre credito
      p_tranpcre := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_CREDITO');
      --cod. transaccion padre gratificacion
      p_tranpgra := fug_obt_parentes(p_cod_ente, 'COD_TRA_PAD_GRATIFICACION');
      --
      p_deb_exceso := fug_obt_parentes(p_cod_ente, 'DEB_EXCESO_EMPRESA');
      --fecha de inicio del contrato de la empresa
      p_fec_inicio := to_date(fug_obt_parentes(p_cod_ente, 'FEC_INICIO'), 'DD/MM/YYYY');
      IF p_fec_inicio IS NULL THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_EMPRESA: ATENCION. La empresa no posee FECHA INICIO CONTRATO . Verifique!!!');
      END IF;
      --fecha de vencimiento de contrato de la empresa
      p_fec_vencimiento := to_date(fug_obt_parentes(p_cod_ente, 'FEC_VENCIMIENTO'), 'DD/MM/YYYY');
      IF p_fec_vencimiento IS NULL THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_EMPRESA: ATENCION. La empresa no posee FECHA VENCIMIENTO CONTRATO . Verifique!!!');
      END IF;
      --si el servicio está activo
      p_ser_activo := fug_obt_parentes(p_cod_ente, 'SER_ACTIVO');
      --cantidad máxima de transacciones
      p_can_max_trans := fug_obt_parentes(p_cod_ente, 'CAN_MAX_TRANSACCION');
      --nro. de cuenta contable
      p_nro_cta_contable := fug_obt_parentes(p_cod_ente, 'NRO_CTA_CONTABLE');
      --referencia del archivo txt para pago de sueldos
      p_referencia_txt := fug_obt_parentes(p_cod_ente, 'REFERENCIA_TXT_SUELDO');
      IF p_referencia_txt IS NULL THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_EMPRESA: ATENCION. La empresa no posee DEFINICION PARA TXT . Verifique!!!');
      END IF;
   
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_EMPRESA: Empresa Inexistente... Verifique.' || SQLERRM);
      WHEN TOO_MANY_ROWS THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_EMPRESA: Empresa Duplicada... AVISE AL ADMINISTRADOR.' || SQLERRM);
      WHEN OTHERS THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_EMPRESA: Error en LP_OBT_DAT_EMPRESA ' || SQLERRM);
   END LP_OBT_DAT_EMPRESA;

   /*
   * Realiza el débito automático de Préstamos, Tarjetas y Mov.Pendientes
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_PRO_DEB_AUTOMATICO(p_cod_ente      IN NUMBER,
                                   p_lote          IN ge_pag_sue_ips.nro_lote% TYPE,
                                   p_nro_secuencia IN OUT NUMBER,
                                   p_fec_hoy       IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE,
                                   p_error         OUT VARCHAR2) IS
   
      v_cuenta ge_pag_sueldos.nro_cuenta%TYPE;
   BEGIN
      DECLARE
         CURSOR Sdo IS
            SELECT DISTINCT p.nro_cuenta
              FROM GE_CTA_CLIENTES R, GE_PAG_SUELDOS P
             WHERE r.nro_cuenta = p.nro_cuenta
                   AND cod_ente = p_cod_ente
                   AND p.nro_secuencia = p_nro_secuencia
                   AND relacion = 'P'
                   AND p.tipo = 'C'
                   AND cod_proceso = 0
                   AND fec_proceso = p_fec_hoy
             ORDER BY tipo DESC;
      BEGIN
         IF Sdo%ISOPEN THEN
            CLOSE Sdo;
         END IF;
      
         OPEN Sdo;
         LOOP
            FETCH Sdo
               INTO v_cuenta;
            EXIT WHEN Sdo%NOTFOUND;
         
            P_ERROR := NULL;
         
            --TODO saber dónde se actualiza p_cierre
            --IF p_cierre = 'N' THEN
            pag_sue.pr_ins_log(v_cuenta, 0, 'DEB_AUTOMATICO', 'LP_PRO_DEB_AUTOMATICO: Cuenta: ' || v_cuenta);
         
            pr_ins_bitacora(p_lote, NULL, 'LP_PRO_DEB_AUTOMATICO: Cuenta: ' || v_cuenta);
         
            /* BSEVOCORE-416 se comenta la llamada por cuenta, ya se ejecuta luego por ente
            BEGIN
               prt_deb_automatico(v_cuenta);
            EXCEPTION
               WHEN OTHERS THEN
                  P_ERROR := 'Tarjetas ' || SQLERRM;
               
                  pr_ins_bitacora(p_lote, NULL, 'prt_deb_automatico: ' || P_ERROR);
            END;
            */
            
            BEGIN
               prp_deb_automatico(NULL, NULL, NULL, v_cuenta);
            EXCEPTION
               WHEN OTHERS THEN
                  P_ERROR := 'Préstamos ' || SQLERRM;
               
                  pr_ins_bitacora(p_lote, NULL, 'prp_deb_automatico: ' || P_ERROR);
            END;
         
            BEGIN
               prg_cob_mov_pendientes(v_cuenta);
            EXCEPTION
               WHEN OTHERS THEN
                  P_ERROR := 'Mov. Pendientes ' || SQLERRM;
               
                  pr_ins_bitacora(p_lote, NULL, 'prg_cob_mov_pendientes: ' || P_ERROR);
            END;
         END LOOP;
      END;
   END;

   /*
   * LIQUIDACION DEL ANTICIPO DE SUELDOS Y O/ AGUINALDOS
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_LIQ_ANTICIPOS(p_lote          IN GE_PAG_sue_ips.nro_lote%TYPE,
                              p_cod_ente      IN NUMBER,
                              p_tip_tra_padre IN VARCHAR2) IS
   
      v_interes NUMBER;
      v_fila    VARCHAR2(200);
      p_fec_hoy DATE;
   
      CURSOR cuentas IS
         SELECT a.nro_cuenta nro_cuenta, a.ROWID fila
           FROM CC_CTA_CORRIENTES c, GE_PAG_SUELDOS A
          WHERE a.cod_ente = p_cod_ente
                AND a.fec_proceso = p_fec_hoy
                AND a.COD_proceso = 0
                AND a.tipo = 'C'
                AND a.nro_cuenta = c.nro_cuenta
                AND c.cod_ente = a.cod_ente
                AND EXISTS (SELECT 0
                   FROM ge_pag_sue_anticipos b
                  WHERE b.nro_cuenta = a.nro_cuenta
                        AND b.liquidado = 'N');
   
   BEGIN
      p_fec_hoy := pag_cal.fu_obt_fec_actual(4);
      FOR ct IN cuentas
      LOOP
         v_fila := ct.fila;
         -- invoco a la liquidacion de sobregiros
         prc_liq_sobregiros(ct.nro_cuenta);
         -- invoco a cargo adicional de aguinaldos
         v_interes := pac_sob.FU_UTI_ANTICIPOS(ct.nro_cuenta, 'S', p_tip_tra_padre);
      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_LIQ_ANTICIPOS: Error al procesar liquidacion de anticipos.');
   END;

   /*
   * Procedimiento para obtener los datos de la cuenta
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_OBT_DAT_CUENTA(p_lote              IN GE_PAG_sue_ips.nro_lote%TYPE,
                               P_NRO_CUENTA        IN VARCHAR2,
                               P_TAS_PERSONALIZADA IN OUT VARCHAR2,
                               P_COD_MONEDA        IN OUT VARCHAR2,
                               P_LUGAR             OUT VARCHAR2) IS
   BEGIN
      p_lugar := 'Obteniendo Datos de la Cuenta';
      SELECT tas_personalizada, cod_moneda
        INTO P_TAS_PERSONALIZADA, p_cod_moneda
        FROM GE_CUENTAS
       WHERE nro_cuenta = p_nro_cuenta;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_CUENTA: ERROR. Cuenta :' || p_nro_cuenta || ' no existe.');
      WHEN OTHERS THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_CUENTA: ERROR. obt. datos cuenta: ' || p_nro_cuenta || ' ' || SQLERRM);
   END LP_OBT_DAT_CUENTA;

   /*
   * Obtener cant.y monto total de pago de sueldo
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_OBT_MONTO_PROC(p_lote      IN GE_PAG_sue_ips.nro_lote%TYPE,
                               P_SECUENCIA IN NUMBER,
                               P_COD_ENTE  IN NUMBER,
                               P_CANTCRED  IN OUT NUMBER,
                               P_MONTCRED  IN OUT NUMBER,
                               P_LUGAR     OUT VARCHAR2,
                               P_FEC_HOY   IN DATE) IS
   BEGIN
      --Obtener Cantidad y Monto Total del Pago de Sueldos
      p_lugar := 'LP_OBT_MONTO_PROC';
   
      SELECT COUNT(*), SUM(NVL(MONTO, 0))
        INTO p_CantCred, p_MontCred
        FROM GE_PAG_SUELDOS
       WHERE COD_ENTE = p_cod_ente
             AND TIPO = 'C'
             AND fec_proceso = trunc(P_FEC_HOY)
             AND nro_secuencia = p_secuencia
             AND monto > 0;
   EXCEPTION
      WHEN OTHERS THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_OBT_MONTO_PROC: Al Buscar monto y cant total proceso ' || SQLERRM);
   END lp_obt_monto_proc;

   /*
   * Actualizar el CodProceso del Lote.
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_ACT_PAG_SUELDOS(p_lote        IN ge_pag_sue_ips.nro_lote%TYPE,
                                P_FILA        IN VARCHAR2,
                                P_COD_PROCESO IN NUMBER) IS
   BEGIN
      UPDATE ge_pag_sueldos
         SET cod_proceso = p_cod_proceso
       WHERE ROWID = p_fila;
   
   EXCEPTION
      WHEN OTHERS THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_ACT_PAG_SUELDOS: Error al actualizar ge_pag_sueldos. ' || SQLERRM);
   END;

   /*
   * Actualizar la tabla ge_pag_sueldos
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_ACT_PAG_SUELDOS(p_lote          IN ge_pag_sue_ips.nro_lote%TYPE,
                                P_COD_ENTE      IN NUMBER,
                                P_FEC_PROCESO   IN DATE,
                                P_NRO_SECUENCIA IN NUMBER,
                                P_NRO_CUENTA    IN VARCHAR2,
                                P_COD_PROCESO   IN NUMBER) IS
   BEGIN
      UPDATE ge_pag_sueldos
         SET cod_proceso = p_cod_proceso
       WHERE cod_ente = P_COD_ENTE
             AND fec_proceso = p_fec_proceso
             AND nro_secuencia = p_nro_secuencia
             AND nro_cuenta = p_nro_cuenta;
   
   EXCEPTION
      WHEN OTHERS THEN
         pr_ins_bitacora(p_lote, NULL, 'LP_ACT_PAG_SUELDOS: Error al actualizar ge_pag_sueldos. ' || SQLERRM);
   END;

   /*
   * Procedimiento para obtener los datos de la cuenta
   * @Fecha : 30-01-2019
   */
   PROCEDURE LP_INS_MOV_SUELDO(P_HUBO_ERROR         IN OUT VARCHAR2,
                               P_HORAMOV            IN OUT VARCHAR2,
                               P_COD_ENTE           IN ge_pag_sue_ips.cod_ente%TYPE,
                               p_lote               IN ge_pag_sue_ips.nro_lote%TYPE,
                               P_NRO_SECUENCIA      IN OUT NUMBER,
                               P_LUGAR              IN OUT VARCHAR2,
                               P_CDOFICI            IN NUMBER,
                               P_FEC_HOY            IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE,
                               P_USUARIO            IN VARCHAR2,
                               P_TIPO_TRA_PADRE     IN VARCHAR2,
                               P_SEC_SGT_MOVIMIENTO OUT NUMBER) IS
   BEGIN
   
      DECLARE
         --traemos el débito y los créditos.
         CURSOR Sdo IS
            SELECT p.ROWID, nro_secuencia, p.nro_cuenta, tipo, DECODE(tipo, 'D', 503, 'C', 602, NULL),
                   --
                   monto, r.cod_modalidad, r.cod_modulo, fec_proceso, observacion nro_remito, cod_moneda
              FROM GE_CTA_CLIENTES R, GE_PAG_SUELDOS P
             WHERE r.nro_cuenta = p.nro_cuenta
                   AND cod_ente = p_cod_ente
                   AND p.nro_secuencia = p_nro_secuencia
                   AND relacion = 'P'
                   AND nvl(cod_proceso, 0) = 0
                   AND fec_proceso = p_fec_hoy
             ORDER BY tipo DESC;
      
         v_cuenta              ge_cuentas.nro_cuenta%TYPE;
         v_cuenta_db           ge_cuentas.nro_cuenta%TYPE;
         v_tpmovim             VARCHAR2(01);
         v_cnmovim             ge_movimientos.concepto%TYPE;
         v_mensaje_error       VARCHAR2(1000);
         v_proceso_ok          VARCHAR2(01);
         v_fila                VARCHAR2(18);
         v_mov_error           VARCHAR2(01);
         v_cdmoned             VARCHAR2(03);
         v_estado_nuevo        VARCHAR2(01);
         v_puede_procesar      VARCHAR2(01);
         v_tiene_tp            VARCHAR2(01);
         v_fcproce             DATE;
         v_max_sec_use_fgdiari NUMBER(07) := 0;
         v_codigo_error        NUMBER(03);
         v_cdmodal             NUMBER(03);
         v_cdmodul             NUMBER(03);
         v_cdmodap             NUMBER(03);
         v_cdmodup             NUMBER(03);
         v_cdofici             NUMBER(03);
         v_cdofior             NUMBER(03);
         v_tranh               NUMBER(03);
         v_secuencia           NUMBER(03);
         v_Sldisp              NUMBER;
         v_sldisp_comb         NUMBER;
         v_valor_com           NUMBER;
         v_valor_iva           NUMBER;
         v_Cantcred            NUMBER(05);
         v_Total_Credito       NUMBER;
         v_Comision            NUMBER;
         v_Iva                 NUMBER;
         v_imtrans             NUMBER;
         rg_movs               ge_movimientos%ROWTYPE;
         v_cod_mon_local       ba_monedas.cod_moneda%TYPE;
         v_cdpers              ba_personas.cod_persona%TYPE;
         ---* estas variables son para obtener los datos de empresa
         v_descrip     VARCHAR2(60);
         v_ctadbsu     ge_cuentas.nro_cuenta%TYPE;
         v_tranpdb     ge_transacciones.cod_transaccion%TYPE;
         v_cdtasas     ge_par_entes.val_parametro%TYPE;
         v_cdtasas_iva ge_par_entes.val_parametro%TYPE;
         v_cdtriva     ge_transacciones.cod_transaccion%TYPE;
         v_cdtrcom     ge_transacciones.cod_transaccion%TYPE;
         ---*
         v_trancom ge_transacciones.cod_transaccion%TYPE;
         v_tranexc ge_transacciones.cod_transaccion%TYPE;
         --v_tranpagui            ge_transacciones.cod_transaccion%TYPE;
         v_tranpcom             ge_transacciones.cod_transaccion%TYPE;
         v_tranpcre             ge_transacciones.cod_transaccion%TYPE;
         v_tranpgra             ge_transacciones.cod_transaccion%TYPE; ---agr.p/pag.grat.
         v_deb_exceso           ge_par_entes.val_parametro%TYPE;
         v_fec_inicio           ge_pag_sueldos.fec_proceso%TYPE;
         v_fec_vencimiento      ge_pag_sueldos.fec_proceso%TYPE;
         v_nro_cta_contable_txt ge_par_entes.val_parametro%TYPE;
         v_ser_activo           ge_par_entes.val_parametro%TYPE;
         v_can_max_trans        ge_par_entes.val_parametro%TYPE;
         v_precio_fijo          ge_par_entes.val_parametro%TYPE;
         --v_tra_aguinaldo        ge_par_entes.val_parametro%TYPE;
      
         ---* para package de tasas
         v_ente           ge_entes.cod_ente%TYPE;
         v_referencia_txt VARCHAR2(100);
         ---* para obtener ley 125
         v_tot_debito NUMBER;
         --v_cta_ahorro       ge_cuentas.nro_cuenta%TYPE;
         v_tot_imtrans      NUMBER;
         v_mto_max_comision NUMBER;
         v_remito           ge_pag_sueldos.observacion%TYPE;
         v_nro_documento    NUMBER(15); -- OMM 20/10/2010
         v_est_modulo       ba_modulos.estado%TYPE; -- OMM 13/12/2010
         v_horario          VARCHAR2(1) := 'D'; -- Dia normal -- OMM 13/12/2010
         v_es_nocturno      VARCHAR2(1) := 'N'; -- No es Nocturno -- OMM 13/12/2010
         --N -> se procesa parcialmente el lote, C -> no se procesa parcialmente
         v_pro_con_errores VARCHAR2(1) := UPPER(nvl(fug_obt_parentes(P_COD_ENTE, 'PRO_CON_ERRORES'), 'N'));
         v_moneda          ge_pag_sueldos.cod_moneda%TYPE;
         v_mto_credito     ge_pag_sueldos.monto%TYPE;
         v_mto_debito      ge_pag_sue_lotes.mto_debito%TYPE;
         v_cta_ente        ge_cuentas.nro_cuenta%TYPE;
         --v_cta_aguinaldo    VARCHAR2(1);
         v_mensaje NUMBER;
      BEGIN
         v_precio_fijo      := fug_obt_parentes(p_cod_ente, 'COD_TRA_PRECIO_FIJO');
         v_mto_max_comision := fug_obt_parentes(p_cod_ente, 'MTO_MAX_COMISION');
      
         -- OMM 13/12/2010 Se modifico para pago de salarios via web en sistema cerrado
         IF nvl(PAE_CNF.G_PROGRAMA, 'x') <> 'GPPAGSUE' THEN
            v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(4);
            IF v_est_modulo = 2 THEN
               v_horario     := 'D'; -- N=Cerrado, D=Abierto
               v_es_nocturno := 'N'; -- N=Abierto,  S=Cerrado
            ELSE
               v_horario     := 'N'; -- N=Cerrado, D=Abierto
               v_es_nocturno := 'S'; -- N=Abierto,  S=Cerrado
            END IF;
            pag_cta.g_horario := v_horario;
         END IF;
      
         --trata de procesar otro ente,
         --inserto datos de otro ente a verificar desde diskete ---
         BEGIN
            SELECT cod_ente
              INTO v_ente
              FROM ge_pag_sueldos
             WHERE cod_ente = p_cod_ente
                   AND rownum = 1;
         EXCEPTION
            WHEN no_data_found THEN
               p_hubo_error := 'X';
         END;
      
         IF nvl(v_ente, 0) <> p_cod_ente THEN
            p_hubo_error := 'X';
            v_mov_error  := 'S';
         ELSE
            v_cnmovim    := 'Pago de Sueldo ';
            v_mov_error  := 'N';
            p_hubo_error := 'N';
         
            p_lugar := 'LP_INS_MOV_SUELDO.LP_OBT_DAT_EMPRESA';
            pr_ins_bitacora(p_lote, NULL, p_lugar);
         
            --obtener los datos del Ente.
            LP_OBT_DAT_EMPRESA(p_cod_ente, p_lote, v_descrip, v_ctadbsu, v_tranpdb, v_trancom,
                               --
                               v_tranexc, /*v_tranpagui,*/ v_tranpcom, v_tranpcre, v_tranpgra,
                               --
                               v_deb_exceso, v_fec_inicio, v_fec_vencimiento, v_ser_activo,
                               --
                               v_can_max_trans, v_nro_cta_contable_txt, v_referencia_txt,
                               --
                               p_lugar, p_fec_hoy);
         
            IF P_TIPO_TRA_PADRE = 'C' THEN
               ---- COMISION
               v_tranpdb := v_tranpcom;
               v_cnmovim := 'Pago de Comision ';
            ELSIF P_TIPO_TRA_PADRE = 'T' THEN
               --- CREDITO
               v_tranpdb := v_tranpcre;
               v_cnmovim := 'Credito en Cuenta ';
            ELSIF P_TIPO_TRA_PADRE = 'G' THEN
               --- GRATIFICACION
               v_tranpdb := v_tranpgra;
               v_cnmovim := 'Gratificacion del Empleado ';
            END IF;
         
            -- obtiene una hora unica para todos los movimientos a ser insertados
            IF p_horamov IS NULL THEN
               p_horamov := TO_CHAR(SYSDATE, 'HH24:MI:SS');
            END IF;
            p_horamov := fug_obt_hor_disponible(P_FEC_HOY, p_horamov, USER, v_es_nocturno);
            --
            v_tot_imtrans := 0;
            IF Sdo%ISOPEN THEN
               CLOSE Sdo;
            END IF;
         
            --recorremos el lote de pagos
            OPEN Sdo;
            LOOP
               FETCH Sdo
                  INTO v_fila, v_secuencia, v_cuenta, v_tpmovim, v_tranh, v_imtrans, v_cdmodal, v_cdmodul, v_fcproce, v_remito, v_moneda;
               EXIT WHEN Sdo%NOTFOUND;
            
               --p_lugar := 'Procesando Pago a Cuenta :' || v_cuenta;
               --pr_ins_bitacora(p_lote, NULL, p_lugar);
               ---
               v_mov_error := 'N';
               ---
               -- OMM 20/10/2010 Se agrego secuencia para poder ingresar mas de 1 pago x dia
               v_nro_documento := to_number(v_secuencia || p_cod_ente);
               IF v_cdmodup IS NULL THEN
                  ---
                  IF v_nro_cta_contable_txt IS NULL THEN
                     --- agregado para modulo de RRHH
                     BEGIN
                        SELECT A.nro_cuenta, B.cod_moneda, B.cod_oficina
                          INTO v_cuenta_db, v_cdmoned, v_cdofici
                          FROM ge_pag_sueldos A, ge_cuentas B
                         WHERE A.nro_cuenta = B.nro_cuenta
                               AND A.cod_modulo = B.cod_modulo
                               AND A.cod_modalidad = B.cod_modalidad
                               AND A.cod_ente = p_cod_ente
                               AND A.tipo = 'D'
                               AND A.nro_secuencia = v_secuencia
                               AND A.fec_proceso = v_fcproce;
                     EXCEPTION
                        WHEN no_data_found THEN
                           p_hubo_error := 'S';
                           v_mov_error  := 'S';
                           --actualiza el registro de pagos
                           LP_ACT_PAG_SUELDOS(p_lote, p_cod_ente, v_fcproce, v_secuencia, v_ctadbsu, 12);
                           pr_ins_bitacora(p_lote, NULL, 'LP_ACT_PAG_SUELDOS: No se obtuvieron datos del pago.');
                        WHEN too_many_rows THEN
                           pr_ins_bitacora(p_lote, v_remito, 'Error: Ya se procesó el Ente');
                     END;
                     --
                     BEGIN
                        SELECT cod_modulo, cod_modalidad, p_cdofici
                          INTO v_cdmodup, v_cdmodap, v_cdofior
                          FROM ge_cta_clientes
                         WHERE nro_cuenta = v_cuenta_db
                               AND relacion = 'P';
                     EXCEPTION
                        WHEN OTHERS THEN
                           p_hubo_error := 'S';
                           v_mov_error  := 'S';
                           --actualiza el registro de pagos
                           LP_ACT_PAG_SUELDOS(p_lote, p_cod_ente, v_fcproce, v_secuencia, v_ctadbsu, 12);
                           pr_ins_bitacora(p_lote, v_remito, 'LP_ACT_PAG_SUELDOS: No se obtuvieron datos de la cuenta.');
                     END;
                  END IF;
               END IF;
               --
               IF v_mov_error = 'N' THEN
                  IF v_nro_cta_contable_txt IS NOT NULL THEN
                     --- Agregado para modulo de RRHH
                     --- Para grabar por cada registro procesado y sus movimientos la misma hora
                     v_cdmodup := 14;
                     v_cdmodap := 141;
                  END IF;
                  --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                  -- Aqui se debe verificar si alguna cuenta de crédito tiene error.
                  IF v_tpmovim = 'C' AND v_pro_con_errores = 'N' AND p_hubo_error = 'N' THEN
                     --p_lugar := 'LP_INS_MOV_SUELDO --> PAG_CTA.PR_VER_OPERACION';
                     --pr_ins_bitacora(p_lote, NULL, p_lugar);
                  
                     PAG_CTA.PR_VER_OPERACION(v_cuenta, v_tranpdb, v_cdmodup, v_cdmodap, v_tpmovim,
                                              --
                                              v_cdmoned, v_imtrans, v_cdofior, v_cdmodul, v_cdmodal,
                                              --
                                              v_estado_nuevo, v_sldisp, v_puede_procesar);
                  
                     v_mensaje_error := pag_cta.fu_obt_msj_error;
                     v_codigo_error  := pag_cta.fu_obt_cod_error;
                     IF v_codigo_error > 0 THEN
                        --actualiza el registro de pagos
                        LP_ACT_PAG_SUELDOS(p_lote, p_cod_ente, v_fcproce, v_secuencia, v_cuenta, v_codigo_error);
                     
                        p_lugar := 'LP_INS_MOV_SUELDO --> LP_ACT_PAG_SUELDOS: ' || v_codigo_error || ': ' || v_mensaje_error;
                        pr_ins_bitacora(p_lote, v_remito, p_lugar);
                     END IF;
                  END IF;
                  -- FQ Acumulo el total del credito para que se realice el débito por el monto
                  -- de cuentas sin error. BBVADES 2576
                  IF v_tpmovim = 'D' AND v_pro_con_errores = 'N' AND p_hubo_error = 'N' THEN
                     v_cta_ente := v_cuenta;
                  
                     BEGIN
                        SELECT SUM(monto)
                          INTO v_imtrans
                          FROM GE_CTA_CLIENTES R, GE_PAG_SUELDOS P
                         WHERE r.nro_cuenta = p.nro_cuenta
                               AND cod_ente = p_cod_ente
                               AND p.nro_secuencia = p_nro_secuencia
                               AND relacion = 'P'
                               AND nvl(cod_proceso, 0) = 0
                               AND p.tipo = 'C'
                               AND fec_proceso = p_fec_hoy;
                     EXCEPTION
                        WHEN no_data_found THEN
                           pr_ins_bitacora(p_lote, v_remito, 'LP_INS_MOV_SUELDO: No se encuentran cuentas de Crédito a Procesar.');
                     END;
                  END IF;
               
                  IF v_mov_error = 'N' AND v_imtrans > 0 THEN
                     -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                     IF v_max_sec_use_fgdiari > 990 THEN
                        v_max_sec_use_fgdiari := -999;
                     ELSIF v_max_sec_use_fgdiari < 0 AND v_max_sec_use_fgdiari > -10 THEN
                        p_horamov             := fug_obt_hor_disponible(v_fcproce, p_horamov, USER, v_es_nocturno);
                        v_max_sec_use_fgdiari := 0;
                     END IF;
                  
                     --TODO ver de donde sale p_cierre
                     IF p_cierre = 'N' THEN
                        pag_sue.pr_ins_log(v_cuenta, v_imtrans, 'LP_INS_MOV_SUELDO', 'Actualización Saldo Cta. crédito');
                     END IF;
                  
                     --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
                     IF p_hubo_error = 'N' THEN
                        BEGIN
                           --p_lugar := p_lugar || ' LP_INS_MOV_SUELDO->PAG_CTA.PR_ACT_OPERACION: ' || v_cuenta || '|' || v_tpmovim || '|' || v_imtrans;
                        
                           --pr_ins_bitacora(p_lote, NULL, p_lugar);
                        
                           pag_cta.PR_SET_NRO_DOCUMENTO3(p_cod_ente);
                        
                           --guardamos en Nro_documento2 el cod. cabecera / detalle
                           PAG_CTA.PR_SET_NRO_DOCUMENTO2(v_remito);
                        
                           pag_cta.pr_set_variables(USER, v_fcproce, v_tranpdb, 'N', 'N', v_max_sec_use_fgdiari, NULL, v_cdofior, v_cdmodup, v_cdmodap);
                        
                           PAG_CTA.PR_ACT_OPERACION(v_cuenta, p_horamov, v_tpmovim, v_cdmoned, v_imtrans,
                                                    --
                                                    v_tranpdb, v_tranh,
                                                    --nvl(v_remito, v_nro_documento),
                                                    v_nro_documento,
                                                    --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                    NULL, v_cdofior, v_cdmodup, v_cdmodap, NULL, NULL, v_cnmovim, 'S',
                                                    --
                                                    v_max_sec_use_fgdiari, v_fcproce);
                           --
                           v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                           v_mensaje_error := pag_cta.fu_obt_msj_error;
                           v_codigo_error  := pag_cta.fu_obt_cod_error;
                        
                           p_lugar := ' LP_INS_MOV_SUELDO->LP_ACT_PAG_SUELDOS: ' || v_codigo_error;
                           pr_ins_bitacora(p_lote, v_remito, p_lugar);
                        
                           --actualiza el registro de pagos
                           LP_ACT_PAG_SUELDOS(p_lote, v_fila, v_codigo_error);
                        
                           IF v_proceso_ok = 'S' THEN
                              --RI : 30/11/09 : Acumulo el total de creditos para luego tener en cuenta para generar
                              -- la comision, si el monto total acreditardo es cero no generar comision
                              IF v_tpmovim = 'C' THEN
                                 v_tot_imtrans := nvl(v_tot_imtrans, 0) + nvl(v_imtrans, 0);
                              
                                 p_lugar := ' Acumulado de créditos: ' || v_tot_imtrans;
                                 pr_ins_bitacora(p_lote, v_remito, p_lugar);
                              END IF;
                           ELSE
                              p_hubo_error := 'S';
                              v_mov_error  := 'S';
                              P_LUGAR      := v_mensaje_error;
                           END IF;
                        
                        EXCEPTION
                           WHEN OTHERS THEN
                              v_pk_error := PAG_CTA.G_MSJ_ERROR;
                              pr_ins_bitacora(p_lote, v_remito, PAG_CTA.G_COD_ERROR || '|' || PAG_CTA.G_MSJ_ERROR);
                              --reintento si es error de PK
                              if( instr(v_pk_error,'PK_GE_MOVIMIENTOS') > 0 )then
                                  --1. llamar nuevamente a la funcion de obtener hora
                                  p_horamov := fug_obt_hor_disponible(P_FEC_HOY, TO_CHAR(SYSDATE, 'HH24:MI:SS'), USER, v_es_nocturno);
                                  --2. enviar email a ep-sau
                                  begin
                                       PRG_ENV_MAIL( fug_obt_dir_correo,
                                         fug_obt_pardinamico('EMAIL_MOV_INFONET'),
                                         'ERROR PK_GE_MOVIMIENTOS EN ACREDITACIONES IPS '|| to_char(sysdate,'YYYY-MM-DD'),
                                         'Error de PK al insertar movimiento en lote '|| p_lote || chr(10) || chr(10) ||
                                         v_pk_error || chr(10) || chr(10) ||
                                         'PAG_IPS.' );
                                  exception
                                       when others then
                                          pr_ins_bitacora(p_lote, v_remito, PAG_CTA.G_COD_ERROR || '|' || 'Error al enviar email de aviso de error PK_GE_MOVIMIENTOS.');
                                   end;
                              end if;                              
                        END;
                     ELSE
                        v_proceso_ok := 'S';
                     END IF;
                  END IF;
               END IF;
            
               IF v_proceso_ok = 'N' AND v_tpmovim = 'D' THEN
                  p_hubo_error := 'S';
                  v_mov_error  := 'S';
               ELSIF v_proceso_ok = 'S' THEN
                  -- CAN-NOTIFICACIONES Fase 2
                  v_cdpers := FUG_OBT_CLI_PRINCIPAL(v_cuenta);
               
                  p_lugar := 'LP_INS_MOV_SUELDO->PAW_NOT.fu_not_pag_sueldo. Persona: ' || v_cdpers || --
                             'Cuenta: ' || v_cuenta || '. Monto: ' || v_cdmoned || ' ' || v_imtrans;
                  pr_ins_bitacora(p_lote, v_remito, p_lugar);
               
                  v_mensaje := PAW_NOT.fu_not_pag_sueldo( --Código de Persona
                                                         v_cdpers,
                                                         --Número de Cuenta
                                                         v_cuenta,
                                                         --Código de la Moneda
                                                         v_cdmoned,
                                                         --Monto de la Acreditación
                                                         v_imtrans,
                                                         --Tipo de Pago de Sueldos
                                                         p_tipo_tra_padre);
               END IF;
               EXIT WHEN p_hubo_error > 'S';
            END LOOP;
         
            IF Sdo%ISOPEN THEN
               CLOSE Sdo;
            END IF;
         
            v_cod_mon_local := pag_gen.fu_obt_mon_local;
            v_Sldisp        := 0;
            v_Sldisp_comb   := 0;
         
            BEGIN
               SELECT nvl(SUM(monto), 0)
                 INTO v_mto_credito
                 FROM ge_pag_sueldos
                WHERE cod_ente = p_cod_ente
                      AND fec_proceso = P_FEC_HOY
                      AND nro_secuencia = p_nro_secuencia
                      AND tipo = 'C'
                      AND nvl(cod_proceso, 0) = 0;
            EXCEPTION
               WHEN no_data_found THEN
                  P_HUBO_ERROR := 'Z';
            END;
            IF nvl(v_mto_credito, 0) = 0 THEN
               P_HUBO_ERROR := 'Z';
            END IF;
         
            IF nvl(p_hubo_error, 'N') = 'N' AND v_mto_credito > 0 THEN
               ---
               --- agregado para modulo de RRHH
               ---
               IF v_nro_cta_contable_txt IS NULL THEN
                  p_lugar := 'LP_INS_MOV_SUELDO->PAG_CTA.PR_VER_OPERACION)';
                  pr_ins_bitacora(p_lote, NULL, p_lugar);
               
                  PAG_CTA.PR_VER_OPERACION(v_ctadbsu, v_tranpdb, v_cdmodul, v_cdmodal, 'D', v_cdmoned, 1,
                                           --
                                           v_cdofior, v_cdmodup, v_cdmodap, v_estado_nuevo, v_sldisp, v_puede_procesar);
                  v_mensaje_error := pag_cta.fu_obt_msj_error;
                  v_codigo_error  := pag_cta.fu_obt_cod_error;
               
                  v_sldisp_comb := pag_cta.fu_sal_dis_combinada; --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                  --
                  p_lugar := 'LP_INS_MOV_SUELDO->LP_OBT_DAT_CUENTA ';
                  pr_ins_bitacora(p_lote, NULL, p_lugar);
                  LP_OBT_DAT_CUENTA(p_lote, v_ctadbsu, v_tiene_tp, v_cdmoned, p_lugar);
               
                  p_lugar := 'LP_INS_MOV_SUELDO->lp_obt_monto_proc ';
                  pr_ins_bitacora(p_lote, NULL, p_lugar);
                  LP_OBT_MONTO_PROC(p_lote, v_Secuencia, p_cod_ente, v_CantCred, v_Total_Credito, P_lugar, p_fec_hoy);
               
                  ----- A PARTIR DE AQUI DEBE HACER EL PRG_OBT_CARGOS
                  ----------------------------------------------
                  -----Calcula Comision e Iva para La Empresa --
                  ----------------------------------------------
                  IF v_trancom IS NOT NULL AND v_tot_imtrans > 0 THEN
                     p_lugar := 'LP_INS_MOV_SUELDO->PRG_OBT_CARGOS ';
                     pr_ins_bitacora(p_lote, NULL, p_lugar);
                  
                     PRG_OBT_CARGOS(v_cdofior --P_COD_OFI_ORIGEN     IN GE_CUENTAS.COD_OFICINA%TYPE
                                   , v_ctadbsu
                                    --P_NRO_CUENTA         IN GE_CUENTAS.NRO_CUENTA%TYPE
                                   , v_cdmoned
                                    --P_COD_MONEDA         IN GE_CUENTAS.COD_MONEDA%TYPE
                                   , v_Total_Credito
                                    --P_MONTO              IN GE_MOVIMIENTOS.MONTO%TYPE
                                   , v_cdmodup
                                    --P_COD_MODULO         IN GE_CUENTAS.COD_MODULO%TYPE
                                   , v_cdmodap
                                    --P_COD_MODALIDAD      IN GE_CUENTAS.COD_MODALIDAD%TYPE
                                   , v_trancom
                                    --P_COD_TRA_CARGO      IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
                                   , v_cdtasas
                                    --P_COD_TAS_CARGO      OUT GE_MOVIMIENTOS.COD_TASA%TYPE
                                   , v_valor_com
                                    --P_VAL_TAS_CARGO      OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                                   , v_comision
                                    --P_VAL_CARGO          OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                                   , v_cdtriva
                                    --P_COD_TRA_IMPUESTO   OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE
                                   , v_cdtasas_iva
                                    --P_COD_TAS_IMPUESTO   OUT GE_MOVIMIENTOS.COD_TASA%TYPE
                                   , v_valor_iva
                                    --P_VAL_TAS_IMPUESTO   OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                                   , v_iva); -- P_VAL_IMPUESTO      OUT GE_MOVIMIENTOS.VAL_TASA%TYPE
                     --- si el precio es fijo, la comision deber ser igual ---
                     IF nvl(v_precio_fijo, 'N') = 'S' THEN
                        v_comision := v_comision;
                     ELSE
                        --- si es valor debe multiplicar por la cant. de creditos ---
                        IF v_valor_com = nvl(v_comision, 0) + nvl(v_iva, 0) THEN
                           v_tot_debito := (nvl(v_comision, 0) + nvl(v_iva, 0)) * nvl(v_cantcred, 0);
                           -- RI : 07/12/09 : Si esta parametrizado el monto maximo de comision que se puede
                           -- cobrar al ente ajustar la comision a esta monto.
                           IF nvl(v_tot_Debito, 0) > nvl(v_mto_max_comision, 0) AND nvl(v_mto_max_comision, 0) > 0 THEN
                              v_tot_debito := v_mto_max_comision;
                           END IF;
                           --
                           IF v_cdmoned = v_cod_mon_local THEN
                              v_iva := round((v_tot_debito * nvl(v_valor_iva, 0) / (nvl(v_valor_iva, 0) + 100)), 0);
                           ELSE
                              v_iva := round((v_tot_debito * nvl(v_valor_iva, 0) / (nvl(v_valor_iva, 0) + 100)), 2);
                           END IF;
                           v_comision := v_tot_debito - v_iva;
                        END IF;
                     END IF;
                  
                     p_lugar := 'LP_INS_MOV_SUELDO->Procesar_Movim.Sueldo - Busca Tasa Comision-Empresa';
                     pr_ins_bitacora(p_lote, NULL, p_lugar);
                  
                     ---* aqui verifico si no supera monto+iva lo disponible antes de generar mov 16/02/05
                     IF NVL(v_SlDisp, 0) + nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(v_ctadbsu), 0) < NVL(v_comision, 0) + NVL(v_iva, 0) THEN
                        v_sldisp := v_sldisp_comb;
                     
                        IF NVL(v_SlDisp, 0) + nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(v_ctadbsu), 0) < NVL(v_comision, 0) + NVL(v_iva, 0) THEN
                           p_hubo_error := 'S';
                           --actualizamos los datos del pago
                           LP_ACT_PAG_SUELDOS(p_lote, p_cod_ente, v_fcproce, v_secuencia, v_ctadbsu, 25);
                        END IF;
                     END IF;
                  
                     IF nvl(p_hubo_error, 'N') = 'N' THEN
                        IF NVL(v_SlDisp, 0) + nvl(pag_cta.FU_OBT_LIN_SOBREGIRO(v_ctadbsu), 0) >= NVL(v_comision, 0) + NVL(v_iva, 0) AND NVL(v_comision, 0) + NVL(v_iva, 0) > 0 THEN
                           --
                           v_cnmovim := 'Comision pago de Sueldo';
                           --
                           IF v_comision > 0 THEN
                              -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                              IF v_max_sec_use_fgdiari > 990 THEN
                                 v_max_sec_use_fgdiari := -999;
                              ELSIF v_max_sec_use_fgdiari < 0 AND v_max_sec_use_fgdiari > -10 THEN
                                 p_horamov             := fug_obt_hor_disponible(v_fcproce, p_horamov, USER, v_es_nocturno);
                                 v_max_sec_use_fgdiari := 0;
                              END IF;
                           
                              p_lugar := 'LP_INS_MOV_SUELDO->PAG_CTA.PR_ACT_OPERACION : pago sueldo';
                              pr_ins_bitacora(p_lote, NULL, p_lugar);
                              --actualizamos los datos del pago
                              IF p_cierre = 'N' THEN
                                 pag_sue.pr_ins_log(v_ctadbsu, v_comision, 'LP_INS_MOV_SUELDO', 'Cobro de comisión al ente');
                              END IF;
                           
                              pag_cta.pr_set_variables(USER, v_fcproce, v_tranpdb, 'N', 'N', v_max_sec_use_fgdiari, NULL, v_cdofior, v_cdmodup, v_cdmodap);
                           
                              --guardamos en Nro_documento2 el cod. cabecera
                              PAG_CTA.PR_SET_NRO_DOCUMENTO2(p_lote);
                           
                              PAG_CTA.PR_ACT_OPERACION(v_ctadbsu, p_horamov, 'D', v_cdmoned, v_comision, v_tranpdb, v_trancom,
                                                       ---v_cdtrcom,
                                                       --nvl(v_remito, v_nro_documento),
                                                       v_nro_documento,
                                                       --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                       NULL, nvl(v_cdofior, p_cdofici), v_cdmodup, v_cdmodap, NULL, NULL, v_cnmovim, 'S', v_max_sec_use_fgdiari, v_fcproce);
                           
                              v_mensaje_error := pag_cta.fu_obt_msj_error;
                              v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                              v_codigo_error  := pag_cta.fu_obt_cod_error;
                           
                              IF v_proceso_ok != 'S' THEN
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_MOV_SUELDO: Error en pr_act_operacion: ' || v_codigo_error || v_mensaje_error);
                              END IF;
                           END IF;
                           --
                           IF nvl(v_iva, 0) > 0 THEN
                              v_cnmovim := 'Iva s/Imp.pago de Sueldo';
                              --
                              -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                              IF v_max_sec_use_fgdiari > 990 THEN
                                 v_max_sec_use_fgdiari := -999;
                              ELSIF v_max_sec_use_fgdiari < 0 AND v_max_sec_use_fgdiari > -10 THEN
                                 p_horamov             := fug_obt_hor_disponible(v_fcproce, p_horamov, USER, v_es_nocturno);
                                 v_max_sec_use_fgdiari := 0;
                              END IF;
                              --
                              p_lugar := 'LP_INS_MOV_SUELDO->PAG_CTA.PR_ACT_OPERACION : DB Iva';
                              pr_ins_bitacora(p_lote, NULL, p_lugar);
                              --actualizamos los datos del pago
                              IF p_cierre = 'N' THEN
                                 pag_sue.pr_ins_log(v_ctadbsu, v_iva, 'LP_INS_MOV_SUELDO', p_lugar || ' Cobro de comisión al ente');
                              END IF;
                           
                              pag_cta.pr_set_variables(USER, v_fcproce, v_tranpdb, 'N', 'N', v_max_sec_use_fgdiari, NULL, v_cdofior, v_cdmodup, v_cdmodap);
                           
                              PAG_CTA.PR_ACT_OPERACION(v_ctadbsu, p_horamov, 'D', v_cdmoned, v_iva, v_cdtriva,
                                                       --v_tranpdb,
                                                       v_cdtriva,
                                                       --nvl(v_remito, v_nro_documento),
                                                       v_nro_documento,
                                                       --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                                                       NULL, nvl(v_cdofior, p_cdofici), v_cdmodup, v_cdmodap, v_cdtasas_iva, v_valor_iva, v_cnmovim, 'S', v_max_sec_use_fgdiari, v_fcproce);
                           
                              v_mensaje_error := pag_cta.fu_obt_msj_error;
                              v_proceso_ok    := pag_cta.fu_obt_ok_procesar;
                              v_codigo_error  := pag_cta.fu_obt_cod_error;
                           
                              IF v_proceso_ok != 'S' THEN
                                 pr_ins_bitacora(p_lote, NULL, 'Error en pr_act_operacion : IVA ' || v_codigo_error || v_mensaje_error);
                              END IF;
                           END IF;
                           --
                        ELSIF NVL(v_SlDisp, 0) < NVL(v_comision, 0) + NVL(v_iva, 0) AND NVL(v_comision, 0) + NVL(v_iva, 0) > 0 THEN
                           --
                           -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                           IF v_max_sec_use_fgdiari > 990 THEN
                              v_max_sec_use_fgdiari := -999;
                           ELSIF v_max_sec_use_fgdiari < 0 AND v_max_sec_use_fgdiari > -10 THEN
                              p_horamov             := fug_obt_hor_disponible(v_fcproce, p_horamov, USER, v_es_nocturno);
                              v_max_sec_use_fgdiari := 0;
                           END IF;
                           --
                           p_lugar                 := ' Carga registro rg_movs ';
                           rg_movs.COD_USUARIO     := p_usuario;
                           rg_movs.hora            := p_horamov;
                           rg_movs.nro_secuencia   := v_max_sec_use_fgdiari + 1;
                           rg_movs.cod_modulo      := v_cdmodul;
                           rg_movs.cod_modalidad   := v_cdmodal;
                           rg_movs.cod_oficina     := v_cdofici;
                           rg_movs.nro_cuenta      := v_ctadbsu;
                           rg_movs.cod_moneda      := v_cdmoned;
                           rg_movs.cod_tra_padre   := v_tranpdb;
                           rg_movs.cod_transaccion := v_cdtrcom;
                           rg_movs.fecha           := p_fec_hoy;
                           rg_movs.fec_valor       := p_fec_hoy;
                           rg_movs.nro_documento   := nvl(v_remito, v_nro_documento); --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                           rg_movs.nro_documento3  := p_cod_ente;
                           rg_movs.monto           := v_comision;
                           rg_movs.est_cuenta      := 'N';
                           rg_movs.estado          := 'E';
                           rg_movs.cod_ofi_origen  := nvl(v_cdofior, p_cdofici);
                           rg_movs.concepto        := v_cnmovim;
                           rg_movs.reversado       := 'N';
                           rg_movs.emi_aviso       := 'N';
                           rg_movs.cod_mod_padre   := v_cdmodup;
                           rg_movs.cod_mad_padre   := v_cdmodap;
                        
                           p_lugar := 'LP_INS_MOV_SUELDO->PAG_GEN.PR_INS_GE_MOVIMIENTO , inserta mov E ';
                           pr_ins_bitacora(p_lote, NULL, p_lugar);
                           -- 13/12/2010 OMM Para pagar en sistema cerrado
                           PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs, v_es_nocturno);
                        END IF;
                     END IF;
                  END IF;
                  ---
               ELSE
                  --- agregado para RRHH
                  --------------------------------------
                  --- si no se debita de cuenta de ahorro
                  --- se debe debitar del rubro contable
                  p_lugar := 'LP_INS_MOV_SUELDO->lp_obt_monto_proc ';
                  pr_ins_bitacora(p_lote, NULL, p_lugar);
                  PAG_SUE.LP_OBT_MONTO_PROC(v_Secuencia, p_cod_ente, v_CantCred, v_Total_Credito, P_lugar, p_fec_hoy);
               
                  BEGIN
                     SELECT c.cod_moneda
                       INTO v_cdmoned
                       FROM cb_rubros c
                      WHERE c.cod_rubro = v_nro_cta_contable_txt;
                  EXCEPTION
                     WHEN no_data_found THEN
                        pr_ins_bitacora(p_lote, NULL, 'LP_INS_MOV_SUELDO: Rubro contable no posee moneda: ' || v_nro_cta_contable_txt);
                  END;
               
                  -- OMM 09/10/2014. Se ajusta la secuencia por errores en la generación de movimientos
                  IF v_max_sec_use_fgdiari > 990 THEN
                     v_max_sec_use_fgdiari := -999;
                  ELSIF v_max_sec_use_fgdiari < 0 AND v_max_sec_use_fgdiari > -10 THEN
                     --p_horamov := pag_gen.FU_OBT_SIG_SEGUNDO(p_horamov);
                     p_horamov             := fug_obt_hor_disponible(v_fcproce, p_horamov, USER, v_es_nocturno);
                     v_max_sec_use_fgdiari := 0;
                  END IF;
                  --
                  p_lugar                 := ' Carga registro rg_movs ';
                  rg_movs.cod_transaccion := 1499;
                  rg_movs.cod_modulo      := 14;
                  rg_movs.cod_modalidad   := 141;
                  rg_movs.cod_tra_padre   := v_tranpdb;
                  rg_movs.cod_mod_padre   := 14;
                  rg_movs.cod_mad_padre   := 141;
                  rg_movs.monto           := v_Total_Credito;
                  rg_movs.cod_moneda      := v_cdmoned;
                  --
                  rg_movs.nro_cuenta     := NULL; --v_ctadbsu;
                  rg_movs.cod_oficina    := v_cdofici;
                  rg_movs.COD_USUARIO    := p_usuario;
                  rg_movs.hora           := p_horamov;
                  rg_movs.fecha          := pag_cal.FU_OBT_FEC_ACTUAL(1);
                  rg_movs.nro_secuencia  := v_max_sec_use_fgdiari + 1;
                  rg_movs.fec_valor      := pag_cal.FU_OBT_FEC_ACTUAL(1);
                  rg_movs.nro_documento  := nvl(v_remito, v_nro_documento); --RI: 07/06/2010 Nro_docuemento si tiene o sino el codigo de ente
                  rg_movs.nro_documento3 := p_cod_ente;
                  rg_movs.cod_tasa       := NULL;
                  rg_movs.val_tasa       := NULL;
                  rg_movs.cotizacion     := NULL;
                  rg_movs.emi_aviso      := 'N';
                  rg_movs.cod_ofi_origen := nvl(v_cdofior, p_cdofici);
                  rg_movs.concepto       := v_cnmovim;
                  rg_movs.estado         := 'N';
                  rg_movs.est_cuenta     := 'N';
                  rg_movs.reversado      := 'N';
                  rg_movs.emi_aviso      := 'N';
                  --
                  rg_movs.nro_caja      := NULL; --to_number(p_nro_caja);
                  rg_movs.cod_rubro     := v_nro_cta_contable_txt;
                  rg_movs.tip_mov_rubro := 'D'; -- débito
                  --
                  p_lugar := 'LP_INS_MOV_SUELDO->PAG_GEN.PR_INS_GE_MOVIMIENTO , inserta mov E ';
                  pr_ins_bitacora(p_lote, NULL, p_lugar);
                  -- 13/12/2010 OMM Para pagar en sistema cerrado
                  PAG_GEN.PR_INS_GE_MOVIMIENTO(rg_movs, v_es_nocturno);
               END IF; --- filtro agregado para RRHH
            END IF;
         END IF;
         --- Actualizar como procesados los registros
         IF nvl(p_hubo_error, 'N') = 'N' THEN
            UPDATE GE_PAG_SUELDOS
               SET PROCESADO = 'S'
             WHERE cod_ente = p_cod_ente
                   AND fec_proceso = p_fec_hoy
                   AND nro_secuencia = p_nro_secuencia
                   AND nvl(cod_proceso, 0) = 0;
         
         ELSIF P_HUBO_ERROR = 'Z' THEN
            p_lugar := 'No se encontraron cuentas de Crédito. ';
            pr_ins_bitacora(p_lote, NULL, p_lugar);
         END IF;
         BEGIN
            SELECT SUM(monto)
              INTO v_mto_debito
              FROM ge_pag_sueldos
             WHERE cod_ente = p_cod_ente
                   AND fec_proceso = P_FEC_HOY
                   AND nro_secuencia = p_nro_secuencia
                   AND tipo = 'D';
         EXCEPTION
            WHEN no_data_found THEN
               P_HUBO_ERROR := 'Z';
         END;
      
         IF v_mto_credito > 0 THEN
            --Actualizar el registro de débito
            IF v_pro_con_errores = 'N' THEN
               UPDATE ge_pag_sueldos
                  SET monto = v_mto_credito
                WHERE cod_ente = p_cod_ente
                      AND fec_proceso = P_FEC_HOY
                      AND nro_secuencia = p_nro_secuencia
                      AND tipo = 'D';
            END IF;
         END IF;
         --- Limpiar el seteo del nro_documento3
         pr_ins_bitacora(p_lote, NULL, 'LP_INS_MOV_SUELDO: Limpiar el seteo del nro_documento3');
         pag_cta.PR_SET_NRO_DOCUMENTO3(NULL);
      
         p_sec_sgt_movimiento := rg_movs.nro_secuencia;
      END;
   END lp_ins_mov_sueldo;

   PROCEDURE LP_INS_TABLA(P_ERROR           OUT VARCHAR2,
                          P_NRO_ARCHIVO     IN NUMBER DEFAULT NULL,
                          P_PRO_CON_ERRORES IN VARCHAR2 DEFAULT 'N',
                          P_LOTE            IN ge_pag_sue_ips.nro_lote%TYPE) IS
      v_nro_cuenta ge_pag_sueldos.nro_cuenta%TYPE;
   
      P_FEC_HOY GE_PAG_SUELDOS.FEC_PROCESO%TYPE := trunc(SYSDATE);
   
      v_mto_debito    ge_pag_sueldos.monto%TYPE := 0;
      v_cod_proceso   ge_pag_sueldos.cod_proceso%TYPE := 0;
      v_cod_modulo    ge_cuentas.cod_modulo%TYPE;
      v_cod_modalidad ge_cuentas.cod_modalidad%TYPE;
      v_cod_oficina   ge_cuentas.cod_oficina%TYPE;
      v_cod_moneda    ge_cuentas.cod_moneda%TYPE;
      v_estado        ge_cuentas.estado%TYPE;
      p_cod_ente      ge_pag_sueldos.cod_ente%TYPE;
      --estructura que representa el archivo (cabecera y detalle)
      v_lote typ_lotepagosueldoips := typ_lotepagosueldoips();
   
      v_pago typ_pagosueldoips := typ_pagosueldoips();
   
      v_mensaje_error ge_pag_sue_ips.comentarios%TYPE;
   
      --cursor con los datos del lote a procesar.
      CURSOR c_lote_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT c.*
           FROM ge_pag_sue_ips c
          WHERE c.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado o procesado
                AND trunc(c.fec_acreditacion) <= trunc(SYSDATE) --lote a acreditar
                AND trunc(c.fec_vencimiento) >= trunc(SYSDATE); --lote vigente
   
      CURSOR c_lotes_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT d.*
           FROM ge_pag_sue_ips_det d
           JOIN ge_pag_sue_ips c
             ON d.nro_lote = c.nro_lote
          WHERE d.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado y procesado.
                AND d.estado = 'P' -- Pendientes de acreditación
                AND d.fec_acreditacion IS NULL
                AND d.fe_vida = 'S'; -- fe de vida vigente
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
   
      v_lote.estado      := 'P';
      v_lote.comentarios := '';
   
      P_ERROR := 'N';
   
      BEGIN
         SELECT ge.cod_ente
           INTO p_cod_ente
           FROM ge_pag_sue_ips ge
          WHERE ge.nro_lote = P_LOTE;
      EXCEPTION
         WHEN no_data_found THEN
            P_ERROR := 'S';
            pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: No se encuentran los datos del Ente: ' || p_cod_ente);
      END;
   
      IF P_ERROR != 'S' THEN
         --- CUENTAS CRÉDITOS ---
         FOR reg IN c_lotes_pagos(p_lote)
         LOOP
            v_nro_cuenta := reg.nro_cta_jubilado;
         
            v_pago.nroLote           := reg.nro_lote;
            v_pago.nroCtaJubilado    := reg.nro_cta_jubilado;
            v_pago.nroDocJubilado    := reg.nro_doc_jubilado;
            v_pago.importe           := reg.importe;
            v_pago.nroOrden          := reg.nro_orden;
            v_pago.fechaAcreditacion := SYSDATE;
            v_pago.estado            := 'A';
            v_pago.comentarios       := '';
         
            BEGIN
               SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado
                 INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado
                 FROM GE_CUENTAS A
                WHERE A.Nro_Cuenta = v_nro_cuenta;
            EXCEPTION
               WHEN no_data_found THEN
                  v_mensaje_error    := 'Cuenta Inexistente: ' || v_nro_cuenta;
                  v_pago.comentarios := v_mensaje_error;
                  v_pago.estado      := 'E';
               
                  P_ERROR       := 'S';
                  v_cod_proceso := 12;
               
                  pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: ' || v_mensaje_error);
               WHEN OTHERS THEN
                  pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: Error en la cuenta: ' || v_nro_cuenta || SQLERRM);
            END;
            /*RI : 23/02/2010 : cuando es rubro contable en la cuenta debito
            se recibe 999999999999999 */
            IF (reg.nro_cta_jubilado IS NULL OR reg.nro_cta_jubilado <> '999999999999999') AND p_pro_con_errores = 'C' THEN
               v_mensaje_error := 'Cuenta Inexistente';
            
               v_pago.comentarios := v_mensaje_error;
               v_pago.estado      := 'E';
            
               P_ERROR       := 'S';
               v_cod_proceso := 12;
            
               pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: ' || v_mensaje_error);
            ELSE
               pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: Cuenta: ' || reg.nro_cta_jubilado || '| Monto: ' || reg.importe);
               --acumulamos las acreditaciones
               v_mto_debito := v_mto_debito + reg.importe;
               --insertamos los créditos
               --se almacena el cod. del detalle en el campo observación.
               INSERT INTO ge_pag_sueldos
                  (cod_ente, fec_proceso, nro_secuencia, nro_cuenta, cod_moneda, fec_envio,
                   --
                   tipo, monto, estado, cod_proceso, cod_modulo, cod_modalidad, nro_documento, observacion)
               VALUES
                  (P_COD_ENTE, p_fec_hoy, p_nro_archivo, v_pago.nroCtaJubilado, v_cod_moneda, p_fec_hoy,
                   --
                   'C', v_pago.importe, 'N', v_cod_proceso, v_cod_modulo, v_cod_modalidad, v_pago.nroDocJubilado, v_pago.nroOrden);
            END IF;
         
            --si es error no se registra la fecha de acreditacion
            IF v_pago.estado = 'E' THEN
               LP_ACT_PAGO(v_pago, FALSE);
            ELSE
               LP_ACT_PAGO(v_pago, TRUE);
            END IF;
         END LOOP;
      
         IF v_mto_debito > 0 THEN
            --- CUENTA DÉBITO ---
            BEGIN
               --traemos los datos del lote
               FOR c_lote IN c_lote_pagos(p_lote)
               LOOP
                  v_nro_cuenta       := c_lote.nro_cta_pag_salario;
                  v_lote.estado      := 'P';
                  v_lote.comentarios := '';
                  v_lote.nroLote     := c_lote.nro_lote;
               
                  IF (v_nro_cuenta IS NULL OR v_nro_cuenta <> '999999999999999') AND p_pro_con_errores = 'C' THEN
                     v_mensaje_error    := 'Cuenta Inexistente';
                     v_lote.comentarios := v_mensaje_error;
                     v_lote.estado      := 'E';
                  
                     P_ERROR       := 'S';
                     v_cod_proceso := 12;
                  
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_mensaje_error);
                  ELSE
                     SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado
                       INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado
                       FROM GE_CUENTAS A
                      WHERE A.Nro_Cuenta = v_nro_cuenta;
                  
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_nro_cuenta || '|' || v_mto_debito);
                  
                     --para los débitos, guardamos el codigo de lote en el campo observacion
                     INSERT INTO ge_pag_sueldos
                        (cod_ente, fec_proceso, nro_secuencia, nro_cuenta,
                         --
                         cod_moneda, fec_envio, tipo, monto, estado, cod_proceso, cod_modulo, cod_modalidad, observacion)
                     VALUES
                        (c_lote.cod_ente, p_fec_hoy, p_nro_archivo, v_nro_cuenta,
                         --
                         v_cod_moneda, p_fec_hoy, 'D', v_mto_debito, 'N', v_cod_proceso, v_cod_modulo, v_cod_modalidad, p_lote);
                  
                  END IF;
                  LP_ACT_LOTE(v_lote, FALSE);
               END LOOP;
            END;
         ELSE
            P_ERROR            := 'S';
            v_mensaje_error    := 'Monto débito: ' || v_mto_debito || ' inconsistente. Verifique.';
            v_lote.comentarios := v_mensaje_error;
            v_lote.estado      := 'E';
         
            pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_mensaje_error);
         
            LP_ACT_LOTE(v_lote, FALSE);
         END IF;
      ELSE
         P_ERROR            := 'S';
         v_lote.estado      := 'E';
         v_mensaje_error    := 'No se pudo procesar el lote: ' || p_lote || '. Verifique.';
         v_lote.comentarios := v_mensaje_error;
         LP_ACT_LOTE(v_lote, FALSE);
      
         pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_mensaje_error);
      END IF;
   END lp_ins_tabla;

   /*
   * BSEVOCORE-451 NAF 05/2020
   * Inserta sublotes para el pago de sueldos
   */
   PROCEDURE LP_INS_TABLA(P_ERROR           OUT VARCHAR2,
                          P_NRO_ARCHIVO     IN NUMBER DEFAULT NULL,
                          P_PRO_CON_ERRORES IN VARCHAR2 DEFAULT 'N',
                          P_LOTE            IN ge_pag_sue_ips.nro_lote%TYPE,
                          P_SUBLOTE         IN ge_pag_sue_ips_sublotes.nro_sublote%TYPE) IS
      v_nro_cuenta ge_pag_sueldos.nro_cuenta%TYPE;
   
      P_FEC_HOY GE_PAG_SUELDOS.FEC_PROCESO%TYPE := trunc(SYSDATE);
   
      v_mto_debito    ge_pag_sueldos.monto%TYPE := 0;
      v_cod_proceso   ge_pag_sueldos.cod_proceso%TYPE := 0;
      v_cod_modulo    ge_cuentas.cod_modulo%TYPE;
      v_cod_modalidad ge_cuentas.cod_modalidad%TYPE;
      v_cod_oficina   ge_cuentas.cod_oficina%TYPE;
      v_cod_moneda    ge_cuentas.cod_moneda%TYPE;
      v_estado        ge_cuentas.estado%TYPE;
      p_cod_ente      ge_pag_sueldos.cod_ente%TYPE;
      --estructura que representa el archivo (cabecera y detalle)
      v_lote typ_lotepagosueldoips := typ_lotepagosueldoips();
   
      v_pago typ_pagosueldoips := typ_pagosueldoips();
   
      v_mensaje_error ge_pag_sue_ips.comentarios%TYPE;
   
      --cursor con los datos del lote a procesar.
      CURSOR c_lote_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT c.*
           FROM ge_pag_sue_ips c
          WHERE c.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado o procesado
                AND trunc(c.fec_acreditacion) <= trunc(SYSDATE) --lote a acreditar
                AND trunc(c.fec_vencimiento) >= trunc(SYSDATE); --lote vigente
   
      CURSOR c_lotes_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT d.*
           FROM ge_pag_sue_ips_det d
           JOIN ge_pag_sue_ips c
             ON d.nro_lote = c.nro_lote
           JOIN ge_pag_sue_ips_sublotes e
             ON e.nro_lote = d.nro_lote and
                e.nro_orden = d.nro_orden and
                e.nro_sublote = P_SUBLOTE
          WHERE d.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado y procesado.
                AND d.estado = 'P' -- Pendientes de acreditación
                AND d.fec_acreditacion IS NULL
                AND d.fe_vida = 'S'; -- fe de vida vigente
   BEGIN
      BEGIN
         pre_ini_aplicacion;
         pae_cnf.g_cod_modulo := 1;
      END;
   
      v_lote.estado      := 'P';
      v_lote.comentarios := '';
   
      P_ERROR := 'N';
   
      BEGIN
         SELECT ge.cod_ente
           INTO p_cod_ente
           FROM ge_pag_sue_ips ge
          WHERE ge.nro_lote = P_LOTE;
      EXCEPTION
         WHEN no_data_found THEN
            P_ERROR := 'S';
            pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: No se encuentran los datos del Ente: ' || p_cod_ente  || ' - sublote: ' || p_sublote);
      END;
   
      IF P_ERROR != 'S' THEN
         --- CUENTAS CRÉDITOS ---
         FOR reg IN c_lotes_pagos(p_lote)
         LOOP
            v_nro_cuenta := reg.nro_cta_jubilado;
         
            v_pago.nroLote           := reg.nro_lote;
            v_pago.nroCtaJubilado    := reg.nro_cta_jubilado;
            v_pago.nroDocJubilado    := reg.nro_doc_jubilado;
            v_pago.importe           := reg.importe;
            v_pago.nroOrden          := reg.nro_orden;
            v_pago.fechaAcreditacion := SYSDATE;
            v_pago.estado            := 'A';
            v_pago.comentarios       := '';
         
            BEGIN
               SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado
                 INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado
                 FROM GE_CUENTAS A
                WHERE A.Nro_Cuenta = v_nro_cuenta;
            EXCEPTION
               WHEN no_data_found THEN
                  v_mensaje_error    := 'Cuenta Inexistente: ' || v_nro_cuenta;
                  v_pago.comentarios := v_mensaje_error;
                  v_pago.estado      := 'E';
               
                  P_ERROR       := 'S';
                  v_cod_proceso := 12;
               
                  pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
               WHEN OTHERS THEN
                  pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: Error en la cuenta: ' || v_nro_cuenta || SQLERRM  || ' - sublote: ' || p_sublote);
            END;
            /*RI : 23/02/2010 : cuando es rubro contable en la cuenta debito
            se recibe 999999999999999 */
            IF (reg.nro_cta_jubilado IS NULL OR reg.nro_cta_jubilado <> '999999999999999') AND p_pro_con_errores = 'C' THEN
               v_mensaje_error := 'Cuenta Inexistente';
            
               v_pago.comentarios := v_mensaje_error;
               v_pago.estado      := 'E';
            
               P_ERROR       := 'S';
               v_cod_proceso := 12;
            
               pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
            ELSE
               pr_ins_bitacora(p_lote, v_pago.nroOrden, 'LP_INS_TABLA: Cuenta: ' || reg.nro_cta_jubilado || '| Monto: ' || reg.importe || ' - sublote: ' || p_sublote);
               --acumulamos las acreditaciones
               v_mto_debito := v_mto_debito + reg.importe;
               --insertamos los créditos
               --se almacena el cod. del detalle en el campo observación.
               INSERT INTO ge_pag_sueldos
                  (cod_ente, fec_proceso, nro_secuencia, nro_cuenta, cod_moneda, fec_envio,
                   --
                   tipo, monto, estado, cod_proceso, cod_modulo, cod_modalidad, nro_documento, observacion)
               VALUES
                  (P_COD_ENTE, p_fec_hoy, p_nro_archivo, v_pago.nroCtaJubilado, v_cod_moneda, p_fec_hoy,
                   --
                   'C', v_pago.importe, 'N', v_cod_proceso, v_cod_modulo, v_cod_modalidad, v_pago.nroDocJubilado, v_pago.nroOrden);
            END IF;
         
            --si es error no se registra la fecha de acreditacion
            IF v_pago.estado = 'E' THEN
               LP_ACT_PAGO(v_pago, FALSE);
            ELSE
               LP_ACT_PAGO(v_pago, TRUE);
            END IF;
         END LOOP;
      
         IF v_mto_debito > 0 THEN
            --- CUENTA DÉBITO ---
            BEGIN
               --traemos los datos del lote
               FOR c_lote IN c_lote_pagos(p_lote)
               LOOP
                  v_nro_cuenta       := c_lote.nro_cta_pag_salario;
                  v_lote.estado      := 'P';
                  v_lote.comentarios := '';
                  v_lote.nroLote     := c_lote.nro_lote;
               
                  IF (v_nro_cuenta IS NULL OR v_nro_cuenta <> '999999999999999') AND p_pro_con_errores = 'C' THEN
                     v_mensaje_error    := 'Cuenta Inexistente';
                     v_lote.comentarios := v_mensaje_error;
                     v_lote.estado      := 'E';
                  
                     P_ERROR       := 'S';
                     v_cod_proceso := 12;
                  
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                  ELSE
                     SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado
                       INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado
                       FROM GE_CUENTAS A
                      WHERE A.Nro_Cuenta = v_nro_cuenta;
                  
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_nro_cuenta || '|' || v_mto_debito || ' - sublote: ' || p_sublote);
                  
                     --para los débitos, guardamos el codigo de lote en el campo observacion
                     INSERT INTO ge_pag_sueldos
                        (cod_ente, fec_proceso, nro_secuencia, nro_cuenta,
                         --
                         cod_moneda, fec_envio, tipo, monto, estado, cod_proceso, cod_modulo, cod_modalidad, observacion)
                     VALUES
                        (c_lote.cod_ente, p_fec_hoy, p_nro_archivo, v_nro_cuenta,
                         --
                         v_cod_moneda, p_fec_hoy, 'D', v_mto_debito, 'N', v_cod_proceso, v_cod_modulo, v_cod_modalidad, p_lote);
                  
                  END IF;
                  LP_ACT_LOTE(v_lote, FALSE);
               END LOOP;
            END;
         ELSE
            P_ERROR            := 'S';
            v_mensaje_error    := 'Monto débito: ' || v_mto_debito || ' inconsistente. Verifique.';
            v_lote.comentarios := v_mensaje_error;
            v_lote.estado      := 'E';
         
            pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
         
            LP_ACT_LOTE(v_lote, FALSE);
         END IF;
      ELSE
         P_ERROR            := 'S';
         v_lote.estado      := 'E';
         v_mensaje_error    := 'No se pudo procesar el lote: ' || p_lote || '. Verifique.';
         v_lote.comentarios := v_mensaje_error;
         LP_ACT_LOTE(v_lote, FALSE);
      
         pr_ins_bitacora(p_lote, NULL, 'LP_INS_TABLA: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
      END IF;
   END lp_ins_tabla;

   PROCEDURE LP_ACR_EMPLEADO(P_COD_ENTE       IN ge_pag_sue_ips.cod_ente%TYPE,
                             p_lote           IN ge_pag_sue_ips.nro_lote%TYPE,
                             P_NRO_SECUENCIA  IN OUT NUMBER,
                             P_CDOFICI        IN NUMBER,
                             P_FEC_HOY        IN GE_PAG_SUELDOS.FEC_PROCESO%TYPE,
                             P_USUARIO        IN VARCHAR2,
                             P_HUBO_ERROR     OUT VARCHAR2,
                             P_TIPO_TRA_PADRE IN VARCHAR2,
                             P_HOR_MOVIMIENTO IN VARCHAR2 DEFAULT NULL,
                             P_SUBLOTE        IN NUMBER DEFAULT NULL) IS
      --estructura que representa el pago a acreditar
      v_pago                 typ_pagosueldoips := typ_pagosueldoips();
      v_cob_aut_atr_tarjetas ge_par_dinamicos.val_parametro%TYPE;
      v_tar_cob_aut_atr_itgf ge_par_dinamicos.val_parametro%TYPE;
      P_LUGAR                VARCHAR2(1000);
      v_str_sublote          varchar2(50) := '';
   BEGIN
      if P_SUBLOTE is not null then
         v_str_sublote := ' - sublote: ' || P_SUBLOTE;
      end if;
      DECLARE
         v_hrmovim            VARCHAR2(08);
         v_sec_sgt_movimiento NUMBER;
         v_error              VARCHAR2(4000);
         -- C -> Cancela los pagos.
         -- N -> Pagos parciales
         v_pro_con_errores VARCHAR2(1) := UPPER(fug_obt_parentes(P_COD_ENTE, 'PRO_CON_ERRORES'));
      
         CURSOR err(p_cod_ente      ge_pag_sueldos.cod_ente%TYPE,
                    p_fec_proceso   ge_pag_sueldos.fec_proceso%TYPE,
                    p_nro_secuencia ge_pag_sueldos.nro_secuencia%TYPE) IS
            SELECT *
              FROM ge_pag_sueldos
             WHERE cod_ente = p_cod_ente
                   AND trunc(fec_proceso) = trunc(p_fec_proceso)
                   AND nro_secuencia = p_nro_secuencia
                   AND tipo = 'C'
                   AND nvl(cod_proceso, 0) <> 0;
      
      BEGIN
         IF p_hor_movimiento IS NOT NULL THEN
            v_hrmovim := p_hor_movimiento;
         END IF;
      
         p_lugar := 'proc: LP_ACR_EMPLEADO :llama a LP_INS_MOV_SUELDO Procesar movimiento';
         --insertar en bitácora
         pr_ins_bitacora(p_lote, NULL, p_lugar || v_str_sublote);
      
         LP_INS_MOV_SUELDO(p_hubo_error, v_hrmovim, p_cod_ente, p_lote, p_nro_secuencia, p_lugar, p_cdofici, p_fec_hoy,
                           --
                           p_usuario, P_TIPO_TRA_PADRE, v_sec_sgt_movimiento);
      
         IF p_hubo_error IN ('N', 'C') AND p_tipo_tra_padre IN ('S', 'A') THEN
            -- agregado para liquidar el anticipo y/o aguinaldo
            -- seteo las variables de hora y secuencia para el debito automatico
            pae_cnf.PR_SET_VARIABLES(v_hrmovim, v_sec_sgt_movimiento);
            BEGIN
               LP_LIQ_ANTICIPOS(p_lote, p_cod_ente, p_tipo_tra_padre);
            EXCEPTION
               WHEN OTHERS THEN
                  v_error      := SQLERRM;
                  p_lugar      := 'Liquidacion de Anticipos ' || SQLERRM;
                  p_hubo_error := 'S';
               
                  pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO' || p_lugar  || v_str_sublote);
            END;
            --DYDMR-8896 Incidencia SAU - ITGF - Error Acreditación de Pasantes Universitarios.
         ELSIF p_hubo_error = 'S' THEN
            p_hubo_error := 'Z';
            p_lugar      := ' Error detectado en LP_INS_MOV_SUELDO. Verifique!';
            pr_ins_bitacora(p_lote, NULL, p_lugar || v_str_sublote);
         ELSE
            -- seteo las variables de hora y secuencia para el debito automatico
            pae_cnf.PR_SET_VARIABLES(v_hrmovim, v_sec_sgt_movimiento);
         END IF;
      
         /* OMM 19/01/2015. Se realiza el proceso de Debito Automático en caso de Pagos On-line que no corresponda a Aguinaldo
         y que sea via Web, en caso del Programa realiza el Debito automático en el Programa según indicación  */
         IF p_hubo_error IN ('N', 'C') AND p_tipo_tra_padre <> 'A' AND nvl(PAE_CNF.G_PROGRAMA, 'x') <> 'GPPAGSUE' THEN
            p_lugar := 'Procesando LP_PRO_DEB_AUTOMATICO.';
            pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO' || p_lugar || v_str_sublote);
         
            LP_PRO_DEB_AUTOMATICO(p_cod_ente, p_lote, p_nro_secuencia, p_fec_hoy, v_error);
         
            BEGIN
                prt_deb_automatico(null, null, p_cod_ente, p_nro_secuencia, p_fec_hoy);
            EXCEPTION
              WHEN OTHERS THEN
               v_error := substr('Tarjetas prt_deb_automatico '||sqlerrm,1,1000);
               pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO ' || v_error || v_str_sublote);
            END;
            --Proyecto PCCDEEVO-1046 - Optimizacion--
            v_cob_aut_atr_tarjetas := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_TARJETAS'), 'N');
            v_tar_cob_aut_atr_itgf := nvl(fug_obt_pardinamico('TAR_COB_AUT_ATR_ITGF'), 'N');
            IF v_cob_aut_atr_tarjetas = 'S' THEN
               IF v_tar_cob_aut_atr_itgf = 'S' THEN
                  prt_deb_automatico_atr(NULL, NULL, p_cod_ente, p_nro_secuencia, p_fec_hoy);
               END IF;
            END IF;
            -----------------------------------------
         END IF;
      
         IF p_hubo_error IN ('S') THEN
            --p_lugar := 'proc: LP_ACR_EMPLEADO : llama a LP_INS_ERROR_PROCESO - cod error de proceso ';
         
            IF P_HUBO_ERROR <> 'P' THEN
               p_hubo_error := 'N';
            END IF;
         
            -- borro los registros procesados
            p_lugar := 'Borrando datos de ge_pag_sueldos';
            pr_ins_bitacora(p_lote, NULL, p_lugar || v_str_sublote);
            IF nvl(v_pro_con_errores, 'N') = 'C' THEN
               DELETE FROM ge_pag_sueldos
                WHERE cod_ente = p_cod_ente
                      AND fec_proceso = p_fec_hoy
                      AND nro_secuencia = p_nro_secuencia;
               --Verificar si el monto registrado corresponde a lo debitado
            ELSE
               --recorro el cursor para ir insertando cada cuenta con error en la tabla de errores.
               FOR c IN err(p_cod_ente, p_fec_hoy, p_nro_secuencia)
               LOOP
                  pag_sue.pr_ins_errores(c.nro_cuenta, c.cod_ente, c.fec_proceso, c.nro_secuencia, c.cod_moneda, c.monto, 'C',
                                         --credito
                                         '10', 'Error al acreditar en cuenta nro. ' || c.nro_cuenta);
               
                  --TODO actualizar los comentarios y estado de los registros.
                  v_pago.estado      := 'E';
                  v_pago.comentarios := 'Error al acreditar en cuenta nro. ' || c.nro_cuenta;
                  pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO' || p_lugar || v_str_sublote);
               END LOOP;
            
               DELETE FROM ge_pag_sueldos
                WHERE cod_ente = p_cod_ente
                      AND fec_proceso = p_fec_hoy
                      AND nro_secuencia = p_nro_secuencia
                      AND nvl(cod_proceso, 0) <> 0;
            END IF;
            --- ahora hago raise para que de el error y no deje procesado nada
         ELSIF p_hubo_error IN ('N', 'C') THEN
            p_lugar := 'proc: LP_ACR_EMPLEADO : Proceso Terminado sin Errores ....';
            pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO' || p_lugar || v_str_sublote);
         
            IF p_hubo_error = 'C' THEN
               p_lugar := 'NO SE PUDO COBRAR LA COMISION...VERIFIQUE...';
               pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO' || p_lugar || v_str_sublote);
            END IF;
         ELSIF p_hubo_error = 'X' THEN
            --- quiso procesar otro ente distinto al verificado
            p_lugar := 'Trato de procesar otro Ente '; --- en el programa despliega el mensaje de error para no borrar datos del tmp
            pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO' || p_lugar || v_str_sublote);
         ELSIF p_hubo_error = 'Z' THEN
            IF v_pro_con_errores = 'N' THEN
               DELETE FROM ge_pag_sueldos
                WHERE cod_ente = p_cod_ente
                      AND fec_proceso = p_fec_hoy
                      AND nro_secuencia = p_nro_secuencia;
               COMMIT;
               p_lugar := ' No se encuentran cuentas de Crédito. Verifique!';
               pr_ins_bitacora(p_lote, NULL, 'LP_ACR_EMPLEADO' || p_lugar || v_str_sublote);
            END IF;
         END IF;
      END;
   
   END LP_ACR_EMPLEADO;

   /*
   BSEVOCORE-426 NAF 03/2020
   Actualiza estado de registros de GE_PAG_SUE_IPS_REP_TMP para control y envio 
   de mensajes en caso de error en acreditaciones de clientes con actualización de Fe de Vida
   */
   PROCEDURE LP_ACT_TMP_REPROCESO( p_nro_lote GE_PAG_SUE_IPS_DET.NRO_LOTE%type, 
                                   p_nro_orden GE_PAG_SUE_IPS_DET.NRO_ORDEN%type,
                                   p_estado varchar2 default 'P') IS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     update GE_PAG_SUE_IPS_REP_TMP set estado = p_estado
     where NRO_LOTE = p_nro_lote and NRO_ORDEN = p_nro_orden
           and estado = 'I';
     commit;
   EXCEPTION
      when others then
        null;
   END;
        
   /**
   * Procedimiento que inserta los registros a partir del lote remitido por IPS a la tabla ge_pag_sueldos.
   */
   PROCEDURE LP_INS_PAG_SUELDO(p_verifica_ok   IN OUT VARCHAR2,
                               P_CANT_ERROR    IN OUT NUMBER,
                               p_error         OUT VARCHAR2,
                               p_lote          IN ge_pag_sue_ips.nro_lote%TYPE,
                               p_nro_secuencia IN NUMBER,
                               p_tipo varchar2 default null) IS
      /* Definición de Variables */
      v_Tot_Debito     NUMBER(18, 2) := 0;
      v_Tot_Credito    NUMBER(18, 2) := 0;
      v_Tot_Acreditado NUMBER(18, 2) := 0; -- total de creditos realizados
   
      v_min_fec DATE;
      v_max_fec DATE;
      v_cantreg NUMBER(5) := 0;
      -------------------
      v_fech_env DATE;
   
      v_tip_movimiento    VARCHAR2(01);
      v_mensaje_error     VARCHAR2(1000) := '';
      v_cod_moneda        VARCHAR2(03);
      v_cod_mon_debito    VARCHAR2(03);
      v_est_movimiento    VARCHAR2(01);
      v_estado_nuevo      VARCHAR2(01);
      v_puede_procesar    VARCHAR2(01);
      v_tas_personalizada VARCHAR2(01);
      v_cod_modulo        NUMBER(03);
      v_cod_modalidad     NUMBER(03);
      v_estado            ge_cuentas.estado%TYPE;
      v_cod_oficina       NUMBER(03);
      v_sldisponible      NUMBER(18, 2);
      v_Secuencia         NUMBER(03);
      v_Codigo_Error      NUMBER(03);
   
      v_cta_ok     VARCHAR2(1) := 'N';
      v_cta_ok_deb VARCHAR2(1) := 'N';
      --v_esAguinaldo VARCHAR2(1) := 'N';
      --v_traspaso VARCHAR2(1) := 'N';
      v_cod_ente NUMBER;
      p_tranpdb  NUMBER;
   
      v_cta_debito_txt ge_pag_sueldos.nro_cuenta%TYPE;
      v_con_error      NUMBER;
      v_cont           NUMBER := 0;
   
      p_TCreDet NUMBER := 0; -- total de credito
      p_cCreDet NUMBER := 0; --
      p_TCreCab NUMBER := 0;
   
      --para la bitácora
      p_lugar VARCHAR2(100);
   
      v_val_cta VARCHAR2(2);
   
      --estructura que representa el archivo (cabecera y detalle)
      v_lote typ_lotepagosueldoips := typ_lotepagosueldoips();
   
      --estructura que representa la lista de pagos a acreditar
      v_pago typ_pagosueldoips := typ_pagosueldoips();
   
      --Nro. Doc. por defecto
      v_nro_doc_generico NUMBER := fug_obt_pardinamico('NRO_DOC_GEN_PAG_SAL');
   
      -- Si es igual a N= se puede procesar con errores el lote C= cancelar, no se puede procesar con errores
      v_pro_con_errores VARCHAR2(1);
      
      -- controlar si cursor no devuelve registros DYDMR-13833 / pruebas contingencia 2020
      v_con_reg_lote  number(1); 
      v_con_reg_pagos number(1);
      
      --cursor con los datos del lote a procesar.
      CURSOR c_lote_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT c.*,
                (SELECT COUNT(*)
                    FROM ge_pag_sue_ips_det d
                   WHERE d.nro_lote = c.nro_lote
                         AND d.estado = 'P') cantidad
           FROM ge_pag_sue_ips c
          WHERE c.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado o procesado
                AND trunc(c.fec_acreditacion) <= trunc(SYSDATE) --lote a acreditar
                AND trunc(c.fec_vencimiento) >= trunc(SYSDATE); --lote vigente
   
      -- trae todos los registros del lote a pagar
      -- se valida con cabecera con estado verificado o procesado
      CURSOR c_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT d.*
           FROM ge_pag_sue_ips_det d
           JOIN ge_pag_sue_ips c
             ON d.nro_lote = c.nro_lote
          WHERE d.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado o procesado
                AND D.Fec_Acreditacion IS NULL --aun no pagados
                AND d.estado = 'P' -- registros con estado pendientes de acreditación
                AND d.fe_vida = 'S'; -- fe de vida vigente
   
   BEGIN
      BEGIN
         --secuencia para el lote de pagos en ge_pag_sueldos
         v_secuencia := p_nro_secuencia;
         p_TCreDet   := 0; -- total de credito
         p_cCreDet   := 0; --
      
         BEGIN
            v_con_reg_lote := 0;
            --traemos los datos del lote
            FOR c_lote IN c_lote_pagos(p_lote)
            LOOP
               --almacenamos los datos del lote de pago.
               v_lote.estado            := 'P'; --Procesado
               v_lote.fechaAcreditacion := c_lote.fec_acreditacion;
               v_lote.tipoProceso       := c_lote.tip_proceso;
               v_lote.nroLote           := c_lote.nro_lote;
               v_con_reg_lote           := 1;
            
               -- si no hay detalles a pagar, se coloca con Error el lote.
               --todo
               IF c_lote.cantidad = 0 THEN
                  SELECT COUNT(*)
                    INTO P_CANT_ERROR
                    FROM ge_pag_sue_ips_det ged
                    JOIN ge_pag_sue_ips ge
                      ON ge.nro_lote = ged.nro_lote
                   WHERE ged.nro_lote = p_lote
                         AND ge.estado = 'V'
                         AND ged.estado = 'E'
                         AND ged.fe_vida = 'S';
               
                  v_cta_ok_deb    := 'S';
                  v_mensaje_error := 'Lote sin detalles a acreditar.';
                  pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
               
                  p_error := v_mensaje_error;
               
                  RETURN;
               END IF;
            
               -- Se verifican los datos leidos....
               -- total de debitos,
               -- se toma fecha min como fecha de acreditación y fecha maxima la fecha de vencimiento
               -- se obtiene de la cuenta donde se debe realizar el debito
               v_Tot_debito     := c_lote.mto_debito;
               v_min_fec        := c_lote.fec_acreditacion;
               v_max_fec        := c_lote.fec_vencimiento;
               v_cta_debito_txt := c_lote.nro_cta_pag_salario;
               v_cod_ente       := c_lote.cod_ente;
            
               BEGIN
                  p_verifica_ok := 'S';
               
                  -- Si es igual a N= se puede procesar con errores el lote C= cancelar, no se puede procesar con errores
                  v_pro_con_errores := UPPER(NVL(fug_obt_parentes(v_cod_ente, 'PRO_CON_ERRORES'), 'N'));
               
                  --- total de importe a pagar a jubilados, se cuenta la cantidad de registros
                  SELECT SUM(ged.importe), COUNT(*)
                    INTO v_Tot_credito, v_cantreg
                    FROM GE_PAG_SUE_IPS_DET ged
                    JOIN GE_PAG_SUE_IPS ge
                      ON ged.nro_lote = ge.nro_lote
                   WHERE ged.nro_lote = p_lote
                         AND ge.estado IN ('V', 'P') --cabecera validada o acreditada parcialmente
                         AND ged.estado = 'P' --pagos pendientes de acreditación
                         AND ged.fe_vida = 'S' --fe de vida vigente
                         AND TRUNC(ge.fec_acreditacion) <= TRUNC(SYSDATE)
                         AND TRUNC(ge.fec_vencimiento) >= TRUNC(SYSDATE);
               
                  IF v_cta_debito_txt IS NOT NULL THEN
                     p_lugar := 'LP_INS_PAG_SUELDO->LP_OBT_DAT_CUENTA';
                     pr_ins_bitacora(p_lote, NULL, p_lugar);
                  
                     -- se obtienen datos de la cuenta
                     LP_OBT_DAT_CUENTA(p_lote, v_cta_debito_txt, v_tas_personalizada, v_cod_mon_debito, p_lugar);
                  ELSE
                     v_mensaje_error := 'Se debe parametrizar para que el descuento se realice del Rubro Contable o de la Cta. de Débito';
                  
                     p_error := v_mensaje_error;
                  
                     v_lote.estado      := 'E';
                     v_lote.comentarios := v_mensaje_error;
                  
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                  END IF;
                  ------------------------
                  --TODO verificar si la fecha está bien
                  --TODO p_TCreCab debe ser del tipo OUT
                  v_fech_env := v_min_fec;
                  p_TCreCab  := v_tot_Credito;
                  -----------------------
               
                  --TODO está bien comentado?
                  v_cont  := 0;
                  p_lugar := 'Traer datos de la cuenta débito: ' || v_cta_debito_txt;
                  pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || p_lugar);
               
                  ---- VERIFICAR CUENTA DEBITO---
                  v_tip_movimiento := 'D';
                  v_cta_ok_deb     := 'S';
               
                  IF v_cta_debito_txt IS NOT NULL THEN
                     BEGIN
                        --datos de la cuenta
                        SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado, A.SAL_CONTABLE
                          INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado, v_sldisponible
                          FROM GE_CUENTAS A
                         WHERE A.NRO_CUENTA = v_cta_debito_txt;
                     
                        IF v_cod_modalidad NOT IN (31, 41) THEN
                           --'MODALIDAD DE LA CUENTA INVALIDO';
                           v_codigo_error := 52;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Se debe parametrizar para que el descuento se realice
                                             del Rubro Contable o de la Cta. de Débito';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           p_error := v_mensaje_error;
                        END IF;
                     
                        IF v_estado IS NULL THEN
                           --'ESTADO INVALIDO';
                           v_codigo_error := 53;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Cuenta: ' || v_cta_debito_txt || '. Estado invalido --> NULL';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           p_error := v_mensaje_error;
                        END IF;
                     
                        -- Que no tenga esta C, T, P o X, y que lo que deba cobrar sea mayor a 0
                        /*--'ESTADO DE LA CUENTA INVALIDO';
                        C-CANCELADA
                        T-BLOQUEO TOTAL
                        P-CERRADA
                        X-VERIFICACION*/
                        IF v_estado IN ('C', 'T', 'P', 'X') AND nvl(v_Tot_credito, 0) > 0 THEN
                           SELECT decode(v_estado, 'C', 67, 'T', 68, 'P', 69, 'X', 70, 55)
                             INTO v_codigo_error
                             FROM dual;
                        
                           v_cta_ok_deb := 'N';
                        
                           v_mensaje_error    := 'Cuenta: ' || v_cta_debito_txt || ' con estado de cuenta inválido: ' || v_estado;
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           p_error := v_mensaje_error;
                        END IF;
                        -- Verificamos que la cuenta tenga fondos
                        IF v_sldisponible < 0 OR v_sldisponible < v_Tot_credito THEN
                           v_cta_ok_deb       := 'N';
                           v_mensaje_error    := 'Cuenta  débito: ' || v_cta_debito_txt || ' sin fondos suficientes';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           p_error := v_mensaje_error;
                        END IF;
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           v_codigo_error := 12;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Dato no encontrado';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           p_error := v_mensaje_error;
                        WHEN OTHERS THEN
                           v_codigo_error := 12;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Error al traer los datos de la cuenta débito: ' || v_cta_debito_txt;
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           p_error := v_mensaje_error;
                     END; -- fin del begin datos de modulo modalidad
                  
                     IF v_cta_ok_deb = 'S' THEN
                        IF nvl(v_Tot_credito, 0) > 0 THEN
                        
                           p_lugar := 'LP_INS_PAG_SUELDO->PAG_CTA.PR_VER_OPERACION';
                           pr_ins_bitacora(p_lote, NULL, p_lugar);
                        
                           p_tranpdb := LF_OBT_TRA_SUELDO(v_cod_ente, 'S');
                        
                           PAG_CTA.PR_VER_OPERACION(v_cta_debito_txt, p_tranpdb, v_cod_modulo, v_cod_modalidad, v_tip_movimiento,
                                                    --
                                                    v_cod_moneda, v_Tot_credito, v_cod_oficina, v_cod_modulo, v_cod_modalidad,
                                                    --
                                                    v_estado_nuevo, v_sldisponible, v_puede_procesar);
                        
                           --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                           v_sldisponible := pag_cta.fu_sal_dis_combinada;
                        
                           -- OMM 17/12/2013. Es Cta Cte, se verifica linea de sobregiro
                           IF v_cod_modulo = 4 THEN
                              v_sldisponible := v_sldisponible + pag_cta.FU_OBT_LIN_SOBREGIRO(v_cta_debito_txt);
                           END IF;
                        
                           -- Movimiento Normal
                           IF v_puede_procesar = 'S' AND v_cod_mon_debito = v_cod_moneda THEN
                              v_est_movimiento := 'N';
                           ELSIF v_puede_procesar = 'S' AND v_cod_mon_debito <> v_cod_moneda THEN
                              v_cta_ok_deb := 'N';
                           
                              v_mensaje_error    := 'Movimiento erroneo: monedas distintas: ' || v_cod_mon_debito || ' vs ' || v_cod_moneda;
                              v_lote.estado      := 'E';
                              v_lote.comentarios := v_mensaje_error;
                              pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                           
                              v_est_movimiento := 'E'; -- Movimiento Erróneo
                              v_Codigo_Error   := 43;
                           
                              p_error := v_mensaje_error;
                           ELSE
                              v_cta_ok_deb := 'N';
                           
                              v_mensaje_error    := 'Movimiento erroneo';
                              v_lote.estado      := 'E';
                              v_lote.comentarios := v_mensaje_error;
                              pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                           
                              v_est_movimiento := 'E'; -- Movimiento Erróneo
                           
                              p_error := v_mensaje_error;
                           END IF;
                        ELSE
                           -- si la cuenta debito no tiene dinero
                           v_cta_ok_deb := 'N';
                        
                           v_mensaje_error    := 'Monto de débito es igual a cero ';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           p_error := v_mensaje_error;
                        END IF; -- fin  if v_tot_cred > 0
                     END IF; -- fin if v_cta_ok_deb S
                  ELSE
                     v_cta_ok_deb := 'N';
                  
                     v_mensaje_error    := 'Cuenta de débito no existe: ' || v_cta_debito_txt;
                     v_lote.estado      := 'E';
                     v_lote.comentarios := v_mensaje_error;
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                  
                     p_error := v_mensaje_error;
                  END IF; -- fin verificación de cuenta debito
               
                  -----------------------------------------------------------------------------------
                  --- VALIDACIÖN CUENTA CREDITO -----------
                  ---------------------------------------------------------------------------------------------
                  -- solo si la validación de la cuenta debito fue exitosa, se realiza las demás validaciones
                  IF v_cta_ok_deb = 'S' THEN
                     --movimiento de crédito
                     v_tip_movimiento := 'C';
                     v_con_reg_pagos  := 0;
                     FOR c_pago IN c_pagos(p_lote)
                     LOOP
                        v_con_reg_pagos  := 1;
                        -- BSEVOCORE-426 Si es reproceso actualiza estado de tabla temporal a P - Pendiente
                        if p_tipo = 'R' Then
                           LP_ACT_TMP_REPROCESO(c_pago.nro_lote,c_pago.nro_orden,'P');
                        end if;
                        -- en c_pagos solo se encuentran los registros de credito
                        v_cta_ok        := 'S';
                        v_codigo_error  := NULL;
                        v_mensaje_error := NULL;
                     
                        v_pago.nroOrden          := c_pago.nro_orden;
                        v_pago.estado            := 'A'; --Acreditado.
                        v_pago.comentarios       := ''; --sin comentarios.
                        v_pago.importe           := c_pago.importe; -- sueldo del jubilado
                        v_pago.nroCtaJubilado    := c_pago.nro_cta_jubilado; -- nro de cuenta del jubilado
                        v_pago.nroDocJubilado    := c_pago.nro_doc_jubilado; -- nro de documento del jubilado
                        v_pago.feVidaVigente     := c_pago.fe_vida; --tiene fe de vida vigente? en teoria aca solo trae los que tienen fe de vida vigente
                        v_pago.fechaAcreditacion := SYSDATE;
                     
                        IF v_pago.nroCtaJubilado IS NOT NULL THEN
                           BEGIN
                              p_lugar := 'Traer datos de la cuenta: ' || v_pago.nroCtaJubilado;
                              pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || p_lugar);
                           
                              --Obtengo el modulo,la modalidad y la oficina de la cuenta
                              SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado
                                INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado
                                FROM GE_CUENTAS A
                               WHERE A.NRO_CUENTA = v_pago.nroCtaJubilado;
                           
                              --- si es cta ahorro o cta cte
                              IF v_cod_modalidad NOT IN (31, 41) THEN
                                 --'MODALIDAD DE LA CUENTA INVALIDO';
                                 v_codigo_error := 52;
                                 v_cta_ok       := 'N';
                              
                                 v_mensaje_error    := 'Se debe parametrizar para que el descuento se realice
                                             del Rubro Contable o de la Cta. de Débito';
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                                 p_error := v_mensaje_error;
                              END IF;
                              IF v_estado IS NULL THEN
                                 --'ESTADO INVALIDO';
                                 v_codigo_error  := 53;
                                 v_cta_ok        := 'N';
                                 v_mensaje_error := 'Cuenta: ' || v_pago.nroCtaJubilado || '. Estado invalido --> NULL.';
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                                 p_error := v_mensaje_error;
                              END IF;
                           
                              -- Que no tenga esta C, T, P o X, y que lo que deba cobrar sea mayor a 0
                              /*--'ESTADO DE LA CUENTA INVALIDO';
                              C-CANCELADA
                              T-BLOQUEO TOTAL
                              P-CERRADA
                              X-VERIFICACION*/
                              IF v_estado IN ('C', 'T', 'P', 'X') AND nvl(v_pago.importe, 0) > 0 THEN
                                 SELECT decode(v_estado, 'C', 67, 'T', 68, 'P', 69, 'X', 70, 55)
                                   INTO v_codigo_error
                                   FROM dual;
                                 v_cta_ok        := 'N';
                                 v_mensaje_error := 'Cuenta: ' || v_pago.nroCtaJubilado || '. Estado no válido: ' || v_estado;
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              END IF;
                           EXCEPTION
                              WHEN NO_DATA_FOUND THEN
                                 v_codigo_error := 12;
                                 v_cta_ok       := 'N';
                              
                                 v_mensaje_error    := 'Dato no encontrado';
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                                 p_error := v_mensaje_error;
                              WHEN OTHERS THEN
                                 v_codigo_error := 12;
                                 v_cta_ok       := 'N';
                              
                                 v_mensaje_error    := 'Dato no encontrado';
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                                 p_error := v_mensaje_error;
                           END;
                        
                           -- verificar que el nro documento pertenezca al cliente
                           -- se valida el documento con la cuenta si se recibe
                           IF fug_obt_parentes(v_cod_ente, 'VAL_NRO_DOCUMENTO') = 'S' THEN
                              --validamos la cuenta, si retorna 0, la cuenta está asociada al Nro. de Documento
                              v_val_cta := lf_cta_valida(c_pago.Nro_Cta_Jubilado, c_pago.nro_doc_jubilado);
                           
                              IF v_nro_doc_generico <> nvl(c_pago.nro_doc_jubilado, '0') AND v_val_cta != '0' THEN
                              
                                 v_codigo_error := 90;
                                 v_cta_ok       := 'N';
                              
                                 IF v_val_cta = 1 THEN
                                    v_mensaje_error := 'El Nro. de Documento: [' || c_pago.nro_doc_jubilado || '] no existe.';
                                 ELSIF v_val_cta = 2 THEN
                                    v_mensaje_error := 'La cuenta: [' || c_pago.Nro_Cta_Jubilado || '] no existe.';
                                 ELSIF v_val_cta = 3 THEN
                                    v_mensaje_error := 'La cuenta: [' || c_pago.Nro_Cta_Jubilado || '] no está asociada a la Cuenta: [' || c_pago.Nro_Cta_Jubilado || ']';
                                 ELSE
                                    v_mensaje_error := 'Hubo un error en la validación de la Cuenta: [' || c_pago.Nro_Cta_Jubilado || '] y el Nro. Documento: [' || c_pago.nro_doc_jubilado || '].';
                                 END IF;
                              
                                 v_pago.estado      := 'E';
                                 v_pago.comentarios := v_mensaje_error;
                              
                                 p_error := v_mensaje_error;
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                              END IF;
                           END IF;
                        
                           IF v_cta_ok = 'S' THEN
                              IF nvl(v_pago.importe, 0) > 0 THEN
                                 --p_lugar := 'LP_INS_PAG_SUELDO->PAG_CTA.PR_VER_OPERACION';
                                 --pr_ins_bitacora(p_lote, NULL, p_lugar);
                              
                                 PAG_CTA.PR_VER_OPERACION(v_pago.nroCtaJubilado, p_tranpdb, v_cod_modulo, v_cod_modalidad,
                                                          --
                                                          v_tip_movimiento, v_cod_moneda, v_pago.importe, v_cod_oficina, v_cod_modulo,
                                                          --
                                                          v_cod_modalidad, v_estado_nuevo, v_sldisponible, v_puede_procesar);
                              
                                 --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                                 v_sldisponible := pag_cta.fu_sal_dis_combinada;
                              
                                 -- OMM 17/12/2013. Es Cta Cte, se verifica linea de sobregiro
                                 IF v_cod_modulo = 4 THEN
                                    v_sldisponible := v_sldisponible + pag_cta.FU_OBT_LIN_SOBREGIRO(v_pago.nroDocJubilado);
                                 END IF;
                              
                                 --registramos el error
                                 IF v_codigo_error > 0 THEN
                                    v_mensaje_error    := 'PAG_CTA.PR_VER_OPERACION :' || v_pago.nroCtaJubilado || '. Error: ' || v_mensaje_error;
                                    v_pago.comentarios := v_mensaje_error;
                                    v_pago.estado      := 'E';
                                    v_cta_ok           := 'N'; --estaba en S, cambié a N
                                 
                                    pr_ins_bitacora(p_lote, NULL, v_mensaje_error);
                                 
                                    p_error := v_mensaje_error;
                                 END IF;
                              ELSE
                                 v_mensaje_error := 'Importe a pagar es menor o igual a cero: ' || v_pago.importe;
                                 v_cta_ok        := 'N';
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 p_error := v_mensaje_error;
                              END IF; -- end if del importe mayor a cerou
                           
                              IF v_cta_ok = 'S' THEN
                                 IF v_puede_procesar = 'S' AND v_cod_mon_debito = v_cod_moneda THEN
                                    v_est_movimiento := 'N'; -- Movimiento Normal
                                 ELSIF v_puede_procesar = 'S' AND v_cod_mon_debito <> v_cod_moneda THEN
                                    v_est_movimiento := 'E'; -- Movimiento Erróneo
                                    v_Codigo_Error   := 43;
                                    v_cta_ok         := 'N';
                                 
                                    v_mensaje_error := 'Movimiento erroneo: monedas distintas: ' || v_cod_mon_debito || ' vs ' || v_cod_moneda;
                                    pr_ins_bitacora(p_lote, NULL, v_mensaje_error);
                                 
                                    v_pago.comentarios := v_mensaje_error;
                                    v_pago.estado      := 'E';
                                 
                                    p_error := v_mensaje_error;
                                 ELSE
                                    v_est_movimiento := 'E'; -- Movimiento Erróneo
                                    v_cta_ok         := 'N';
                                 
                                    v_mensaje_error := 'Movimiento erroneo';
                                    pr_ins_bitacora(p_lote, NULL, v_mensaje_error);
                                 
                                    v_pago.comentarios := v_mensaje_error;
                                    v_pago.estado      := 'E';
                                 
                                    p_error := v_mensaje_error;
                                 END IF;
                              
                                 IF v_est_movimiento = 'E' AND v_tip_movimiento = 'C' THEN
                                    p_lugar := 'LP_INS_PAG_SUELDO->PAG_CTA.PR_VER_OPERACION';
                                    pr_ins_bitacora(p_lote, NULL, p_lugar);
                                 
                                    PAG_CTA.PR_VER_OPERACION(v_pago.nroCtaJubilado, p_tranpdb, v_cod_modulo, v_cod_modalidad,
                                                             --
                                                             v_tip_movimiento, v_cod_moneda, v_pago.importe, v_cod_oficina, v_cod_modulo,
                                                             --
                                                             v_cod_modalidad, v_estado_nuevo, v_sldisponible, v_puede_procesar);
                                 
                                    --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                                    v_sldisponible  := pag_cta.fu_sal_dis_combinada;
                                    v_mensaje_error := PAG_CTA.FU_OBT_MSJ_ERROR;
                                    v_Codigo_Error  := PAG_CTA.FU_OBT_COD_ERROR;
                                 
                                    pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                                 
                                    --insertamos los errores
                                    pag_sue.pr_ins_errores(v_pago.nroCtaJubilado, v_cod_ente, trunc(v_lote.fechaAcreditacion), v_Secuencia,
                                                           --
                                                           v_cod_moneda, v_pago.importe, v_tip_movimiento, v_Codigo_Error, v_mensaje_error);
                                 
                                    v_pago.estado      := 'E';
                                    v_pago.comentarios := v_mensaje_error;
                                 
                                    p_error := v_mensaje_error;
                                 END IF;
                              
                                 -- si es estado normal, sumariza y cuenta los créditos.
                                 IF v_est_movimiento = 'N' THEN
                                    IF v_tip_movimiento = 'C' THEN
                                       p_TCreDet := p_TCreDet + v_pago.importe;
                                       p_cCreDet := p_cCreDet + 1;
                                    END IF;
                                 END IF;
                              ELSE
                                 v_mensaje_error := fug_obt_err_sueldos(v_Codigo_Error) || ' Nro. Secuencia: ' || v_Secuencia;
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 p_error := v_mensaje_error;
                              
                                 v_cta_ok := 'N';
                              END IF; -- if cuenta igual a OK = S Menor
                           ELSE
                              v_puede_procesar := 'N';
                           
                              IF v_tip_movimiento = 'C' AND nvl(v_Codigo_Error, 0) <> 0 THEN
                                 --FQ Se debe insertar en la tabla de errores si el error no se ha insertado aún.
                                 --cod error 90 CI no corresponde a cuenta
                                 IF v_Codigo_Error NOT IN (90) THEN
                                    PAG_CTA.PR_VER_OPERACION(v_pago.nroCtaJubilado, p_tranpdb, v_cod_modulo, v_cod_modalidad,
                                                             --
                                                             v_tip_movimiento, v_cod_moneda, v_pago.importe, v_cod_oficina, v_cod_modulo,
                                                             --
                                                             v_cod_modalidad, v_estado_nuevo, v_sldisponible, v_puede_procesar);
                                 
                                    v_mensaje_error := PAG_CTA.FU_OBT_MSJ_ERROR;
                                    v_Codigo_Error  := PAG_CTA.FU_OBT_COD_ERROR;
                                    pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                                 ELSE
                                    v_mensaje_error := fug_obt_err_sueldos(v_Codigo_Error) || ' Nro. Secuencia: ' || v_Secuencia;
                                    pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                                 
                                 END IF;
                              
                                 pag_sue.pr_ins_errores(v_pago.nroCtaJubilado, v_cod_ente, trunc(v_lote.fechaAcreditacion),
                                                        --
                                                        v_Secuencia, v_cod_moneda, v_pago.importe, v_tip_movimiento,
                                                        --
                                                        v_Codigo_Error, v_mensaje_error);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 p_error := v_mensaje_error;
                              END IF;
                           END IF; -- if cuenta igual a OK = S
                        ELSE
                           v_mensaje_error := 'Cuenta del jubilado: ' || v_pago.nroCtaJubilado;
                        
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || v_mensaje_error);
                        
                           v_pago.comentarios := v_mensaje_error;
                           v_pago.estado      := 'E';
                        
                           p_error := v_mensaje_error;
                        END IF; --- end if cuenta distinta a null                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                END IF;*/
                     END LOOP;
                     IF v_con_reg_pagos = 0 THEN
                         pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || p_lote || ' no se recuperan registros en cursor c_pagos.');
                     END IF;
                  ELSE
                     p_verifica_ok := 'N';
                  END IF;
               END;
            
               --contamos los registros con Estado --> Error
               BEGIN
                  SELECT COUNT(*)
                    INTO P_CANT_ERROR
                    FROM ge_pag_sue_ips_det ged
                    JOIN ge_pag_sue_ips ge
                      ON ge.nro_lote = ged.nro_lote
                   WHERE ged.nro_lote = p_lote
                         AND ge.estado = 'V'
                         AND ged.estado = 'E'
                         AND ged.fe_vida = 'S';
               EXCEPTION
                  WHEN OTHERS THEN
                     p_Cant_Error := 0;
               END;
            
               --Verifico si el archivo registró algún error
               IF v_pro_con_errores = 'N' THEN
                  BEGIN
                     SELECT COUNT(*)
                       INTO v_con_error
                       FROM ge_pag_sueldos_err
                      WHERE cod_ente = c_lote.cod_ente
                            AND trunc(nvl(fec_proceso, fec_insercion)) = trunc(v_lote.fechaAcreditacion)
                            AND --
                            nvl(nro_secuencia, 0) = nvl(v_Secuencia, 0);
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_con_error := 0;
                  END;
               END IF;
            
               v_Tot_Acreditado := p_TCreDet;
            
               --Agregado para verificar si el Débito coincide con el total de créditos en caso de que no haya cuentas con error.
               IF (nvl(v_Tot_Debito, 0) != nvl(v_Tot_Acreditado, 0) AND v_pro_con_errores = 'C') --
                  OR (nvl(v_Tot_Debito, 0) != nvl(v_Tot_Acreditado, 0) AND v_pro_con_errores = 'N' AND P_CANT_ERROR = 0) THEN
                  pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: Total de Créditos no coincide con Total de Débitos');
               END IF;
            
            END LOOP;
            IF v_con_reg_lote = 0 THEN
               pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || p_lote || ' no se recuperan registros en cursor c_lote_pagos.');
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: Error al ejecutar el procedimiento de acreditación.');
         END;
      END;
   END LP_INS_PAG_SUELDO;

   /**
   * BSEVOCORE-451 NAF 05/2020
   * Procedimiento que controla los registros a partir del sublote del lote remitido por IPS.
   */
   PROCEDURE LP_INS_PAG_SUE_SUBLOTE(p_verifica_ok   IN OUT VARCHAR2,
                               P_CANT_ERROR    IN OUT NUMBER,
                               p_error         OUT VARCHAR2,
                               p_lote          IN ge_pag_sue_ips.nro_lote%TYPE,
                               p_nro_secuencia IN NUMBER,
                               p_sublote       number) IS
      /* Definición de Variables */
      v_Tot_Debito     NUMBER(18, 2) := 0;
      v_Tot_Credito    NUMBER(18, 2) := 0;
      v_Tot_Acreditado NUMBER(18, 2) := 0; -- total de creditos realizados
   
      v_min_fec DATE;
      v_max_fec DATE;
      v_cantreg NUMBER(5) := 0;
      -------------------
      v_fech_env DATE;
   
      v_tip_movimiento    VARCHAR2(01);
      v_mensaje_error     VARCHAR2(1000) := '';
      v_cod_moneda        VARCHAR2(03);
      v_cod_mon_debito    VARCHAR2(03);
      v_est_movimiento    VARCHAR2(01);
      v_estado_nuevo      VARCHAR2(01);
      v_puede_procesar    VARCHAR2(01);
      v_tas_personalizada VARCHAR2(01);
      v_cod_modulo        NUMBER(03);
      v_cod_modalidad     NUMBER(03);
      v_estado            ge_cuentas.estado%TYPE;
      v_cod_oficina       NUMBER(03);
      v_sldisponible      NUMBER(18, 2);
      v_Secuencia         NUMBER(03);
      v_Codigo_Error      NUMBER(03);
   
      v_cta_ok     VARCHAR2(1) := 'N';
      v_cta_ok_deb VARCHAR2(1) := 'N';
      --v_esAguinaldo VARCHAR2(1) := 'N';
      --v_traspaso VARCHAR2(1) := 'N';
      v_cod_ente NUMBER;
      p_tranpdb  NUMBER;
   
      v_cta_debito_txt ge_pag_sueldos.nro_cuenta%TYPE;
      v_con_error      NUMBER;
      v_cont           NUMBER := 0;
   
      p_TCreDet NUMBER := 0; -- total de credito
      p_cCreDet NUMBER := 0; --
      p_TCreCab NUMBER := 0;
   
      --para la bitácora
      p_lugar VARCHAR2(100);
   
      v_val_cta VARCHAR2(2);
   
      --estructura que representa el archivo (cabecera y detalle)
      v_lote typ_lotepagosueldoips := typ_lotepagosueldoips();
   
      --estructura que representa la lista de pagos a acreditar
      v_pago typ_pagosueldoips := typ_pagosueldoips();
   
      --Nro. Doc. por defecto
      v_nro_doc_generico NUMBER := fug_obt_pardinamico('NRO_DOC_GEN_PAG_SAL');
   
      -- Si es igual a N= se puede procesar con errores el lote C= cancelar, no se puede procesar con errores
      v_pro_con_errores VARCHAR2(1);
      
      -- controlar si cursor no devuelve registros DYDMR-13833 / pruebas contingencia 2020
      v_con_reg_lote  number(1); 
      v_con_reg_pagos number(1);
      
      --cursor con los datos del lote a procesar.
      CURSOR c_lote_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT c.*,
                b.cantidad,
                b.tot_imp_sublote
          FROM ge_pag_sue_ips c
              join (SELECT d.nro_lote, COUNT(*) cantidad, sum( d.importe) tot_imp_sublote
                    FROM ge_pag_sue_ips_det d
                         join ge_pag_sue_ips_sublotes e on d.nro_orden=e.nro_orden
                              and d.nro_lote = e.nro_lote
                              and e.nro_sublote = p_sublote
                   WHERE d.nro_lote = p_lote
                         AND d.estado = 'P'
                   GROUP by d.nro_lote) b on b.nro_lote = c.nro_lote
          WHERE c.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado o procesado
                AND trunc(c.fec_acreditacion) <= trunc(SYSDATE) --lote a acreditar
                AND trunc(c.fec_vencimiento) >= trunc(SYSDATE); --lote vigente
   
      -- trae todos los registros del lote a pagar
      -- se valida con cabecera con estado verificado o procesado
      CURSOR c_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT d.*
           FROM ge_pag_sue_ips_det d
           JOIN ge_pag_sue_ips c
             ON d.nro_lote = c.nro_lote
           JOIN ge_pag_sue_ips_sublotes s 
             ON s.nro_orden = d.nro_orden and
                s.nro_lote = d.nro_lote and
                s.nro_sublote = p_sublote    
          WHERE d.nro_lote = p_lote
                AND c.estado IN ('V', 'P') --lote verificado o procesado
                AND D.Fec_Acreditacion IS NULL --aun no pagados
                AND d.estado = 'P' -- registros con estado pendientes de acreditación
                AND d.fe_vida = 'S'; -- fe de vida vigente
   
   BEGIN
      BEGIN
         --secuencia para el lote de pagos en ge_pag_sueldos
         v_secuencia := p_nro_secuencia;
         p_TCreDet   := 0; -- total de credito
         p_cCreDet   := 0; --
      
         BEGIN
            --traemos los datos del lote
            v_con_reg_lote   := 0;
            FOR c_lote IN c_lote_pagos(p_lote)
            LOOP
               --almacenamos los datos del lote de pago.
               v_lote.estado            := 'P'; --Procesado
               v_lote.fechaAcreditacion := c_lote.fec_acreditacion;
               v_lote.tipoProceso       := c_lote.tip_proceso;
               v_lote.nroLote           := c_lote.nro_lote;
               v_con_reg_lote           := 1; --recupera registros
               -- si no hay detalles a pagar, se coloca con Error el lote.
               --todo
               IF c_lote.cantidad = 0 THEN --revisar esto para sub lotes
                  SELECT COUNT(*)
                    INTO P_CANT_ERROR
                    FROM ge_pag_sue_ips_det ged
                    JOIN ge_pag_sue_ips ge
                      ON ge.nro_lote = ged.nro_lote
                   WHERE ged.nro_lote = p_lote
                         AND ge.estado = 'V'
                         AND ged.estado = 'E'
                         AND ged.fe_vida = 'S';
               
                  v_cta_ok_deb    := 'S';
                  v_mensaje_error := 'Lote sin detalles a acreditar.';
                  pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
               
                  p_error := v_mensaje_error;
               
                  RETURN;
               END IF;
            
               -- Se verifican los datos leidos....
               -- total de debitos,
               -- se toma fecha min como fecha de acreditación y fecha maxima la fecha de vencimiento
               -- se obtiene de la cuenta donde se debe realizar el debito
               v_Tot_debito     := c_lote.tot_imp_sublote; --con procesamiento de sublotes tomar sum del det
               v_min_fec        := c_lote.fec_acreditacion;
               v_max_fec        := c_lote.fec_vencimiento;
               v_cta_debito_txt := c_lote.nro_cta_pag_salario;
               v_cod_ente       := c_lote.cod_ente;
            
               BEGIN
                  p_verifica_ok := 'S';
               
                  -- Si es igual a N= se puede procesar con errores el lote C= cancelar, no se puede procesar con errores
                  v_pro_con_errores := UPPER(NVL(fug_obt_parentes(v_cod_ente, 'PRO_CON_ERRORES'), 'N'));
               
                  --- total de importe a pagar a jubilados, se cuenta la cantidad de registros
                  SELECT SUM(ged.importe), COUNT(*)
                    INTO v_Tot_credito, v_cantreg
                    FROM GE_PAG_SUE_IPS_DET ged
                    JOIN GE_PAG_SUE_IPS ge
                      ON ged.nro_lote = ge.nro_lote
                    JOIN GE_PAG_SUE_IPS_SUBLOTES sub 
                      ON sub.nro_orden = ged.nro_orden and
                         sub.nro_lote = ged.nro_lote and
                         sub.nro_sublote = p_sublote                        
                   WHERE ged.nro_lote = p_lote
                         AND ge.estado IN ('V', 'P') --cabecera validada o acreditada parcialmente
                         AND ged.estado = 'P' --pagos pendientes de acreditación
                         AND ged.fe_vida = 'S' --fe de vida vigente
                         AND TRUNC(ge.fec_acreditacion) <= TRUNC(SYSDATE)
                         AND TRUNC(ge.fec_vencimiento) >= TRUNC(SYSDATE);
               
                  IF v_cta_debito_txt IS NOT NULL THEN
                     p_lugar := 'LP_INS_PAG_SUE_SUBLOTE->LP_OBT_DAT_CUENTA';
                     pr_ins_bitacora(p_lote, NULL, p_lugar || ' - sublote: ' || p_sublote);
                  
                     -- se obtienen datos de la cuenta
                     LP_OBT_DAT_CUENTA(p_lote, v_cta_debito_txt, v_tas_personalizada, v_cod_mon_debito, p_lugar);
                  ELSE
                     v_mensaje_error := 'Se debe parametrizar para que el descuento se realice del Rubro Contable o de la Cta. de Débito';
                  
                     p_error := v_mensaje_error;
                  
                     v_lote.estado      := 'E';
                     v_lote.comentarios := v_mensaje_error;
                  
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                  END IF;
                  ------------------------
                  --TODO verificar si la fecha está bien
                  --TODO p_TCreCab debe ser del tipo OUT
                  v_fech_env := v_min_fec;
                  p_TCreCab  := v_tot_Credito;
                  -----------------------
               
                  --TODO está bien comentado?
                  v_cont  := 0;
                  p_lugar := 'Traer datos de la cuenta débito: ' || v_cta_debito_txt;
                  pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || p_lugar || ' - sublote: ' || p_sublote);
               
                  ---- VERIFICAR CUENTA DEBITO---
                  v_tip_movimiento := 'D';
                  v_cta_ok_deb     := 'S';
               
                  IF v_cta_debito_txt IS NOT NULL THEN
                     BEGIN
                        --datos de la cuenta
                        SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado, A.SAL_CONTABLE
                          INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado, v_sldisponible
                          FROM GE_CUENTAS A
                         WHERE A.NRO_CUENTA = v_cta_debito_txt;
                     
                        IF v_cod_modalidad NOT IN (31, 41) THEN
                           --'MODALIDAD DE LA CUENTA INVALIDO';
                           v_codigo_error := 52;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Se debe parametrizar para que el descuento se realice
                                             del Rubro Contable o de la Cta. de Débito';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                        
                           p_error := v_mensaje_error;
                        END IF;
                     
                        IF v_estado IS NULL THEN
                           --'ESTADO INVALIDO';
                           v_codigo_error := 53;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Cuenta: ' || v_cta_debito_txt || '. Estado invalido --> NULL';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                        
                           p_error := v_mensaje_error;
                        END IF;
                     
                        -- Que no tenga esta C, T, P o X, y que lo que deba cobrar sea mayor a 0
                        /*--'ESTADO DE LA CUENTA INVALIDO';
                        C-CANCELADA
                        T-BLOQUEO TOTAL
                        P-CERRADA
                        X-VERIFICACION*/
                        IF v_estado IN ('C', 'T', 'P', 'X') AND nvl(v_Tot_credito, 0) > 0 THEN
                           SELECT decode(v_estado, 'C', 67, 'T', 68, 'P', 69, 'X', 70, 55)
                             INTO v_codigo_error
                             FROM dual;
                        
                           v_cta_ok_deb := 'N';
                        
                           v_mensaje_error    := 'Cuenta: ' || v_cta_debito_txt || ' con estado de cuenta inválido: ' || v_estado;
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                        
                           p_error := v_mensaje_error;
                        END IF;
                        -- Verificamos que la cuenta tenga fondos
                        IF v_sldisponible < 0 OR v_sldisponible < v_Tot_credito THEN
                           v_cta_ok_deb       := 'N';
                           v_mensaje_error    := 'Cuenta  débito: ' || v_cta_debito_txt || ' sin fondos suficientes';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                        
                           p_error := v_mensaje_error;
                        END IF;
                     EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                           v_codigo_error := 12;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Dato no encontrado';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                        
                           p_error := v_mensaje_error;
                        WHEN OTHERS THEN
                           v_codigo_error := 12;
                           v_cta_ok_deb   := 'N';
                        
                           v_mensaje_error    := 'Error al traer los datos de la cuenta débito: ' || v_cta_debito_txt;
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error|| ' - sublote: ' || p_sublote);
                        
                           p_error := v_mensaje_error;
                     END; -- fin del begin datos de modulo modalidad
                  
                     IF v_cta_ok_deb = 'S' THEN
                        IF nvl(v_Tot_credito, 0) > 0 THEN
                        
                           p_lugar := 'LP_INS_PAG_SUE_SUBLOTE->PAG_CTA.PR_VER_OPERACION';
                           pr_ins_bitacora(p_lote, NULL, p_lugar || ' - sublote: ' || p_sublote);
                        
                           p_tranpdb := LF_OBT_TRA_SUELDO(v_cod_ente, 'S');
                        
                           PAG_CTA.PR_VER_OPERACION(v_cta_debito_txt, p_tranpdb, v_cod_modulo, v_cod_modalidad, v_tip_movimiento,
                                                    --
                                                    v_cod_moneda, v_Tot_credito, v_cod_oficina, v_cod_modulo, v_cod_modalidad,
                                                    --
                                                    v_estado_nuevo, v_sldisponible, v_puede_procesar);
                        
                           --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                           v_sldisponible := pag_cta.fu_sal_dis_combinada;
                        
                           -- OMM 17/12/2013. Es Cta Cte, se verifica linea de sobregiro
                           IF v_cod_modulo = 4 THEN
                              v_sldisponible := v_sldisponible + pag_cta.FU_OBT_LIN_SOBREGIRO(v_cta_debito_txt);
                           END IF;
                        
                           -- Movimiento Normal
                           IF v_puede_procesar = 'S' AND v_cod_mon_debito = v_cod_moneda THEN
                              v_est_movimiento := 'N';
                           ELSIF v_puede_procesar = 'S' AND v_cod_mon_debito <> v_cod_moneda THEN
                              v_cta_ok_deb := 'N';
                           
                              v_mensaje_error    := 'Movimiento erroneo: monedas distintas: ' || v_cod_mon_debito || ' vs ' || v_cod_moneda;
                              v_lote.estado      := 'E';
                              v_lote.comentarios := v_mensaje_error;
                              pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error|| ' - sublote: ' || p_sublote);
                           
                              v_est_movimiento := 'E'; -- Movimiento Erróneo
                              v_Codigo_Error   := 43;
                           
                              p_error := v_mensaje_error;
                           ELSE
                              v_cta_ok_deb := 'N';
                           
                              v_mensaje_error    := 'Movimiento erroneo';
                              v_lote.estado      := 'E';
                              v_lote.comentarios := v_mensaje_error;
                              pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error|| ' - sublote: ' || p_sublote);
                           
                              v_est_movimiento := 'E'; -- Movimiento Erróneo
                           
                              p_error := v_mensaje_error;
                           END IF;
                        ELSE
                           -- si la cuenta debito no tiene dinero
                           v_cta_ok_deb := 'N';
                        
                           v_mensaje_error    := 'Monto de débito es igual a cero ';
                           v_lote.estado      := 'E';
                           v_lote.comentarios := v_mensaje_error;
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                        
                           p_error := v_mensaje_error;
                        END IF; -- fin  if v_tot_cred > 0
                     END IF; -- fin if v_cta_ok_deb S
                  ELSE
                     v_cta_ok_deb := 'N';
                  
                     v_mensaje_error    := 'Cuenta de débito no existe: ' || v_cta_debito_txt;
                     v_lote.estado      := 'E';
                     v_lote.comentarios := v_mensaje_error;
                     pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                  
                     p_error := v_mensaje_error;
                  END IF; -- fin verificación de cuenta debito
               
                  -----------------------------------------------------------------------------------
                  --- VALIDACIÖN CUENTA CREDITO -----------
                  ---------------------------------------------------------------------------------------------
                  -- solo si la validación de la cuenta debito fue exitosa, se realiza las demás validaciones
                  IF v_cta_ok_deb = 'S' THEN
                     --movimiento de crédito
                     v_tip_movimiento := 'C';
                     v_con_reg_pagos  := 0;
                     FOR c_pago IN c_pagos(p_lote)
                     LOOP
                        -- en c_pagos solo se encuentran los registros de credito
                        v_cta_ok        := 'S';
                        v_codigo_error  := NULL;
                        v_mensaje_error := NULL;
                        v_con_reg_pagos := 1;
                        
                        v_pago.nroOrden          := c_pago.nro_orden;
                        v_pago.estado            := 'A'; --Acreditado.
                        v_pago.comentarios       := ''; --sin comentarios.
                        v_pago.importe           := c_pago.importe; -- sueldo del jubilado
                        v_pago.nroCtaJubilado    := c_pago.nro_cta_jubilado; -- nro de cuenta del jubilado
                        v_pago.nroDocJubilado    := c_pago.nro_doc_jubilado; -- nro de documento del jubilado
                        v_pago.feVidaVigente     := c_pago.fe_vida; --tiene fe de vida vigente? en teoria aca solo trae los que tienen fe de vida vigente
                        v_pago.fechaAcreditacion := SYSDATE;
                     
                        IF v_pago.nroCtaJubilado IS NOT NULL THEN
                           BEGIN
                              p_lugar := 'Traer datos de la cuenta: ' || v_pago.nroCtaJubilado;
                              pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUELDO: ' || p_lugar || ' - sublote: ' || p_sublote);
                           
                              --Obtengo el modulo,la modalidad y la oficina de la cuenta
                              SELECT A.COD_MODULO, A.COD_MODALIDAD, A.COD_OFICINA, A.COD_MONEDA, a.estado
                                INTO v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, v_estado
                                FROM GE_CUENTAS A
                               WHERE A.NRO_CUENTA = v_pago.nroCtaJubilado;
                           
                              --- si es cta ahorro o cta cte
                              IF v_cod_modalidad NOT IN (31, 41) THEN
                                 --'MODALIDAD DE LA CUENTA INVALIDO';
                                 v_codigo_error := 52;
                                 v_cta_ok       := 'N';
                              
                                 v_mensaje_error    := 'Se debe parametrizar para que el descuento se realice
                                             del Rubro Contable o de la Cta. de Débito';
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                              
                                 p_error := v_mensaje_error;
                              END IF;
                              IF v_estado IS NULL THEN
                                 --'ESTADO INVALIDO';
                                 v_codigo_error  := 53;
                                 v_cta_ok        := 'N';
                                 v_mensaje_error := 'Cuenta: ' || v_pago.nroCtaJubilado || '. Estado invalido --> NULL.';
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                              
                                 p_error := v_mensaje_error;
                              END IF;
                           
                              -- Que no tenga esta C, T, P o X, y que lo que deba cobrar sea mayor a 0
                              /*--'ESTADO DE LA CUENTA INVALIDO';
                              C-CANCELADA
                              T-BLOQUEO TOTAL
                              P-CERRADA
                              X-VERIFICACION*/
                              IF v_estado IN ('C', 'T', 'P', 'X') AND nvl(v_pago.importe, 0) > 0 THEN
                                 SELECT decode(v_estado, 'C', 67, 'T', 68, 'P', 69, 'X', 70, 55)
                                   INTO v_codigo_error
                                   FROM dual;
                                 v_cta_ok        := 'N';
                                 v_mensaje_error := 'Cuenta: ' || v_pago.nroCtaJubilado || '. Estado no válido: ' || v_estado;
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              END IF;
                           EXCEPTION
                              WHEN NO_DATA_FOUND THEN
                                 v_codigo_error := 12;
                                 v_cta_ok       := 'N';
                              
                                 v_mensaje_error    := 'Dato no encontrado';
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                              
                                 p_error := v_mensaje_error;
                              WHEN OTHERS THEN
                                 v_codigo_error := 12;
                                 v_cta_ok       := 'N';
                              
                                 v_mensaje_error    := 'Dato no encontrado';
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                              
                                 p_error := v_mensaje_error;
                           END;
                        
                           -- verificar que el nro documento pertenezca al cliente
                           -- se valida el documento con la cuenta si se recibe
                           IF fug_obt_parentes(v_cod_ente, 'VAL_NRO_DOCUMENTO') = 'S' THEN
                              --validamos la cuenta, si retorna 0, la cuenta está asociada al Nro. de Documento
                              v_val_cta := lf_cta_valida(c_pago.Nro_Cta_Jubilado, c_pago.nro_doc_jubilado);
                           
                              IF v_nro_doc_generico <> nvl(c_pago.nro_doc_jubilado, '0') AND v_val_cta != '0' THEN
                              
                                 v_codigo_error := 90;
                                 v_cta_ok       := 'N';
                              
                                 IF v_val_cta = 1 THEN
                                    v_mensaje_error := 'El Nro. de Documento: [' || c_pago.nro_doc_jubilado || '] no existe.';
                                 ELSIF v_val_cta = 2 THEN
                                    v_mensaje_error := 'La cuenta: [' || c_pago.Nro_Cta_Jubilado || '] no existe.';
                                 ELSIF v_val_cta = 3 THEN
                                    v_mensaje_error := 'La cuenta: [' || c_pago.Nro_Cta_Jubilado || '] no está asociada a la Cuenta: [' || c_pago.Nro_Cta_Jubilado || ']';
                                 ELSE
                                    v_mensaje_error := 'Hubo un error en la validación de la Cuenta: [' || c_pago.Nro_Cta_Jubilado || '] y el Nro. Documento: [' || c_pago.nro_doc_jubilado || '].';
                                 END IF;
                              
                                 v_pago.estado      := 'E';
                                 v_pago.comentarios := v_mensaje_error;
                              
                                 p_error := v_mensaje_error;
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                              
                              END IF;
                           END IF;
                        
                           IF v_cta_ok = 'S' THEN
                              IF nvl(v_pago.importe, 0) > 0 THEN
                                 --p_lugar := 'LP_INS_PAG_SUE_SUBLOTE->PAG_CTA.PR_VER_OPERACION';
                                 --pr_ins_bitacora(p_lote, NULL, p_lugar);
                              
                                 PAG_CTA.PR_VER_OPERACION(v_pago.nroCtaJubilado, p_tranpdb, v_cod_modulo, v_cod_modalidad,
                                                          --
                                                          v_tip_movimiento, v_cod_moneda, v_pago.importe, v_cod_oficina, v_cod_modulo,
                                                          --
                                                          v_cod_modalidad, v_estado_nuevo, v_sldisponible, v_puede_procesar);
                              
                                 --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                                 v_sldisponible := pag_cta.fu_sal_dis_combinada;
                              
                                 -- OMM 17/12/2013. Es Cta Cte, se verifica linea de sobregiro
                                 IF v_cod_modulo = 4 THEN
                                    v_sldisponible := v_sldisponible + pag_cta.FU_OBT_LIN_SOBREGIRO(v_pago.nroDocJubilado);
                                 END IF;
                              
                                 --registramos el error
                                 IF v_codigo_error > 0 THEN
                                    v_mensaje_error    := 'PAG_CTA.PR_VER_OPERACION :' || v_pago.nroCtaJubilado || '. Error: ' || v_mensaje_error;
                                    v_pago.comentarios := v_mensaje_error;
                                    v_pago.estado      := 'E';
                                    v_cta_ok           := 'N'; --estaba en S, cambié a N
                                 
                                    pr_ins_bitacora(p_lote, NULL, v_mensaje_error || ' - sublote: ' || p_sublote);
                                 
                                    p_error := v_mensaje_error;
                                 END IF;
                              ELSE
                                 v_mensaje_error := 'Importe a pagar es menor o igual a cero: ' || v_pago.importe;
                                 v_cta_ok        := 'N';
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 p_error := v_mensaje_error;
                              END IF; -- end if del importe mayor a cerou
                           
                              IF v_cta_ok = 'S' THEN
                                 IF v_puede_procesar = 'S' AND v_cod_mon_debito = v_cod_moneda THEN
                                    v_est_movimiento := 'N'; -- Movimiento Normal
                                 ELSIF v_puede_procesar = 'S' AND v_cod_mon_debito <> v_cod_moneda THEN
                                    v_est_movimiento := 'E'; -- Movimiento Erróneo
                                    v_Codigo_Error   := 43;
                                    v_cta_ok         := 'N';
                                 
                                    v_mensaje_error := 'Movimiento erroneo: monedas distintas: ' || v_cod_mon_debito || ' vs ' || v_cod_moneda;
                                    pr_ins_bitacora(p_lote, NULL, v_mensaje_error || ' - sublote: ' || p_sublote);
                                 
                                    v_pago.comentarios := v_mensaje_error;
                                    v_pago.estado      := 'E';
                                 
                                    p_error := v_mensaje_error;
                                 ELSE
                                    v_est_movimiento := 'E'; -- Movimiento Erróneo
                                    v_cta_ok         := 'N';
                                 
                                    v_mensaje_error := 'Movimiento erroneo';
                                    pr_ins_bitacora(p_lote, NULL, v_mensaje_error || ' - sublote: ' || p_sublote);
                                 
                                    v_pago.comentarios := v_mensaje_error;
                                    v_pago.estado      := 'E';
                                 
                                    p_error := v_mensaje_error;
                                 END IF;
                              
                                 IF v_est_movimiento = 'E' AND v_tip_movimiento = 'C' THEN
                                    p_lugar := 'LP_INS_PAG_SUE_SUBLOTE->PAG_CTA.PR_VER_OPERACION';
                                    pr_ins_bitacora(p_lote, NULL, p_lugar || ' - sublote: ' || p_sublote);
                                 
                                    PAG_CTA.PR_VER_OPERACION(v_pago.nroCtaJubilado, p_tranpdb, v_cod_modulo, v_cod_modalidad,
                                                             --
                                                             v_tip_movimiento, v_cod_moneda, v_pago.importe, v_cod_oficina, v_cod_modulo,
                                                             --
                                                             v_cod_modalidad, v_estado_nuevo, v_sldisponible, v_puede_procesar);
                                 
                                    --Para tener el Disponible con la Cta. Combinada  <<EF,27/11/2009>>
                                    v_sldisponible  := pag_cta.fu_sal_dis_combinada;
                                    v_mensaje_error := PAG_CTA.FU_OBT_MSJ_ERROR;
                                    v_Codigo_Error  := PAG_CTA.FU_OBT_COD_ERROR;
                                 
                                    pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                                 
                                    --insertamos los errores
                                    pag_sue.pr_ins_errores(v_pago.nroCtaJubilado, v_cod_ente, trunc(v_lote.fechaAcreditacion), v_Secuencia,
                                                           --
                                                           v_cod_moneda, v_pago.importe, v_tip_movimiento, v_Codigo_Error, v_mensaje_error);
                                 
                                    v_pago.estado      := 'E';
                                    v_pago.comentarios := v_mensaje_error;
                                 
                                    p_error := v_mensaje_error;
                                 END IF;
                              
                                 -- si es estado normal, sumariza y cuenta los créditos.
                                 IF v_est_movimiento = 'N' THEN
                                    IF v_tip_movimiento = 'C' THEN
                                       p_TCreDet := p_TCreDet + v_pago.importe;
                                       p_cCreDet := p_cCreDet + 1;
                                    END IF;
                                 END IF;
                              ELSE
                                 v_mensaje_error := fug_obt_err_sueldos(v_Codigo_Error) || ' Nro. Secuencia: ' || v_Secuencia;
                                 pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error  || ' - sublote: ' || p_sublote);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 p_error := v_mensaje_error;
                              
                                 v_cta_ok := 'N';
                              END IF; -- if cuenta igual a OK = S Menor
                           ELSE
                              v_puede_procesar := 'N';
                           
                              IF v_tip_movimiento = 'C' AND nvl(v_Codigo_Error, 0) <> 0 THEN
                                 --FQ Se debe insertar en la tabla de errores si el error no se ha insertado aún.
                                 --cod error 90 CI no corresponde a cuenta
                                 IF v_Codigo_Error NOT IN (90) THEN
                                    PAG_CTA.PR_VER_OPERACION(v_pago.nroCtaJubilado, p_tranpdb, v_cod_modulo, v_cod_modalidad,
                                                             --
                                                             v_tip_movimiento, v_cod_moneda, v_pago.importe, v_cod_oficina, v_cod_modulo,
                                                             --
                                                             v_cod_modalidad, v_estado_nuevo, v_sldisponible, v_puede_procesar);
                                 
                                    v_mensaje_error := PAG_CTA.FU_OBT_MSJ_ERROR;
                                    v_Codigo_Error  := PAG_CTA.FU_OBT_COD_ERROR;
                                    pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                                 ELSE
                                    v_mensaje_error := fug_obt_err_sueldos(v_Codigo_Error) || ' Nro. Secuencia: ' || v_Secuencia;
                                    pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                                 
                                 END IF;
                              
                                 pag_sue.pr_ins_errores(v_pago.nroCtaJubilado, v_cod_ente, trunc(v_lote.fechaAcreditacion),
                                                        --
                                                        v_Secuencia, v_cod_moneda, v_pago.importe, v_tip_movimiento,
                                                        --
                                                        v_Codigo_Error, v_mensaje_error);
                              
                                 v_pago.comentarios := v_mensaje_error;
                                 v_pago.estado      := 'E';
                              
                                 p_error := v_mensaje_error;
                              END IF;
                           END IF; -- if cuenta igual a OK = S
                        ELSE
                           v_mensaje_error := 'Cuenta del jubilado: ' || v_pago.nroCtaJubilado;
                        
                           pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || v_mensaje_error || ' - sublote: ' || p_sublote);
                        
                           v_pago.comentarios := v_mensaje_error;
                           v_pago.estado      := 'E';
                        
                           p_error := v_mensaje_error;
                        END IF; --- end if cuenta distinta a null                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                END IF;*/
                     END LOOP;
                     IF v_con_reg_pagos = 0 THEN
                         pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || p_lote || ' - ' || p_sublote || ' no se recuperan registros en cursor c_pagos.');
                     END IF;
                  ELSE
                     p_verifica_ok := 'N';
                  END IF;
               END;
            
               --contamos los registros con Estado --> Error
               BEGIN
                  SELECT COUNT(*)
                    INTO P_CANT_ERROR
                    FROM ge_pag_sue_ips_det ged
                    JOIN ge_pag_sue_ips ge
                       ON ge.nro_lote = ged.nro_lote
                    JOIN ge_pag_sue_ips_sublotes sub
                       ON sub.nro_orden = ged.nro_orden and
                          sub.nro_lote = ged.nro_lote and
                          sub.nro_sublote = p_sublote 
                   WHERE ged.nro_lote = p_lote
                         AND ge.estado = 'V'
                         AND ged.estado = 'E'
                         AND ged.fe_vida = 'S';
               EXCEPTION
                  WHEN OTHERS THEN
                     p_Cant_Error := 0;
               END;
            
               --Verifico si el archivo registró algún error
               IF v_pro_con_errores = 'N' THEN
                  BEGIN
                     SELECT COUNT(*)
                       INTO v_con_error
                       FROM ge_pag_sueldos_err
                      WHERE cod_ente = c_lote.cod_ente
                            AND trunc(nvl(fec_proceso, fec_insercion)) = trunc(v_lote.fechaAcreditacion)
                            AND --
                            nvl(nro_secuencia, 0) = nvl(v_Secuencia, 0);
                  EXCEPTION
                     WHEN OTHERS THEN
                        v_con_error := 0;
                  END;
               END IF;
            
               v_Tot_Acreditado := p_TCreDet;
            
               --Agregado para verificar si el Débito coincide con el total de créditos en caso de que no haya cuentas con error.
               IF (nvl(v_Tot_Debito, 0) != nvl(v_Tot_Acreditado, 0) AND v_pro_con_errores = 'C') --
                  OR (nvl(v_Tot_Debito, 0) != nvl(v_Tot_Acreditado, 0) AND v_pro_con_errores = 'N' AND P_CANT_ERROR = 0) THEN
                  pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: Total de Créditos no coincide con Total de Débitos'  || ' - sublote: ' || p_sublote);
               END IF;
            
            END LOOP;
            IF v_con_reg_lote = 0 THEN
               pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: ' || p_lote || ' - ' || p_sublote || ' no se recuperan registros en cursor c_lote_pagos.');
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'LP_INS_PAG_SUE_SUBLOTE: Error al ejecutar el procedimiento de acreditación.' || ' - sublote: ' || p_sublote);
         END;
      END;
   END LP_INS_PAG_SUE_SUBLOTE;
   
   PROCEDURE PR_PRO_ACREDITACION(p_lote ge_pag_sue_ips.nro_lote%TYPE, 
                                 p_tipo varchar2 default null) IS
   
      v_ente            NUMBER;
      v_nro_archivo     NUMBER; -- secuencia
      v_cod_ofi         NUMBER;
      v_fecha           ge_pag_sueldos.fec_proceso%TYPE := trunc(SYSDATE);
      v_nro_cuenta      ge_pag_sue_ips.nro_cta_pag_salario%TYPE;
      v_tip_transaccion VARCHAR2(1);
   
      v_pro_con_errores VARCHAR2(1); -- si se puede procesar con errores
      v_error           VARCHAR2(1); --error de intentar insertar en ge_pag_sue
      v_Cant_Error      NUMBER;
      v_verifica_ok     VARCHAR2(1); --N cuando hubo errores S sin errores
   
      codigoOficinaOrigen cj_cajas.cod_oficina%TYPE;
   
      retError typ_mensajeRespuesta := typ_mensajeRespuesta;
   
      v_nro_caja        cj_cajas.nro_caja%TYPE := 999;
      v_msj_caja        typ_mensajeCaja;
      v_horario         VARCHAR2(1);
      v_es_mov_noc      VARCHAR2(1);
      v_es_cta_noc      VARCHAR2(1);
      v_fec_actual      DATE;
      fechaUltimoCierre cj_cajas.fec_hor_cierre%TYPE;
   
      v_mensaje_error VARCHAR2(1000) := '';
   BEGIN
      BEGIN
         -- hallamos el ente del lote
         BEGIN
            SELECT ge.cod_ente, ge.nro_cta_pag_salario
              INTO v_ente, v_nro_cuenta
              FROM GE_PAG_SUE_IPS ge
             WHERE ge.nro_lote = p_lote;
         
            SELECT c.cod_oficina
              INTO v_cod_ofi
              FROM ge_cuentas c
             WHERE c.nro_cuenta = v_nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al obtener los datos del lote: ' || p_lote);
         END;
      
         BEGIN
            --validar el nro. de caja.
            v_msj_caja := lf_val_caja(p_lote, v_nro_caja);
         
            --traemos los datos de la caja.
            SELECT c.cod_oficina, c.fec_hor_cierre
              INTO codigoOficinaOrigen, fechaUltimoCierre
              FROM cj_cajas c
             WHERE nro_caja = v_nro_caja
                   AND estado = 'A' --activo
                   AND tipo IN ('C', 'I', 'S');
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al obtener los datos de la caja: ' || v_nro_caja);
         END;
      
         BEGIN
            --verificamos el horario para que no se procese estando en cierre
            retError := lp_ver_horario(fechaUltimoCierre, codigoOficinaOrigen, v_horario, v_es_mov_noc, v_es_cta_noc, v_fec_actual);
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al verificar el horario y estado de los módulos.');
         END;
      
         --si hay problemas con la caja
         IF v_msj_caja.error = 'S' THEN
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: ' || v_msj_caja.nombreRespuesta || '. ' || v_msj_caja.descripcionRespuesta);
         
            --si hay problemas del horario para ejecutar. No se procesa si es que está en Cierre.
         ELSIF retError.error = 'S' THEN
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: ' || retError.nombreRespuesta || '. ' || retError.descripcionRespuesta);
         ELSE
            v_tip_transaccion := 'S';
         
            --- parametro si se puede procesar con errores un archivo.
            v_pro_con_errores := UPPER(NVL(fug_obt_parentes(v_ente, 'PRO_CON_ERRORES'), 'N'));
         
            -- hallamos el nro de archivo (secuencia) para enviar a la función de validación
            v_nro_archivo := LF_OBT_NRO_SECUENCIA(v_ente, TRUNC(SYSDATE));
         
            --
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION->LP_INS_PAG_SUELDO. Secuencia: ' || v_nro_archivo);
         
            LP_INS_PAG_SUELDO(v_verifica_ok, v_cant_error, v_mensaje_error, p_lote, v_nro_archivo, p_tipo);
         
            IF v_verifica_OK = 'S' THEN
               -- si no hubo errores
               -- se puede realizar la acreditación
               --se  inserta en la tabla ge_pag_sue
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION->lp_ins_tabla');
            
               lp_ins_tabla(v_error, v_nro_archivo, v_pro_con_errores, p_lote);
            
               IF v_error = 'S' THEN
                  -- hubo error
                  pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al intentar insertar en ge_pag_sue');
               ELSE
                  pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION->LP_ACR_EMPLEADO');
                  LP_ACR_EMPLEADO(v_ente, p_lote, v_nro_archivo, v_cod_ofi, v_fecha, USER, v_error, v_tip_transaccion);
               END IF;
            ELSE
               --actualizamos la cabecera con estado -> E y con comentarios.
               UPDATE ge_pag_sue_ips c
                  SET c.estado      = 'E',
                      c.comentarios = substr(v_mensaje_error,1,999)
                WHERE c.nro_lote = p_lote;
            
               -- si no resulto la validación de pr ins ge pag sueldo
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error en el lote o detalle 1 ' || v_mensaje_error);
            END IF;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al procesar el lote: ' || p_lote);
      END;
   
   END PR_PRO_ACREDITACION;
   
   /*
   * BSEVOCORE-451 NAF 05/2020
   * Proceso de Acreditacion por sublote
   */
   PROCEDURE PR_PRO_ACR_SUBLOTE(p_lote ge_pag_sue_ips.nro_lote%TYPE, 
                                p_sublote ge_pag_sue_ips_sublotes.nro_sublote%TYPE) IS
   
      v_ente            NUMBER;
      v_nro_archivo     NUMBER; -- secuencia
      v_cod_ofi         NUMBER;
      v_fecha           ge_pag_sueldos.fec_proceso%TYPE := trunc(SYSDATE);
      v_nro_cuenta      ge_pag_sue_ips.nro_cta_pag_salario%TYPE;
      v_tip_transaccion VARCHAR2(1);
   
      v_pro_con_errores VARCHAR2(1); -- si se puede procesar con errores
      v_error           VARCHAR2(1); --error de intentar insertar en ge_pag_sue
      v_Cant_Error      NUMBER;
      v_verifica_ok     VARCHAR2(1); --N cuando hubo errores S sin errores
   
      codigoOficinaOrigen cj_cajas.cod_oficina%TYPE;
   
      retError typ_mensajeRespuesta := typ_mensajeRespuesta;
   
      v_nro_caja        cj_cajas.nro_caja%TYPE := 999;
      v_msj_caja        typ_mensajeCaja;
      v_horario         VARCHAR2(1);
      v_es_mov_noc      VARCHAR2(1);
      v_es_cta_noc      VARCHAR2(1);
      v_fec_actual      DATE;
      fechaUltimoCierre cj_cajas.fec_hor_cierre%TYPE;
   
      v_mensaje_error VARCHAR2(1000) := '';
   BEGIN
      BEGIN
         -- hallamos el ente del lote
         BEGIN
            SELECT ge.cod_ente, ge.nro_cta_pag_salario
              INTO v_ente, v_nro_cuenta
              FROM GE_PAG_SUE_IPS ge
             WHERE ge.nro_lote = p_lote;
         
            SELECT c.cod_oficina
              INTO v_cod_ofi
              FROM ge_cuentas c
             WHERE c.nro_cuenta = v_nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al obtener los datos del lote: ' || p_lote || ' - ' || p_sublote);
         END;
      
         BEGIN
            --validar el nro. de caja.
            v_msj_caja := lf_val_caja(p_lote, v_nro_caja);
         
            --traemos los datos de la caja.
            SELECT c.cod_oficina, c.fec_hor_cierre
              INTO codigoOficinaOrigen, fechaUltimoCierre
              FROM cj_cajas c
             WHERE nro_caja = v_nro_caja
                   AND estado = 'A' --activo
                   AND tipo IN ('C', 'I', 'S');
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al obtener los datos de la caja: ' || v_nro_caja || ' - sublote: ' || p_sublote);
         END;
      
         BEGIN
            --verificamos el horario para que no se procese estando en cierre
            retError := lp_ver_horario(fechaUltimoCierre, codigoOficinaOrigen, v_horario, v_es_mov_noc, v_es_cta_noc, v_fec_actual);
         EXCEPTION
            WHEN OTHERS THEN
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al verificar el horario y estado de los módulos.' || ' - sublote: ' || p_sublote);
         END;
      
         --si hay problemas con la caja
         IF v_msj_caja.error = 'S' THEN
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: ' || v_msj_caja.nombreRespuesta || '. ' || v_msj_caja.descripcionRespuesta  || ' - sublote: ' || p_sublote);
         
            --si hay problemas del horario para ejecutar. No se procesa si es que está en Cierre.
         ELSIF retError.error = 'S' THEN
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: ' || retError.nombreRespuesta || '. ' || retError.descripcionRespuesta|| ' - sublote: ' || p_sublote);
         ELSE
            v_tip_transaccion := 'S';
         
            --- parametro si se puede procesar con errores un archivo.
            v_pro_con_errores := UPPER(NVL(fug_obt_parentes(v_ente, 'PRO_CON_ERRORES'), 'N'));
         
            -- hallamos el nro de archivo (secuencia) para enviar a la función de validación
            v_nro_archivo := LF_OBT_NRO_SECUENCIA(v_ente, TRUNC(SYSDATE));
         
            --
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION->LP_INS_PAG_SUE_SUBLOTE. Secuencia: ' || v_nro_archivo || ' - sublote: ' || p_sublote);
         
            LP_INS_PAG_SUE_SUBLOTE(v_verifica_ok, v_cant_error, v_mensaje_error, p_lote, v_nro_archivo, p_sublote);
         
            IF v_verifica_OK = 'S' THEN
               -- si no hubo errores
               -- se puede realizar la acreditación
               --se  inserta en la tabla ge_pag_sue
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION->lp_ins_tabla');
            
               lp_ins_tabla(v_error, v_nro_archivo, v_pro_con_errores, p_lote, p_sublote);
            
               IF v_error = 'S' THEN
                  -- hubo error
                  pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al intentar insertar en ge_pag_sue' || ' - sublote: ' || p_sublote);
               ELSE
                  pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION->LP_ACR_EMPLEADO'|| ' - sublote: ' || p_sublote);
                  LP_ACR_EMPLEADO(v_ente, p_lote, v_nro_archivo, v_cod_ofi, v_fecha, USER, v_error, v_tip_transaccion, null, p_sublote);
               END IF;
            ELSE
               --actualizamos la cabecera con estado -> E y con comentarios.
               UPDATE ge_pag_sue_ips c
                  SET c.estado      = 'E',
                      c.comentarios = substr(v_mensaje_error,1,999)
                WHERE c.nro_lote = p_lote;
            
               -- si no resulto la validación de pr ins ge pag sueldo
               pr_ins_bitacora(p_lote, NULL, ' sublote: ' || p_sublote || ' '|| SUBSTR(SQLERRM, 1 , 2899));
               pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error en el lote o detalle 2'|| ' - sublote: ' || p_sublote);
            END IF;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            pr_ins_bitacora(p_lote, NULL, ' sublote: ' || p_sublote || ' '|| SUBSTR(SQLERRM, 1 , 2899));
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_ACREDITACION: Error al procesar el lote: ' || p_lote|| ' - ' || p_sublote);
      END;
   
   END PR_PRO_ACR_SUBLOTE;
   
   /*
   * BSEVOCORE-451 NAF 05/2020
   * Procedimiento que genera sublotes para el lote del parametro
   */
   PROCEDURE LP_GEN_SUBLOTES(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
     v_can_acr_sublotes   number := 0;
     v_acu_sublotes       number := 1;
     v_contador           number := 0;
     v_exi_sublotes       varchar2(1);
     v_con_reg_lote       number;
     cursor c_det_lote is
        SELECT d.nro_orden, d.nro_lote
        FROM ge_pag_sue_ips_det d
         JOIN ge_pag_sue_ips c
           ON d.nro_lote = c.nro_lote
        WHERE d.nro_lote = p_lote
              AND c.estado IN ('V', 'P') --lote verificado y procesado.
              AND d.estado = 'P' -- Pendientes de acreditación
              AND d.fec_acreditacion IS NULL
              AND d.fe_vida = 'S';
   BEGIN
     BEGIN
       select 'S'
       INTO v_exi_sublotes
       from GE_PAG_SUE_IPS_SUBLOTES 
       where nro_lote = p_lote
       and rownum = 1; 
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
         v_exi_sublotes := 'N';
     END;
     -- si no exite sub lote para el lote, lo genera
     IF v_exi_sublotes = 'N' THEN
       v_can_acr_sublotes := nvl(fug_obt_pardinamico('IPS_REG_SUBLOTES'),'1000');
       v_con_reg_lote := 0;
       FOR reg IN c_det_lote
       LOOP
           v_con_reg_lote := 1;
           Insert into GE_PAG_SUE_IPS_SUBLOTES (NRO_ORDEN, NRO_LOTE, NRO_SUBLOTE)
           values ( reg.nro_orden, reg.nro_lote, v_acu_sublotes);
           v_contador := v_contador + 1;
           if v_contador = v_can_acr_sublotes then
              v_acu_sublotes := v_acu_sublotes + 1;
              v_contador := 0;
           end if;
       END LOOP;
       IF v_con_reg_lote = 0 THEN
           pr_ins_bitacora(p_lote, NULL, 'LP_GEN_SUBLOTES: ERROR no encuentra detalles de lote ' || p_lote);
       END IF;
     END IF;
   END LP_GEN_SUBLOTES;
   
   /*
   * BSEVOCORE-451 NAF 05/2020
   * Devuelve el menor sublote con acreditaciones pendientes
   */
   FUNCTION LF_OBT_SUBLOTE(p_lote ge_pag_sue_ips.nro_lote%TYPE) return number IS
   v_sub_lote number;
   BEGIN
       select min(a.nro_sublote)
       into v_sub_lote
       from GE_PAG_SUE_IPS_SUBLOTES a
           join GE_PAG_SUE_IPS_DET b on a.nro_orden=b.nro_orden
                and a.nro_lote=b.nro_lote
       where b.nro_lote = p_lote
       and b.estado = 'P'
       and b.fe_vida = 'S';
       
       return v_sub_lote;
   EXCEPTION
      when others then
       return null;
   END LF_OBT_SUBLOTE;
   
   /*
   * BSEVOCORE-451 NAF 05/2020
   * Devuelve el menor y mayor sublote existente par ael lote del parametro
   */
   PROCEDURE LP_OBT_DAT_SUBLOTE(p_lote IN  ge_pag_sue_ips.nro_lote%TYPE,
                               p_min_sublote OUT number,
                               p_max_sublote OUT number   
                               ) IS
   BEGIN
       select min(a.nro_sublote), max(a.nro_sublote)
       into p_min_sublote, p_max_sublote
       from GE_PAG_SUE_IPS_SUBLOTES a
           join GE_PAG_SUE_IPS_DET b on a.nro_orden=b.nro_orden
                and a.nro_lote=b.nro_lote
       where b.nro_lote = p_lote
       and b.estado = 'P'
       and b.fe_vida = 'S';
   EXCEPTION
      when NO_DATA_FOUND then
        pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_SUBLOTE:  no se recuperan sublotes para lote ' || p_lote);
        p_min_sublote := 0;
        p_max_sublote := 0;
      when others then
        pr_ins_bitacora(p_lote, NULL, 'LP_OBT_DAT_SUBLOTE:  ' || substr(SQLERRM,1000));
        p_min_sublote := 0;
        p_max_sublote := 0;
   END LP_OBT_DAT_SUBLOTE;
   
   /*
   * BSEVOCORE-451 NAF 05/2020
   * Mantenimiento de datos de tabla de SubLotes GE_PAG_SUE_IPS_SUBLOTES
   * Elimina los registros de sublotes con mas de un mes de vencimiento
   */ 
   PROCEDURE LP_MAN_SUBLOTES (p_lote ge_pag_sue_ips.nro_lote%TYPE default null) IS
     PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
     -- se eliminan sublotes de lotes vencidos en el mes antepasado
     delete ge_pag_sue_ips_sublotes a
     where a.nro_lote IN (select b.nro_lote
         from ge_pag_sue_ips b 
             join (select to_date('01'||to_char(c.pri_dia_mes-1,'/mm/yyyy'),'dd/mm/yyyy') fec_almacenar
                  from ge_calendarios c 
                  where c.cod_modulo=3) c on b.fec_vencimiento < c.fec_almacenar);
     commit;
   EXCEPTION
      when others then
        -- no interrumpimos ejecucion en caso de error
        pr_ins_bitacora(p_lote, NULL, 'LP_MAN_SUBLOTES: ERROR: ' ||substr(SQLERRM, 1, 100) );
   END;    
      
   /*
   Procedimiento que realiza la validación de los lotes de pago a jubilados de IPS
   Las validaciones son las mismas que se realizan en el paquete PAW_BEL para los pagos de nominas que se procesan en BBVA Net.
   @param p_lote ID del lote de pagos a validar.
   @param p_modo Indica si los chequeos son en modo Validación o Procesar.
   */
   PROCEDURE PR_PRO_VALIDACION(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
      --estructura que representa el archivo (cabecera y detalle)
      v_lote typ_lotepagosueldoips := typ_lotepagosueldoips();
   
      --estructura que representa el pago a acreditar
      v_pago typ_pagosueldoips := typ_pagosueldoips();
   
      --para validaciones de la caja
      v_msj_caja typ_mensajeCaja;
      v_nro_caja cj_cajas.nro_caja%TYPE := 999;
   
      --Datos asociados al Ente de PS IPS
      v_cod_persona_ips ba_personas.cod_persona%TYPE;
      v_nro_documento   ba_personas.nro_documento%TYPE;
      v_cod_ente        NUMBER(6); -- codigo del ente
      v_des_ente        VARCHAR2(100); -- descripcion del ente
      v_nro_cta_debito  VARCHAR2(17); -- cuenta de debito
      v_for_archivo     VARCHAR2(100);
      v_val_nro_doc     ge_par_entes.val_parametro%TYPE;
   
      v_cta_formateada VARCHAR2(17); -- cuenta formateada
      v_cod_tip_cuenta VARCHAR2(2); -- codigo del tipo de cuenta
      v_des_tip_cuenta VARCHAR2(35); -- descripcion del tipo de cuenta
      v_cod_moneda     VARCHAR2(3); -- moneda de la cuenta
      v_nom_cuenta     VARCHAR2(100); -- nombre de la cuenta
      v_cod_modulo     ge_cuentas.cod_modulo%TYPE;
   
      v_cod_modalidad ge_cuentas.cod_modalidad%TYPE;
      v_activo        ge_est_cuentas.activo%TYPE;
      v_est_cuenta    ge_cuentas.estado%TYPE;
   
      v_val_cta VARCHAR2(2) := '';
   
      v_redondeo NUMBER;
   
      v_msj_bitacora VARCHAR2(500) := '';
      v_cod_res_cta  VARCHAR2(3); -- respuesta por cada cuenta
      --v_cod_error     NUMBER := 0; -- 0: Ok, 1: Error en cuenta, 2: Error en monto, 3: error en cuenta y monto
      v_mensaje       VARCHAR2(100);
      v_msj_respuesta typ_MensajeRespuesta := typ_MensajeRespuesta;
      v_con_error_cab BOOLEAN := FALSE;
      v_con_error_det BOOLEAN := FALSE;
   
      --cod. de Transaccion
      v_cod_tra_padre   ge_transacciones.cod_transaccion%TYPE;
      v_cod_transaccion ge_transacciones.cod_transaccion%TYPE;
   
      v_nro_doc_generico ge_par_dinamicos.val_parametro%TYPE;
      --Moneda del crédito, por defecto Gs.
      v_codMoneda ge_cuentas.cod_moneda%TYPE := 'GS';
   
      codigoOficinaOrigen cj_cajas.cod_oficina%TYPE;
      retError            typ_mensajeRespuesta := typ_mensajeRespuesta;
      v_horario           VARCHAR2(1);
      v_es_mov_noc        VARCHAR2(1);
      v_es_cta_noc        VARCHAR2(1);
      v_fec_actual        DATE;
      fechaUltimoCierre   cj_cajas.fec_hor_cierre%TYPE;
   
      --cursor con los datos del lote a procesar.
      CURSOR c_lotes_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT c.*,
                (SELECT COUNT(*)
                    FROM ge_pag_sue_ips_det d
                   WHERE d.nro_lote = p_lote) cantRegistros
           FROM ge_pag_sue_ips c
          WHERE c.nro_lote = p_lote
                AND c.estado = 'I' --insertado
                AND trunc(c.fec_vencimiento) >= trunc(SYSDATE); --lote vigente
   
      --cursor con los datos de los pagos insertados y que deben ser verificados.
      CURSOR c_pagos(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
         SELECT d.*
           FROM ge_pag_sue_ips_det d
           JOIN ge_pag_sue_ips c
             ON d.nro_lote = c.nro_lote
          WHERE d.nro_lote = p_lote
                AND c.estado = 'I' --lote insertado
                AND d.estado = 'I' --registros insertados
                AND trunc(c.fec_vencimiento) >= trunc(SYSDATE); --lote vigente
   
   BEGIN
      --leemos el lote a procesar
      BEGIN
         --traemos los datos de la caja.
         SELECT c.cod_oficina, c.fec_hor_cierre
           INTO codigoOficinaOrigen, fechaUltimoCierre
           FROM cj_cajas c
          WHERE nro_caja = v_nro_caja
                AND estado = 'A' --activo
                AND tipo IN ('C', 'I', 'S');
      
         --verificamos el horario para que no se procese estando en cierre
         retError := lp_ver_horario(fechaUltimoCierre, codigoOficinaOrigen, v_horario, v_es_mov_noc, v_es_cta_noc, v_fec_actual);
      
         IF retError.error = 'S' THEN
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_VALIDACION: ' || retError.nombreRespuesta || '. ' || retError.descripcionRespuesta);
         ELSE
            FOR c_lote IN c_lotes_pagos(p_lote)
            LOOP
               --almacenamos los datos del lote de pago.
               v_lote.nroLote           := c_lote.nro_lote;
               v_lote.estado            := c_lote.estado;
               v_lote.fechaAcreditacion := c_lote.fec_acreditacion;
               v_lote.fechaVencimiento  := c_lote.fec_vencimiento;
               v_lote.tipoProceso       := c_lote.tip_proceso;
               v_lote.nroCtaPagSalario  := c_lote.nro_cta_pag_salario;
            
               --validamos que tenga detalles el lote.
               IF c_lote.cantregistros = 0 THEN
                  v_con_error_cab    := TRUE;
                  v_msj_bitacora     := 'El lote de archivo no tiene detalles de pagos asociado.';
                  v_lote.estado      := 'E';
                  v_lote.comentarios := v_msj_bitacora;
                  pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_msj_bitacora);
               END IF;
            
               --validar el nro. de caja.
               --corregir por el nombre correcto del parametro dinamico.
               --v_nro_caja := fug_obt_pardinamico('IPS_NRO_CAJA');
               v_msj_caja := lf_val_caja(p_lote, v_nro_caja);
            
               IF v_msj_caja.error = 'S' THEN
                  v_con_error_cab    := TRUE;
                  v_msj_bitacora     := v_msj_caja.descripcionRespuesta;
                  v_lote.estado      := 'E';
                  v_lote.comentarios := v_msj_bitacora;
                  pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_msj_bitacora);
               END IF;
            
               --obtenemos los datos del ente CodPersona, RUC, CodEnte, Descripcion, NroCtaDebito, Formato de Archivo, Validar Doc.
               BEGIN
                  SELECT a.cod_persona, p.nro_documento, a.cod_ente, a.descripcion, fug_obt_parentes(a.cod_ente, 'NRO_CTA_DEBITO'), fug_obt_parentes(a.cod_ente, 'REFERENCIA_TXT_SUELDO'), TRIM(fug_obt_parentes(a.cod_ente, 'VAL_NRO_DOCUMENTO'))
                    INTO v_cod_persona_ips, v_nro_documento, v_cod_ente, v_des_ente, v_nro_cta_debito, v_for_archivo, v_val_nro_doc
                    FROM ge_entes a
                    JOIN ba_personas p
                      ON a.cod_persona = p.cod_persona
                   WHERE a.tipo = 'SU' --ente para Pago de Salarios
                         AND a.cod_ente = c_lote.cod_ente --CodEnte
                         AND fug_obt_parentes(a.cod_ente, 'SER_ACTIVO') = 'S'; --Habilitado el servicio de Pago de Salarios
               EXCEPTION
                  WHEN too_many_rows THEN
                     v_con_error_cab    := TRUE;
                     v_msj_bitacora     := 'No se puede obtener los datos del ente:  ' || c_lote.cod_ente;
                     v_lote.estado      := 'E';
                     v_lote.comentarios := v_msj_bitacora;
                     pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_msj_bitacora);
                  WHEN OTHERS THEN
                     v_con_error_cab    := TRUE;
                     v_msj_bitacora     := v_msj_bitacora || ', ORA-ERR: [' || substr(SQLERRM, 1, 100) || ']';
                     v_lote.estado      := 'E';
                     v_lote.comentarios := v_msj_bitacora;
                     pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_msj_bitacora);
               END;
            
               --validamos el estado de la cuenta débito.
               SELECT fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada,
                      --
                      paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
                      --
                      fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta, a.denominacion nom_cuenta, a.cod_moneda cod_moneda,
                      --
                      a.cod_modulo, a.cod_modalidad, c.activo, a.estado
                 INTO v_cta_formateada,
                      --
                      v_cod_tip_cuenta,
                      --
                      v_des_tip_cuenta, v_nom_cuenta, v_cod_moneda,
                      --
                      v_cod_modulo, v_cod_modalidad, v_activo, v_est_cuenta
               
                 FROM ge_est_cuentas c, ge_cuentas a
                WHERE a.nro_cuenta = TRIM(v_lote.nroCtaPagSalario)
                      AND a.cod_modulo = c.cod_modulo
                      AND a.cod_modalidad = c.cod_modalidad
                      AND a.estado = c.estado;
            
               --validamos que coincidan las monedas
               IF v_codMoneda <> v_cod_moneda THEN
                  v_con_error_cab    := TRUE;
                  v_lote.estado      := 'E';
                  v_lote.comentarios := 'La moneda de la cuenta es invalida';
                  pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_lote.comentarios);
               END IF;
            
               IF v_activo != 'S' THEN
                  v_con_error_cab    := TRUE;
                  v_lote.estado      := 'E';
                  v_lote.comentarios := 'Cuenta: ' || v_lote.nroCtaPagSalario || ' inactiva.';
                  pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_lote.comentarios);
               END IF;
            
               IF v_cod_modalidad NOT IN (31, 41) THEN
                  v_con_error_cab    := TRUE;
                  v_lote.estado      := 'E';
                  v_lote.comentarios := 'Cuenta: ' || v_lote.nroCtaPagSalario || ' con modalidad incorrecta: ' || v_cod_modalidad;
                  pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_lote.comentarios);
               END IF;
            
               IF v_est_cuenta IN ('X', 'C', 'P') THEN
                  v_con_error_cab    := TRUE;
                  v_lote.estado      := 'E';
                  v_lote.comentarios := 'Cuenta: ' || v_lote.nroCtaPagSalario || ' con estado incorrecto: ' || v_est_cuenta;
                  pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_lote.comentarios);
               END IF;
            
               --fin validacion
               /* OMM 13/01/2011 --Se agrego esta validaciòn solo para el BBVA por mala
               configuraciòn del OAS de Produccion en ITGF (el parametro "NLS_NUMERIC_CHARACTER" no estaba
               configurado en el OAS por esto se procesa con otro tipo de archivo en USD)   */
               IF v_for_archivo = 'PAG_SUELDOS_USD' THEN
                  v_for_archivo := 'PAG_SUELDOS';
               END IF;
            
               --obtenemos la cantidad de decimales por moneda
               v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', NULL, NULL, v_codMoneda, NULL, NULL);
            
               -- obtenemos la transacción padre
               v_cod_tra_padre := LF_OBT_TRA_SUELDO(v_cod_ente, 'S');
            
               --Nro. Doc. por defecto
               v_nro_doc_generico := fug_obt_pardinamico('NRO_DOC_GEN_PAG_SAL');
            
               -- validar siempre que la cuenta debito pertenezca al ente (en base a NroCta y RUC)
               -- OMM 07/10/2010 Valida q la Cta debito sea de la empresa.
            
               v_val_cta := lf_cta_valida(v_nro_cta_debito, v_nro_documento);
            
               IF v_val_cta != '0' THEN
                  v_con_error_cab := TRUE;
               
                  IF v_val_cta = 1 THEN
                     v_msj_bitacora := v_msj_bitacora || 'El Nro. de Documento: [' || v_nro_documento || '] no existe.';
                  ELSIF v_val_cta = 2 THEN
                     v_msj_bitacora := v_msj_bitacora || 'La cuenta: [' || v_nro_cta_debito || '] no existe.';
                  ELSIF v_val_cta = 3 THEN
                     v_msj_bitacora := v_msj_bitacora || 'La cuenta: [' || v_nro_cta_debito || '] no pertenece a la Empresa.';
                  ELSE
                     v_msj_bitacora := v_msj_bitacora || 'Hubo un error en la validación de la Cuenta: [' || v_nro_cta_debito || '] y el Nro. Documento: [' || v_nro_documento || '].';
                  END IF;
               
                  v_lote.estado      := 'E';
                  v_lote.comentarios := v_msj_respuesta.descripcionRespuesta;
                  pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_msj_bitacora);
               END IF;
            
               --solo si no tuvo errores la cabecera, se recorren los detalles.
               IF NOT v_con_error_cab THEN
                  --marcamos como Verificado el lote.
                  v_lote.estado := 'V';
               
                  --validamos los pagos del lote
                  FOR c_pago IN c_pagos(p_lote)
                  LOOP
                     v_cod_res_cta := paw_bce.v_cod_aprobado;
                     --almacenamos el código de cada pago, estado y comentarios.
                     v_pago.nroLote                 := c_pago.nro_lote;
                     v_pago.nroOrden                := c_pago.nro_orden;
                     v_pago.estado                  := 'P'; --pendiente de acreditación.
                     v_pago.comentarios             := ''; --limpiamos cualquier comentario
                     v_pago.nroComprobanteDuplicado := c_pago.nro_com_duplicado;
                     v_pago.importe                 := c_pago.importe;
                  
                     -- validamos la cuenta crédito recibida
                     BEGIN
                        v_cta_formateada := NULL;
                        v_cod_tip_cuenta := NULL;
                        v_des_tip_cuenta := NULL;
                        v_nom_cuenta     := NULL;
                        v_cod_moneda     := NULL;
                        v_cod_modulo     := NULL;
                     
                        SELECT fug_cta_formateada(a.cod_modulo, a.cod_modalidad, a.cod_oficina, a.nro_cuenta, a.cod_moneda) cta_formateada,
                               --
                               paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta,
                               --
                               fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta, a.denominacion nom_cuenta, a.cod_moneda cod_moneda,
                               --
                               a.cod_modulo, a.cod_modalidad, c.activo, a.estado
                          INTO v_cta_formateada,
                               --
                               v_cod_tip_cuenta,
                               --
                               v_des_tip_cuenta, v_nom_cuenta, v_cod_moneda,
                               --
                               v_cod_modulo, v_cod_modalidad, v_activo, v_est_cuenta
                        
                          FROM ge_est_cuentas c, ge_cuentas a
                         WHERE a.nro_cuenta = TRIM(c_pago.nro_cta_jubilado) --confirmar si es cta. del cliente.
                               AND a.cod_modulo = c.cod_modulo
                               AND a.cod_modalidad = c.cod_modalidad
                               AND a.estado = c.estado;
                     
                        --validamos que coincidan las monedas
                        IF v_codMoneda <> v_cod_moneda THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_invalida; -- moneda diferente
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'La moneda de la cuenta es invalida';
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        END IF;
                     
                        IF v_activo != 'S' THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_invalida;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'Cuenta: ' || c_pago.nro_cta_jubilado || ' inactiva.';
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        END IF;
                     
                        IF v_cod_modalidad NOT IN (31, 41) THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_invalida;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'Cuenta: ' || c_pago.nro_cta_jubilado || ' con modalidad incorrecta: ' || v_cod_modalidad;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        END IF;
                     
                        IF v_est_cuenta IN ('X', 'C', 'P') THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_invalida;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'Cuenta: ' || c_pago.nro_cta_jubilado || ' con estado incorrecto: ' || v_est_cuenta;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        END IF;
                     
                     EXCEPTION
                        WHEN no_data_found THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_inexistente;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'Cuenta: ' || c_pago.nro_cta_jubilado || ' no existe.';
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        WHEN too_many_rows THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_duplicada;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'Cuenta duplicada: ' || c_pago.nro_cta_jubilado;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        WHEN OTHERS THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_invalida;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'Cuenta invalida: ' || c_pago.nro_cta_jubilado || ' ' || SQLERRM;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                     END;
                     -- validamos que no se acredite a cuenta propia de IPS
                     IF v_cod_res_cta = paw_bce.v_cod_aprobado THEN
                        IF lf_val_cta_origen(c_pago.nro_cta_jubilado, nvl(v_cod_persona_ips, 86383)) = 'S' THEN
                           v_con_error_det    := TRUE;
                           v_cod_res_cta      := paw_bce.v_cod_cta_invalida;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'La cuenta pertenece al ente: ' || c_pago.nro_cta_jubilado;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        END IF;
                     END IF;
                  
                     IF c_pago.importe <= 0 THEN
                        v_con_error_det := TRUE;
                     
                        IF v_cod_res_cta = paw_bce.v_cod_aprobado THEN
                           -- monto inválido
                           v_cod_res_cta      := paw_bce.v_cod_mto_invalido;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'Monto invalido: ' || c_pago.importe;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        ELSE
                           v_pago.estado      := 'E';
                           v_pago.comentarios := v_mensaje || '. Monto Invalido: ' || c_pago.importe;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        END IF;
                     END IF;
                     -- valido los decimales
                     IF c_pago.importe > 0 AND v_pago.importe <> trunc(c_pago.importe, v_redondeo) THEN
                        v_con_error_det := TRUE;
                     
                        IF v_cod_res_cta = paw_bce.v_cod_aprobado THEN
                           v_cod_res_cta      := paw_bce.v_mon_dec_invalida;
                           v_pago.estado      := 'E';
                           v_pago.comentarios := 'La cuenta no admite decimal: ' || c_pago.nro_cta_jubilado;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        ELSE
                           v_pago.estado      := 'E';
                           v_pago.comentarios := v_mensaje || '. La cuenta no admite decimal: ' || c_pago.nro_cta_jubilado;
                           pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                        END IF;
                     END IF;
                     -- se valida el documento con la cuenta si se recibe
                     IF v_val_nro_doc = 'S' THEN
                        --validamos la cuenta, si retorna 0, la cuenta está asociada al Nro. de Documento
                        v_val_cta := lf_cta_valida(c_pago.Nro_Cta_Jubilado, c_pago.nro_doc_jubilado);
                     
                        IF v_nro_doc_generico <> nvl(c_pago.nro_doc_jubilado, '0') AND v_val_cta != '0' THEN
                        
                           v_con_error_det := TRUE;
                        
                           IF v_val_cta = 1 THEN
                              v_msj_bitacora := 'El Nro. de Documento: [' || c_pago.nro_doc_jubilado || '] no existe.';
                           ELSIF v_val_cta = 2 THEN
                              v_msj_bitacora := 'La cuenta: [' || c_pago.Nro_Cta_Jubilado || '] no existe.';
                           ELSIF v_val_cta = 3 THEN
                              v_msj_bitacora := 'La cuenta: [' || c_pago.Nro_Cta_Jubilado || '] no está asociada al Nro. de Documento: [' || c_pago.nro_doc_jubilado || ']';
                           ELSE
                              v_msj_bitacora := 'Hubo un error en la validación de la Cuenta: [' || c_pago.Nro_Cta_Jubilado || '] y el Nro. Documento: [' || c_pago.nro_doc_jubilado || '].';
                           END IF;
                        
                           v_pago.estado      := 'E';
                           v_pago.comentarios := v_msj_bitacora;
                           pr_ins_bitacora(v_lote.nroLote, NULL, 'PR_PRO_VALIDACION: ' || v_msj_bitacora);
                        
                        END IF;
                     END IF;
                  
                     -- verificamos si se puede realizar la operación de débito/crédito
                     IF v_cod_res_cta = paw_bce.v_cod_aprobado THEN
                        -- obtenemos el codigo de transacción, Crédito
                        v_cod_transaccion := 602;
                     
                        -- verificamos si se puede realizar la operacion, para fecha futura no debe validar saldo disponible
                        -- Tipo C -> crédito.
                        IF paw_bce.fu_ver_operacion(c_pago.nro_cta_jubilado, c_pago.importe, v_cod_transaccion, v_cod_tra_padre, 'C') = 'N' THEN
                           IF pag_cta.g_cod_error <> 0 THEN
                              -- controlamos si dispone de saldo suficiente
                              IF pag_cta.g_cod_error NOT IN (25, 29, 31, 36) THEN
                                 v_con_error_Det := TRUE;
                                 -- hubo otro error
                                 v_cod_res_cta      := paw_bce.v_cod_cta_invalida;
                                 v_pago.estado      := 'E';
                                 v_pago.comentarios := 'Cuenta invalida: ' || c_pago.nro_cta_jubilado || '. CodError: ' || pag_cta.g_cod_error || '. DesError: ' || pag_cta.g_msj_error;
                                 pr_ins_bitacora(c_pago.nro_lote, c_pago.nro_orden, 'PR_PRO_VALIDACION: ' || v_pago.comentarios);
                              END IF;
                           END IF;
                        END IF;
                     
                     END IF;
                  
                     --si el nro. de comprobante ips está duplicado, agregamos el comentario
                     --sólo si el registro de pago no tuvo otro error en la validación.
                     IF v_pago.nroComprobanteDuplicado = 'S' AND v_pago.estado != 'E' THEN
                        v_pago.comentarios := 'Nro. de Comprobante IPS: ' || to_char(c_pago.nro_comprobante) || ' duplicado.';
                     END IF;
                  
                     --actualizar los datos del pago.
                     LP_ACT_PAGO(v_pago, FALSE);
                  END LOOP;
               
                  --si la valicación del lote resultó OK, se agenda para procesamiento
                  IF v_con_error_det = FALSE AND v_lote.tipoProceso = 'V' THEN
                     v_lote.tipoProceso := 'P';
                     --actualizamos el estado, comentarios y tipo de proceso del lote de pagos.
                     LP_ACT_LOTE(v_lote, TRUE);
                     pr_ins_bitacora(p_lote, NULL, 'Lote: ' || v_lote.nroLote || ' validado y registrado para procesarse. F.Acreditación: ' || v_lote.fechaAcreditacion || '. F.Vencimiento: ' || v_lote.fechaVencimiento);
                  ELSIF v_con_error_det = FALSE AND v_lote.tipoProceso = 'P' THEN
                     --actualizamos el estado y comentarios del lote de pagos.
                     LP_ACT_LOTE(v_lote, FALSE);
                     pr_ins_bitacora(p_lote, NULL, 'Lote: ' || v_lote.nroLote || ' validado y a procesarse sin errores. F.Acreditación: ' || v_lote.fechaAcreditacion || '. F.Vencimiento: ' || v_lote.fechaVencimiento);
                  ELSIF v_con_error_det = TRUE AND v_lote.tipoProceso = 'P' THEN
                     --actualizamos el estado y comentarios del lote de pagos.
                     LP_ACT_LOTE(v_lote, FALSE);
                     pr_ins_bitacora(p_lote, NULL, 'Lote: ' || v_lote.nroLote || ' validado y a procesarse. Hubo registros con error, ver más información en los comentarios de los pagos. F.Acreditación: ' || v_lote.fechaAcreditacion || '. F.Vencimiento: ' || v_lote.fechaVencimiento);
                  ELSE
                     --actualizamos el estado y comentarios del lote de pagos.
                     LP_ACT_LOTE(v_lote, FALSE);
                     pr_ins_bitacora(p_lote, NULL, 'Lote: ' || v_lote.nroLote || ' validado. Más información de los errores en los comentarios de los pagos. F.Acreditación: ' || v_lote.fechaAcreditacion || '. F.Vencimiento: ' || v_lote.fechaVencimiento);
                  END IF;
               ELSE
                  --actualizamos con error el lote.
                  LP_ACT_LOTE(v_lote, FALSE);
               END IF;
            END LOOP;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_msj_bitacora     := v_msj_bitacora || 'No se pudo procesar el lote de pagos con ID: ' || p_lote || '. Archivo: ' || v_lote.nombreArchivo || '. ' || SQLERRM;
            v_lote.estado      := 'E';
            v_lote.comentarios := v_msj_bitacora;
            pr_ins_bitacora(p_lote, NULL, 'PR_PRO_VALIDACION: ' || v_msj_bitacora);
         
            LP_ACT_LOTE(v_lote, FALSE);
      END;
   
   END PR_PRO_VALIDACION;

   /**
   * Procedimiento que procesa la conciliación de los lotes de pagos acreditados.
   * La diferencia de los montos no acreditados, se transfiere a la cuenta operativa del IPS.
   */
   PROCEDURE PR_PRO_CONCILIACION(p_lote ge_pag_sue_ips.nro_lote%TYPE) IS
   
      --
      v_mto_reg_archivo ge_pag_sue_ips.mto_debito%TYPE := 0;
      v_nom_archivo     ge_pag_sue_ips.nom_archivo%TYPE;
   
      v_mto_registrado   ge_pag_sue_ips_det.importe%TYPE := 0;
      v_mto_debitado     ge_pag_sue_ips_det.importe%TYPE := 0;
      v_mto_acreditado   ge_pag_sue_ips_det.importe%TYPE := 0;
      v_mto_movimientos  ge_pag_sue_ips_det.importe%TYPE := 0;
      v_monto_diferencia ge_pag_sue_ips_det.importe%TYPE := 0;
   
      v_cc_montos ge_pag_sue_ips_det.importe%TYPE := 0;
      v_ah_montos ge_pag_sue_ips_det.importe%TYPE := 0;
      v_error     BOOLEAN;
   BEGIN
      BEGIN
         v_error := FALSE;
         --traemos los datos del lote
         BEGIN
            SELECT c.mto_debito, c.nom_archivo
              INTO v_mto_reg_archivo, v_nom_archivo
              FROM ge_pag_sue_ips c
             WHERE c.nro_lote = p_lote
                   AND c.estado = 'P' --procesado
                   AND c.tip_proceso = 'P' --para procesar
                   AND c.fec_vencimiento <= trunc(SYSDATE); --se concilia en la fecha o en fechas anteriores
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               v_error := TRUE;
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: No se encontraron datos del lote a conciliar: ' || p_lote || '. Favor verificar.');
            WHEN OTHERS THEN
               v_error := TRUE;
            
               --actualizamos el lote de pago
               UPDATE ge_pag_sue_ips
                  SET ESTADO      = 'E',
                      COMENTARIOS = 'Error al conciliar el lote de pagos'
                WHERE nro_lote = p_lote;
            
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: No se encontraron datos del lote a conciliar: ' || p_lote || '. Favor verificar.');
         END;
      
         pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Total original registrado a partir del archivo de IPS: ' || p_lote || '. Total:.' || nvl(v_mto_reg_archivo, 0));
      
         IF NOT v_error THEN
            BEGIN
               --sumarizamos el total registrado a partir del archivo de IPS y lo acreditado.
               SELECT SUM(d.importe)
                 INTO v_mto_registrado
                 FROM ge_pag_sue_ips_det d
                 JOIN ge_pag_sue_ips c
                   ON d.nro_lote = c.nro_lote
                WHERE c.nro_lote = p_lote
                      AND c.estado = 'P' --procesado
                      AND c.tip_proceso = 'P' --para procesar
                      AND d.estado = 'A' --acreditado
                      AND d.fec_acreditacion IS NOT NULL; --con fecha de acreditación
               -- insertamos en bitacora el v_mto_registrado
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Sumarización el total acreditado: ' || p_lote || '. Total:.' || nvl(v_mto_registrado, 0));
            
               --sumarizamos el total debitado en la tabla de sueldos
               SELECT SUM(s.monto) --suma de los débitos hechos
                 INTO v_mto_debitado
                 FROM ge_pag_sueldos s
                 JOIN ge_pag_sue_ips c
                   ON s.cod_ente = c.cod_ente
                      AND s.nro_cuenta = c.nro_cta_pag_salario
                      AND s.observacion = c.nro_lote --cod. cabecera
                WHERE s.procesado = 'S' --procesados
                      AND s.tipo = 'D' --los débitos hechos
                      AND c.nro_lote = p_lote; --lote
               -- insertamos en bitactora el v_mto_debitado
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Sumarización del total debitado en la tabla de sueldos: ' || p_lote || '. Total:.' || nvl(v_mto_debitado, 0));
            
               --sumarizamos el total acreditado en la tabla de sueldos
               SELECT SUM(s.monto) --suma de los créditos  hechos
                 INTO v_mto_acreditado
                 FROM ge_pag_sueldos s
                 JOIN ge_pag_sue_ips_det d
                   ON s.observacion = d.nro_orden --cod. detalle de pago
                      AND d.estado = 'A' --acreditados
                      AND s.nro_documento = d.nro_doc_jubilado --nro. doc. jubilado
                      AND s.fec_proceso = trunc(d.fec_acreditacion) --en fec. acreditacion
                      AND S.MONTO = d.importe --monto acreditado
                 JOIN ge_pag_sue_ips c
                   ON d.nro_lote = c.nro_lote
                      AND s.cod_ente = c.cod_ente
                WHERE s.procesado = 'S' --procesados
                      AND s.tipo = 'C' --los créditos hechos
                      AND c.nro_lote = p_lote; --lote
            
               -- insertamos en bitacora el v_mto_acreditado
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Sumarización el total acreditado en la tabla de sueldos: ' || p_lote || '. Total:.' || nvl(v_mto_acreditado, 0));
            
               IF v_mto_registrado != v_mto_debitado AND v_mto_debitado != v_mto_acreditado THEN
                  v_error := TRUE;
               
                  --actualizamos el lote de pago
                  UPDATE ge_pag_sue_ips
                     SET ESTADO      = 'E',
                         COMENTARIOS = 'No coinciden los montos en ge_pag_sue_ips_det y ge_pag_sueldos (débitos y créditos). Favor verificar.'
                   WHERE nro_lote = p_lote;
               
                  pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: No coinciden los montos en ge_pag_sue_ips_det y ge_pag_sueldos (débitos y créditos). Favor verificar.');
               END IF;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  v_error := TRUE;
                  pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Error al conciliar: ' || p_lote || '. Favor verificar.');
               
               WHEN OTHERS THEN
                  v_error := TRUE;
               
                  --actualizamos el lote de pago
                  UPDATE ge_pag_sue_ips
                     SET ESTADO      = 'E',
                         COMENTARIOS = 'Error al conciliar: ' || p_lote || '. Favor verificar.'
                   WHERE nro_lote = p_lote;
               
                  pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Error al conciliar: ' || p_lote || '. Favor verificar.');
            END;
         END IF;
      
         IF NOT v_error THEN
            BEGIN
               --suma de los créditos en los movimientos
               SELECT SUM(D.IMPORTE)
                 INTO v_mto_movimientos
               FROM ge_pag_sue_ips c, ge_pag_sue_ips_det d, ge_movimientos m
               WHERE c.nro_lote = p_lote --lote
                  AND d.nro_lote = c.nro_lote 	
                  AND m.fecha >= trunc(d.fec_acreditacion) and m.fecha <= trunc(sysdate) --fechas movimientos
                  AND m.nro_documento3 = C.cod_ente
                  AND m.nro_documento2 = d.nro_orden
                  AND m.nro_cuenta = d.nro_cta_jubilado --si en mov. , no en ips
                  AND m.COD_TRANSACCION = 602 --
                  AND m.COD_TRA_PADRE = 303;
               
            
               --insercion en bitacora del v_mto_movimientos
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Sumarización de los créditos en los movimientos: ' || p_lote || '. Total:.' || nvl(v_mto_movimientos, 0));
            
               --suma de los créditos en las cuentas de los jubilados CC
               SELECT SUM(D.IMPORTE)
                 INTO v_cc_montos
               FROM ge_pag_sue_ips c, ge_pag_sue_ips_det d, cc_movimientos_his cc
               WHERE c.nro_lote = p_lote --lote
                  AND d.nro_lote = c.nro_lote 	
                  AND cc.fecha >= trunc(d.fec_acreditacion) and cc.fecha <= trunc(sysdate) --fechas movimientos
                  AND cc.nro_documento3 = C.cod_ente
                  AND cc.nro_documento2 = d.nro_orden
                  AND cc.nro_cuenta = d.nro_cta_jubilado --si en mov. , no en ips
                  AND cc.COD_TRANSACCION = 602 --
                  AND cc.COD_TRA_PADRE = 303;
                           
               -- inserción en bitacora de v_cc_montos
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Sumarización de los créditos en las cuentas de los jubilados CC: ' || p_lote || '. Total:.' || nvl(v_cc_montos, 0));
            
               --suma de los créditos en las cuentas de los jubilados AH
               SELECT SUM(D.IMPORTE)
   				INTO v_ah_montos
               FROM ge_pag_sue_ips c, ge_pag_sue_ips_det d, ah_movimientos_his ah
               WHERE c.nro_lote = 121 --lote
                  AND d.nro_lote = c.nro_lote 	
                  AND ah.fecha >= trunc(d.fec_acreditacion) and ah.fecha <= trunc(sysdate) --fechas movimientos
                  AND ah.nro_documento3 = C.cod_ente
                  AND ah.nro_documento2 = d.nro_orden
                  AND ah.nro_cuenta = d.nro_cta_jubilado --si en mov. , no en ips
                  AND ah.COD_TRANSACCION = 602 --
                  AND ah.COD_TRA_PADRE = 303;
            
               --inserción en bitacora de v_ah_montos
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Sumarización de los créditos en las cuentas de los jubilados AH: ' || p_lote || '. Total:.' || nvl(v_ah_montos, 0));
            
               --sumarizamos los movimientos totales
               v_mto_movimientos := nvl(v_mto_movimientos, 0) + nvl(v_cc_montos, 0) + nvl(v_ah_montos, 0);
            
               -- inserción en bitacora de v_mto_movimientos
               pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Sumarización de los movimientos totales: ' || p_lote || '. Total:.' || nvl(v_mto_movimientos, 0));
            
               IF v_mto_movimientos != v_mto_debitado THEN
                  v_error := TRUE;
               
                  --actualizamos el lote de pago
                  UPDATE ge_pag_sue_ips
                     SET ESTADO      = 'E',
                         COMENTARIOS = 'No coinciden los montos en ge_pag_sue_ips_det y ge_pag_sueldos (débitos y créditos). Favor verificar.'
                   WHERE nro_lote = p_lote;
               
                  pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: No coinciden los montos en ge_pag_sue_ips_det y ge_pag_sueldos (débitos y créditos). Favor verificar.');
               END IF;
            
               IF NOT v_error THEN
                  IF v_mto_reg_archivo > v_mto_movimientos THEN
                     --se calcula la diferencia
                     v_monto_diferencia := v_mto_reg_archivo - v_mto_movimientos;
                  
                     --actualizamos el lote
                     UPDATE ge_pag_sue_ips c
                        SET c.estado          = 'C', --conciliado
                            c.fec_concilacion = SYSDATE,
                            c.comentarios     = 'Monto conciliado: Gs.' || v_mto_movimientos || '. Diferencia: Gs.' || v_monto_diferencia || '.'
                      WHERE c.nro_lote = p_lote;
                  
                     pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Monto conciliado: Gs.' || v_mto_movimientos || '. Diferencia: Gs.' || v_monto_diferencia || '.');
                  ELSIF v_mto_reg_archivo = v_mto_movimientos THEN
                     --actualizamos el lote
                     UPDATE ge_pag_sue_ips c
                        SET c.estado          = 'C', --conciliado
                            c.fec_concilacion = SYSDATE,
                            c.comentarios     = 'Monto conciliado: Gs.' || v_mto_movimientos || '.'
                      WHERE c.nro_lote = p_lote;
                  
                     pr_ins_bitacora(p_lote, NULL, 'Monto conciliado: Gs.' || v_mto_movimientos || '.');
                  
                  ELSE
                     --actualizamos el lote de pago
                     UPDATE ge_pag_sue_ips
                        SET ESTADO      = 'E',
                            COMENTARIOS = 'Hubo un problema al conciliar el Lote: ' || p_lote || '. Archivo: ' || v_nom_archivo
                      WHERE nro_lote = p_lote;
                  
                     pr_ins_bitacora(p_lote, NULL, 'Hubo un problema al conciliar el Lote: ' || p_lote || '. Archivo: ' || v_nom_archivo);
                  END IF;
               END IF;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Error al conciliar el lote: ' || p_lote || '. Favor verificar.');
               WHEN OTHERS THEN
                  --actualizamos el lote
                  UPDATE ge_pag_sue_ips
                     SET ESTADO      = 'E',
                         COMENTARIOS = 'Error al conciliar el lote: ' || p_lote || '. Favor verificar.'
                   WHERE nro_lote = p_lote;
               
                  pr_ins_bitacora(p_lote, NULL, 'pr_conciliarPagos: Error al conciliar el lote: ' || p_lote || '. Favor verificar.');
            END;
         END IF;
      END;
   END PR_PRO_CONCILIACION;
   
   /*
   BSEVOCORE-426 NAF 03/2020
   Verifica Rango de Horarios para procesamiento en parametro dinamico IPS_ACR_HORARIOS.
   Reemplaza control realizado en IpsAcredScheduler
   */
   FUNCTION LF_VER_PAR_HORARIOS( p_tipo varchar default 'P') return varchar2 is
      v_horarios       Ge_Par_Dinamicos.Val_Parametro%type;
      v_respuesta      varchar2(1);
   BEGIN
     If p_tipo = 'P' then
        v_horarios := nvl(fug_obt_pardinamico('IPS_ACR_HORARIOS'),'06:00-06:30,9:30-11:00,14:00-18:00');
     Else 
        v_horarios := nvl(fug_obt_pardinamico('IPS_REP_HORARIOS'),'07:00-18:30');
     End If;
     Begin
       select 'S' 
       into v_respuesta
       from ( select to_number(to_char(sysdate,'HH24MI')) ahora,
             rango,
             to_number(replace(substr(rango,1,INSTR(rango,'-')-1),':')) inicio,
             to_number(replace(substr(rango,INSTR(rango,'-')+1),':')) fin
             from ( select rownum id_rango, regexp_substr(v_horarios,'[^,]+', 1, level) rango 
             from dual
             connect by regexp_substr(v_horarios, '[^,]+', 1, level) is not null) )
       where ahora between inicio and fin;
     Exception
        when NO_DATA_FOUND then
             v_respuesta := 'N';
        when others then
             v_respuesta := 'S';
     End;
     return v_respuesta;
   END;
   /*
   BSEVOCORE-426 NAF 03/2020
   Template para Notificaciones
   Devuelve Texto con formato Html
   */
   FUNCTION LF_TEM_NOTIFICACION( p_titulo varchar2,
                                 p_sub_titulo varchar2 default null,
                                 p_aviso varchar2 default null,
                                 p_texto long default null,
                                 p_error long default null, --pre titulo
                                 p_email_links varchar2 default fug_obt_dir_correo
                                 ) return long is
   v_html          Long;
   BEGIN
       v_html := fug_gen_template('M')|| chr(10) ||
                 -- inicio div
                 paw_pro.fu_not_inicio;
       -- mensaje de error          
       if p_error is not null then
          v_html := v_html || p_error || chr(10);
       end if;
       -- titulo
       v_html := v_html || paw_pro.fu_not_titulo(p_titulo)|| chr(10);
       -- sub titulo
       v_html := v_html || paw_pro.fu_not_sub_titulo(p_sub_titulo)|| chr(10);
       -- aviso, en rojo
       if p_aviso is not null then
          v_html := v_html || paw_pro.fu_not_titulo_err(p_aviso)|| chr(10);
       end if;
       -- texto principal del mensaje
       if p_texto is not null then
          v_html := v_html || p_texto|| chr(10);
       end if;   
       v_html := v_html || paw_pro.fu_not_fin|| chr(10);
       v_html := v_html || chr(10)||fug_gen_template('F')|| chr(10) ||
                           chr(10) ||fug_gen_template('P', p_email_links);
       return v_html;
   END;  
    
   /*
   BSEVOCORE-426 NAF 03/2020
   Procedimiento que envia notificacion de acreditaciones realizadas por lote.
   Reemplaza al Notificaciones - notificarAcreditacionOk del WAR acreditadorips
   */
   PROCEDURE LP_ENV_NOTIFICACION( p_lote ge_pag_sue_ips.nro_lote%TYPE, 
                                  p_tipo varchar default null) IS
     v_nro_lote              GE_PAG_SUE_IPS.NRO_LOTE%type;
     v_nom_archivo           GE_PAG_SUE_IPS.NOM_ARCHIVO%type;
     v_mon_tot_acreditado    GE_PAG_SUE_IPS.MTO_ACREDITADO%type;
     v_fec_insercion         varchar2(50);
     v_fec_acreditacion      varchar2(50);
     v_fec_vencimiento       varchar2(50);     
     v_can_registros         number;
     v_can_acreditados       number;
     v_can_errores           number;
     v_can_pen_fedevida      number;
     
     v_titulo                VARCHAR2(200)  := NULL;
     v_detalle               VARCHAR2(3300) := NULL;
     v_aviso                 varchar2(700);
     v_cuerpo                LONG;     
     v_sal_linea             varchar2(5);
     v_conexion              utl_smtp.connection;
     v_nom_adjunto           varchar2(150);
     v_asunto                varchar2(300);
     v_det_error             varchar2(400);
     v_tip_error             varchar2(1); --G/General, A/Attach, M/eMail
     cursor c_detalle is
     select d.NRO_COMPROBANTE, d.NRO_CTA_JUBILADO, d.NRO_DOC_JUBILADO, 
            d.NOM_JUBILADO, d.COMENTARIOS
     from GE_PAG_SUE_IPS_DET d
     where d.NRO_LOTE = p_lote
           and (d.estado = 'E' or d.nro_com_duplicado = 'S');
              
     procedure Lp_Obt_Dat_Acr_Lote(p_lote ge_pag_sue_ips.nro_lote%TYPE) is
       BEGIN
         -- Cabecera
         select c.NRO_LOTE, c.NOM_ARCHIVO, c.MTO_ACREDITADO,
                to_char(c.FEC_INSERCION, 'DD/MM/YYYY HH24:MI:SS'),
                to_char(c.FEC_ACREDITACION, 'DD/MM/YYYY'),
                to_char(c.FEC_VENCIMIENTO, 'DD/MM/YYYY')
         into v_nro_lote, v_nom_archivo, v_mon_tot_acreditado,
              v_fec_insercion, v_fec_acreditacion, v_fec_vencimiento
         from GE_PAG_SUE_IPS c
         where c.NRO_LOTE = p_lote;
         
         -- Detalle
         -- cantidad de registros
         select count(1)
         into v_can_registros
         from GE_PAG_SUE_IPS_DET d
         where d.NRO_LOTE = p_lote;
         -- cantidad de acreditados
         select count(1)
         into v_can_acreditados
         from GE_PAG_SUE_IPS_DET d
         where d.NRO_LOTE = p_lote
         and d.estado = 'A';
         -- cantidad de errores
         select count(1)
         into v_can_errores
         from GE_PAG_SUE_IPS_DET d
         where d.NRO_LOTE = p_lote
         and d.estado = 'E';
         -- pendientes de Fe de Vida
         select count(1)
         into v_can_pen_fedevida
         from GE_PAG_SUE_IPS_DET d
         where d.NRO_LOTE = p_lote
         and d.fe_vida = 'N';
       END;
   BEGIN
     v_tip_error       := 'G';
     v_det_error       := '';
     v_sal_linea       := chr(13) || chr(10);
     
     if p_tipo = 'R' then -- Reproceso desde proceso independiente
        v_dir_para := v_dir_para ||','|| v_dir_err; -- Se concatena email de EP para verificar correcto reenvio
     end if;
     
     -- Obtener datos del procesamiento
     Lp_Obt_Dat_Acr_Lote(p_lote);
     v_titulo := 'Resumen de la Acreditación del lote: ' || v_nom_archivo;
     v_asunto := '[IPS] ' || v_titulo;

     -- Aviso en caso de error
     if nvl(v_can_errores,0) > 0 then
        v_aviso := paw_pro.fu_not_titulo_err('Hay registros con error, los mismos no fueron acreditados. Por favor, revise el archivo adjunto para m&aacute;s informaci&oacute;n.');
     end if;

     -- detalles
     v_detalle := '';
     v_detalle := replace(paw_pro.fu_not_ini_tabla,'width="500"; ','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Cantidad de registros', v_can_registros),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Cantidad de registros acreditados', v_can_acreditados),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Cantidad de registros con error', v_can_errores),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Cantidad de registros no acreditados por Fe de Vida no vigente', v_can_pen_fedevida),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Monto total acreditado', v_mon_tot_acreditado),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Fecha de Validaci&oacute;n', v_fec_insercion),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Fecha de Acreditaci&oacute;n seg&uacute;n archivo', v_fec_acreditacion),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Fecha de Acreditaci&oacute;n', to_char(sysdate, 'dd-MM-yyyy HH24:mi:ss')),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Fecha de Vencimiento', v_fec_vencimiento),'width="150";','');
     v_detalle := v_detalle || replace(paw_pro.fu_not_row_tag('Ref. Nro. de Lote', v_nro_lote),'width="150";','');
     v_detalle := v_detalle || paw_pro.fu_not_fin_tabla;
     
     v_cuerpo :=  LF_TEM_NOTIFICACION( replace(v_titulo,'ó','&oacute;'),
                                       null,
                                       v_aviso,
                                       v_detalle);
                          
     -- Si hay errores ESTADO = E or NRO_COM_DUPLICADO = S crear adjunto
     if v_can_errores > 0 then
       begin
           -- Envia Email Notificacion con Adjunto
           v_nom_adjunto := 'errores-acreditacion_' || v_nom_archivo || '.txt';
           v_conexion := it_mail.begin_mail(v_dir_de, v_dir_para, v_asunto, IT_MAIL.MULTIPART_MIME_TYPE);
           it_mail.attach_text(v_conexion, v_cuerpo, 'text/html');
           it_mail.begin_attachment(v_conexion, 'text/plain', false, v_nom_adjunto, 'US-ASCII');
           it_mail.write_text(v_conexion, 'Fecha de Acreditación: ' || to_char(sysdate,'DD-MM-YYYY') || v_sal_linea ||
                                          'REGISTROS CON ERROR' || v_sal_linea || 
                                          rpad('Nro'||/*chr(176)||*/' Comprob.',16,' ') ||rpad('Nro. Cuenta',16,' ')||rpad('Documento',18,' ')|| rpad('Nombre',39,' ') || '	' ||'Comentario' ||
                                          v_sal_linea);
           FOR arc IN c_detalle LOOP
                  it_mail.write_text(v_conexion, rpad(arc.nro_comprobante,16,' ') ||
                                                 rpad(arc.nro_cta_jubilado,16,' ')|| 
                                                 rpad(arc.nro_doc_jubilado,18,' ')|| 
                                                 rpad(arc.nom_jubilado,39,' ') || '	' ||
                                                 arc.comentarios || v_sal_linea);
           END LOOP;
           UTL_SMTP.WRITE_DATA(v_conexion, UTL_TCP.CRLF);
           it_mail.end_mail(v_conexion);       
       exception
         when utl_smtp.transient_error or utl_smtp.permanent_error then
              v_det_error := substr(sqlerrm,1,400);
              v_tip_error := 'A';
              begin
                 utl_smtp.quit(v_conexion);
              exception
                 when others then
                      null;
              end;
              raise_application_error(-20000,'Error Attach.');
         WHEN OTHERS THEN
              v_det_error := substr(sqlerrm,1,400);
              v_tip_error := 'A';
              begin
                 utl_smtp.quit(v_conexion);
              exception
                 when others then
                      null;
              end;
              raise_application_error(-20000,'Error Attach.');
       end;
     else
       begin
         -- Envia Email Notificacion sin Adjunto
         v_conexion := it_mail.begin_mail(v_dir_de, v_dir_para, v_asunto, IT_MAIL.MULTIPART_MIME_TYPE);
         it_mail.attach_text(v_conexion, v_cuerpo, 'text/html');
         it_mail.end_mail(v_conexion);

       exception
         when utl_smtp.transient_error or utl_smtp.permanent_error then
              v_det_error := substr(sqlerrm,1,400);
              v_tip_error := 'M';
              begin
                 utl_smtp.quit(v_conexion);
              exception
                 when others then
                      null;
              end;
              raise_application_error(-20000,'Error Notificacion.');
         when others then
              v_det_error := substr(sqlerrm,1,400);
              v_tip_error := 'M';
              begin
                 utl_smtp.quit(v_conexion);
              exception
                 when others then
                      null;
              end;
              raise_application_error(-20000,'Error Notificacion.');
       end;
     end if;
   EXCEPTION
     WHEN OTHERS THEN
       v_det_error := v_det_error || substr(sqlerrm,1,400);
       IF v_tip_error = 'M' Then
          -- Error al Generar Email sin Adjunto
          -- Inserta Notificacion al Cliente
          prg_ins_notificacion(sysdate,v_dir_de,v_dir_para,
                     v_asunto,v_cuerpo,'PAG_IPS','NOTPROIPS');
          
          v_cuerpo :=  LF_TEM_NOTIFICACION( replace(v_titulo,'ó','&oacute;'),
                                            null,
                                            v_aviso,
                                            v_detalle,
                                            '<div style="padding:20px 20px">'||paw_pro.fu_not_titulo_err('Se registra para envio en GE_NOTIFICACIONES. No hay necesidad de generar adjunto.')||'</div>' ||
                                            '<div style="padding:20px 20px">'|| paw_pro.fu_not_titulo_err(v_det_error) ||'</div>'
                                            );
          -- Inserta Notificacion EP
          prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
                               'ERROR EMAIL ' || v_asunto,
                               v_cuerpo,
                               'PAG_IPS','NOTPROIPS');
       Elsif v_tip_error = 'A' Then
          -- Error al Generar Email con Adjunto
          -- Sobreescribe mensaje del aviso
          v_cuerpo := replace(v_cuerpo,'Por favor, revise el archivo adjunto para m&aacute;s informaci&oacute;n.',
                     'El archivo adjunto ser&aacute; enviado en breve.');
          -- Inserta Notificacion al Cliente
          prg_ins_notificacion(sysdate,v_dir_de,v_dir_para,
                     v_asunto,v_cuerpo,'PAG_IPS','NOTPROIPS');

          v_cuerpo :=  LF_TEM_NOTIFICACION( replace(v_titulo,'ó','&oacute;'),
                                  null,
                                  v_aviso,
                                  v_detalle,
                                  '<div style="padding:20px 20px">'||paw_pro.fu_not_titulo_err('Se registra para envio en GE_NOTIFICACIONES. Queda Pendiente Envio de Adjunto!')||'</div>' ||
                                  '<div style="padding:20px 20px">'|| paw_pro.fu_not_titulo_err(v_det_error) ||'</div>' ||
                                  '<div style="padding:20px 20px">Enviar el resultado de la consulta a los sigtes destinos:'|| '<BR>' ||
                                  v_dir_para || '<BR><BR>' ||
                                  'Con el sigte nombre de archivo: <b>' ||v_nom_adjunto ||'</b><BR><BR>' ||
                                  'select d.NRO_COMPROBANTE Nro_Comprobante,'||'<BR>'||
                                  '      d.NRO_CTA_JUBILADO Nro_Cuenta, d.NRO_DOC_JUBILADO Documento,'||'<BR>'||
                                  '      d.NOM_JUBILADO Nombre, d.COMENTARIOS Comentario'||'<BR>'||
                                  'from GE_PAG_SUE_IPS_DET d'||'<BR>'||
                                  'where d.NRO_LOTE = '||p_lote||'<BR>'||
                                  '     and (d.estado = ''E'' or d.nro_com_duplicado = ''S'');'||'<div>');
          -- Inserta Notificacion EP
          prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
                      'ERROR EMAIL, PENDIENTE DE ENVIO ADJUNTO ' ||v_asunto,
                      v_cuerpo,
                      'PAG_IPS','NOTPROIPS');
       Else
          -- Error General
          v_cuerpo :=  LF_TEM_NOTIFICACION( '<br>Nro Lote '||p_lote||' - Archivo '|| nvl(v_nom_archivo,'No Existente'),
                                  null,
                                  null,
                                  null,
                                  '<div style="padding:20px 20px">'||paw_pro.fu_not_titulo_err('No se realizo el env&iacute;o de la notificaci&oacute;n! Acreditaci&oacute;n Nro. Lote: '||p_lote)||'</div>' ||
                                  '<div style="padding:20px 20px">'|| paw_pro.fu_not_titulo_err(v_det_error) ||'</div>' ||
                                  '<div style="padding:20px 20px">Solucionado el problema, puede reprocesar el envio ejecutando el proceso independiente 39 [IPS] - REENVIO NOTIFICACION ACRED.'|| '<BR>' ||
                                  'El parametro dinamico IPS_NOT_LOT_REENVIO (ge_par_dinamicos) debe contener el nro de lote <b>'||p_lote||'</b>, favor actualizar para reprocesar.<div>');
          -- Inserta Notificacion EP
          prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
               'ERROR AL NOTIFICAR ACREDITACION ' || v_asunto,
               v_cuerpo,
               'PAG_IPS','NOTPROIPS');
       End if;
   END LP_ENV_NOTIFICACION;
   
   /*
   BSEVOCORE-426 NAF 03/2020
   Procedimiento que envia notificacion de acreditaciones.
   El numero de lote se indica en el parametro dinamico [IPS_NOT_LOT_REENVIO].
   */
   PROCEDURE PR_ENV_NOT_PARAMETRO IS
   BEGIN
      LP_ENV_NOTIFICACION(nvl(fug_obt_pardinamico('IPS_NOT_LOT_REENVIO'),0),'R');
   END;
   
   /*
   * BSEVOCORE-461 NAF 06/2020
   * Verifica Inicio de dia de ITGF
   */
   FUNCTION LF_VER_INICIO return varchar2 IS
   v_fec_actual      ge_calendarios.fec_actual%type;
   v_fec_control     ge_calendarios.fec_actual%type;
   v_iniciado        varchar2(1) := 'N';
   v_error           varchar2(500);
   BEGIN
       IF fug_obt_pardinamico('IPS_HAB_CON_INI') = 'S' THEN
           select fec_actual
           into v_fec_actual 
           from ge_calendarios
           where cod_modulo = 1;
           
           v_fec_control := to_date(nvl( fug_obt_pardinamico('IPS_ULT_FEC_INI'), to_char(trunc(sysdate)-1,'dd/mm/yyyy')) ,'dd/mm/yyyy');
           
           if v_fec_control = v_fec_actual and v_fec_control >= trunc(sysdate) then
              v_iniciado := 'S';
           end if;
       ELSE
           v_iniciado := 'S';
       END IF;
       return v_iniciado;
   EXCEPTION
      when others then
       v_error := substr(SQLERRM,1,500);
       --registra el error
       pr_ins_bitacora(NULL, NULL, 'LF_VER_INICIO: Error - ' || v_error);
       -- Inserta Notificacion EP
       prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
           '[IPS] ERROR AL VERIFICAR INICIO DE ITGF - PAG_IPS.LF_VER_INICIO',
           v_error,
           'PAG_IPS','NOTPROIPS');
       return v_iniciado;
   END LF_VER_INICIO;
   
   /*
   BSEVOCORE-426 NAF 03/2020
   Procedimiento que recupera las acreditaciones pendientes para el dia y
   llama al proceso de acreditacion por lotes.
   Reemplaza al IpsAcredScheduler y ProcessAcreditaciones - acreditarMasivo del WAR acreditadorips
   */
   PROCEDURE PR_PRO_ACR_PENDIENTES IS
     v_nro_lote      GE_PAG_SUE_IPS.NRO_LOTE%TYPE;
     v_estado        GE_PAG_SUE_IPS.ESTADO%type;
     v_comentarios   GE_PAG_SUE_IPS.COMENTARIOS%type;
     v_nom_archivo   GE_PAG_SUE_IPS.NOM_ARCHIVO%type;
     v_titulo        VARCHAR2(200)  := NULL;
     v_mensaje       LONG  := NULL;
     v_asunto        VARCHAR2(200)  := NULL;
     v_conexion      utl_smtp.connection;
     v_error         varchar2(500);
     v_hab_sublotes  GE_PAR_DINAMICOS.VAL_PARAMETRO%type;
     v_nro_sublote   GE_PAG_SUE_IPS_SUBLOTES.NRO_SUBLOTE%TYPE;
     v_max_sublote   GE_PAG_SUE_IPS_SUBLOTES.NRO_SUBLOTE%TYPE;
     
     cursor c_lotes is
       select c.NRO_LOTE
       from GE_PAG_SUE_IPS c 
       where c.TIP_PROCESO = 'P' 
             and (c.ESTADO = 'V' or c.fec_acr_efectiva is null)-- lotes en estado V verificado o Fecha Acreditacion nula
             and trunc(c.FEC_VENCIMIENTO) >= trunc(sysdate)
             and trunc(c.FEC_ACREDITACION) <= trunc(sysdate) 
       order by c.FEC_ACREDITACION asc;
     
     -- Recupera estado del lote
     Procedure LP_VER_DET_LOTE(p_lote ge_pag_sue_ips.nro_lote%TYPE) is
     begin  
       select c.estado, c.comentarios, c.nom_archivo
       into   v_estado, v_comentarios, v_nom_archivo
       from GE_PAG_SUE_IPS c 
       where c.NRO_LOTE = p_lote;
     end;
     
     -- Actualiza Fecha de Acreditacion del Lote
     Procedure LP_ACT_FEC_ACR_LOTE(p_lote ge_pag_sue_ips.nro_lote%TYPE) is
       PRAGMA AUTONOMOUS_TRANSACTION;
     begin  
       update GE_PAG_SUE_IPS c set c.fec_acr_efectiva = sysdate where c.NRO_LOTE = p_lote;
       commit;
       
       pr_ins_bitacora(v_nro_lote, NULL, 'PR_PRO_ACR_PENDIENTES: Finaliza Acreditacion Lote ' || v_nro_lote || ' '|| to_char(sysdate,'dd/mm/yyyy HH24:mi:ss') );
     end;
     
   BEGIN
     IF LF_VER_PAR_HORARIOS('P') = 'S' and LF_VER_INICIO = 'S' THEN -- BSEVOCORE-461 Verifica Inicio de Dia ITGF
       -- BSEVOCORE-451 NAF 05/2020 Implementa Acreditacion por sublotes
       v_hab_sublotes := nvl(fug_obt_pardinamico('IPS_HAB_SUBLOTES'),'N');
       
       IF c_lotes%ISOPEN THEN
         CLOSE c_lotes;
       END IF;
       OPEN c_lotes;
       LOOP
         FETCH c_lotes
           INTO v_nro_lote;
         EXIT WHEN c_lotes%NOTFOUND;
         
         BEGIN
           IF v_hab_sublotes = 'S' THEN
              -- Procesa por sublotes
              -- Mantenimiento de tabla de sublotes
              LP_MAN_SUBLOTES(v_nro_lote);
              -- Genera sublotes
              LP_GEN_SUBLOTES(v_nro_lote);
              LP_OBT_DAT_SUBLOTE(v_nro_lote, v_nro_sublote, v_max_sublote);
              -- Recorre los sublotes y Acredita
              WHILE nvl(v_nro_sublote,0) > 0
                LOOP
                   pr_ins_bitacora(v_nro_lote, NULL, 'PR_PRO_ACR_PENDIENTES: Inicia Acreditacion Lote ' || v_nro_lote || ' sublote ' || v_nro_sublote || '/' || v_max_sublote);
                   PR_PRO_ACR_SUBLOTE(v_nro_lote, v_nro_sublote);
                   -- se realiza comit para liberar las cuentas ya acreditadas
                   commit;
                   v_nro_sublote := v_nro_sublote + 1;
                   IF v_nro_sublote > v_max_sublote then
                      v_nro_sublote := 0;
                      EXIT;
                   END IF;
                END LOOP;
           ELSE
              pr_ins_bitacora(v_nro_lote, NULL, 'PR_PRO_ACR_PENDIENTES: Inicia Acreditacion Lote ' || v_nro_lote );
              -- Procesa el lote completo
              PR_PRO_ACREDITACION(v_nro_lote);
           END IF;
           
           LP_VER_DET_LOTE(v_nro_lote);
           IF v_estado = 'P' THEN
              -- Actualiza fecha de acreditacion 
              LP_ACT_FEC_ACR_LOTE(v_nro_lote);
              -- Procesa la notificacion
              LP_ENV_NOTIFICACION(v_nro_lote);
           ELSE
              --envia aviso de error
              v_titulo := 'Ocurrió un error en el proceso de acreditación del archivo: ' || v_nom_archivo;
              v_asunto := '[IPS] ' || v_titulo;
              v_mensaje := LF_TEM_NOTIFICACION( paw_pro.fu_not_sub_titulo(replace(v_titulo,'ó','&oacute;')),
                               null,
                               paw_pro.fu_not_titulo_err(v_comentarios));
              -- Envia Email Aviso de Error
              -- Al Cliente
              v_conexion := it_mail.begin_mail(v_dir_de, v_dir_para, v_asunto, IT_MAIL.MULTIPART_MIME_TYPE);
              it_mail.attach_text(v_conexion, v_mensaje, 'text/html');
              it_mail.end_mail(v_conexion);
              
              -- Inserta Notificacion EP
              prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
               v_asunto || ' Lote ' || v_nro_lote,
               v_comentarios,
               'PAG_IPS','NOTPROIPS');
           END IF;
           
         EXCEPTION 
           WHEN OTHERS THEN
             v_error := substr(SQLERRM,1,500);
             --registra el error
             pr_ins_bitacora(v_nro_lote, NULL, 'PR_PRO_ACR_PENDIENTES: Error - ' || v_error);
             -- Inserta Notificacion EP
             prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
                 '[IPS] ERROR AL ACREDITAR LOTE ' || v_nro_lote,
                 v_error || ' ' ||v_comentarios,
                 'PAG_IPS','NOTPROIPS');
         END;
       END LOOP;
     ELSE
       -- registra el intento en log
       pr_ins_bitacora(NULL, NULL, 'PR_PRO_ACR_PENDIENTES:' || to_char(sysdate,'HH24:mi:ss')||' Horario no habilitado. Permitido: '||fug_obt_pardinamico('IPS_ACR_HORARIOS')||
                       ' o ITGF aun no inicia en fecha ' || to_char(sysdate,'dd/mm/yyyy'));
     END IF;
   END PR_PRO_ACR_PENDIENTES;
   
   /*
   BSEVOCORE-426 NAF 03/2020
   Procedimiento de reproceso de acreditaciones pendientes para el dia.
   Remplaza la llamada de Acreditaciones en AcredFeDeVidaPend, acredita a
   personas que tienen cambios de fe de Vida, via WS.
   Se ejecuta cada 5 minutos
   */
   PROCEDURE PR_REP_ACR_PENDIENTES IS
     v_nro_lote            GE_PAG_SUE_IPS.NRO_LOTE%TYPE;
     v_titulo              VARCHAR2(200)  := NULL;
     v_mensaje             LONG;
     v_asunto              VARCHAR2(200)  := NULL;
     v_conexion            utl_smtp.connection;
     v_con_error           number;
     v_men_error           varchar2(4000);
     v_linea               varchar2(1000);
     v_mas_lineas          varchar2(1);
     v_error               varchar2(500);
     -- Solo recupera registros con actualizacion de fe de vida
     cursor c_lotes is
       select distinct c.nro_lote
       from GE_PAG_SUE_IPS c 
            join GE_PAG_SUE_IPS_DET d on c.nro_lote=d.nro_lote
                 and d.fe_vida = 'S' and d.estado = 'P'
       where c.ESTADO IN ('P')  -- solo lotes en estado P ya Procesados masivamente 
             and c.tip_proceso = 'P'
             and trunc(c.FEC_VENCIMIENTO) >= trunc(sysdate)
             and trunc(c.FEC_ACREDITACION) <= trunc(sysdate)
             and c.fec_acr_efectiva is not null -- BSEVOCORE-451 NAF 05/2020 solo si ya finalizo acreditacion masiva del lote
       order by c.NRO_LOTE asc;
     -- cursor de control de registros con cambio de fe de vida
     cursor c_control is
       select a.*, b.estado est_control
       from GE_PAG_SUE_IPS_DET a 
            join GE_PAG_SUE_IPS_REP_TMP b on a.nro_lote = b.nro_lote
                 and a.nro_orden = b.nro_orden and b.estado NOT IN ('I')
       where a.nro_lote = v_nro_lote;
   BEGIN
     IF LF_VER_PAR_HORARIOS('R') = 'S' and LF_VER_INICIO = 'S' THEN -- BSEVOCORE-461 Verifica Inicio de Dia ITGF
       IF c_lotes%ISOPEN THEN
         CLOSE c_lotes;
       END IF;
       OPEN c_lotes;
       LOOP
         FETCH c_lotes
           INTO v_nro_lote;
         EXIT WHEN c_lotes%NOTFOUND;
         
         BEGIN
           -- Procesa la acreditacion
           PR_PRO_ACREDITACION(v_nro_lote,'R');
           
           -- Control de proceso
           v_con_error := 0;
           v_men_error := '';
           v_mas_lineas := 'N';
           FOR reg IN c_control
           LOOP
               -- Los registros con estado Acreditado se eliminan
               IF reg.estado = 'A' then
                   delete from GE_PAG_SUE_IPS_REP_TMP c
                   where c.nro_lote=reg.nro_lote and c.nro_orden=reg.nro_orden;
               Else
                 -- se omiten los est_control =  R que ya fueron reportados
                 If reg.est_control != 'E' then
                   -- se registran con estado E los que estan aun pendientes
                   LP_ACT_TMP_REPROCESO(reg.nro_lote,reg.nro_orden,'E');
                   v_con_error := v_con_error + 1;
                   v_linea := '<p>Nro. Orden: ' || reg.nro_orden || ' ' ||
                                  'Nro.Doc: ' || reg.nro_doc_jubilado || ' ' ||
                                  'Importe: ' || reg.importe || ' </p>';
                   if length(nvl(v_men_error,' ')) < 3900 and length(nvl(v_men_error,' ')) + length(v_linea) < 3900 Then
                      v_men_error := v_men_error || v_linea;
                   else
                      v_mas_lineas := 'S';
                   end if;
                 End If;
               End if;
           END LOOP;
           IF v_mas_lineas = 'S' THEN
              v_men_error := v_men_error ||  paw_pro.fu_not_titulo_err('Existen mas registros con Error que los listados.</br>');
           END IF;
           --Lp_Ver_Det_Lote(v_nro_lote);
           IF v_con_error > 0 THEN
              --envia aviso de error         
              begin
                v_titulo := 'Existen Errores de Acreditacion en el Lote: ' || v_nro_lote;
                v_asunto := '[IPS] ' || v_titulo;
                v_mensaje := LF_TEM_NOTIFICACION( replace(v_titulo,'ó','&oacute;'),
                                 '<p>select a.*, b.estado est_control'||' </p>'||
                                 '<p>from GE_PAG_SUE_IPS_DET a'||' </p>'||
                                 '<p>    join GE_PAG_SUE_IPS_REP_TMP b on a.nro_lote = b.nro_lote'||' </p>'||
                                 '<p>         and a.nro_orden = b.nro_orden and b.estado NOT IN (''I'')'||' </p>'||
                                 '<p>where a.nro_lote = '||v_nro_lote||';',
                                 paw_pro.fu_not_titulo_err(v_con_error ||' Acreditaciones por Actualización Online de Fe de Vida.'),
                                 v_men_error
                                 );
                -- Envia Email Aviso de Error a EP
                v_conexion := it_mail.begin_mail(v_dir_de, v_dir_err, v_asunto, IT_MAIL.MULTIPART_MIME_TYPE);
                it_mail.attach_text(v_conexion, v_mensaje, 'text/html');
                it_mail.end_mail(v_conexion);
              exception
                 when utl_smtp.transient_error or utl_smtp.permanent_error then
                      prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
                             v_asunto,v_mensaje,'PAG_IPS','NOTPROIPS');
                      begin
                         utl_smtp.quit(v_conexion);
                      exception
                         when others then
                              null;
                      end;
                 when others then
                      prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
                             v_asunto,v_mensaje,'PAG_IPS','NOTPROIPS');
                      begin
                         utl_smtp.quit(v_conexion);
                      exception
                         when others then
                              null;
                      end;
              end;
           END IF;
         EXCEPTION 
           WHEN OTHERS THEN
             v_error := substr(SQLERRM,1,500);
             --registra el error
             pr_ins_bitacora(v_nro_lote, NULL, 'PR_REP_ACR_PENDIENTES: Error - ' || v_error);
             -- Inserta Notificacion EP
             prg_ins_notificacion(sysdate,v_dir_de,v_dir_err,
                 '[IPS] ERROR AL REPROCESAR ACRED. LOTE ' || v_nro_lote,
                 v_error,
                 'PAG_IPS','NOTPROIPS');
         END;
       END LOOP;
     ELSE
       -- registra el intento en log
       pr_ins_bitacora(NULL, NULL, 'PR_REP_ACR_PENDIENTES:' || to_char(sysdate,'HH24:mi:ss')||' Horario no habilitado. Permitido: '||fug_obt_pardinamico('IPS_REP_HORARIOS')||
                       ' o ITGF aun no inicia en fecha ' || to_char(sysdate,'dd/mm/yyyy'));
     END IF;
   END PR_REP_ACR_PENDIENTES;
   
   /**
   * BSEVOCORE-461 NAF 03/2020
   * Proceso Principal llamado desde en el war acreditador-ips-1.0.5
   */
   PROCEDURE PR_PRO_ACREDITACIONES IS 
   BEGIN
     -- Proceso de Acreditaciones por Actualizacion de Fe de Vida
     PR_REP_ACR_PENDIENTES;
     -- Proceso de Acreditaciones Masiva
     PR_PRO_ACR_PENDIENTES;
   END PR_PRO_ACREDITACIONES;
BEGIN
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja
   /* BSEVOCORE-426 NAF 03/2020*/
   v_dir_de       := fug_obt_dir_correo;
   v_dir_para     := fug_obt_pardinamico('IPS_EVT_NOT_MAILS');
   v_dir_err      := fug_obt_pardinamico('IPS_ERR_NOT_MAILS');
END PAG_IPS;
/

