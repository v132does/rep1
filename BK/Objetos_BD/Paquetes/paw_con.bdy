CREATE OR REPLACE PACKAGE BODY IT.paw_con IS

   FUNCTION fu_encriptacionCuentas(p_clave IN VARCHAR2) RETURN VARCHAR2 IS
      v_cadena        CHAR(16) := '39z06x8w74y25v1-';
      v_secuencia     CHAR(12) := '892804697513';
      v_base          NUMBER(02) := 3;
      v_log_cadena    NUMBER(02);
      v_indice        NUMBER(02);
      v_caracter      CHAR(01);
      v_cad_final     VARCHAR2(12);
      v_cad_retorno   VARCHAR2(16);
      v_cad_origen    VARCHAR2(12);
      v_letra         NUMBER(2);
      v_val_secuencia NUMBER(2);
      v_nvo_valor     NUMBER(2);
      v_longitud      NUMBER(2);
      v_nuevo         VARCHAR2(12);

   BEGIN

      v_nuevo      := SUBSTR(lpad(p_clave, 16, '-'), 1, 12);
      v_cad_origen := v_nuevo;
      v_cad_final  := NULL;
      v_log_cadena := LENGTH(v_cadena);
      v_indice     := LENGTH(v_secuencia);
      v_longitud   := LENGTH(v_cad_origen);
      LOOP
         v_caracter      := SUBSTR(v_cad_origen, v_longitud, 1); -- Determina caracter
         v_letra         := INSTR(v_cadena, v_caracter) - 1; -- v_nvo_valor numerico del caracter
         v_val_secuencia := TO_NUMBER(SUBSTR(v_secuencia, v_indice, 1)); -- v_nvo_valor de la secuencia
         v_nvo_valor     := v_letra + v_val_secuencia + v_base; -- Nvo. valor de la letra
         v_nvo_valor     := MOD(v_nvo_valor, v_log_cadena);
         v_base          := NVL(v_nvo_valor, 0);
         IF NVL(v_nvo_valor, 0) = 0 THEN
            v_nvo_valor := v_log_cadena;
         END IF;
         IF v_cad_final IS NULL THEN
            v_cad_final := SUBSTR(v_cadena, v_nvo_valor, 1);
         ELSE
            v_cad_final := SUBSTR(v_cadena, v_nvo_valor, 1) || v_cad_final;
         END IF;
         v_longitud := v_longitud - 1;
         v_indice   := v_indice - 1;
         IF v_indice < 1 THEN
            v_indice := LENGTH(v_secuencia);
         END IF;
         EXIT WHEN v_longitud = 0;
      END LOOP;

      IF LENGTH(p_clave) < 4 THEN
         v_cad_retorno := v_cad_final || lpad(p_clave, 4, '*');
      ELSE
         v_cad_retorno := v_cad_final || SUBSTR(p_clave, LENGTH(p_clave) - 3, 4);

      END IF;

      RETURN v_cad_retorno;

   END;

   FUNCTION fu_desencriptacionCuentas(p_clave IN VARCHAR2) RETURN VARCHAR2 IS

      v_cadena        CHAR(16) := '39z06x8w74y25v1-';
      v_secuencia     CHAR(12) := '892804697513';
      v_caracter      CHAR(01);
      v_sig_letra     VARCHAR2(02);
      v_cad_final     VARCHAR(12);
      v_cad_retorno   VARCHAR(16);
      v_log_cadena    NUMBER(02);
      v_indice        NUMBER(02);
      v_aux_letra     NUMBER(02);
      v_letra         NUMBER(2);
      v_val_secuencia NUMBER(2);
      v_nvo_valor     NUMBER(2);
      v_longitud      NUMBER(2) := 1;
      v_aux_valor     NUMBER(2);
      v_sig_valor     NUMBER(2);
      v_clave         VARCHAR2(12);
      v_sub_cadena    VARCHAR2(4);

   BEGIN

      IF INSTR(p_clave, '*') > 0 THEN
         v_sub_cadena := SUBSTR(p_clave, INSTR(p_clave, '*'));

         v_cad_retorno := REPLACE(v_sub_cadena, '*', '');
         RETURN v_cad_retorno;

      END IF;

      v_cad_final  := NULL;
      v_log_cadena := LENGTH(v_cadena);
      v_indice     := LENGTH(v_secuencia);

      v_clave     := SUBSTR(lpad(p_clave, 16, '-'), 1, 12);
      v_aux_letra := LENGTH(v_clave);
      IF v_aux_letra < v_indice + 1 THEN
         v_indice := (v_indice - v_aux_letra) + 1;
      ELSE
         v_aux_valor := MOD(v_aux_letra, v_indice);
         v_indice    := (v_indice - v_aux_valor) + 1;
         IF v_indice > LENGTH(v_secuencia) THEN
            v_indice := 1;
         END IF;
      END IF;
      LOOP
         v_caracter      := SUBSTR(v_clave, v_longitud, 1); -- Ubicar v_caracter
         v_letra         := INSTR(v_cadena, v_caracter); -- v_nvo_valor de la letra
         v_val_secuencia := TO_NUMBER(SUBSTR(v_secuencia, v_indice, 1)); -- Numero en la secuencia
         IF v_longitud = v_aux_letra THEN
            v_sig_valor := 3;
         ELSE
            v_sig_letra := SUBSTR(v_clave, v_longitud + 1, 1); -- sgte. letra
            v_sig_valor := INSTR(v_cadena, v_sig_letra); -- valor sgte. letra
         END IF;
         v_nvo_valor := v_letra - (v_sig_valor + v_val_secuencia - 1); --obtener nuevo valor
         IF v_nvo_valor = 0 THEN
            v_nvo_valor := v_log_cadena;
         ELSE
            LOOP
               EXIT WHEN v_nvo_valor >= 1;
               v_nvo_valor := v_nvo_valor + v_log_cadena;
            END LOOP;
         END IF;
         IF v_cad_final IS NULL THEN
            v_cad_final := SUBSTR(v_cadena, v_nvo_valor, 1);
         ELSE
            v_cad_final := v_cad_final || SUBSTR(v_cadena, v_nvo_valor, 1);
         END IF;
         v_longitud := v_longitud + 1;
         v_indice   := v_indice + 1;
         IF v_indice > LENGTH(v_secuencia) THEN
            v_indice := 1;
         END IF;
         EXIT WHEN v_longitud >= v_aux_letra + 1;
      END LOOP;

      v_cad_retorno := v_cad_final || SUBSTR(p_clave, LENGTH(p_clave) - 3, 4);

      v_cad_retorno := REPLACE(v_cad_retorno, '-');

      RETURN v_cad_retorno;

   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0;
   END;

   FUNCTION fu_generarBitacora
   (
      error                IN VARCHAR2,
      nombreRespuesta      IN VARCHAR2,
      descripcionRespuesta IN VARCHAR2,
      mensajesAdicionales  IN VARCHAR2 := NULL
   ) RETURN VARCHAR2 IS
      v_linea    VARCHAR2(1000);
      v_paquete  VARCHAR2(1000);
      v_llamador VARCHAR2(1000);
      v_duenho   VARCHAR2(1000);
   BEGIN
      OWA_UTIL.WHO_CALLED_ME(v_duenho, v_paquete, v_linea, v_llamador);
      RETURN v_paquete || '.' || v_linea || sys_context('USERENV', 'ACTION') || ' Userid:' || sys_context('USERENV', 'SESSION_USER') || ' Ip:' || sys_context('USERENV', 'IP_ADDRESS') || ' isDBA:' || sys_context('USERENV', 'ISDBA') || ' Error:' ||(CASE error WHEN 'S' THEN 'T' WHEN 'N' THEN 'F' END) || ' nombreRespuesta:' || nombreRespuesta || ' descripcionRespuesta:' || descripcionRespuesta;
   END;

   FUNCTION fu_obt_permisos
   (
      p_cod_persona   IN VARCHAR2,
      p_cod_perfil    IN VARCHAR2,
      p_cod_operacion IN VARCHAR2,
      p_nro_terminal  IN VARCHAR2
   ) RETURN typ_obtenerPermisos IS
      v_retorno  typ_obtenerPermisos;
      v_consulta VARCHAR(5);
      v_registra VARCHAR(5);
      v_autoriza VARCHAR(5);
      c_msg_op_no_permitida CONSTANT VARCHAR2(15) := '135';
      c_msg_sal_per_sin_aut CONSTANT VARCHAR2(15) := '280';
   BEGIN
      SELECT TRIM(decode(consulta, 'S', 'C', '') || decode(ingresa, 'S', 'I', '') || decode(autoriza, 'S', 'A', ''))
        INTO v_tip_mensaje
        FROM bw_tip_mensajes
       WHERE cod_tip_mensaje = p_cod_operacion;
      BEGIN
         pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- busco primero especifico para la empresa
         SELECT decode(consulta, 'S', 'TRUE', 'FALSE'), decode(ingresa, 'S', 'TRUE', 'FALSE'), decode(autoriza, 'S', 'TRUE', 'FALSE'), nvl(can_firmas, 0)
           INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
           FROM bw_rol_permisos
          WHERE cod_perfil = p_cod_perfil
            AND cod_tip_mensaje = p_cod_operacion
            AND cod_persona = p_cod_persona;
      EXCEPTION
         WHEN no_data_found THEN
            BEGIN
               -- busco los permisos generales para el perfil
               SELECT decode(consulta, 'S', 'TRUE', 'FALSE'), decode(ingresa, 'S', 'TRUE', 'FALSE'), decode(autoriza, 'S', 'TRUE', 'FALSE'), nvl(can_firmas, 0)
                 INTO v_consulta, v_registra, v_autoriza, v_can_aut_requeridas
                 FROM bw_rol_permisos
                WHERE cod_perfil = p_cod_perfil
                  AND cod_tip_mensaje = p_cod_operacion
                  AND cod_persona IS NULL;
            EXCEPTION
               WHEN no_data_found THEN
                  pr_mensajeUsuario(c_msg_sal_per_sin_aut, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
                  pr_insertarBitacora(p_cod_persona, p_nro_terminal, NULL, p_cod_operacion, NULL, 'Operacion no permitida-', BITACORA_ERROR);
            END;
      END;
      IF v_can_aut_requeridas > 0 AND p_nro_terminal != C_COD_HOMEBANKING THEN
         -- operacion no permitida en autoservicios por requerir autorizacion
         pr_mensajeUsuario(c_msg_op_no_permitida, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora(p_cod_persona, p_nro_terminal, NULL, p_cod_operacion, NULL, 'Operacion no permitida-', BITACORA_ERROR);
      END IF;
      v_retorno.autoriza                 := (v_autoriza = 'TRUE');
      v_retorno.consulta                 := (v_consulta = 'TRUE');
      v_retorno.registra                 := (v_registra = 'TRUE');
      v_retorno.autorizacionesRequeridas := v_can_aut_requeridas;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN v_retorno;
   END;

   /** Inserta registro en la tabla bw_bitacoras
   * @param p_codigoPersona Código de persona
   * @param p_codigoCanal Código de canal
   * @param p_codSesion Código de la sesión
   * @param p_tipoMensaje Tipo de mensaje
   * @param p_codigoEmpresa Código de la persona vinculada
   * @param p_datos Información de lo realizado
   * @param p_tipo Tipo de la bitácora
   */
   PROCEDURE pr_insertarBitacora
   (
      p_codigoPersona       IN VARCHAR2 DEFAULT NULL,
      p_codigoCanal         IN VARCHAR2 DEFAULT NULL,
      p_codSesion           IN VARCHAR2 DEFAULT NULL,
      p_tipoMensaje         IN VARCHAR2 DEFAULT NULL,
      p_codigoEmpresa       IN VARCHAR2 DEFAULT NULL,
      p_datos               IN VARCHAR2 DEFAULT NULL,
      p_tipo                IN VARCHAR2 DEFAULT NULL,
      p_numeroTelefono      IN VARCHAR2 DEFAULT NULL,
      p_codigoError         IN VARCHAR2 DEFAULT NULL,
      p_observacion         IN VARCHAR2 DEFAULT NULL,
      p_codigoMotivo        IN VARCHAR2 DEFAULT NULL,
      p_numeroCuentaDebito  IN VARCHAR2 DEFAULT NULL,
      p_numeroCuentaCredito IN VARCHAR2 DEFAULT NULL,
      p_monto               IN NUMBER DEFAULT NULL,
      p_codigoMoneda        IN VARCHAR2 DEFAULT NULL,
      p_dato2               IN CLOB DEFAULT NULL
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      INSERT INTO bw_bitacoras
         (COD_PERSONA, COD_CANAL, COD_SESION, COD_TIP_MENSAJE, COD_PER_VINCULADA, DATO, TIPO, DATO2)
      VALUES
         (p_codigoPersona, p_codigoCanal, p_codSesion, p_tipoMensaje, p_codigoEmpresa, SUBSTR(p_datos, 1, 4000), p_tipo, p_dato2);

      IF p_tipo = BITACORA_ERROR AND p_observacion IS NOT NULL THEN
         INSERT INTO bw_log_incidencias
            (nro_telefono, cod_error, usu_insercion, fec_insercion, observacion, nro_caja, cod_tip_mensaje, cod_persona, nro_cta_debito, nro_cta_credito, monto, cod_moneda, cod_motivo)
         VALUES
            (p_numeroTelefono, p_codigoError, USER, SYSDATE, p_observacion, p_codigoCanal, p_tipoMensaje, p_codigoPersona, p_numeroCuentaDebito, p_numeroCuentaCredito, p_monto, p_codigoMoneda, p_codigoMotivo);
      END IF;

      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   FUNCTION depurarAlfanumerico
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2 IS
   BEGIN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:]])', ''), 1, maxLength);
   END;
   FUNCTION depurarTextos
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2 IS
   BEGIN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:][:space:][:punct:]])', ''), 1, maxLength);
   END;
   FUNCTION depurarNumerico
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2 IS
   BEGIN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:digit:].,])', ''), 1, maxLength);
   END;

   FUNCTION depurarCaracter
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2 IS
   BEGIN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:]])', ''), 1, maxLength);
   END;

   FUNCTION depurarCuenta
   (
      p_string  IN VARCHAR2,
      maxLength IN NUMBER
   ) RETURN VARCHAR2 IS
   BEGIN
      RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^[:alnum:][:space:]])', ''), 1, maxLength);
   END;

   FUNCTION fu_for_date(p_dato IN DATE) RETURN CHAR IS
   BEGIN
      RETURN nvl(to_char(p_dato, 'ddmmyyyy'), ' ');
   END;
   /** Determina si la cuenta es una Cuenta Conjunta
   */
   FUNCTION fu_es_conjunta
   (
      p_nro_cuenta      IN VARCHAR2,
      p_cod_persona     IN VARCHAR2,
      p_cod_per_empresa IN VARCHAR2
   ) RETURN VARCHAR2 IS
      v_can_conjunta NUMBER;
   BEGIN
      IF p_cod_per_empresa IS NOT NULL THEN
         RETURN 'N';
      END IF;
      -- veo si la cuenta no es conjunta
      SELECT COUNT(*)
        INTO v_can_conjunta
        FROM ge_cta_clientes
       WHERE nro_cuenta = p_nro_cuenta
         AND relacion = 'Y'
         AND rownum = 1;

      IF nvl(v_can_conjunta, 0) > 0 AND nvl(v_can_aut_requeridas, 0) = 0 THEN
         -- nueva condicion 17-01-2010
         /* no requiere autorizacion y la cuenta es conjunta, no debe acceder*/

         /*nueva condicion 17-01-2010
         Cuando una persona esta com ofirmante 'indistinta' de la cuenta, aunque existan
         otros firmantes que esten definidas como 'conjunta', permitir debitar  cuentas
         donde la persona este con regimen 'indistinto'.*/
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   /** Determina si la persona es una persona Juridica
   */
   FUNCTION fu_es_juridica
   (
      p_nro_cuenta      IN VARCHAR2,
      p_cod_per_empresa IN VARCHAR2,
      p_cod_persona     IN VARCHAR2
   ) RETURN VARCHAR2 IS
      v_cod_principal ba_personas.cod_persona%TYPE;
   BEGIN
      --- Obtengo el principal.
      SELECT cod_persona
        INTO v_cod_principal
        FROM ge_cta_clientes
       WHERE nro_cuenta = p_nro_cuenta
         AND relacion = 'P';
      --
      IF pag_gen.fu_es_per_fisica(v_cod_principal) = 'N' AND nvl(p_cod_per_empresa, p_cod_persona) != v_cod_principal THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   FUNCTION fu_es_ope_limitadas
   (
      p_cod_mensaje IN VARCHAR2,
      p_nro_cuenta  IN VARCHAR2,
      p_cod_canal   IN VARCHAR2,
      p_fecha       IN DATE
   ) RETURN VARCHAR2 IS
      v_lim_det     bw_limites.mto_maximo%TYPE;

   BEGIN

      v_lim_det := 0;

      -- solo graba en BW_OPE_LIMITADAS si el mensaje está limitado en BW_LIMITES_DET
      SELECT d.mto_mensaje
        INTO v_lim_det
        FROM bw_limites l, bw_limites_det d
       WHERE l.cod_canal = p_cod_canal
         AND l.fec_inicio <= p_fecha
         AND l.cod_moneda = c_cod_mon_fuerte
         AND l.nro_secuencia = d.nro_secuencia
         AND d.cod_tip_mensaje = p_cod_mensaje
         AND (l.nro_cuenta = p_nro_cuenta OR l.nro_cuenta IS NULL)
         AND (l.fec_vencimiento >= p_fecha OR l.fec_vencimiento IS NULL)
         AND rownum = 1;

      IF nvl(v_lim_det, 0) > 0 THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;

   EXCEPTION
      WHEN no_data_found THEN
         RETURN 'N';
      WHEN OTHERS THEN
         RETURN 'S';

   END;

   /** Setea el campo error y limpia el código del cliente y nombre
   */
   FUNCTION fu_setearError(v_retorno IN OUT typ_iniciarSesion) RETURN typ_iniciarSesion IS

   BEGIN
      v_retorno.codigoCliente  := NULL;
      v_retorno.nombreCompleto := NULL;
      v_retorno.nombreEmpresa  := NULL;
      v_retorno.codigoEmpresa  := NULL;
      v_retorno.error          := 'S';
      RETURN v_retorno;
   END;

   -- Verifica si no sobrepasa el límite de operaciones por día y semana.
   FUNCTION fu_val_monto
   (
      p_monto       IN NUMBER,
      p_cod_moneda  IN VARCHAR2,
      p_cod_mensaje IN VARCHAR2,
      p_nro_cuenta  IN VARCHAR2,
      p_cod_canal   IN VARCHAR2,
      p_fec_actual  IN DATE
   ) RETURN VARCHAR2 IS
      v_lim_cab        bw_limites.mto_maximo%TYPE;
      v_lim_det        bw_limites.mto_maximo%TYPE;
      v_cod_mon_fuerte ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_fuerte;
      v_dias           bw_limites.dias%TYPE;
      v_mto_cab        bw_limites.mto_maximo%TYPE;
      v_mto_det        bw_limites.mto_maximo%TYPE;
      v_control        bw_limites.dias%TYPE;
      v_nro_secuencia  bw_limites.nro_secuencia%TYPE;
      v_fec_servidor   DATE := trunc(SYSDATE);

      CURSOR c_limites IS
         SELECT l.mto_maximo, l.dias, l.nro_secuencia
           FROM bw_limites l
          WHERE l.cod_canal = p_cod_canal
            AND l.fec_inicio <= p_fec_actual
            AND l.cod_moneda = v_cod_mon_fuerte
            AND (l.nro_cuenta = p_nro_cuenta OR l.nro_cuenta IS NULL)
            AND (l.fec_vencimiento >= v_fec_actual OR l.fec_vencimiento IS NULL)
          ORDER BY l.nro_cuenta ASC, l.fec_inicio DESC, l.dias ASC;

      CURSOR c_limites_det IS
         SELECT d.mto_mensaje
           FROM bw_limites l, bw_limites_det d
          WHERE l.cod_canal = p_cod_canal
            AND l.fec_inicio <= p_fec_actual
            AND l.cod_moneda = v_cod_mon_fuerte
            AND l.nro_secuencia = d.nro_secuencia
            AND l.nro_secuencia = v_nro_secuencia
            AND d.cod_tip_mensaje = p_cod_mensaje
            AND (l.nro_cuenta = p_nro_cuenta OR l.nro_cuenta IS NULL)
            AND (l.fec_vencimiento >= p_fec_actual OR l.fec_vencimiento IS NULL)
          ORDER BY l.nro_cuenta ASC, l.fec_inicio DESC;

   BEGIN
      v_control := NULL;
      FOR i IN c_limites LOOP

         IF v_control = i.dias THEN
            GOTO siguiente_registro;
         ELSE
            v_control := i.dias;
         END IF;

         v_lim_cab       := i.mto_maximo;
         v_lim_det       := 0;
         v_mto_cab       := 0;
         v_mto_det       := 0;
         v_dias          := i.dias - 1;
         v_nro_secuencia := i.nro_secuencia;

         BEGIN
            SELECT SUM(nvl(a.monto, 0))
              INTO v_mto_cab
              FROM bw_ope_limitadas a
             WHERE a.cod_canal = p_cod_canal
               AND a.nro_cuenta = p_nro_cuenta
               AND trunc(a.fec_insercion) BETWEEN v_fec_servidor - v_dias AND v_fec_servidor;
         EXCEPTION
            WHEN OTHERS THEN
               -- SDC v_cod_respuesta := v_cod_otr_error;
               RETURN 'N';
         END;

         IF v_lim_cab > 0 AND v_lim_cab < nvl(v_mto_cab, 0) + nvl(p_monto, 0) THEN
            RETURN 'N';
         END IF;

         IF p_cod_mensaje IS NOT NULL THEN
            IF c_limites_det%ISOPEN THEN
               CLOSE c_limites_det;
            END IF;
            OPEN c_limites_det;
            FETCH c_limites_det
               INTO v_lim_det;
            CLOSE c_limites_det;
            BEGIN
               SELECT SUM(nvl(a.monto, 0))
                 INTO v_mto_det
                 FROM bw_ope_limitadas a
                WHERE a.cod_canal = p_cod_canal
                  AND a.nro_cuenta = p_nro_cuenta
                  AND a.cod_tip_mensaje = p_cod_mensaje
                  AND trunc(a.fec_insercion) BETWEEN v_fec_servidor - v_dias AND v_fec_servidor;
            EXCEPTION
               WHEN OTHERS THEN
                  -- SDC v_cod_respuesta := v_cod_otr_error;
                  RETURN 'N';
            END;
            IF nvl(v_lim_det, 0) > 0 AND v_lim_det < nvl(v_mto_det, 0) + nvl(p_monto, 0) THEN
               RETURN 'N';
            END IF;
         END IF;
         <<siguiente_registro>>
         NULL;
      END LOOP;
      RETURN 'S';
   END;

   FUNCTION fu_obt_cta_tarjeta
   (
      p_nro_cta_especifica VARCHAR2,
      p_cod_per_empresa    VARCHAR2,
      p_cod_persona        VARCHAR2
   ) RETURN VARCHAR2 IS
      v_nro_cta_especifica VARCHAR2(30) := REPLACE(REPLACE(REPLACE(TRIM(p_nro_cta_especifica), '.', '-'), ' ', '-'), '/', '-');
   BEGIN
      IF length(v_nro_cta_especifica) = 16 THEN
         -- es un tarjeta de credito, busco y reemplazo el dato
         BEGIN
            SELECT a.nro_cuenta
              INTO v_nro_cta_especifica
              FROM ge_cta_clientes a, ta_tarjetas b
             WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
               AND b.nro_cuenta = a.nro_cuenta
               AND a.cod_persona = nvl(p_cod_per_empresa, p_cod_persona);
         EXCEPTION
            WHEN no_data_found THEN
               SELECT b.nro_cuenta
                 INTO v_nro_cta_especifica
                 FROM ta_tarjetas b
                WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
                  AND vigente = 'S'
                  AND rownum = 1;
         END;
      END IF;
      RETURN v_nro_cta_especifica;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   /* Función que devuelve si una cuenta tiene o no cheque devuelto
   */
   FUNCTION fu_obt_che_devuelto(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
      v_cantidad NUMBER;
   BEGIN
      SELECT COUNT(*)
        INTO v_cantidad
        FROM ge_movimientos
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_mod_padre = 4
         AND cod_mad_padre = 41
         AND cod_tra_padre = 321
         AND cod_transaccion IN (522, 503, 182)
         AND reversado = 'N'
         AND estado = 'N'
         AND rownum = 1;
      IF v_cantidad > 0 THEN
         RETURN 'S';
      ELSE
         RETURN 'N';
      END IF;
   END;

   /** Devuelve la moneda de una cuenta
   */
   FUNCTION fu_obt_moneda(p_nro_cuenta IN VARCHAR2) RETURN VARCHAR2 IS
      v_retorno VARCHAR2(3);
   BEGIN
      SELECT cod_moneda
        INTO v_retorno
        FROM ge_cuentas
       WHERE nro_cuenta = p_nro_cuenta
         AND rownum = 1;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   /** Devuelve el numero de tarjeta de credito de la Persona o Cuenta
   */
   FUNCTION fu_obt_nro_tarjeta
   (
      p_numeroCuenta    IN VARCHAR2,
      p_cod_persona     IN VARCHAR2,
      p_cod_per_empresa IN VARCHAR2
   ) RETURN VARCHAR2 IS
      v_retorno VARCHAR2(20);
   BEGIN
      SELECT nro_tarjeta
        INTO v_retorno
        FROM ta_tarjetas
       WHERE nro_cuenta = p_numeroCuenta
         AND vigente = 'S'
         AND cod_persona = nvl(p_cod_per_empresa, p_cod_persona)
         AND rownum = 1;
      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         -- puede ser tarjeta empresa
         SELECT MAX(nro_tarjeta)
           INTO v_retorno
           FROM ta_tarjetas
          WHERE nro_cuenta = p_numeroCuenta
            AND vigente = 'S';
         RETURN v_retorno;
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   --recibe la clave en minusculas y hasheada en md5 recupera el salt del usuario y verifica que la clave sea igual a la guardada
   FUNCTION fu_val_ope_clave
   (
      p_clave             IN VARCHAR2,
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2,
      p_act_visitas       IN VARCHAR2 DEFAULT 'N'
   ) RETURN typ_mensajeRespuesta IS
      MSG_CLA_OPE_ESTADO   CONSTANT VARCHAR2(15) := 'CLA_OPE_ESTADO';
      MSG_CLA_OPE_INTENTOS CONSTANT VARCHAR2(15) := 'CLA_OPE_INTENTO';
      MSG_CLA_OPE_CAMBIAR  CONSTANT VARCHAR2(15) := 'CLA_OPE_CAMBIAR';
      MSG_CLA_OPE_INVALIDA CONSTANT VARCHAR2(15) := 'CLA_OPE_INVALID';
      MSG_CLA_ACC_CAMBIAR  CONSTANT VARCHAR2(15) := 'CLA_ACC_CAMBIAR';
      MSG_CLA_ACC_ESTADO   CONSTANT VARCHAR2(15) := 'CLA_ACC_ESTADO';
      MSG_CLA_ACC_INTENTOS CONSTANT VARCHAR2(15) := 'CLA_ACC_INTENTO';
      MSG_CLA_INT_INVALIDO CONSTANT VARCHAR2(15) := '268';

      v_salt         NUMBER;
      v_clave        VARCHAR(300);
      v_estado       VARCHAR(1);
      v_can_errores  NUMBER(2);
      v_max_intentos NUMBER;
      v_retorno      typ_mensajeRespuesta := typ_mensajeRespuesta;
      --Verifica que la clave si tiene mas de 3 intentos fallidos pase a estado B
      PROCEDURE pr_blo_clave
      (
         p_cod_persona       IN VARCHAR2,
         p_cod_per_vinculada IN VARCHAR2,
         p_tip_clave         IN VARCHAR2
      ) IS
         PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
         --v_can_intentos NUMBER;
      BEGIN
         UPDATE bw_ope_claves
            SET est_clave     = 'B',
                fec_est_clave = SYSDATE
          WHERE cod_persona = p_cod_persona
            AND est_clave IN ('A', 'M') -- se bloquea solo si esta para cambiar o modificado
            AND can_intentos >= v_max_intentos
            AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
            AND tip_clave = p_tip_clave;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
      --registra que cuando ocurrio un error en el uso de la clave
      --para validar que no se ingrese mal la clave muy rapido
      PROCEDURE pr_reg_error
      (
         p_cod_persona       IN VARCHAR2,
         p_cod_per_vinculada IN VARCHAR2,
         p_tip_clave         IN VARCHAR2
      ) IS
         PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      BEGIN
         UPDATE bw_ope_claves
            SET fec_ult_error = SYSDATE,
                can_intentos  = nvl(can_intentos, 0) + 1
          WHERE cod_persona = p_cod_persona
            AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
            AND tip_clave = p_tip_clave;
         COMMIT;
         pr_blo_clave(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      --actualiza el ultimo acceso realizado, en caso de que la clave sea la correcta
      --reinicia el contados de intentos fallidos a 0
      PROCEDURE lp_act_visitas
      (
         p_cod_persona       IN VARCHAR2,
         p_cod_per_vinculada IN VARCHAR2,
         p_tip_clave         IN VARCHAR2
      ) IS
         PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      BEGIN
         UPDATE bw_ope_claves
            SET can_acceso     = can_acceso + 1,
                can_intentos   = 0,
                fec_ult_acceso = SYSDATE
          WHERE cod_persona = p_cod_persona
            AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
            AND tip_clave = p_tip_clave;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            -- por si bw_ope_claves.can_acceso llego a su tope, se reinicia
            UPDATE bw_ope_claves
               SET can_acceso     = 0,
                   can_intentos   = 0,
                   fec_ult_acceso = SYSDATE
             WHERE cod_persona = p_cod_persona
               AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
               AND tip_clave = p_tip_clave;
            COMMIT;
      END;
   BEGIN

      BEGIN
         -- obtiene el salt y el estado
         SELECT cla_verificador, est_clave, can_intentos
           INTO v_salt, v_estado, v_can_errores
           FROM bw_ope_claves
          WHERE cod_persona = p_cod_persona
            AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
            AND tip_clave = p_tip_clave;
      EXCEPTION
         WHEN too_many_rows THEN
            -- RETURN - 1;
            pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

            RETURN v_retorno;
         WHEN no_data_found THEN
            pr_reg_error(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
            -- RETURN - 2;
            pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
      END;

      paw_con.pr_act_est_ope_clave(p_cod_persona, p_cod_per_vinculada, p_tip_clave, C_COD_HOMEBANKING);

      --v_clave := v_salt || '|' || p_clave;
      --v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
      v_clave := p_clave;
      -- obtenemos la máxima cantidad de intentos de uso de claves
      BEGIN
         IF p_tip_clave = 'T' THEN
            -- máxima cantidad para clave transaccional
            v_max_intentos := to_number(fug_obt_pardinamico('BWE_CAN_INT_CLA_TRANSACCIONAL'));
         ELSE
            -- máxima cantidad para clave de acceso
            v_max_intentos := to_number(fug_obt_pardinamico('BWE_CAN_INT_CLA_ACCESO'));
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            IF p_tip_clave = 'T' THEN
               v_max_intentos := 3;
            ELSE
               v_max_intentos := 5;
            END IF;
      END;
      -- se controla el valor de v_max_intentos
      IF v_max_intentos IS NULL THEN
         v_max_intentos := 5;
      END IF;

      IF v_can_errores >= v_max_intentos THEN
         pr_reg_error(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
         -- v_cod_respuesta:=PAW_BCE.v_cla_ope_intentos;
         -- return paw_bce.v_cla_ope_intentos;
         IF v_estado IN ('A', 'M', 'B') THEN
            pr_mensajeUsuario(MSG_CLA_OPE_INTENTOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         ELSE
            pr_mensajeUsuario(MSG_CLA_OPE_ESTADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         END IF;
         RETURN v_retorno;
      END IF;
      BEGIN
         SELECT cla_verificador, est_clave
           INTO v_salt, v_estado
           FROM bw_ope_claves
          WHERE cod_persona = p_cod_persona
            AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
            AND clave = v_clave
            AND tip_clave = p_tip_clave;
         --La clave tiene que estar activa
         IF v_estado <> 'M' THEN
            IF v_estado = 'A' AND nvl(P_TIP_CLAVE, 'X') = 'T' THEN
               pr_mensajeUsuario(MSG_CLA_OPE_CAMBIAR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;
            ELSIF v_estado = 'B' AND nvl(P_TIP_CLAVE, 'X') = 'T' THEN
               pr_mensajeUsuario(MSG_CLA_OPE_INTENTOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;
            ELSIF nvl(P_TIP_CLAVE, 'X') = 'T' THEN
               pr_mensajeUsuario(MSG_CLA_OPE_ESTADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;

            ELSIF v_estado = 'A' AND nvl(P_TIP_CLAVE, 'X') = 'A' THEN

               pr_mensajeUsuario(MSG_CLA_ACC_CAMBIAR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;

            ELSIF v_estado = 'B' AND nvl(P_TIP_CLAVE, 'X') = 'A' THEN

               pr_mensajeUsuario(MSG_CLA_ACC_INTENTOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;

            ELSIF nvl(P_TIP_CLAVE, 'X') = 'A' THEN
               pr_mensajeUsuario(MSG_CLA_ACC_ESTADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;

            END IF;
         END IF;

      EXCEPTION
         WHEN too_many_rows THEN
            -- RETURN - 3;
            pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
         WHEN no_data_found THEN
            pr_reg_error(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
            IF (v_max_intentos - v_can_errores) = 1 THEN
               pr_mensajeUsuario(MSG_CLA_INT_INVALIDO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            ELSE
               pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            END IF;
            RETURN v_retorno;

      END;
      IF p_act_visitas = 'S' THEN
         lp_act_visitas(p_cod_persona, p_cod_per_vinculada, p_tip_clave);
      END IF;
      -- v_cod_respuesta:=v_cod_aprobado;
      pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      RETURN v_retorno;
      -- RETURN 0;
   END;

   -- lp_con_mon_a_moneda
   PROCEDURE pr_con_mon_a_moneda
   (
      p_cod_mon_original IN ba_monedas.cod_moneda%TYPE,
      p_cod_mon_destino  IN ba_monedas.cod_moneda%TYPE,
      p_mto_mon_original IN NUMBER,
      p_mto_mon_destino  OUT NUMBER,
      p_cot_mon_original IN OUT NUMBER,
      p_cot_mon_destino  IN OUT NUMBER,
      p_interbancaria    IN VARCHAR2 DEFAULT NULL
   ) IS
      v_lugar VARCHAR2(100);
   BEGIN
      IF p_cot_mon_original <= 0 THEN
         p_cot_mon_original := NULL;
      END IF;
      IF p_cot_mon_destino <= 0 THEN
         p_cot_mon_destino := NULL;
      END IF;
      v_lugar := 'obtener moneda base';
      IF p_cod_mon_original = p_cod_mon_destino THEN
         p_mto_mon_destino := p_mto_mon_original;
         IF p_cod_mon_original <> v_cod_mon_local THEN
            p_cot_mon_destino  := nvl(p_cot_mon_original, pag_gen.fu_obt_cotizacion(p_cod_mon_original));
            p_cot_mon_original := p_cot_mon_destino;
         ELSE
            p_cot_mon_destino  := 1;
            p_cot_mon_original := 1;
         END IF;
      ELSE
         IF nvl(p_interbancaria, 'N') = 'N' THEN
            IF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino = v_cod_mon_local THEN
               --convertir moneda original a base o destino
               p_cot_mon_original := nvl(p_cot_mon_original, fuw_obt_cotizacion(p_cod_mon_original, 'C' /*COMPRA*/, v_fec_actual));
               p_cot_mon_destino  := 1;
               p_mto_mon_destino  := round(p_mto_mon_original * p_cot_mon_original, 0);
            ELSIF p_cod_mon_original = v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               -- pasar moneda original a moneda base
               p_cot_mon_original := 1;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, fuw_obt_cotizacion(p_cod_mon_destino, 'V' /*VENTA */, v_fec_actual));
               p_mto_mon_destino  := round(p_mto_mon_original / p_cot_mon_destino, 2);
            ELSIF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               p_cot_mon_original := nvl(p_cot_mon_original, fuw_obt_cotizacion(p_cod_mon_original, 'C' /*COMPRA*/, v_fec_actual));
               p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, fuw_obt_cotizacion(p_cod_mon_destino, 'V' /*VENTA */, v_fec_actual));
               p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino, 2);
            END IF;
         ELSE
            IF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino = v_cod_mon_local THEN
               --convertir moneda original a base o destino
               p_cot_mon_original := nvl(p_cot_mon_original, fuw_obt_cotizacion(p_cod_mon_original, 'V' /*VENTA*/, v_fec_actual));
               p_cot_mon_destino  := 1;
               p_mto_mon_destino  := round(p_mto_mon_original * p_cot_mon_original, 0);
            ELSIF p_cod_mon_original = v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               -- pasar moneda original a moneda base
               p_cot_mon_original := 1;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, fuw_obt_cotizacion(p_cod_mon_destino, 'C' /*COMPRA*/, v_fec_actual));
               p_mto_mon_destino  := round(p_mto_mon_original / p_cot_mon_destino, 2);
            ELSIF p_cod_mon_original <> v_cod_mon_local AND p_cod_mon_destino <> v_cod_mon_local THEN
               p_cot_mon_original := nvl(p_cot_mon_original, fuw_obt_cotizacion(p_cod_mon_original, 'V' /*VENTA*/, v_fec_actual));
               p_mto_mon_destino  := p_mto_mon_original * p_cot_mon_original;
               p_cot_mon_destino  := nvl(p_cot_mon_destino, fuw_obt_cotizacion(p_cod_mon_destino, 'C' /*COMPRA*/, v_fec_actual));
               p_mto_mon_destino  := round(p_mto_mon_destino / p_cot_mon_destino, 2);
            END IF;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_lugar || ' - ' || SQLERRM);
   END;

   --Verifica que la clave transaccional sea la correcta
   --hace un substr desde p_ini_ope_clave-1 hasta p_ini_ope_clave+31
   FUNCTION fu_obt_cla_validar
   (
      p_cla_transaccional IN VARCHAR2,
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2
   ) RETURN typ_mensajeRespuesta IS
   BEGIN
      RETURN FU_VAL_OPE_CLAVE(p_cla_transaccional, p_cod_persona, p_cod_per_vinculada, p_tip_clave, 'S');
   END;

   /**Inserta registro en bw_movimientos
   * @param p_nro_cuenta Nro de cuenta
   * @param p_cod_moneda Código de moneda
   * @param p_monto monto
   * @param p_nro_cta_contra Nro de cuenta
   * @param p_cantidad Cantidad
   * @param p_etiqueta Etiqueta
   * @param p_dato Dato
   * @param p_etiqueta2 Etiqueta2
   * @param p_dato2 Dato2
   * @param p_observacion Observación
   * @param p_dir_ip Dirección ip
   * @param p_cod_respuesta Codigo de respuesta
   * @param p_cod_persona Codigo de persona
   * @param p_cod_operacion Codigo de operación
   * @param p_nro_operacion Nro de operación
   * @param p_nro_terminal Nro de terminal
   * @param p_clave Clave
   * @param p_cod_per_empresa Código de empresa
   */
   PROCEDURE pr_reg_operacion
   (
      p_nro_cuenta      IN VARCHAR2 DEFAULT NULL,
      p_cod_moneda      IN VARCHAR2 DEFAULT NULL,
      p_monto           IN NUMBER DEFAULT NULL,
      p_nro_cta_contra  IN VARCHAR2 DEFAULT NULL,
      p_cantidad        IN NUMBER DEFAULT NULL,
      p_etiqueta        IN VARCHAR2 DEFAULT NULL,
      p_dato            IN VARCHAR2 DEFAULT NULL,
      p_etiqueta2       IN VARCHAR2 DEFAULT NULL,
      p_dato2           IN VARCHAR2 DEFAULT NULL,
      p_observacion     IN VARCHAR2 DEFAULT NULL,
      p_dir_ip          IN VARCHAR2 DEFAULT NULL,
      p_cod_respuesta   IN VARCHAR2 DEFAULT NULL,
      p_cod_persona     IN VARCHAR2 DEFAULT NULL,
      p_cod_operacion   IN VARCHAR2 DEFAULT NULL,
      p_nro_operacion   IN VARCHAR2 DEFAULT NULL,
      p_nro_terminal    IN VARCHAR2 DEFAULT NULL,
      p_clave           IN VARCHAR2 DEFAULT NULL,
      p_cod_per_empresa IN VARCHAR2 DEFAULT NULL,
      p_nro_sobre       IN VARCHAR2 DEFAULT NULL
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
     v_hor_actual       VARCHAR2(08) := to_char(sysdate, 'HH24:MI:SS'); -- Hora actual
     v_fec_actual       VARCHAR2(15) := pag_cal.fu_obt_fec_actual(9);
     v_fec_hora         DATE;
   BEGIN
      v_fec_hora := TO_DATE(v_fec_actual||' '||v_hor_actual,'DD/MM/RRRR HH24:MI:SS');
      INSERT INTO bw_movimientos
         (nro_documento, cod_per_principal, cod_per_ingreso, clave, fec_hora, nro_caja, cod_tip_mensaje, dir_ip, cod_respuesta, observacion, nro_cuenta, cod_moneda, monto, nro_cta_contra, cantidad, etiqueta, dato, etiqueta2, dato2,parametros)
      VALUES
         (p_nro_operacion, nvl(p_cod_per_empresa, p_cod_persona), p_cod_persona, substr(p_clave, 1, 20), v_fec_hora, p_nro_terminal, p_cod_operacion, p_dir_ip, '000', p_observacion, substr(REPLACE(TRIM(p_nro_cuenta), chr(13), ''), 0, 15), p_cod_moneda, p_monto, substr(REPLACE(TRIM(p_nro_cta_contra), chr(13), ''), 0, 15), p_cantidad, p_etiqueta, p_dato, p_etiqueta2, p_dato2, p_nro_sobre);
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('ERROR AL INSERTAR BW_MOVMIENTOS '|| SQLERRM);
   END;

   --Verifica los ultimos accesos de las claves y actualiza el estado de la misma
   PROCEDURE pr_act_est_ope_clave
   (
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2,
      p_cod_canal         IN VARCHAR2
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_ope_cam_cambio NUMBER(10);
      v_ope_cam_uso    NUMBER(10);
   BEGIN
      --Si no exite el parametro dinamico, toma 90 dias
      BEGIN
         IF p_tip_clave = 'T' THEN
            -- frecuencia de cambio para clave transaccional
            v_ope_cam_cambio := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_CAMBIO', 1));
         ELSE
            -- frecuencia de cambio para clave de acceso
            v_ope_cam_cambio := TO_NUMBER(fug_obt_pardinamico('FRE_CAM_CLA_ACCESO_HB'));
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_ope_cam_cambio := 90;
      END;
      -- controlamos el valor de v_ope_cam_cambio
      IF v_ope_cam_cambio IS NULL THEN
         v_ope_cam_cambio := 90;
      END IF;
      -- Si no existe el paramtro dinamico toma 45
      BEGIN
         IF p_tip_clave = 'T' THEN
            -- frecuencia de cambio para clave transaccional
            v_ope_cam_uso := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_USO', 1));
         ELSE
            -- frecuencia de cambio para clave de acceso
            v_ope_cam_uso := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_USO_ACCESO'));
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_ope_cam_uso := 45;
      END;
      -- controlamos el valor de v_ope_cam_uso
      IF v_ope_cam_uso IS NULL THEN
         v_ope_cam_uso := 45;
      END IF;

      BEGIN
         --exige el cambio a las claves que no se usaron en un tiempo
         -- segun OPE_CAM_USO(transaccional) o OPE_CAM_USO_ACCESO(acceso) días
         UPDATE bw_ope_claves
            SET est_clave     = 'A',
                fec_est_clave = SYSDATE,
                cod_canal     = p_cod_canal
          WHERE cod_persona = p_cod_persona
            AND tip_clave = p_tip_clave
            AND est_clave NOT IN ('X', 'I', 'B') -- no cambiar si el estado es anulada, impresa o bloqueada
            AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
            AND (fec_ult_acceso IS NULL OR SYSDATE - fec_ult_acceso > v_ope_cam_uso);
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      BEGIN
         --Exigir el cambio de clave a los que cambiaron hace
         -- FRE_CAM_CLA_ACCESO_HB(Acceso) o OPE_CAM_CAMBIO(Transaccional) días
         UPDATE bw_ope_claves
            SET est_clave     = 'A',
                fec_est_clave = SYSDATE
          WHERE cod_persona = p_cod_persona
            AND est_clave = 'M'
            AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
            AND tip_clave = p_tip_clave
            AND SYSDATE - FEC_CAM_CLAVE > v_ope_cam_cambio;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
   END;

   -- Registro las operaciones que superaron el limite
   PROCEDURE pr_reg_error
   (
      p_cta_debito   IN VARCHAR2,
      p_cta_credito  IN VARCHAR2,
      p_monto        IN NUMBER,
      p_cod_moneda   IN VARCHAR2,
      p_cod_mensaje  IN VARCHAR2,
      p_cod_error    IN VARCHAR2,
      p_cod_motivo   IN VARCHAR2,
      p_comentario   IN VARCHAR2,
      p_nro_telefono IN VARCHAR2,
      p_cod_canal    IN VARCHAR2,
      p_cod_persona  IN VARCHAR2
   ) IS

      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
   BEGIN
      INSERT INTO bw_log_incidencias
         (nro_telefono, cod_error, usu_insercion, fec_insercion, observacion, nro_caja, cod_tip_mensaje, cod_persona, nro_cta_debito, nro_cta_credito, monto, cod_moneda, cod_motivo)
      VALUES
         (p_nro_telefono, p_cod_error, USER, SYSDATE, p_comentario, p_cod_canal, p_cod_mensaje, p_cod_persona, p_cta_debito, p_cta_credito, p_monto, p_cod_moneda, p_cod_motivo);
      COMMIT;

   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   --Verifica los ultimos accesos de las claves y actualiza el estado de la misma
   PROCEDURE lp_act_est_ope_clave
   (
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      v_ope_cam_cambio NUMBER(3);
      v_ope_cam_uso    NUMBER(3);
   BEGIN
      --Si no exite el parametro dinamico, toma 90 dias
      BEGIN
         v_ope_cam_cambio := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_CAMBIO', 1));
      EXCEPTION
         WHEN OTHERS THEN
            v_ope_cam_cambio := 90;
      END;
      -- Si no existe el paramtro dinmico toma 45
      BEGIN
         v_ope_cam_uso := TO_NUMBER(fug_obt_pardinamico('OPE_CAM_USO', 1));
      EXCEPTION
         WHEN OTHERS THEN
            v_ope_cam_uso := 45;
      END;

      BEGIN
         --exige el cambio a las claves que no se usaron en un tiempo
         IF p_cod_per_vinculada IS NULL THEN
            UPDATE bw_ope_claves
               SET est_clave     = 'A',
                   fec_est_clave = SYSDATE
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada IS NULL
               AND SYSDATE - fec_ult_acceso > v_ope_cam_uso;
         ELSE
            UPDATE bw_ope_claves
               SET est_clave     = 'A',
                   fec_est_clave = SYSDATE
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada = p_cod_per_vinculada
               AND SYSDATE - FEC_ULT_ACCESO > v_ope_cam_uso;
         END IF;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      BEGIN
         --Exigir el cambio de clave a los que cambiaron hace v_ope_cam_activacion dias
         IF p_cod_per_vinculada IS NULL THEN
            UPDATE bw_ope_claves
               SET est_clave     = 'A',
                   fec_est_clave = SYSDATE
             WHERE cod_persona = p_cod_persona
               AND est_clave = 'M'
               AND cod_per_vinculada IS NULL
               AND SYSDATE - FEC_CAM_CLAVE > v_ope_cam_cambio;
         ELSE
            UPDATE bw_ope_claves
               SET est_clave     = 'A',
                   fec_est_clave = SYSDATE
             WHERE cod_persona = p_cod_persona
               AND est_clave = 'M'
               AND cod_per_vinculada = p_cod_per_vinculada
               AND SYSDATE - FEC_CAM_CLAVE > v_ope_cam_cambio;
         END IF;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
   END;

   /** Obtiene un mensaje de la base de datos por el nombre del mensaje
   * @param p_mensaje Nombre del mensaje
   * @return p_nombreMensaje Nombre del mensaje
   * @return p_descripcionMensaje Descripción del mensaje
   * @return p_error Indicador de si es o no un mensaje de error
   */
   PROCEDURE pr_mensajeUsuario
   (
      mensaje            IN VARCHAR2,
      codigoMensaje      OUT VARCHAR2,
      descripcionMensaje OUT VARCHAR2,
      error              OUT VARCHAR2
   ) IS
      v_error VARCHAR2(1);
   BEGIN
      BEGIN
         SELECT a.nombre, a.des_mensaje, a.error
           INTO codigoMensaje, descripcionMensaje, v_error
           FROM bw_men_respuestas a
          WHERE a.nombre = mensaje;
      EXCEPTION
         WHEN no_data_found THEN
            descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado';
         WHEN OTHERS THEN
            descripcionMensaje := 'No pudo recuperar el key de mensaje solicitado';
      END;
      error := v_error;
   END;

   PROCEDURE pr_can_reg_historicos
   (
      p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
      p_fecha      IN ge_movimientos.fecha%TYPE,
      p_horario    OUT VARCHAR2
   ) IS
      v_lugar         VARCHAR2(100);
      v_can_registros NUMBER(5) := 99;
   BEGIN
      v_lugar := 'obtener cantidad de registros historicos';
      BEGIN
         SELECT 1
           INTO v_can_registros
           FROM cc_movimientos_his h
          WHERE h.fecha = p_fecha
            AND h.nro_cuenta = p_nro_cuenta
            AND rownum = 1
         UNION
         SELECT 1
           FROM ah_movimientos_his h
          WHERE h.fecha = p_fecha
            AND h.nro_cuenta = p_nro_cuenta
            AND rownum = 1;
      EXCEPTION
         WHEN no_data_found THEN
            v_can_registros := 0;
      END;
      IF v_can_registros = 0 THEN
         p_horario := 'D';
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, v_lugar || ' - ' || SQLERRM);
   END;
   -- genera movimientos en movimientos
   PROCEDURE pr_ins_movimiento
   (
      p_retorno           IN OUT typ_mensajerespuesta, -- agregado
      p_nro_secuencia     IN OUT NUMBER, -- agregado
      p_ses_usuario       IN typ_validarSesion, -- agregado
      p_men_caja          IN typ_mensajeCaja, -- agregado
      p_fec_actual        IN DATE, -- agregado
      p_hor_actual        IN VARCHAR2, -- agregado
      p_fec_valor         IN DATE, -- agregado
      p_cod_mod_cta       IN NUMBER,
      p_cod_mad_cta       IN NUMBER,
      p_cod_ofi_cta       IN NUMBER,
      p_nro_cuenta        IN VARCHAR2,
      p_cod_moneda        IN VARCHAR2,
      p_cod_tra_padre     IN NUMBER,
      p_cod_transaccion   IN NUMBER,
      p_nro_documento     IN NUMBER,
      p_monto             IN NUMBER,
      p_cod_operacion     IN VARCHAR2,
      p_nro_documento2    IN VARCHAR2,
      p_afe_caja          IN VARCHAR2 DEFAULT 'N', -- E-efectivo C-Cheq.Ntro.bco O-Cheq.otro.bco N-no afecta
      p_es_mov_noc        IN VARCHAR2 DEFAULT NULL,
      p_cod_retencion     IN NUMBER DEFAULT NULL,
      p_fec_fin_retencion IN DATE DEFAULT NULL,
      p_concepto          IN VARCHAR2 DEFAULT NULL,
      p_cotizacion        IN NUMBER DEFAULT NULL,
      p_cod_mod_padre     IN NUMBER DEFAULT NULL,
      p_cod_mad_padre     IN NUMBER DEFAULT NULL,
      p_val_tasa          IN NUMBER DEFAULT NULL,
      p_tipo_movimiento   IN VARCHAR2 DEFAULT NULL,
      p_cod_rubro         IN VARCHAR2 DEFAULT NULL
   )

    IS
      r_gmovi           ge_movimientos%ROWTYPE;
      v_can_movimientos NUMBER(8) := 0;
      cod_ped_duplicado CONSTANT VARCHAR2(15) := 'G_COD_MOV_DUPLI';
      v_ins_movimiento  varchar2(1) := 'N';
      v_can_intentos    number := 1;
      v_err_movimiento  varchar2(300);
      v_hor_actual ge_movimientos.hora%type := p_hor_actual;
      v_estado   VARCHAR2(1);
      v_tip_monto VARCHAR2(1);

   BEGIN
   --el formulario toma v_tip_monto y en cheques otros bancos es diferente y no muestra el monto

      -- veo posible duplicacion de nros de boleta
      BEGIN
         IF p_es_mov_noc = 'S' THEN
            SELECT COUNT(*)
              INTO v_can_movimientos
              FROM ge_movimientos_noc
             WHERE nro_cuenta = p_nro_cuenta
               AND cod_transaccion = p_cod_transaccion
               AND nro_documento = p_nro_documento
               AND cod_retencion = p_cod_retencion
               AND rownum = 1;
         ELSE
            SELECT COUNT(*)
              INTO v_can_movimientos
              FROM ge_movimientos
             WHERE nro_cuenta = p_nro_cuenta
               AND cod_transaccion = p_cod_transaccion
               AND nro_documento = p_nro_documento
               AND cod_retencion = p_cod_retencion
               AND rownum = 1;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            v_can_movimientos := 0;
      END;
            --Los Pagos de TC y Pagos de Préstamos ingresados por el TAS deben ingresar con estado 'X'
     --      IF  p_ses_usuario.codigoCanal not in ('998','999') and p_cod_operacion in ('031','032','015') then
               -- 393 efectivo
               -- 394 Cheques Nuestro Banco
               -- 395 Cheques Otros Bancos
     --          v_estado := 'X';
     --       ELSE
               v_estado := 'N';
     --       END IF;
      IF v_can_movimientos > 0 THEN
         -- ya se ingreso la boleta, se debe rechazar
         -- v_cod_respuesta := paw_bce.v_cod_ped_duplicado;
         pr_mensajeUsuario(cod_ped_duplicado, p_retorno.nombreRespuesta, p_retorno.descripcionRespuesta, p_retorno.error);
      ELSE
         -- movimiento puede ser ingresado
         r_gmovi.cod_modulo    := p_cod_mod_cta;
         r_gmovi.cod_modalidad := p_cod_mad_cta;
         r_gmovi.cod_oficina   := p_cod_ofi_cta;
         r_gmovi.nro_cuenta    := p_nro_cuenta;
         r_gmovi.cod_moneda    := p_cod_moneda;
         r_gmovi.cod_usuario   := p_men_caja.codigoUsuario; --v_cod_usuario;
         r_gmovi.hora          := v_hor_actual; --v_hor_actual;
         r_gmovi.fecha         := p_fec_actual; -- v_fec_actual;
         -- Aumento la secuencia
         -- v_nro_secuencia         := v_nro_secuencia + 1;
         p_nro_secuencia       := p_nro_secuencia + 1;
         r_gmovi.nro_secuencia := p_nro_secuencia; -- v_nro_secuencia;
         --
         r_gmovi.fec_valor       := p_fec_valor; --v_fec_valor;
         r_gmovi.cod_tra_padre   := p_cod_tra_padre;
         r_gmovi.cod_mod_padre   := nvl(p_cod_mod_padre, 9);
         r_gmovi.cod_mad_padre   := nvl(p_cod_mad_padre, 91);
         r_gmovi.cod_transaccion := p_cod_transaccion;
         r_gmovi.monto           := p_monto;
         r_gmovi.nro_documento   := p_nro_documento;
         r_gmovi.cotizacion      := p_cotizacion;
         IF p_cotizacion IS NOT NULL AND p_cod_moneda <> pag_gen.FU_OBT_MON_LOCAL THEN
            r_gmovi.mto_equ_local := ROUND(nvl(r_gmovi.monto, 0) * nvl(p_cotizacion, 0), 0);
            r_gmovi.cotizacion    := p_cotizacion;
         END IF;
         IF p_cod_moneda = pag_gen.FU_OBT_MON_LOCAL THEN
            r_gmovi.mto_equ_local := NULL;
            r_gmovi.cotizacion    := NULL;
         END IF;

         r_gmovi.cod_ofi_origen := p_men_caja.codigoOficinaOrigen; --v_cod_ofi_origen;
         r_gmovi.emi_aviso      := 'N';
         r_gmovi.concepto       := p_concepto;
         r_gmovi.estado         := v_estado;
         r_gmovi.reversado      := 'N';
         r_gmovi.nro_caja       := p_ses_usuario.codigoCanal; --v_nro_terminal;
         --
         r_gmovi.cod_retencion     := p_cod_retencion;
         r_gmovi.fec_fin_retencion := p_fec_fin_retencion;
         --
         r_gmovi.val_tasa      := p_val_tasa;
         r_gmovi.cod_rubro     := p_cod_rubro;
         r_gmovi.tip_mov_rubro := p_tipo_movimiento;

         while v_ins_movimiento = 'N' and v_can_intentos <= 10 loop
            begin
               PAG_GEN.PR_INS_GE_MOVIMIENTO(r_gmovi, p_es_mov_noc);
               v_ins_movimiento := 'S';
            exception
               when others then
                  v_hor_actual     := FUG_OBT_HOR_DISPONIBLE(v_fec_actual, v_hor_actual, user, p_es_mov_noc);
                  r_gmovi.hora     := v_hor_actual;
                  v_ins_movimiento := 'N';
                  v_can_intentos   := v_can_intentos + 1;
                  v_err_movimiento := substr(sqlerrm, 1, 300);
            end;
         end loop;
         if v_ins_movimiento = 'N' then
            raise_application_error(-20000, v_err_movimiento);
         end if;

         IF nvl(p_afe_caja, 'N') <> 'N' THEN


               IF(p_afe_caja='E') then

             v_tip_monto:='E';
           elsif(p_afe_caja='C') then
             v_tip_monto:='C';
           elsif(p_afe_caja='O') then
             v_tip_monto:='S';
           end if;
           v_estado:='X'; --para cj_cajas
            -- genero el movimiento en caja
            IF /*v_es_mov_noc*/
             p_es_mov_noc = 'S' THEN
               INSERT INTO cj_movimientos_noc
                  (fecha, hora, cod_usuario, nro_secuencia, cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_oficina, cod_moneda, nro_caja, nro_documento, nro_cuenta, monto, tip_monto, tipo,estado/*,nro_documento2*/)
               VALUES
                  (p_fec_actual, p_hor_actual, p_men_caja.codigoUsuario /*v_cod_usuario*/, p_nro_secuencia,
                   -- secuencia 1
                   p_cod_tra_padre, nvl(p_cod_mod_padre, 9), nvl(p_cod_mad_padre, 91), p_men_caja.codigoOficinaOrigen /*v_cod_ofi_origen*/, p_cod_moneda, to_number(p_ses_usuario.codigoCanal /*v_nro_terminal*/), p_nro_documento, p_nro_cuenta, p_monto, p_afe_caja, 'D',v_estado/*, p_nro_documento2*/); --es debito
            ELSE
               INSERT INTO cj_movimientos
                  (fecha, hora, cod_usuario, nro_secuencia, cod_tra_padre, cod_mod_padre, cod_mad_padre, cod_oficina, cod_moneda, nro_caja, nro_documento, nro_cuenta, monto, tip_monto, tipo, estado/*,nro_documento2*/)
               VALUES
                  (p_fec_actual, p_hor_actual, p_men_caja.codigoUsuario /*v_cod_usuario*/, p_nro_secuencia,
                   -- secuencia 1
                   p_cod_tra_padre, nvl(p_cod_mod_padre, 9), nvl(p_cod_mad_padre, 91), p_men_caja.codigoOficinaOrigen /*v_cod_ofi_origen*/, p_cod_moneda, to_number(p_ses_usuario.codigoCanal /*v_nro_terminal*/), p_nro_documento, p_nro_cuenta, p_monto, p_afe_caja, 'D', v_estado/*,p_nro_documento2*/); --es debito

            END IF;
         END IF;
      END IF;
   END;
   -- fin de la insercion de movimientos

   --recibe la clave en minusculas y hasheada en md5 recupera el salt del usuario y verifica que la clave sea igual a la guardada
   FUNCTION fu_val_ope_clave
   (
      p_clave             IN VARCHAR2,
      p_cod_persona       IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2
   ) RETURN typ_mensajeRespuesta IS
      MSG_CLA_OPE_ESTADO   CONSTANT VARCHAR2(15) := 'CLA_OPE_ESTADO';
      MSG_CLA_OPE_INTENTOS CONSTANT VARCHAR2(15) := 'CLA_OPE_INTENTO';
      MSG_CLA_OPE_CAMBIAR  CONSTANT VARCHAR2(15) := 'CLA_OPE_CAMBIAR';
      MSG_CLA_OPE_INVALIDA CONSTANT VARCHAR2(15) := 'CLA_OPE_INVALID';
      v_salt        NUMBER;
      v_clave       VARCHAR(300);
      v_estado      VARCHAR(1);
      v_can_errores NUMBER(2);
      v_retorno     typ_mensajeRespuesta := typ_mensajeRespuesta;
      --Verifica que la clave si tiene mas de 3 intentos fallidos pase a estado B
      PROCEDURE lp_blo_clave
      (
         p_cod_persona       IN VARCHAR2,
         p_cod_per_vinculada IN VARCHAR2
      ) IS
         PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
         v_can_intentos NUMBER;
      BEGIN
         IF p_cod_per_vinculada IS NULL THEN
            SELECT can_intentos
              INTO v_can_intentos
              FROM bw_ope_claves
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada IS NULL
               AND est_clave <> 'B';
         ELSE
            SELECT can_intentos
              INTO v_can_intentos
              FROM bw_ope_claves
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada = p_cod_per_vinculada
               AND est_clave <> 'B';
         END IF;
         IF (nvl(v_can_intentos, 0) >= 3) THEN
            IF p_cod_per_vinculada IS NULL THEN
               UPDATE bw_ope_claves
                  SET est_clave = 'B'
                WHERE cod_persona = p_cod_persona
                  AND cod_per_vinculada IS NULL;
            ELSE
               UPDATE bw_ope_claves
                  SET est_clave = 'B'
                WHERE cod_persona = p_cod_persona
                  AND cod_per_vinculada = p_cod_per_vinculada;
            END IF;
         END IF;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
      --registra que cuando ocurrio un error en el uso de la clave
      --para validar que no se ingrese mal la clave muy rapido
      PROCEDURE pr_reg_error
      (
         p_cod_persona       IN VARCHAR2,
         p_cod_per_vinculada IN VARCHAR2
      ) IS
         PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      BEGIN
         IF p_cod_per_vinculada IS NULL THEN
            UPDATE bw_ope_claves
               SET fec_ult_error = SYSDATE,
                   can_intentos  = nvl(can_intentos, 0) + 1
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada IS NULL;
         ELSE
            UPDATE bw_ope_claves
               SET fec_ult_error = SYSDATE,
                   can_intentos  = nvl(can_intentos, 0) + 1
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada = p_cod_per_vinculada;
         END IF;
         COMMIT;
         lp_blo_clave(p_cod_persona, p_cod_per_vinculada);
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;

      --actualiza el ultimo acceso realizado, en caso de que la clave sea la correcta
      --reinicia el contados de intentos fallidos a 0
      PROCEDURE lp_act_visitas
      (
         p_cod_persona       IN VARCHAR2,
         p_cod_per_vinculada IN VARCHAR2
      ) IS
         PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
      BEGIN
         IF p_cod_per_vinculada IS NULL THEN
            UPDATE bw_ope_claves
               SET can_acceso     = can_acceso + 1,
                   can_intentos   = 0,
                   fec_ult_acceso = SYSDATE
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada IS NULL;
         ELSE
            UPDATE bw_ope_claves
               SET can_acceso     = can_acceso + 1,
                   can_intentos   = 0,
                   fec_ult_acceso = SYSDATE
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada = p_cod_per_vinculada;
         END IF;
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
   BEGIN

      BEGIN
         -- obtiene el salt y el estado
         IF p_cod_per_vinculada IS NULL THEN
            SELECT cla_verificador, est_clave, can_intentos
              INTO v_salt, v_estado, v_can_errores
              FROM bw_ope_claves
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada IS NULL;
         ELSE
            SELECT cla_verificador, est_clave, can_intentos
              INTO v_salt, v_estado, v_can_errores
              FROM bw_ope_claves
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada = p_cod_per_vinculada;
         END IF;
      EXCEPTION
         WHEN too_many_rows THEN
            -- RETURN - 1;
            pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

            RETURN v_retorno;
         WHEN no_data_found THEN
            pr_reg_error(p_cod_persona, p_cod_per_vinculada);
            -- RETURN - 2;
            pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
      END;

      lp_act_est_ope_clave(p_cod_persona, p_cod_per_vinculada);

      v_clave := v_salt || '|' || p_clave;
      v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));

      IF v_can_errores >= to_number(fug_obt_pardinamico('CAN_INT_CLA_TRANSACCIONAL')) THEN
         lp_blo_clave(p_cod_persona, p_cod_per_vinculada);
         -- v_cod_respuesta:=PAW_BCE.v_cla_ope_intentos;
         -- return paw_bce.v_cla_ope_intentos;
         pr_mensajeUsuario(MSG_CLA_OPE_INTENTOS, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
      END IF;
      BEGIN
         IF p_cod_per_vinculada IS NULL THEN
            SELECT cla_verificador
              INTO v_salt
              FROM bw_ope_claves
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada IS NULL
               AND clave = v_clave;
         ELSE
            SELECT cla_verificador
              INTO v_salt
              FROM bw_ope_claves
             WHERE cod_persona = p_cod_persona
               AND cod_per_vinculada = p_cod_per_vinculada
               AND clave = v_clave;
         END IF;
         --La clave tiene que estar activa
         IF v_estado <> 'M' THEN
            IF v_estado = 'A' THEN
               -- v_cod_respuesta:=PAW_BCE.v_cla_ope_cambiar;
               --return paw_bce.v_cla_ope_cambiar;
               pr_mensajeUsuario(MSG_CLA_OPE_CAMBIAR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;
            ELSE
               pr_mensajeUsuario(MSG_CLA_OPE_ESTADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               RETURN v_retorno;
               -- return -9;
            END IF;
         END IF;
      EXCEPTION
         WHEN too_many_rows THEN
            -- RETURN - 3;
            pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            RETURN v_retorno;
         WHEN no_data_found THEN
            pr_reg_error(p_cod_persona, p_cod_per_vinculada);
            pr_mensajeUsuario(MSG_CLA_OPE_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            -- v_cod_respuesta:=paw_bce.v_cla_ope_invalida;
            RETURN v_retorno;
            --RETURN - 4;

      END;
      lp_act_visitas(p_cod_persona, p_cod_per_vinculada);
      -- v_cod_respuesta:=v_cod_aprobado;
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      RETURN v_retorno;
      -- RETURN 0;
   END;

   -- procedimiento que valida el contrato de cotizacion
   PROCEDURE pr_val_con_cambio
   (
      p_operacion       IN VARCHAR2,
      p_nro_contrato    IN NUMBER,
      p_cod_mon_debito  IN VARCHAR2 DEFAULT NULL,
      p_cod_mon_credito IN VARCHAR2 DEFAULT NULL,
      p_nro_cta_debito  IN VARCHAR2 DEFAULT NULL,
      p_nro_cta_credito IN VARCHAR2 DEFAULT NULL,
      p_cotizacion      IN NUMBER DEFAULT 0,
      p_importe         IN NUMBER DEFAULT 0,
      p_cod_mensaje     OUT VARCHAR2
   ) IS

      v_tipo              VARCHAR2(1);
      v_cont_mon_compra   lc_con_cambios.cod_mon_compra%TYPE;
      v_cont_cotiz_compra lc_con_cambios.Cot_Compra%TYPE;
      v_cont_mon_venta    lc_con_cambios.cod_mon_venta%TYPE;
      v_cont_cotiz_venta  lc_con_cambios.Cot_venta%TYPE;
      v_paridad           lc_con_cambios.paridad%TYPE;
      v_mto_compra        lc_con_cambios.mto_compra%TYPE;
      v_mto_venta         lc_con_cambios.mto_venta%TYPE;
      v_cta_debito        lc_con_cambios.nro_cta_debito%TYPE;
      v_cta_credito       lc_con_cambios.nro_cta_credito%TYPE;
      v_fec_actual        ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(1);

      c_con_cam_invalido CONSTANT VARCHAR2(3) := '162';
      c_con_mto_invalido CONSTANT VARCHAR2(3) := '180';
      c_con_cta_deb_inv  CONSTANT VARCHAR2(3) := '182';
      c_con_cta_cre_inv  CONSTANT VARCHAR2(3) := '183';
      c_cot_con_cam_inv  CONSTANT VARCHAR2(3) := '163';

   BEGIN
      p_cod_mensaje := msg_ok;
      IF p_nro_contrato > 0 THEN
         IF p_operacion = 'V' THEN
            IF p_cod_mon_debito <> c_cod_mon_local AND p_cod_mon_credito <> c_cod_mon_local THEN
               v_tipo := 'A'; -- arbitraje
            ELSIF p_cod_mon_credito = c_cod_mon_local AND p_cod_mon_debito <> c_cod_mon_local THEN
               v_tipo := 'C'; -- compra
            ELSE
               v_tipo := 'V'; -- venta
            END IF;
            BEGIN
               SELECT cod_mon_compra, cot_compra, cod_mon_venta, cot_venta, paridad, nvl(mto_compra, 0), nvl(mto_venta, 0), nro_cta_debito, nro_cta_credito
                 INTO v_cont_mon_compra, v_cont_cotiz_compra, v_cont_mon_venta, v_cont_cotiz_venta, v_paridad, v_mto_compra, v_mto_venta, v_cta_debito, v_cta_credito
                 FROM lc_con_cambios
                WHERE nro_contrato = p_nro_contrato
                  AND estado = 'P'
                  AND tipo = v_tipo
                  AND trunc(fec_insercion) = v_fec_actual;
            EXCEPTION
               WHEN OTHERS THEN
                  p_cod_mensaje := c_con_cam_invalido;
            END;
            IF p_cod_mensaje = msg_ok THEN
               IF (v_mto_compra != p_importe AND v_mto_venta != p_importe) THEN
                  p_cod_mensaje := c_con_mto_invalido;
               ELSIF v_cta_debito != p_nro_cta_debito THEN
                  p_cod_mensaje := c_con_cta_deb_inv;
               ELSIF v_cta_credito != p_nro_cta_credito AND p_nro_cta_credito IS NOT NULL AND nvl(v_cta_credito, 0) != 0 THEN
                  p_cod_mensaje := c_con_cta_cre_inv;
               END IF;
            END IF;
            --valido la cotizacion recibida Vs. la cotizacion del contrato
            IF (v_tipo = 'A' AND p_cotizacion != v_paridad) OR (v_tipo = 'V' AND p_cotizacion != v_cont_cotiz_venta) OR (v_tipo = 'C' AND p_cotizacion != v_cont_cotiz_compra) THEN
               p_cod_mensaje := c_cot_con_cam_inv;
            END IF;
         ELSE
            UPDATE lc_con_cambios
               SET estado = 'C'
             WHERE nro_contrato = p_nro_contrato;
         END IF;
      END IF;
   END;

   -- Obtiene el Menor Cargo
   PROCEDURE pr_obt_cargos
   (
      p_cod_ofi_origen   IN ge_cuentas.cod_oficina%TYPE,
      p_nro_cuenta       IN ge_cuentas.nro_cuenta%TYPE,
      p_cod_moneda       IN ge_cuentas.cod_moneda%TYPE,
      p_monto            IN ge_movimientos.monto%TYPE,
      p_cod_modulo       IN ge_cuentas.cod_modulo%TYPE,
      p_cod_modalidad    IN ge_cuentas.cod_modalidad%TYPE,
      p_cod_tra_cargo    IN ge_movimientos.cod_transaccion%TYPE,
      p_cod_tas_cargo    OUT ge_movimientos.cod_tasa%TYPE,
      p_val_tas_cargo    OUT ge_movimientos.val_tasa%TYPE,
      p_val_cargo        OUT ge_movimientos.val_tasa%TYPE,
      p_cod_tra_impuesto OUT ge_movimientos.cod_transaccion%TYPE,
      p_cod_tas_impuesto OUT ge_movimientos.cod_tasa%TYPE,
      p_val_tas_impuesto OUT ge_movimientos.val_tasa%TYPE,
      p_val_impuesto     OUT ge_movimientos.val_tasa%TYPE
   ) IS
      v_val_base          NUMBER(18, 2) := p_monto;
      v_fec_vigencia      DATE;
      v_tip_valor         VARCHAR2(1);
      v_tipo              VARCHAR2(1);
      v_redondeo          NUMBER(1);
      v_tas_personalizada VARCHAR2(1);
      v_val_tas_gen_cargo ge_movimientos.val_tasa%TYPE;
      v_val_tas_per_cargo ge_movimientos.val_tasa%TYPE;
   BEGIN
      -- veo si la cuenta tiene transaccion prohibida
      IF pag_cta.fu_ver_tra_prohibida(p_nro_cuenta, p_cod_tra_cargo, p_cod_modulo, p_cod_modalidad) = 'N' THEN
         -- no tiene transaccion prohibida, se calcula
         BEGIN
            SELECT tas_personalizada
              INTO v_tas_personalizada
              FROM ge_cuentas
             WHERE nro_cuenta = p_nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'Cuenta ' || p_nro_cuenta || ' no registrada');
         END;
         IF p_cod_moneda = pag_gen.fu_obt_mon_local THEN
            v_redondeo := 0;
         ELSE
            v_redondeo := 2;
         END IF;
         -- busco el valor de la tasa
         -- Por Cuenta
         pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad, p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda, v_val_base, nvl(v_tas_personalizada, 'N'), p_cod_tas_cargo, p_cod_tra_cargo, trunc(SYSDATE), v_val_tas_per_cargo, v_fec_vigencia, v_tip_valor, v_tipo);
         p_val_tas_cargo := nvl(v_val_tas_per_cargo, 0);
         -- General
         IF instr(',' || fug_obt_pardinamico('COD_TAS_SUJ_AJUSTE') || ',', ',' || p_cod_tas_cargo || ',') > 0 THEN
            pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad, p_cod_ofi_origen, NULL, p_cod_moneda, v_val_base, 'N', p_cod_tas_cargo, p_cod_tra_cargo, trunc(SYSDATE), v_val_tas_gen_cargo, v_fec_vigencia, v_tip_valor, v_tipo);
            IF nvl(v_val_tas_per_cargo, 0) > nvl(v_val_tas_gen_cargo, 0) THEN
               p_val_tas_cargo := nvl(v_val_tas_gen_cargo, 0);
            ELSE
               p_val_tas_cargo := nvl(v_val_tas_per_cargo, 0);
            END IF;
         END IF;

         IF v_tip_valor = 'V' THEN
            -- si es un valor, se toma directamente
            p_val_cargo := nvl(p_val_tas_cargo, 0);
         ELSE
            -- es un porcentaje
            p_val_cargo := round(nvl(v_val_base, 0) * nvl(p_val_tas_cargo, 0) / 100, v_redondeo);
         END IF;
         -- busco el impuesto asociado a este cargo
         BEGIN
            SELECT cod_tra_hijo
              INTO p_cod_tra_impuesto
              FROM ge_transacciones_det
             WHERE cod_modulo = p_cod_modulo
               AND cod_modalidad = p_cod_modalidad
               AND cod_transaccion = p_cod_tra_cargo
               AND cod_mod_hijo = p_cod_modulo
               AND cod_mad_hijo = p_cod_modalidad
               AND rownum = 1
               AND EXISTS (SELECT 0
                      FROM ge_transacciones x
                     WHERE x.cod_modulo = cod_mod_hijo
                       AND x.cod_modalidad = cod_mad_hijo
                       AND x.cod_transaccion = cod_tra_hijo
                       AND x.cod_tasa IS NOT NULL);
            -- veo si la cuenta tiene exoneracion de impuestos
            IF pag_cta.fu_ver_tra_prohibida(p_nro_cuenta, p_cod_tra_impuesto, p_cod_modulo, p_cod_modalidad) = 'N' THEN
               -- Se encontró impuesto asociado, se calcula
               pag_gen.pr_obt_val_tasa(p_cod_modulo, p_cod_modalidad, p_cod_ofi_origen, p_nro_cuenta, p_cod_moneda, p_val_cargo, nvl(v_tas_personalizada, 'N'), p_cod_tas_impuesto, p_cod_tra_impuesto, trunc(SYSDATE), p_val_tas_impuesto, v_fec_vigencia, v_tip_valor, v_tipo); ---OUT
               IF v_tip_valor = 'V' THEN
                  -- si es un valor, se toma directamente
                  p_val_impuesto := nvl(p_val_tas_impuesto, 0);
               ELSE
                  --
                  -- es un porcentaje, se considera incluido en el cargo
                  p_val_impuesto := round(nvl(p_val_cargo, 0) * nvl(p_val_tas_impuesto, 0) / (100 + p_val_tas_impuesto), v_redondeo);
               END IF;
               -- resto el monto del impuesto al cargo, porque va incluido
               p_val_cargo := nvl(p_val_cargo, 0) - nvl(p_val_impuesto, 0);
               IF p_val_cargo < 0 THEN
                  raise_application_error(-20000, 'Impuesto mas alto que el Cargo');
               END IF;
            ELSE
               p_val_impuesto := 0;
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               p_val_impuesto := 0;
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Al leer Impuesto ' || SQLERRM);
         END;
      END IF;
   END;

   PROCEDURE pr_set_tip_transferencia
   (
      p_tip_valor IN VARCHAR2,
      r_gtran     IN OUT pas_snp.rg_msj
   ) IS
   BEGIN
      IF p_tip_valor = 'B' THEN
         --LBTR (B)
         r_gtran.cod_msj_swift         := 103;
         r_gtran.cod_tip_operacion     := '001';
         r_gtran.cod_sub_tip_operacion := '002';
      ELSIF p_tip_valor = 'C' THEN
         --ACH (C)
         r_gtran.cod_msj_swift         := 102;
         r_gtran.cod_tip_operacion     := '011';
         r_gtran.cod_sub_tip_operacion := '001';
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         r_gtran.cod_msj_swift         := 102;
         r_gtran.cod_tip_operacion     := '001';
         r_gtran.cod_sub_tip_operacion := '002';
   END pr_set_tip_transferencia;

   /*VALIDA LA DUPLICACION DEL MOVIMIENTO*/
   PROCEDURE pr_val_duplicacion
   (
      p_nro_cta_debito      IN VARCHAR2,
      p_mto_debito          IN NUMBER,
      p_dato                IN VARCHAR2,
      p_cod_tra_padre       IN NUMBER,
      p_tie_ctr_duplicacion IN NUMBER,
      p_cod_per_empresa     IN NUMBER,
      p_cod_persona         IN NUMBER,
      p_cod_usuario         IN VARCHAR2,
      p_fec_actual          DATE,
      v_mensaje             OUT typ_mensajeCaja
   ) IS
      v_existe     VARCHAR2(1) := 'S';
      v_es_mov_noc VARCHAR2(1) := 'N'; -- Graba S/N mov nocturnosc
      c_cod_mov_duplicado CONSTANT VARCHAR2(04) := '1328';
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM bw_mov_pendientes
          WHERE cod_per_principal = p_cod_per_empresa
            AND nro_cuenta = p_nro_cta_debito
            AND monto = p_mto_debito
            AND estado = 'P'
            AND cod_tip_mensaje = '036'
            AND dato = p_dato
            AND can_aut_faltantes > 0
            AND (SYSDATE - fec_insercion) * 24 * 60 <= p_tie_ctr_duplicacion
            AND rownum = 1;
      EXCEPTION
         WHEN too_many_rows THEN
            v_existe := 'S';
         WHEN OTHERS THEN
            v_existe := 'N';
      END;
      IF v_existe = 'N' THEN
         IF v_es_mov_noc = 'S' THEN
            BEGIN
               SELECT DISTINCT 'S'
                 INTO v_existe
                 FROM ge_movimientos_noc
                WHERE nro_cuenta = p_nro_cta_debito
                  AND cod_tra_padre = p_cod_tra_padre
                  AND monto = p_mto_debito
                  AND reversado = 'N'
                  AND nro_secuencia = '1'
                  AND cod_usuario = p_cod_usuario
                     -- Controla que por lo menos haya pasado 10 minutos
                  AND (SYSDATE - fec_insercion) * 24 * 60 <= p_tie_ctr_duplicacion
                  AND rownum = 1;
            EXCEPTION
               WHEN too_many_rows THEN
                  v_existe := 'S';
               WHEN OTHERS THEN
                  v_existe := 'N';
            END;
         ELSE
            BEGIN
               SELECT DISTINCT 'S'
                 INTO v_existe
                 FROM ge_movimientos
                WHERE nro_cuenta = p_nro_cta_debito
                  AND cod_tra_padre = p_cod_tra_padre
                  AND monto = p_mto_debito
                  AND reversado = 'N'
                  AND nro_secuencia = '1'
                  AND cod_usuario = p_cod_usuario
                  AND fecha = p_fec_actual
                     -- Controla que por lo menos haya pasado 10 minutos
                  AND (SYSDATE - fec_insercion) * 24 * 60 <= p_tie_ctr_duplicacion
                  AND rownum = 1;
            EXCEPTION
               WHEN too_many_rows THEN
                  v_existe := 'S';
               WHEN OTHERS THEN
                  v_existe := 'N';
            END;
         END IF;
         IF v_existe = 'N' THEN
            BEGIN
               SELECT 'S'
                 INTO v_existe
                 FROM ge_snp_transferencias h
                WHERE h.cod_per_solicitante = nvl(p_cod_per_empresa, p_cod_persona)
                  AND h.nro_cta_solicitante = p_nro_cta_debito
                  AND h.monto = p_mto_debito
                  AND h.nro_cta_beneficiario = p_dato
                  AND (SYSDATE - h.fec_insercion) * 24 * 60 <= p_tie_ctr_duplicacion
                  AND rownum = 1;
            EXCEPTION
               WHEN too_many_rows THEN
                  v_existe := 'S';
               WHEN OTHERS THEN
                  v_existe := 'N';
            END;
         END IF;
      END IF;
      IF nvl(v_existe, 'N') = 'S' THEN
         pr_mensajeUsuario(c_cod_mov_duplicado, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      ELSE
         pr_mensajeUsuario(msg_ok, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN too_many_rows THEN
         pr_mensajeUsuario(c_cod_mov_duplicado, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
   END;

   FUNCTION fu_ver_horario
   (
      p_horario        OUT VARCHAR2,
      p_es_mov_noc     OUT VARCHAR2,
      p_es_cta_noc     OUT VARCHAR2,
      p_ult_cierre     IN DATE,
      p_cod_ofi_origen IN VARCHAR2,
      p_fec_actual     OUT DATE,
      p_fec_cie_caja   IN DATE,
      p_fec_valor      OUT DATE
   ) RETURN typ_MensajeRespuesta IS

      c_msg_sis_cierre CONSTANT VARCHAR2(15) := '106';
      v_est_modulo ba_modulos.estado%TYPE;
      v_retorno    typ_MensajeRespuesta := typ_MensajeRespuesta;
   BEGIN
      --v_cod_respuesta := paw_bce.v_cod_aprobado;
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
      v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

      IF v_est_modulo IN (6) THEN
         -- En cierre.
         --v_cod_respuesta := paw_bce.v_cod_sis_cierre;
         paw_con.pr_mensajeUsuario(c_msg_sis_cierre, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         paw_con.pr_insertarBitacora(NULL, NULL, NULL, '999', NULL, ' lp_ver_horario()-Sistema en cierre-', c_bit_error);
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto

         -- Verifica la hora --
         IF SYSDATE > p_ult_cierre AND trunc(p_ult_cierre) = p_fec_actual THEN
            p_horario    := 'T'; -- Tarde
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
            p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         END IF;

      ELSE
         p_horario := 'N'; -- Noche
         IF v_est_modulo <> 1 THEN
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
         END IF;
         p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         p_es_cta_noc := 'S'; -- Solo para que llavee la cuenta nocturna
      END IF;
      p_fec_valor       := trunc(SYSDATE);
      pag_cta.g_horario := p_horario;
      RETURN v_retorno;
   END fu_ver_horario;

   FUNCTION fu_val_cta_debito
   (
      p_nro_cta_debito IN VARCHAR2,
      p_cod_tra_padre  IN NUMBER,
      p_monto          IN NUMBER,
      p_cod_mon_debito OUT VARCHAR2,
      p_cod_mod_debito OUT NUMBER,
      p_cod_mad_debito OUT NUMBER,
      p_cod_ofi_debito OUT NUMBER,
      p_cta_for_debito OUT VARCHAR2,
      p_nom_cta_debito OUT VARCHAR2,
      p_validarSesion  IN typ_validarSesion,
      p_mensajeCaja    IN typ_mensajeCaja
   ) RETURN typ_mensajeRespuesta IS
      MSG_COD_CTA_INVALIDA    CONSTANT VARCHAR2(15) := '1267';
      MSG_COD_CTA_INEXISTENTE CONSTANT VARCHAR2(15) := '1266';
      MSG_COD_TRA_PROHIBIDA   CONSTANT VARCHAR2(15) := '1270';
      MSG_COD_SAL_INSUF       CONSTANT VARCHAR2(15) := '1268';
      MSG_COD_CTA_DUPLICADA   CONSTANT VARCHAR2(15) := '1265';
      MSG_COD_CTA_CONJUNTA    CONSTANT VARCHAR2(15) := '1271';
      MSG_COD_CTA_COMBINADA   CONSTANT VARCHAR2(15) := '1252';

      v_est_cta_debito VARCHAR2(1);
      v_nvo_estado     VARCHAR2(1) := NULL; -- cambio de estado de cuenta
      v_procesa        VARCHAR2(1) := 'N';
      v_sal_disponible NUMBER(18, 2);
      v_can_conjunta   NUMBER(7);
      v_retorno        typ_mensajeRespuesta := typ_mensajeRespuesta;
      -- verifico cuenta de debito
   BEGIN
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      SELECT a.cod_moneda, a.estado, cod_modalidad, cod_modulo, cod_oficina, fug_cta_formateada(cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, cod_moneda) cta_formateada, denominacion
        INTO p_cod_mon_debito, v_est_cta_debito, p_cod_mad_debito, p_cod_mod_debito, p_cod_ofi_debito, p_cta_for_debito, p_nom_cta_debito
        FROM ge_cuentas a
       WHERE a.nro_cuenta = p_nro_cta_debito; -- contiene el nro de cuenta
      -- debito
      IF p_cod_mad_debito NOT IN (31, 41) THEN
         pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
      ELSIF v_est_cta_debito NOT IN ('P', 'I', 'N', 'S') THEN
         pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
      ELSIF pag_cta.fu_ver_tra_prohibida(p_nro_cta_debito, p_cod_tra_padre, 9, 91) = 'S' THEN
         pr_mensajeUsuario(MSG_COD_TRA_PROHIBIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_tra_prohibida;
      ELSIF fu_es_conjunta(p_nro_cta_debito, p_validarSesion.codigoPersona, p_validarSesion.codigoEmpresa) = 'S' THEN
         pr_mensajeUsuario(MSG_COD_CTA_CONJUNTA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         -- v_cod_respuesta := paw_bce.v_cod_tra_invalida;
      ELSIF p_cod_mad_debito = 31 AND pag_cta.fu_obt_cta_cte_comb(p_nro_cta_debito) IS NOT NULL THEN
         pr_mensajeUsuario(MSG_COD_CTA_COMBINADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      ELSE
         pag_cta.pr_ver_operacion(p_nro_cta_debito, p_cod_tra_padre, 9, 91, 'D', p_cod_mon_debito, p_monto, p_mensajeCaja.codigoOficinaOrigen /* v_cod_ofi_origen */, p_cod_mod_debito, p_cod_mad_debito, v_nvo_estado, v_sal_disponible, v_procesa, 503);
         IF v_procesa = 'N' THEN
            -- no se puede debitar
            IF instr(upper(pag_cta.G_MSJ_ERROR), 'INSUFIC') > 0 THEN
               -- saldo insuficiente
               pr_mensajeUsuario(MSG_COD_SAL_INSUF, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               -- v_cod_respuesta := paw_bce.v_cod_sal_insuficiente;
            ELSE
               pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
               -- v_cod_respuesta := paw_bce.v_cod_cta_invalida;
            END IF;
         END IF;
      END IF;
      -- agregado para permitir a cuentas indistintas de personas fisicas grabar sin autorizacion
      IF v_retorno.error = 'N' AND p_validarSesion.codigoEmpresa IS NULL THEN
         -- veo si la cuenta no es conjunta
         SELECT COUNT(*)
           INTO v_can_conjunta
           FROM ge_cta_clientes
          WHERE nro_cuenta = p_nro_cta_debito
            AND relacion = 'Y'
            AND rownum = 1;
         IF nvl(v_can_conjunta, 0) = 0 THEN
            -- veo si es persona fisica no debe requerir autorizacion
            v_can_aut_requeridas := 0; -- no tiene autorizacion pendiente cuando es la persona fisica
         END IF;
      END IF;

      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         pr_mensajeUsuario(MSG_COD_CTA_INEXISTENTE, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
         -- v_cod_respuesta  := paw_bce.v_cod_cta_inexistente;
      WHEN too_many_rows THEN
         pr_mensajeUsuario(MSG_COD_CTA_DUPLICADA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
         -- v_cod_respuesta  := paw_bce.v_cod_cta_duplicada;
      WHEN OTHERS THEN
         pr_mensajeUsuario(MSG_COD_CTA_INVALIDA, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
         -- v_cod_respuesta  := paw_bce.v_cod_cta_invalida;
   END;
   -- Fin Validar Cuenta Debito
   /**
   *  Verifica que una transacción igual no se haya realizado en los últimos minutos
   */
   FUNCTION fu_ver_transaccion
   (
      p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
      p_cod_tra_padre   IN ge_movimientos.cod_tra_padre%TYPE,
      p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
      p_monto           IN ge_movimientos.monto%TYPE,
      p_mensajeCaja     IN typ_mensajeCaja
   ) RETURN typ_mensajeRespuesta IS

      MSG_COD_MOV_YA_INGRESADO CONSTANT VARCHAR2(15) := 'G_MOV_YA_INGRE';
      v_existe  VARCHAR2(1);
      v_retorno typ_mensajeRespuesta := typ_mensajeRespuesta;
      -- para controlar transacciones duplicadas, default 10 minutos
      v_min_transaccion NUMBER := nvl(to_number(fug_obt_pardinamico('PAW_MIN_TRANSACCION')), 10);
      v_horario         VARCHAR2(1);
      v_es_mov_noc      VARCHAR2(1);
      v_es_cta_noc      VARCHAR2(1);
      v_fec_actual      DATE;
      v_fec_valor       DATE;
   BEGIN
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      v_retorno := fu_ver_horario(v_horario, v_es_mov_noc, v_es_cta_noc, p_mensajeCaja.fechaUltimoCierre /* v_ult_cierre */,
                                  -- IN
                                  p_mensajeCaja.codigoOficinaOrigen /* v_cod_ofi_origen */,
                                  -- IN
                                  v_fec_actual, p_mensajeCaja.fechaCierre, v_fec_valor);
      IF v_retorno.error = 'S' THEN
         RETURN v_retorno;
      END IF;

      BEGIN
         IF v_es_mov_noc = 'S' THEN
            SELECT 'S'
              INTO v_existe
              FROM ge_movimientos_noc
             WHERE nro_cuenta = p_nro_cuenta
               AND cod_transaccion = p_cod_transaccion
               AND cod_tra_padre = p_cod_tra_padre
               AND monto = p_monto
               AND reversado = 'N'
               AND cod_usuario = p_mensajeCaja.codigoUsuario /* v_cod_usuario */
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
               AND cod_usuario = p_mensajeCaja.codigoUsuario /* v_cod_usuario */
               AND ((SYSDATE) - fec_insercion) * 1440 <= v_min_transaccion
               AND rownum = 1;
         END IF;
         -- v_respuesta := v_cod_mov_ya_ingresado;
         pr_mensajeUsuario(MSG_COD_MOV_YA_INGRESADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN too_many_rows THEN
            --v_respuesta := v_cod_mov_ya_ingresado;
            pr_mensajeUsuario(MSG_COD_MOV_YA_INGRESADO, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END;

      RETURN v_retorno;
   END;
   -- Final de fu_ver_transaccion

   /**
   ****  Funcion que controla la Cuenta Origen corresponda a la persona ***
   * @Migrado por: Sergio Ayala
   * @Fecha : 17-07-2012
   */
   FUNCTION lf_val_cta_origen
   (
      p_nro_cuenta  IN VARCHAR2,
      p_cod_persona IN VARCHAR2
   ) RETURN VARCHAR2 IS
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
   -- Final de Controla la Cuenta Origen

   -- busca si la persona puede ver tarjetas adicionales
   FUNCTION fu_ver_adicional
   (
      p_cod_modulo  NUMBER,
      p_relacion    VARCHAR2,
      p_nro_cuenta  VARCHAR2,
      p_cod_persona IN VARCHAR2
   ) RETURN VARCHAR2 IS
      v_ver_mov bw_cta_accesos.ver_movimientos%TYPE;
   BEGIN
      -- La condicion "IF p_cod_modulo = 5" esta aqui para no tener que poner en todos los lugares que se llama a la funcion
      -- La relacion se incluye de modo que solo se verifique los permisos para cuentas de tarjetas adicionales

      IF p_cod_modulo = 5 AND p_relacion = 'A' THEN
         BEGIN
            SELECT nvl(a.ver_movimientos, 'N') --T/N/S (Todo/Ninguno/Solo sus mov)
              INTO v_ver_mov
              FROM bw_cta_accesos a
             WHERE cod_per_vinculo = p_cod_persona
               AND nro_cuenta = p_nro_cuenta
               AND tip_acceso = 'H'
               AND activo = 'S';
         EXCEPTION
            WHEN OTHERS THEN
               v_ver_mov := 'N';
         END;
      ELSE
         v_ver_mov := 'T';
      END IF;
      RETURN v_ver_mov;
   END;

   FUNCTION fu_obt_tot_transacciones
   (
      p_codEmpresa      IN VARCHAR2,
      p_codPersona      IN VARCHAR2,
      p_nro_cuenta      IN VARCHAR2,
      p_cod_tra_padre   IN NUMBER,
      p_cod_tip_mensaje IN VARCHAR2
   ) RETURN NUMBER IS
      v_total      NUMBER(18, 2) := 0;
      p_fec_actual DATE := pag_cal.FU_OBT_FEC_ACTUAL(3);
   BEGIN
      SELECT nvl(SUM(j.monto), 0)
        INTO v_total
        FROM ge_movimientos j
       WHERE j.nro_cuenta = p_nro_cuenta
         AND j.estado = 'N'
         AND j.reversado = 'N'
         AND j.cod_tra_padre = p_cod_tra_padre
         AND j.cod_transaccion = '503'
         AND trunc(j.fec_insercion) = p_fec_actual
         AND EXISTS (SELECT 1
                FROM bw_movimientos h
               WHERE h.nro_documento = j.nro_documento
                 AND h.nro_caja = '999'
                 AND trunc(h.fec_insercion) = trunc(SYSDATE)
                 AND h.cod_per_principal = nvl(p_codEmpresa, p_codPersona)
                 AND ((h.cod_tip_mensaje = p_cod_tip_mensaje AND h.dato <> '0') OR (h.cod_tip_mensaje = '023' AND h.dato = '0')));

      SELECT nvl(v_total, 0) + nvl(SUM(j.monto), 0)
        INTO v_total
        FROM ge_movimientos_noc j
       WHERE j.nro_cuenta = p_nro_cuenta
         AND j.estado = 'N'
         AND j.reversado = 'N'
         AND j.cod_tra_padre = p_cod_tra_padre
         AND j.cod_transaccion = '503'
         AND trunc(j.fec_insercion) = p_fec_actual
         AND EXISTS (SELECT 1
                FROM bw_movimientos h
               WHERE (CASE fue_val_es_numerico(h.dato2)
                        WHEN 'S' THEN
                         h.dato2
                        ELSE
                         '-1'
                     END) = j.nro_documento
                 AND h.nro_caja = '999'
                 AND trunc(h.fec_insercion) = trunc(j.fec_insercion)
                 AND h.cod_per_principal = nvl(p_codEmpresa, p_codPersona)
                 AND ((h.cod_tip_mensaje = p_cod_tip_mensaje AND h.dato <> '0') OR (h.cod_tip_mensaje = '023' AND h.dato <> '0')));

      SELECT nvl(v_total, 0) + nvl(SUM(j.monto), 0)
        INTO v_total
        FROM ge_movimientos_noc j
       WHERE j.nro_cuenta = p_nro_cuenta
         AND j.estado = 'N'
         AND j.reversado = 'N'
         AND j.cod_tra_padre = p_cod_tra_padre
         AND j.cod_transaccion = '503'
         AND j.fecha = p_fec_actual
         AND EXISTS (SELECT 1
                FROM bw_movimientos h
               WHERE (CASE fue_val_es_numerico(h.dato2)
                        WHEN 'S' THEN
                         h.dato2
                        ELSE
                         '-1'
                     END) = j.nro_documento
                 AND h.nro_caja = '999'
                 AND trunc(h.fec_insercion) = trunc(j.fec_insercion)
                 AND h.cod_per_principal = nvl(p_codEmpresa, p_codPersona)
                 AND ((h.cod_tip_mensaje = p_cod_tip_mensaje AND h.dato <> '0') OR (h.cod_tip_mensaje = '023' AND h.dato <> '0')));

      SELECT nvl(v_total, 0) + nvl(SUM(monto), 0)
        INTO v_total
        FROM bw_mov_pendientes
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_tip_mensaje = p_cod_tip_mensaje
         AND estado = 'P'
         AND trunc(fec_insercion) = p_fec_actual;

      RETURN v_total;
   END;

   /**
   * Valida los datos de la Caja.
   */
   FUNCTION fu_val_caja(p_sesion IN typ_validarSesion) RETURN typ_mensajeCaja IS
      c_msg_caj_prohibida     CONSTANT VARCHAR2(15) := '236';
      c_msg_est_caj_invalida  CONSTANT VARCHAR2(15) := '237';
      c_msg_caj_no_encontrada CONSTANT VARCHAR2(15) := '235';
      -- Verifico la situacion del numero de caja
      v_est_caja       cj_cajas.estado%TYPE;
      v_tip_caja       cj_cajas.tipo%TYPE;
      v_cod_ofi_origen cj_cajas.cod_oficina%TYPE;
      v_cod_usuario    cj_cajas.cod_usuario%TYPE;
      v_ult_cierre     cj_cajas.fec_hor_cierre%TYPE;
      v_fec_cie_caja   cj_cajas.fec_cierre%TYPE;
      v_retorno        typ_mensajeCaja;

   BEGIN
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      SELECT estado, tipo, cod_oficina, cod_usuario, fec_hor_cierre, fec_cierre
        INTO v_est_caja, v_tip_caja, v_cod_ofi_origen, v_cod_usuario, v_ult_cierre, v_fec_cie_caja
        FROM cj_cajas
       WHERE nro_caja = to_number(p_sesion.codigoCanal);
      IF v_tip_caja NOT IN ('C', 'I', 'S') THEN
         -- tipo de caja no permitido
         pr_mensajeUsuario(c_msg_caj_prohibida, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;
      IF v_est_caja <> 'A' THEN
         pr_mensajeUsuario(c_msg_est_caj_invalida, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      END IF;

      v_retorno.estadoCaja          := v_est_caja;
      v_retorno.tipoCaja            := v_tip_caja;
      v_retorno.codigoOficinaOrigen := v_cod_ofi_origen;
      v_retorno.codigoUsuario       := v_cod_usuario;
      v_retorno.fechaUltimoCierre   := v_ult_cierre;
      v_retorno.fechaCierre         := v_fec_cie_caja;

      RETURN v_retorno;
   EXCEPTION
      WHEN no_data_found THEN
         pr_mensajeUsuario(c_msg_caj_no_encontrada, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         RETURN v_retorno;
   END;
   -- Final de lf_val_caja

   -- valida si una cuenta pertenece a un documento dado
   FUNCTION lf_cta_valida
   (
      p_nro_cuenta    VARCHAR2,
      p_nro_documento IN VARCHAR2,
      p_validarSesion IN typ_validarSesion,
      v_retError      IN OUT typ_mensajeRespuesta
   ) RETURN VARCHAR2 IS
      v_sino          VARCHAR2(01) := 'N';
      v_tip_persona   VARCHAR2(1);
      v_cod_persona   VARCHAR2(20);
      v_nro_documento VARCHAR2(20) := p_nro_documento;
      v_per_otr_cta   typ_obtenerPermisos;
      v_can_anterior  NUMBER;
      v_retorno       typ_validarSesion;
   BEGIN
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      IF v_nro_documento IS NULL THEN
         SELECT nro_documento
           INTO v_nro_documento
           FROM ba_personas
          WHERE cod_persona = nvl(p_validarSesion.codigoEmpresa, p_validarSesion.codigoPersona);
      ELSE
         -- veo si tiene permiso para transferencia 039 a otras cuentas
         v_can_anterior := v_can_aut_requeridas;
         ---+++  v_per_otr_cta  := paw_tas.l(nvl(p_validarSesion.codigoEmpresa,     p_validarSesion.codigoPersona), p_validarSesion.codigoPerfil,'039',p_validarSesion.codigoCanal);

         v_can_aut_requeridas := v_can_anterior;
         IF v_per_otr_cta.error = 'S' THEN
            v_retError.error                := v_per_otr_cta.error;
            v_retError.nombreRespuesta      := v_per_otr_cta.nombreRespuesta;
            v_retError.descripcionRespuesta := v_per_otr_cta.descripcionRespuesta;
            -- v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
            v_sino := 'N';
            RETURN v_sino;
         END IF;
      END IF;

      SELECT tipo, a.cod_persona
        INTO v_tip_persona, v_cod_persona
        FROM ba_personas b, ge_cta_clientes a
       WHERE a.nro_cuenta = p_nro_cuenta
         AND a.relacion = 'P'
         AND a.cod_persona = b.cod_persona;
      BEGIN
         IF v_tip_persona = 'J' THEN
            -- empresa
            -- busqueda por principal para ver si es el documento de la empresa
            SELECT 'S'
              INTO v_sino
              FROM ba_personas a
             WHERE a.cod_persona = v_cod_persona
               AND a.nro_documento = v_nro_documento;
         ELSE
            -- la cuenta es de una persona fisica
            SELECT 'S'
              INTO v_sino
              FROM ba_personas b
             WHERE b.nro_documento = v_nro_documento
               AND b.cod_persona IN (SELECT x.cod_persona
                                       FROM ge_cta_clientes x
                                      WHERE x.nro_cuenta = p_nro_cuenta
                                        AND x.cod_persona = b.cod_persona)
               AND rownum = 1; -- primero que encuentre
         END IF;
      END;
      RETURN v_sino;
   EXCEPTION
      WHEN OTHERS THEN
         v_sino := 'N';
         RETURN v_sino;
   END;

   /* Función que encripta y devuelve el valor encriptado de una palabra en formato md5
   */
   FUNCTION fu_enc_md5(p_encripta VARCHAR2) RETURN VARCHAR2 IS
      result VARCHAR2(2000);
   BEGIN
      result := lower(dbms_obfuscation_toolkit.md5(input => utl_raw.cast_to_raw((p_encripta))));
      RETURN(result);
   END fu_enc_md5;

   FUNCTION fu_obt_des_chequera(p_tip_chequera IN VARCHAR2) RETURN VARCHAR2 IS
      v_retorno VARCHAR2(200);
   BEGIN
      SELECT descripcion || ' ' || substr(p_tip_chequera, 3, 4)
        INTO v_retorno
        FROM cc_tip_chequeras
       WHERE cod_tip_chequera = substr(p_tip_chequera, 1, 1);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   FUNCTION fu_tip_cuenta
   (
      p_cod_modulo    IN NUMBER,
      p_cod_modalidad IN NUMBER
   ) RETURN CHAR IS
      v_cod_tip_cuenta CHAR(2);
   BEGIN
      IF p_cod_modulo = 3 THEN
         -- ahorros
         IF p_cod_modalidad = 31 THEN
            v_cod_tip_cuenta := 'AH';
         ELSIF p_cod_modalidad IN (32, 33, 34, 36) THEN
            v_cod_tip_cuenta := 'AP';
         END IF;
      ELSIF p_cod_modulo = 4 THEN
         -- cuentas corrientes
         v_cod_tip_cuenta := 'CC';
      ELSIF p_cod_modulo = 5 THEN
         -- Tarjetas
         v_cod_tip_cuenta := 'TJ';
      ELSIF p_cod_modulo = 6 THEN
         -- prestamos
         v_cod_tip_cuenta := 'PT';
      ELSIF p_cod_modulo = 8 THEN
         -- comercio exterior
         v_cod_tip_cuenta := 'CX';
      END IF;

      RETURN v_cod_tip_cuenta;
   END;

   /* Retorna el saldo actual de una cuenta
   */
   FUNCTION fu_obt_sal_actual
   (
      p_cod_modulo    IN NUMBER,
      p_cod_modalidad IN NUMBER,
      p_numeroCuenta  IN VARCHAR2
   ) RETURN NUMBER IS
      v_sal_actual NUMBER;
   BEGIN

      IF p_cod_modulo IN (3, 4) THEN
         -- cuentas pasivas
         pag_cta.pr_obt_cuenta(p_numeroCuenta);
         v_sal_actual := pag_cta.FU_SAL_DISPONIBLE;
      ELSIF p_cod_modulo = 5 THEN
         -- Tarjetas
         SELECT nvl(lin_credito, 0) - (nvl(b.sal_facturar, 0) + nvl(b.sal_facturado, 0) + nvl(b.sal_financiado, 0) + nvl(b.sal_cuo_pendientes, 0))
           INTO v_sal_actual
           FROM ta_cta_tarjetas b
          WHERE b.nro_cuenta = p_numeroCuenta;
      ELSIF p_cod_modulo = 6 THEN
         -- prestamos
         SELECT nvl(b.sal_capital, 0) + nvl(b.sal_int_adelantado, 0)
           INTO v_sal_actual
           FROM pr_cta_prestamos b
          WHERE b.nro_cuenta = p_numeroCuenta;
      ELSIF p_cod_modulo = 8 THEN
         -- comercio exterior
         v_sal_actual := 0;
      END IF;
      RETURN v_sal_actual;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0; -- saldo 0(cero)
   END;

   FUNCTION fu_val_pin_temporal(p_cod_cliente IN VARCHAR2) RETURN VARCHAR2 IS
      v_fec_hora   bw_movimientos.fec_hora%TYPE;
      v_existe     VARCHAR2(01) := 'N';
      v_fec_actual DATE := pag_cal.fu_obt_fec_actual(9); -- fecha de hoy
   BEGIN
      -- Verifico si posee movimientos de creación de pin temporales de IVR
      BEGIN
         SELECT nvl(MAX(a.fec_hora), '')
           INTO v_fec_hora
           FROM bw_movimientos a
          WHERE a.cod_per_ingreso = p_cod_cliente
            AND trunc(a.fec_hora) = v_fec_actual
            AND a.cod_tip_mensaje = '080'
            AND a.etiqueta = 'Call Center';
      EXCEPTION
         WHEN OTHERS THEN
            v_existe := 'N';
      END;
      IF v_fec_hora IS NOT NULL THEN
         IF ((SYSDATE - v_fec_hora) * 24 * 60) <= 30 THEN
            v_existe := 'S';
         END IF;
      END IF;
      RETURN(V_EXISTE);
   END;

   /** Verifica la validez de una sesion obtenida previamente de fu_iniciarSesion
   * @param p_sesionUsuario identificador de sesion a ser verificado
   * @param p_codCanal identificador del Canal para el cual la sesion fue obtenida
   * @return retorna información de la sesion o error si no pudo comprobarse su validez
   */
   FUNCTION fu_validarSesion
   (
      p_sesionUsuario IN VARCHAR2,
      p_codCanal      IN VARCHAR2
   ) RETURN typ_validarSesion IS
      PRAGMA AUTONOMOUS_TRANSACTION;

      c_msg_aut_error   CONSTANT VARCHAR2(15) := '238';
      c_msg_tk_expirado CONSTANT VARCHAR2(15) := '241';

      c_fec_hor_actual CONSTANT DATE := SYSDATE;
      c_cod_operacion  CONSTANT VARCHAR2(5) := '005';
      v_max_tie_inactividad NUMBER(3);
      v_ultimoAcceso        DATE;
      v_retorno             typ_validarSesion;
   BEGIN

      v_max_tie_inactividad := fug_obt_pardinamico('BCA_MBS_MIN_INACTIVIDAD');
      IF (p_codCanal IS NULL OR p_sesionUsuario IS NULL OR length(p_codCanal) = 0 OR length(p_sesionUsuario) = 0) THEN
         pr_mensajeUsuario(c_msg_aut_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora(p_sesionUsuario, p_codCanal, NULL, c_cod_operacion, NULL, 'fu_validarSesion- Error Canal ' || fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), c_bit_ERROR);
         RETURN v_retorno;
      END IF;

      BEGIN
         SELECT cod_canal, cod_persona, cod_per_vinculada, cod_perfil, fec_ult_actividad, nro_telefono
           INTO v_retorno.codigoCanal, v_retorno.codigoPersona, v_retorno.codigoEmpresa, v_retorno.codigoPerfil, v_ultimoAcceso, v_retorno.numeroTelefono
           FROM bw_aut_sesiones tk
          WHERE tk.cod_sesion = p_sesionUsuario;
      EXCEPTION
         WHEN no_data_found THEN
            pr_mensajeUsuario(c_msg_aut_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
            pr_insertarBitacora('0', p_codCanal, p_sesionUsuario, c_cod_operacion, NULL, 'fu_validarSesion - Token inexistente-' || fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), c_bit_ERROR);
            RETURN v_retorno;
      END;

      -- AuthToken  NO corresponde al usuario y canal proveido?
      IF (v_retorno.codigoCanal <> p_codCanal) THEN
         --Panic!
         DELETE FROM BW_AUT_SESIONES
          WHERE cod_sesion = p_sesionUsuario;
         COMMIT;

         pr_mensajeUsuario(c_msg_aut_error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora('0', p_codCanal, p_sesionUsuario, c_cod_operacion, NULL, 'fu_validarSesion - Token no corresponde a canal-' || fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), c_bit_ERROR);
         RETURN v_retorno;
      END IF;

      --El AuthToken  ya no es válido?
      IF ((c_fec_hor_actual - v_ultimoAcceso) * 1440) > v_max_tie_inactividad THEN
         DELETE FROM bw_aut_sesiones
          WHERE cod_sesion = p_sesionUsuario;
         COMMIT;
         pr_mensajeUsuario(c_msg_tk_expirado, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora('0', p_codCanal, p_sesionUsuario, c_cod_operacion, v_retorno.codigoEmpresa, 'fu_validarSesion Token expirado-' || fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), c_bit_ERROR);
         RETURN v_retorno;
      END IF;

      --todo fue ok, actualizar el ultimo acceso
      UPDATE bw_aut_sesiones
         SET fec_ult_actividad = c_fec_hor_actual
       WHERE cod_sesion = p_sesionUsuario;
      COMMIT;
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      pr_insertarBitacora('000', p_codCanal, p_sesionUsuario, c_cod_operacion, v_retorno.codigoEmpresa, 'validarSesion-' || fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, NULL), BITACORA_SALIDA);
      RETURN v_retorno;
   END;

   /* Funcion que controla la Cuenta Origen corresponda a la persona */
   FUNCTION fu_val_cta_origen
   (
      p_nro_cuenta  IN VARCHAR2,
      p_cod_persona IN VARCHAR2
   ) RETURN VARCHAR2 IS
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

   FUNCTION fu_obt_cta_limpia
   (
      p_nro_cta_especifica VARCHAR2,
      p_cod_operacion      VARCHAR2,
      p_cod_persona        VARCHAR2
   ) RETURN VARCHAR2 IS
      v_nro_cta_especifica VARCHAR2(30) := REPLACE(REPLACE(REPLACE(TRIM(p_nro_cta_especifica), '.', '-'), ' ', '-'), '/', '-');
      v_pos                NUMBER;
   BEGIN
      IF v_nro_cta_especifica IS NOT NULL THEN
         IF (instr(v_nro_cta_especifica, '-') > 0 OR instr(v_nro_cta_especifica, ' ') > 0) THEN
            -- se extrae los guiones de la cuenta
            IF p_cod_operacion = '031' THEN
               -- Si es pago de prestamos solo debe quitarle el guion y el espacio si tiene
               v_nro_cta_especifica := TRIM(REPLACE(REPLACE(v_nro_cta_especifica, '-', ''), ' ', ''));
            ELSE
               v_pos := instr(v_nro_cta_especifica, '-', -1);
               IF v_pos > 0 THEN
                  v_nro_cta_especifica := to_number(substr(v_nro_cta_especifica, v_pos + 1));
               END IF;
            END IF;
         ELSIF length(v_nro_cta_especifica) = 16 THEN
            -- es un tarjeta de credito, busco y reemplazo el dato
            BEGIN
               SELECT a.nro_cuenta
                 INTO v_nro_cta_especifica
                 FROM ge_cta_clientes a, ta_tarjetas b
                WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
                  AND b.nro_cuenta = a.nro_cuenta
                  AND a.cod_persona = p_cod_persona;
            EXCEPTION
               WHEN no_data_found THEN
                  SELECT b.nro_cuenta
                    INTO v_nro_cta_especifica
                    FROM ta_tarjetas b
                   WHERE b.nro_tarjeta = TRIM(v_nro_cta_especifica)
                     AND vigente = 'S'
                     AND rownum = 1;
            END;
         ELSIF substr(v_nro_cta_especifica, 1, 2) = '00' THEN
            v_nro_cta_especifica := to_number(v_nro_cta_especifica);
         END IF;
      END IF;
      RETURN v_nro_cta_especifica;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- valida si una cuenta pertenece a un documento dado
   FUNCTION fu_cta_valida
   (
      p_nro_cuenta    VARCHAR2,
      p_nro_documento IN VARCHAR2,
      p_validarSesion IN typ_validarSesion,
      v_retError      IN OUT typ_mensajeRespuesta
   ) RETURN VARCHAR2 IS
      v_sino          VARCHAR2(01) := 'N';
      v_tip_persona   VARCHAR2(1);
      v_cod_persona   VARCHAR2(20);
      v_nro_documento VARCHAR2(20) := p_nro_documento;
      -- v_per_otr_cta varchar2(10);
      v_per_otr_cta  typ_obtenerPermisos;
      v_can_anterior NUMBER;
      v_retorno      typ_validarSesion;
   BEGIN
      pr_mensajeUsuario(msg_ok, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      IF v_nro_documento IS NULL THEN
         SELECT nro_documento
           INTO v_nro_documento
           FROM ba_personas
          WHERE cod_persona = nvl(p_validarSesion.codigoEmpresa, p_validarSesion.codigoPersona);
      ELSE
         -- veo si tiene permiso para transferencia 039 a otras cuentas
         v_can_anterior := v_can_aut_requeridas;
         v_per_otr_cta  := fu_obt_permisos(nvl(p_validarSesion.codigoEmpresa, p_validarSesion.codigoPersona), p_validarSesion.codigoPerfil, '039', p_validarSesion.codigoCanal);

         v_can_aut_requeridas := v_can_anterior;
         IF v_per_otr_cta.error = 'S' THEN
            v_retError.error                := v_per_otr_cta.error;
            v_retError.nombreRespuesta      := v_per_otr_cta.nombreRespuesta;
            v_retError.descripcionRespuesta := v_per_otr_cta.descripcionRespuesta;
            -- v_cod_respuesta := paw_bce.v_cod_sin_autorizacion;
            v_sino := 'N';
            RETURN v_sino;
         END IF;
      END IF;

      SELECT tipo, a.cod_persona
        INTO v_tip_persona, v_cod_persona
        FROM ba_personas b, ge_cta_clientes a
       WHERE a.nro_cuenta = p_nro_cuenta
         AND a.relacion = 'P'
         AND a.cod_persona = b.cod_persona;
      BEGIN
         IF v_tip_persona = 'J' THEN
            -- empresa
            -- busqueda por principal para ver si es el documento de la empresa
            SELECT 'S'
              INTO v_sino
              FROM ba_personas a
             WHERE a.cod_persona = v_cod_persona
               AND a.nro_documento = v_nro_documento;
         ELSE
            -- la cuenta es de una persona fisica
            SELECT 'S'
              INTO v_sino
              FROM ba_personas b
             WHERE b.nro_documento = v_nro_documento
               AND b.cod_persona IN (SELECT x.cod_persona
                                       FROM ge_cta_clientes x
                                      WHERE x.nro_cuenta = p_nro_cuenta
                                        AND x.cod_persona = b.cod_persona)
               AND rownum = 1; -- primero que encuentre
         END IF;
      END;
      RETURN v_sino;
   EXCEPTION
      WHEN OTHERS THEN
         v_sino := 'N';
         RETURN v_sino;
   END;

   -- obtiene el codigo de transaccion para las comisiones en transferencias (098,105)
   FUNCTION fu_obt_cod_transaccion
   (
      p_es_cambio       BOOLEAN,
      p_fecha_valor     DATE,
      p_cod_per_empresa VARCHAR2,
      p_cod_persona     VARCHAR2
   ) -- O/B (Ordenante, Beneficiario)
    RETURN NUMBER IS

      v_es_corporativo  VARCHAR2(1);
      v_cod_transaccion ge_movimientos.cod_transaccion%TYPE;
      v_tip_operacion   NUMBER(5);
    BEGIN
      BEGIN
         SELECT DISTINCT 'S'
           INTO v_es_corporativo
           FROM ge_bancas b, ba_usuarios u, ge_clientes c
          WHERE b.cod_banca = u.cod_banca
            AND c.cod_usu_oficial = u.cod_usuario
            AND b.descripcion LIKE '%CORP%'
            AND c.cod_persona = nvl(p_cod_per_empresa, p_cod_persona);
      EXCEPTION
         WHEN OTHERS THEN
            v_es_corporativo := 'N';
      END;
      IF p_es_cambio THEN
         -- si es una operacion de cambio donde la moneda credito difiere a la moneda debito
         v_cod_transaccion := 5100;
      ELSE
         IF v_es_corporativo = 'S' THEN
            -- si es corporativo
            v_cod_transaccion := 779;
         ELSE
            -- si es minorista o cualquier otro tipo de banca
            --      v_tip_operacion := p_fecha_valor - v_fec_actual;
            -- v_tip_operacion := fuh_obt_dif_dias(v_fec_actual, p_fecha_valor);
            IF v_tip_operacion = 0 THEN
               -- 00 Hs
               v_cod_transaccion := 5101;
            ELSIF v_tip_operacion BETWEEN - 1 AND 1 THEN
               -- 24 Hs.
               v_cod_transaccion := 5102;
            ELSIF v_tip_operacion BETWEEN - 2 AND 2 THEN
               -- 48 Hs.
               v_cod_transaccion := 5103;
            ELSE
               v_cod_transaccion := NULL; -- No se cobra comision
            END IF;
         END IF;
      END IF;

      RETURN v_cod_transaccion;
   END;

   -- obtener cotizacion para operaciones via banca electronica
   FUNCTION fu_obt_cotizacion
   (
      p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
      p_tipo       IN VARCHAR2 -- C-COMPRA o V-VENTA
   ) RETURN NUMBER IS

      v_cotizacion ge_cotizaciones.val_conversion%TYPE;
      v_fec_actual ge_calendarios.fec_actual%TYPE := pag_cal.FU_OBT_FEC_ACTUAL(1);

   BEGIN
      SELECT decode(p_tipo, 'C', val_com_electronica, 'V', val_ven_electronica, NULL)
        INTO v_cotizacion
        FROM ge_cotizaciones a
       WHERE fecha = (SELECT MAX(fecha)
                        FROM ge_cotizaciones
                       WHERE cod_moneda = p_cod_moneda
                         AND fecha <= v_fec_actual)
         AND cod_moneda = p_cod_moneda;
      RETURN v_cotizacion;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
      WHEN OTHERS THEN
         raise_application_error(-20000, SQLERRM || 'error. al buscar cotizacion de venta ');
   END;

   /* Funcion que obtiene los email's relacionados al tipo de mensaje*/
   FUNCTION fu_obt_msg_mail(p_cod_tip_mensaje VARCHAR2) RETURN VARCHAR2 IS
      v_dir_mail bw_tip_mensajes.dir_mail%TYPE;
   BEGIN
      BEGIN
         SELECT dir_mail
           INTO v_dir_mail
           FROM bw_tip_mensajes m
          WHERE m.cod_tip_mensaje = p_cod_tip_mensaje
            AND m.dir_mail IS NOT NULL;

         v_dir_mail := REPLACE(v_dir_mail, ' ', ''); --quito los espacios en blanco

      EXCEPTION
         WHEN OTHERS THEN
            v_dir_mail := NULL;
      END;

      RETURN v_dir_mail;
   END;

   FUNCTION fu_obt_val_decodificado(p_clob IN CLOB) RETURN BLOB IS
      v_retorno      BLOB;
      v_acumulado    INTEGER;
      v_temporal     CLOB;
      v_val_caracter VARCHAR2(32000);
      v_valor        RAW(32000);
      v_porcion      BINARY_INTEGER := 32000;
   BEGIN
      IF p_clob IS NULL THEN
         RETURN NULL;
      END IF;
      --  v_temporal := fu_act_clob(p_clob, utl_tcp.crlf, '');
      dbms_lob.createtemporary(v_retorno, TRUE);
      v_acumulado := 1;
      FOR i IN 1 .. ceil(dbms_lob.getlength(v_temporal) / v_porcion) LOOP

         dbms_lob.read(v_temporal, v_porcion, v_acumulado, v_val_caracter);
         v_valor := utl_encode.base64_decode(utl_raw.cast_to_raw(v_val_caracter));
         dbms_lob.writeappend(v_retorno, utl_raw.length(v_valor), v_valor);
         v_acumulado := v_acumulado + v_porcion;

      END LOOP;
      RETURN v_retorno;
   END fu_obt_val_decodificado;

   /*genera una clave lista para guardar en bw_ope_claves, si generar ='S'
   crea una clave con un numero aleatorio y la retorna en p_cla_operacion
   la clave no debe ser almacenada en ningun lugar en plano, siempre tiene que estar al menos hasheada
   p_cod_per_vinculada tiene que ser nulo si es una persona fisica*/
   FUNCTION fu_gen_ope_clave (p_clave           in  varchar2,
                           p_cod_persona       in  varchar2,
                           p_cod_per_vinculada in  varchar2,
                           p_accion            in  varchar2,
                           p_tip_clave         in  varchar2,
                           p_cla_operacion     out varchar2)
   return varchar2 is
    v_salt      NUMBER;
    v_clave     VARCHAR(300);
    v_clave_aux NUMBER;
   --guarda en el log
   BEGIN
   --verifica que la persona este relacionada a la empresa
   IF p_cod_per_vinculada IS NOT NULL THEN
       IF paw_con.fu_val_per_vinculada(p_cod_per_vinculada, p_cod_persona) = 'N' THEN
        RETURN -5;
     END IF;
   END IF;
   v_salt := round(dbms_random.value(1000000, 9999999));
   IF (p_clave IS NULL OR p_accion = 'C') THEN
    IF (p_tip_clave='A') then
     v_clave_aux     := round(dbms_random.value(100000000, 999999999));
    ELSE
     v_clave_aux     := round(dbms_random.value(100000, 999999));
    END IF;
     p_cla_operacion := v_clave_aux;
   ELSIF p_accion <> 'A' THEN -- p_clave ya viene hasheada con p_accion = 'A'
     v_clave_aux := to_number(p_clave);
   END IF;
    --hago el hash 2 veces porque necesito poder enviar desde el hb la clave y que no se pueda ver en los logs
    --se va a enviar la clave hasheada, entonce se vuelve a hashear
    --los hash se guardan en minusculas para que sean iguales a los producidos por perl
    -- modificado para reutilizar desde fu_pro_operacion_080 y fu_pro_operacion_219
    -- donde la clave ya viene hasheada y envia p_accion = 'A'
    IF p_accion = 'A' THEN
       v_clave := p_clave;
    ELSE
      --no se aplica sha256 porque se quiere mantener la misma lógica anterior y sobre ella el sha 256
      v_clave := lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave_aux))));

      --ajuste sha256
      v_clave := fuw_obt_sha256(v_clave);
      --

    END IF;
    --aca hasheo el hasheo de la clave
    --v_clave := v_salt || '|' || v_clave;
    --v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));

   --Si acción es N, crear Nueva contraseña
    CASE p_accion
       WHEN 'C' THEN
          BEGIN
             INSERT INTO bw_ope_claves
                (cla_verificador, clave, can_acceso, est_clave, cod_persona, cod_per_vinculada, tip_clave)
             VALUES
                (v_salt, v_clave, 0, 'N', p_cod_persona, p_cod_per_vinculada, p_tip_clave);
               pr_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
          EXCEPTION
             WHEN dup_val_on_index THEN
                --Si hay error de PK intenta actualizar
                BEGIN
                   UPDATE bw_ope_claves
                      SET cla_verificador = v_salt,
                          clave           = v_clave,
                          est_clave       = 'N',
                          can_intentos    = 0
                    WHERE cod_persona = p_cod_persona
                      AND tip_clave = p_tip_clave
                        AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada));
                     paw_con.pr_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
                EXCEPTION
                   WHEN OTHERS THEN
                      RETURN - 7;
                END;
             WHEN OTHERS THEN
                RETURN - 1;
          END;

       WHEN 'R' THEN
          --La acción es cambiar la contraseña
          DECLARE
             i NUMBER;
          BEGIN
             UPDATE bw_ope_claves
                SET cla_verificador = v_salt,
                    clave           = v_clave,
                    est_clave       = 'N',
                    can_intentos    = 0
              WHERE cod_persona = p_cod_persona
                AND tip_clave = p_tip_clave
                  AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada));
             i := SQL%ROWCOUNT;
             IF i = 0 THEN
                -- no se actualizó ningun registro
                RETURN - 3;
             END IF;
               paw_con.pr_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
          EXCEPTION
             WHEN OTHERS THEN
                RETURN - 2;
          END;
    WHEN 'A' THEN
       -- verificamos si la clave ya está en uso
        IF paw_con.fu_val_vul_claves(p_cod_persona, p_clave) = 'N' THEN
          RETURN -6;
       END IF;
       -- actualizar clave nueva y estado
       UPDATE bw_ope_claves
          SET clave           = v_clave,
              cla_verificador = v_salt,
              fec_cam_clave   = SYSDATE,
              fec_ult_acceso  = SYSDATE,
              can_intentos    = 0,
              est_clave       = 'M'
        WHERE cod_persona = p_cod_persona
               AND ((p_cod_per_vinculada IS NULL AND cod_per_vinculada IS NULL) OR (p_cod_per_vinculada IS NOT NULL AND cod_per_vinculada = p_cod_per_vinculada))
          AND tip_clave = p_tip_clave;
       -- controlamos si hubo actualización
       IF SQL%NOTFOUND THEN
          -- no se actualizó ningun registro
          RETURN - 3;
       END IF;
            paw_con.pr_cla_reg_operacion(p_cod_persona, p_accion, p_cod_per_vinculada, p_tip_clave);
    END CASE;

    RETURN lower(v_clave);
    --RETURN v_clave;
   END;

   /* Función que valida que el código de persona este vinculada a la empresa */
   FUNCTION fu_val_per_vinculada
   (
      p_cod_per_empresa IN ge_clientes.cod_persona%TYPE,
      p_cod_persona     IN ge_clientes.cod_persona%TYPE
   ) RETURN VARCHAR2 IS
      v_sino VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         IF pag_gen.fu_es_per_fisica(p_cod_per_empresa) = 'N' THEN
            SELECT 'S'
              INTO v_sino
              FROM ba_vinculos
             WHERE cod_per_vinculo = p_cod_persona
               AND cod_persona = p_cod_per_empresa;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN OTHERS THEN
            NULL;
      END;
      RETURN v_sino;
   END;

   -- función que valida que una clave (de acceso o transaccional) no se repita,
   -- si un usuario posee varias claves, todas deben ser diferentes, p_cla_nueva esta en MD5
   -- S : la clave es valida para usar, N : caso contrario
  FUNCTION fu_val_vul_claves(p_cod_persona in bw_ope_claves.cod_persona%type,
                             p_cla_nueva   in bw_ope_claves.clave%type) return varchar2 is
  v_cla_valida      varchar2(1) := 'S'; -- es válida la clave
  v_clave           varchar2(300);
  v_nro_doc_cliente ba_personas.nro_documento%type;
  -- obtiene todas las claves que posee la persona
  cursor c_claves is
    select cla_verificador, clave, cod_per_vinculada
      from bw_ope_claves
     where cod_persona = p_cod_persona;
  begin
    -- buscamos si ya existe la clave nueva creada
    for cla in c_claves loop

      --ajuste sha256
      --v_clave := cla.cla_verificador || '|' || p_cla_nueva;
      --v_clave := rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_clave)));
      v_clave := p_cla_nueva;
      --

      if v_clave = cla.clave then
        v_cla_valida := 'N'; -- no es válida la clave
        exit;
      end if;
      -- buscamos si escogió la clave igual a su cod. persona vinculada
      if v_cla_valida = 'S' and cla.cod_per_vinculada is not null then

        --ajuste sha256
        v_clave := fuw_obt_sha256(lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => cla.cod_per_vinculada)))));
        --

        if v_clave = p_cla_nueva then
          v_cla_valida := 'N';
          exit;
        end if;
      end if;
    end loop;
    -- buscamos si escogió la clave igual a su cod. persona
    if v_cla_valida = 'S' then

      --ajuste sha256
      v_clave := fuw_obt_sha256(lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => p_cod_persona)))));
      --

      if v_clave = p_cla_nueva then
        v_cla_valida := 'N';
      end if;
    end if;

    -- buscamos si escogió la clave igual a su CI
    if v_cla_valida = 'S' then
      begin
        select a.nro_documento
          into v_nro_doc_cliente
          from ba_personas a
         where a.cod_persona = p_cod_persona;

        --ajuste sha256
        v_clave := fuw_obt_sha256(lower(rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => v_nro_doc_cliente)))));
        --

        if v_clave = p_cla_nueva then
          v_cla_valida := 'N';
        end if;
      exception
        when others then
          v_cla_valida := 'N';
      end;
    end if;
    return v_cla_valida;
  end;

   -- Graba los movimientos que operan bajo limites en Mobile Banking
   PROCEDURE pr_gen_monto
   (
      p_cod_mensaje IN VARCHAR2,
      p_monto       IN NUMBER,
      p_cod_moneda  IN VARCHAR2,
      p_nro_cuenta  IN VARCHAR2,
      p_fec_actual  IN DATE,
      p_cod_canal   IN VARCHAR2
   ) IS
      v_nro_secuencia NUMBER(9);

   BEGIN
      SELECT s_nro_operacion.nextval
        INTO v_nro_secuencia
        FROM dual;
      INSERT INTO bw_ope_limitadas
         (nro_secuencia, nro_cuenta, cod_tip_mensaje, cod_canal, fecha, monto, cod_moneda)
      VALUES
         (v_nro_secuencia, p_nro_cuenta, p_cod_mensaje, p_cod_canal, p_fec_actual, p_monto, p_cod_moneda);
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END;

   --Guarda una accion con las claves de operaciones
   PROCEDURE pr_cla_reg_operacion
   (
      p_cod_persona       IN VARCHAR2,
      p_accion            IN VARCHAR2,
      p_cod_per_vinculada IN VARCHAR2,
      p_tip_clave         IN VARCHAR2
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
   BEGIN
      INSERT INTO BW_CLA_ACCIONES
         (cod_persona, accion, tip_clave, cod_per_vinculada)
      VALUES
         (p_cod_persona, p_accion, p_tip_clave, p_cod_per_vinculada); --Codigo C es para Crear -- R Cambiar
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, SQLERRM);
   END;

   FUNCTION pr_ver_horario(p_horario        OUT VARCHAR2
                          ,p_es_mov_noc     OUT VARCHAR2
                          ,p_es_cta_noc     OUT VARCHAR2
                          ,p_ult_cierre     IN  DATE
                          ,p_cod_ofi_origen IN  VARCHAR2
                          ,p_fec_actual     OUT DATE
                          ,p_fec_cie_caja   IN  DATE
                          ,p_fec_valor      OUT DATE) RETURN typ_MensajeRespuesta IS

      c_msg_sis_cierre constant varchar2(15) := '106';
      v_est_modulo     ba_modulos.estado%TYPE;
      v_retorno        typ_MensajeRespuesta := typ_MensajeRespuesta;
   BEGIN
      --v_cod_respuesta := paw_bce.v_cod_aprobado;
      pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

      p_horario    := 'D'; -- Dia normal
      p_es_mov_noc := 'N'; -- Para grabar en las tablas nocturnas
      p_es_cta_noc := 'N';
      p_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(3);
      v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(3);

      IF v_est_modulo IN (6) THEN
         -- En cierre.
         --v_cod_respuesta := paw_bce.v_cod_sis_cierre;
         pr_mensajeUsuario(c_msg_sis_cierre, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         pr_insertarBitacora(NULL, NULL, NULL, C_COD_HOMEBANKING, NULL, ' lp_ver_horario()-Sistema en cierre-', BITACORA_ERROR);
      ELSIF v_est_modulo = 2 THEN
         -- El modulo esta abierto

         -- Verifica la hora --
         IF SYSDATE > p_ult_cierre AND trunc(p_ult_cierre) = p_fec_actual THEN
            p_horario    := 'T'; -- Tarde
            p_fec_actual := pag_cal.FU_OBT_FEC_HABIL(p_fec_actual + 1, 1, p_cod_ofi_origen);
            p_es_mov_noc := 'S'; -- Para grabar en las tablas nocturnas
         END IF;

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
   END pr_ver_horario;

   FUNCTION fu_val_usu_tas
   (
      p_cod_canal VARCHAR2,
      p_clave     VARCHAR2,
      p_cod_persona VARCHAR2
   ) RETURN typ_iniciarsesion IS
      v_salt      VARCHAR2(32);
      v_authToken VARCHAR2(32);
      V_DUMMY     NUMBER := 0;
      v_retorno   typ_iniciarsesion := typ_iniciarsesion();
   BEGIN
      BEGIN
         SELECT 1
           INTO V_DUMMY
           FROM BW_OPE_CLA_TAS BW
          WHERE BW.EST_CLAVE = 'M'
            AND BW.COD_CANAL = p_cod_canal
            AND BW.COD_PERSONA = p_cod_persona
            AND BW.clave = p_clave;--rawtohex(utl_raw.cast_to_raw(dbms_obfuscation_toolkit.md5(input_string => cla_verificador || '|' || p_clave)));
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_DUMMY := 0;
         WHEN OTHERS THEN
            V_DUMMY := 0;
      END;

      IF V_DUMMY > 0 THEN
         pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         BEGIN
            -- Generar Salt aleatorio Salt = MD5(random_string)
            SELECT fu_enc_md5(dbms_random.string('P', 20)) salt
              INTO v_salt
              FROM dual;

            -- md5(pass + salt + nroTerminal)
            v_authToken := fu_enc_md5(p_clave || v_salt || p_cod_canal);
            DELETE FROM BW_AUT_SESIONES
             WHERE cod_persona = p_cod_canal
               AND cod_canal = p_cod_canal;

            INSERT INTO BW_AUT_SESIONES
               (cod_persona, cod_per_vinculada, cod_perfil, cod_canal, FEC_ULT_ACTIVIDAD, cod_sesion)
            VALUES
               (p_cod_canal, NULL, 'COMPLETO', p_cod_canal, SYSDATE, v_authToken);
            COMMIT;
            v_retorno.nombreCompleto := 'Usuario TAS ' || p_cod_canal;
            v_retorno.codigoCliente  := p_cod_canal;
            v_retorno.sesionUsuario  := v_authToken;
            v_retorno.codigoPerfil   := 'COMPLETO';

         END;

      END IF;
      RETURN v_retorno;
   END;

   FUNCTION fu_val_est_tas(p_cod_canal VARCHAR2) RETURN BOOLEAN IS
      V_DUMMY NUMBER := 0;
   BEGIN
      BEGIN
         SELECT DISTINCT 1
           INTO V_DUMMY
           FROM BW_OPE_CLA_TAS BW
          WHERE BW.COD_PERSONA = p_cod_canal;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            V_DUMMY := 0;
         WHEN OTHERS THEN
            V_DUMMY := 0;
      END;

      IF V_DUMMY > 0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END;

   PROCEDURE pr_val_dup_tas
   (
      p_nro_cta_cuenta IN VARCHAR2,
      p_nro_sobre      IN NUMBER,
      v_mensaje        OUT typ_mensajeCaja
   ) IS
      v_existe     VARCHAR2(1) := 'S';
      v_es_mov_noc VARCHAR2(1) := 'N'; -- Graba S/N mov nocturnosc
      c_cod_mov_duplicado CONSTANT VARCHAR2(15) := 'G_COD_MOV_DUPLI';
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ge_movimientos
          WHERE nro_cuenta = p_nro_cta_cuenta
            AND nro_documento = p_nro_sobre
            AND rownum = 1;
      EXCEPTION
         WHEN too_many_rows THEN
            v_existe := 'S';
         WHEN OTHERS THEN
            v_existe := 'N';
      END;
      IF v_existe = 'N' THEN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ge_movimientos_noc
             WHERE nro_cuenta = p_nro_cta_cuenta
               AND nro_documento = p_nro_sobre
               AND rownum = 1;
         EXCEPTION
            WHEN too_many_rows THEN
               v_existe := 'S';
            WHEN OTHERS THEN
               v_existe := 'N';
         END;
      END IF;

      IF nvl(v_existe, 'N') = 'S' THEN
         pr_mensajeUsuario(c_cod_mov_duplicado, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      ELSE
         pr_mensajeUsuario(msg_ok, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN too_many_rows THEN
         pr_mensajeUsuario(c_cod_mov_duplicado, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
   END;

--inicializacion del paquete
BEGIN
   pre_cam_for_numerico('.,');
   PRE_INI_APLICACION;
   PAE_CNF.G_COD_MODULO := 9; --Modulo caja

END PAW_CON;
/

