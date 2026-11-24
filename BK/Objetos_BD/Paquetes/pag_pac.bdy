CREATE OR REPLACE PACKAGE BODY IT.PAG_PAC IS
   -- Variables globales
   G_ENT_PAG_BEPSA CONSTANT NUMBER := fug_obt_pardinamico('COD_ENT_PAG_BEPSA'); 
   G_TIP_ENT_PAG   CONSTANT ge_entes.tipo%TYPE := 'EP';
   G_API_KEY_PAC   CONSTANT ge_par_entes.parametro%TYPE := 'API_KEY_PAC';
   G_COD_BCO       CONSTANT ge_bancos.cod_banco%TYPE := nvl(fug_obt_cod_banco, 7);
   G_MON_GS        CONSTANT ba_monedas.cod_moneda%TYPE := nvl(pag_gen.fu_obt_mon_local, 'GS');
   G_MON_USD       CONSTANT ba_monedas.cod_moneda%TYPE := nvl(pag_gen.fu_obt_mon_fuerte, 'USD');
   G_MOD_BCO_PAIS  CONSTANT ge_modalidades.cod_modalidad%TYPE := 42;
   G_CAN_MAX_INT   CONSTANT NUMBER := NVL(fug_obt_pardinamico('CAN_MAX_INT_PAC'), 3);
   G_COD_MOD_PADRE CONSTANT ba_modulos.cod_modulo%TYPE := 9;
   G_COD_MAD_PADRE CONSTANT ge_modalidades.cod_modalidad%TYPE := 91;
   G_COD_TRA_DEB   CONSTANT ge_transacciones.cod_transaccion%TYPE := 503;
   G_COD_TRA_CRE   CONSTANT ge_transacciones.cod_transaccion%TYPE := 602;
   G_COD_USUARIO   ge_movimientos.cod_usuario%TYPE; -- Usuario por Ente
   -- Errores
   C_OPE_APR    CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_OPE_APROB'; -- Operacion Aprobada
   C_OPE_NO_APR CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_OPE_NO_APR'; -- Operacion NO Aprobada
   C_OPE_NO_AUT CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_OPE_NO_AUT'; -- Operacion NO Autorizada
   C_DAT_INV    CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_DAT_INVALID'; -- Parámetros inválidos
   -- Mensajes
   C_API_KEY_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_API_KEY_INV'; -- Api Key inválido
   C_IP_ORI_INV  CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_IP_ORI_INV'; -- IP Origen inválido
   C_EN_CIERRE   CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_EN_CIERRE'; -- Sistema en Cierre
   C_CTA_DEB_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_CTA_DEB_INV'; -- Cuenta Débito inválida
   C_CTA_CRE_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_CTA_CRE_INV'; -- Cuenta Crédito inválida
   C_TRA_INV     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_TRA_INVALID'; -- Transaccion inválida
   C_OPE_INV     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_OPE_INVALID'; -- Operación inválida
   C_PAG_DUP     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_PAG_DUPLICA'; -- Pago Duplicado
   C_PAG_INE     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_PAG_INE'; -- Boleta de Pago no Encontrado
   C_MON_INV     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_MON_INV'; -- Moneda inválida
   C_CRE_DEB_IGU CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_CRE_DEB_IGU'; -- Cuenta Crédito igual a la de Débito
   C_CRE_INE     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_CTA_CRE_INE'; -- Cuenta Crédito inexistente
   C_DEB_INE     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_CTA_DEB_INE'; -- Cuenta Débito inexistente
   C_CRE_PRO     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_CTA_CRE_PRO'; -- Operación prohibida en la Cuenta Crédito
   C_DEB_PRO     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_CTA_DEB_PRO'; -- Operación prohibida en la Cuenta Débito
   C_EST_CRE_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_EST_CRE_INV'; -- Estado de Cuenta Crédito inválida
   C_EST_DEB_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_EST_DEB_INV'; -- Estado de Cuenta Crédito inválida
   C_MTO_INV     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_MTO_INVALID'; -- Monto inválido
   C_BOL_INV     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_BOL_INV'; -- Boleta inválido.
   C_COM_INV     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_NOM_COM_INV'; -- Nombre de Comercio inválido.
   C_FEC_INV     CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_FEC_TRA_INV'; -- Fecha de Transación inválida.
   C_TIP_TAR_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_TIP_TAR_INV'; -- Tipo de Tarjeta inválida.
   C_BCO_DEB_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_BCO_DEB_INV'; -- Banco Débito inválido.
   C_BCO_CRE_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_BCO_CRE_INV'; -- Banco Crédito inválido.
   C_ERR_CON_ENT CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_ERR_CON_ENT'; -- Error en Configuración de Entidad.
   C_BOL_EXT_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_BOL_EXT_INV'; -- Boleta Extorno inválida.
   C_MON_EXT_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_MON_EXT_INV'; -- Moneda Extorno inválido.
   C_MTO_EXT_INV CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_MTO_EXT_INV'; -- Monto Extorno inválido.
   C_DEB_SAL_INS CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_DEB_SAL_INS'; -- Cuenta Débito con Saldo insufiente
   C_OTR_ERROR   CONSTANT bw_men_respuesta.nombre%TYPE := 'PAC_OTR_ERROR'; -- Error no especificado
   --
   C_TRA_PAD_PAG_TD CONSTANT ge_parametros.parametro%TYPE := 'COD_TRA_PAD_PAG_COM_TD';
   C_TRA_PAD_PAG_TC CONSTANT ge_parametros.parametro%TYPE := 'COD_TRA_PAD_PAG_COM_TC';
   C_TRA_PAD_DEB_TD CONSTANT ge_parametros.parametro%TYPE := 'COD_TRA_PAD_DEB_COM_TD';
   C_TRA_PAD_DEB_TC CONSTANT ge_parametros.parametro%TYPE := 'COD_TRA_PAD_DEB_COM_TC';
   C_SER_ACTIVO     CONSTANT ge_parametros.parametro%TYPE := 'IND_SER_ACTIVO';
   C_BCO_PAIS_GS    CONSTANT ge_parametros.parametro%TYPE := 'CTA_BCO_PAIS_OPE_GS';
   C_BCO_PAIS_USD   CONSTANT ge_parametros.parametro%TYPE := 'CTA_BCO_PAIS_OPE_USD';
   G_CTA_TRA_ENT_GS CONSTANT ge_parametros.parametro%TYPE := 'CTA_TRA_ENT_GS';
   C_CAN_DIA_EXT    CONSTANT ge_parametros.parametro%TYPE := 'CAN_MAX_DIA_REVERSION';
   C_OFI_ORIGEN     CONSTANT ba_oficinas.cod_oficina%TYPE := NVL(FUG_OBT_OFI_MATRIZ, 7);

   /* Funcion para verificación de horario */
   FUNCTION fu_ver_horario(p_horario OUT VARCHAR2, p_es_mov_noc OUT VARCHAR2, p_es_cta_noc OUT VARCHAR2, p_cod_ofi_origen OUT NUMBER,
                           p_fec_actual OUT DATE) RETURN typ_MensajeRespuesta IS
      v_est_modulo ba_modulos.estado%TYPE;
      v_retorno    typ_MensajeRespuesta := typ_MensajeRespuesta();
   BEGIN
      PAW_UTI.pr_mensajeUsuario(C_OPE_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      p_horario        := 'D'; -- Dia normal  
      p_es_mov_noc     := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc     := 'N';
      p_fec_actual     := pag_cal.FU_OBT_FEC_ACTUAL(3);
      v_est_modulo     := pae_cnf.FU_OBT_EST_MODULO(3);
      p_cod_ofi_origen := C_OFI_ORIGEN;
      IF v_est_modulo IN (1, 6) THEN
         --En cierre.
         PAW_UTI.pr_mensajeUsuario(C_EN_CIERRE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSIF v_est_modulo = 2 THEN
         NULL;
         -- Verifica la hora --
         /*IF SYSDATE > p_ult_cierre AND trunc(p_ult_cierre) = p_fec_actual THEN
            p_horario    := 'T'; -- Tarde
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
            p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         END IF;*/
      ELSE
         p_horario := 'N'; -- Noche
         IF v_est_modulo <> 1 THEN
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
         END IF;
         p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         p_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
      pag_cta.g_horario := p_horario;
      RETURN v_retorno;
   END fu_ver_horario;

   /* Devolver el numero de Cuenta del Banco */
   FUNCTION fu_obt_cta_banco(p_banco IN ge_bancos.cod_banco%TYPE, p_moneda IN ba_monedas.cod_moneda%TYPE) RETURN ge_cuentas.nro_cuenta%TYPE IS
      v_nro_cuenta ge_cuentas.nro_cuenta%TYPE;
   BEGIN
      SELECT a.nro_cuenta
        INTO v_nro_cuenta
        FROM cc_cta_bancarias a
       WHERE a.cod_modalidad = G_MOD_BCO_PAIS
         AND a.cod_banco = p_banco
         AND a.cod_moneda = p_moneda;
      RETURN v_nro_cuenta;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   /* Obtener el siguiente nro de referencia */
   FUNCTION fu_obt_sig_nro_referencia(p_fecha IN DATE DEFAULT NULL) RETURN NUMBER IS
      /* Se obtiene el siguiente nro. de referencia, como el campo NRO_DOCUMENTO es NUMBER(15)
         Se calcula 6 digitos para la fecha 'YYMMDD' y 6 digitos para la secuencia.
      */
      v_nro_referencia ge_acr_comercios.nro_referencia%TYPE;
      c_fecha CONSTANT DATE := nvl(p_fecha, SYSDATE);
   BEGIN
      SELECT to_number(to_char(c_fecha, 'YYMMDD') || to_char(s_nro_ref_acr_com.nextval))
        INTO v_nro_referencia
        FROM dual;
      -- retorno el sgte nro de referencia
      RETURN v_nro_referencia;
   END fu_obt_sig_nro_referencia;

   /* Funcion para Validar ApiKey/IpOrigen */
   FUNCTION fu_val_api_key(p_api_key IN VARCHAR2, p_ip_origen IN VARCHAR2) RETURN typ_MensajeRespuesta IS
      v_respuesta   typ_MensajeRespuesta := typ_MensajeRespuesta;
      v_ip_ori_ente ge_par_entes.val_parametro%TYPE;
      v_cod_ente    NUMBER;
   
      /* Obtener Codigo de Ente a partir del ApiKey */
      FUNCTION lf_obt_cod_ente RETURN NUMBER IS
         v_ret NUMBER;
      BEGIN
         SELECT DISTINCT e.cod_ente
           INTO v_ret
           FROM ge_entes e, ge_par_entes pe
          WHERE e.cod_ente = pe.cod_ente
            AND e.tipo = G_TIP_ENT_PAG
            AND pe.val_parametro = p_api_key;
         RETURN v_ret;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END;
   BEGIN
      PAW_UTI.pr_mensajeUsuario(C_OPE_APR, v_respuesta.nombreRespuesta, v_respuesta.descripcionRespuesta, v_respuesta.error);
      -- Obtener Codigo de Ente
      v_cod_ente := lf_obt_cod_ente;
      IF v_cod_ente IS NULL THEN
         PAW_UTI.pr_mensajeUsuario(C_API_KEY_INV, v_respuesta.nombreRespuesta, v_respuesta.descripcionRespuesta, v_respuesta.error);
         GOTO FIN;
      END IF;
      -- Validar IP Origen
      v_ip_ori_ente := fug_obt_parentes(v_cod_ente, 'IP_ORIGEN');
      IF v_ip_ori_ente IS NOT NULL THEN
         IF p_ip_origen IS NULL OR p_ip_origen != v_ip_ori_ente THEN
            PAW_UTI.pr_mensajeUsuario(C_IP_ORI_INV, v_respuesta.nombreRespuesta, v_respuesta.descripcionRespuesta, v_respuesta.error);
            GOTO FIN;
         END IF;
      ELSE
         PAW_UTI.pr_mensajeUsuario(C_IP_ORI_INV, v_respuesta.nombreRespuesta, v_respuesta.descripcionRespuesta, v_respuesta.error);
         GOTO FIN;
      END IF;
      <<FIN>>
      RETURN v_respuesta;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(C_API_KEY_INV, v_respuesta.nombreRespuesta, v_respuesta.descripcionRespuesta, v_respuesta.error);
         RETURN v_respuesta;
   END;

   /* Funcion para obtener datos de Boleta */
   FUNCTION fu_obt_dat_boleta(p_nro_boleta ge_acr_comercios.nro_boleta%TYPE, p_cod_ente ge_entes.cod_ente%TYPE) RETURN ge_acr_comercios%ROWTYPE IS
      v_racr ge_acr_comercios%ROWTYPE;
   BEGIN
      SELECT *
        INTO v_racr
        FROM ge_acr_comercios a
       WHERE a.nro_boleta = p_nro_boleta
         AND a.cod_ente = p_cod_ente;
      RETURN v_racr;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         BEGIN -- 05/2018 -- Se agrega para obtener datos del his
            SELECT *
              INTO v_racr
              FROM ge_acr_comercios_his a
             WHERE a.nro_boleta = p_nro_boleta
               AND a.cod_ente = p_cod_ente;
         RETURN v_racr;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               RETURN v_racr;
         END;
      WHEN OTHERS THEN
        RETURN NULL;
   END;
   --

   /* Procedimiento para Validar ApiKey/IpOrigen y obtener Código de Ente */
   PROCEDURE pr_val_ente(p_api_key IN VARCHAR2, p_ip_origen IN VARCHAR2, p_cod_ente IN OUT NUMBER, p_respuesta IN OUT typ_MensajeRespuesta) IS
      v_ip_ori_ente ge_par_entes.val_parametro%TYPE;
      /* Obtener Codigo de Ente a partir del ApiKey */
      FUNCTION lf_obt_cod_ente RETURN NUMBER IS
         v_result NUMBER;
         
      BEGIN
         SELECT DISTINCT e.cod_ente
           INTO v_result
           FROM ge_entes e, ge_par_entes pe
          WHERE e.cod_ente = pe.cod_ente
            AND e.tipo = G_TIP_ENT_PAG
            AND pe.parametro = G_API_KEY_PAC
            AND pe.val_parametro = p_api_key;
         RETURN v_result;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END;
   BEGIN
      PAW_UTI.pr_mensajeUsuario(C_OPE_APR, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
      -- Obtener Codigo de Ente
      p_cod_ente := lf_obt_cod_ente;
      IF p_cod_ente IS NULL THEN
         PAW_UTI.pr_mensajeUsuario(C_API_KEY_INV, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
         GOTO FIN;
      END IF;
      -- Validar IP Origen
      v_ip_ori_ente := fug_obt_parentes(p_cod_ente, 'IP_ORIGEN');
      IF v_ip_ori_ente IS NOT NULL THEN
         BEGIN
            SELECT column_value linea
              INTO v_ip_ori_ente
              FROM TABLE(fug_obt_tab_registro(REPLACE(v_ip_ori_ente, ';', ',')))
             WHERE column_value = p_ip_origen;
         EXCEPTION
            WHEN OTHERS THEN
               v_ip_ori_ente := NULL;
         END;
         IF p_ip_origen IS NULL OR v_ip_ori_ente IS NULL OR p_ip_origen != v_ip_ori_ente THEN
            PAW_UTI.pr_mensajeUsuario(C_IP_ORI_INV, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
            GOTO FIN;
         END IF;
      ELSE
         PAW_UTI.pr_mensajeUsuario(C_IP_ORI_INV, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
         GOTO FIN;
      END IF;
      <<FIN>>
      RETURN;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(C_API_KEY_INV, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
         RETURN;
   END;

   /* Obtener datos de Cuenta */
   PROCEDURE pr_obt_dat_cuenta(p_nro_cuenta IN VARCHAR2, p_cod_modulo OUT NUMBER, p_cod_modalidad OUT NUMBER, p_cod_oficina OUT NUMBER,
                               p_cod_moneda OUT VARCHAR2, p_respuesta IN OUT typ_MensajeRespuesta) IS
   BEGIN
      IF p_nro_cuenta IS NULL THEN
         PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
      ELSE
         SELECT cod_modulo, cod_modalidad, cod_oficina
           INTO p_cod_modulo, p_cod_modalidad, p_cod_oficina
           FROM ge_cuentas
          WHERE nro_cuenta = p_nro_cuenta;
         IF p_cod_modalidad = 31 THEN
            SELECT cod_moneda
              INTO p_cod_moneda
              FROM ah_cta_vistas
             WHERE nro_cuenta = p_nro_cuenta;
         ELSIF p_cod_modalidad = 41 THEN
            SELECT cod_moneda
              INTO p_cod_moneda
              FROM cc_cta_corrientes
             WHERE nro_cuenta = p_nro_cuenta;
         ELSIF p_cod_modalidad IN (42, 49) THEN
            SELECT cod_moneda
              INTO p_cod_moneda
              FROM cc_cta_bancarias
             WHERE nro_cuenta = p_nro_cuenta;
         END IF;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
      WHEN OTHERS THEN
         PAW_UTI.pr_mensajeUsuario(C_OTR_ERROR, p_respuesta.nombreRespuesta, p_respuesta.descripcionRespuesta, p_respuesta.error);
   END pr_obt_dat_cuenta;


   /* Procedimiento para insercion de log de peticiones procesadas */
   PROCEDURE pr_ins_log(p_mensaje VARCHAR2, p_respuesta VARCHAR2, p_datos VARCHAR2, p_cod_ente NUMBER, p_fec_inicio DATE, p_error VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO ge_log_acr_comercios
         (mensaje, respuesta, datos, cod_ente, fec_inicio, error)
      VALUES
         (substr(p_mensaje, 1, 4000), substr(p_respuesta, 1, 200), substr(p_datos, 1, 4000), p_cod_ente, p_fec_inicio, substr(p_error, 1, 4000));
      COMMIT;
   END pr_ins_log;

   /* Procedimiento para insercion de peticiones de acreditaciones */
   PROCEDURE pr_ins_acr_comercios(p_rg_acr_comercios IN ge_acr_comercios%ROWTYPE) IS
   BEGIN
      INSERT INTO ge_acr_comercios
         (nro_referencia, cod_ente, nro_boleta, fec_movimiento, hor_movimiento, fec_transaccion, hor_transaccion, tip_transaccion, tip_operacion,
          cta_debito, bco_debito, cta_credito, bco_credito, monto, moneda, beneficiario, tip_tarjeta, nro_lote, nro_bol_extorno)
      VALUES
         (p_rg_acr_comercios.nro_referencia, p_rg_acr_comercios.cod_ente, p_rg_acr_comercios.nro_boleta, p_rg_acr_comercios.fec_movimiento,
          p_rg_acr_comercios.hor_movimiento, p_rg_acr_comercios.fec_transaccion, p_rg_acr_comercios.hor_transaccion, p_rg_acr_comercios.tip_transaccion,
          p_rg_acr_comercios.tip_operacion, p_rg_acr_comercios.cta_debito, p_rg_acr_comercios.bco_debito, p_rg_acr_comercios.cta_credito,
          p_rg_acr_comercios.bco_credito, p_rg_acr_comercios.monto, p_rg_acr_comercios.moneda, p_rg_acr_comercios.beneficiario,
          p_rg_acr_comercios.tip_tarjeta, p_rg_acr_comercios.nro_lote, p_rg_acr_comercios.nro_bol_extorno);
   
      IF p_rg_acr_comercios.nro_bol_extorno IS NOT NULL THEN
         UPDATE ge_acr_comercios a
            SET a.extornado = 'S'
          WHERE a.nro_boleta = p_rg_acr_comercios.nro_bol_extorno;
      END IF;
   END pr_ins_acr_comercios;

   /* Inserta datos en la Tabla GE_BAT_MOVIMIENTOS */
   PROCEDURE pr_ins_bat_movimientos(rp_gmovi IN ge_movimientos%ROWTYPE, p_tip_movimiento IN VARCHAR2) IS
   BEGIN
      INSERT INTO GE_BAT_MOVIMIENTOS
         (cod_usuario, hora, nro_secuencia, cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda, cod_tra_padre, cod_transaccion, fecha,
          nro_documento, monto, cod_mod_padre, cod_mad_padre, EST_PRO_BATCH, TIP_OPERACION)
      VALUES
         (rp_gmovi.cod_usuario, rp_gmovi.hora, rp_gmovi.nro_secuencia, rp_gmovi.cod_modulo, rp_gmovi.cod_modalidad, rp_gmovi.cod_oficina,
          rp_gmovi.nro_cuenta, rp_gmovi.cod_moneda, rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.fecha, rp_gmovi.nro_documento,
          rp_gmovi.monto, rp_gmovi.cod_mod_padre, rp_gmovi.cod_mad_padre, 'N', p_tip_movimiento);
   END;

   /* Procedimiento para realizar validaciones de parámetros requeridos */
   PROCEDURE pr_val_parametros(p_cod_ente NUMBER, p_datAcreditaciones IN OUT typ_datosAcreditaciones,
                               p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones) IS
      v_ser_activo        ge_par_entes.val_parametro%TYPE;
      v_menAcreditaciones typ_menAcreditaciones := typ_menAcreditaciones();
   BEGIN
      -- Verifica Codigo de Ente Bepsa
      IF G_ENT_PAG_BEPSA IS NULL THEN
         -- Error en Configuración de Ente.
         PAW_UTI.pr_mensajeUsuario(C_ERR_CON_ENT, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
      END IF;
      -- Verificar Servicio Activo para el Ente
      v_ser_activo := nvl(fug_obt_parentes(p_cod_ente, C_SER_ACTIVO), 'N');
      IF v_ser_activo != 'S' THEN
         -- Servicio No Activo para el Ente.
         PAW_UTI.pr_mensajeUsuario(C_ERR_CON_ENT, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
      END IF;
      -- Código de Usuario
      G_COD_USUARIO := fug_obt_parentes(p_cod_ente, 'COD_USU_PAC');
      IF G_COD_USUARIO IS NULL THEN
         -- Error en Configuración de Ente.
         PAW_UTI.pr_mensajeUsuario(C_ERR_CON_ENT, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
      END IF;
      IF NVL(p_retorno.error, 'N') = 'S' THEN
         -- Error Genérico de Operacion no Autorizada
         PAW_UTI.pr_mensajeUsuario(C_OPE_NO_AUT, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         GOTO FIN;
      END IF;
   
      -- Transaccion: 00 = COMPRA, 02 = CONSULTA
      IF p_datAcreditaciones.tipoTransaccion IS NULL OR TO_NUMBER(p_datAcreditaciones.tipoTransaccion) NOT IN (0, 2) THEN
         -- Tipo de Transaccion inválida.
         PAW_UTI.pr_mensajeUsuario(C_TRA_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
      END IF;
      -- Extorno: 00=TRANSACCION, 99=EXTORNO
      IF p_datAcreditaciones.tipoOperacion IS NULL OR TO_NUMBER(p_datAcreditaciones.tipoOperacion) NOT IN (0, 99) THEN
         -- Tipo de Operacion inválida.
         PAW_UTI.pr_mensajeUsuario(C_OPE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
      END IF;
   
      -- Boleta / Boleta Extorno
      IF p_datAcreditaciones.numeroBoleta IS NULL THEN
         -- Nro. de Boleta no puede ser nulo.
         PAW_UTI.pr_mensajeUsuario(C_BOL_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
      ELSE
         IF TO_NUMBER(p_datAcreditaciones.tipoOperacion) = 99 THEN
            IF p_datAcreditaciones.numeroBoletaExtorno IS NULL THEN
               --Nro. de Boleta a Extornar no puede ser nulo.
               PAW_UTI.pr_mensajeUsuario(C_BOL_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
               p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
         END IF;
      END IF;
   
      -- 00 = COMPRA, 02 = CONSULTA
      IF TO_NUMBER(p_datAcreditaciones.tipoTransaccion) != 2 THEN
         -- Importe
         IF nvl(p_datAcreditaciones.montoTransaccion, 0) <= 0 THEN
            -- Importe debe ser mayor a cero
            PAW_UTI.pr_mensajeUsuario(C_MTO_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Moneda
         IF p_datAcreditaciones.Moneda IS NULL THEN
            -- Moneda no puede ser nulo.
            PAW_UTI.pr_mensajeUsuario(C_MON_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Nombre de Comercio
         IF p_datAcreditaciones.nombreComercio IS NULL THEN
            -- Nombre de Comercio no puede ser nulo.
            PAW_UTI.pr_mensajeUsuario(C_COM_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Fecha Hora de Transaccion
         IF p_datAcreditaciones.fechaTransaccion IS NULL THEN
            -- Fecha de Transaccion no puede ser nulo.
            PAW_UTI.pr_mensajeUsuario(C_FEC_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Tipo de Tarjeta
         IF p_datAcreditaciones.fechaTransaccion IS NULL THEN
            -- Tipo de Tarjeta no puede ser nulo.
            PAW_UTI.pr_mensajeUsuario(C_TIP_TAR_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
      END IF;
      IF NVL(p_retorno.error, 'N') = 'S' THEN
         -- Error Genérico de Parámetros inválidos
         PAW_UTI.pr_mensajeUsuario(C_DAT_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         GOTO FIN;
      END IF;
      <<FIN>>
      RETURN;
   END;

   /* Procedimiento para realizar validaciones iniciales */
   PROCEDURE pr_val_inicial(p_cod_ente IN NUMBER, p_fec_actual IN DATE, p_cod_moneda IN OUT ba_monedas.cod_moneda%TYPE,
                            p_cta_bco_ente IN OUT ge_cuentas.nro_cuenta%TYPE, p_bco_ente IN OUT ge_bancos.cod_banco%TYPE,
                            p_cod_tra_padre IN OUT ge_transacciones.cod_transaccion%TYPE, p_ind_rub_debito IN OUT VARCHAR2,
                            p_tra_con_debito IN OUT ge_movimientos.cod_transaccion%TYPE, p_tra_con_credito IN OUT ge_movimientos.cod_transaccion%TYPE,
                            p_mod_con_credito IN OUT ge_movimientos.cod_modulo%TYPE, p_mad_con_credito IN OUT ge_movimientos.cod_modalidad%TYPE,
                            p_cod_rub_credito IN OUT ge_movimientos.cod_rubro%TYPE, p_nro_cta_cli_cre IN OUT VARCHAR2, p_nro_cta_fic_cre OUT VARCHAR2,
                            p_mod_con_debito IN OUT ge_movimientos.cod_modulo%TYPE, p_mad_con_debito IN OUT ge_movimientos.cod_modalidad%TYPE,
                            p_cod_rub_debito IN OUT ge_movimientos.cod_rubro%TYPE, p_nro_cta_cli_deb IN OUT VARCHAR2, p_nro_cta_fic_deb OUT VARCHAR2,
                            p_ind_rub_credito IN OUT VARCHAR2, p_datAcreditaciones IN OUT typ_datosAcreditaciones,
                            p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones) IS
      v_menAcreditaciones typ_menAcreditaciones := typ_menAcreditaciones();
      v_racr              ge_acr_comercios%ROWTYPE;
      /* Obtener Codigo de Banco a partir del Numero de Cuenta */
      FUNCTION lf_obt_cod_banco(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN ge_bancos.cod_banco%TYPE IS
         v_cod_banco ge_bancos.cod_banco%TYPE;
      BEGIN
         SELECT a.cod_banco
           INTO v_cod_banco
           FROM cc_cta_bancarias a
          WHERE a.nro_cuenta = p_nro_cuenta;
         RETURN v_cod_banco;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END;
      --
      /* Obtener Dato Cuenta Ficticia */
      PROCEDURE lp_obt_dat_cta_ficticia(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_ind_rubro OUT VARCHAR2,
                                        p_cod_transaccion OUT cc_cta_ficticias.cod_transaccion%TYPE, p_cod_modulo OUT cc_cta_ficticias.cod_modulo%TYPE,
                                        p_cod_modalidad OUT cc_cta_ficticias.cod_modalidad%TYPE, p_cod_rubro OUT cc_cta_ficticias.cod_rubro%TYPE,
                                        p_nro_cta_cliente OUT cc_cta_ficticias.nro_cta_cliente%TYPE) IS
      BEGIN
         SELECT 'S', cod_transaccion, cod_modulo, cod_modalidad, cod_rubro, nro_cta_cliente
           INTO p_ind_rubro, p_cod_transaccion, p_cod_modulo, p_cod_modalidad, p_cod_rubro, p_nro_cta_cliente
           FROM cc_cta_ficticias
          WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            p_ind_rubro  := 'N';
            p_cod_transaccion  := NULL;
            p_cod_modulo  := NULL;
            p_cod_modalidad  := NULL;
            p_cod_rubro  := NULL;
            p_nro_cta_cliente := NULL;
      END;
      --
      /* Funcion para validar Boleta de Extorno */
      FUNCTION lf_val_bol_extorno(p_nro_boleta ge_acr_comercios.nro_boleta%TYPE, p_cod_ente ge_entes.cod_ente%TYPE) RETURN VARCHAR2 IS
         v_result VARCHAR2(1);
         -- S = Si puede extornar
         -- N = No existe boleta a extornar
      BEGIN
         SELECT 'S'
           INTO v_result
           FROM ge_acr_comercios a
          WHERE a.nro_boleta = p_nro_boleta
            AND a.cod_ente = p_cod_ente
            AND a.tip_operacion = '00' -- 00 = COMPRA
            AND nvl(a.extornado, 'N') = 'N' -- No haya sido extornado
            AND NOT EXISTS (SELECT 1
                   FROM ge_acr_comercios c
                  WHERE c.nro_bol_extorno = p_nro_boleta)
            AND NOT EXISTS (SELECT 1  -- 05/2018 -- Se agrega para obtener datos del his
                   FROM ge_acr_comercios_his c
                  WHERE c.nro_bol_extorno = p_nro_boleta);
         RETURN v_result;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            BEGIN -- 05/2018 -- Se agrega para obtener datos del his
               SELECT 'S'
                 INTO v_result
                 FROM ge_acr_comercios_his a
                WHERE a.nro_boleta = p_nro_boleta
                  AND a.cod_ente = p_cod_ente
                  AND a.tip_operacion = '00' -- 00 = COMPRA
                  AND nvl(a.extornado, 'N') = 'N' -- No haya sido extornado
                  AND NOT EXISTS (SELECT 1
                         FROM ge_acr_comercios c
                        WHERE c.nro_bol_extorno = p_nro_boleta)
                  AND NOT EXISTS (SELECT 1
                         FROM ge_acr_comercios_his c
                        WHERE c.nro_bol_extorno = p_nro_boleta);
               RETURN v_result;
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  RETURN 'N';
            END;
         WHEN OTHERS THEN
            RETURN 'N';
      END;
      --
      /* Funcion para validar Cantidad Máxima de Dias para Solicitar Extorno de Operacion */
      FUNCTION lf_val_can_dia_extorno(p_fec_actual IN DATE, p_fec_ext IN DATE) RETURN VARCHAR2 IS
         v_result VARCHAR2(1) := 'S';
         -- S = Si puede extornar
         -- N = No se puede extornar. Cantidad de dias superado.
         v_can_dia_ext NUMBER := 0;
      BEGIN
         v_can_dia_ext := TO_NUMBER(NVL(fug_obt_parentes(p_cod_ente, C_CAN_DIA_EXT), 0));
         IF (p_fec_actual - p_fec_ext) > v_can_dia_ext THEN
            v_result := 'N';
         END IF;
         RETURN v_result;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 'N';
      END;
      --
   BEGIN
      -- Verificar Moneda de la Transaccion
      IF TO_NUMBER(p_datAcreditaciones.tipoTransaccion) != 2 THEN
         IF TO_NUMBER(p_datAcreditaciones.Moneda) = 0 THEN
            IF p_datAcreditaciones.tipoTarjeta = 'TD' THEN
            p_cod_moneda   := G_MON_GS;
            p_cta_bco_ente := nvl(fug_obt_parentes(p_cod_ente, C_BCO_PAIS_GS), 'N');
            IF p_cta_bco_ente IS NOT NULL THEN
               p_bco_ente := lf_obt_cod_banco(p_cta_bco_ente);
              END IF;
            ELSE
               p_cta_bco_ente := nvl(fug_obt_parentes(p_cod_ente, G_CTA_TRA_ENT_GS), 'N');
               p_bco_ente := G_COD_BCO;
            END IF;
         ELSIF TO_NUMBER(p_datAcreditaciones.Moneda) = 1 THEN
            p_cod_moneda   := G_MON_USD;
            p_cta_bco_ente := nvl(fug_obt_parentes(p_cod_ente, C_BCO_PAIS_USD), 'N');
            IF p_cta_bco_ente IS NOT NULL THEN
               p_bco_ente := lf_obt_cod_banco(p_cta_bco_ente);
            END IF;
            -- Código de Moneda no válido.
            -- Quitar al habilitar operacion con moneda USD
            PAW_UTI.pr_mensajeUsuario(C_MON_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         ELSE
            -- Código de Moneda no válido.;
            PAW_UTI.pr_mensajeUsuario(C_MON_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         IF NVL(p_retorno.error, 'N') = 'S' THEN
            -- Error Genérico de Parámetros inválidos
            PAW_UTI.pr_mensajeUsuario(C_DAT_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            GOTO FIN;
         END IF;
      END IF;
   
      -- Validar Nro. de Boleta
      IF TO_NUMBER(p_datAcreditaciones.tipoTransaccion) != 2 THEN
         v_racr := fu_obt_dat_boleta(p_datAcreditaciones.numeroBoleta, p_cod_ente);
         IF v_racr.nro_referencia IS NOT NULL THEN
            PAW_UTI.pr_mensajeUsuario(C_PAG_DUP, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Validar Boleta a Extornar
         IF TO_NUMBER(p_datAcreditaciones.tipoOperacion) = 99 THEN
            v_racr := fu_obt_dat_boleta(p_datAcreditaciones.numeroBoletaExtorno, p_cod_ente);
            IF v_racr.nro_referencia IS NULL THEN
               PAW_UTI.pr_mensajeUsuario(C_PAG_INE, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
               p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            ELSE
               -- Verificar Boleta Extorno
               IF nvl(lf_val_bol_extorno(p_datAcreditaciones.numeroBoletaExtorno, p_cod_ente), 'S') = 'N' THEN
                  PAW_UTI.pr_mensajeUsuario(C_BOL_EXT_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
               -- Validar Cuenta Débito
               IF p_cod_ente = G_ENT_PAG_BEPSA THEN
                  p_datAcreditaciones.cuentaDebito := PAW_UTI.fu_ver_cuenta(p_datAcreditaciones.cuentaDebito);
               ELSE
                  p_datAcreditaciones.cuentaDebito := PAW_UTI.fu_for_cuenta(p_datAcreditaciones.cuentaDebito);
               END IF;
               IF p_datAcreditaciones.cuentaDebito != v_racr.cta_credito THEN
                  PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
               -- Validar Monto a reversar
               IF p_datAcreditaciones.montoTransaccion != v_racr.monto THEN
                  PAW_UTI.pr_mensajeUsuario(C_MTO_EXT_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
               -- Validar Moneda
               IF p_datAcreditaciones.moneda != v_racr.moneda THEN
                  PAW_UTI.pr_mensajeUsuario(C_MON_EXT_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
               -- Validar Cantidad Máxima de Dias para Solicitar Extorno de Operacion
               IF lf_val_can_dia_extorno(p_fec_actual, v_racr.fec_movimiento) = 'N' THEN
                  PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
            END IF;
         END IF;
         IF NVL(p_retorno.error, 'N') = 'S' THEN
            -- Error Genérico de Operacion No Aprobada
            PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            GOTO FIN;
         END IF;
      END IF;
   
      -- 00 = COMPRA
      IF TO_NUMBER(p_datAcreditaciones.tipoTransaccion) = 0 THEN
         -- 00 = TRANSACCION
         IF TO_NUMBER(p_datAcreditaciones.tipoOperacion) = 0 THEN
            -- Cuenta/Banco Débito
            IF p_cta_bco_ente IS NOT NULL AND p_bco_ente IS NOT NULL THEN
               IF NVL(p_datAcreditaciones.bancoDebito, 0) = 0 THEN
                  p_datAcreditaciones.bancoDebito := p_bco_ente;
               END IF;
               IF p_datAcreditaciones.bancoDebito != p_bco_ente THEN
                  -- Banco Débito no corresponde al Ente.
                  PAW_UTI.pr_mensajeUsuario(C_BCO_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
               IF nvl(p_datAcreditaciones.cuentaDebito, '0') = '0' THEN
                  p_datAcreditaciones.cuentaDebito := p_cta_bco_ente;
               END IF;
               IF p_datAcreditaciones.cuentaDebito IS NOT NULL THEN
                  IF p_datAcreditaciones.cuentaDebito != p_cta_bco_ente THEN
                     -- Cuenta Débito no corresponde al Ente.
                     PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                     v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                     v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                     v_menAcreditaciones.type    := 'ERROR';
                     p_lisMenAcreditaciones.extend;
                     p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
                  END IF;
               ELSE
                  -- Cuenta Débito no puede ser nulo.
                  PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
            ELSE
               IF p_datAcreditaciones.bancoDebito IS NULL THEN
                  -- Banco Débito no puede ser nulo.
                  PAW_UTI.pr_mensajeUsuario(C_BCO_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               ELSE
                  IF nvl(p_datAcreditaciones.cuentaDebito, '0') = '0' THEN
                     -- Obtener Cuenta del Banco
                     p_datAcreditaciones.cuentaDebito := fu_obt_cta_banco(p_datAcreditaciones.bancoDebito, p_cod_moneda);
                  END IF;
               END IF;
               IF p_datAcreditaciones.cuentaDebito IS NULL THEN
                  -- Cuenta Débito no puede ser nulo.
                  PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
                  GOTO FIN;
               END IF;
            END IF;
            -- Cuenta/Banco Crédito
            IF NVL(p_datAcreditaciones.bancoCredito, 0) = 0 THEN
               p_datAcreditaciones.bancoCredito := G_COD_BCO;
            END IF;
            IF p_datAcreditaciones.bancoCredito != G_COD_BCO THEN
               -- Banco Crédito no corresponde a la Entidad.
               PAW_UTI.pr_mensajeUsuario(C_BCO_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
               p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
            IF p_datAcreditaciones.cuentaCredito IS NOT NULL THEN
               IF p_datAcreditaciones.bancoCredito = G_COD_BCO THEN
                  IF p_cod_ente = G_ENT_PAG_BEPSA THEN
                     p_datAcreditaciones.cuentaCredito := PAW_UTI.fu_ver_cuenta(p_datAcreditaciones.cuentaCredito);
                  ELSE
                     p_datAcreditaciones.cuentaCredito := PAW_UTI.fu_for_cuenta(p_datAcreditaciones.cuentaCredito);
                  END IF;
               END IF;
            ELSE
               -- Cuenta Crédito no puede ser nulo.
               PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
               p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
            -- Transaccion Padre.
            IF NVL(p_datAcreditaciones.tipoTarjeta, 'X') = 'TD' THEN
               p_cod_tra_padre := fug_obt_parentes(p_cod_ente, C_TRA_PAD_PAG_TD);
            ELSIF NVL(p_datAcreditaciones.tipoTarjeta, 'X') = 'TC' THEN
               p_cod_tra_padre := fug_obt_parentes(p_cod_ente, C_TRA_PAD_PAG_TC);
            ELSE
               -- Tipo de Tarjeta no válida.
               PAW_UTI.pr_mensajeUsuario(C_TIP_TAR_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
            END IF;
            -- 99 = EXTORNO   
         ELSIF TO_NUMBER(p_datAcreditaciones.tipoOperacion) = 99 THEN
            -- Cuenta Banco Debito      
            IF nvl(p_datAcreditaciones.bancoDebito, 0) = 0 THEN
               p_datAcreditaciones.bancoDebito := G_COD_BCO;
            END IF;
            IF p_datAcreditaciones.bancoDebito != G_COD_BCO THEN
               -- Banco Débito no corresponde a la Entidad.
               PAW_UTI.pr_mensajeUsuario(C_BCO_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
               p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
            IF p_datAcreditaciones.cuentaDebito IS NOT NULL THEN
               IF p_datAcreditaciones.bancoDebito = G_COD_BCO THEN
                  IF p_cod_ente = G_ENT_PAG_BEPSA THEN
                     p_datAcreditaciones.cuentaDebito := PAW_UTI.fu_ver_cuenta(p_datAcreditaciones.cuentaDebito);
                  ELSE
                     p_datAcreditaciones.cuentaDebito := PAW_UTI.fu_for_cuenta(p_datAcreditaciones.cuentaDebito);
                  END IF;
               END IF;
            ELSE
               -- Cuenta Débito no puede ser nulo.
               PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
               p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
            -- Cuenta/Banco Credito  
            IF p_cta_bco_ente IS NOT NULL AND p_bco_ente IS NOT NULL THEN
               IF nvl(p_datAcreditaciones.bancoCredito, 0) = 0 THEN
                  p_datAcreditaciones.bancoCredito := p_bco_ente;
               END IF;
               IF p_datAcreditaciones.bancoCredito != p_bco_ente THEN
                  -- Banco Crédito no corresponde al Ente.
                  PAW_UTI.pr_mensajeUsuario(C_BCO_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
               IF nvl(p_datAcreditaciones.cuentaCredito, '0') = '0' THEN
                  p_datAcreditaciones.cuentaCredito := p_cta_bco_ente;
               END IF;
               IF p_datAcreditaciones.cuentaCredito IS NOT NULL THEN
                  IF p_datAcreditaciones.cuentaCredito != p_cta_bco_ente THEN
                     -- Cuenta Crédito no corresponde al Ente.
                     PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                     v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                     v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                     v_menAcreditaciones.type    := 'ERROR';
                     p_lisMenAcreditaciones.extend;
                     p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
                  END IF;
               ELSE
                  -- Cuenta Crédito no puede ser nulo.
                  PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
            ELSE
               IF p_datAcreditaciones.bancoCredito IS NULL THEN
                  -- Banco Crédito no puede ser nulo.
                  PAW_UTI.pr_mensajeUsuario(C_BCO_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               ELSE
                  -- Obtener Cuenta del Banco
                  IF nvl(p_datAcreditaciones.cuentaCredito, '0') = '0' THEN
                     p_datAcreditaciones.cuentaCredito := fu_obt_cta_banco(p_datAcreditaciones.bancoCredito, p_cod_moneda);
                  END IF;
               END IF;
               IF p_datAcreditaciones.cuentaCredito IS NULL THEN
                  -- Cuenta Crédito no puede ser nulo.
                  PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
                  v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
                  v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
                  v_menAcreditaciones.type    := 'ERROR';
                  p_lisMenAcreditaciones.extend;
                  p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
               END IF;
            END IF;
            -- Transaccion Padre
            IF NVL(p_datAcreditaciones.tipoTarjeta, 'X') = 'TD' THEN
               p_cod_tra_padre := fug_obt_parentes(p_cod_ente, C_TRA_PAD_DEB_TD);
            ELSIF NVL(p_datAcreditaciones.tipoTarjeta, 'X') = 'TC' THEN
               p_cod_tra_padre := fug_obt_parentes(p_cod_ente, C_TRA_PAD_DEB_TC);
            ELSE
               -- Tipo de Tarjeta no válida.
               PAW_UTI.pr_mensajeUsuario(C_TIP_TAR_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
               v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
               v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               p_lisMenAcreditaciones.extend;
               p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
         ELSE
            -- Operación no válida.
            PAW_UTI.pr_mensajeUsuario(C_OPE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- 02 = CONSULTA
      ELSIF TO_NUMBER(p_datAcreditaciones.tipoTransaccion) = 2 THEN
         -- GET ACREDITACION A COMERCIOS
         --Validar solo parámetro de Nro de Ticket
         v_racr := fu_obt_dat_boleta(p_datAcreditaciones.numeroBoleta, p_cod_ente);
         IF v_racr.nro_referencia IS NULL THEN
            PAW_UTI.pr_mensajeUsuario(C_PAG_INE, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            GOTO FIN;
         END IF;
      ELSE
         -- Transaccion inválida.
         PAW_UTI.pr_mensajeUsuario(C_TRA_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
      END IF;
   
      -- Verifica si la cuenta es una cuenta ficticia
      -- Banco/Cuenta Débito
      IF TO_NUMBER(p_datAcreditaciones.tipoTransaccion) != 2 THEN
         IF p_datAcreditaciones.bancoDebito = G_COD_BCO THEN
            lp_obt_dat_cta_ficticia(p_datAcreditaciones.cuentaDebito, p_ind_rub_debito, p_tra_con_debito, p_mod_con_debito, p_mad_con_debito,
                                    p_cod_rub_debito, p_nro_cta_cli_deb);
            IF p_ind_rub_debito = 'S' THEN
               p_nro_cta_fic_deb                := p_datAcreditaciones.cuentaDebito;
               p_datAcreditaciones.cuentaDebito := NULL;
            END IF;
            IF p_cod_rub_debito IS NULL AND p_nro_cta_cli_deb IS NOT NULL THEN
               p_datAcreditaciones.cuentaDebito := p_nro_cta_cli_deb;
               p_ind_rub_debito                 := 'N';
            END IF;
         END IF;
         IF p_cod_rub_debito IS NULL AND p_datAcreditaciones.cuentaDebito IS NULL THEN
            -- Rubro/Cuenta Débito no puede ser nulo.
            PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Rubro/Cuenta Crédito
         IF p_datAcreditaciones.bancoCredito = G_COD_BCO THEN
            lp_obt_dat_cta_ficticia(p_datAcreditaciones.cuentaCredito, p_ind_rub_credito, p_tra_con_credito, p_mod_con_credito, p_mad_con_credito,
                                    p_cod_rub_credito, p_nro_cta_cli_cre);
            IF p_ind_rub_credito = 'S' THEN
               p_nro_cta_fic_cre                 := p_datAcreditaciones.cuentaCredito;
               p_datAcreditaciones.cuentaCredito := NULL;
            END IF;
            IF p_cod_rub_credito IS NULL AND p_nro_cta_cli_cre IS NOT NULL THEN
               p_datAcreditaciones.cuentaCredito := p_nro_cta_cli_cre;
               p_ind_rub_credito                 := 'N';
            END IF;
         END IF;
         IF p_cod_rub_credito IS NULL AND p_datAcreditaciones.cuentaCredito IS NULL THEN
            -- Rubro/Cuenta Crédito no puede ser nulo.
            PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Validar Cuenta Crédito igual a Cuenta Débito
         IF p_datAcreditaciones.cuentaDebito = p_datAcreditaciones.cuentaCredito THEN
            PAW_UTI.pr_mensajeUsuario(C_CRE_DEB_IGU, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         IF NVL(p_retorno.error, 'N') = 'S' THEN
            -- Error Genérico de Parámetros inválidos
            PAW_UTI.pr_mensajeUsuario(C_DAT_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            GOTO FIN;
         END IF;
         -- Validar Transaccion Padre
         IF p_cod_tra_padre IS NULL THEN
            -- Transacción no definida para el Ente.
            PAW_UTI.pr_mensajeUsuario(C_ERR_CON_ENT, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         IF NVL(p_retorno.error, 'N') = 'S' THEN
            -- Error Genérico de Operacion No Autorizada
            PAW_UTI.pr_mensajeUsuario(C_OPE_NO_AUT, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         END IF;
      END IF;
      <<FIN>>
      RETURN;
   END;

   /* Procedimiento para Verificar operacion */
   PROCEDURE pr_ver_operacion(p_cta_debito IN ge_cuentas.nro_cuenta%TYPE, p_cta_credito IN ge_cuentas.nro_cuenta%TYPE,
                              p_cod_tra_padre IN ge_transacciones.cod_transaccion%TYPE, p_cod_mod_padre IN ge_transacciones.cod_modulo%TYPE,
                              p_cod_mad_padre IN ge_transacciones.cod_modalidad%TYPE, p_cod_mon_debito IN ba_monedas.cod_moneda%TYPE,
                              p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE, p_imp_debito IN NUMBER, p_imp_credito IN NUMBER,
                              p_cod_ofi_origen IN ba_oficinas.cod_oficina%TYPE, p_mod_cta_deb IN OUT ba_modulos.cod_modulo%TYPE,
                              p_mad_cta_deb IN OUT ge_modalidades.cod_modalidad%TYPE, p_mod_cta_cre IN OUT ba_modulos.cod_modulo%TYPE,
                              p_mad_cta_cre IN OUT ge_modalidades.cod_modalidad%TYPE, p_cod_per_deb IN OUT ba_personas.cod_persona%TYPE,
                              p_cod_per_cre IN OUT ba_personas.cod_persona%TYPE, p_nro_cta_comb_deb IN OUT ge_cuentas.nro_cuenta%TYPE,
                              p_est_cta_deb IN OUT ge_cuentas.estado%TYPE, p_est_cta_cre IN OUT ge_cuentas.estado%TYPE,
                              p_sal_dis_deb IN OUT ah_cta_vistas.sal_total%TYPE, p_sal_dis_cre IN OUT ah_cta_vistas.sal_total%TYPE,
                              p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones) IS
      v_procesa           VARCHAR2(1);
      v_nvo_est_deb       ah_cta_vistas.nro_cuenta%TYPE;
      v_mad_cta_cre       ge_cuentas.cod_modalidad%TYPE;
      v_nvo_est_cre       ah_cta_vistas.nro_cuenta%TYPE;
      v_menAcreditaciones typ_menAcreditaciones := typ_menAcreditaciones();
      v_cod_error         NUMBER;
      v_men_error         VARCHAR2(1000);
   BEGIN
      -- Cuenta Débito
      BEGIN
         v_procesa := 'N';
         pag_cta.pr_ver_operacion(p_cta_debito, p_cod_tra_padre, p_cod_mod_padre, p_cod_mad_padre, 'D', p_cod_mon_debito, p_imp_debito, p_cod_ofi_origen,
                                  p_mod_cta_deb, p_mad_cta_deb, v_nvo_est_deb, p_sal_dis_deb, v_procesa, G_COD_TRA_DEB);
      EXCEPTION
         WHEN OTHERS THEN
            v_procesa := 'N';
      END;
      IF nvl(v_procesa, 'N') = 'N' THEN
         v_cod_error := PAG_CTA.FU_OBT_COD_ERROR;
         v_men_error := PAG_CTA.FU_OBT_MSJ_ERROR;
         -- Cuenta Inexistente
         IF nvl(v_cod_error, 0) = 12 THEN
            PAW_UTI.pr_mensajeUsuario(C_DEB_INE, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            p_retorno.descripcionRespuesta := v_cod_error || ' - ' || v_men_error;
            GOTO FIN;
         END IF;
         -- Validacion de Saldo Insuficiente para Débito
         -- controlamos si dispone de saldo suficiente
         IF nvl(v_cod_error, 0) IN (25, 29, 31, 36) THEN
            PAW_UTI.pr_mensajeUsuario(C_DEB_SAL_INS, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            p_retorno.descripcionRespuesta := v_cod_error || ' - ' || v_men_error;
            GOTO FIN;
         END IF;
         IF nvl(v_procesa, 'N') = 'N' THEN
            PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            p_retorno.descripcionRespuesta := v_cod_error || ' - ' || v_men_error;
            GOTO FIN;
         END IF;
      ELSE
         p_est_cta_deb      := PAG_CTA.FU_OBT_EST_CUENTA;
         p_cod_per_deb      := PAG_CTA.G_CTAS.COD_CLIENTE;
         p_nro_cta_comb_deb := PAG_CTA.G_CTAS.NRO_CTA_COMBINADA;
         --p_mad_cta_deb      := PAG_CTA.FU_OBT_MAD_CUENTA;
         -- Estado distinto a Normal o con bloqueo de saldo -- Estado Inactivo tambien debe permitir.
         IF p_est_cta_deb NOT IN ('N', 'S', 'I') THEN
            -- Estado de Cuenta Débito distinto a Normal o con bloqueo de Saldo.
            PAW_UTI.pr_mensajeUsuario(C_EST_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Verifica si el Cliente está inhibido y la causa es por Demanda Judicial
         IF fug_obt_inhibicion(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'), p_cod_per_deb, p_cta_debito) THEN
            PAW_UTI.pr_mensajeUsuario(C_DEB_PRO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         END IF;
         -- Verifica la modalidad de la Cuenta
         -- Ahorro a la Vista / Cta. Corrientes / Cuentas Bancarias
         IF p_mad_cta_deb NOT IN (31, 41, 42 /*, 48, 46, 49*/) THEN
            PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            GOTO FIN;
         END IF;
      END IF;
   
      -- Cuenta Crédito
      BEGIN
         pag_cta.pr_ver_operacion(p_cta_credito, p_cod_tra_padre, p_cod_mod_padre, p_cod_mad_padre, 'C', p_cod_mon_credito, p_imp_credito,
                                  p_cod_ofi_origen, p_mod_cta_cre, p_mad_cta_cre, v_nvo_est_cre, p_sal_dis_cre, v_procesa, G_COD_TRA_CRE);
      EXCEPTION
         WHEN OTHERS THEN
            v_procesa := 'N';
      END;
      IF nvl(v_procesa, 'N') = 'N' THEN
         v_cod_error := PAG_CTA.FU_OBT_COD_ERROR;
         v_men_error := PAG_CTA.FU_OBT_MSJ_ERROR;
         -- Cuenta Inexistente
         IF v_cod_error = 12 THEN
            PAW_UTI.pr_mensajeUsuario(C_CRE_INE, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            p_retorno.descripcionRespuesta := v_cod_error || ' - ' || v_men_error;
            GOTO FIN;
         END IF;
         PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
         v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
         v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         p_lisMenAcreditaciones.extend;
         p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
         p_retorno.descripcionRespuesta := v_cod_error || ' - ' || v_men_error;
         GOTO FIN;
      ELSE
         p_est_cta_cre := PAG_CTA.FU_OBT_EST_CUENTA;
         p_cod_per_cre := PAG_CTA.G_CTAS.COD_CLIENTE;
         --p_mad_cta_cre := PAG_CTA.FU_OBT_MAD_CUENTA;
         -- Estado distinto a Normal o con bloqueo de saldo -- Estado Inactivo tambien debe permitir.
         IF p_est_cta_cre NOT IN ('N', 'S', 'I') THEN
            -- Estado de Cuenta Débito distinto a Normal o con bloqueo de Saldo.
            PAW_UTI.pr_mensajeUsuario(C_EST_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            GOTO FIN;
         END IF;
         -- Verifica si el Cliente está inhibido y la causa es por Demanda Judicial
         IF fug_obt_inhibicion(fug_obt_pardinamico('COD_CAU_DEM_JUDICIAL'), p_cod_per_cre, p_cta_credito) THEN
            -- Cliente inhibido.
            PAW_UTI.pr_mensajeUsuario(C_CRE_PRO, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            GOTO FIN;
         END IF;
         -- Verifica la modalidad de la Cuenta
         -- Ahorro a la Vista / Cta. Corrientes / Cuentas Bancarias
         IF v_mad_cta_cre NOT IN (31, 41, 42 /*, 48, 46, 49*/) THEN
            PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            GOTO FIN;
         END IF;
      END IF;
      <<FIN>>
      RETURN;
   END;

   /* Procedimiento para Procesar operacion */
   PROCEDURE pr_pro_operacion(p_cta_debito IN ge_cuentas.nro_cuenta%TYPE, p_cta_credito IN ge_cuentas.nro_cuenta%TYPE,
                              p_bco_credito IN ge_bancos.cod_banco%TYPE, p_nro_cta_comb ge_cuentas.nro_cuenta%TYPE,
                              p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_tra_padre IN ge_movimientos.cod_tra_padre%TYPE,
                              p_mod_cta_deb IN ge_cuentas.cod_modulo%TYPE, p_mad_cta_deb IN ge_cuentas.cod_modalidad%TYPE,
                              p_mod_cta_cre IN ge_cuentas.cod_modulo%TYPE, p_mad_cta_cre IN ge_cuentas.cod_modalidad%TYPE,
                              p_ofi_cta_deb IN ba_oficinas.cod_oficina%TYPE, p_ofi_cta_cre IN ba_oficinas.cod_oficina%TYPE,
                              p_ofi_origen IN ba_oficinas.cod_oficina%TYPE, p_mon_cta_deb IN ba_monedas.cod_moneda%TYPE,
                              p_mon_cta_cre IN ba_monedas.cod_moneda%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                              p_est_cta_deb IN ge_cuentas.estado%TYPE, p_est_cta_cre IN ge_cuentas.estado%TYPE,
                              p_sal_dis_debito IN OUT ah_cta_vistas.sal_total%TYPE, p_cod_usuario IN OUT ba_usuarios.cod_usuario%TYPE,
                              p_hora IN OUT ge_movimientos.hora%TYPE, p_fecha IN OUT ge_movimientos.fecha%TYPE, p_es_nocturno IN VARCHAR2,
                              p_horario IN VARCHAR2, p_concepto IN ge_movimientos.concepto%TYPE, p_cod_modulo IN ge_movimientos.cod_modulo%TYPE,
                              p_cod_modalidad IN ge_movimientos.cod_modalidad%TYPE, p_fec_valor IN ge_movimientos.fec_valor%TYPE,
                              p_imp_debito IN ge_movimientos.monto%TYPE, p_imp_credito IN ge_movimientos.monto%TYPE,
                              p_cot_debito IN ge_movimientos.cotizacion%TYPE, p_cot_credito IN ge_movimientos.cotizacion%TYPE,
                              p_nro_documento IN ge_movimientos.nro_documento%TYPE, p_nro_documento2 IN ge_movimientos.nro_documento2%TYPE,
                              p_nro_documento3 IN ge_movimientos.nro_documento3%TYPE, p_ind_rub_debito IN VARCHAR2, p_ind_rub_credito IN VARCHAR2,
                              p_tra_con_debito IN OUT ge_movimientos.cod_transaccion%TYPE, p_tra_con_credito IN OUT ge_movimientos.cod_transaccion%TYPE,
                              p_cod_rub_debito IN OUT ge_movimientos.cod_rubro%TYPE, p_cod_rub_credito IN OUT ge_movimientos.cod_rubro%TYPE,
                              p_mod_con_credito IN OUT ge_movimientos.cod_modulo%TYPE, p_mad_con_credito IN OUT ge_movimientos.cod_modalidad%TYPE,
                              p_cod_ente IN NUMBER, p_lisMenAcreditaciones IN OUT typ_lisMenAcreditaciones, p_retorno IN OUT typ_resAcreditaciones) IS
   
      v_menAcreditaciones typ_menAcreditaciones := typ_menAcreditaciones();
      r_gmovi             ge_movimientos%ROWTYPE;
      v_nro_secuencia     ge_movimientos.nro_secuencia%TYPE;
      v_est_cta_comb      ge_cuentas.estado%TYPE;
      v_tip_movimiento    VARCHAR2(1);
      v_cta_ent_gs    VARCHAR2(50) := nvl(fug_obt_parentes(p_cod_ente, G_CTA_TRA_ENT_GS), 0);
   
      /*Procedimiento para registrar movimientos*/
      PROCEDURE lp_ins_ge_movimiento IS
         v_ins_movimiento VARCHAR2(1) := 'N';
         v_can_intentos   NUMBER := 0;
         v_men_respuesta  VARCHAR2(4000);
         v_temp           TIMESTAMP;
      BEGIN
         WHILE v_ins_movimiento = 'N' AND v_can_intentos <= G_CAN_MAX_INT
         LOOP
            BEGIN
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, p_es_nocturno);
               v_ins_movimiento := 'S';
            EXCEPTION
               WHEN OTHERS THEN
                  v_temp           := pai_int.smg_sleep('0.5');
                  p_hora           := fug_obt_hor_disponible(p_fecha, r_gmovi.hora, p_cod_usuario, p_es_nocturno);
                  r_gmovi.hora     := p_hora;
                  v_ins_movimiento := 'N';
                  v_can_intentos   := v_can_intentos + 1;
                  v_men_respuesta  := substr(SQLERRM, 1, 4000);
            END;
         END LOOP;
         IF v_ins_movimiento = 'N' THEN
            --raise_application_error(-20000, v_men_respuesta);
            PAW_UTI.pr_mensajeUsuario(C_OTR_ERROR, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
            v_menAcreditaciones.code    := p_retorno.nombreRespuesta;
            v_menAcreditaciones.message := p_retorno.descripcionRespuesta;
            v_menAcreditaciones.type    := 'ERROR';
            p_lisMenAcreditaciones.extend;
            p_lisMenAcreditaciones(p_lisMenAcreditaciones.count) := v_menAcreditaciones;
            p_retorno.descripcionRespuesta := v_men_respuesta;
         END IF;
      END;
      --
   BEGIN
      v_nro_secuencia := 1;
      pag_cta.g_horario := p_horario;
      IF nvl(to_number(p_cta_debito), 0) != 0 OR nvl(p_ind_rub_debito, 'N') = 'S' THEN
         -- Carga los parametros de movimientos de Debito
         r_gmovi.cod_modulo    := p_mod_cta_deb;
         r_gmovi.cod_modalidad := p_mad_cta_deb;
         r_gmovi.cod_oficina   := nvl(p_ofi_cta_deb, p_ofi_origen);
         r_gmovi.nro_cuenta    := p_cta_debito;
         r_gmovi.cod_moneda    := nvl(p_mon_cta_deb, p_cod_moneda);
         r_gmovi.cod_usuario   := p_cod_usuario;
         r_gmovi.hora          := p_hora;
         r_gmovi.fecha         := p_fecha;
         r_gmovi.nro_secuencia := v_nro_secuencia;
         --
         r_gmovi.fec_valor     := p_fec_valor;
         r_gmovi.cod_tra_padre := p_cod_tra_padre;
         r_gmovi.cod_mod_padre := p_cod_modulo;
         r_gmovi.cod_mad_padre := p_cod_modalidad;
      
         IF p_ind_rub_debito = 'S' THEN
            r_gmovi.cod_transaccion := p_tra_con_debito;
            r_gmovi.tip_mov_rubro   := 'D';
            r_gmovi.cod_rubro       := p_cod_rub_debito;
         ELSE
            r_gmovi.cod_transaccion := 503;
            IF PAW_UTI.fu_exi_banco(p_bco_credito) = 'S' THEN
               r_gmovi.cod_banco := p_bco_credito;
               IF PAW_UTI.fu_exi_financiera(p_bco_credito) = 'S' THEN
                  r_gmovi.cod_banco := NULL;
               ELSE
                  r_gmovi.cod_banco := p_bco_credito;
               END IF;
            END IF;
         END IF;
      
         --r_gmovi.cod_banco       := p_bco_credito;
         --r_gmovi.cod_transaccion := 503;
         r_gmovi.monto          := p_imp_debito;
         r_gmovi.nro_documento  := p_nro_documento;
         r_gmovi.nro_documento2 := p_nro_documento2;
         r_gmovi.referencia     := p_cta_credito;
         r_gmovi.nro_documento3 := p_nro_documento3;
      
         r_gmovi.cod_tasa := NULL;
         r_gmovi.val_tasa := NULL;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion    := p_cot_debito;
         r_gmovi.mto_equ_local := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen := p_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := p_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         r_gmovi.cod_persona    := p_cod_persona;
      
         --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
         lp_ins_ge_movimiento;
         -- Para actualizacion en Batch del Saldo de la Cuenta Bancaria
         IF p_mad_cta_deb = G_MOD_BCO_PAIS or p_cta_debito = v_cta_ent_gs THEN
            v_tip_movimiento := 'D';
            pr_ins_bat_movimientos(r_gmovi, v_tip_movimiento);
         ELSE
            -- DDSI-300 -- 02/2018
            IF nvl(p_ind_rub_debito, 'N') = 'N' THEN
               v_tip_movimiento := 'D';
               PAG_CTA.PR_ACT_SAL_CTA(p_cta_debito, p_mad_cta_deb, v_tip_movimiento, p_fecha, p_hora, p_imp_debito, 0, 0, 'N');
            END IF;
            --   
         END IF;
      
         r_gmovi.tip_mov_rubro := NULL;
         r_gmovi.cod_rubro     := NULL;
      
         -- cuenta combinada ----------------------------------
         IF p_nro_cta_comb IS NOT NULL AND p_imp_debito > p_sal_dis_debito THEN
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            IF p_sal_dis_debito < 0 THEN
               r_gmovi.monto := p_imp_debito;
            ELSE
               r_gmovi.monto := p_imp_debito - p_sal_dis_debito;
            END IF;
            r_gmovi.concepto        := 'Transferencia de la Cta ' || p_nro_cta_comb;
            --r_gmovi.cod_tra_padre   := 309;
            r_gmovi.cod_transaccion := 602;
            ---
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            lp_ins_ge_movimiento;
            -- acreditar el monto que le falta
            -- DDSI-300 -- 02/2018
            IF nvl(p_ind_rub_debito, 'N') = 'N' THEN 
               v_tip_movimiento := 'C';
               PAG_CTA.PR_ACT_SAL_CTA(p_cta_debito, p_mad_cta_deb, v_tip_movimiento, p_fecha, p_hora, r_gmovi.monto, 0, 0, 'N');
            END IF;
            --
         END IF;
      
         IF p_est_cta_deb = 'I' THEN
            -- Debo cambiar el estado de la cuenta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := NULL;
            r_gmovi.est_cuenta      := 'N';
            --r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            lp_ins_ge_movimiento;
         END IF;
      
         IF p_nro_cta_comb IS NOT NULL AND p_imp_debito > p_sal_dis_debito THEN
            IF p_sal_dis_debito < 0 THEN
               r_gmovi.monto := p_imp_debito;
            ELSE
               r_gmovi.monto := p_imp_debito - p_sal_dis_debito;
            END IF;
            pag_cta.PR_OBT_CUENTA(p_nro_cta_comb);
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.concepto        := 'Transferencia a la Cta ' || p_cta_debito;
            --r_gmovi.cod_tra_padre   := 309;
            r_gmovi.cod_transaccion := 503;
            r_gmovi.cod_modulo      := pag_cta.g_ctas.cod_modulo;
            r_gmovi.cod_modalidad   := pag_cta.g_ctas.cod_modalidad;
            r_gmovi.cod_oficina     := pag_cta.g_ctas.cod_oficina;
            r_gmovi.nro_cuenta      := pag_cta.g_ctas.nro_cuenta;
            ---
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            lp_ins_ge_movimiento;
            -- DDSI-300 -- 02/2018
            IF nvl(p_ind_rub_debito, 'N') = 'N' THEN
               v_tip_movimiento := 'D';
               PAG_CTA.PR_ACT_SAL_CTA(pag_cta.g_ctas.nro_cuenta, pag_cta.g_ctas.cod_modalidad, v_tip_movimiento, p_fecha, p_hora, r_gmovi.monto , 0, 0, 'N');
            END IF;               
            --
            --FB AP 927 Actualizo el estado de la cta.comb.
            v_est_cta_comb := pag_cta.FU_OBT_EST_CUENTA;
            IF v_est_cta_comb = 'I' AND pag_cta.g_cod_error = 0 THEN
               v_nro_secuencia         := v_nro_secuencia + 1;
               r_gmovi.nro_secuencia   := v_nro_secuencia;
               r_gmovi.monto           := NULL;
               r_gmovi.est_cuenta      := 'N';
               --r_gmovi.cod_tra_padre   := 425;
               r_gmovi.cod_transaccion := 425;
               --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
               lp_ins_ge_movimiento;
            END IF;
            --
         END IF;
      END IF;
   
      IF nvl(to_number(p_cta_credito), 0) != 0 OR nvl(p_ind_rub_credito, 'N') = 'S' THEN
         -- Carga los parametros de movimientos de Credito
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.cod_modulo      := p_mod_cta_cre;
         r_gmovi.cod_modalidad   := p_mad_cta_cre;
         r_gmovi.cod_oficina     := nvl(p_ofi_cta_cre, p_ofi_origen);
         r_gmovi.nro_cuenta      := p_cta_credito;
         r_gmovi.cod_moneda      := nvl(p_mon_cta_cre, p_cod_moneda);
         r_gmovi.cod_usuario     := p_cod_usuario;
         r_gmovi.hora            := p_hora;
         r_gmovi.fecha           := p_fecha;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.fec_valor       := p_fec_valor;
         r_gmovi.cod_tra_padre   := p_cod_tra_padre;
         r_gmovi.cod_mod_padre   := p_cod_modulo;
         r_gmovi.cod_mad_padre   := p_cod_modalidad;
         r_gmovi.cod_transaccion := 602;
      
         --r_gmovi.cod_banco := p_bco_credito;
         IF PAW_UTI.fu_exi_banco(p_bco_credito) = 'S' THEN
            IF PAW_UTI.fu_exi_financiera(p_bco_credito) = 'S' THEN
               r_gmovi.cod_banco := NULL;
            ELSE
               r_gmovi.cod_banco := p_bco_credito;
            END IF;
         END IF;
      
         IF nvl(p_ind_rub_credito, 'N') = 'S' THEN
            r_gmovi.cod_transaccion := p_tra_con_credito;
            IF p_cod_rub_credito IS NOT NULL THEN
               r_gmovi.tip_mov_rubro := 'C';
               r_gmovi.cod_rubro     := p_cod_rub_credito;
            END IF;
            r_gmovi.cod_modulo    := p_mod_con_credito;
            r_gmovi.cod_modalidad := p_mad_con_credito;
            /*IF v_nro_cta_tarjeta IS NOT NULL THEN
               r_gmovi.cod_oficina := v_ofi_con_credito;
               r_gmovi.nro_cuenta  := v_nro_cta_tarjeta;
            END IF;*/
         END IF;
      
         r_gmovi.monto          := p_imp_credito;
         r_gmovi.nro_documento  := p_nro_documento;
         r_gmovi.nro_documento2 := p_nro_documento2;
         r_gmovi.nro_documento3 := p_nro_documento3;
      
         r_gmovi.cod_tasa := NULL;
         r_gmovi.val_tasa := NULL;
         -- tys: cotizacion de cambio
         r_gmovi.cotizacion    := p_cot_credito;
         r_gmovi.mto_equ_local := round(r_gmovi.monto * r_gmovi.cotizacion);
         --
         r_gmovi.cod_ofi_origen := p_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := p_concepto;
         r_gmovi.estado         := 'N';
         r_gmovi.reversado      := 'N';
         r_gmovi.cod_persona    := p_cod_persona;
      
         --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
         lp_ins_ge_movimiento;
         -- Para actualizacion en Batch del Saldo de la Cuenta Bancaria
         IF p_mad_cta_cre = G_MOD_BCO_PAIS or p_cta_credito = v_cta_ent_gs THEN
            v_tip_movimiento := 'C';
            pr_ins_bat_movimientos(r_gmovi, v_tip_movimiento);
         ELSE
            -- DDSI-300 -- 02/2018
            IF nvl(p_ind_rub_credito, 'N') = 'N' THEN
               v_tip_movimiento := 'C';
               PAG_CTA.PR_ACT_SAL_CTA(p_cta_credito, p_mad_cta_cre, v_tip_movimiento, p_fecha, p_hora, p_imp_credito, 0, 0, 'N');  
            END IF;
            --
         END IF;
      
         IF p_est_cta_cre = 'I' THEN
            -- Debo cambiar el estado de la cuenta
            v_nro_secuencia         := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia   := v_nro_secuencia;
            r_gmovi.monto           := NULL;
            r_gmovi.est_cuenta      := 'N';
            --r_gmovi.cod_tra_padre   := 425;
            r_gmovi.cod_transaccion := 425;
            --PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, v_es_nocturno);
            lp_ins_ge_movimiento;
         END IF;
      END IF;
   END pr_pro_operacion;

   /* Funcion para procesar Peticiones de Acreditaciones a Comercios */
   FUNCTION fu_acr_comercios(p_peticion IN typ_datosAcreditaciones, p_api_key IN VARCHAR2, p_ip_origen IN VARCHAR2) RETURN typ_resAcreditaciones IS
      -- Variables --
      v_retorno              typ_resAcreditaciones := typ_resAcreditaciones();
      v_men_respuesta        typ_MensajeRespuesta := typ_MensajeRespuesta();
      v_listaAcreditaciones  typ_listaAcreditaciones := typ_listaAcreditaciones();
      v_lisMenAcreditaciones typ_lisMenAcreditaciones := typ_lisMenAcreditaciones();
      v_datAcreditaciones    typ_datosAcreditaciones := typ_datosAcreditaciones();
      v_menAcreditaciones    typ_menAcreditaciones := typ_menAcreditaciones();
      v_mensaje              VARCHAR2(32767);
      v_error                VARCHAR2(32767);
      v_respuesta            VARCHAR2(200);
      v_datos                VARCHAR2(32767);
      v_cod_ente             NUMBER(5);
      v_fec_inicio           DATE;
      v_agregar              VARCHAR2(1000);
      v_est_modulo           ba_modulos.estado%TYPE;
      v_horario              VARCHAR2(1);
      v_es_nocturno          VARCHAR2(1);
      v_es_cta_noc           VARCHAR2(1);
      v_fec_actual           DATE;
      v_cod_ofi_origen       ba_oficinas.cod_oficina%TYPE;
      v_cta_bco_ente         ge_cuentas.nro_cuenta%TYPE;
      v_bco_ente             ge_bancos.cod_banco%TYPE;
      v_ind_rub_debito       VARCHAR2(1) := 'N';
      v_tra_con_debito       ge_movimientos.cod_transaccion%TYPE;
      v_mod_con_debito       ge_movimientos.cod_modulo%TYPE;
      v_mad_con_debito       ge_movimientos.cod_modalidad%TYPE;
      v_cod_rub_debito       ge_movimientos.cod_rubro%TYPE;
      v_nro_cta_fic_deb      VARCHAR2(20);
      v_nro_cta_cli_deb      VARCHAR2(20);
      v_ind_rub_credito      VARCHAR2(1) := 'N';
      v_tra_con_credito      ge_movimientos.cod_transaccion%TYPE;
      v_mod_con_credito      ge_movimientos.cod_modulo%TYPE;
      v_mad_con_credito      ge_movimientos.cod_modalidad%TYPE;
      v_cod_rub_credito      ge_movimientos.cod_rubro%TYPE;
      v_nro_cta_fic_cre      VARCHAR2(20);
      v_nro_cta_cli_cre      VARCHAR2(20);
      v_cta_debito           ge_cuentas.nro_cuenta%TYPE;
      v_cta_credito          ge_cuentas.nro_cuenta%TYPE;
      v_cod_tra_padre        ge_movimientos.cod_tra_padre%TYPE;
      v_mod_cta_deb          ge_movimientos.cod_modulo%TYPE;
      v_mad_cta_deb          ge_movimientos.cod_modalidad%TYPE;
      v_ofi_cta_deb          ge_movimientos.cod_oficina%TYPE;
      v_mon_cta_deb          ba_monedas.cod_moneda%TYPE;
      v_mod_cta_cre          ge_movimientos.cod_modulo%TYPE;
      v_mad_cta_cre          ge_movimientos.cod_modalidad%TYPE;
      v_ofi_cta_cre          ge_movimientos.cod_oficina%TYPE;
      v_mon_cta_cre          ba_monedas.cod_moneda%TYPE;
      v_cod_moneda           ba_monedas.cod_moneda%TYPE;
      v_importe              NUMBER(18, 2) := 0;
      v_imp_debito           NUMBER(18, 2);
      v_imp_credito          NUMBER(18, 2);
      v_cot_debito           ge_movimientos.cotizacion%TYPE;
      v_cot_credito          ge_movimientos.cotizacion%TYPE;
      v_cod_per_deb          ge_movimientos.cod_persona%TYPE;
      v_cod_per_cre          ge_movimientos.cod_persona%TYPE;
      v_nro_cta_comb         ge_cuentas.nro_cuenta%TYPE;
      v_est_cta_deb          ge_cuentas.estado%TYPE;
      v_est_cta_cre          ge_cuentas.estado%TYPE;
      v_sal_dis_deb          ah_cta_vistas.sal_total%TYPE;
      v_sal_dis_cre          ah_cta_vistas.sal_total%TYPE;
      -- Parametros      
      v_api_key         ge_par_entes.val_parametro%TYPE;
      v_ip_origen       ge_par_entes.val_parametro%TYPE;
      v_fec_transaccion DATE;
      r_gmov            ge_movimientos%ROWTYPE;
      r_gacc            ge_acr_comercios%ROWTYPE;
   
      /* Procedimiento para concatenar datos para ingresar como datos del LOG */
      PROCEDURE lp_act_datos(p_agregar IN VARCHAR2, p_datos IN OUT VARCHAR2) IS
      BEGIN
         IF p_datos IS NOT NULL THEN
            p_datos := p_datos || ', ' || p_agregar;
         ELSE
            p_datos := p_agregar;
         END IF;
      END;
      --
      /* Funcion para retornar mensaje en formato JSON a partir del TYPE typ_datosAcreditaciones*/
      FUNCTION lf_for_mensaje(p_datAcreditaciones typ_datosAcreditaciones) RETURN VARCHAR2 IS
         v_mensaje VARCHAR2(32767);
         v_json    PAW_JSON.JSONStructObj;
      BEGIN
         PAW_JSON.newJSONObj(v_json);
         v_json := PAW_JSON.addAttr(v_json, 'debitAccount', p_datAcreditaciones.cuentaDebito);
         v_json := PAW_JSON.addAttr(v_json, 'debitBank', to_char(p_datAcreditaciones.bancoDebito));
         v_json := PAW_JSON.addAttr(v_json, 'creditAccount', p_datAcreditaciones.cuentaCredito);
         v_json := PAW_JSON.addAttr(v_json, 'creditBank', p_datAcreditaciones.bancoCredito);
         v_json := PAW_JSON.addAttr(v_json, 'transactionType', p_datAcreditaciones.tipoTransaccion);
         v_json := PAW_JSON.addAttr(v_json, 'operationType', p_datAcreditaciones.tipoOperacion);
         v_json := PAW_JSON.addAttr(v_json, 'ticketNumber', p_datAcreditaciones.numeroBoleta);
         v_json := PAW_JSON.addAttr(v_json, 'transactionAmount', p_datAcreditaciones.montoTransaccion);
         v_json := PAW_JSON.addAttr(v_json, 'currencyCode', p_datAcreditaciones.Moneda);
         v_json := PAW_JSON.addAttr(v_json, 'commerceName', p_datAcreditaciones.nombreComercio);
         v_json := PAW_JSON.addAttr(v_json, 'transactionDate', p_datAcreditaciones.fechaTransaccion);
         v_json := PAW_JSON.addAttr(v_json, 'cardType', p_datAcreditaciones.tipoTarjeta);
         v_json := PAW_JSON.addAttr(v_json, 'lotNumber', p_datAcreditaciones.numeroLote);
         v_json := PAW_JSON.addAttr(v_json, 'revertTicketNumber', p_datAcreditaciones.numeroBoletaExtorno);
         PAW_JSON.closeJSONObj(v_json);
         v_mensaje := PAW_JSON.JSON2String(v_json);
         v_mensaje := REPLACE(v_mensaje, '''', '"');
         --PAW_JSON.print(PAW_JSON.JSON2String(v_json));
         --PAW_JSON.print(v_mensaje);
         RETURN v_mensaje;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END;
   BEGIN
      v_fec_inicio := SYSDATE; -- Para ver tiempo de procesamiento
      v_agregar    := 'ini: ' || to_char(v_fec_inicio, 'DD-MM-YYYY HH24:MI:SS');
      lp_act_datos(v_agregar, v_datos);
      v_retorno.error := 'N';
      v_agregar       := 'ope aprob';
      lp_act_datos(v_agregar, v_datos);
      PAW_UTI.pr_mensajeUsuario(C_OPE_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      v_agregar := 'resp: ' || v_retorno.nombreRespuesta;
      lp_act_datos(v_agregar, v_datos);
      IF NVL(v_retorno.error, 'N') = 'S' THEN
         v_error := v_retorno.descripcionRespuesta;
         v_menAcreditaciones.code    := v_retorno.nombreRespuesta;
         v_menAcreditaciones.message := v_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         v_lisMenAcreditaciones.extend;
         v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
         GOTO FIN;
      END IF;
   
      -- Peticion
      v_agregar := 'ver peticion';
      lp_act_datos(v_agregar, v_datos);
      v_datAcreditaciones := p_peticion;
      -- Parametros 
      v_api_key                               := TRIM(p_api_key);
      v_ip_origen                             := TRIM(p_ip_origen);
      v_datAcreditaciones.cuentaDebito        := PAW_UTI.depurarAlfanumerico(v_datAcreditaciones.cuentaDebito, 15);
      v_datAcreditaciones.bancoDebito         := PAW_UTI.depurarNumerico(v_datAcreditaciones.bancoDebito, 3);
      v_datAcreditaciones.cuentaCredito       := PAW_UTI.depurarAlfanumerico(v_datAcreditaciones.cuentaCredito, 15);
      v_datAcreditaciones.bancoCredito        := PAW_UTI.depurarNumerico(v_datAcreditaciones.bancoCredito, 3);
      v_datAcreditaciones.tipoTransaccion     := PAW_UTI.depurarAlfanumerico(v_datAcreditaciones.tipoTransaccion, 2); -- 00=COMPRA, 02=CONSULTA
      v_datAcreditaciones.tipoOperacion       := PAW_UTI.depurarAlfanumerico(v_datAcreditaciones.tipoOperacion, 2); -- 00=TRANSACCION, 99=EXTORNO
      v_datAcreditaciones.numeroBoleta        := PAW_UTI.depurarNumerico(v_datAcreditaciones.numeroBoleta, 15);
      v_datAcreditaciones.montoTransaccion    := PAW_UTI.depurarNumerico(v_datAcreditaciones.montoTransaccion, 18);
      v_datAcreditaciones.Moneda              := PAW_UTI.depurarAlfanumerico(v_datAcreditaciones.Moneda, 2);
      v_datAcreditaciones.nombreComercio      := TRIM(v_datAcreditaciones.nombreComercio);
      v_fec_transaccion                       := v_datAcreditaciones.fechaTransaccion;
      r_gmov.fec_valor                        := TRUNC(v_fec_transaccion);
      v_datAcreditaciones.tipoTarjeta         := PAW_UTI.depurarAlfanumerico(v_datAcreditaciones.tipoTarjeta, 2);
      v_datAcreditaciones.numeroLote          := PAW_UTI.depurarNumerico(v_datAcreditaciones.numeroLote, 18);
      v_datAcreditaciones.numeroBoletaExtorno := PAW_UTI.depurarNumerico(v_datAcreditaciones.numeroBoletaExtorno, 15);
      -- Asignar por defecto Transaccion 02=CONSULTA, Operacion 00=TRANSACCION
      v_datAcreditaciones.tipoTransaccion := NVL(v_datAcreditaciones.tipoTransaccion, 2);
      v_datAcreditaciones.tipoOperacion   := NVL(v_datAcreditaciones.tipoOperacion, 0);
      IF TO_NUMBER(v_datAcreditaciones.tipoOperacion) != 99 THEN
         v_datAcreditaciones.numeroBoletaExtorno := 0;
      END IF;
   
      -- Formato JSON Mensaje Recibido
      v_agregar := 'for mensaje';
      lp_act_datos(v_agregar, v_datos);
      v_mensaje := lf_for_mensaje(v_datAcreditaciones);
   
      -- Validar ApiKey/IP Origen - Obtener Codigo de Ente
      v_agregar := 'val ente';
      lp_act_datos(v_agregar, v_datos);
      pr_val_ente(v_api_key, v_ip_origen, v_cod_ente, v_men_respuesta);
      v_agregar := 'resp: ' || v_men_respuesta.nombreRespuesta;
      lp_act_datos(v_agregar, v_datos);
      IF NVL(v_men_respuesta.error, 'N') = 'S' THEN
         v_error := v_men_respuesta.descripcionRespuesta;
         PAW_UTI.pr_mensajeUsuario(C_OPE_NO_AUT, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         v_menAcreditaciones.code    := v_men_respuesta.nombreRespuesta;
         v_menAcreditaciones.message := v_men_respuesta.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         v_lisMenAcreditaciones.extend;
         v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
         GOTO FIN;
      END IF;
   
      -- Validaciones de parámetros recibidos
      v_agregar := 'val parametros';
      lp_act_datos(v_agregar, v_datos);
      pr_val_parametros(v_cod_ente, v_datAcreditaciones, v_lisMenAcreditaciones, v_retorno);
      v_agregar := 'resp: ' || v_retorno.nombreRespuesta;
      lp_act_datos(v_agregar, v_datos);
      IF NVL(v_retorno.error, 'N') = 'S' THEN
         v_error := v_retorno.descripcionRespuesta;
         GOTO FIN;
      END IF;
   
      -- Verifica Estado de módulo y horario.
      v_agregar := 'ver horario';
      lp_act_datos(v_agregar, v_datos);
      v_est_modulo    := pae_cnf.FU_OBT_EST_MODULO(3);
      v_men_respuesta := fu_ver_horario(v_horario, v_es_nocturno, v_es_cta_noc, v_cod_ofi_origen, v_fec_actual);
      v_agregar       := 'resp: ' || v_men_respuesta.nombreRespuesta;
      lp_act_datos(v_agregar, v_datos);
      IF NVL(v_men_respuesta.error, 'N') = 'S' THEN
         v_error := v_men_respuesta.descripcionRespuesta;
         -- Error en Verificación de Estado de Módulo y Horario.
         PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         v_menAcreditaciones.code    := v_men_respuesta.nombreRespuesta;
         v_menAcreditaciones.message := v_men_respuesta.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         v_lisMenAcreditaciones.extend;
         v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
         GOTO FIN;
      END IF;
   
      -- Validaciones iniciales
      v_agregar := 'val inicial';
      lp_act_datos(v_agregar, v_datos);
      pr_val_inicial(v_cod_ente, v_fec_actual, v_cod_moneda, v_cta_bco_ente, v_bco_ente, v_cod_tra_padre, v_ind_rub_debito, v_tra_con_debito,
                     v_tra_con_credito, v_mod_con_credito, v_mad_con_credito, v_cod_rub_credito, v_nro_cta_cli_cre, v_nro_cta_fic_cre, v_mod_con_debito,
                     v_mad_con_debito, v_cod_rub_debito, v_nro_cta_cli_deb, v_nro_cta_fic_deb, v_ind_rub_credito, v_datAcreditaciones,
                     v_lisMenAcreditaciones, v_retorno);
      v_agregar := 'resp: ' || v_retorno.nombreRespuesta;
      lp_act_datos(v_agregar, v_datos);
      IF NVL(v_retorno.error, 'N') = 'S' THEN
         v_error := v_lisMenAcreditaciones(1).message;
         GOTO FIN;
      END IF;
   
      -- Verificar Datos de la Transaccion
      IF TO_NUMBER(v_datAcreditaciones.tipoTransaccion) = 0 THEN
         v_agregar := 'datos trx';
         lp_act_datos(v_agregar, v_datos);
         r_gmov.fecha         := v_fec_actual;
         --r_gmov.fec_valor     := TRUNC(v_datAcreditaciones.fechaTransaccion);
         r_gmov.fec_valor     := v_fec_actual;
         r_gmov.cod_usuario   := G_COD_USUARIO;
         r_gmov.hora          := to_char(v_fec_transaccion, 'HH24:MI:SS');
         r_gmov.hora          := fug_obt_hor_disponible(r_gmov.fecha, r_gmov.hora, r_gmov.cod_usuario, v_es_nocturno);
         r_gmov.nro_documento := to_number(substr(lpad(to_char(v_datAcreditaciones.numeroBoleta), 15, '0'), -7));
         r_gmov.nro_documento3 := v_datAcreditaciones.numeroBoleta;
         r_gmov.cod_tra_padre  := v_cod_tra_padre;
         r_gmov.cod_mod_padre  := G_COD_MOD_PADRE;
         r_gmov.cod_mad_padre  := G_COD_MAD_PADRE;
         r_gmov.concepto       := v_datAcreditaciones.nombreComercio;
         v_importe             := v_datAcreditaciones.montoTransaccion;
         v_cta_debito          := v_datAcreditaciones.cuentaDebito;
         v_cta_credito         := v_datAcreditaciones.cuentaCredito;
      
         -- Cuenta Debito
         v_agregar := 'cta deb';
         lp_act_datos(v_agregar, v_datos);
         IF nvl(v_ind_rub_debito, 'N') = 'N' THEN
            v_agregar := 'dat cta';
            lp_act_datos(v_agregar, v_datos);
            pr_obt_dat_cuenta(v_cta_debito, v_mod_cta_deb, v_mad_cta_deb, v_ofi_cta_deb, v_mon_cta_deb, v_men_respuesta);
            v_agregar := 'resp: ' || v_men_respuesta.nombreRespuesta;
            lp_act_datos(v_agregar, v_datos);
            IF NVL(v_men_respuesta.error, 'N') = 'S' THEN
               PAW_UTI.pr_mensajeUsuario(C_DEB_INE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               v_menAcreditaciones.code    := v_retorno.nombreRespuesta;
               v_menAcreditaciones.message := v_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               v_lisMenAcreditaciones.extend;
               v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
            IF NVL(v_men_respuesta.error, 'N') = 'N' THEN
               IF v_mad_cta_deb NOT IN (42, 46, 49) THEN
                  IF PAG_CTA.FU_LLAVEAR_CUENTA(v_mad_cta_deb, v_cta_debito, v_es_cta_noc) = 'N' THEN
                     -- Error al realizar bloqueo de la Cuenta Débito.
                     PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     v_menAcreditaciones.code    := v_men_respuesta.nombreRespuesta;
                     v_menAcreditaciones.message := v_men_respuesta.descripcionRespuesta;
                     v_menAcreditaciones.type    := 'ERROR';
                     v_lisMenAcreditaciones.extend;
                     v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
                  END IF;
               END IF;
            ELSE
               -- Cuenta Débito no válida.
               PAW_UTI.pr_mensajeUsuario(C_CTA_DEB_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               v_menAcreditaciones.code    := v_men_respuesta.nombreRespuesta;
               v_menAcreditaciones.message := v_men_respuesta.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               v_lisMenAcreditaciones.extend;
               v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
         END IF;
      
         -- Cuenta Credito
         v_agregar := 'cta cred';
         lp_act_datos(v_agregar, v_datos);
         IF nvl(v_ind_rub_credito, 'N') = 'N' THEN
            v_agregar := 'dat cta';
            lp_act_datos(v_agregar, v_datos);
            pr_obt_dat_cuenta(v_cta_credito, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_cre, v_mon_cta_cre, v_men_respuesta);
            v_agregar := 'resp: ' || v_men_respuesta.nombreRespuesta;
            lp_act_datos(v_agregar, v_datos);
            IF NVL(v_men_respuesta.error, 'N') = 'S' THEN
               PAW_UTI.pr_mensajeUsuario(C_CRE_INE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               v_menAcreditaciones.code    := v_retorno.nombreRespuesta;
               v_menAcreditaciones.message := v_retorno.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               v_lisMenAcreditaciones.extend;
               v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
            IF NVL(v_men_respuesta.error, 'N') = 'N' THEN
               IF v_mad_cta_cre NOT IN (42, 46, 49) THEN
                  IF PAG_CTA.FU_LLAVEAR_CUENTA(v_mad_cta_cre, v_cta_credito, v_es_cta_noc) = 'N' THEN
                     -- Error al realizar bloqueo de la Cuenta Crédito.;
                     PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                     v_menAcreditaciones.code    := v_men_respuesta.nombreRespuesta;
                     v_menAcreditaciones.message := v_men_respuesta.descripcionRespuesta;
                     v_menAcreditaciones.type    := 'ERROR';
                     v_lisMenAcreditaciones.extend;
                     v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
                  END IF;
               END IF;
            ELSE
               -- Cuenta Credito no válida.
               PAW_UTI.pr_mensajeUsuario(C_CTA_CRE_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               v_menAcreditaciones.code    := v_men_respuesta.nombreRespuesta;
               v_menAcreditaciones.message := v_men_respuesta.descripcionRespuesta;
               v_menAcreditaciones.type    := 'ERROR';
               v_lisMenAcreditaciones.extend;
               v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
            END IF;
         END IF;
      
         -- Conversion de moneda --
         IF v_cod_moneda != v_mon_cta_deb THEN
            v_agregar := 'conv mon debito';
            lp_act_datos(v_agregar, v_datos);
            -- Código de moneda no corresponde al de la Cuenta Débito.
            -- si la moneda de la operacion es distinta a la moneda de la cuenta de debito
            -- realiza la conversión de monto credito -> debito. el importe de debito de estar nulo
            v_imp_debito  := NULL;
            v_imp_credito := v_importe;
            PAW_UTI.pr_con_mon_a_moneda(v_mon_cta_deb, v_cod_moneda, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
         END IF;
         IF v_imp_debito IS NULL THEN
            v_imp_debito := v_importe;
         END IF;
         IF v_mon_cta_cre != v_mon_cta_deb THEN
            v_agregar := 'conv mon debito';
            lp_act_datos(v_agregar, v_datos);
            -- realiza la conversion de monto debito -> credito
            PAW_UTI.pr_con_mon_a_moneda(v_mon_cta_deb, v_mon_cta_cre, v_imp_debito, v_imp_credito, v_cot_debito, v_cot_credito);
         END IF;
         IF v_imp_credito IS NULL THEN
            v_imp_credito := v_importe;
         END IF;
         IF NVL(v_retorno.error, 'N') = 'S' THEN
            v_error := v_retorno.descripcionRespuesta;
            -- Error Genérico de Operacion No Aprobada
            PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            v_retorno.error := 'S';
            GOTO FIN;
         END IF;
      END IF;
   
      -- Verifica Estado de módulo y horario.
      v_agregar := 'ver horario';
      lp_act_datos(v_agregar, v_datos);
      v_est_modulo    := pae_cnf.FU_OBT_EST_MODULO(3);
      v_men_respuesta := fu_ver_horario(v_horario, v_es_nocturno, v_es_cta_noc, v_cod_ofi_origen, v_fec_actual);
      v_agregar       := 'resp: ' || v_men_respuesta.nombreRespuesta;
      lp_act_datos(v_agregar, v_datos);
      IF NVL(v_men_respuesta.error, 'N') = 'S' THEN
         v_error := v_men_respuesta.descripcionRespuesta;
         -- Error en Verificación de Estado de Módulo y Horario. 
         PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         v_menAcreditaciones.code    := v_men_respuesta.nombreRespuesta;
         v_menAcreditaciones.message := v_men_respuesta.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         v_lisMenAcreditaciones.extend;
         v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
         GOTO FIN;
      END IF;
   
      -- Verificar la operacion
      IF TO_NUMBER(v_datAcreditaciones.tipoTransaccion) = 0 THEN
         v_agregar := 'ver operacion';
         lp_act_datos(v_agregar, v_datos);
         pr_ver_operacion(v_cta_debito, v_cta_credito, v_cod_tra_padre, G_COD_MOD_PADRE, G_COD_MAD_PADRE, v_mon_cta_deb, v_mon_cta_cre, v_imp_debito,
                          v_imp_credito, v_cod_ofi_origen, v_mod_cta_deb, v_mad_cta_deb, v_mod_cta_cre, v_mad_cta_cre, v_cod_per_deb, v_cod_per_cre,
                          v_nro_cta_comb, v_est_cta_deb, v_est_cta_cre, v_sal_dis_deb, v_sal_dis_cre, v_lisMenAcreditaciones, v_retorno);
         v_agregar := 'resp: ' || v_retorno.nombreRespuesta;
         lp_act_datos(v_agregar, v_datos);
         IF NVL(v_retorno.error, 'N') = 'S' THEN
            v_error := v_lisMenAcreditaciones(1).message;
            -- Error Genérico de Operacion No Aprobada
            PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            GOTO FIN;
         END IF;
      END IF;
   
      -- Procesar la operacion
      IF TO_NUMBER(v_datAcreditaciones.tipoTransaccion) = 0 THEN
         v_datAcreditaciones.numeroReferencia := fu_obt_sig_nro_referencia(v_fec_actual);
         r_gmov.nro_documento2                := v_datAcreditaciones.numeroReferencia;
         v_agregar                            := 'pro operacion';
         lp_act_datos(v_agregar, v_datos);
         pr_pro_operacion(v_cta_debito, v_cta_credito, v_datAcreditaciones.bancoCredito, v_nro_cta_comb, v_cod_per_deb, v_cod_tra_padre, v_mod_cta_deb,
                          v_mad_cta_deb, v_mod_cta_cre, v_mad_cta_cre, v_ofi_cta_deb, v_ofi_cta_cre, C_OFI_ORIGEN, v_mon_cta_deb, v_mon_cta_cre,
                          v_cod_moneda, v_est_cta_deb, v_est_cta_cre, v_sal_dis_deb, r_gmov.cod_usuario, r_gmov.hora, r_gmov.fecha, v_es_nocturno,
                          v_horario, r_gmov.concepto, r_gmov.cod_mod_padre, r_gmov.cod_mad_padre, r_gmov.fec_valor, v_imp_debito, v_imp_credito,
                          v_cot_debito, v_cot_credito, r_gmov.nro_documento, r_gmov.nro_documento2, r_gmov.nro_documento3, v_ind_rub_debito,
                          v_ind_rub_credito, v_tra_con_debito, v_tra_con_credito, v_cod_rub_debito, v_cod_rub_credito, v_mod_con_credito, v_mad_con_credito,
                          v_cod_ente, v_lisMenAcreditaciones, v_retorno);
         v_agregar := 'resp: ' || v_retorno.nombreRespuesta;
         lp_act_datos(v_agregar, v_datos);
         IF NVL(v_retorno.error, 'N') = 'S' THEN
            v_error := v_lisMenAcreditaciones(1).message;
            -- Error Genérico de Operacion No Aprobada
            PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            GOTO FIN;
         END IF;
      END IF;
   
      -- Registrar la Acreditacion
      IF TO_NUMBER(v_datAcreditaciones.tipoTransaccion) = 0 THEN
         v_agregar := 'reg acr';
         lp_act_datos(v_agregar, v_datos);
         r_gacc.nro_referencia  := v_datAcreditaciones.numeroReferencia;
         r_gacc.cod_ente        := v_cod_ente;
         r_gacc.nro_boleta      := v_datAcreditaciones.numeroBoleta;
         r_gacc.fec_movimiento  := r_gmov.fecha;
         r_gacc.hor_movimiento  := r_gmov.hora;
         r_gacc.fec_transaccion := v_datAcreditaciones.fechaTransaccion;
         r_gacc.hor_transaccion := to_char(r_gacc.fec_transaccion, 'HH24:MI:SS');
         r_gacc.tip_transaccion := v_datAcreditaciones.tipoTransaccion;
         r_gacc.tip_operacion   := v_datAcreditaciones.tipoOperacion;
         r_gacc.cta_debito      := v_datAcreditaciones.cuentaDebito;
         r_gacc.bco_debito      := v_datAcreditaciones.bancoDebito;
         r_gacc.cta_credito     := v_datAcreditaciones.cuentaCredito;
         r_gacc.bco_credito     := v_datAcreditaciones.bancoCredito;
         r_gacc.monto           := v_datAcreditaciones.montoTransaccion;
         r_gacc.moneda          := v_datAcreditaciones.Moneda;
         r_gacc.beneficiario    := v_datAcreditaciones.nombreComercio;
         r_gacc.tip_tarjeta     := v_datAcreditaciones.tipoTarjeta;
         r_gacc.nro_lote        := v_datAcreditaciones.numeroLote;
         r_gacc.nro_bol_extorno := v_datAcreditaciones.numeroBoletaExtorno;
         pr_ins_acr_comercios(r_gacc);
      END IF;
   
      -- Consultar Operacion
      IF TO_NUMBER(v_datAcreditaciones.tipoTransaccion) = 2 THEN
         r_gacc                                  := fu_obt_dat_boleta(v_datAcreditaciones.numeroBoleta, v_cod_ente);
         v_datAcreditaciones.cuentaDebito        := r_gacc.cta_debito;
         v_datAcreditaciones.bancoDebito         := r_gacc.bco_debito;
         v_datAcreditaciones.cuentaCredito       := r_gacc.cta_credito;
         v_datAcreditaciones.bancoCredito        := r_gacc.bco_credito;
         v_datAcreditaciones.tipoTransaccion     := r_gacc.tip_transaccion;
         v_datAcreditaciones.tipoOperacion       := r_gacc.tip_operacion;
         v_datAcreditaciones.numeroBoleta        := r_gacc.nro_boleta;
         v_datAcreditaciones.montoTransaccion    := r_gacc.monto;
         v_datAcreditaciones.moneda              := r_gacc.moneda;
         v_datAcreditaciones.nombreComercio      := r_gacc.beneficiario;
         v_datAcreditaciones.fechaTransaccion    := r_gacc.fec_transaccion;
         v_datAcreditaciones.tipoTarjeta         := r_gacc.tip_tarjeta;
         v_datAcreditaciones.numeroLote          := r_gacc.nro_lote;
         v_datAcreditaciones.numeroBoletaExtorno := r_gacc.nro_bol_extorno;
         v_datAcreditaciones.numeroReferencia    := r_gacc.nro_referencia;
      END IF;
   
      <<FIN>>
      v_agregar := 'error: ' || v_retorno.error;
      lp_act_datos(v_agregar, v_datos);
      IF NVL(v_retorno.error, 'N') = 'N' THEN
         v_listaAcreditaciones.extend;
         v_listaAcreditaciones(v_listaAcreditaciones.count) := v_datAcreditaciones;
         v_lisMenAcreditaciones := typ_lisMenAcreditaciones();
         v_respuesta := v_retorno.nombreRespuesta || ': ' || v_retorno.descripcionRespuesta || ', error: ' || v_retorno.error || ', nro_referencia: ' ||
                        v_datAcreditaciones.numeroReferencia;
      ELSE
         v_error := nvl(v_error,v_retorno.descripcionRespuesta);
         v_datAcreditaciones.numeroReferencia := NULL;
         v_listaAcreditaciones                := typ_listaAcreditaciones();
         v_respuesta                          := v_retorno.nombreRespuesta || ': ' || v_retorno.descripcionRespuesta || ', error: ' || v_retorno.error;
         ROLLBACK;
      END IF;
      v_retorno.listaDatosAcreditaciones    := v_listaAcreditaciones;
      v_retorno.listaMensajesAcreditaciones := v_lisMenAcreditaciones;
      v_agregar                             := 'resp: ' || v_retorno.nombreRespuesta;
      lp_act_datos(v_agregar, v_datos);
      v_agregar := 'fin: ' || to_char(SYSDATE, 'DD-MM-YYYY HH24:MI:SS');
      lp_act_datos(v_agregar, v_datos);
      pr_ins_log(v_mensaje, v_respuesta, v_datos, v_cod_ente, v_fec_inicio, v_error);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         v_error := substr(SQLERRM, 1, 4000);
         ROLLBACK;
         v_agregar := 'ver otro error';
         lp_act_datos(v_agregar, v_datos);
         PAW_UTI.pr_mensajeUsuario(C_OTR_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         v_agregar := 'resp: ' || v_retorno.nombreRespuesta;
         lp_act_datos(v_agregar, v_retorno.descripcionRespuesta);
         v_lisMenAcreditaciones      := typ_lisMenAcreditaciones();
         v_menAcreditaciones.code    := v_retorno.nombreRespuesta;
         v_menAcreditaciones.message := v_retorno.descripcionRespuesta;
         v_menAcreditaciones.type    := 'ERROR';
         v_lisMenAcreditaciones.extend;
         v_lisMenAcreditaciones(v_lisMenAcreditaciones.count) := v_menAcreditaciones;
         -- Error genérico de Operacion No Aprobada
         v_agregar := 'ope no apr';
         lp_act_datos(v_agregar, v_datos);
         PAW_UTI.pr_mensajeUsuario(C_OPE_NO_APR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         v_agregar := 'resp: ' || v_retorno.nombreRespuesta;
         lp_act_datos(v_agregar, v_retorno.descripcionRespuesta);
         v_listaAcreditaciones                 := typ_listaAcreditaciones();
         v_retorno.listaDatosAcreditaciones    := v_listaAcreditaciones;
         v_retorno.listaMensajesAcreditaciones := v_lisMenAcreditaciones;
         v_respuesta                           := v_retorno.nombreRespuesta || ' : ' || v_retorno.descripcionRespuesta;
         v_agregar                             := 'fin: ' || to_char(SYSDATE, 'DD-MM-YYYY HH:MI:SS');
         lp_act_datos(v_agregar, v_datos);
         pr_ins_log(v_mensaje, v_respuesta, v_datos, v_cod_ente, v_fec_inicio, v_error);
         RETURN v_retorno;
   END;

   /* Funcion para Consultar Peticiones de Acreditaciones a Comercios */
   FUNCTION fu_con_acr_comercios(p_nro_boleta IN NUMBER, p_api_key IN VARCHAR2, p_ip_origen IN VARCHAR2) RETURN typ_resAcreditaciones IS
      -- Variables --
      v_retorno  typ_resAcreditaciones := typ_resAcreditaciones();
      v_peticion typ_datosacreditaciones := typ_datosacreditaciones();
   BEGIN
      v_peticion.tipoTransaccion := '02'; -- 02=CONSULTA
      v_peticion.tipoOperacion   := '00'; -- 00=TRANSACCION
      v_peticion.numeroBoleta    := p_nro_boleta;
      v_retorno                  := fu_acr_comercios(v_peticion, p_api_key, p_ip_origen);
      RETURN v_retorno;
   END;

--inicializacion del paquete
BEGIN
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja
END PAG_PAC;
/

