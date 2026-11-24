CREATE OR REPLACE PACKAGE BODY IT.PAW_NOT IS
  
   /**  Codigo de respuesta OK generico */
   MSG_OK CONSTANT VARCHAR2(30) := 'OP_APROBADA';

   /** Codigo de error generico, Ej. excepciones no manejadas */
   MSG_ERROR CONSTANT VARCHAR2(30) := 'OP_ERROR';

   /** Constantes de tipo de Bitácora */
   BITACORA_ERROR   CONSTANT VARCHAR2(3) := 'ERR';
   BITACORA_ENTRADA CONSTANT VARCHAR2(3) := 'ENT';
   BITACORA_SALIDA  CONSTANT VARCHAR2(3) := 'SAL';

   FUNCTION lf_val_sesion(p_sesion IN VARCHAR2, p_cod_canal IN VARCHAR2) RETURN bw_aut_sesiones%ROWTYPE IS
      v_retorno bw_aut_sesiones%rowtype;
      v_max_tiempo  CONSTANT NUMBER(3) := 15;
   BEGIN
      SELECT * -- s.cod_per_vinculada, s.cod_persona
        INTO v_retorno--v_cod_empresa, v_cod_persona
        FROM bw_aut_sesiones s
       WHERE s.cod_sesion = p_sesion
         AND s.cod_canal = p_cod_canal
         AND ((SYSDATE - s.fec_ult_actividad) * 1440) <= v_max_tiempo;

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

FUNCTION lf_dia_habil RETURN VARCHAR2 IS
BEGIN
   IF pag_cal.fu_obt_fec_sig_hab(trunc(SYSDATE), 031, 0) = trunc(SYSDATE) THEN
      RETURN 'S';
   END IF;
   RETURN 'N';
END;

   FUNCTION lf_obt_ult_tarjeta(p_nro_tarjeta IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      RETURN '*' || substr(p_nro_tarjeta, length(p_nro_tarjeta) - 3);
   END;
   -- Formatea  la fecha en formato sin año, hora formato 24 y sin segundos
   FUNCTION lf_obt_fec_tra_formateado(p_fecha IN DATE) RETURN VARCHAR2 IS
   BEGIN
      RETURN to_char(p_fecha, 'DD/MM HH24:MI');
   END;

   FUNCTION lf_obt_des_tip_tarjeta(p_tipo IN VARCHAR2) RETURN VARCHAR2 IS
   BEGIN
      IF (upper(p_tipo) = 'C') THEN
         RETURN 'credito';
      END IF;
      RETURN 'debito';
   END;

   FUNCTION lf_obt_mto_formateado(p_monto IN FLOAT, p_moneda IN NUMBER DEFAULT 600) RETURN VARCHAR2 IS
   BEGIN
      IF p_moneda = 600 THEN
         RETURN REPLACE(TRIM(BOTH FROM TO_CHAR(p_monto, '999,999,999,999')), ',', '.');
      END IF;
      RETURN replace(replace(replace(TRIM(BOTH FROM TO_CHAR(p_monto, '999,999,999,999.00')),'.','*'),',','.'),'*',',');
   END;

   FUNCTION lf_obt_com_formateado(p_comercio IN VARCHAR) RETURN VARCHAR2 IS
   BEGIN
      RETURN substr(REPLACE(TRIM(BOTH FROM p_comercio), '  ', ' '), 0, 40);
   END;

   FUNCTION lf_val_cta_origen(p_nro_cuenta  IN VARCHAR2,
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

/* Calcula el cierre de una tarjeta de credito */
   FUNCTION lf_obt_fec_cierre(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_cod_modulo IN ta_cta_tarjetas.cod_modulo%TYPE,
                              p_cod_modalidad IN ta_cta_tarjetas.cod_modalidad%TYPE) RETURN DATE IS
      v_fec_inicio      DATE;
      v_fec_prox_cierre DATE;
      v_tip_cierre      ta_cta_tarjetas.cod_tip_cierre%TYPE;
   BEGIN
      SELECT fec_ult_cierre, cod_tip_cierre
        INTO v_fec_inicio, v_tip_cierre
        FROM ta_cta_tarjetas
       WHERE nro_cuenta = p_nro_cuenta;

      SELECT MIN(fec_cierre)
        INTO v_fec_prox_cierre
        FROM ta_cal_cierres v
       WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
         AND v.cod_modulo = p_cod_modulo
         AND v.cod_modalidad = p_cod_modalidad
         AND v.cod_tip_cierre = v_tip_cierre
         AND fec_cierre > v_fec_inicio;

      RETURN v_fec_prox_cierre;
   END;

   FUNCTION lf_obt_mon_bancard(p_ban_moneda IN VARCHAR) RETURN VARCHAR2 IS
      v_cod_moneda ba_monedas.cod_moneda%TYPE;
   BEGIN

      BEGIN
         SELECT m.moneda
           INTO v_cod_moneda
           FROM BW_NOT_ISO_CODIGOS m
          WHERE m.cod_iso = p_ban_moneda
          and rownum=1;
         RETURN v_cod_moneda;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN '';
      END;
   END;

--obtiene informacion del evento
FUNCTION lf_obt_con_evento(p_cod_evento IN bw_not_eventos.cod_evento%TYPE, p_horario OUT bw_not_eventos.horario%TYPE,
                           p_ocurrencia OUT bw_not_eventos.ocurrencia%TYPE, p_mto_minimo OUT bw_not_eventos.mto_minimo%TYPE,
                           p_mandatorio OUT bw_not_eventos.mandatorio%TYPE, p_cod_tip_evento OUT bw_not_eventos.cod_tip_evento%TYPE) RETURN NUMBER IS
BEGIN
   SELECT mandatorio, mto_minimo, ocurrencia, horario, cod_tip_evento
     INTO p_mandatorio, p_mto_minimo, p_ocurrencia, p_horario, p_cod_tip_evento
     FROM bw_not_eventos
    WHERE cod_evento = p_cod_evento;
   RETURN 0;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 1;
END;

FUNCTION lf_obt_dia_frecuencia(p_frecuencia VARCHAR2) RETURN NUMBER IS
   v_dias NUMBER := 0;
BEGIN
   CASE p_frecuencia
      WHEN 'D' THEN
         v_dias := 1;
      WHEN 'S' THEN
         v_dias := 7;
      WHEN 'Q' THEN
         v_dias := 15;
      WHEN 'M' THEN
         v_dias := 30;
      ELSE
        v_dias  := 1;
   END CASE;
   RETURN v_dias;
END;

--Actualiza la fecha del ultimo envio de la suscripcion
FUNCTION lf_act_fec_ult_evento(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
                                  p_cod_evento IN bw_not_eventos.cod_evento%TYPE, p_envio IN DATE,p_dato1 in number DEFAULT 0) RETURN NUMBER IS
BEGIN
   UPDATE bw_not_suscripciones s
         SET s.fec_ult_envio = p_envio,
         s.dato1=p_dato1
    WHERE s.cod_persona = p_cod_persona
      AND s.nro_cuenta = p_nro_cuenta
      AND s.cod_evento = p_cod_evento;
   RETURN 0;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 1;
END;

   PROCEDURE lp_ins_log_mensajeria(p_pedido IN bw_log_bca_electronica.mensaje%TYPE, p_respuesta IN bw_log_bca_electronica.respuesta%TYPE) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      BEGIN
         INSERT INTO bw_log_bca_electronica
            (mensaje, respuesta)
         VALUES
            (p_pedido, p_respuesta);
         COMMIT;
      EXCEPTION
         WHEN OTHERS THEN
            NULL;
      END;
   END;

   --para evitar que se generen mensajes parecidos en poco tiempo
   FUNCTION lf_obt_men_duplicado(p_cod_persona IN ba_personas.cod_persona%TYPE, p_mensaje IN VARCHAR2, p_dias IN NUMBER,
                                 p_fec_programada IN DATE DEFAULT NULL) RETURN NUMBER IS
      v_retorno NUMBER := 0;
      v_dias    NUMBER := 0;
   BEGIN
      IF p_fec_programada IS NULL THEN
         v_dias := p_dias;
      ELSE
         v_dias := p_fec_programada - SYSDATE;
         IF p_dias > v_dias THEN
            v_dias := p_dias;
         END IF;
      END IF;
      BEGIN
         SELECT COUNT(*)
           INTO v_retorno
           FROM bw_not_mensajes m
          WHERE m.cod_persona = p_cod_persona
            AND m.mensaje = p_mensaje
            AND m.fec_insercion >= SYSDATE - v_dias;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 0;
      END;
      RETURN v_retorno;
   END;

    FUNCTION lf_ver_destino(p_cod_persona IN ba_personas.cod_persona%TYPE, p_destino IN bw_not_destinos.nombre%TYPE) RETURN VARCHAR2 IS
       v_direccion bw_not_cli_destino.direccion%TYPE;
    BEGIN
       BEGIN
          SELECT c.direccion
            INTO v_direccion
            FROM bw_not_cli_destino c, bw_not_destinos d
           WHERE d.cod_destino = c.cod_destino
             AND d.nombre = p_destino
             AND c.activo = 'S'
             AND c.cod_persona = p_cod_persona;
       EXCEPTION
          WHEN OTHERS THEN
             RETURN NULL;
       END;
       RETURN v_direccion;
    END;


   FUNCTION fu_obt_not_template(p_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE, p_template OUT bw_not_tip_eventos.template%TYPE,
                                p_response_code IN ta_ban_transaciones.response_code%TYPE DEFAULT '00') RETURN NUMBER IS
      v_template2 bw_not_tip_eventos.template%TYPE;
   BEGIN
      BEGIN
         SELECT template, template2
           INTO p_template, v_template2
           FROM bw_not_tip_eventos
          WHERE cod_tip_evento = p_cod_tip_evento;
         IF p_response_code <> '00' THEN
            p_template := v_template2;
         END IF;
         IF p_template IS NULL THEN
            RETURN 11;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            dbms_output.put_line(SQLERRM);
            RETURN 10;
      END;
      RETURN 0;
   END;


   FUNCTION fu_env_sms_prueba(p_nro_telefono IN VARCHAR2, p_mensaje IN VARCHAR2, p_origen IN VARCHAR2) RETURN NUMBER IS
      c_ws_metodo CONSTANT VARCHAR2(50) := 'Send';
      v_url          VARCHAR2(100) := '';
      v_ws_respuesta paw_json.JSONStructObj;
      v_parametros   VARCHAR2(400);
      v_resPost      TYP_POSTRESPUESTA;
      v_return       VARCHAR(10);
   BEGIN

      v_url        := g_not_webservice || c_ws_metodo;
      v_parametros := utl_lms.format_message('cod_destiny=SMS&destiny=%s&message=%s&secure=0&origin=%s', p_nro_telefono, utl_url.escape(p_mensaje, true, 'UTF-8'), p_origen);
      v_resPost    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
      lp_ins_log_mensajeria(v_url || '?' || v_parametros, v_resPost.error || '|' || v_resPost.respuesta);
      IF (v_resPost.error = 'N') THEN
         v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
         v_return       := paw_json.getAttrValue(v_ws_respuesta, 'code');
      ELSE   
         dbms_output.put_line(v_resPost.respuesta);
         RETURN - 99;
      END IF;

      RETURN v_return;
   END;

FUNCTION fu_env_email_prueba(p_email IN VARCHAR2, p_mensaje IN VARCHAR2, p_origen IN VARCHAR2) RETURN NUMBER IS
      c_ws_metodo CONSTANT VARCHAR2(50) := 'Send';
      v_url          VARCHAR2(100) := '';
      v_ws_respuesta paw_json.JSONStructObj;
      v_parametros   VARCHAR2(32000);
      v_resPost      TYP_POSTRESPUESTA;
      v_return       VARCHAR(10);
   BEGIN

      v_url        := g_not_webservice || c_ws_metodo;
      v_parametros := utl_lms.format_message('cod_destiny=EMAIL&destiny=%s&message=%s&secure=0&origin=%s', p_email, p_mensaje, p_origen);
      v_resPost    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
      lp_ins_log_mensajeria(v_url || '?' || substr(v_parametros,1,3600), substr(v_resPost.error || '|' || v_resPost.respuesta,1,4000));
      IF (v_resPost.error = 'N') THEN
         v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
         v_return       := paw_json.getAttrValue(v_ws_respuesta, 'code');
      ELSE
         dbms_output.put_line(v_resPost.respuesta);
         lp_ins_log_mensajeria(v_url || '?' || v_parametros, substr(v_resPost.error || '|' || v_resPost.respuesta,1,4000));
         RETURN - 99;
      END IF;

      RETURN v_return;
   EXCEPTION
      WHEN OTHERS THEN
           lp_ins_log_mensajeria(v_url || '?' || v_parametros, sqlerrm);
         RETURN - 99;
   END;



   FUNCTION fu_env_todos RETURN NUMBER IS
      c_ws_metodo CONSTANT VARCHAR2(50) := 'SendAll';
      v_url          VARCHAR2(100) := '';
      v_ws_respuesta paw_json.JSONStructObj;
      v_parametros   VARCHAR2(200);
      v_resPost      TYP_POSTRESPUESTA;

      v_return       VARCHAR(10);

   BEGIN
      v_url        := g_not_webservice || c_ws_metodo;
      v_parametros := utl_lms.format_message('');
      v_resPost    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
      IF (v_resPost.error = 'N') THEN
         v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
         v_return       := paw_json.getAttrValue(v_ws_respuesta, 'code');
      ELSE
         dbms_output.put_line(v_resPost.respuesta);
         RETURN - 99;
      END IF;

      RETURN v_return;

   END;


   FUNCTION fu_obt_suscripcion(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_suscripto VARCHAR(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_suscripto
           FROM bw_not_cli_suscriptos d
          WHERE d.cod_persona = p_cod_persona
            AND d.activo = 'S';
         RETURN v_suscripto;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 'N';
      END;
   END;

   /*
   Verifica que el cliente este suscripto a un evento especifico y retorna informacion de la suscripcion
   */
   FUNCTION fu_obt_eve_suscripcion(p_cod_persona IN VARCHAR2, p_nro_cuenta IN VARCHAR2, p_cod_tip_evento IN bw_not_tip_eventos.cod_tip_evento%TYPE,
                                   p_cod_evento OUT bw_not_eventos.cod_evento%TYPE, p_horario OUT bw_not_eventos.horario%TYPE,
                                p_monto IN bw_not_eventos.mto_minimo%TYPE,p_cod_iso_moneda in bw_not_iso_codigos.moneda%type, p_ocurrencia OUT bw_not_eventos.ocurrencia%TYPE,
                                p_mandatorio OUT bw_not_eventos.mandatorio%TYPE, p_rechazo IN VARCHAR2 DEFAULT 'N') RETURN NUMBER IS

   v_aux   VARCHAR2(1) := 'N';
   v_monto Ge_Movimientos.Monto%TYPE := 0;
       v_aux2 number;

       FUNCTION lf_obt_modulo(p_nro_cuenta IN VARCHAR2) RETURN NUMBER IS
          v_modulo NUMBER(3) := 0;
       BEGIN
          BEGIN
             SELECT cod_modulo
               INTO v_modulo
               FROM ge_cuentas
              WHERE nro_cuenta = p_nro_cuenta;
          EXCEPTION
             WHEN OTHERS THEN
                RETURN 0;
          END;
          RETURN v_modulo;
       END;

       FUNCTION lf_eve_sus_mandatorio(p_cod_tip_evento IN bw_not_tip_eventos.cod_tip_evento%TYPE, p_cod_evento OUT bw_not_eventos.cod_evento%TYPE,
                                      p_horario OUT bw_not_eventos.horario%TYPE, p_monto IN bw_not_eventos.mto_minimo%TYPE,
                                      p_cod_iso_moneda IN bw_not_iso_codigos.moneda%TYPE, p_mandatorio OUT bw_not_eventos.mandatorio%TYPE, 
                                      p_cod_modulo IN ge_cuentas.cod_modulo%TYPE, p_rechazo IN VARCHAR2 DEFAULT 'N',p_mto_mandatorio OUT bw_not_eventos.mto_minimo%TYPE) RETURN NUMBER IS

       BEGIN
   BEGIN
                SELECT cod_evento, 'M', mandatorio, nvl(mto_mandatorio, 0)
               INTO p_cod_evento, p_horario, p_mandatorio, p_mto_mandatorio
                  FROM bw_not_eventos
                 WHERE cod_tip_evento = p_cod_tip_evento
                 and cod_modulo=p_cod_modulo
                      --AND nvl(mto_mandatorio, 0) < p_monto
                   AND rownum = 1;
             IF p_mandatorio = 'S' THEN
                -- si es mandatorio se avisa, si es guaranies se comprueba el minimo
                   if p_cod_iso_moneda<>'600' then
                     return 0;
                   end if;
                   IF p_rechazo = 'S' THEN
                      RETURN 0;
                ELSIF p_rechazo = 'N' AND p_mto_mandatorio <= p_monto THEN
                      RETURN 0;
                ELSE
                   RETURN 8;
                   END IF;
                END IF;
             EXCEPTION
                WHEN OTHERS THEN
                   NULL;
             END;
          RETURN 7;
       END;
    BEGIN
     /*
   Verifica si esta suscripto a notificaciones
   */
   BEGIN
      SELECT 'S'
        INTO v_aux
        FROM bw_not_cli_suscriptos s
       WHERE s.cod_persona = p_cod_persona
         AND s.activo = 'S';
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 2;
   END;
   /*
     Primero busca la suscripcion del cliente, luego busca si el evento es mandatorio
     si es mandatorio entonces retorna que el cliente esta sucripto.
     */
      BEGIN
          SELECT s.cod_evento, s.horario, v.mandatorio, v.ocurrencia,s.MTO_MINIMO
        INTO p_cod_evento, p_horario, p_mandatorio, p_ocurrencia, v_monto
           FROM bw_not_suscripciones s, bw_not_tip_eventos e, bw_not_cli_destino d, bw_not_eventos v
          WHERE d.cod_persona = s.cod_persona
            AND s.cod_evento = v.cod_evento
            AND v.cod_tip_evento = e.cod_tip_evento
            --AND nvl(s.mto_minimo,0) <= p_monto 
            AND s.cod_persona = p_cod_persona
            AND s.nro_cuenta = p_nro_cuenta
            AND e.cod_tip_evento = p_cod_tip_evento
            AND s.activo = 'S'
            AND d.activo = 'S'
            AND rownum = 1;
      EXCEPTION
         WHEN OTHERS THEN
           return lf_eve_sus_mandatorio(p_cod_tip_evento , p_cod_evento ,
                                      p_horario , p_monto ,
                                      p_cod_iso_moneda , p_mandatorio ,
                                      lf_obt_modulo(p_nro_cuenta),
                                      p_rechazo,v_monto) ;
      END;

       if v_monto is null then
         v_aux2:= lf_eve_sus_mandatorio(p_cod_tip_evento , p_cod_evento ,
                                      p_horario , p_monto ,
                                      p_cod_iso_moneda , p_mandatorio ,
                                      lf_obt_modulo(p_nro_cuenta),
                                      p_rechazo,v_monto);
            END IF;
   --Si es un rechazo se avisa, sino se verifica el monto solamente si es guaranies
   IF p_rechazo = 'S' THEN
      RETURN 0;
   ELSIF p_rechazo = 'N' THEN
        if v_monto <= p_monto then
      RETURN 0;
        end if;
      end if;
   RETURN 4;
   END;

   PROCEDURE lp_reg_mensaje(p_mensaje IN LONG, p_respuesta IN VARCHAR2) is
        PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
        v_respuesta ba_log_mensajeria.respuesta%type;
      BEGIN
         v_respuesta := substr(p_respuesta, 1, 4000);
         insert into ba_log_mensajeria
            (mensaje, respuesta)
         values
            (p_mensaje, v_respuesta);
         commit;
      EXCEPTION
         WHEN OTHERS THEN
            null;
      END;
   FUNCTION fu_ins_mensaje(p_cod_evento IN NUMBER, p_cod_origen IN VARCHAR2, p_mensaje IN VARCHAR2,p_titulo IN VARCHAR2, p_destino IN VARCHAR2,p_cod_persona IN VARCHAR2, p_nro_cuenta IN VARCHAR2,
                           p_fec_programada DATE DEFAULT NULL, p_enviar IN VARCHAR2 DEFAULT 'N', p_nro_documento3 IN NUMBER default 0) RETURN NUMBER IS
      v_cod_mensaje NUMBER(16) := 0;
      v_mensaje     VARCHAR2(140);
      v_titulo      VARCHAR2(45);
      v_destino     VARCHAR2(10);
      v_nro_documento3  NUMBER(3);
   BEGIN
      v_mensaje := substr(p_mensaje, 0, 140);
      v_titulo := substr(p_titulo, 0, 45);
      v_destino := nvl(substr(p_destino, 0, 10),3);
      v_nro_documento3 := substr(p_nro_documento3, 0, 15);
      
      IF (fu_obt_con_blacklist(p_cod_persona, p_cod_origen) = 'N') THEN
         BEGIN
            SELECT s_bw_not_mensajes.nextval
              INTO v_cod_mensaje
              FROM dual;

            INSERT INTO bw_not_mensajes
               (COD_MENSAJE, COD_EVENTO,COD_CLI_DESTINO, COD_ORIGEN, MENSAJE, COD_PERSONA, NRO_CUENTA, FEC_PROGRAMADO, ENVIAR,TITULO, NRO_DOCUMENTO3)
            VALUES
               (v_cod_mensaje, p_cod_evento, v_destino, p_cod_origen, v_mensaje, p_cod_persona, p_nro_cuenta, p_fec_programada, p_enviar,v_titulo, v_nro_documento3);
         EXCEPTION
            WHEN OTHERS THEN
               lp_reg_mensaje('fu_ins_mensaje:'||v_cod_mensaje||'-'||p_cod_evento||'-'||p_cod_origen||'-'||v_mensaje||'-'||p_cod_persona||'-'||p_nro_cuenta||'-'||p_fec_programada||'-'||p_enviar, SQLERRM);
               RETURN 11; --Paso algo
         END;
      ELSE
         RETURN 22;
      END IF;
      RETURN 0; --OK
   END;
   --S si la modalidad pertenece a las tarjetas gourmets
   FUNCTION lf_es_gourmet(p_cod_modalidad IN ge_cuentas.cod_modalidad%TYPE) RETURN VARCHAR2 IS
      v_cod_respuesta VARCHAR2(1) := 'N';
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_cod_respuesta
           FROM ba_cod_referencias
          WHERE dominio = 'TAR_MAD_GOURMET'
            AND val_minimo = p_cod_modalidad;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN 'N';
      END;
      RETURN v_cod_respuesta;
   END;
   -- busca informacion de una tarjeta que puede ser de debito o credito del principal
   FUNCTION fu_obt_dat_tarjeta(p_nro_tarjeta IN VARCHAR2, p_cod_persona OUT VARCHAR2, p_embozado OUT VARCHAR2, p_nro_cuenta OUT VARCHAR2,
                               p_titular OUT VARCHAR2, p_tipo OUT VARCHAR2,p_gourmet OUT VARCHAR2) RETURN NUMBER IS
      v_cod_persona VARCHAR2(10) := NULL;
      v_embozado    VARCHAR2(26) := NULL;
      v_nro_cuenta  VARCHAR2(15) := NULL;
      v_relacion    VARCHAR2(1) := NULL;
      v_tipo        VARCHAR2(1) := NULL;
      v_cod_modulo  ge_cuentas.cod_modulo%type;
      v_cod_modalidad ge_cuentas.cod_modalidad%type;
   BEGIN
     p_gourmet:='N';
      --Buscar primero en tarjetas de debito
      BEGIN

         SELECT c.cod_persona, s.embozado, s.nro_cuenta,cu.cod_modulo,cu.cod_modalidad
           INTO v_cod_persona, v_embozado, v_nro_cuenta,v_cod_modulo,v_cod_modalidad
           FROM ah_tar_debitos s, ge_cta_clientes c, ge_cuentas cu, ge_est_cuentas e
          WHERE s.fec_vencimiento > SYSDATE
            AND s.nro_tarjeta = p_nro_tarjeta
            --AND s.tar_activa = 'S'
            AND c.cod_persona = s.cod_persona
            AND c.relacion = 'P'
            AND cu.nro_cuenta = c.nro_cuenta
            AND cu.nro_cuenta = s.nro_cuenta
            AND c.cod_modulo != 7
            AND c.cod_modalidad <> 36
            AND e.cod_modulo = cu.cod_modulo
            AND e.cod_modalidad = cu.cod_modalidad
            AND e.estado = cu.estado
            AND e.activo = 'S'
            AND cu.estado <> 'X'
           -- AND s.fec_cancelacion IS NULL Problema de tarjetas duplicadas
            AND rownum = 1;

         v_tipo := 'D';
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
      END;

      IF v_cod_persona IS NULL THEN
         BEGIN
            SELECT c.cod_persona, s.nom_embozar, s.nro_cuenta,cu.cod_modulo,cu.cod_modalidad
              INTO v_cod_persona, v_embozado, v_nro_cuenta,v_cod_modulo,v_cod_modalidad
              FROM ta_tarjetas s, ge_cta_clientes c, ge_cuentas cu
             WHERE s.fec_vencimiento > SYSDATE
               AND s.nro_tarjeta = p_nro_tarjeta
               AND s.vigente = 'S'
               AND cu.nro_cuenta=c.nro_cuenta
               AND s.cod_estado = '6'
               AND s.nro_cuenta = c.nro_cuenta
               AND c.relacion = 'P'
               AND rownum = 1;
            v_tipo := 'C';

            if lf_es_gourmet(v_cod_modalidad)='S' then
               p_gourmet:='S';
            end if;
         EXCEPTION
            WHEN no_data_found THEN
               NULL;
         END;
      END IF;

      IF v_cod_persona IS NULL THEN
         RETURN 1;
      ELSE
         BEGIN
            --Informacion de la cuenta
            SELECT 'S'
              INTO v_relacion
              FROM ge_cta_clientes
             WHERE cod_persona = v_cod_persona
               AND nro_cuenta = v_nro_cuenta
               AND relacion = 'P';
         EXCEPTION
            WHEN no_data_found THEN
               v_relacion := 'N';
         END;
         p_cod_persona := v_cod_persona;
         p_embozado    := v_embozado;
         p_nro_cuenta  := v_nro_cuenta;
         p_titular     := v_embozado;
         p_titular     := v_relacion;
         p_tipo        := v_tipo;
      END IF;
      RETURN 0;
   END;

   FUNCTION fu_obt_tar_vencimiento(p_nro_cuenta IN VARCHAR2, p_cod_modulo IN VARCHAR2, p_cod_modalidad IN VARCHAR2) RETURN DATE IS
      v_fec_inicio      DATE;
      v_fec_vencimiento DATE;
      v_fec_cierre   DATE;
      v_tip_cierre      ta_cta_tarjetas.cod_tip_cierre%TYPE;
      v_monto3          ta_cta_tarjetas.sal_pag_minimo%TYPE;
   BEGIN
      BEGIN
         SELECT fec_ult_cierre, fec_vct_ult_cierre, cod_tip_cierre, decode(nvl(sal_pag_minimo, 0), 0, nvl(mto_mora, 0), nvl(sal_pag_minimo, 0))
           INTO v_fec_inicio, v_fec_vencimiento, v_tip_cierre, v_monto3
           FROM ta_cta_tarjetas
          WHERE nro_cuenta = p_nro_cuenta;

         SELECT MIN(fec_cierre)
           INTO v_fec_cierre
           FROM ta_cal_cierres v
          WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
            AND v.cod_modulo = p_cod_modulo
            AND v.cod_modalidad = p_cod_modalidad
            AND v.cod_tip_cierre = v_tip_cierre
            AND fec_cierre > v_fec_inicio;

         -- si ya pago se busca el siguiente cierre, o ya hay nuevo cierre
         IF v_monto3 = 0 THEN
            SELECT MIN(fec_cierre), MIN(fec_vencimiento)
              INTO v_fec_cierre, v_fec_vencimiento
              FROM ta_cal_cierres v
             WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
               AND v.cod_modulo = p_cod_modulo
               AND v.cod_modalidad = p_cod_modalidad
               AND v.cod_tip_cierre = v_tip_cierre
               AND fec_cierre > v_fec_inicio;
         END IF;

         -- Si no existe para esa modalidad busco el vcto general
         IF v_fec_cierre IS NULL THEN
            SELECT MIN(fec_cierre), MIN(fec_vencimiento)
              INTO v_fec_cierre, v_fec_vencimiento
              FROM ta_cal_cierres v
             WHERE cod_ent_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD')
               AND v.cod_modulo = p_cod_modulo
               AND v.cod_modalidad IS NULL
                  --AND v.cod_tip_cierre = v_tip_cierre
               AND fec_cierre > v_fec_inicio;
         END IF;


      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END;
      RETURN v_fec_vencimiento;
   END;



   FUNCTION lf_obt_cod_evento(p_cod_tip_evento IN bw_not_tip_eventos.cod_tip_evento%TYPE) RETURN NUMBER IS
      v_cod_evento NUMBER := 0;
   BEGIN
      BEGIN
         SELECT cod_evento
           INTO v_cod_evento
           FROM bw_not_eventos e
          WHERE e.cod_tip_evento = p_cod_tip_evento
            AND ROWNUM = 1;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN - 1;
      END;
      RETURN v_cod_evento;
   END;

   --Busca la persona suscripta y envia la notificacion
   -- La persona tiene que tener destinos configurados
   FUNCTION fu_not_env_evento(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_tip_evento IN bw_not_tip_eventos.cod_tip_evento%TYPE,
                              p_cod_origen IN VARCHAR2) RETURN NUMBER IS
      v_template   bw_not_mensajes.mensaje%TYPE;
      v_cod_evento bw_not_eventos.cod_evento%TYPE;
      v_envio      VARCHAR2(1) := 'S';
   BEGIN
      IF fu_obt_suscripcion(p_cod_persona) = 'S' OR p_cod_tip_evento in ('NOTBAJA','NOTALTA') THEN
      IF fu_obt_not_template(p_cod_tip_evento, v_template) <> 0 THEN
         RETURN 20;
      END IF;
      v_cod_evento := lf_obt_cod_evento(p_cod_tip_evento);
         BEGIN --Verifica que no existe un mensaje igual en los ultimos 5 min
            SELECT 'N'
              INTO v_envio
              FROM bw_not_mensajes m
             WHERE m.cod_persona = p_cod_persona
               AND m.mensaje = v_template
               AND m.fec_insercion >= SYSDATE - INTERVAL '5' MINUTE;
         EXCEPTION
            WHEN OTHERS then
               v_envio := 'S' ; 
          END; 
          IF v_envio = 'S'  THEN
      RETURN fu_ins_mensaje(v_cod_evento, p_cod_origen, v_template, p_cod_persona, '0', NULL, 'S');
      ELSE
               RETURN 2;
         END IF;
      ELSE
         RETURN 7;
      END IF;
   END;

FUNCTION fu_not_tar_men_vencimientos RETURN NUMBER IS
   v_cod_evento     bw_not_eventos.cod_evento%TYPE;
   v_horario        bw_not_eventos.horario%TYPE;
   v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
   v_mandatorio     bw_not_eventos.mandatorio%TYPE;
   v_template       bw_not_tip_eventos.template%TYPE;
   v_mensaje        bw_not_mensajes.mensaje%TYPE;
   v_result         VARCHAR2(1); -- return 0 exito y 1 fracaso}
   v_result2        NUMBER(1);
   v_fec_programada DATE; --Fecha programada de envío
      v_ret            NUMBER(3);
   --Tarjetas de créditos a vencer
   CURSOR c_tarVenc IS
      SELECT DISTINCT tc.nro_cuenta, TA.Nro_Tarjeta, cc.cod_persona, tc.cod_modulo, tc.cod_modalidad,
                      lf_obt_fec_cierre(tc.nro_cuenta, tc.cod_modulo, tc.cod_modalidad) AS fec_cierre,
                      fu_obt_tar_vencimiento(tc.nro_cuenta, tc.cod_modulo, tc.cod_modalidad) tar_vec
        FROM TA_TARJETAS TA, TA_CTA_TARJETAS TC, GE_CTA_CLIENTES CC
       WHERE TA.NRO_CUENTA = TC.NRO_CUENTA
         AND TA.VIGENTE = 'S'
         AND TA.Cod_Estado = 6
         AND TA.FEC_VENCIMIENTO > SYSDATE
         AND paw_not.fu_obt_tar_vencimiento(tc.nro_cuenta, tc.cod_modulo, tc.cod_modalidad) = trunc(SYSDATE) + 1
         AND CC.NRO_CUENTA = TC.NRO_CUENTA
         AND CC.COD_PERSONA = TA.COD_PERSONA
         and cc.cod_modalidad not in (501,55)
         AND CC.RELACION = 'P'
         AND (nvl(tc.mto_mora, 0) + nvl(tc.sal_pag_minimo, 0)) > 0
         AND CC.COD_PERSONA IN (SELECT COD_PERSONA
                                  FROM BW_NOT_CLI_SUSCRIPTOS 
                                 WHERE ACTIVO = 'S');
BEGIN
   --    v_cod_persona    := p_cod_persona;


   IF fu_obt_not_template('TCFECVEN', v_template) <> 0 THEN
      RETURN 20;
   END IF;

   FOR i IN c_tarVenc
   LOOP
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, i.nro_cuenta, 'TCFECVEN', v_cod_evento, v_horario, 1,600, v_ocurrencia, v_mandatorio);
      --v_fec_programada := lf_obt_fec_sig_evento(i.cod_persona, i.nro_cuenta, i.cod_evento);
      v_fec_programada :=trunc(i.tar_vec) - 1+((1/24)*8);

           v_mensaje := utl_lms.format_message(v_template, lf_obt_ult_tarjeta(i.nro_tarjeta), TO_CHAR(i.tar_vec, 'dd/mm'));
      IF lf_obt_men_duplicado(i.cod_persona, v_mensaje, 10, v_fec_programada) = 0 THEN
           v_result  := fu_ins_mensaje(v_cod_evento, 'TCFECVEN', v_mensaje, i.cod_persona, i.nro_cuenta, v_fec_programada, 'S');
           v_result2 := lf_act_fec_ult_evento(i.cod_persona, i.nro_cuenta, v_cod_evento, v_fec_programada);
       end if;
   END LOOP;
   IF v_result = 0 THEN
      RETURN 0;
   ELSE
      RETURN 1;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 1;
END;


FUNCTION fu_not_tar_men_cierres RETURN NUMBER IS
   v_result         VARCHAR2(1); -- return 0 exito y 1 fracaso}
   v_result2        NUMBER(1);
   v_fec_programada DATE; --Fecha programada de envío
   v_cod_evento     bw_not_eventos.cod_evento%TYPE;
   v_horario        bw_not_eventos.horario%TYPE;
   v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
   v_mandatorio     bw_not_eventos.mandatorio%TYPE;
   v_template       bw_not_tip_eventos.template%TYPE;
   v_mensaje        bw_not_mensajes.mensaje%TYPE;
   v_ret            NUMBER(3);
   CURSOR c_tarCierre IS
      SELECT DISTINCT tc.nro_cuenta, TA.Nro_Tarjeta, cc.cod_persona, tc.cod_modulo, tc.cod_modalidad,
                      lf_obt_fec_cierre(tc.nro_cuenta, tc.cod_modulo, tc.cod_modalidad) AS fec_cierre,
                      fu_obt_tar_vencimiento(tc.nro_cuenta, tc.cod_modulo, tc.cod_modalidad) tar_vec
        FROM TA_TARJETAS TA, TA_CTA_TARJETAS TC, GE_CTA_CLIENTES CC
       WHERE TA.NRO_CUENTA = TC.NRO_CUENTA
         AND TA.VIGENTE = 'S'
         AND TA.Cod_Estado = 6
         AND TA.FEC_VENCIMIENTO > SYSDATE
         AND CC.NRO_CUENTA = TC.NRO_CUENTA
         AND CC.COD_PERSONA = TA.COD_PERSONA
         and cc.cod_modalidad not in (501,55)
         AND paw_not.lf_obt_fec_cierre(tc.nro_cuenta, tc.cod_modulo, tc.cod_modalidad) = trunc(SYSDATE) + 1
         AND CC.RELACION = 'P'
         AND CC.COD_PERSONA IN (SELECT COD_PERSONA
                                  FROM BW_NOT_CLI_SUSCRIPTOS
                                   WHERE ACTIVO = 'S');


BEGIN
   IF fu_obt_not_template('TCFECCIER', v_template) <> 0 THEN
      RETURN 20;
   END IF;

   FOR i IN c_tarCierre
   LOOP
      v_ret := fu_obt_eve_suscripcion(i.cod_persona, i.nro_cuenta, 'TCFECCIER', v_cod_evento, v_horario, 1,'600', v_ocurrencia, v_mandatorio);
      --v_fec_programada := lf_obt_fec_sig_evento(i.cod_persona, i.nro_cuenta, 8);
      v_fec_programada :=trunc(i.fec_cierre) - 1+((1/24)*8);
        --BBVA le informa: al cierre de la fecha %s sera el corte de facturacion de la tarjeta de credito %s, con vcto. %s.

      IF v_fec_programada IS NOT NULL AND v_ret = 0 THEN
         --
         -- 
           --tar_vec
           v_mensaje := utl_lms.format_message(v_template,
                                             TO_CHAR(i.fec_cierre, 'dd/mm'),
                                               lf_obt_ult_tarjeta(i.nro_tarjeta),
                                               TO_CHAR(i.tar_vec, 'dd/mm'));
         IF lf_obt_men_duplicado(i.cod_persona, v_mensaje, 10, v_fec_programada) = 0 THEN
         v_result  := fu_ins_mensaje(v_cod_evento, 'TCFECCIER', v_mensaje, i.cod_persona, i.nro_cuenta, v_fec_programada, 'S');
         v_result2 := lf_act_fec_ult_evento(i.cod_persona, i.nro_cuenta, v_cod_evento, v_fec_programada);
      END IF;
      END IF;
   END LOOP;
   IF v_result = 0 THEN
      RETURN 0;
   ELSE
      RETURN 1;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 1;
END;

--Reconoce los eventos de pago de tarjetas
   --retorna 20 en caso de error con el template
   FUNCTION lf_not_tar_pagos(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                             ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                             card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT, response_code VARCHAR2,
                             origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                             transaction_type VARCHAR2, payment_source VARCHAR2,p_gourmet VARCHAR2) RETURN NUMBER IS
      v_cod_evento     bw_not_eventos.cod_evento%TYPE;
      v_horario        bw_not_eventos.horario%TYPE;
      v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio     bw_not_eventos.mandatorio%TYPE;
      v_template       bw_not_tip_eventos.template%TYPE;
      v_mensaje        bw_not_mensajes.mensaje%TYPE;
      v_ret            NUMBER(3);
   BEGIN
      IF upper(transaction_type) = 'CREDITO' THEN
         --verifica suscripcion compra comercio nacional tarjeta de credito            
         -- si el pais es 600 es nacional
         v_ret := fu_obt_eve_suscripcion(p_cod_persona,
                                         p_nro_cuenta,
                                         'TARPAGO',
                                         v_cod_evento,
                                         v_horario,
                                         transaction_amount,
                                         currency_code,
                                         v_ocurrencia,
                                         v_mandatorio);
         IF v_ret = 0 THEN
            --esta suscripto
            IF fu_obt_not_template('TARPAGO', v_template, response_code) = 0 THEN
               --BBVA le informa: registramos el pago de %s %s a la tarjeta de crédito %s, realizado el dia %s.
               v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code),
                                                          lf_obt_mto_formateado(transaction_amount, currency_code),lf_obt_ult_tarjeta(card_number),
                                                          lf_obt_fec_tra_formateado(transaction_date)),0,g_men_longitud);

               IF p_gourmet = 'S' THEN
                  v_mensaje := REPLACE(v_mensaje, 'la tarjeta de credito', 'su gourmet card');
                  v_mensaje := REPLACE(v_mensaje, 'pago', 'credito');
               END IF;               
               v_ret := fu_ins_mensaje(v_cod_evento, 'TARPAGO', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
            ELSE
               RETURN 20;
            END IF;
         END IF;
         RETURN v_ret;
      END IF;
      RETURN 10;
   END;

--Calcula y retorna la fecha en la que se tiene que enviar la siguiente notificacion
FUNCTION lf_obt_fec_sig_evento(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
                               p_cod_evento IN bw_not_eventos.cod_evento%TYPE) RETURN DATE IS
   --datos suscripcion
   v_horario       bw_not_suscripciones.horario%TYPE;
   v_mto_minimo    bw_not_suscripciones.mto_minimo%TYPE;
   v_frecuencia    bw_not_suscripciones.frecuencia%TYPE;
   v_fec_ult_envio bw_not_suscripciones.fec_ult_envio%TYPE;
   v_activo        bw_not_suscripciones.activo%TYPE;
   --datos del evento
   v_eve_horario            bw_not_eventos.horario%TYPE;
   v_eve_ocurrencia         bw_not_eventos.ocurrencia%TYPE;
   v_eve_mto_minimo         bw_not_eventos.mto_minimo%TYPE;
   v_eve_mandatorio         bw_not_eventos.mandatorio%TYPE;
   v_eve_cod_tiv_eve_evento bw_not_eventos.cod_tip_evento%TYPE;
   v_dias                   NUMBER(3):=0;
   --variables aux 
   v_siguiente DATE := TRUNC(SYSDATE);
   v_horas     NUMBER(5,3) := 0;

BEGIN
   BEGIN
      --obtener datos de la suscripcion
      SELECT horario, mto_minimo, frecuencia, TRUNC(fec_ult_envio), activo
        INTO v_horario, v_mto_minimo, v_frecuencia, v_fec_ult_envio, v_activo
        FROM bw_not_suscripciones s
       WHERE s.cod_persona = p_cod_persona
         AND s.nro_cuenta = p_nro_cuenta
         AND s.cod_evento = p_cod_evento;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;
   IF v_activo = 'N' THEN
      RETURN NULL;
   END IF;
   --Si ya se envio
   IF v_fec_ult_envio IS NULL THEN
      v_siguiente := trunc(sysdate);
   else
     v_dias:= lf_obt_dia_frecuencia(v_frecuencia);
     if trunc(sysdate) < v_fec_ult_envio+v_dias then
       return null;
     end if;
   END IF;
   --obtener datos del evento
   IF lf_obt_con_evento(p_cod_evento, v_eve_horario, v_eve_ocurrencia, v_eve_mto_minimo, v_eve_mandatorio, v_eve_cod_tiv_eve_evento) <> 0 THEN
      RETURN NULL;
   END IF;

   IF v_eve_ocurrencia = 'S' THEN
      --Si es por ocurrencia retorna ahora
      RETURN sysdate;
   END IF;


   --si se personaliza el horario 
   IF v_eve_horario = 'S' THEN
      CASE v_horario
         WHEN 'M' THEN
            v_horas := round((1/24)*8,3); --mañana desde las 8
         WHEN 'T' THEN
            v_horas := round((1/24)*14,3); --tarde desde las 14
         WHEN 'N' THEN
            v_horas := round((1/24)*19,3); --noche desde las 19
            ELSE
               v_horas := round((1 / 24) * 8, 3);
      END CASE;
   ELSE
      v_horas := 0; --no importa la hora
   END IF;

  return v_siguiente+v_horas;
END;


   --Reconoce los eventos de compra en comercio nacionales e internacionales y genera los avisos
   --retorna 20 en caso de error con el template
   FUNCTION lf_not_tar_com_comercios(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                                     ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                                     entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount IN FLOAT,
                                     response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                                     provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2, p_gourmet VARCHAR2,
                                     product_brand VARCHAR2, brand_code VARCHAR2)
      RETURN NUMBER IS
      v_cod_evento     bw_not_eventos.cod_evento%TYPE;
      v_horario        bw_not_eventos.horario%TYPE;
      v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio     bw_not_eventos.mandatorio%TYPE;
      v_template       bw_not_tip_eventos.template%TYPE;
      v_mensaje        bw_not_mensajes.mensaje%TYPE;
      v_nom_comercio   VARCHAR2(40);
      v_ret            NUMBER(3);
      v_des_tip_tarjeta VARCHAR2(20);
      v_rechazo VARCHAR2(1):='N';
   BEGIN
      --verifica suscripcion compra comercio nacional tarjeta de credito            
      v_nom_comercio := lf_obt_com_formateado(commerce_name);
      v_des_tip_tarjeta := lf_obt_des_tip_tarjeta(p_tip_tarjeta);
      if(response_code<>'00') then
         v_rechazo:='S';
      end if;
      IF country_code = 600 THEN
         -- si el pais es 600 es nacional
         IF provide_service_code ='STAR' AND NVL(product_brand, 'X') =  'PMO' AND NVL(brand_code, 'X') = 'ENT' THEN
            v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'OSTCOMNAC', v_cod_evento, v_horario, transaction_amount, v_ocurrencia, v_mandatorio,v_rechazo);
            IF v_ret = 0 THEN
               IF fu_obt_not_template('OSTCOMNAC', v_template, response_code) = 0 THEN
                  v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(transaction_amount, currency_code),
                                                      substr(v_nom_comercio, 0, 30), lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);
                  v_ret := fu_ins_mensaje(v_cod_evento, 'OSTCOMNAC', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               ELSE
                  RETURN 20;
               END IF;
            END IF;
         ELSE
         v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TACOMNAC', v_cod_evento, v_horario, transaction_amount, v_ocurrencia, v_mandatorio,v_rechazo);
         IF v_ret = 0 THEN
            --esta suscripto
            IF fu_obt_not_template('TACOMNAC', v_template, response_code) = 0 THEN
               /* Ejemplo de mensaje
               BBVA le informa: la compra de Gs 99.999.999 en 12345678901234567890, con la tarjeta de crédito *1234  el DD/MM HH:MM.
               BBVA le informa: la compra de %s %s en %s, con la tarjeta de %s %s  el %d.
               BBVA le informa: la compra de GS 11,000 en crédito, con la tarjeta de *7079 COMERCION PARAGUAYO  el 04/06 21:06.
               */
               v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(transaction_amount, currency_code),
                                                          v_nom_comercio, v_des_tip_tarjeta, lf_obt_ult_tarjeta(card_number),
                                                          lf_obt_fec_tra_formateado(transaction_date)),0,g_men_longitud);

               IF p_gourmet = 'S' THEN
                  v_mensaje := REPLACE(v_mensaje, 'de credito', '');
               END IF;
               v_ret := fu_ins_mensaje(v_cod_evento, 'TACOMNAC', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
            ELSE
               RETURN 20;
               END IF;
            END IF;
         END IF;
         RETURN v_ret;
      ELSE
         v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TACOMINT', v_cod_evento, v_horario, transaction_amount, v_ocurrencia, v_mandatorio,v_rechazo);
         IF v_ret = 0 THEN
            --esta suscripto
            IF fu_obt_not_template('TACOMINT', v_template, response_code) = 0 THEN
               --El BBVA le informa que se ha realizado una operación en %s por valor de Gs %s con su tarjeta %s
               v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code),
                                                          lf_obt_mto_formateado(transaction_amount, currency_code), substr(v_nom_comercio, 0, 30),
                                                          v_des_tip_tarjeta, lf_obt_ult_tarjeta(card_number), lf_obt_fec_tra_formateado(transaction_date)),0,g_men_longitud);          
               v_ret     := fu_ins_mensaje(v_cod_evento, 'TACOMINT', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');       
            ELSE
               RETURN 20;
            END IF;
         END IF;
         RETURN v_ret;
      END IF;
   END;


   --Reconoce los eventos vuelto comercio nacionales y genera los avisos
   --retorna 20 en caso de error con el template
   --TAVUEPOS
   FUNCTION lf_not_tar_vuelto(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                              ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                              entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount IN FLOAT,
                              response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                              provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2, p_gourmet VARCHAR2,
                              product_brand VARCHAR2, brand_code VARCHAR2)
      RETURN NUMBER IS
      v_cod_evento     bw_not_eventos.cod_evento%TYPE;
      v_horario        bw_not_eventos.horario%TYPE;
      v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio     bw_not_eventos.mandatorio%TYPE;
      v_template       bw_not_tip_eventos.template%TYPE;
      v_mensaje        bw_not_mensajes.mensaje%TYPE;
      v_nom_comercio   VARCHAR2(40);
      v_ret            NUMBER(3);
      v_des_tip_tarjeta VARCHAR2(20);
      v_rechazo VARCHAR2(1):='N';
      v_response_code  VARCHAR2(2);
      v_monto          ta_ban_transaciones.transaction_amount%TYPE;
   BEGIN
      --verifica suscripcion vuelto comercio nacional tarjeta de credito            
      v_nom_comercio := lf_obt_com_formateado(commerce_name);
      v_des_tip_tarjeta := lf_obt_des_tip_tarjeta(p_tip_tarjeta);
      v_response_code   := response_code;
      v_monto           := transaction_amount;
      IF transaction_amount < 0 THEN
         v_response_code := '11';
         v_monto         := v_monto * -1;
      END IF;
      if(v_response_code<>'00') then
         v_rechazo:='S';
      end if;


      v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TAVUEPOS', v_cod_evento, v_horario, v_monto, v_ocurrencia, v_mandatorio,v_rechazo);
      IF v_ret = 0 THEN
         --esta suscripto
         IF fu_obt_not_template('TAVUEPOS', v_template, v_response_code) = 0 THEN
            /* Ejemplo de mensaje
            BBVA le informa: la compra de Gs 99.999.999 en 12345678901234567890, con la tarjeta de crédito *1234  el DD/MM HH:MM.
            BBVA le informa: la compra de %s %s en %s, con la tarjeta de %s %s  el %d.
            BBVA le informa: la compra de GS 11,000 en crédito, con la tarjeta de *7079 COMERCION PARAGUAYO  el 04/06 21:06.
               */
            v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(v_monto, currency_code),
                                                       v_nom_comercio, v_des_tip_tarjeta, lf_obt_ult_tarjeta(card_number),
                                                       lf_obt_fec_tra_formateado(transaction_date)),0,g_men_longitud);

            v_ret := fu_ins_mensaje(v_cod_evento, 'TAVUEPOS', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
          ELSE
            RETURN 20;
          END IF;
       END IF;
       RETURN v_ret;
   END;
   --Reconoce los eventos de uso de ATM
   --retorna 20 en caso de error con el template
   FUNCTION lf_not_tar_uso_atm(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                            ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                            card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT, response_code VARCHAR2,
                            origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                            transaction_type VARCHAR2, payment_source VARCHAR2, product_brand VARCHAR2 DEFAULT NULL, brand_code VARCHAR2 DEFAULT NULL)
                            RETURN NUMBER IS
      v_cod_evento     bw_not_eventos.cod_evento%TYPE;
      v_horario        bw_not_eventos.horario%TYPE;
      v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio     bw_not_eventos.mandatorio%TYPE;
      v_template       bw_not_tip_eventos.template%TYPE;
      v_mensaje        bw_not_mensajes.mensaje%TYPE;
      v_nom_comercio   VARCHAR2(40);
      v_ret            NUMBER(3);
      v_des_tip_tarjeta VARCHAR2(20);
      v_monto          ta_ban_transaciones.transaction_amount%TYPE;
      v_response_code  VARCHAR2(2);
      v_rechazo        VARCHAR2(1);
   BEGIN
      --verifica suscripcion compra comercio nacional tarjeta de credito            
      v_nom_comercio := lf_obt_com_formateado(commerce_name);
      v_des_tip_tarjeta := lf_obt_des_tip_tarjeta(p_tip_tarjeta);
      v_response_code   := response_code;
      v_monto           := transaction_amount;

   IF transaction_amount < 0 THEN
      v_response_code := '11';
      v_monto         := v_monto * -1;
   END IF;
      if(response_code<>'00') then
         v_rechazo:='S';
      end if;      
      CASE upper(provide_service_code)
         WHEN 'TD' THEN
          IF country_code = 600 THEN
            --operacion con tarjeta de debito
         v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TDATMUSO', v_cod_evento, v_horario, v_monto, v_ocurrencia, v_mandatorio,v_rechazo);
            IF v_ret = 0 THEN
               --esta suscripto
            IF fu_obt_not_template('TDATMUSO', v_template, v_response_code) = 0 THEN
/*
BBVA le informa: la extracción de efectivo por Gs 9.999.999 en 12345678901234567890, con la tarjeta de débito *1234  el DD/MM HH:MM.
BBVA le informa: la extracción de efectivo por %s %s en %s, con la tarjeta de %s %s  el %s.

*/                
                  v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(v_monto, currency_code),
                                                             v_nom_comercio, v_des_tip_tarjeta, lf_obt_ult_tarjeta(card_number),
                                                             lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);


                  v_ret := fu_ins_mensaje(v_cod_evento, 'TDATMUSO', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               ELSE
                  RETURN 20;
               END IF;
            END IF;
          ELSE -- Internacional
            v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TDATMINT', v_cod_evento, v_horario, v_monto, v_ocurrencia, v_mandatorio,v_rechazo);
            IF v_ret = 0 THEN
               --esta suscripto
               IF fu_obt_not_template('TDATMINT', v_template, v_response_code) = 0 THEN
                  v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(v_monto, currency_code),
                                                             v_nom_comercio, v_des_tip_tarjeta, lf_obt_ult_tarjeta(card_number),
                                                             lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);
                  v_ret := fu_ins_mensaje(v_cod_evento, 'TDATMINT', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               ELSE
                  RETURN 20;
               END IF;
            END IF;
          END IF;
         WHEN 'TC' THEN
           IF country_code = 600 THEN
            --operacion con tarjeta de debito
         v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TCATMUSO', v_cod_evento, v_horario, v_monto, v_ocurrencia, v_mandatorio,v_rechazo);
            IF v_ret = 0 THEN
               --esta suscripto
            IF fu_obt_not_template('TCATMUSO', v_template, v_response_code) = 0 THEN
                  --El BBVA le informa que se ha realizado una operación en %s por valor de Gs %s con su tarjeta %s
                  v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(v_monto, currency_code),
                                                             v_nom_comercio, v_des_tip_tarjeta, lf_obt_ult_tarjeta(card_number),
                                                             lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);               
                  v_ret := fu_ins_mensaje(v_cod_evento, 'TCATMUSO', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               ELSE
                  RETURN 20;
               END IF;
            END IF;
     ELSE -- Internacional
            --operacion con tarjeta de debito
            v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TCATMINT', v_cod_evento, v_horario, v_monto, v_ocurrencia, v_mandatorio,v_rechazo);
            IF v_ret = 0 THEN
               --esta suscripto
               IF fu_obt_not_template('TCATMINT', v_template, v_response_code) = 0 THEN
                  --El BBVA le informa que se ha realizado una operación en %s por valor de Gs %s con su tarjeta %s
                  v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(v_monto, currency_code),
                                                             v_nom_comercio, v_des_tip_tarjeta, lf_obt_ult_tarjeta(card_number),
                                                             lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);               
                  v_ret := fu_ins_mensaje(v_cod_evento, 'TCATMINT', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               ELSE
                  RETURN 20;
               END IF;
            END IF; 
      END IF;
         WHEN 'STAR' THEN
          --operaciones sin tarjetas (pago móvil)
          IF product_brand = 'PMO' AND brand_code = 'ENT' THEN
             v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'OSTATMUSO', v_cod_evento, v_horario, v_monto, v_ocurrencia, v_mandatorio,v_rechazo);
             IF v_ret = 0 THEN
               IF fu_obt_not_template('OSTATMUSO', v_template, v_response_code) = 0 THEN
                  v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(v_monto, currency_code),
                                                   substr(v_nom_comercio, 0,  30), lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);
                  v_ret := fu_ins_mensaje(v_cod_evento, 'OSTATMUSO', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               ELSE
                  RETURN 20;
               END IF;
               END IF;
            END IF;
      END CASE;
      RETURN v_ret;
   END;

   --Reconoce los eventos de uso de ATM
   --retorna 20 en caso de error con el template
   FUNCTION lf_not_tar_uso_web(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                               ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                               card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT, response_code VARCHAR2,
                               origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                               transaction_type VARCHAR2, payment_source VARCHAR2) RETURN NUMBER IS
      v_cod_evento     bw_not_eventos.cod_evento%TYPE;
      v_horario        bw_not_eventos.horario%TYPE;
      v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio     bw_not_eventos.mandatorio%TYPE;
      v_template       bw_not_tip_eventos.template%TYPE;
      v_mensaje        bw_not_mensajes.mensaje%TYPE;
      v_ret            NUMBER(3);
   BEGIN



      --verifica suscripcion compra comercio nacional tarjeta de credito            
      CASE upper(provide_service_code)
         WHEN '0000' THEN
            --operacion con tarjeta de debito
            v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'WEBSALDO', v_cod_evento, v_horario, transaction_amount,currency_code, v_ocurrencia,
                                            v_mandatorio);
            IF v_ret = 0 THEN
               --esta suscripto
               IF fu_obt_not_template('WEBSALDO', v_template) = 0 THEN
                  --El BBVA le informa que se ha realizado una operación en %s por valor de Gs %s con su tarjeta %s
                  v_mensaje := utl_lms.format_message(v_template, lf_obt_ult_tarjeta(card_number));

                  v_ret := fu_ins_mensaje(v_cod_evento, 'WEBSALDO', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               ELSE
                  RETURN 20;
               END IF;
            END IF;
         ELSE
            NULL;
      END CASE;
      RETURN v_ret;
   END;




   /*
   Retorna:
   0 En caso de exito
   10 Si no encuentra informacion de la tarjeta
   11 El cliente no esta suscripto a notificaciones
   30 si el mensaje es muy viejo
   */
   FUNCTION fu_not_men_tarjetas(ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                                entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount NUMBER,
                                response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                                provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2,
                                product_brand VARCHAR2 DEFAULT NULL, brand_code VARCHAR2 DEFAULT NULL, customer_account_number VARCHAR2, payment_method VARCHAR2) RETURN NUMBER IS


      v_cod_persona ba_personas.cod_persona%TYPE;

      v_embozado   VARCHAR2(120);
      v_nro_cuenta VARCHAR2(20);
      v_titular    VARCHAR2(30);
      v_tipo       VARCHAR2(2);
      v_ret        NUMBER(3) := 0;
      v_suscripto  VARCHAR2(2);
      v_ser_code   ta_ban_transaciones.service_code%TYPE;
      v_operacion  VARCHAR2(30);
      v_gourmet    VARCHAR2(1);
      v_response_code   VARCHAR2(2);
      v_monto           ta_ban_transaciones.transaction_amount%type;
      v_direccion      varchar2(300);
      cursor c_titulares (p_nro_cuenta varchar2) is
         SELECT cod_persona
           FROM ge_cta_clientes
          WHERE nro_cuenta = p_nro_cuenta;

      FUNCTION lf_not_men_tarjetas(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_tipo IN VARCHAR2,
                                   ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                                   card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount NUMBER, response_code VARCHAR2,
                                   origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                                   transaction_type VARCHAR2, payment_source VARCHAR2,p_gourmet VARCHAR2,
                                   product_brand VARCHAR2 DEFAULT NULL, brand_code VARCHAR2 DEFAULT NULL, payment_method VARCHAR2 DEFAULT NULL) RETURN NUMBER IS
      BEGIN

         --Verifica que este suscripto a notificaciones
         v_suscripto := fu_obt_suscripcion(p_cod_persona);

         if transaction_date< sysdate-2 then
            return 30;
         end if;

         IF (v_suscripto <> 'S') THEN
           IF upper(transaction_type) = 'RETIRO EFECTIVO' and device_type <> 'POS' and 
              upper(provide_service_code) = 'TC' and country_code = 600 then
              v_direccion := substr(paw_not.fu_obt_cli_des_activo(p_cod_persona), 1, 200);
              v_ret := paw_not.fu_alt_notificacion(p_cod_persona, v_direccion);
           ELSE
              RETURN 11; --Sino esta suscripto salimos
           END IF;
         END IF;

         v_ser_code := upper(service_code);
         --Reconocer compras en comercios 


         CASE upper(transaction_type)
           when 'REV. RETIRO EFECTIVO' THEN
             if device_type = 'POS' then
                 v_ret := lf_not_tar_vuelto(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                            entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                            device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
                                            product_brand, brand_code);
             else
                  v_ret := lf_not_tar_uso_atm(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                              entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                              device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,
                                              product_brand, brand_code);
             end if;  


            WHEN 'RETIRO EFECTIVO' THEN
              if device_type = 'POS' then
                 v_ret := lf_not_tar_vuelto(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                            entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                            device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
                                            product_brand, brand_code);
              else
                 v_ret := lf_not_tar_uso_atm(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                             entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                             device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,
                                             product_brand, brand_code);
              end if; 
            WHEN 'CREDITO' THEN
               v_ret := lf_not_tar_pagos(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                         entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code, device_type,
                                         service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet);
            WHEN 'COMPRA' THEN
               v_ret := lf_not_tar_com_comercios(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                                 entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                                 device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
                                                 product_brand, brand_code);
            WHEN 'REV. COMPRA' THEN
               v_ret := lf_not_tar_com_comercios(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                                 entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                                 device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
             product_brand, brand_code);

            WHEN 'CONF. DE PREAUTORIZACION' THEN
               v_ret := lf_not_tar_com_comercios(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                                 entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                                 device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
             product_brand, brand_code); 
            when 'TRANSFERENCIA' then
               v_ret := lf_not_tar_transferencias(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                            entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                                 device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,
                                                 product_brand, brand_code);
            when 'REV. TRANSFERENCIA' then
               v_ret := lf_not_tar_transferencias(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                                  entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                                  device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,
                                                  product_brand, brand_code);
            WHEN 'DEBITO AUTOMATICO' THEN
               v_ret := lf_not_tar_deb_automatico(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                                  entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                                  device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source);
           when 'REV. DEBITO AUTOMATICO'  then
               v_ret := lf_not_tar_deb_automatico(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                                  entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                                  device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source);
            WHEN 'PAGO DE SERVICIO' THEN
               v_ret := lf_not_tar_debitos(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                           entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                              device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
                                              product_brand, brand_code, payment_method);
            when 'REV. PAGO DE SERVICIO' then --Rev. Pago de Servicio
                    v_ret := lf_not_tar_debitos(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                              entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                              device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
                                              product_brand, brand_code, payment_method);

            when 'CAMBIO DE PIN' then
                    v_ret := lf_not_tar_cam_pin(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                              entity_code, card_number, currency_code, country_code, 5000, response_code, origin_code,
                                                device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,
                                                product_brand, brand_code);
            WHEN 'PAGO' THEN
               v_ret := lf_not_tar_debitos(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                           entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                              device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
                                              product_brand, brand_code, payment_method);
            when 'REV. PAGO' then                                  
                    v_ret :=lf_not_tar_debitos(p_cod_persona, p_nro_cuenta, p_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                              entity_code, card_number, currency_code, country_code, transaction_amount, response_code, origin_code,
                                              device_type, service_code, provide_service_code, mcc_code, transaction_type, payment_source,p_gourmet,
                                              product_brand, brand_code, payment_method);
               ELSE
               NULL;
            END CASE;



         RETURN v_ret;
      END;

   BEGIN

      v_response_code:=response_code;
      v_monto           := transaction_amount;
      IF transaction_amount < 0 THEN
         v_response_code := '11';
         v_monto := v_monto * -1;
      END IF;      

      IF (NVL(provide_service_code, 'X') ='STAR' AND NVL(product_brand, 'X') =  'PMO' AND NVL(brand_code, 'X') = 'ENT') OR
         (NVL(payment_method, 'X') = '04' ) THEN
        v_tipo := 'D';
        v_gourmet := 'N';
        --si es pago de extracto obtener dato de la cuenta a partir del numero de tarjeta
        IF upper(transaction_type) = 'CREDITO' THEN
          v_ret := fu_obt_dat_tarjeta(card_number, v_cod_persona, v_embozado, v_nro_cuenta, v_titular, v_tipo,v_gourmet);
        ELSE
          v_nro_cuenta := LPAD(customer_account_number, 10, '0');
        END IF;
      ELSE
        v_ret := fu_obt_dat_tarjeta(card_number, v_cod_persona, v_embozado, v_nro_cuenta, v_titular, v_tipo,v_gourmet);
        IF v_ret <> 0 THEN
           RETURN 10; --No se encuentra datos de la tarjeta
        END IF;
      END IF;
      if v_tipo='C' then
         RETURN lf_not_men_tarjetas(v_cod_persona, v_nro_cuenta, v_tipo, ticket_number, transaction_date, commerce_name, authorization_number, entity_code,
                                    card_number, currency_code, country_code, v_monto, v_response_code, origin_code, device_type, service_code,
                                    provide_service_code, mcc_code, transaction_type, payment_source,v_gourmet, product_brand, brand_code, payment_method);
     else

   FOR i IN c_titulares(v_nro_cuenta)
   LOOP
            v_ret := lf_not_men_tarjetas(i.cod_persona, v_nro_cuenta, v_tipo, ticket_number, transaction_date, commerce_name, authorization_number,
                                         entity_code, card_number, currency_code, country_code, v_monto, v_response_code, origin_code, device_type,
                                         service_code, provide_service_code, mcc_code, transaction_type, payment_source,v_gourmet, product_brand, 
                                         brand_code, payment_method);
   END LOOP;

     end if;
     return v_ret;
   END;
   /* funcion para manejar las suscripciones
     Retorno n
     ---------
      n : numero de filas afectadas, (para n > -1)
     -1 : sesion invalida
     -2 : cuenta invalida
     -3 : evento invalido
     -4 : horario invalido
     -5 : parametro de activacion invalido
     -6 : parametro de frecuencia invalida
     -7 : horario no puede ser nulo
     -8 : solo permite ocurrencia en la frecuencia
     -9 : no permite monto minimo
    -10 : modulo de la cuenta invalida
    -11 : modalidad invalida
   */
   FUNCTION fu_ins_suscripciones(p_sesion IN VARCHAR2, p_canal IN VARCHAR2, p_nro_cuenta IN VARCHAR2, p_cod_evento IN NUMBER, p_activo IN VARCHAR2,
                                 p_horario IN VARCHAR2 DEFAULT NULL, p_mto_minimo IN NUMBER DEFAULT NULL, p_frecuencia IN VARCHAR2 DEFAULT NULL)
      RETURN NUMBER IS
      v_cod_persona    ba_personas.cod_persona%TYPE;
      v_nro_cuenta     ge_cuentas.nro_cuenta%TYPE;
      v_cod_evento     bw_not_eventos.cod_evento%TYPE := p_cod_evento;
      v_horario        bw_not_suscripciones.horario%TYPE := NULL;
      v_mto_minimo     bw_not_suscripciones.mto_minimo%TYPE := p_mto_minimo;
      v_activo         bw_not_suscripciones.activo%TYPE := substr(TRIM(p_activo), 1, 1);
      v_frecuencia     bw_not_suscripciones.frecuencia%TYPE := NULL;
      v_cod_mod_evento bw_not_eventos.cod_modulo%TYPE;
      v_cod_mad_evento bw_not_eventos.cod_modalidad%TYPE;
      v_eve_mto_minimo bw_not_eventos.mto_minimo%TYPE;
      v_eve_ocurrencia bw_not_eventos.ocurrencia%TYPE;
      v_cod_mod_cuenta ge_cta_clientes.cod_modulo%TYPE;
      v_cod_mad_cuenta ge_cta_clientes.cod_modalidad%TYPE;
      v_retorno        NUMBER;
   BEGIN
      v_nro_cuenta := substr(regexp_replace(TRIM(p_nro_cuenta), '([^[:alnum:]])', ''), 1, 15);

      -- validamos la sesion
      v_retorno := -1; -- sesion invalida
      SELECT nvl(cod_per_vinculada, cod_persona)
        INTO v_cod_persona
        FROM bw_aut_sesiones
       WHERE cod_sesion = p_sesion
         AND cod_canal = p_canal;

      -- se valida que la cuenta pertenezca a la persona
      v_retorno := -2; -- cuenta invalida
      SELECT c.cod_modulo, c.cod_modalidad
        INTO v_cod_mod_cuenta, v_cod_mad_cuenta
        FROM ge_cta_clientes c, ba_personas p
       WHERE p.cod_persona = v_cod_persona
         AND c.nro_cuenta = v_nro_cuenta
         AND p.cod_persona = c.cod_persona
         AND c.relacion = 'P'
         AND ROWNUM = 1;

      -- obtenemos los parametros del codigo de evento
      v_retorno := -3; -- evento invalido
      SELECT mto_minimo, ocurrencia, cod_modulo, cod_modalidad
        INTO v_eve_mto_minimo, v_eve_ocurrencia, v_cod_mod_evento, v_cod_mad_evento
        FROM bw_not_eventos
       WHERE cod_evento = v_cod_evento;

      -- se valida el parametro 'horario'
      -- M: manhana, T: tarde, N: noche
      IF p_horario IS NOT NULL THEN
         IF p_horario NOT IN ('M', 'T', 'N') THEN
            RETURN - 4; -- horario invalido
         ELSE
            v_horario := p_horario;
         END IF;
      END IF;

      -- se valida el parametro 'activo'
      IF v_activo NOT IN ('S', 'N') THEN
         RETURN - 5; -- activo invalido
      END IF;

      -- se valida el parametro 'frecuencia'
      -- D: diario, S: semanal, O: ocurrencia, M: mensual, Q: quincenal
      IF p_frecuencia IS NOT NULL THEN
         IF p_frecuencia NOT IN ('D', 'S', 'O', 'M', 'Q') THEN
            RETURN - 6; -- frecuencia invalida
         ELSE
            v_frecuencia := p_frecuencia;
         END IF;
      END IF;

      IF v_eve_ocurrencia = 'N' AND v_horario IS NULL THEN
         RETURN - 7; -- se debe especificar un horario
      END IF;

      IF v_eve_ocurrencia = 'S' AND nvl(v_frecuencia, 'x') <> 'O' THEN
         RETURN - 8; -- solo puede ser por ocurrencia
      END IF;

      IF v_eve_mto_minimo = 'N' AND v_mto_minimo IS NOT NULL THEN
         RETURN - 9; -- no se puede especificar monto minimo
      END IF;

      -- validamos el modulo de la cuenta
      IF nvl(v_cod_mod_evento, 0) <> 0 THEN
         IF v_cod_mod_evento <> v_cod_mod_cuenta THEN
            RETURN - 10; -- modulo invalido
         END IF;
      END IF;

      -- validamos la modalidad de la cuenta
      IF nvl(v_cod_mad_evento, 0) <> 0 THEN
         IF v_cod_mad_evento <> v_cod_mad_cuenta THEN
            RETURN - 11; -- modalidad invalida
         END IF;
      END IF;

      -- *********************
      -- TODO: validar los parametros frecuencia, mto_minimo y horario en base a parametros
      -- de bw_not_eventos
      v_retorno := 0;
      BEGIN
         INSERT INTO bw_not_suscripciones
            (cod_persona, nro_cuenta, cod_evento, horario, mto_minimo, activo, frecuencia)
         VALUES
            (v_cod_persona, v_nro_cuenta, v_cod_evento, v_horario, v_mto_minimo, v_activo, v_frecuencia);
      EXCEPTION
         WHEN DUP_VAL_ON_INDEX THEN
            UPDATE bw_not_suscripciones
               SET horario = v_horario, mto_minimo = v_mto_minimo, activo = v_activo, frecuencia = v_frecuencia
             WHERE cod_persona = v_cod_persona
               AND nro_cuenta = v_nro_cuenta
               AND cod_evento = v_cod_evento;
      END;
      v_retorno := SQL%ROWCOUNT;

      RETURN v_retorno;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN v_retorno;
      WHEN OTHERS THEN
         RETURN - 99;
   END;
   --Cantidad de suscripciones que tiene un persona
   FUNCTION lf_obt_cant_suscripciones(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN NUMBER IS
      v_cantidad NUMBER := 0;
   BEGIN
      BEGIN
         SELECT COUNT(activo)
           INTO v_cantidad
           FROM bw_not_suscripciones
          WHERE activo = 'S'
            AND cod_persona = p_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN - 1;
      END;
      RETURN v_cantidad;
   END;

--Pago de salarios
FUNCTION fu_not_pag_sueldo(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_moneda IN VARCHAR2,
                           p_monto ge_pag_sueldos.monto%TYPE, p_tipo ge_pag_sueldos.tipo%TYPE) RETURN NUMBER IS
   v_cod_evento   bw_not_eventos.cod_evento%TYPE;
   v_horario      bw_not_eventos.horario%TYPE;
   v_ocurrencia   bw_not_eventos.ocurrencia%TYPE;
   v_mandatorio   bw_not_eventos.mandatorio%TYPE;
   v_template     bw_not_tip_eventos.template%TYPE;
   v_mensaje      bw_not_mensajes.mensaje%TYPE;
   v_nom_comercio VARCHAR2(40);
   v_ret          NUMBER(3);
   v_moneda       number(3):=600;
   FUNCTION lf_obt_tip_pago(p_tipo ge_pag_sueldos.tipo%TYPE) RETURN VARCHAR2 IS
   BEGIN
      CASE
         WHEN p_tipo = 'A' THEN
            RETURN ' en concepto de pago de Aguinaldo';
         WHEN p_tipo = 'S' THEN
            RETURN ' en concepto de pago de Salario';
         WHEN p_tipo = 'C' THEN
            RETURN ' en concepto de pago de Comision';
         WHEN p_tipo = 'T' THEN
            RETURN '';
      END CASE;
      RETURN '';
   END;
BEGIN
     if(trim(p_moneda)<>'GS')THEN
          v_moneda:=840;
     end if;
   --pago de salario
   v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'SUEACR', v_cod_evento, v_horario, p_monto,v_moneda, v_ocurrencia, v_mandatorio);

   IF v_ret = 0 THEN

      --esta suscripto
      --BBVA informa: el credito de %s %s a su cuenta nro %s, realizado el día %s en concepto de pago de %s..
      IF fu_obt_not_template('SUEACR', v_template) = 0 THEN
            v_mensaje := utl_lms.format_message(v_template, p_moneda, lf_obt_mto_formateado(p_monto, v_moneda), lf_obt_ult_tarjeta(p_nro_cuenta),
                                                substr(lf_obt_fec_tra_formateado(SYSDATE), 0, 5), lf_obt_tip_pago(p_tipo));
         v_ret     := fu_ins_mensaje(v_cod_evento, 'SUEACR', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
      ELSE
         RETURN 20;
      END IF;
   END IF;

   RETURN v_ret;
END;

   FUNCTION lf_obt_fec_saldo(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE) RETURN DATE IS
      v_fec_saldo ge_sal_diarios.fecha%TYPE;
   BEGIN

      SELECT MAX(fecha)
        INTO v_fec_saldo
        FROM ge_sal_diarios s
       WHERE s.nro_cuenta = p_nro_cuenta;
      RETURN v_fec_saldo;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

FUNCTION fu_not_sal_cuenta RETURN NUMBER IS
   v_cod_evento     bw_not_eventos.cod_evento%TYPE;
   v_horario        bw_not_eventos.horario%TYPE;
   v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
   v_mandatorio     bw_not_eventos.mandatorio%TYPE;
   v_template       bw_not_tip_eventos.template%TYPE;
   v_mensaje        bw_not_mensajes.mensaje%TYPE;
   v_result         VARCHAR2(1); -- return 0 exito y 1 fracaso}
   v_ret            NUMBER(1);
   v_fec_programada DATE; --Fecha programada de envío
   v_moneda         number(3):=600;
   v_dia_habil      VARCHAR2(1):='S';
   CURSOR c_suscriptosSaldo IS
      SELECT S.COD_PERSONA, C.NRO_CUENTA, C.COD_MONEDA, E.Cod_Evento, c.cod_modulo, c.cod_modalidad,
             paw_bce.fu_obt_sal_actual(c.cod_modulo, c.cod_modalidad, c.nro_cuenta) AS saldo, c.cod_moneda AS moneda,s.dato1 as saldoAnterior
        FROM BW_NOT_SUSCRIPCIONES S, GE_CUENTAS C, BW_NOT_EVENTOS E
       WHERE S.COD_EVENTO = E.COD_EVENTO
         AND C.NRO_CUENTA = S.NRO_CUENTA
         AND E.COD_TIP_EVENTO = 'SALAMA'         
   AND C.ESTADO != 'C'; -- 03/2017 -- No notificar a Cuentas Canceladas

BEGIN
   IF fu_obt_not_template('SALAMA', v_template) <> 0 THEN
      RETURN 20;
   END IF;


   FOR i IN c_suscriptosSaldo
   LOOP
         if(trim(i.moneda)in ('USD','EUR')) then
           v_moneda:=840;
         else
           v_moneda:=600;
         end if;

      v_ret := fu_obt_eve_suscripcion(i.cod_persona, i.nro_cuenta, 'SALAMA', v_cod_evento, v_horario, i.saldo,v_moneda, v_ocurrencia, v_mandatorio);
      IF v_ret = 0 and ((i.saldo<>nvl(i.saldoanterior,0) and lf_dia_habil='N') or lf_dia_habil='S') THEN
         v_fec_programada := lf_obt_fec_sig_evento(i.cod_persona, i.nro_cuenta, i.cod_evento);
         --BBVA le informa: El saldo de su cuenta *NNNN al dd/mm - mm:hh, es de GS XXX.XXX.XXX
         --BBVA le informa: El saldo de su cuenta %s al %s, es de %s %s.
         v_mensaje := utl_lms.format_message(v_template,
                                             lf_obt_ult_tarjeta(i.nro_cuenta),
                                             lf_obt_fec_tra_formateado(sysdate),
                                             i.cod_moneda,
                                             lf_obt_mto_formateado(i.saldo, v_moneda));
         IF v_fec_programada IS NOT NULL AND lf_obt_men_duplicado(i.cod_persona, v_mensaje, 1, v_fec_programada) = 0 THEN
            v_result := fu_ins_mensaje(v_cod_evento, 'SALAMA', v_mensaje, i.cod_persona, i.nro_cuenta, v_fec_programada, 'S');
            v_result := lf_act_fec_ult_evento(i.cod_persona, i.nro_cuenta, v_cod_evento, v_fec_programada,i.saldo);
         END IF;
      END IF;
   END LOOP;
   IF v_result = 0 THEN
      RETURN 0;
   ELSE
      RETURN 1;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 99;
END;

   --retorna 20 en caso de error con el template
   FUNCTION lf_not_tar_debitos(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                                     ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                                     entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT,
                                     response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                                     provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2, p_gourmet VARCHAR2,
                                     product_brand VARCHAR2, brand_code VARCHAR2, payment_method VARCHAR2) RETURN NUMBER IS
      v_cod_evento bw_not_eventos.cod_evento%TYPE;
      v_horario    bw_not_eventos.horario%TYPE;
      v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio bw_not_eventos.mandatorio%TYPE;
      v_template   bw_not_tip_eventos.template%TYPE;
      v_mensaje    bw_not_mensajes.mensaje%TYPE;
      v_operacion  VARCHAR2(20);
      v_ret        NUMBER(3);
      v_tip_tarjeta varchar(20):='debito';
      v_rechazo     VARCHAR2(1):='N';
   BEGIN
--'debito automatico', 'pago de servicio' ,'transferencia'     
      --operacion con tarjeta de debito
       if(response_code<>'00') then
         v_rechazo:='S';
      end if;
       --operacion sin tarjeta de debito
      IF nvl(payment_method, 'x') = '04' THEN
         v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'OSTTARPAG', v_cod_evento, v_horario, transaction_amount, v_ocurrencia, v_mandatorio, v_rechazo);
         IF v_ret = 0 THEN
           IF fu_obt_not_template('OSTTARPAG', v_template, response_code) = 0 THEN
              v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(transaction_amount, currency_code),
                                                  lf_obt_com_formateado(commerce_name), lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);
              v_ret := fu_ins_mensaje(v_cod_evento, 'OSTTARPAG', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
            ELSE
               RETURN 20;
            END IF;
         END IF;
      ELSE
      v_ret := fu_obt_eve_suscripcion(p_cod_persona,
                                      p_nro_cuenta,
                                      'TADEBITOS',
                                      v_cod_evento,
                                      v_horario,
                                      transaction_amount,
                                      v_ocurrencia,
                                      v_mandatorio,
                                      v_rechazo);
      IF v_ret = 0 THEN
         v_operacion:=substr(lower(transaction_type),0,20);
         CASE
           WHEN v_operacion='transferencia' THEN 
                v_operacion:='La transferencia';
           WHEN v_operacion='debito automatico' THEN 
                v_operacion:='un debito automatico';
           WHEN v_operacion='pago de servicio' THEN 
               if response_code='00' then
                v_operacion:='El pago de servicio';
           else
                 v_operacion := 'del pago de servicio';
               end if;
            WHEN v_operacion = 'pago' THEN
               IF provide_service_code = 'PGFT' THEN
                 if response_code='00' then
                  v_operacion := 'El pago de servicio';
               ELSE
                   v_operacion := 'del pago de servicio';
                 end if;
               ELSE
                   if response_code='00' then
                      v_operacion:='El pago';
                    else 
                     v_operacion := 'del pago';
                   end if;
               END IF;
           else
             v_operacion:='El pago';
           end case;
          v_tip_tarjeta:='de '||lf_obt_des_tip_tarjeta(p_tip_tarjeta)||' ';
         --esta suscripto
         IF fu_obt_not_template('TADEBITOS', v_template,response_code) = 0 THEN
            -- 'BBVA le informa: Registramos %s de %s %s a su tarjeta %s, realizado el %s en %s
            v_mensaje := substr(utl_lms.format_message(v_template, v_operacion, lf_obt_mon_bancard(currency_code),
                                                       lf_obt_mto_formateado(transaction_amount, currency_code), v_tip_tarjeta || lf_obt_ult_tarjeta(card_number),
                                                       lf_obt_fec_tra_formateado(transaction_date), lf_obt_com_formateado(commerce_name)),0,g_men_longitud);

            v_ret := fu_ins_mensaje(v_cod_evento, 'TADEBITOS', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
         ELSE
            RETURN 20;
           END IF;
         END IF;
      END IF;
      RETURN v_ret;
   END;

   --retorna 20 en caso de error con el template
   --Para cambio de pin tiene que estar suscrito a otros debitos
   FUNCTION lf_not_tar_cam_pin(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                               ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2, entity_code VARCHAR2,
                               card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT, response_code VARCHAR2,
                               origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2, provide_service_code VARCHAR2, mcc_code NUMBER,
                               transaction_type VARCHAR2, payment_source VARCHAR2, product_brand VARCHAR2, brand_code VARCHAR2) RETURN NUMBER IS
      v_cod_evento bw_not_eventos.cod_evento%TYPE;
      v_horario    bw_not_eventos.horario%TYPE;
      v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio bw_not_eventos.mandatorio%TYPE;
      v_template   bw_not_tip_eventos.template%TYPE;
      v_mensaje    bw_not_mensajes.mensaje%TYPE;
      v_operacion  VARCHAR2(20);
      v_ret        NUMBER(3);
      v_tip_tarjeta varchar(20):='de debito';
   BEGIN
--'debito automatico', 'pago de servicio' ,'transferencia'     
      --operacion con tarjeta de debito
      IF provide_service_code ='STAR' AND NVL(product_brand, 'X') =  'PMO' AND NVL(brand_code, 'X') = 'ENT' THEN
        v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'OSTCAMPIN', v_cod_evento, v_horario, transaction_amount,currency_code, v_ocurrencia, v_mandatorio);
        IF v_ret = 0 THEN
          IF fu_obt_not_template('OSTCAMPIN', v_template, response_code) = 0 THEN
             v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_ult_tarjeta(p_nro_cuenta), lf_obt_fec_tra_formateado(transaction_date),
                                                 lf_obt_com_formateado(commerce_name)),0, g_men_longitud);
             v_ret := fu_ins_mensaje(v_cod_evento, 'OSTCAMPIN', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
           ELSE
              RETURN 20;
           END IF;
        END IF;
      ELSE
      v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TACAMPIN', v_cod_evento, v_horario, transaction_amount,currency_code, v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN
         --esta suscripto
         IF fu_obt_not_template('TACAMPIN', v_template,response_code) = 0 THEN
             v_tip_tarjeta:='de '||lf_obt_des_tip_tarjeta(p_tip_tarjeta)||' ';
            -- BBVA le informa: el cambio de Clave de la tarjeta %s, realizado el %s en el ATM %s
            v_mensaje := substr(utl_lms.format_message(v_template, v_tip_tarjeta || lf_obt_ult_tarjeta(card_number), lf_obt_fec_tra_formateado(transaction_date),
                                                       lf_obt_com_formateado(commerce_name)),0,g_men_longitud);

            v_ret := fu_ins_mensaje(v_cod_evento, 'TACAMPIN', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
         ELSE
            RETURN 20;
           END IF;
         END IF;
      END IF;
      RETURN v_ret;
   END;

   --retorna 20 en caso de error con el template
   FUNCTION lf_not_tar_transferencias(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                                     ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                                     entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT,
                                     response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                                      provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2,
                                      product_brand VARCHAR2, brand_code VARCHAR2) RETURN NUMBER IS
      v_cod_evento bw_not_eventos.cod_evento%TYPE;
      v_horario    bw_not_eventos.horario%TYPE;
      v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio bw_not_eventos.mandatorio%TYPE;
      v_template   bw_not_tip_eventos.template%TYPE;
      v_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE;
      v_mensaje    bw_not_mensajes.mensaje%TYPE;
      v_ret        NUMBER(3);
      v_rechazo    VARCHAR2(1):='N';
   BEGIN
      if(response_code<>'00') then
         v_rechazo:='S';
      end if;
--'debito automatico', 'pago de servicio' ,'transferencia'     
      --operacion con tarjeta de debito
      IF provide_service_code ='STAR' AND NVL(product_brand, 'X') =  'PMO' AND NVL(brand_code, 'X') = 'ENT' THEN
        v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'OSTCOMNAC', v_cod_evento, v_horario, transaction_amount, v_ocurrencia, v_mandatorio,v_rechazo);
        IF v_ret = 0 THEN
           IF fu_obt_not_template('OSTTRAATM', v_template, response_code) = 0 THEN
              v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(transaction_amount, currency_code),
                                                  lf_obt_ult_tarjeta(p_nro_cuenta), lf_obt_fec_tra_formateado(transaction_date)),0, g_men_longitud);
              v_ret := fu_ins_mensaje(v_cod_evento, 'OSTTRAATM', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
           ELSE
              RETURN 20;
           END IF;
        END IF;
      ELSE
         v_cod_tip_evento := 'TATRANATM';
        IF provide_service_code in ('CARG','GIRO') 
           and product_brand in ('MIB','ENV')then
            v_cod_tip_evento := 'PAGSER';
        end if;
      v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, v_cod_tip_evento, v_cod_evento, v_horario, transaction_amount, v_ocurrencia, v_mandatorio,v_rechazo);
      IF v_ret = 0 THEN
         --esta suscripto
         IF fu_obt_not_template(v_cod_tip_evento, v_template,response_code) = 0 THEN
--BBVA le informa: El debito de %s %s a su cta. %s por la transferencia de fondos en Cajero Automatico %s el %s.
            if v_cod_tip_evento = 'TATRANATM' then
            v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(transaction_amount, currency_code),
                                                       lf_obt_ult_tarjeta(p_nro_cuenta), lf_obt_com_formateado(commerce_name),
                                                       lf_obt_fec_tra_formateado(transaction_date)),0,g_men_longitud);
            else
              v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_mon_bancard(currency_code), lf_obt_mto_formateado(transaction_amount, currency_code),
                                                         lf_obt_fec_tra_formateado(transaction_date),lf_obt_ult_tarjeta(p_nro_cuenta)),0,g_men_longitud);
            end if;     
            v_ret := fu_ins_mensaje(v_cod_evento, v_cod_tip_evento, v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
         ELSE
            RETURN 20;
           END IF;
         END IF;
      END IF;
      RETURN v_ret;
   END;
   --retorna 20 en caso de error con el template
   FUNCTION lf_not_tar_deb_automatico(p_cod_persona ba_personas.cod_persona%TYPE, p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_tip_tarjeta IN VARCHAR2,
                                     ticket_number NUMBER, transaction_date DATE, commerce_name VARCHAR2, authorization_number VARCHAR2,
                                     entity_code VARCHAR2, card_number VARCHAR2, currency_code NUMBER, country_code NUMBER, transaction_amount FLOAT,
                                     response_code VARCHAR2, origin_code VARCHAR2, device_type VARCHAR2, service_code VARCHAR2,
                                      provide_service_code VARCHAR2, mcc_code NUMBER, transaction_type VARCHAR2, payment_source VARCHAR2) RETURN NUMBER IS
      v_cod_evento bw_not_eventos.cod_evento%TYPE;
      v_horario    bw_not_eventos.horario%TYPE;
      v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio bw_not_eventos.mandatorio%TYPE;
      v_template   bw_not_tip_eventos.template%TYPE;
      v_mensaje    bw_not_mensajes.mensaje%TYPE;
      v_ret        NUMBER(3);

   BEGIN
--'debito automatico', 'pago de servicio' ,'transferencia'     
      --operacion con tarjeta de debito
      v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, 'TCDEBAUT', v_cod_evento, v_horario, transaction_amount,currency_code, v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN
         --esta suscripto
         IF fu_obt_not_template('TCDEBAUT', v_template,response_code) = 0 THEN
--BBVA le informa: Un debito automatico de %s por %s %s, realizado el %s con cargo a su tarjeta de crédito %s.
            v_mensaje := substr(utl_lms.format_message(v_template, lf_obt_com_formateado(commerce_name), lf_obt_mon_bancard(currency_code),
                                                       lf_obt_mto_formateado(transaction_amount, currency_code), lf_obt_fec_tra_formateado(transaction_date),
                                                       lf_obt_ult_tarjeta(card_number)),0,g_men_longitud);
            v_ret := fu_ins_mensaje(v_cod_evento, 'TCDEBAUT', v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
         ELSE
            RETURN 20;
         END IF;
      END IF;
      RETURN v_ret;
   END;

   -- funcion para desuscribir al cliente del push.
   FUNCTION fu_des_push(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN NUMBER IS
      v_retorno       NUMBER := 0;
      v_sesion        bw_aut_sesiones%rowtype := NULL;
      v_cod_operacion VARCHAR2(3) := '552';
      v_mensaje       typ_mensajerespuesta := typ_mensajerespuesta();
      v_cod_persona   ba_personas.cod_persona%TYPE;
      v_res_post      typ_postRespuesta;
      v_url           VARCHAR2(100) := '';
      v_salida        VARCHAR2(3) := 'SAL';
      v_parametros    VARCHAR2(200);
   BEGIN
      v_sesion := lf_val_sesion(p_sesion, p_cod_canal);
      IF v_sesion.cod_sesion IS NULL THEN
         RETURN -1;
      END IF;
      paw_bel.pr_mensajeUsuario('OP_APROBADA', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                  'fu_des_push ' ||
                                   paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ENT');

      v_cod_persona := nvl(v_sesion.cod_per_vinculada, v_sesion.cod_persona);

      v_url        := g_not_webservice || 'desPush';
      v_parametros := utl_lms.format_message('cod_persona=%s', v_cod_persona);
      v_res_post    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
      lp_ins_log_mensajeria(v_url || '?' || v_parametros, v_res_post.error || '|' || v_res_post.respuesta);
      IF v_res_post.error = 'S' THEN
         paw_bel.pr_mensajeUsuario('OP_ERROR', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
         v_salida := 'ERR';
         v_retorno := -1;
      END IF;
      paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                  'fu_des_push - ret : ' || v_retorno || ' ' ||
                                   paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), v_salida);
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario('OP_ERROR', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);      
         paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                     'fu_des_push - ERR: [' || substr(SQLERRM, 1, 500) || '] ' ||
                                      paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ERR');
         RETURN -99;
   END;
   -- funcion para suscribir al cliente a un paquete basico
   FUNCTION fu_sus_paq_basico(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN NUMBER IS
      v_total         NUMBER := 0;
      v_tot_error     NUMBER := 0;
      v_horario       bw_not_suscripciones.horario%TYPE;
      v_frecuencia    bw_not_suscripciones.frecuencia%TYPE;
      v_cod_persona   ba_personas.cod_persona%TYPE;
      v_sesion        bw_aut_sesiones%rowtype := NULL;
      v_cod_operacion VARCHAR2(3) := '550';
      v_mensaje       typ_mensajerespuesta := typ_mensajerespuesta();
   BEGIN
      v_sesion := lf_val_sesion(p_sesion, p_cod_canal);
      IF v_sesion.cod_sesion IS NULL THEN
         RETURN -1;
      END IF;
      v_cod_persona := nvl(v_sesion.cod_per_vinculada, v_sesion.cod_persona);
      paw_bel.pr_mensajeUsuario('OP_APROBADA', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                  'fu_sus_paq_basico ' ||
                                   paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ENT');
      -- para cada evento del paquete basico
      FOR paq IN g_cur_paquete(1)
      LOOP
         FOR cue IN g_cur_cuentas(v_cod_persona, nvl(paq.cod_modulo, 0), nvl(paq.cod_modalidad, 0))
         LOOP
            BEGIN               
               IF paq.ocurrencia = 'S' THEN
                  v_frecuencia := 'O';
                  v_horario    := NULL;
               ELSE
                  v_frecuencia := 'D';
                  v_horario    := 'M';
               END IF;

               INSERT INTO bw_not_suscripciones
                  (cod_persona, nro_cuenta, cod_evento, horario, frecuencia)
               VALUES
                  (v_cod_persona, cue.nro_cuenta, paq.cod_evento, v_horario, v_frecuencia);

               v_total := v_total + 1;
            EXCEPTION
               WHEN DUP_VAL_ON_INDEX THEN
                  -- el evento ya esta configurado, omitir
                  v_tot_error := v_tot_error + 1;
            END;
         END LOOP;
      END LOOP;
      paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                  'fu_sus_paq_basico - total : ' || v_total || ', totError: ' || v_tot_error || ' ' ||
                                   paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'SAL');
      RETURN v_total;
   EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario('OP_ERROR', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);      
         paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                     'fu_sus_paq_basico - ERR: [' || substr(SQLERRM, 1, 500) || '] ' ||
                                      paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ERR');
         RETURN -99;
   END;
   -- funcion para desuscribir al cliente del paquete basico
   FUNCTION fu_des_paq_basico(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal IN cj_cajas.nro_caja%TYPE) RETURN NUMBER IS
      v_total         NUMBER := 0;
      v_cod_persona   ba_personas.cod_persona%TYPE;
      v_sesion        bw_aut_sesiones%rowtype := NULL;
      v_cod_operacion VARCHAR2(3) := '551';
      v_mensaje       typ_mensajerespuesta := typ_mensajerespuesta();
   BEGIN
      v_sesion := lf_val_sesion(p_sesion, p_cod_canal);
      IF v_sesion.cod_sesion IS NULL THEN
         RETURN -1;
      END IF;
      v_cod_persona := nvl(v_sesion.cod_per_vinculada, v_sesion.cod_persona);
      paw_bel.pr_mensajeUsuario('OP_APROBADA', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                  'fu_des_paq_basico ' ||
                                   paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ENT');

      -- para cada evento del paquete basico
      FOR paq IN g_cur_paquete(1)
      LOOP
         FOR cue IN g_cur_cuentas(v_cod_persona, nvl(paq.cod_modulo, 0), nvl(paq.cod_modalidad, 0))
         LOOP
            UPDATE bw_not_suscripciones p
               SET p.activo = 'N'
             WHERE p.cod_persona = v_cod_persona
               AND p.nro_cuenta = cue.nro_cuenta
               AND p.cod_evento = paq.cod_evento
               AND p.activo = 'S';
            v_total := v_total + SQL%ROWCOUNT;
         END LOOP;
      END LOOP;
      paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                  'fu_des_paq_basico - total : ' || v_total || ' ' ||
                                   paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'SAL');
      RETURN v_total;
   EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario('OP_ERROR', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);      
         paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                     'fu_des_paq_basico - ERR: [' || substr(SQLERRM, 1, 500) || '] ' ||
                                      paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ERR');
         RETURN -99;
   END;
--Notificacion de pago en Bach de tarjetas de credito
 FUNCTION fu_tar_pag_batch(p_nro_tarjeta IN ta_tarjetas.nro_tarjeta%TYPE, p_monto ge_movimientos.monto%TYPE) RETURN NUMBER IS
      v_cod_evento bw_not_eventos.cod_evento%TYPE;
      v_horario    bw_not_eventos.horario%TYPE;
      v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio bw_not_eventos.mandatorio%TYPE;
      v_template   bw_not_tip_eventos.template%TYPE;
      v_mensaje    bw_not_mensajes.mensaje%TYPE;
      v_cod_persona ba_personas.cod_persona%TYPE;   
      v_embozado   VARCHAR2(120);
      v_nro_cuenta VARCHAR2(20);
      v_titular    VARCHAR2(30);
      v_tipo       VARCHAR2(2);
      v_ret        NUMBER(3) := 0;
      v_gourmet    VARCHAR2(1);
      v_modalidad  VARCHAR2(3);
   BEGIN
      v_ret := fu_obt_dat_tarjeta(p_nro_tarjeta, v_cod_persona, v_embozado, v_nro_cuenta, v_titular, v_tipo,v_gourmet);
      IF v_ret <> 0 THEN
         RETURN 10; --No se encuentra datos de la tarjeta
      END IF;     
      v_ret := fu_obt_eve_suscripcion(v_cod_persona, v_nro_cuenta, 'TARPAGO', v_cod_evento, v_horario, p_monto,'600', v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN
         --esta suscripto
         IF fu_obt_not_template('TARPAGO', v_template, '00') = 0 THEN
            SELECT cod_modalidad
              INTO v_modalidad
              FROM ge_cuentas c
             WHERE c.nro_cuenta = v_nro_cuenta;
            --BBVA le informa. Registramos un pago al cierre de su tarjeta %s por %s %s.
               v_mensaje := utl_lms.format_message(v_template,
                                                   lf_obt_mon_bancard(600),
                                                   lf_obt_mto_formateado(p_monto, 600),
                                                   lf_obt_ult_tarjeta(p_nro_tarjeta),
                                                   lf_obt_fec_tra_formateado(sysdate));

               IF lf_es_gourmet(v_modalidad) = 'S' THEN
                  v_mensaje := REPLACE(v_mensaje, 'la tarjeta de credito', 'su gourmet card');
                  v_mensaje := REPLACE(v_mensaje, 'pago', 'credito');
               END IF;     
            v_ret     := fu_ins_mensaje(v_cod_evento, 'TARPAGO', v_mensaje, v_cod_persona, v_nro_cuenta, NULL, 'S');
         ELSE
            RETURN 20;
         END IF;
      END IF;
      RETURN v_ret;
   END;

FUNCTION fu_tar_exc_linea RETURN NUMBER IS
   CURSOR c_suscripciones IS
      SELECT ta_cta_tarjetas.nro_cuenta, BW_NOT_SUSCRIPCIONES.COD_PERSONA, GE_CTA_CLIENTES.RELACION, BW_NOT_SUSCRIPCIONES.Cod_Evento,
             TA_TARJETAS.NRO_TARJETA, ta_cta_tarjetas.cod_modulo, ta_cta_tarjetas.cod_modalidad, BW_NOT_EVENTOS.COD_TIP_EVENTO
        FROM ta_cta_tarjetas
       INNER JOIN BW_NOT_SUSCRIPCIONES
          ON ta_cta_tarjetas.NRO_CUENTA = BW_NOT_SUSCRIPCIONES.NRO_CUENTA
       INNER JOIN GE_CTA_CLIENTES
          ON BW_NOT_SUSCRIPCIONES.COD_PERSONA = GE_CTA_CLIENTES.COD_PERSONA
         AND BW_NOT_SUSCRIPCIONES.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
       INNER JOIN TA_TARJETAS
          ON GE_CTA_CLIENTES.COD_PERSONA = TA_TARJETAS.COD_PERSONA
         AND GE_CTA_CLIENTES.NRO_CUENTA = TA_TARJETAS.NRO_CUENTA
       INNER JOIN BW_NOT_EVENTOS
          ON BW_NOT_SUSCRIPCIONES.COD_EVENTO = BW_NOT_EVENTOS.COD_EVENTO
       WHERE GE_CTA_CLIENTES.RELACION = 'P'
         AND paw_bce.fu_obt_sal_actual(ta_cta_tarjetas.cod_modulo, ta_cta_tarjetas.cod_modalidad, BW_NOT_SUSCRIPCIONES.nro_cuenta) < 0
         AND TA_TARJETAS.VIGENTE = 'S'
         AND BW_NOT_EVENTOS.COD_TIP_EVENTO = 'TAEXCLINEA'
         AND (BW_NOT_SUSCRIPCIONES.DATO1 IS NULL OR
             BW_NOT_SUSCRIPCIONES.DATO1 <>
             paw_bce.fu_obt_sal_actual(ta_cta_tarjetas.cod_modulo, ta_cta_tarjetas.cod_modalidad, BW_NOT_SUSCRIPCIONES.nro_cuenta));
       v_cod_evento  bw_not_eventos.cod_evento%TYPE;
    v_horario     bw_not_eventos.horario%TYPE;
    v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio  bw_not_eventos.mandatorio%TYPE;
    v_template    bw_not_tip_eventos.template%TYPE;
    v_mensaje     bw_not_mensajes.mensaje%TYPE;
    v_ret         NUMBER(3) := 0;
    v_result     NUMBER(3) := 0;
    v_fec_programada DATE;
   v_monto          ge_movimientos.monto%TYPE;

   ----DYDMR-12466 - se agrega la inserción de log
   v_err_code NUMBER(5);
   v_err_msj  VARCHAR2(4000);
   v_hini_notifi ge_ra_log_mail.hor_inicio%type;
   v_hfin_notifi ge_ra_log_mail.hor_fin%type;

 BEGIN
      IF fu_obt_not_template('TAEXCLINEA', v_template) <> 0 THEN
         RETURN 20;
      END IF;
      v_hini_notifi := to_char(sysdate, 'hh24:mi:ss');
      FOR i IN c_suscripciones
      LOOP
         v_ret := fu_obt_eve_suscripcion(i.cod_persona, i.nro_cuenta, 'TAEXCLINEA', v_cod_evento, v_horario, 0,'600', v_ocurrencia, v_mandatorio);
         IF v_ret = 0 THEN
         v_monto          := paw_bce.fu_obt_sal_actual(i.cod_modulo, i.cod_modalidad, i.nro_cuenta);
           v_fec_programada := lf_obt_fec_sig_evento(i.cod_persona, i.nro_cuenta, i.cod_evento);
            --BBVA le informa. Excedio la linea de su tarjeta %s.
         v_mensaje := utl_lms.format_message(v_template, lf_obt_ult_tarjeta(i.nro_tarjeta));
            IF v_fec_programada IS NOT NULL AND lf_obt_men_duplicado(i.cod_persona, v_mensaje, 1, v_fec_programada) = 0 THEN
              v_result := fu_ins_mensaje(v_cod_evento, 'TAEXCLINEA', v_mensaje, i.cod_persona, i.nro_cuenta, v_fec_programada, 'S');
            if v_result= 0 then
              v_result := lf_act_fec_ult_evento(i.cod_persona, i.nro_cuenta, v_cod_evento, v_fec_programada, v_monto);
            END IF;
         END IF;
      END IF;
      END LOOP;
      v_hfin_notifi := to_char(sysdate, 'hh24:mi:ss');
      IF v_result = 0 THEN
    return 0;
      ELSE
         RETURN 1;
      END IF;
   EXCEPTION
    WHEN OTHERS THEN
     v_err_code := SQLCODE;
     v_err_msj  := SQLERRM;
      INSERT INTO ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, nro_error, men_error)
           VALUES (972, 'PAW_NOT.FU_TAR_EXC_LINEA', v_hini_notifi, v_hfin_notifi, v_err_code, v_err_msj);
 END;

 FUNCTION fu_pre_vencimientos RETURN NUMBER IS

    CURSOR c_suscripciones IS
       SELECT ns.COD_PERSONA, p.nro_cuenta, p.fec_vencimiento, p.nro_cuota, pc.CAN_CUOTAS
         FROM pr_cuotas p
        INNER JOIN GE_CTA_CLIENTES c
           ON p.NRO_CUENTA = c.NRO_CUENTA
        INNER JOIN bw_not_cli_suscriptos ns
           ON c.COD_PERSONA = ns.COD_PERSONA
        INNER JOIN PR_CTA_PRESTAMOS pc
           ON p.NRO_CUENTA = pc.NRO_CUENTA
        WHERE trunc(p.fec_vencimiento) = trunc(SYSDATE + 1)
          AND ns.activo = 'S'
          AND p.estado = 'C'
          AND c.relacion = 'P';
    v_cod_evento     bw_not_eventos.cod_evento%TYPE;
    v_horario        bw_not_eventos.horario%TYPE;
    v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio     bw_not_eventos.mandatorio%TYPE;
    v_template       bw_not_tip_eventos.template%TYPE;
    v_mensaje        bw_not_mensajes.mensaje%TYPE;
    v_ret            NUMBER(3) := 0;
    v_result         NUMBER(3) := 0;
    v_fec_programada DATE;
 BEGIN
    IF fu_obt_not_template('PRECUOVEN', v_template) <> 0 THEN
       RETURN 20;
    END IF;

    FOR i IN c_suscripciones
    LOOP
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, i.nro_cuenta, 'PRECUOVEN', v_cod_evento, v_horario, 0,'600', v_ocurrencia, v_mandatorio);
       IF v_ret = 0 THEN
          v_fec_programada := lf_obt_fec_sig_evento(i.cod_persona, i.nro_cuenta, v_cod_evento);
          --BBVA le recuerda: el vencimiento de pago de la cuota %s de %s del prestamo %s, sera el dia %s.
          v_mensaje := utl_lms.format_message(v_template,trim(to_char(i.nro_cuota,'999')), trim(to_char(i.CAN_CUOTAS,'999')), lf_obt_ult_tarjeta(i.nro_cuenta),
                                              substr(lf_obt_fec_tra_formateado(i.fec_vencimiento), 0, 5));
          v_result  := fu_ins_mensaje(v_cod_evento, 'PRECUOVEN', v_mensaje, i.cod_persona, i.nro_cuenta, v_fec_programada, 'S');
       END IF;
    END LOOP;
    IF v_result = 0 THEN
       RETURN 0;
    ELSE
       RETURN 1;
    END IF;
 END;

 FUNCTION fu_che_lib_fondos(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                            p_tipo VARCHAR2,p_fecha in date) RETURN NUMBER IS
    v_cod_evento  bw_not_eventos.cod_evento%TYPE;
    v_horario     bw_not_eventos.horario%TYPE;
    v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio  bw_not_eventos.mandatorio%TYPE;
    v_template    bw_not_tip_eventos.template%TYPE;
    v_mensaje     bw_not_mensajes.mensaje%TYPE;
    v_ret         NUMBER(3) := 0;
    v_iso_moneda  NUMBER(3) := 600;
    v_tip_evento  VARCHAR2(15):='CHELIBFON';
 BEGIN
/*    IF (upper(p_tipo)='O') THEN
      v_tip_evento:='CHELIBFONO';
    END IF;  
*/    
    IF fu_obt_not_template(v_tip_evento, v_template, '00') <> 0 THEN
       RETURN 20;
    END IF;
    IF (TRIM(p_cod_moneda) <> 'GS') THEN
       v_iso_moneda := 840;
    END IF;  
    FOR i IN g_cur_titulares(p_nro_cuenta)
    LOOP
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, p_nro_cuenta, v_tip_evento, v_cod_evento, v_horario, p_monto,v_iso_moneda, v_ocurrencia, v_mandatorio);
       IF v_ret = 0 THEN
          --esta suscripto
             --BBVA le informa: la disponibilidad de fondos del deposito en cheques por %s %s, realizado el %s a la cuenta %s.
             v_mensaje := utl_lms.format_message(v_template, p_cod_moneda, 
                                                 lf_obt_mto_formateado(p_monto, v_iso_moneda),
                                                 substr(lf_obt_fec_tra_formateado(p_fecha),0,5),
                                                 lf_obt_ult_tarjeta(p_nro_cuenta));
             v_ret     := fu_ins_mensaje(v_cod_evento, v_tip_evento, v_mensaje, i.cod_persona, p_nro_cuenta, NULL, 'S');
          END IF;
    END LOOP;
    RETURN v_ret;
 END;

 FUNCTION fu_che_dev_cheques(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_nro_cheque in VARCHAR2 ,p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                            p_tipo VARCHAR2,p_fecha in date) RETURN NUMBER IS
    v_cod_evento  bw_not_eventos.cod_evento%TYPE;
    v_horario     bw_not_eventos.horario%TYPE;
    v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio  bw_not_eventos.mandatorio%TYPE;
    v_template    bw_not_tip_eventos.template%TYPE;
    v_mensaje     bw_not_mensajes.mensaje%TYPE;
    v_ret         NUMBER(3) := 0;
    v_iso_moneda NUMBER(3) := 600;
    v_tip_evento  VARCHAR2(15):='CHERECFON';
 BEGIN
   /*  IF (upper(p_tipo)='O') THEN
      v_tip_evento:='CHERECFONT';
    END IF;  */
    IF fu_obt_not_template(v_tip_evento, v_template, '00') <> 0 THEN
       RETURN 20;
    END IF;
    IF (TRIM(p_cod_moneda) <> 'GS') THEN
       v_iso_moneda := 840;
    END IF; 
    FOR i IN g_cur_titulares(p_nro_cuenta)
    LOOP
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, p_nro_cuenta, v_tip_evento, v_cod_evento, v_horario, p_monto,v_iso_moneda, v_ocurrencia, v_mandatorio);
       IF v_ret = 0 THEN
          --esta suscripto
             --BBVA le informa: La devolución del cheque %s de %s %s, depositado el %s a la cuenta %s.
             v_mensaje := utl_lms.format_message(v_template,p_nro_cheque, 
                                                 p_cod_moneda, 
                                                 lf_obt_mto_formateado(p_monto, v_iso_moneda),
                                                 substr(lf_obt_fec_tra_formateado(p_fecha),0,5),
                                                 lf_obt_ult_tarjeta(p_nro_cuenta));
             v_ret     := fu_ins_mensaje(v_cod_evento, v_tip_evento, v_mensaje, i.cod_persona, p_nro_cuenta, NULL, 'S');
          END IF;
    END LOOP;
    RETURN v_ret;
 END;

FUNCTION fu_not_pag_servicios(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                            p_tipo VARCHAR2,p_fecha in date) RETURN NUMBER IS
    v_cod_evento  bw_not_eventos.cod_evento%TYPE;
    v_horario     bw_not_eventos.horario%TYPE;
    v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio  bw_not_eventos.mandatorio%TYPE;
    v_template    bw_not_tip_eventos.template%TYPE;
    v_mensaje     bw_not_mensajes.mensaje%TYPE;
    v_ret         NUMBER(3) := 0;
    v_iso_moneda NUMBER(3) := 600;
    v_cod_moneda VARCHAR(3);
    v_tip_evento  VARCHAR2(15):='PAGSER';
    v_tipo        VARCHAR(2):='00';
    v_rechazo     varchar(2):='S';
    v_dir_cor_pri VARCHAR2(120);
    v_dir_cor_not VARCHAR2(120) := NULL;
 BEGIN
    IF upper(p_tipo)='R' THEN
      v_tipo:='11';
      v_rechazo:='S';
    ELSE
      v_tipo:='00';
      v_rechazo:='N';
    END IF;
    IF fu_obt_not_template(v_tip_evento, v_template, v_tipo) <> 0 THEN
       RETURN 20;
    END IF;
    v_cod_moneda:=trim(p_cod_moneda);
    --Cuando viene via IFrame viene con codigo de moneda 1 para GS y 2 para USA
    IF (v_cod_moneda='1') THEN 
      v_cod_moneda:='GS';
    elsif (v_cod_moneda='2') THEN
        v_cod_moneda:='USD';
    END IF;

    IF (v_cod_moneda <> 'GS') THEN
       v_iso_moneda := 840;
    else
       v_iso_moneda := 600;
    END IF; 


    FOR i IN g_cur_titulares(p_nro_cuenta)
    LOOP
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, p_nro_cuenta, v_tip_evento, v_cod_evento, v_horario, p_monto,v_iso_moneda, v_ocurrencia, v_mandatorio,v_rechazo);
       IF v_ret = 0 THEN --esta suscripto

          --Control para evitar la doble notificacion cuando se realiza el pago (no reversa)
          --Un primer envio por mail ya se hace en PAW_BEL.fu_pagoServicioWsActualizar a esta direcccion de correo
          IF upper(p_tipo)='P' THEN
             v_dir_cor_pri := TRIM(UPPER(paw_seg.fu_obt_mail(fug_obt_cli_principal(p_nro_cuenta))));
             v_dir_cor_not := lf_ver_destino(i.cod_persona, 'EMAIL');
          END IF;


          --entra al bloque solo si la configuracion no es mail o es mail pero el destino es distinto al ya usado
          IF (v_dir_cor_not IS NULL OR TRIM(UPPER(v_dir_cor_not)) <> v_dir_cor_pri) THEN

            --BBVA le informa: el pago de servicios de %s %s realizado el %s, con cargo a la cuenta %s.
            --BBVA le informa: la reversion del pago de servicios de %s %s realizado el %s, con cargo a la cuenta %s.
             v_mensaje := utl_lms.format_message(v_template, 
                                                 v_cod_moneda, 
                                                 lf_obt_mto_formateado(p_monto, v_iso_moneda),
                                                 lf_obt_fec_tra_formateado(p_fecha),
                                                 lf_obt_ult_tarjeta(p_nro_cuenta));
             v_ret     := fu_ins_mensaje(v_cod_evento, v_tip_evento, v_mensaje, i.cod_persona, p_nro_cuenta, NULL, 'S');
          END IF;
        END IF;
    END LOOP;
    RETURN v_ret;
 END;

 FUNCTION fu_che_pag_girado(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_nro_cheque IN VARCHAR2, p_monto ge_movimientos.monto%TYPE,
                            p_cod_moneda IN ba_monedas.cod_moneda%TYPE, p_tipo VARCHAR2, p_fecha IN DATE) RETURN NUMBER IS
    v_cod_evento bw_not_eventos.cod_evento%TYPE;
    v_horario    bw_not_eventos.horario%TYPE;
    v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio bw_not_eventos.mandatorio%TYPE;
    v_template   bw_not_tip_eventos.template%TYPE;
    v_mensaje    bw_not_mensajes.mensaje%TYPE;
    v_ret        NUMBER(3) := 0;
    v_iso_moneda NUMBER(3) := 600;
    v_resultado  VARCHAR2(2);
    v_rechazado  VARCHAR2(1);
 BEGIN
    IF (p_tipo = 'S') THEN
       v_resultado := '00';
       v_rechazado :='N';
    ELSE
       v_resultado := '01';
       v_rechazado :='S';
    END IF; 
    IF fu_obt_not_template('CHEPAGGIR', v_template, v_resultado) <> 0 THEN
       RETURN 20;
    END IF;
    IF (TRIM(p_cod_moneda) <> 'GS') THEN
       v_iso_moneda := 840;
    END IF;

    FOR i IN g_cur_titulares(p_nro_cuenta)
    LOOP
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, p_nro_cuenta, 'CHEPAGGIR', v_cod_evento, v_horario, p_monto, v_ocurrencia, v_mandatorio,v_rechazado);
       IF v_ret = 0 THEN
          --esta suscripto
          --BBVA le informa: La devolución del cheque %s de %s %s, depositado el %s a la cuenta %s.
          v_mensaje := utl_lms.format_message(v_template, p_nro_cheque, p_cod_moneda, lf_obt_mto_formateado(p_monto, v_iso_moneda),
                                              substr(lf_obt_fec_tra_formateado(p_fecha), 0, 5), lf_obt_ult_tarjeta(p_nro_cuenta));
          v_ret     := fu_ins_mensaje(v_cod_evento, 'CHEPAGGIR', v_mensaje, i.cod_persona, p_nro_cuenta, NULL, 'S');
       END IF;
    END LOOP;
    RETURN v_ret;
 END;

 FUNCTION fu_not_deb_caja(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                          p_fecha IN DATE) RETURN NUMBER IS
    v_cod_evento bw_not_eventos.cod_evento%TYPE;
    v_horario    bw_not_eventos.horario%TYPE;
    v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio bw_not_eventos.mandatorio%TYPE;
    v_template   bw_not_tip_eventos.template%TYPE;
    v_mensaje    bw_not_mensajes.mensaje%TYPE;
    v_ret        NUMBER(3) := 0;
    v_iso_moneda NUMBER(3) := 600;
 BEGIN

    IF fu_obt_not_template('CAJDEB', v_template, '00') <> 0 THEN
       RETURN 20;
    END IF;
    IF (TRIM(p_cod_moneda) <> 'GS') THEN
       v_iso_moneda := 840;
    END IF;
    FOR i IN g_cur_titulares(p_nro_cuenta)
    LOOP
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, p_nro_cuenta, 'CAJDEB', v_cod_evento, v_horario, p_monto,v_iso_moneda, v_ocurrencia, v_mandatorio);
       IF v_ret = 0 THEN
          --esta suscripto
          --BBVA le informa: la extraccion en cajas de %s %s, realizada el %s a su cuenta %s.
          v_mensaje := utl_lms.format_message(v_template, p_cod_moneda, lf_obt_mto_formateado(p_monto, v_iso_moneda),
                                              substr(lf_obt_fec_tra_formateado(p_fecha), 0, 5), lf_obt_ult_tarjeta(p_nro_cuenta));
          v_ret     := fu_ins_mensaje(v_cod_evento, 'CAJDEB', v_mensaje, i.cod_persona, p_nro_cuenta, NULL, 'S');
       END IF;
    END LOOP;
    RETURN v_ret;
 END;

FUNCTION fu_not_exc_sobregiro RETURN NUMBER IS
   CURSOR c_suscripciones IS
      SELECT S.COD_PERSONA, C.NRO_CUENTA, C.COD_MONEDA, E.Cod_Evento, c.cod_modulo, c.cod_modalidad,
             paw_bce.fu_obt_sal_actual(c.cod_modulo, c.cod_modalidad, c.nro_cuenta) AS saldo, c.cod_moneda AS moneda
        FROM BW_NOT_SUSCRIPCIONES S, GE_CUENTAS C, BW_NOT_EVENTOS E, cc_lin_sobregiros g
       WHERE S.COD_EVENTO = E.COD_EVENTO
         AND C.NRO_CUENTA = S.NRO_CUENTA
         AND g.nro_cuenta = s.nro_cuenta
         AND g.fec_vencimiento > SYSDATE
         AND C.Cod_Modulo = 4
         AND c.nro_cuenta = s.nro_cuenta
         AND e.cod_tip_evento = 'CCEXSJIRO'
         AND paw_bce.fu_obt_sal_actual(c.cod_modulo, c.cod_modalidad, c.nro_cuenta) < (g.monto * -1);
   v_cod_evento     bw_not_eventos.cod_evento%TYPE;
   v_horario        bw_not_eventos.horario%TYPE;
   v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
   v_mandatorio     bw_not_eventos.mandatorio%TYPE;
   v_template       bw_not_tip_eventos.template%TYPE;
   v_mensaje        bw_not_mensajes.mensaje%TYPE;
   v_ret            NUMBER(3) := 0;
   v_result         NUMBER(3) := 0;
   v_fec_programada DATE;
 BEGIN
   IF fu_obt_not_template('CCEXSJIRO', v_template) <> 0 THEN
      RETURN 20;
   END IF;

   FOR i IN c_suscripciones
   LOOP
      v_ret := fu_obt_eve_suscripcion(i.cod_persona, i.nro_cuenta, 'CCEXSJIRO', v_cod_evento, v_horario, 0,'600', v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN
         v_fec_programada := lf_obt_fec_sig_evento(i.cod_persona, i.nro_cuenta, i.cod_evento);
         --          BBVA le informa: en fecha %s se ha sobrepasado la linea de sobregiro asignada a la cuenta %s.
         v_mensaje := utl_lms.format_message(v_template, substr(lf_obt_fec_tra_formateado(SYSDATE), 0, 5), lf_obt_ult_tarjeta(i.nro_cuenta));
         IF v_fec_programada IS NOT NULL AND lf_obt_men_duplicado(i.cod_persona, v_mensaje, 1, v_fec_programada) = 0 THEN
            v_result := fu_ins_mensaje(v_cod_evento, 'CCEXSJIRO', v_mensaje, i.cod_persona, i.nro_cuenta, v_fec_programada, 'S');
            if v_result=0 then
            v_result := lf_act_fec_ult_evento(i.cod_persona, i.nro_cuenta, v_cod_evento, v_fec_programada,i.saldo);
         END IF;
      END IF;
      END IF;
   END LOOP;
   IF v_result = 0 THEN
      RETURN 0;
   ELSE
      RETURN 1;
   END IF;
 END;

FUNCTION fu_not_sobregiro RETURN NUMBER IS
   CURSOR c_suscripciones IS
      SELECT S.COD_PERSONA, C.NRO_CUENTA, C.COD_MONEDA, E.Cod_Evento, c.cod_modulo, c.cod_modalidad,
             paw_bce.fu_obt_sal_actual(c.cod_modulo, c.cod_modalidad, c.nro_cuenta) AS saldo, c.cod_moneda AS moneda
        FROM BW_NOT_SUSCRIPCIONES S, GE_CUENTAS C, BW_NOT_EVENTOS E
       WHERE S.COD_EVENTO = E.COD_EVENTO
         AND C.NRO_CUENTA = S.NRO_CUENTA
         AND C.Cod_Modulo = 4
         AND c.nro_cuenta = s.nro_cuenta
         AND e.cod_tip_evento = 'CCSOBJIRO'
         AND paw_bce.fu_obt_sal_actual(c.cod_modulo, c.cod_modalidad, c.nro_cuenta) < 0;
   v_cod_evento     bw_not_eventos.cod_evento%TYPE;
   v_horario        bw_not_eventos.horario%TYPE;
   v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
   v_mandatorio     bw_not_eventos.mandatorio%TYPE;
   v_template       bw_not_tip_eventos.template%TYPE;
   v_mensaje        bw_not_mensajes.mensaje%TYPE;
   v_ret            NUMBER(3) := 0;
   v_result         NUMBER(3) := 0;
   v_fec_programada DATE;
 BEGIN
   IF fu_obt_not_template('CCSOBJIRO', v_template) <> 0 THEN
      RETURN 20;
   END IF;

   FOR i IN c_suscripciones
   LOOP
      v_ret := fu_obt_eve_suscripcion(i.cod_persona, i.nro_cuenta, 'CCSOBJIRO', v_cod_evento, v_horario, 0,'600', v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN
         v_fec_programada := lf_obt_fec_sig_evento(i.cod_persona, i.nro_cuenta, i.cod_evento);
         --          BBVA le informa: en fecha %s se ha sobrepasado la linea de sobregiro asignada a la cuenta %s.
         v_mensaje := utl_lms.format_message(v_template, substr(lf_obt_fec_tra_formateado(SYSDATE), 0, 5), lf_obt_ult_tarjeta(i.nro_cuenta));
         IF v_fec_programada IS NOT NULL AND lf_obt_men_duplicado(i.cod_persona, v_mensaje, 1, v_fec_programada) = 0 THEN
            v_result := fu_ins_mensaje(v_cod_evento, 'CCSOBJIRO', v_mensaje, i.cod_persona, i.nro_cuenta, v_fec_programada, 'S');
            if v_result=0 then
            v_result := lf_act_fec_ult_evento(i.cod_persona, i.nro_cuenta, v_cod_evento, v_fec_programada,i.saldo);
         END IF;
      END IF;
      END IF;
   END LOOP;
   IF v_result = 0 THEN
      RETURN 0;
   ELSE
      RETURN 1;
   END IF;
 END;

 FUNCTION fu_not_transferencias(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_monto ge_movimientos.monto%TYPE, p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                                p_tipo IN VARCHAR2, p_fecha IN DATE) RETURN NUMBER IS
    v_cod_evento bw_not_eventos.cod_evento%TYPE;
    v_horario    bw_not_eventos.horario%TYPE;
    v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio bw_not_eventos.mandatorio%TYPE;
    v_template   bw_not_tip_eventos.template%TYPE;
    v_mensaje    bw_not_mensajes.mensaje%TYPE;


    v_ret            NUMBER(3) := 0;
    v_iso_moneda     NUMBER(3) := 600;
    v_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE := 'TATRANATM'; --Debito 
 BEGIN
    v_cod_tip_evento := 'TATRANATM';
    IF (upper(p_tipo) = 'C') THEN
       v_cod_tip_evento := 'TATRANCRE'; --evento de credito
    END IF;
    IF fu_obt_not_template(v_cod_tip_evento, v_template, '00') <> 0 THEN
       RETURN 20;
    END IF;
    IF (TRIM(p_cod_moneda) <> 'GS') THEN
       v_iso_moneda := 840;
    END IF;
    FOR i IN g_cur_titulares(p_nro_cuenta)
    LOOP
       --la suscripcion es solamente a transferencias
       v_ret := fu_obt_eve_suscripcion(i.cod_persona, p_nro_cuenta, 'TATRANATM', v_cod_evento, v_horario, p_monto,v_iso_moneda, v_ocurrencia, v_mandatorio);
       IF v_ret = 0 THEN
          --esta suscripto
          --BBVA le informa: el credito de %s %s a la cuenta %s, por la transferencia de fondos realizada el %s.
          --BBVA le informa: el debito de %s %s a la cuenta %s, por la transferencia de fondos realizada el %s.
          v_mensaje := utl_lms.format_message(v_template, p_cod_moneda, lf_obt_mto_formateado(p_monto, v_iso_moneda), lf_obt_ult_tarjeta(p_nro_cuenta),
                                              substr(lf_obt_fec_tra_formateado(p_fecha), 0, 5));
          v_ret     := fu_ins_mensaje(v_cod_evento, v_cod_tip_evento, v_mensaje, i.cod_persona, p_nro_cuenta, NULL, 'S');
       END IF;
    END LOOP;
    RETURN v_ret;
 END;

  FUNCTION fu_not_tra_gnb(p_nro_cta_debito   IN VARCHAR2,
                          p_cod_mon_debito   IN VARCHAR2,
                          p_mto_debito       IN NUMBER,
                          p_nro_cta_credito  IN VARCHAR2,
                          p_cod_mon_credito  IN VARCHAR2,
                          p_mto_credito      IN NUMBER,
                          p_nom_beneficiario IN VARCHAR2,
                          p_concepto         IN VARCHAR2,
                          p_nro_referencia   IN NUMBER,
                          p_tipo             IN VARCHAR2 DEFAULT 'C') RETURN NUMBER IS
    v_cod_evento  bw_not_eventos.cod_evento%TYPE;
    v_horario     bw_not_eventos.horario%TYPE;
    v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio  bw_not_eventos.mandatorio%TYPE;
    v_template    bw_not_tip_eventos.template%TYPE;
    v_mensaje     bw_not_mensajes.mensaje%TYPE;
    v_ret         NUMBER(3) := 0;
    v_iso_moneda NUMBER(3) := 600;
    v_cod_moneda VARCHAR(3);
    v_cod_persona ba_personas.cod_persona%TYPE;
    v_tip_evento  VARCHAR2(15):='TRAGNBENV';
    v_dir_cor_pri VARCHAR2(120);
    v_dir_cor_not VARCHAR2(120) := NULL;
    v_cod_error   VARCHAR2(2) := '00';
 BEGIN
    -- notificamos por correo
    v_ret := fu_not_tra_gnb_mail(p_nro_cta_debito, p_cod_mon_debito, p_mto_debito, p_nro_cta_credito, p_cod_mon_credito, 
                        p_mto_credito, p_nom_beneficiario, p_concepto,  p_nro_referencia, p_tipo);

    IF p_tipo IN ('E','T', 'P') THEN
       RETURN v_ret;
    END IF;

    IF p_tipo = 'R' THEN
       v_cod_error := '01';
    END IF;

    IF fu_obt_not_template(v_tip_evento, v_template, v_cod_error) <> 0 THEN
       RETURN 20;
    END IF;
    v_cod_moneda:=trim(p_cod_mon_debito);

    IF (v_cod_moneda <> 'GS') THEN
       v_iso_moneda := 840;
    else
       v_iso_moneda := 600;
    END IF; 

    v_cod_persona := fug_obt_cli_principal(p_nro_cta_debito);
    v_ret := fu_obt_eve_suscripcion(v_cod_persona, p_nro_cta_debito, v_tip_evento, v_cod_evento, v_horario, p_mto_debito, v_iso_moneda, v_ocurrencia, v_mandatorio);

    IF v_ret = 0 THEN --esta suscripto
       v_dir_cor_not := lf_ver_destino(v_cod_persona, 'EMAIL');
       IF v_dir_cor_not IS NULL THEN -- si no es correo va por serv. de notificaciones

            --Banco le informa: el debito de %s %s a la cuenta %s, por la transferencia enviada a GNBPY
             v_mensaje := utl_lms.format_message(v_template, 
                                                 v_cod_moneda, 
                                                 lf_obt_mto_formateado(p_mto_debito, v_iso_moneda),
                                                 lf_obt_ult_tarjeta(p_nro_cta_debito));
             v_ret     := fu_ins_mensaje(v_cod_evento, v_tip_evento, v_mensaje, v_cod_persona, p_nro_cta_debito, NULL, 'S');

       END IF;
    END IF;

    RETURN v_ret;
 END;

  FUNCTION fu_not_tra_gnb_mail(p_nro_cta_debito   IN VARCHAR2,
                               p_cod_mon_debito   IN VARCHAR2,
                               p_mto_debito       IN NUMBER,
                               p_nro_cta_credito  IN VARCHAR2,
                               p_cod_mon_credito  IN VARCHAR2,
                               p_mto_credito      IN NUMBER,
                               p_nom_beneficiario IN VARCHAR2,
                               p_concepto         IN VARCHAR2,
                               p_nro_referencia   IN NUMBER,
                               p_tipo             IN VARCHAR2 DEFAULT 'C') RETURN NUMBER IS
      v_cabecera   VARCHAR2(700)  := NULL;
      v_detalle    VARCHAR2(3500) := NULL;
      v_pie        VARCHAR2(350)  := NULL;
      v_tag        VARCHAR2(50);
      v_dir_correo ba_mails.dir_correo%TYPE;
      v_number     NUMBER;
      v_pos        NUMBER;
      v_iso_moneda NUMBER;
   BEGIN
      -- obtenemos la direccion de correo de la cuenta debito
      IF p_tipo = 'P' THEN -- es una recibida, se notifica a la cuenta credito
         v_dir_correo := paw_seg.fu_obt_mail(fug_obt_cli_principal(p_nro_cta_credito));
      ELSE
         v_dir_correo := paw_seg.fu_obt_mail(fug_obt_cli_principal(p_nro_cta_debito));
      END IF;
      -- controlamos el envio de correo

      -- ---------- cabecera --------------
      -- titulo
      IF p_tipo = 'R' THEN
         v_cabecera := 
            paw_pro.fu_not_titulo_err('REVERSION DE TRANSFERENCIA A GNB PY');
      ELSIF p_tipo = 'T' THEN
         v_cabecera := 
            -- titulo
            paw_pro.fu_not_titulo('TRANSFERENCIA A GNB PY EN PROCESO');
      ELSIF p_tipo = 'P' THEN
         v_cabecera := 
            -- titulo
            paw_pro.fu_not_titulo('TRANSFERENCIA RECIBIDA DE GNB PY');
      ELSE
         v_cabecera := 
            -- titulo
            paw_pro.fu_not_titulo('TRANSFERENCIA ENVIADA A GNB PY');
      END IF;

      v_cabecera := v_cabecera ||
            -- inicio tabla
            paw_pro.fu_not_ini_tabla || 
            -- inicio tbody
            paw_pro.fu_not_ini_tab_cuerpo;

      -- ---------- pie --------------
      -- fin tabla, fin div
      v_pie := 
            -- fin tbody
            paw_pro.fu_not_fin_tab_cuerpo || 
            -- fin table
            paw_pro.fu_not_fin_tabla;

      IF p_tipo = 'T' THEN
         v_detalle := v_detalle || '<tr><td colspan=2>' || utl_url.escape('Estimado Cliente: en este momento se esta procesando la transferencia. En caso de dudas, por favor comuniquese al Call Center 021 417 6000.', TRUE, 'UTF-8') || '</td></tr><tr rowspan=2><td colspan=2></td></tr>';
      END IF;

      IF p_tipo = 'R' THEN
         v_detalle := v_detalle || '<tr><td colspan=2>' || utl_url.escape('Estimado Cliente, le informamos que la siguiente operacion fue reversada.', TRUE, 'UTF-8') || '</td></tr><tr rowspan=2><td colspan=2></td></tr>';
      END IF;

      IF p_tipo = 'P' THEN
         v_detalle := v_detalle || '<tr><td colspan=2>' || utl_url.escape('Estimado Cliente: se a acreditado la siguiente operacion recibida.', TRUE, 'UTF-8') || '</td></tr><tr rowspan=2><td colspan=2></td></tr>';
      END IF;

      v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro. de Operacion', p_nro_referencia);
      IF p_tipo <> 'P' THEN 
         v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro cuenta remitente', p_nro_cta_debito);
         v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nombre remitente', fug_obt_nom_cuenta(p_nro_cta_debito));
      ELSE
         v_pos := instr(p_nro_cta_debito, ' ');
         IF v_pos > 0 THEN 
           -- cta y nombre benef separado por ' '
           v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro cuenta remitente', TRIM(substr(p_nro_cta_debito, 1, v_pos)));
           v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nombre remitente', utl_url.escape(TRIM(substr(p_nro_cta_debito, v_pos, 100)), TRUE, 'UTF-8'));
         ELSE
            v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro cuenta remitente', p_nro_cta_debito);
         END IF;
      END IF;
      v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro cuenta beneficiario', p_nro_cta_credito);
      IF p_nom_beneficiario IS NOT NULL THEN
         v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nombre beneficiario', utl_url.escape(p_nom_beneficiario, TRUE, 'UTF-8'));
      END IF;
      IF p_concepto IS NOT NULL THEN
         v_detalle := v_detalle || paw_pro.fu_not_row_tag('Concepto', utl_url.escape(p_concepto, TRUE, 'UTF-8'));
      END IF;
      IF p_cod_mon_credito <> pag_gen.fu_obt_mon_local() THEN
         v_iso_moneda := 840;
      ELSE
         v_iso_moneda := 600;
      END IF;
      v_detalle := v_detalle || paw_pro.fu_not_row_tag('Importe', p_cod_mon_credito|| ' ' ||lf_obt_mto_formateado(p_mto_credito, v_iso_moneda));   
      v_detalle := v_detalle || paw_pro.fu_not_row_tag('Fecha Operacion', to_char(sysdate, 'dd/mm/yyyy'));
      v_detalle := v_detalle||'<tr><td> </td><td> </td></tr><tr><td> </td><td> </td></tr><tr><td> </td><td> </td></tr>';

      -- fin div    
      v_number := paw_not.fu_env_email_prueba(v_dir_correo, v_cabecera || v_detalle || v_pie, 'paw_not');
      IF v_dir_correo IS NULL THEN
         lp_reg_mensaje('paw_pro.fu_not_tra_gnb_mail#:'||p_nro_referencia, 'res:'||v_number||', cor:'||v_dir_correo||', cta:'||p_nro_cta_debito);
      END IF;
      RETURN v_number;
   EXCEPTION
      WHEN OTHERS THEN
         lp_reg_mensaje('paw_pro.fu_not_tra_gnb_mail##referencia:'||p_nro_referencia, sqlerrm);      
         RETURN -99;
   END;

/* Alta de cliente */
 FUNCTION fu_alt_cliente(p_cod_persona IN BA_PERSONAS.COD_PERSONA%TYPE, p_cod_destino IN BW_NOT_CLI_DESTINO.COD_DESTINO%TYPE,
                         p_direccion IN BW_NOT_CLI_DESTINO.DIRECCION%TYPE, p_cod_origen IN BW_NOT_CLI_DESTINO.COD_ORIGEN%TYPE,
                         p_cod_evento IN BW_NOT_EVENTOS.COD_EVENTO%TYPE DEFAULT 0, p_nro_cuenta IN GE_CUENTAS.NRO_CUENTA%TYPE DEFAULT NULL) RETURN NUMBER IS
    v_template       bw_not_tip_eventos.template%TYPE;
    v_mensaje        bw_not_mensajes.mensaje%TYPE;
    v_ret            NUMBER(3) := 0;
    v_tip_evento     VARCHAR2(15) := 'NOTALTAMAS';
    v_fec_programada DATE;
 BEGIN
    BEGIN
       INSERT INTO bw_not_cli_suscriptos
          (cod_persona, fec_suscripcion, activo, cod_origen)
       VALUES
          (p_cod_persona, SYSDATE, 'S', p_cod_origen);
    EXCEPTION
       WHEN OTHERS THEN
          RETURN 1;
    END;
    BEGIN
       INSERT INTO bw_not_cli_destino
          (cod_persona, cod_destino, direccion, activo, cod_origen)
       VALUES
          (p_cod_persona, p_cod_destino, p_direccion, 'S', p_cod_origen);
    EXCEPTION
       WHEN OTHERS THEN
          RETURN 2;
    END;

    v_fec_programada := trunc(SYSDATE)+(9/24);
    IF fu_obt_not_template(v_tip_evento, v_template, '00') <> 0 THEN
       RETURN 20;
    END IF;

    RETURN 0;--fu_ins_mensaje(0, p_cod_origen, v_template, p_cod_persona, p_cod_origen, v_fec_programada, 'S');


 END;

  function lf_ver_not_push(p_cod_persona IN varchar2)  RETURN VARCHAR2 IS 
  v_existe varchar2(1);
  BEGIN
      v_existe:='N';
      BEGIN
        SELECT 'S'
          INTO v_existe
          FROM bw_not_cli_destino c, bw_not_destinos d
         WHERE c.cod_persona = p_cod_persona
           and upper(d.nombre)='PUSH'
           --AND c.activo = 'S'
           AND d.cod_destino = c.cod_destino;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe:='N';
        WHEN OTHERS THEN
          v_existe:='N';
      END;
      return v_existe;
  END;  
/* Alta compulsiva de clientes */ 
--Caso: DYDMR-3428
PROCEDURE pr_alt_compulsiva IS
  --Cambio realizado: modificacion del curso c_clientes(busca clientes que aun no estan suscriptos notificaciones).
  CURSOR c_clientes IS
    SELECT DISTINCT COD_PERSONA
      FROM (SELECT DISTINCT GE_CTA_CLIENTES.COD_PERSONA
              FROM ge_pag_sueldos s
             INNER JOIN GE_CTA_CLIENTES
                ON s.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
             INNER JOIN BA_PERSONAS
                ON GE_CTA_CLIENTES.COD_PERSONA = BA_PERSONAS.COD_PERSONA
             WHERE s.fec_insercion > SYSDATE - 30
               AND s.tipo = 'C'
               AND GE_CTA_CLIENTES.RELACION = 'P'
               AND BA_PERSONAS.TIPO = 'F'
               AND NOT EXISTS
             (SELECT *
                      FROM BW_NOT_CLI_SUSCRIPTOS
                     WHERE BW_NOT_CLI_SUSCRIPTOS.COD_PERSONA =
                           GE_CTA_CLIENTES.COD_PERSONA)
            UNION
            SELECT DISTINCT GE_CTA_CLIENTES.COD_PERSONA
              FROM GE_CTA_CLIENTES
             INNER JOIN TA_TARJETAS
                ON TA_TARJETAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
             INNER JOIN BA_PERSONAS
                ON GE_CTA_CLIENTES.COD_PERSONA = BA_PERSONAS.COD_PERSONA
             WHERE TA_TARJETAS.COD_ESTADO = 10
               AND TA_TARJETAS.Fec_Vencimiento > SYSDATE
               AND GE_CTA_CLIENTES.Cod_Modulo = 5
               AND GE_CTA_CLIENTES.RELACION = 'P'
               AND BA_PERSONAS.TIPO = 'F'
               AND NOT EXISTS
             (SELECT *
                      FROM BW_NOT_CLI_SUSCRIPTOS
                     WHERE BW_NOT_CLI_SUSCRIPTOS.COD_PERSONA =
                           GE_CTA_CLIENTES.COD_PERSONA));
  /*      SELECT DISTINCT COD_PERSONA
  FROM (SELECT DISTINCT GE_CTA_CLIENTES.COD_PERSONA
           FROM ge_pag_sueldos s
          INNER JOIN GE_CTA_CLIENTES
             ON s.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
          INNER JOIN BA_PERSONAS
             ON GE_CTA_CLIENTES.COD_PERSONA = BA_PERSONAS.COD_PERSONA
          WHERE s.fec_insercion > SYSDATE - 30
            AND s.tipo = 'C'
            AND GE_CTA_CLIENTES.RELACION = 'P'
            AND BA_PERSONAS.TIPO = 'F'
         UNION
         SELECT DISTINCT GE_CTA_CLIENTES.COD_PERSONA
           FROM GE_CTA_CLIENTES
          INNER JOIN TA_TARJETAS
             ON TA_TARJETAS.NRO_CUENTA = GE_CTA_CLIENTES.NRO_CUENTA
          INNER JOIN BA_PERSONAS
             ON GE_CTA_CLIENTES.COD_PERSONA = BA_PERSONAS.COD_PERSONA
          WHERE TA_TARJETAS.COD_ESTADO = 10
            AND TA_TARJETAS.Fec_Vencimiento > SYSDATE
            AND GE_CTA_CLIENTES.Cod_Modulo = 5
            AND GE_CTA_CLIENTES.RELACION = 'P'
            AND BA_PERSONAS.TIPO = 'F');*/

  v_celular     VARCHAR2(50);
  v_cod_destino BW_NOT_CLI_DESTINO.COD_DESTINO%TYPE;
  v_ret         NUMBER(4) := 0;
BEGIN
  -- ALTER TRIGGER TA_BW_NOT_CLI_DESTINO DISABLE;
  SELECT cod_destino
    INTO v_cod_destino
    FROM bw_not_destinos
   WHERE nombre = 'SMS';
  FOR i IN c_clientes LOOP
    v_celular := fu_obt_tel_cliente(i.cod_persona);
    IF v_celular IS NOT NULL THEN
      v_ret := fu_alt_cliente(i.cod_persona,
                              v_cod_destino,
                              v_celular,
                              'COMP');
    END IF;
  END LOOP;
  --ALTER TRIGGER TA_BW_NOT_CLI_DESTINO ENABLE;   
END;

FUNCTION fu_obt_tel_cliente(p_cod_persona IN ba_personas.cod_persona%TYPE)
  RETURN VARCHAR2 IS
  v_area     BA_TELEFONOS.AREA%TYPE;
  v_telefono BA_TELEFONOS.TELEFONO%TYPE;
  v_celular  VARCHAR2(50);
BEGIN
  --Buscar numero de notificaciones
  BEGIN
    SELECT d.direccion
      INTO v_celular
      FROM bw_not_cli_destino d
     INNER JOIN BW_NOT_DESTINOS
        ON d.COD_DESTINO = BW_NOT_DESTINOS.COD_DESTINO
     WHERE d.cod_destino = 1
       AND d.cod_persona = p_cod_persona
       AND BW_NOT_DESTINOS.NOMBRE = 'SMS'
       AND rownum = 1;
    RETURN v_celular;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
  END;
  --Buscar en Token
  BEGIN
    SELECT m.ref_medio
      INTO v_celular
      FROM bw_otp_ref_medios m
     WHERE m.tipo = 'C' --Celular
       AND m.cod_persona = p_cod_persona
       AND ROWNUM = 1;
    RETURN v_celular;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
  END;
  --Buscar en la carpeta de la persona, prioridad claro, personal, tigo y el resto
  BEGIN
    SELECT area, telefono
      INTO v_area, v_telefono
      FROM (SELECT substr(area, 0, 4) AS area, telefono
              FROM ba_telefonos
             WHERE cod_persona = p_cod_persona
               AND substr(area, 0, 3) IN ('099', '097', '098')
               AND tipo = 'P' --Particular
               AND tip_linea = 'C' --Celular
             ORDER BY decode(substr(area, 0, 3),
                             '099',
                             3,
                             '097',
                             2,
                             '098',
                             1) DESC NULLS LAST)
     WHERE ROWNUM = 1;

    --Caso: DYDMR-3428
    --Cambio realizado: Se mejora la función fu_obt_tel_cliente, para que maneje los espacios en blanco y longitud del telefono
    IF v_area IS NOT NULL THEN
      v_celular := v_area || v_telefono;
      v_celular := replace(v_celular, ' ', '');
      IF LENGTH(v_celular) = 10 THEN
        --debe tener exactamente 10 (formato 098XXXXXXX)
        RETURN v_celular;
      ELSE
        RETURN null;
      END IF;
    ELSIF v_area IS NULL THEN
      v_celular := v_telefono;
      v_celular := replace(v_celular, ' ', '');
      IF LENGTH(v_celular) = 10 THEN
        --debe tener exactamente 10 (formato 098XXXXXXX)
        RETURN v_celular;
      ELSE
        RETURN null;
      END IF;
    ELSE
      RETURN null;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN null;
  END;

END;
   FUNCTION fu_sus_cuenta(p_sesion IN bw_aut_sesiones.cod_sesion%TYPE, p_cod_canal IN bw_movimientos.nro_caja%TYPE,
                          p_nro_cuenta ge_cuentas.nro_cuenta%TYPE, p_modo IN VARCHAR2) RETURN NUMBER IS
      v_sesion        bw_aut_sesiones%ROWTYPE := NULL;
      v_cod_operacion VARCHAR2(3) := '551';
      v_cod_persona   ba_personas.cod_persona%TYPE;
      v_mensaje       typ_mensajerespuesta := typ_mensajerespuesta();

   FUNCTION lf_obt_push(p_cod_persona ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
     --Verifica que el cliente este suscripto a push
      v_sus_push VARCHAR2(1);
   BEGIN
      BEGIN
         SELECT 'S'
           INTO v_sus_push
           FROM bw_not_cli_destino c, bw_not_destinos d
          WHERE c.cod_destino = d.cod_destino
            AND d.nombre = 'PUSH'
            AND c.activo = 'S'
            AND rownum = 1
            AND c.cod_persona = p_cod_persona;
      EXCEPTION
         WHEN OTHERS THEN
            v_sus_push := 'N';
      END;
      RETURN v_sus_push;
   END;
   --deactiva las suscripciones de un cliente
   FUNCTION lf_cam_suscripciones(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_cod_persona ba_personas.cod_persona%TYPE, p_estado IN VARCHAR2)
      RETURN NUMBER IS
   BEGIN
      IF lf_obt_push(p_cod_persona) = 'N' or p_estado='N' THEN
      UPDATE bw_not_suscripciones
         SET activo = p_estado
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_persona = p_cod_persona;
      ELSE
         UPDATE bw_not_suscripciones s
            SET s.activo = p_estado
          WHERE s.nro_cuenta = p_nro_cuenta
            AND s.cod_persona = p_cod_persona
            AND s.cod_evento IN (SELECT p.cod_evento
                                   FROM bw_not_paquetes p
                                  WHERE p.activo = 'S'
                                    AND p.paquete = 1);
      END IF;
      RETURN 0;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN - 20;
   END;

   FUNCTION lf_ver_suscripciones(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE, p_cod_persona ba_personas.cod_persona%TYPE)
      RETURN NUMBER IS
      v_can NUMBER(4);
   BEGIN
      SELECT COUNT(*)
        INTO v_can
        FROM bw_not_suscripciones
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_persona = p_cod_persona
         and activo='S';
      IF v_can = 0 THEN
         RETURN 0;
      ELSE
         RETURN 1;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 0;
   END;

   BEGIN
      v_sesion := lf_val_sesion(p_sesion, p_cod_canal);
      IF v_sesion.cod_sesion IS NULL THEN
         RETURN - 1;
      END IF;
      v_cod_persona := nvl(v_sesion.cod_per_vinculada, v_sesion.cod_persona);
      paw_bel.pr_mensajeUsuario('OP_APROBADA', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);
      paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                  'fu_sus_cuenta ' ||
                                   paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ENT');
      if(lf_val_cta_origen(p_nro_cuenta,v_cod_persona)='S') then

      case
        when p_modo='A' then
          return lf_cam_suscripciones(p_nro_cuenta,v_cod_persona,'S');
        when p_modo='D' then
          return lf_cam_suscripciones(p_nro_cuenta,v_cod_persona,'N');
        when p_modo='C' then
          return lf_ver_suscripciones(p_nro_cuenta , v_cod_persona);
      end case;
      else
        return -30;
      end if;


      EXCEPTION
      WHEN OTHERS THEN
         paw_bel.pr_mensajeUsuario('OP_ERROR', v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, v_mensaje.error);      
         paw_bel.pr_insertarBitacora(v_sesion.cod_persona, p_cod_canal, p_sesion, v_cod_operacion, v_sesion.cod_per_vinculada,
                                     'fu_sus_cuenta - ERR: [' || substr(SQLERRM, 1, 500) || '] ' ||
                                      paw_bel.fu_generarbitacora(v_mensaje.error, v_mensaje.nombreRespuesta, v_mensaje.descripcionRespuesta, NULL), 'ERR');
         RETURN -99;
   END;
      -- reemplaza los acentos para envío de mails      
      FUNCTION lf_reemplazoAcentos(p_texto IN VARCHAR2) RETURN VARCHAR2 IS
         v_retorno VARCHAR2(3000);
      BEGIN
         SELECT translate(p_texto, 'áéíóúàèìòùãõâêîôôäëïöüçñÁÉÍÓÚÀÈÌÒÙÃÕÂÊÎÔÛÄËÏÖÜÇÑ', 'aeiouaeiouaoaeiooaeioucnAEIOUAEIOUAOAEIOOAEIOUCN')
           INTO v_retorno
           FROM dual;
         RETURN v_retorno;
      END;

   FUNCTION fu_env_mail_can_prod RETURN NUMBER IS
      v_enviado    VARCHAR2(1) := 'N';
      v_mensaje    VARCHAR2(3500);
      v_dir_correo VARCHAR2(2000);
      v_number     NUMBER;
      v_db_name    VARCHAR2(20);
      v_can        NUMBER := 0;

      CURSOR c_pendientes IS
         SELECT *
           FROM bw_sol_can_productos
          WHERE enviado = 'N';


   BEGIN
      FOR reg IN c_pendientes
      LOOP
         BEGIN
            v_mensaje := '<h2 style="color:#074CA9; font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; margin-top:0px">SOLICITUD DE CANCELACION DE PRODUCTOS Y/O SERVICIOS CONTRATADOS EN CANALES</h2>';
            v_mensaje := v_mensaje || '
             <table width="500"; style="font-family: ' || chr(39) || 'Helvetica Neue' || chr(39) || ', Helvetica, Arial, sans-serif; font-size:14px;">
              <tbody >
                 <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nombre del Cliente:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || lf_reemplazoAcentos(fue_obt_nom_persona(reg.cod_persona)) || '</td>
                 </tr>
                 <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Tipo de Producto o Servicio:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || lf_reemplazoAcentos(reg.tip_producto) || '</td>
                 </tr>
                 <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nro. del Producto o Servicio:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || reg.nro_producto || '</td>
                 </tr>
                 <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Motivo de la Cancelacion:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || lf_reemplazoAcentos(reg.mot_cancelacion) || '</td>
                 </tr>
                 <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Comentarios del Cliente:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || lf_reemplazoAcentos(reg.comentarios) || '</td>
                 </tr>
                 <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Telefono de Contacto:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || reg.tel_contacto || '</td>
                 </tr>
                 <tr>
                    <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Email de Contacto:</b></td>
                    <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">' || lf_reemplazoAcentos(reg.mail_contacto) || '</td>
                 </tr>
              </tbody>
             </table>';
            v_mensaje := '<div style="padding:20px 20px">' || v_mensaje || '</div>';

            v_dir_correo := fug_obt_pardinamico('MAIL_CAN_PROD_HB');
            v_number     := paw_not.fu_env_email_prueba(v_dir_correo, v_mensaje, 'Yaguarete');

         EXCEPTION
            WHEN OTHERS THEN
               v_number := -99;
         END;

         IF v_number = -99 THEN
            v_enviado := 'N';
         ELSE
            v_enviado := 'S';
            v_can     := v_can + 1;
         END IF;

         BEGIN
            -- actualizar el estado del envío del mail
            UPDATE bw_sol_can_productos
               SET enviado = v_enviado
             WHERE cod_persona = reg.cod_persona
               AND tip_producto = reg.tip_producto
               AND nro_producto = reg.nro_producto
               AND fec_solicitud = reg.fec_solicitud;
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END LOOP;

      RETURN v_can;
   END;

FUNCTION fu_obt_con_blacklist(p_cod_persona IN ba_personas.cod_persona%TYPE, p_cod_tip_evento IN bw_not_tip_eventos.cod_tip_evento%TYPE) RETURN VARCHAR IS
   v_existe VARCHAR(1);
BEGIN
   BEGIN
      SELECT 'S'
        INTO v_existe
        FROM bw_not_blacklist b
       WHERE b.cod_persona = p_cod_persona
         AND b.activo = 'S'
         AND ((b.tip_bloqueo = 2)
          OR (b.tip_bloqueo = 1 AND b.cod_tip_evento = p_cod_tip_evento));
   EXCEPTION
      WHEN OTHERS THEN
         RETURN 'N';
   END;
   RETURN 'S';
END;

FUNCTION fu_blacklist(p_cod_sesion     IN BW_AUT_SESIONES.COD_SESION%TYPE,
                      p_cod_canal      IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                      p_tip_operacion  IN VARCHAR2,
                      p_tip_bloqueo    IN BW_NOT_BLACKLIST.TIP_BLOQUEO%TYPE,
                      p_cod_tip_evento IN BW_NOT_BLACKLIST.COD_TIP_EVENTO%TYPE DEFAULT NULL) RETURN TYP_MENSAJERESPUESTA IS
   v_log_datos      BW_BITACORAS.DATO%TYPE;
   v_cod_operacion  VARCHAR2(3) := '231';
   v_cod_sesion     BW_AUT_SESIONES.COD_SESION%TYPE;
   v_cod_canal      BW_AUT_SESIONES.COD_CANAL%TYPE;
   v_sesion_info    paw_bel.typ_validarSesion;
   v_tip_operacion  VARCHAR2(1);
   v_cod_tip_evento BW_NOT_BLACKLIST.COD_TIP_EVENTO%TYPE;
   v_activo         BW_NOT_BLACKLIST.ACTIVO%TYPE;
   v_retorno        typ_mensajeRespuesta := typ_mensajeRespuesta;

   -- errores retornados
   PAR_ENT_INV CONSTANT VARCHAR2(15) := 'PAR_ENT_INV';
BEGIN
   PAW_BEL.pr_mensajeUsuario(MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);

   -- valida sesión del cliente
   v_cod_sesion  := PAW_BEL.depurarAlfanumerico(p_cod_sesion, 32);
   v_cod_canal   := PAW_BEL.depurarNumerico(p_cod_canal, 3);
   v_sesion_info := PAW_BEL.fu_validarSesion(v_cod_sesion, p_cod_canal);
   IF v_sesion_info.error = 'S' THEN
      v_retorno.error                := v_sesion_info.error;
      v_retorno.nombreRespuesta      := v_sesion_info.nombreRespuesta;
      v_retorno.descripcionRespuesta := v_sesion_info.descripcionRespuesta;
      PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, 'fu_blacklist: [sesion invalida]', BITACORA_ERROR);
      RETURN v_retorno;
   END IF;

   v_log_datos := 'fu_blacklist: [p_tip_operacion=' || p_tip_operacion || ', p_tip_bloqueo=' || p_tip_bloqueo || ', p_cod_tip_evento=' || p_cod_tip_evento || ']';
   PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, v_log_datos, BITACORA_ENTRADA);

   -- valida tipo de operación
   v_tip_operacion := PAW_BEL.depurarAlfanumerico(p_tip_operacion, 1);
   IF (v_tip_operacion IS NULL OR v_tip_operacion NOT IN ('A', 'D')) THEN
      PAW_BEL.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, 'fu_blacklist: [parametro p_tip_operacion con valor incorrecto]', BITACORA_ERROR);
      RETURN v_retorno;
   END IF;

   -- valida tipo de bloqueo
   IF (p_tip_bloqueo IS NULL OR (p_tip_bloqueo < 1 AND p_tip_bloqueo > 2)) THEN
      PAW_BEL.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, 'fu_blacklist: [parametro p_tip_bloqueo con valor incorrecto]', BITACORA_ERROR);
      RETURN v_retorno;
   END IF;

   -- valida el código del tipo de evento a bloquear
   v_cod_tip_evento := PAW_BEL.depurarAlfanumerico(p_cod_tip_evento, 10);
   IF (p_tip_bloqueo = 1 AND v_cod_tip_evento IS NULL) THEN
      PAW_BEL.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, 'fu_blacklist: [parametro p_cod_tip_evento con valor incorrecto]', BITACORA_ERROR);
      RETURN v_retorno;
   END IF;
   IF (p_tip_bloqueo = 2 AND v_cod_tip_evento IS NOT NULL) THEN
      PAW_BEL.pr_mensajeUsuario(PAR_ENT_INV, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
      PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, 'fu_blacklist: [parametro p_cod_tip_evento con valor incorrecto]', BITACORA_ERROR);
      RETURN v_retorno;
   END IF;

   -- determina el tipo de actualización
   IF v_tip_operacion = 'A' THEN
      -- activa el bloqueo
      v_activo := 'S';
   ELSE
      --desactiva el bloqueo
      v_activo := 'N';
   END IF;

   -- actualiza el estado del bloqueo 
   BEGIN
      IF p_tip_bloqueo = 2 THEN
         UPDATE BW_NOT_BLACKLIST
            SET activo = v_activo
          WHERE cod_persona = v_sesion_info.codigoPersona
                AND tip_bloqueo = p_tip_bloqueo;
      ELSE
         UPDATE BW_NOT_BLACKLIST
            SET activo = v_activo
          WHERE cod_persona = v_sesion_info.codigoPersona
                AND tip_bloqueo = p_tip_bloqueo
                AND cod_tip_evento = v_cod_tip_evento;
      END IF;
      IF SQL%ROWCOUNT = 0 THEN
         INSERT INTO BW_NOT_BLACKLIST
            (cod_persona, cod_tip_evento, tip_bloqueo, activo)
         VALUES
            (v_sesion_info.codigoPersona, v_cod_tip_evento, p_tip_bloqueo, v_activo);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         PAW_BEL.pr_mensajeUsuario(MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);
         PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, 'fu_blacklist: [insercion: bw_not_blacklist, ORA-ERR: ' || SUBSTR(SQLERRM, 1, 200) || '] ', BITACORA_ERROR);
         RETURN v_retorno;
   END;

   PAW_BEL.pr_insertarBitacora(v_sesion_info.codigoPersona, v_sesion_info.codigoCanal, v_cod_sesion, v_cod_operacion, NULL, PAW_BEL.fu_generarBitacora(v_retorno.error, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta), BITACORA_SALIDA);

   RETURN v_retorno;
END;

FUNCTION fu_enc_push(p_cod_persona IN ba_personas.cod_persona%TYPE, p_mensaje IN bw_not_mensajes.mensaje%TYPE) RETURN NUMBER IS
BEGIN
   IF (lf_ver_destino(p_cod_persona, 'PUSH') IS NULL) THEN
      RETURN 1;
   END IF;
   return fu_ins_mensaje(48, 'PROMOPUSH', p_mensaje, p_cod_persona, 'PROMOPUSHT', null, 'S');   

END;

FUNCTION fu_not_pus_publicidad RETURN NUMBER IS
   v_prom_activas NUMBER(4) := 0;
   v_aux          NUMBER(4) := 0;
   CURSOR cPromociones IS
      SELECT cod_mensaje, mensaje
        FROM BW_NOT_PUSH
       WHERE activo = 'S'
         AND trunc(fec_inicio) < SYSDATE
         AND trunc(fec_fin + 1) > SYSDATE;

   FUNCTION lf_enc_mensajes(p_promocion IN BW_NOT_PUSH.COD_MENSAJE%TYPE, p_mensaje IN BW_NOT_PUSH.Mensaje%TYPE) RETURN NUMBER IS
      CURSOR cClientesPush(cp_promocion BW_NOT_PUSH.COD_MENSAJE%TYPE) IS
         SELECT c.direccion, c.cod_persona, c.cod_origen
           FROM bw_not_cli_destino c, bw_not_destinos d
          WHERE d.cod_destino = c.cod_destino
            AND d.nombre = 'PUSH'
            AND c.activo = 'S'
            AND paw_not.fu_obt_con_blacklist(c.cod_persona, 'PROMOPUSH') = 'N'
            AND c.cod_persona NOT IN (SELECT cod_persona
                                        FROM BW_NOT_PRO_ENVIADOS
                                       WHERE cod_promocion = cp_promocion
                                         AND cod_persona = c.cod_persona);
   BEGIN
      FOR cCliente IN cClientesPush(p_promocion)
      LOOP
         BEGIN
            INSERT INTO BW_NOT_PRO_ENVIADOS
               (cod_promocion, cod_persona)
            VALUES
               (p_promocion, cCliente.Cod_Persona);
            v_aux := fu_ins_mensaje(48, 'PROMOPUSH', p_mensaje, cCliente.Cod_Persona, 'PROPU_' || p_promocion, NULL, 'S');
         EXCEPTION
            WHEN OTHERS THEN
               lp_reg_mensaje('fu_not_pus_publicidad:'||p_promocion||'-'||cCliente.Cod_Persona, SQLERRM);               
         END;
      END LOOP;
      RETURN 0;
   END;

BEGIN
   SELECT COUNT(*)
     INTO v_prom_activas
     FROM BW_NOT_PUSH
    WHERE activo = 'S'
      AND trunc(fec_inicio) < SYSDATE
      AND trunc(fec_fin + 1) > SYSDATE;

   IF (v_prom_activas = 0) THEN
      RETURN - 10;
   END IF;

   FOR cPromocion IN cPromociones
   LOOP
      v_aux := lf_enc_mensajes(cPromocion.Cod_Mensaje, cPromocion.Mensaje);
   END LOOP;

   RETURN v_aux;
END;

   -- obtiene destino activo de un cliente
   FUNCTION fu_obt_cli_des_activo(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
      v_direccion   bw_not_cli_destino.direccion%TYPE := NULL;
      v_cod_destino bw_not_cli_destino.cod_destino%TYPE := NULL;
   BEGIN
      BEGIN
         SELECT d.direccion, d.cod_destino
           INTO v_direccion, v_cod_destino
           FROM bw_not_cli_destino d
          WHERE d.cod_persona = p_cod_persona
            AND d.activo = 'S'
            AND ROWNUM=1;

         IF v_cod_destino = 3 THEN -- push, no mostrar direccion larga
            v_direccion := 'Servicio PUSH'; 
         END IF;
         RETURN v_direccion;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END;
   END;

   -- alta compulsiva de cliente
   FUNCTION fu_alt_notificacion(p_cod_persona IN bw_not_cli_destino.cod_persona%TYPE,
                                p_direccion   IN OUT VARCHAR2) RETURN NUMBER IS
      v_cod_destino bw_not_destinos.cod_destino%TYPE := -1;
      v_direccion   bw_not_cli_destino.direccion%TYPE := NULL;
      v_retorno     NUMBER := 0;
      v_suscrito    VARCHAR2(1);
   BEGIN
      -- buscamos el codigo destino 'SMS'
      BEGIN
         SELECT cod_destino
           INTO v_cod_destino
           FROM bw_not_destinos
          WHERE nombre = 'SMS';
      EXCEPTION
         WHEN OTHERS THEN
            RETURN -1;
      END;
      -- buscamos un celular valido, si la direccion recibida eNOs nula
      v_direccion := substr(TRIM(nvl(p_direccion, paw_not.fu_obt_tel_cliente(p_cod_persona))), 1, 200);
      -- si no tiene direccion de notificacion alguna, no se puede agregar
      IF v_direccion IS NULL THEN
         RETURN -2;
      END IF;
      -- suscribimos
      v_suscrito := fu_obt_suscripcion(p_cod_persona);
      IF v_suscrito = 'N' THEN
         BEGIN
            INSERT INTO bw_not_cli_suscriptos
               (cod_persona, fec_suscripcion, activo, cod_origen)
            VALUES
               (p_cod_persona, SYSDATE, 'S', 'COMP');
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               v_retorno := 1;
               -- activamos el cliente               
               UPDATE bw_not_cli_suscriptos s
                  SET s.activo = 'S'
                WHERE s.cod_persona = p_cod_persona;
               --lf_upd_not_inactiva(p_cod_persona);
         END;
      END IF;
      -- verificamos insercion de destino
      -- si direccion recibida es nula, no se cuenta con destino activo
      IF p_direccion IS NULL THEN
         v_retorno := v_retorno + 2; -- agregamos destino activo modificado
         BEGIN
            INSERT INTO bw_not_cli_destino
               (cod_persona, cod_destino, direccion, activo, cod_origen)
            VALUES
               (p_cod_persona, v_cod_destino, v_direccion, 'S', 'COMP');
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               v_retorno := v_retorno + 4;
               -- puede estar agregada la direccion, pero inactiva, activamos
               UPDATE bw_not_cli_destino d
                  SET d.activo = 'S'
                WHERE d.cod_persona = p_cod_persona
                  AND d.direccion = v_direccion;
         END;
         p_direccion := v_direccion;
      END IF;

      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         lp_reg_mensaje('fu_alt_notificacion['||p_cod_persona||'-'||p_direccion||']', SQLERRM);  
         RETURN -99;
   END;

   -- notificar disponibilidad de extracto
   FUNCTION fu_not_extracto(p_dato        IN VARCHAR2,
                            p_fecha       IN ge_calendarios.fec_actual%TYPE,
                            p_nro_tarjeta IN ta_tarjetas.nro_tarjeta%TYPE DEFAULT NULL) RETURN NUMBER IS
      v_nro_cuenta     ge_cuentas.nro_cuenta%TYPE := NULL;
      v_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE := 'EXTRDIGIT';
      v_cod_evento     bw_not_eventos.cod_evento%TYPE;
      v_horario        bw_not_eventos.horario%TYPE;
      v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
      v_mandatorio     bw_not_eventos.mandatorio%TYPE;
      v_template       bw_not_tip_eventos.template%TYPE;
      v_mensaje        bw_not_mensajes.mensaje%TYPE;
      v_ret            NUMBER(3) := 0;
      v_iso_moneda     NUMBER(3) := 600;
      v_cod_persona    ba_personas.cod_persona%TYPE;
   BEGIN
      -- obtenemos los templates correspondientes
      IF p_nro_tarjeta IS NOT NULL THEN
         BEGIN
            -- SAN tiene la cedula del cliente, buscamos el codigo de persona
            v_cod_persona := fue_obt_cod_persona(p_dato);

            -- si se recibe cuenta, es porque debe ser una tarjeta que es principal la persona
            SELECT t.nro_cuenta
              INTO v_nro_cuenta
              FROM ta_tarjetas t, ge_cta_clientes cc
             WHERE substr(t.nro_tarjeta, -4 ) = p_nro_tarjeta
               AND t.cod_persona = v_cod_persona               
               AND t.nro_cuenta = cc.nro_cuenta  
               AND cc.cod_persona = t.cod_persona               
               AND cc.relacion = 'P'
               AND rownum=1;
            -- verificamos que tarjeta retenga impresion
            IF pat_imp.FU_RET_EXTRACTO(v_nro_cuenta) = 'N' THEN
               RETURN -5;   
            END IF;
            -- verificamos suscripcion a Extracto Clic
            IF nvl(paw_not.fu_obt_sus_ext_clic(v_cod_persona,v_nro_cuenta),'N') = 'N' then -- DYDMR-6268 -- 03/2017 -- Suscrito a Extracto Clic
               RETURN -5;  
            END IF;
            -- obtenemos el template de tarjeta   
            IF fu_obt_not_template(v_cod_tip_evento, v_template, '01') <> 0 THEN
               RETURN 20;
            END IF;
            -- preparamos el mensaje
            --BBVA le informa: el extracto de su tarjeta %s al %, se encuentra disponible.
            v_mensaje := utl_lms.format_message(v_template, lf_obt_ult_tarjeta(p_nro_tarjeta), to_char(p_fecha, 'dd/mm/yyyy'));
         EXCEPTION
            WHEN OTHERS THEN            
               RETURN -1;
         END;
      ELSE
         v_cod_persona := paw_bel.depurarAlfanumerico(p_dato, 10);

         -- sino, es de sus CC/AH
         -- obtenemos el template de cuentas
         IF fu_obt_not_template(v_cod_tip_evento, v_template, '00') <> 0 THEN
            RETURN 20;
         END IF;
         -- preparamos el mensaje
         --BBVA le informa: el extracto de su(s) cuenta(s) al %s, se encuentra disponible.
         v_mensaje := utl_lms.format_message(v_template, to_char(p_fecha, 'dd/mm/yyyy'));
         -- verificar que retenga extracto para notificar         
         IF paw_uti.fu_imp_extracto(v_cod_persona) = 'S' THEN
            RETURN -5;
         END IF;
         -- verificamos suscripcion a Extracto Clic
          IF nvl(paw_not.fu_obt_sus_ext_clic(v_cod_persona,v_nro_cuenta),'N') = 'N' then -- DYDMR-6268 -- 03/2017 -- Suscrito a Extracto Clic
            RETURN -5;
         END IF;
      END IF;
      -- validacion minima de fecha
      IF p_fecha - trunc(sysdate) > 30 THEN
         RETURN -3;
      END IF;
      --se obtiene los datos de la notificacion de extracto
      v_ret := fu_obt_eve_suscripcion(v_cod_persona, NULL, v_cod_tip_evento, v_cod_evento, v_horario, 0,v_iso_moneda, v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN     
         --esta suscripto, notificamos
         v_ret := fu_ins_mensaje(v_cod_evento, v_cod_tip_evento, v_mensaje, v_cod_persona, nvl(v_nro_cuenta, '0'), NULL, 'S');
      END IF;
      RETURN v_ret;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN -99;
   END;
   -- obtener codigo de evento de un tipo
   FUNCTION fu_obt_cod_evento(p_cod_tip_evento IN bw_not_eventos.cod_tip_evento%TYPE,
                              p_cod_modulo     IN bw_not_eventos.cod_modulo%TYPE DEFAULT NULL,
                              p_cod_modalidad  IN bw_not_eventos.cod_modalidad%TYPE DEFAULT NULL,                              
                              p_mandatorio     IN bw_not_eventos.mandatorio%TYPE DEFAULT NULL) RETURN NUMBER IS
      v_retorno bw_not_eventos.cod_evento%TYPE;
   BEGIN
      SELECT e.cod_evento
        INTO v_retorno
        FROM bw_not_eventos e
       WHERE e.cod_tip_evento = p_cod_tip_evento
         AND e.cod_modulo = nvl(p_cod_modulo, e.cod_modulo)
         AND e.cod_modalidad = nvl(p_cod_modalidad, e.cod_modalidad)
         AND e.mandatorio = nvl(p_mandatorio, e.mandatorio)
         AND rownum = 1;
      RETURN v_retorno;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN -1;
   END;

  -- Obtener si el Cliente está suscrito a Extracto Clic
    FUNCTION fu_obt_sus_ext_clic(p_cod_persona IN ba_personas.cod_persona%TYPE, 
                               p_nro_cuenta IN ta_tarjetas.nro_cuenta%TYPE DEFAULT NULL ) RETURN VARCHAR2 IS
     -- Retorna S = Suscrito, N = No Suscrito
     v_suscripto VARCHAR2(1) := 'N';
  BEGIN
    IF p_nro_cuenta IS NOT NULL THEN
       SELECT DISTINCT 'S'
         INTO v_suscripto
         FROM ge_reg_tip_extracto a
        WHERE a.cod_persona = p_cod_persona
          AND a.ret_tarjeta = 'S'
          AND a.tip_novedad = 'A'
          AND (a.nro_cuenta = p_nro_cuenta or a.nro_cuenta is null)
          AND NOT EXISTS (SELECT 1 -- Alta en Extracto Clic que no registra una Baja posterior
                 FROM ge_reg_tip_extracto b
                WHERE b.cod_persona = a.cod_persona
                  AND b.tip_novedad = 'B'
                  AND (b.nro_cuenta =  a.nro_cuenta or b.nro_cuenta is null)
                  AND (b.fecha > a.fecha OR b.fec_insercion > a.fec_insercion));
    ELSE
       SELECT DISTINCT 'S'
         INTO v_suscripto
         FROM ge_reg_tip_extracto a
        WHERE a.cod_persona = p_cod_persona
          AND a.ret_cuenta = 'S'
          AND a.tip_novedad = 'A'
          AND NOT EXISTS (SELECT 1 -- Alta en Extracto Clic que no registra una Baja posterior
                 FROM ge_reg_tip_extracto b
                WHERE b.cod_persona = a.cod_persona
                  AND b.tip_novedad = 'B'
                  AND (b.fecha > a.fecha OR b.fec_insercion > a.fec_insercion));
     END IF;
     RETURN v_suscripto;
  EXCEPTION
     WHEN OTHERS THEN
        RETURN 'N';
  END;

   FUNCTION fu_not_sus_op_sin_tarjeta(p_nro_cuenta          IN BW_CTA_TELEFONOS.NRO_CUENTA%TYPE,
                                      p_nro_celular         IN BW_CTA_TELEFONOS.NRO_CELULAR%TYPE) RETURN NUMBER IS

      v_cabecera        VARCHAR2(700)  := NULL;
      v_detalle         VARCHAR2(3300) := NULL;
      v_pie             VARCHAR2(500)  := NULL;
      v_db_name         VARCHAR2(20);
      v_tag             VARCHAR2(50);
      v_dir_correo      ba_mails.dir_correo%TYPE;
      v_number          NUMBER;
      v_cod_operacion   CONSTANT VARCHAR2(3) := '232';
   BEGIN

      IF nvl(fug_ind_produccion, 'N') != 'S' THEN
         v_dir_correo := fug_obt_pardinamico('OST_SUS_EMA_TEST');
      ELSE
         v_dir_correo := paw_seg.fu_obt_mail(fug_obt_cli_principal(p_nro_cuenta));
      END IF;

      v_cabecera := paw_pro.fu_not_inicio || paw_pro.fu_not_titulo('OPERACIONES SIN TARJETA');
      v_cabecera := v_cabecera || paw_pro.fu_not_sub_titulo(UTL_URL.ESCAPE('Vinculación realizada correctamente', TRUE, 'UTF-8'));
      v_cabecera := v_cabecera || paw_pro.fu_not_ini_tabla || paw_pro.fu_not_ini_tab_cuerpo;
      v_pie := paw_pro.fu_not_fin_tab_cuerpo || paw_pro.fu_not_fin_tabla;

      v_detalle := paw_pro.fu_not_row_tag('Fecha ', to_char(sysdate, 'dd/mm/yyyy'));
      v_detalle := v_detalle || paw_pro.fu_not_row_tag('Hora ', to_char(sysdate, 'hh24:mi:ss'));
      v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nº de Cuenta ',TRUE,'UTF-8'), p_nro_cuenta);
      v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nº de Celular ', TRUE, 'UTF-8'), p_nro_celular);
      v_pie := v_pie || paw_pro.fu_not_fin;
      v_number := fu_env_email_prueba(v_dir_correo, v_cabecera || v_detalle || v_pie, 'paw_not');
      RETURN v_number;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN -99;
   END;

FUNCTION lf_ver_des_suscripto(p_cod_persona IN ba_personas.cod_persona%TYPE)
  RETURN VARCHAR2 IS
  v_nom_destino bw_not_destinos.nombre%TYPE;
BEGIN
  BEGIN
    SELECT d.nombre
      INTO v_nom_destino
      FROM bw_not_cli_destino c, bw_not_destinos d
     WHERE c.cod_persona = p_cod_persona
       AND c.activo = 'S'
       AND d.cod_destino = c.cod_destino;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  RETURN v_nom_destino;
END;
PROCEDURE pr_not_sms_ips IS
  --Cursor de la tabla temporal del proceso de importacion BW_NOT_IPS_SMS
  CURSOR not_masivas IS
    SELECT a.cod_persona, a.mensaje, a.destino, a.tel_celular
    FROM BW_NOT_SMS_MAS_TMP a;
  v_lim_mensajes NUMBER(5);
  v_con_mensajes NUMBER(5) := 0;
  v_aux_insertar NUMBER(3);
  v_fec_envio    DATE;
  v_tot_mensajes NUMBER := 0;
  v_sig_lote     NUMBER;
  v_sec_mensaje  NUMBER;
  v_encolado     VARCHAR(1);
  v_ret          NUMBER := 0;
  v_mensaje      varchar2(300);
  v_cod_destino  bw_not_destinos.cod_destino%type := 1;
  v_celular      varchar2(100);
  v_error        varchar2(100);
  v_fec_actual   date:= pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_cod_persona  varchar2(20);
  v_horario      varchar2(100);
  v_nom_ofi_res  varchar2(100);
  v_nom_dir_res  varchar2(100);
  v_existe       varchar2(10);
  --Usamos la cuenta de seguros que tiene la misma funcionalidad para no crear otro
  v_nro_cuenta  varchar2(30):=fug_obt_pardinamico('NRO_CTA_VEN_SEGURO');
  FUNCTION lf_obt_nro_lote RETURN NUMBER IS
    v_aux_lote NUMBER;
  BEGIN
    SELECT nvl(MAX(lote), 0)
    INTO v_aux_lote
    FROM BW_NOT_SMS_MASIVO;
    RETURN v_aux_lote + 1;
  END;
  FUNCTION lf_ver_sms_suscripto(p_cod_persona IN ba_personas.cod_persona%TYPE)
  RETURN VARCHAR2 IS
  v_nom_destino bw_not_destinos.nombre%TYPE;
BEGIN
  BEGIN
    SELECT d.nombre
      INTO v_nom_destino
      FROM bw_not_cli_destino c, bw_not_destinos d
     WHERE c.cod_persona = p_cod_persona
       AND c.activo = 'S'
       AND d.cod_destino = c.cod_destino
       and d.cod_destino = 1;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  RETURN v_nom_destino;
END;
BEGIN
  v_fec_envio    := trunc(SYSDATE) + 14 / 24;
  v_lim_mensajes := to_number(nvl(fug_obt_pardinamico('BW_NOT_MEN_MASIVO_LIM'),
                                  1000));
  v_sig_lote     := lf_obt_nro_lote;
  FOR destino IN not_masivas LOOP
    v_encolado := 'N';
    v_error:= null;
    --Sino tiene celular Buscamos en ba_telefonos
    v_celular:= null;
    v_cod_persona:= null;
    v_nom_ofi_res:= null;
    v_horario:= null;
    v_existe:= null;
    v_nom_dir_res:=null;
  --Verificamos que exista la persona  
  begin 
    select a.cod_persona
      into v_cod_persona
       from ba_personas a 
         where a.cod_persona=destino.cod_persona
          and rownum=1;
  exception
    when no_data_found then
      v_cod_persona:=null;
    when others then
     v_cod_persona:=null;
  end;  
 if v_cod_persona is not null then 
              --  
             --Verificamos si ya existe en bw_not_suscripciones
             --Sino existe insertamos, si ya existe el cliente pudo haber marcado que no queria recibir
             --Por lo que se validará posteriormente
             begin
               select 'S'
                 into v_existe
                  from bw_not_suscripciones a
                    where a.cod_persona=v_cod_persona
                      and a.nro_cuenta= nvl(v_nro_cuenta,a.nro_cuenta)
                        and a.cod_evento= 69
                        and rownum=1;
             exception
               when no_data_found then
                 v_existe:= 'N';
               when others then
                v_existe:= 'S';
             end;
           IF NVL(v_existe,'S')= 'N' then
               BEGIN
                 INSERT INTO bw_not_suscripciones
                    (cod_persona, nro_cuenta, cod_evento, horario, mto_minimo, activo, frecuencia)
                 VALUES
                    (v_cod_persona, v_nro_cuenta, 69, null, null, 'S', NULL);
               EXCEPTION
                 WHEN OTHERS THEN
                    null;
               END;
            end if;
      --******************
  if  destino.tel_celular is null then
    --Buscamos el celular del cliente, que no tenga observacion
   begin
       select a.area||a.telefono
         into v_celular
         from ba_telefonos a
           where a.cod_persona= destino.cod_persona
           and a.tip_linea='C'
           and a.observacion is null
           and rownum=1;
    exception
      when no_data_found then
         v_error:='No se tiene registrado el Nro. de Celular del Cliente';
         v_celular:=  null;
      when others then
         v_error:=null;
         v_celular:=  null;
    end;
  else
     v_celular:=  destino.tel_celular; 
  end if;  
    --Doy de alta al cliente en el servicio de notificaciones SMS
    IF v_celular IS NOT NULL THEN
      v_ret := fu_alt_cliente(destino.cod_persona,
                              v_cod_destino,
                              v_celular,
                              'SMS');
      if v_ret = 1 then
         BEGIN
           INSERT INTO bw_not_cli_destino
              (cod_persona, cod_destino, direccion, activo, cod_origen)
           VALUES
              (destino.cod_persona, v_cod_destino, v_celular, 'S', 'SMS');
          EXCEPTION
             WHEN OTHERS THEN
                v_ret := 2;
          END;
      end if;
    END IF;
    --Si no esta en el blacklist
    --PCCDEEVO-746 No se validara el black list
    --IF (paw_not.fu_obt_con_blacklist(destino.cod_persona, 'SMSMAS') = 'N' ) THEN  --AND (lf_ver_sms_suscripto(destino.cod_persona) = 'SMS') THEN
    --Obtenemos el Horario si tenemos parametrizado
    IF v_celular IS NOT NULL THEN
      IF upper(trim(destino.destino)) <> 'CAC CENTRO-INTERIOR' THEN
          BEGIN
            select 'Horario:'||a.abreviatura||'-'||a.val_maximo
              into v_horario
              from ba_cod_referencias a
                where a.dominio='HOR_ATE_OFICINAS'
                and upper(trim(a.significado))=upper(trim(destino.destino));
          EXCEPTION
            when no_data_found then 
               v_horario:= Null;
            when others then
               v_horario:= Null;
          END;
      ELSE
        -- NO TIENE HORARIO
         BEGIN
            select a.abreviatura||' '||a.val_maximo
              into v_horario
              from ba_cod_referencias a
                where a.dominio='HOR_ATE_OFICINAS'
                and upper(trim(a.significado))=upper(trim(destino.destino));
          EXCEPTION
            when no_data_found then 
               v_horario:= Null;
            when others then
               v_horario:= Null;
          END;


      END IF;
      --Obtenemos nombre de oficina resumido si tiene parametrizado
       BEGIN
        select trim(a.abreviatura)||','
          into v_nom_ofi_res
          from ba_cod_referencias a
            where a.dominio='NOM_RES_OFICINAS'
            and upper(trim(a.significado))=upper(trim(destino.destino));
      EXCEPTION
        when no_data_found then 
           v_nom_ofi_res:= destino.destino;
        when others then
           v_nom_ofi_res:= destino.destino;
      END;
       --Obtenemos direccion de oficina resumido
       BEGIN
        select trim(a.Val_Maximo)||','
          into v_nom_dir_res
          from ba_cod_referencias a
            where a.dominio='NOM_RES_DIRECCION'
            and upper(trim(a.significado))=upper(trim(destino.destino));
      EXCEPTION
        when no_data_found then 
           v_nom_dir_res:= NULL;
        when others then
           v_nom_dir_res:= NULL;
      END;




      --Cortamos si pasa 140 caracteres
      v_mensaje := substr(trim(destino.mensaje||v_nom_ofi_res||v_nom_dir_res||v_horario),1,140);
      v_aux_insertar := fu_ins_mensaje(69,
                                       'SMSMAS',
                                       v_mensaje,
                                       destino.cod_persona,
                                       '0',
                                       v_fec_envio,
                                       'S');
      v_con_mensajes := v_con_mensajes + 1;
      v_tot_mensajes := v_tot_mensajes + 1;
      v_encolado     := 'S';
      IF (v_con_mensajes >= v_lim_mensajes) THEN
        v_con_mensajes := 0;
        v_fec_envio    := v_fec_envio + 1;
      END IF;
    else
       v_error:='Cliente no tiene Nro de Celular';
    END IF;
    v_sec_mensaje := S_BW_NOT_IPS_SMS.NEXTVAL;
  else
    v_error:='No se encuentra registrada la persona con código= '|| destino.cod_persona; 
  end if;
    BEGIN
      --inserto en la tabla al finalizar el envío del SMS
      INSERT INTO BW_NOT_SMS_MASIVO
        (COD_MENSAJE, cod_persona, mensaje, lote, encolado, error, fecha,nro_celular)
      VALUES
        (v_sec_mensaje, destino.cod_persona, nvl(v_mensaje,destino.mensaje), v_sig_lote,
         v_encolado, v_error,v_fec_actual,v_celular );
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;
END;

PROCEDURE pr_not_req_masivo IS
  CURSOR not_masivas IS
    SELECT cod_persona, mensaje
    FROM bw_not_req_masivo_tmp;
  v_lim_mensajes NUMBER(5);
  v_con_mensajes NUMBER(5) := 0;
  v_aux_insertar NUMBER(3);
  v_fec_envio    DATE;
  v_tot_mensajes NUMBER := 0;
  v_sig_lote     NUMBER;
  v_sec_mensaje  NUMBER;
  v_encolado     VARCHAR(1);
  FUNCTION lf_obt_nro_lote RETURN NUMBER IS
    v_aux_lote NUMBER;
  BEGIN
    SELECT nvl(MAX(lote), 0)
    INTO v_aux_lote
    FROM bw_not_req_masivo;
    RETURN v_aux_lote + 1;
  END;
BEGIN
  v_fec_envio    := trunc(SYSDATE) + 14 / 24;
  v_lim_mensajes := to_number(nvl(fug_obt_pardinamico('BW_NOT_MEN_MASIVO_LIM'),
                                  1000));
  v_sig_lote     := lf_obt_nro_lote;
  FOR destino IN not_masivas LOOP
    v_encolado := 'N';
    IF paw_not.fu_obt_con_blacklist(destino.cod_persona, 'PROMOPUSH') = 'N' THEN
      v_aux_insertar := fu_ins_mensaje(64,
                                       'MASIVOR',
                                       destino.mensaje,
                                       destino.cod_persona,
                                       '0',
                                       v_fec_envio,
                                       'S');
      v_con_mensajes := v_con_mensajes + 1;
      v_tot_mensajes := v_tot_mensajes + 1;
      v_encolado     := 'S';
      IF (v_con_mensajes >= v_lim_mensajes) THEN
        v_con_mensajes := 0;
        v_fec_envio    := v_fec_envio + 1;
      END IF;
    END IF;
    v_sec_mensaje := s_bw_not_masivos.NEXTVAL;
    BEGIN
      INSERT INTO bw_not_req_masivo
        (COD_MENSAJE, cod_persona, mensaje, lote, encolado)
      VALUES
        (v_sec_mensaje, destino.cod_persona, destino.mensaje, v_sig_lote,
         v_encolado);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;
END;
 /*
    Notificacion via mail de Transferencias BBVA, enviadas y recibidas, a Personas y/o Empresas.
   */  
 FUNCTION fu_not_mail_transferencias(p_nro_cta_debito IN ge_cuentas.nro_cuenta%TYPE,    
                                     p_nro_cta_credito IN ge_cuentas.nro_cuenta%TYPE,
                                     p_cod_mon_debito IN ba_monedas.cod_moneda%TYPE, 
                                     p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE,
                                     p_tip_mensaje in bw_tip_mensajes.cod_tip_mensaje%type,  
                                     p_mto_debito  in ge_movimientos.monto%TYPE,
                                     p_mto_credito  in ge_movimientos.monto%TYPE,
                                     p_fecha IN DATE) RETURN NUMBER is
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_number        NUMBER;
    v_membrete LONG := fug_gen_template('M');
    V_FIN      LONG := fug_gen_template('F');
    V_PIE      LONG := fug_gen_template('P'); 
    v_dir_mail varchar2(1000):= NULL;
    v_texto    varchar2(5000);
    v_mje_mail LONG;
    v_msj_titulo       varchar2(80)  := NULL;
    v_asunto           varchar2(80)  := NULL;
    v_texto_detalle    varchar2(32000) := null;
    v_mto_debito       varchar2(100) := null;    
    v_mto_credito      varchar2(100) := null;
    v_cod_per_debito   ba_personas.cod_persona%Type := null;
    v_cod_per_credito  ba_personas.cod_persona%type := null; 
    v_result           number := 0;  
    v_conn           utl_smtp.connection;                               
   BEGIN
      -- cuando el tipo es credito, y en caso de que sea una empresa (persona juridica) 
      -- notificamos a la empresa de la transferencia recibida
      v_cod_per_debito  := fug_obt_cli_principal(p_nro_cta_debito);
      v_cod_per_credito := fug_obt_cli_principal(p_nro_cta_credito);

      --Cambio en la sesion actual el NLS_NUMERIC_CHARACTERS
     -- pre_cam_for_numerico(',.'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
      --
      -----------------------------------------------------------------------------------------------
      ---------------------------- NOTIFICACION POR EL DEBITO --------------------------------------
      -----------------------------------------------------------------------------------------------
      if p_cod_mon_debito = pag_gen.FU_OBT_MON_LOCAL  then
         --v_mto_debito := to_char(p_mto_debito, '999G999G999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''');
         v_mto_debito := lf_obt_mto_formateado(p_mto_debito,600);
      else
         -- v_mto_debito := to_char(p_mto_debito, '999G999G999G999G999D99', 'NLS_NUMERIC_CHARACTERS = '',.''');
         v_mto_debito := lf_obt_mto_formateado(p_mto_debito,1);
      end if;
      --
      -- Busca la direccion de Correo del Cliente que originó la operación.
      -- la funcion FUG_OBT_DIR_MAIL_PER obtiene de ba_personas.dir_correo, en caso que no se tenga 
      -- configurado en ba_personas, busca en ba_mails. 
      BEGIN
         v_dir_mail := FUG_OBT_DIR_MAIL_PER(v_cod_per_debito);
      EXCEPTION
          when others then
             v_dir_mail     := null ;
      END;
       -- asunto del mail
        v_asunto := 'Aviso de Transferencia Emitida';  
        if p_tip_mensaje = '039' then -- si es transferencia de tercero
          v_msj_titulo := 'TRANSFERENCIA A TERCERO';
        else -- entre cuentas propias
          v_msj_titulo := 'TRANSFERENCIA ENTRE CUENTAS PROPIAS';  
        end if;  
         if v_dir_mail is not null then
             -- armamos el mensaje
             v_texto := '<h2 style="color:#074CA9; font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; margin-top:0px">'||v_msj_titulo||'</h2>
                         <p style="font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; font-size:14px">Estimado Cliente, registramos la siguiente '|| pag_htm.FU_CON_HTML('operacion') ||' de Transferencia.</p>
                         <table width="500"; style="font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; font-size:14px;">
                         <tbody >
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>'|| 'Nro. Cuenta Remitente:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||p_nro_cta_debito||'</td>
                         </tr>
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nombre Remitente:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||fue_obt_nom_persona(v_cod_per_debito) ||'</td>
                         </tr>
                         <tr>
                          <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>'||'Nro. Cuenta Beneficiario:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||p_nro_cta_credito||'</td>
                         </tr>
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nombre Beneficiario:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||fue_obt_nom_persona(v_cod_per_credito) ||'</td>
                         </tr>
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Importe:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||p_cod_mon_debito||' '||v_mto_debito||'</td>
                         </tr>
                         <tr>
                         <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Fecha '|| pag_htm.FU_CON_HTML('Operacion') ||':</b></td>
                         <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||to_char(p_fecha,'DD/MM/YYYY')||'</td>
                         </tr>
                         </tbody>
                         </table>
                         <br><br>
                         <p align="center"><i><b>'||utl_url.escape(fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA'), true, 'UTF-8')||'</b></i>
                         </p>';
                   v_texto := '<div style="padding:20px 20px">'||v_texto||'</div>';


                   -- concateno membrete, cuerpo del mail y pie
                   v_mje_mail := v_membrete||v_texto||v_fin||v_pie;
                   --
                   -- si el entorno de ejecucion para el envio de correo es produccion
                   IF fug_ind_produccion = 'S' THEN
                     --- SERVICE INTEGRATOR
                       BEGIN       
                        v_number := paw_not.fu_env_email_prueba(v_dir_mail, v_texto, 'TransferSend');
                       EXCEPTION
                           when others then
                             v_result := -90;
                             insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                              values (fug_obt_dir_correo, v_dir_mail, 'PAW_NOT'||'-'||v_msj_titulo, 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cta_debito ||' - '||substr(v_texto,1,3900), sysdate, user)  ;
                             commit;
                       END;   
                   else -- si no corresponde al entorno de ejecucion de produccion.
                     v_result := -91;
                     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                      values (fug_obt_dir_correo, v_dir_mail, 'PAW_NOT'||'-'||v_msj_titulo, 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cta_debito ||' - Entorno de ejecucion invalido.', sysdate, user)  ;
                      commit;
                   END IF;
         else  -- si no se encontro correo 
           v_result := -92;
           insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
            values (fug_obt_dir_correo, v_dir_mail, 'PAW_NOT'||'-'||v_msj_titulo, 'Cliente: '||v_cod_per_debito||' Cuenta Déb.: '||p_nro_cta_debito ||' - No se encontro un correo configurado segun los criterios definidos.', sysdate, user)  ;
            commit;
         end if;
      -----------------------------------------------------------------------------------------------
      ---------------------------- NOTIFICACION POR EL CREDITO --------------------------------------
      -----------------------------------------------------------------------------------------------
      if p_cod_mon_credito= pag_gen.FU_OBT_MON_LOCAL  then
         -- v_mto_credito := to_char( p_mto_credito, '999G999G999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''');
         v_mto_credito := lf_obt_mto_formateado(p_mto_credito,600);
      else
         -- v_mto_credito := to_char( p_mto_credito, '999G999G999G999G999D99', 'NLS_NUMERIC_CHARACTERS = '',.''');
         v_mto_credito := lf_obt_mto_formateado(p_mto_credito,1);
      end if;
       --
       -- Busca la direccion de Correo del Cliente que originó la operación.
       -- la funcion FUG_OBT_DIR_MAIL_PER obtiene de ba_personas.dir_correo, en caso que no se tenga 
       -- configurado en ba_personas, busca en ba_mails. 
       BEGIN
          v_dir_mail := FUG_OBT_DIR_MAIL_PER(v_cod_per_credito);
       EXCEPTION
          when others then
             v_dir_mail     := null ;
       END; 
       --
        -- asunto del mail
        v_asunto := 'Aviso de Transferencia Recibida';  
        if p_tip_mensaje = '039' then -- si es transferencia de tercero
          v_msj_titulo := 'TRANSFERENCIA DE TERCERO';
        else -- entre cuentas propias
          v_msj_titulo := 'TRANSFERENCIA ENTRE CUENTAS PROPIAS';  
        end if;  
         if v_dir_mail is not null then
             -- armamos el mensaje
             v_texto := '<h2 style="color:#074CA9; font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; margin-top:0px">'||v_msj_titulo||'</h2>
                         <p style="font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; font-size:14px">Estimado Cliente, registramos la siguiente '|| pag_htm.FU_CON_HTML('operacion') ||' de Transferencia.</p>
                         <table width="500"; style="font-family: '||chr(39)||'Helvetica Neue'||chr(39)||', Helvetica, Arial, sans-serif; font-size:14px;">
                         <tbody >
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>'|| 'Nro. Cuenta Remitente:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||p_nro_cta_debito||'</td>
                         </tr>
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nombre Remitente:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||fue_obt_nom_persona(v_cod_per_debito) ||'</td>
                         </tr>
                         <tr>
                          <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b> Nro. Cuenta Beneficiario:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||p_nro_cta_credito||'</td>
                         </tr>
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Nombre Beneficiario:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||fue_obt_nom_persona(v_cod_per_credito) ||'</td>
                         </tr>
                         <tr>
                           <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Importe:</b></td>
                           <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||p_cod_mon_credito||' '||v_mto_credito||'</td>
                         </tr>
                         <tr>
                         <td width="150"; style="border-bottom:thin #AFD48B solid; padding:6px 0px;"><b>Fecha '|| pag_htm.FU_CON_HTML('Operacion') ||':</b></td>
                         <td style="border-bottom:thin #AFD48B solid; padding:6px 0px;">'||to_char(p_fecha,'DD/MM/YYYY')||'</td>
                         </tr>
                         </tbody>
                         </table>
                         <br><br>
                         <p align="center"><i><b>'||utl_url.escape(fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA'), true, 'UTF-8')||'</b></i>
                         </p>';
                   v_texto := '<div style="padding:20px 20px">'||v_texto||'</div>';
                   -- concateno membrete, cuerpo del mail y pie
                   v_mje_mail := v_membrete||v_texto||v_fin||v_pie;
                   -- si el entorno de ejecucion para el envio de correo es produccion
                   IF fug_ind_produccion = 'S' THEN
                        --- SERVICE INTEGRATOR
                       BEGIN        
                          v_number := paw_not.fu_env_email_prueba(v_dir_mail, v_texto, 'TransferReceived');
                       EXCEPTION
                           when others then
                             v_result := -93;
                             insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                              values (fug_obt_dir_correo, v_dir_mail, 'PAW_NOT'||'-'||v_msj_titulo, 'Cliente: '||v_cod_per_credito||' Cuenta Cré.: '||p_nro_cta_credito ||' - '||substr(v_texto,1,3900), sysdate, user)  ;
                             commit;
                       END;       
                   else -- si no corresponde al entorno de ejecucion de produccion.
                     v_result := -94;
                     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                      values (fug_obt_dir_correo, v_dir_mail, 'PAW_NOT'||'-'||v_msj_titulo, 'Cliente: '||v_cod_per_credito||' Cuenta Cré.: '||p_nro_cta_credito ||' - Entorno de ejecucion invalido.', sysdate, user)  ;
                      commit;
                   END IF;
         else  -- si no se encontro correo 
           v_result := -95;
           insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
            values (fug_obt_dir_correo, v_dir_mail, 'PAW_NOT'||'-'||v_msj_titulo, 'Cliente: '||v_cod_per_credito||' Cuenta Cré.: '||p_nro_cta_credito ||' - No se encontro un correo configurado segun los criterios definidos.', sysdate, user)  ;
            commit;
         end if;
     --
     return v_result;
     --
    EXCEPTION
       WHEN OTHERS THEN
           v_texto := substr(sqlerrm, 1,3800);
           insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
           values (fug_obt_dir_correo, v_dir_mail, 'PAW_NOT'||'-'||v_msj_titulo,  'Cliente Deb.:'||v_cod_per_debito||'Cliente Cre.:'||v_cod_per_credito||'-'||v_texto, sysdate, user)  ;
            commit;
          RETURN -99;
   END;   -- fu_not_mail_transferencias        

/** Funcion para notificar a los usuarios el rechazo de cobro, vencimiento poliza de Seguro
   */
   FUNCTION fu_not_seguros(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
     p_cod_modulo     IN bw_not_eventos.cod_modulo%TYPE DEFAULT NULL,
     p_cod_modalidad  IN bw_not_eventos.cod_modalidad%TYPE DEFAULT NULL,
     p_cod_persona in ba_personas.cod_persona%type DEFAULT NULL,
     p_ente ge_entes.descripcion%TYPE DEFAULT NULL,
     p_cod_tip_evento bw_not_eventos.cod_tip_evento%TYPE,
     p_fecha in date DEFAULT NULL)
   RETURN NUMBER IS
    v_cod_evento  bw_not_eventos.cod_evento%TYPE;
    v_horario     bw_not_eventos.horario%TYPE;
    v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio  bw_not_eventos.mandatorio%TYPE;
    v_template    bw_not_tip_eventos.template%TYPE;
    v_mensaje     bw_not_mensajes.mensaje%TYPE;
    v_ret         NUMBER(3) := 0;
    v_tipo        VARCHAR(2):='00';
    v_rechazo     varchar(2):='S';
    v_existe      varchar2(1):='N';

 begin
     IF fu_obt_not_template(p_cod_tip_evento, v_template, v_tipo) <> 0 THEN
       RETURN 20;
    END IF;
       --Buscamos si tiene el evento parametrizado.
        begin
          select a.cod_evento
           into v_cod_evento
            from bw_not_eventos a
              where a.cod_tip_evento= p_cod_tip_evento
               and a.cod_modulo=p_cod_modulo
               and a.cod_modalidad=p_cod_modalidad
               and rownum=1;
        exception
          when no_data_found then
            v_cod_evento:= null;
          when others then
            v_cod_evento:= null;
        end;
        -- Sino existe, insertamos, no actualiamos ya que despues se puede parametrizar
        if v_cod_evento is not null then
             v_existe:='N';
             --Verificamos si ya existe en bw_not_suscripciones
             --Sino existe insertamos, si ya existe el cliente pudo haber marcado que no queria recibir
             --Por lo que se validará posteriormente
             begin
               select 'S'
                 into v_existe
                  from bw_not_suscripciones a
                    where a.cod_persona=p_cod_persona
                      and a.nro_cuenta= nvl(p_nro_cuenta,a.nro_cuenta)
                        and a.cod_evento= cod_evento
                        and rownum=1;
             exception
               when no_data_found then
                 v_existe:= 'N';
               when others then
                v_existe:= 'S';
             end;
           IF NVL(v_existe,'S')= 'N' then
               BEGIN
                 INSERT INTO bw_not_suscripciones
                    (cod_persona, nro_cuenta, cod_evento, horario, mto_minimo, activo, frecuencia)
                 VALUES
                    (p_cod_persona, p_nro_cuenta, v_cod_evento, null, null, 'S', NULL);
               EXCEPTION
                 WHEN OTHERS THEN
                    RETURN -1;
               END;
            end if;
        else
           --Sino esta configurado el evento salimos
           RETURN -1;
        end if;
          v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, p_cod_tip_evento, v_cod_evento, v_horario, null,null, v_ocurrencia, v_mandatorio,v_rechazo);
          IF v_ret = 0 THEN
             --esta suscripto
            if p_cod_tip_evento ='SEGNOTREC' then
               --Para Rechazo
               --BBVA le informa: Que el cobro de cuota de %s  ,no fue debitado favor verifique a fin de evitar inconveniente.
              BEGIN
               v_mensaje := utl_lms.format_message(v_template,
                                                p_ente);
               --Verificamos si pasa los 140 caracteres, para evitar inconvenientes, recortamos de ser asi
               if nvl(length(v_mensaje),0)> 140 then
                 v_mensaje:= substr(v_mensaje,1,139)||'.';
               end if;
               v_ret     := fu_ins_mensaje(v_cod_evento, p_cod_tip_evento, v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
              EXCEPTION
                  WHEN OTHERS THEN
                     RETURN -1;
               END;
            elsif p_cod_tip_evento ='SEGNOTVTO' then
                --Para Vencimiento
                --BBVA le informa: El Vto.de su póliza %s con %s  ,nos comunicaremos con ud.para la renovacion.
              BEGIN
               v_mensaje := utl_lms.format_message(v_template,
                                                p_ente,
                                                substr(lf_obt_fec_tra_formateado(p_fecha), 0, 5));
                v_ret     := fu_ins_mensaje(v_cod_evento, p_cod_tip_evento, v_mensaje, p_cod_persona, p_nro_cuenta, NULL, 'S');
               EXCEPTION
                  WHEN OTHERS THEN
                     RETURN -1;
               END;
            end if;
          END IF;
    RETURN v_ret;
   end;
  PROCEDURE pr_not_ret_pro_suc IS
     -- Cursor de notificaciones
     CURSOR not_masivas IS
        SELECT nro_producto, nro_cedula, nro_cuenta, producto, 
               categoria, sucursal, fec_retiro
          FROM bw_not_ret_pro_suc_tmp;
     -- Variables     
     v_lim_mensajes NUMBER(5);
     v_con_mensajes NUMBER(5) := 0;
     v_aux_insertar NUMBER(3);
     v_fec_envio    DATE;
     v_tot_mensajes NUMBER := 0;
     v_lote         NUMBER;
     v_cod_mensaje  NUMBER;
     v_encolado     VARCHAR(1);
     v_tipo         VARCHAR(2) := '00';
     v_categoria    VARCHAR(20);
     v_nro_prod     VARCHAR(5);
     v_sucursal     VARCHAR(20);
     v_fec_txt      VARCHAR(10);
     v_nro_cuenta   ge_cuentas.nro_cuenta%TYPE;
     v_cod_persona  ba_personas.cod_persona%TYPE;
     v_template     bw_not_tip_eventos.template%TYPE;
     v_mensaje      bw_not_mensajes.mensaje%TYPE;
     v_direccion    bw_not_cli_destino.direccion%type;
     rv_bwnot       bw_not_ret_pro_suc%ROWTYPE;
     -- Constantes
     C_TIP_EVENTO bw_not_tip_eventos.cod_tip_evento%TYPE := 'RETPRODSUC';
     C_COD_EVENTO bw_not_eventos.cod_evento%TYPE := 70;
     -- Funcion para obtener el siguiente Numero de lote
     FUNCTION lf_obt_nro_lote RETURN NUMBER IS
        v_aux_lote NUMBER;
     BEGIN
        SELECT nvl(MAX(lote), 0)
          INTO v_aux_lote
          FROM bw_not_ret_pro_suc;
        RETURN v_aux_lote + 1;
     EXCEPTION
        WHEN OTHERS THEN
           RETURN 1;
     END;
     -- Insertar en la tabla BW_NOT_RET_PRO_SUC
     PROCEDURE lp_ins_not_ret_pro_suc(rp_bwnot bw_not_ret_pro_suc%ROWTYPE) IS
     BEGIN
        INSERT INTO bw_not_ret_pro_suc
           (cod_mensaje, nro_producto, nro_cedula, nro_cuenta, producto, categoria, sucursal, fec_retiro, lote, encolado)
        VALUES
           (rp_bwnot.cod_mensaje, rp_bwnot.nro_producto, rp_bwnot.nro_cedula, rp_bwnot.nro_cuenta, rp_bwnot.producto, rp_bwnot.categoria,
            rp_bwnot.sucursal, rp_bwnot.fec_retiro, rp_bwnot.lote, rp_bwnot.encolado);
     END;
     --
  BEGIN
     v_fec_envio    := trunc(SYSDATE) + 14 / 24; -- A partir de las 14:00hs
     v_lim_mensajes := to_number(nvl(fug_obt_pardinamico('BW_NOT_MEN_MASIVO_LIM'), 1000)); -- Limite de mensajes masivos
     v_lote         := lf_obt_nro_lote; -- Numero de lote
     -- Template para el tipo de evento
     IF paw_not.fu_obt_not_template(C_TIP_EVENTO, v_template, v_tipo) <> 0 THEN
        Raise_application_error(-20000, 'Error al obtener el template de la notificacion para el tipo de evento ' || C_TIP_EVENTO);
     END IF;
     FOR destino IN not_masivas
     LOOP
        v_aux_insertar := 0;
        v_encolado     := 'N';
        v_nro_cuenta   := TRIM(destino.nro_cuenta);
        v_cod_persona  := fug_obt_cli_principal(v_nro_cuenta);
        IF v_cod_persona IS NULL THEN
           BEGIN
             SELECT cod_persona 
               INTO v_cod_persona
               FROM ba_personas
              WHERE cod_persona = v_nro_cuenta;
              v_nro_cuenta := 0;
           EXCEPTION
             WHEN OTHERS THEN
               v_aux_insertar := -1;
           END;
           IF v_aux_insertar < 0 THEN
              -- Buscar por número de cédula
              v_cod_persona := fue_obt_cod_persona(destino.nro_cedula);
              IF v_cod_persona IS NOT NULL THEN
                v_aux_insertar := 0;
              END IF;
           END IF;
        END IF;
        IF v_aux_insertar >= 0 THEN
           -- Destino Activo --
           v_direccion := substr(paw_not.fu_obt_cli_des_activo(v_cod_persona), 1, 200); 
           -- si no tiene servicio de notificacion, se le adhiere de forma compulsiva
           IF paw_not.fu_obt_suscripcion(v_cod_persona) = 'N' OR v_direccion IS NULL THEN
              v_aux_insertar := paw_not.fu_alt_notificacion(v_cod_persona, v_direccion);        
           END IF; 
           IF v_aux_insertar >= 0 THEN
             IF paw_not.fu_obt_con_blacklist(v_cod_persona, C_TIP_EVENTO) = 'N' THEN
                -- Mensaje
                v_categoria := substr(TRIM(destino.categoria), 1, 20);
                v_nro_prod  := substr(PAW_NOT.lf_obt_ult_tarjeta(TRIM(destino.nro_producto)), 1, 5);
                v_sucursal  := substr(TRIM(destino.sucursal), 1, 20);
                v_fec_txt   := substr(to_char(destino.fec_retiro, 'DD/MM/YYYY'), 1, 10);
                --BBVA le informa: Su %s %s esta disponible en la Sucursal %s para su retiro, hasta el %s
                BEGIN
                   v_mensaje      := utl_lms.format_message(v_template, v_categoria, v_nro_prod, v_sucursal, v_fec_txt);
                   v_aux_insertar := paw_not.fu_ins_mensaje(C_COD_EVENTO, C_TIP_EVENTO, v_mensaje, v_cod_persona, v_nro_cuenta, v_fec_envio, 'S');
                EXCEPTION
                   WHEN OTHERS THEN
                      --Raise_application_error(-20000, 'Error al construir el mensaje de la notificacion para Nro. de Cuenta = ' || v_nro_cuenta);
                      v_aux_insertar := -1;
                END;
                IF v_aux_insertar >= 0 THEN
                   v_con_mensajes := v_con_mensajes + 1;
                   v_tot_mensajes := v_tot_mensajes + 1;
                   v_encolado     := 'S';
                   IF (v_con_mensajes >= v_lim_mensajes) THEN
                      v_con_mensajes := 0;
                      v_fec_envio    := v_fec_envio + 1;
                   END IF;
                END IF;
             END IF;
           END IF;
        END IF;
        -- Insertar en la tabla BW_NOT_RET_PRO_SUC
        v_cod_mensaje         := s_bw_not_ret_pro_suc.NEXTVAL;
        rv_bwnot.cod_mensaje  := v_cod_mensaje;
        rv_bwnot.nro_producto := destino.nro_producto;
        rv_bwnot.nro_cedula   := destino.nro_cedula;
        rv_bwnot.nro_cuenta   := destino.nro_cuenta;
        rv_bwnot.producto     := destino.producto;
        rv_bwnot.categoria    := destino.categoria;
        rv_bwnot.sucursal     := destino.sucursal;
        rv_bwnot.fec_retiro   := destino.fec_retiro;
        rv_bwnot.lote         := v_lote;
        rv_bwnot.encolado     := v_encolado;
        lp_ins_not_ret_pro_suc(rv_bwnot);
     END LOOP;
  END;
  --
  FUNCTION fu_obt_horario(p_hor_inicio IN NUMBER,
                          p_hor_fin    IN NUMBER) RETURN DATE IS
     v_hor_actual     VARCHAR2(10);
     v_min_actual     VARCHAR2(10);    
     v_min_agregado   NUMBER := round((1/1440)*0.75,3);
     v_fec_programada DATE := SYSDATE; 
  BEGIN
     SELECT to_number(to_char(v_fec_programada,'hh24')), to_char(v_fec_programada, 'mi:ss')
       INTO v_hor_actual, v_min_actual
       FROM dual;

     -- se programa la hora de envio si no es en horario de oficina
    IF v_hor_actual > p_hor_fin THEN -- se pasa para el dia siguiente
       v_fec_programada := to_date(to_char(v_fec_programada+1, 'dd/mm/yyyy')||' 08:'||v_min_actual, 'dd/mm/yyyy hh24:mi:ss') + v_min_agregado;
    ELSIF v_hor_actual < p_hor_inicio THEN -- se programa la hora inicial
       v_fec_programada := to_date(to_char(v_fec_programada, 'dd/mm/yyyy')||' 08:'||v_min_actual, 'dd/mm/yyyy hh24:mi:ss') + v_min_agregado;
    END IF; -- se mantiene la fecha y hora actual

    RETURN v_fec_programada;
  END;
  --
  PROCEDURE fu_not_cob_ahorro(p_cod_persona    IN ba_personas.cod_persona%TYPE,
                              p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE, 
                              p_moneda         IN ba_monedas.cod_moneda%TYPE,
                              p_monto          IN ah_pro_cuotas.mto_cuota%TYPE, 
                              p_nro_cuota      IN ah_pro_cuotas.nro_cuota%TYPE,
                              p_cod_error      IN VARCHAR2) IS
     v_cod_evento     bw_not_eventos.cod_evento%TYPE;
     v_horario        bw_not_eventos.horario%TYPE;
     v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
     v_mandatorio     bw_not_eventos.mandatorio%TYPE;
     v_template       bw_not_tip_eventos.template%TYPE;
     v_mensaje        bw_not_mensajes.mensaje%TYPE;
     v_ret            NUMBER(3);
     v_moneda         NUMBER(3);
     v_fec_programada DATE;
     v_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE := 'AHPCUOTA';
  BEGIN
    v_ret := fu_obt_eve_suscripcion(p_cod_persona, p_nro_cuenta, v_cod_tip_evento, v_cod_evento, v_horario, p_monto, v_moneda, v_ocurrencia, v_mandatorio);
    SELECT decode(p_moneda, 'GS', 600, 100)
      INTO v_moneda
      FROM dual;

    IF v_ret = 0 THEN -- esta suscripto
      v_fec_programada := fu_obt_horario(8, 19);
      IF fu_obt_not_template(v_cod_tip_evento, v_template, p_cod_error) = 0 THEN
         IF p_cod_error = '00' THEN
            -- BBVA le informa: en fecha %s se ha procesado el débito de %s %s correspondiente la cuota %s pactada en su ahorro programado %s.
            v_mensaje := substr(utl_lms.format_message(v_template, substr(lf_obt_fec_tra_formateado(SYSDATE), 0, 5), lf_obt_mto_formateado(p_monto, v_moneda), p_moneda, to_char(p_nro_cuota), p_nro_cuenta), 1, 140);
         ELSE
            -- BBVA le informa: en fecha %s no ha sido posible el débito de la cuota %s pactada en su ahorro programado %s.
            v_mensaje := substr(utl_lms.format_message(v_template, substr(lf_obt_fec_tra_formateado(SYSDATE), 0, 5), to_char(p_nro_cuota), p_nro_cuenta), 1, 140);
         END IF;
         v_ret := fu_ins_mensaje(v_cod_evento, v_cod_tip_evento, v_mensaje, p_cod_persona, p_nro_cuenta, v_fec_programada, 'S');
      END IF;
   END IF;   
END;

   FUNCTION fu_env_push(p_destino IN VARCHAR2, p_mensaje IN VARCHAR2, p_tipo IN VARCHAR2, p_origen IN VARCHAR2) RETURN NUMBER IS
      c_ws_metodo CONSTANT VARCHAR2(50) := 'Send';
      v_url          VARCHAR2(100) := '';
      v_ws_respuesta paw_json.JSONStructObj;
      v_parametros   VARCHAR2(500);
      v_resPost      TYP_POSTRESPUESTA;
      v_return       VARCHAR(10);
   BEGIN

      v_url        := g_not_webservice || c_ws_metodo;
      v_parametros := utl_lms.format_message('cod_destiny=%s&destiny=%s&message=%s&secure=0&origin=%s',p_tipo, p_destino, p_mensaje, p_origen);
      v_resPost    := fue_env_post(p_parametros => v_parametros, p_url => v_url);
      lp_ins_log_mensajeria(v_url || '?' || v_parametros, v_resPost.error || '|' || v_resPost.respuesta);
      IF (v_resPost.error = 'N') THEN
         v_ws_respuesta := paw_json.String2JSON(v_resPost.respuesta, '"');
         v_return       := paw_json.getAttrValue(v_ws_respuesta, 'code');
      ELSE
         dbms_output.put_line(v_resPost.respuesta);
         RETURN - 99;
      END IF;

      RETURN v_return;
   END;
function fu_obtenerDestinoPush(p_codigoPersona in Varchar2) return typ_mensajerespuesta is
  v_retorno typ_mensajerespuesta:=typ_mensajerespuesta;
  v_direccion varchar(200);
  v_tipo varchar(4);
  begin
  paw_uti.pr_mensajeUsuario(paw_uti.MSG_OK, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);  

  begin
      select direccion,cod_origen 
      into v_retorno.descripcionRespuesta,v_retorno.nombreRespuesta
      from bw_not_cli_destino d where d.cod_persona=p_codigoPersona and cod_destino=3 and rownum=1
      order by d.fec_insercion desc;
    EXCEPTION
      WHEN OTHERS THEN
        paw_uti.pr_mensajeUsuario(paw_uti.MSG_ERROR, v_retorno.nombreRespuesta, v_retorno.descripcionRespuesta, v_retorno.error);  
        END;
      return v_retorno;   
  end;

  --
  FUNCTION fu_not_rec_multiple(p_tipo           IN VARCHAR2,
                               p_cod_persona    IN ba_personas.cod_persona%TYPE,
                               p_moneda         IN ba_monedas.cod_moneda%TYPE,
                               p_monto          IN ge_movimientos.monto%TYPE,
                               p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE,
                               p_fecha          IN DATE) RETURN NUMBER IS
     v_cod_evento     bw_not_eventos.cod_evento%TYPE;
     v_horario        bw_not_eventos.horario%TYPE;
     v_ocurrencia     bw_not_eventos.ocurrencia%TYPE;
     v_mandatorio     bw_not_eventos.mandatorio%TYPE;
     v_template       bw_not_tip_eventos.template%TYPE;
     v_mensaje        bw_not_mensajes.mensaje%TYPE;
     v_ret            NUMBER(3);
     v_moneda         NUMBER(3);
     v_fecha          DATE := nvl(p_fecha, SYSDATE);
     v_cod_tip_evento bw_not_tip_eventos.cod_tip_evento%TYPE;
     v_cod_error      VARCHAR2(2) := '00';
  BEGIN
     -- segun el tipo definimos el tipo de notificacion
     SELECT decode(p_tipo, 'A', 'TRARSOL', -- modo A: aviso de recepcion de solicitud
                           'TRANSOL')  -- modo C,R: aviso de confirmacion/rechazo de solicitud
       INTO v_cod_tip_evento
       FROM DUAL;
     -- para el template
     IF p_tipo = 'R' THEN
        v_cod_error := '01'; -- template2
     END IF;
     -- obtenermos el evento
     v_ret := fu_obt_eve_suscripcion(p_cod_persona, NULL, v_cod_tip_evento, v_cod_evento, v_horario, p_monto, v_moneda, v_ocurrencia, v_mandatorio);

     IF v_ret <> 0 THEN
        -- no esta suscrito al servicio de notificaciones
        RETURN v_ret;
     END IF;
     -- obtenemos el temaplte
     IF fu_obt_not_template(v_cod_tip_evento, v_template, v_cod_error) <> 0 THEN
        RETURN -9; 
     END IF;
     -- obtenemos la moneda para formateo
     SELECT decode(p_moneda, 'GS', 600, 100)
       INTO v_moneda
       FROM dual;

     CASE p_tipo
        WHEN 'A' THEN
           -- BBVA le informa: la recepcion de la solicitud de transferencia de fondos por valor de %s %s.
           v_mensaje := substr(utl_lms.format_message(v_template, p_moneda, lf_obt_mto_formateado(p_monto, v_moneda)), 1, 140);
        WHEN 'C' THEN
           -- BBVA le informa: el credito de %s %s a la cuenta %s, por la transferencia de fondos solicitada el %s.
           v_mensaje := substr(utl_lms.format_message(v_template, p_moneda, lf_obt_mto_formateado(p_monto, v_moneda), lf_obt_ult_tarjeta(p_nro_cuenta), substr(lf_obt_fec_tra_formateado(v_fecha), 0, 5)), 1, 140);
        WHEN 'R' THEN
           -- BBVA le informa: el rechazo de %s %s, por la transferencia de fondos solicitada el %s.
           v_mensaje := substr(utl_lms.format_message(v_template, p_moneda, lf_obt_mto_formateado(p_monto, v_moneda), substr(lf_obt_fec_tra_formateado(v_fecha), 0, 5)), 1, 140);
        ELSE NULL;
     END CASE;
     RETURN fu_ins_mensaje(v_cod_evento, v_cod_tip_evento, v_mensaje, p_cod_persona, p_nro_cuenta, null, 'S');  
  END;


PROCEDURE pr_not_req_mas_push IS
  /*Solo envia notificaciones via push*/
  CURSOR not_masivas IS
    SELECT cod_persona, mensaje
    FROM bw_not_req_masivo_tmp;
  v_lim_mensajes NUMBER(5);
  v_con_mensajes NUMBER(5) := 0;
  v_aux_insertar NUMBER(3);
  v_fec_envio    DATE;
  v_tot_mensajes NUMBER := 0;
  v_sig_lote     NUMBER;
  v_sec_mensaje  NUMBER;
  v_encolado     VARCHAR(1);
  FUNCTION lf_obt_nro_lote RETURN NUMBER IS
    v_aux_lote NUMBER;
  BEGIN
    SELECT nvl(MAX(lote), 0)
    INTO v_aux_lote
    FROM bw_not_req_masivo;
    RETURN v_aux_lote + 1;
  END;

  function lf_tie_not_push(p_cod_persona IN varchar2)  RETURN VARCHAR2 IS 
  v_existe varchar2(1);
  BEGIN
      v_existe:='N';
      BEGIN
        SELECT 'S'
          INTO v_existe
          FROM bw_not_cli_destino c, bw_not_destinos d
         WHERE c.cod_persona = p_cod_persona
           and upper(d.nombre)='PUSH'
           AND d.cod_destino = c.cod_destino;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          v_existe:='N';
        WHEN OTHERS THEN
          v_existe:='N';
      END;
      return v_existe;
  END; 

   FUNCTION lf_ins_men_push(p_cod_evento IN NUMBER, p_cod_origen IN VARCHAR2, p_mensaje IN VARCHAR2, p_cod_persona IN VARCHAR2, p_nro_cuenta IN VARCHAR2,
                           p_fec_programada DATE DEFAULT NULL, p_enviar IN VARCHAR2 DEFAULT 'N') RETURN NUMBER IS
      v_cod_mensaje NUMBER(16) := 0;
      v_mensaje     VARCHAR2(140);
   BEGIN
      v_mensaje := substr(p_mensaje, 0, 140);
      IF (fu_obt_con_blacklist(p_cod_persona, p_cod_origen) = 'N') THEN
         BEGIN
            SELECT s_bw_not_mensajes.nextval
              INTO v_cod_mensaje
              FROM dual;

            INSERT INTO bw_not_mensajes
               (COD_MENSAJE, COD_CLI_DESTINO, COD_EVENTO, COD_ORIGEN, MENSAJE, COD_PERSONA, NRO_CUENTA, FEC_PROGRAMADO, ENVIAR)
            VALUES
               (v_cod_mensaje, 3, p_cod_evento, p_cod_origen, v_mensaje, p_cod_persona, p_nro_cuenta, p_fec_programada, p_enviar);
         EXCEPTION
            WHEN OTHERS THEN
               lp_reg_mensaje('fu_ins_men_push:'||v_cod_mensaje||'-'||p_cod_evento||'-'||p_cod_origen||'-'||v_mensaje||'-'||p_cod_persona||'-'||p_nro_cuenta||'-'||p_fec_programada||'-'||p_enviar, SQLERRM);
               RETURN 11; --Paso algo
         END;
      ELSE
         RETURN 22;
      END IF;
      RETURN 0; --OK
   END; 

BEGIN
  v_fec_envio    := trunc(SYSDATE) + 14 / 24;
  v_lim_mensajes := to_number(nvl(fug_obt_pardinamico('BW_NOT_MEN_MASIVO_LIM'),
                                  1000));
  v_sig_lote     := lf_obt_nro_lote;
  FOR destino IN not_masivas LOOP
    v_encolado := 'N';
    IF paw_not.fu_obt_con_blacklist(destino.cod_persona, 'PROMOPUSH') = 'N' 
      and lf_tie_not_push(destino.cod_persona)='S' THEN --Solo si tiene definida la Notificaci+on Push
      v_aux_insertar := lf_ins_men_push(64,
                                       'MASIVOR',
                                       destino.mensaje,
                                       destino.cod_persona,
                                       '0',
                                       v_fec_envio,
                                       'S');
      v_con_mensajes := v_con_mensajes + 1;
      v_tot_mensajes := v_tot_mensajes + 1;
      v_encolado     := 'S';
      IF (v_con_mensajes >= v_lim_mensajes) THEN
        v_con_mensajes := 0;
        v_fec_envio    := v_fec_envio + 1;
      END IF;
    END IF;
    v_sec_mensaje := s_bw_not_masivos.NEXTVAL;
    BEGIN
      INSERT INTO bw_not_req_masivo
        (COD_MENSAJE, cod_persona, mensaje, lote, encolado)
      VALUES
        (v_sec_mensaje, destino.cod_persona, destino.mensaje, v_sig_lote,
         v_encolado);
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;
END;
  FUNCTION fu_not_cam_cla(p_cod_persona bw_ope_claves.cod_persona%TYPE,
                         p_cod_per_vinculada bw_ope_claves.cod_per_vinculada%TYPE,
                         p_tip_notificacion VARCHAR2,
                         p_tip_clave VARCHAR2)
  RETURN NUMBER IS
    v_cod_evento bw_not_eventos.cod_evento%TYPE;
    v_horario    bw_not_eventos.horario%TYPE;
    v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio bw_not_eventos.mandatorio%TYPE;
    v_template   bw_not_tip_eventos.template%TYPE;
    v_mensaje    bw_not_mensajes.mensaje%TYPE;
    v_ret        NUMBER(3);
    v_tip_clave  varchar(20);
    v_tip_evento bw_not_eventos.cod_tip_evento%type;
  BEGIN
      IF p_tip_clave = 'T' THEN
        v_tip_clave := 'transaccional';
      ELSE
        v_tip_clave := 'de acceso';
      END IF;
      if p_tip_notificacion = 'B' then
         v_tip_evento := 'NOTBLOCLA';
      else
         v_tip_evento := 'NOTCAMCLA';
      end if;
      v_ret := fu_obt_eve_suscripcion(p_cod_persona, 0, v_tip_evento, v_cod_evento, v_horario, 0, 600, v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN
         IF fu_obt_not_template(v_tip_evento, v_template) = 0 THEN
           v_mensaje := substr(utl_lms.format_message(v_template, v_tip_clave),0, g_men_longitud);
           v_ret := fu_ins_mensaje(v_cod_evento, v_tip_evento, v_mensaje, p_cod_persona, 0, null, 'S');

       ELSE
            RETURN 20;
         END IF;
      END IF;
    RETURN v_ret;
  END;
  FUNCTION fu_not_pre_apr(p_cod_persona bw_ope_claves.cod_persona%TYPE,
                          p_nro_cta_credito VARCHAR2) RETURN NUMBER IS  
    v_cod_evento bw_not_eventos.cod_evento%TYPE;
    v_horario    bw_not_eventos.horario%TYPE;
    v_ocurrencia bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio bw_not_eventos.mandatorio%TYPE;
    v_template   bw_not_tip_eventos.template%TYPE;
    v_mensaje    bw_not_mensajes.mensaje%TYPE;
    v_ret        NUMBER(3);
    v_tip_clave  varchar(20);
    v_tip_evento bw_not_eventos.cod_tip_evento%type := 'NOTPREAPR';
  BEGIN
    v_ret := fu_obt_eve_suscripcion(p_cod_persona, 0, v_tip_evento, v_cod_evento, v_horario, 0, 600, v_ocurrencia, v_mandatorio);
      IF v_ret = 0 THEN
         IF fu_obt_not_template(v_tip_evento, v_template) = 0 THEN
           v_mensaje := substr(utl_lms.format_message(v_template, p_nro_cta_credito),0, g_men_longitud);
           v_ret := fu_ins_mensaje(v_cod_evento, v_tip_evento, v_mensaje, p_cod_persona, nvl(p_nro_cta_credito, 0), null, 'S');

       ELSE
            RETURN 20;
         END IF;
      END IF;
    RETURN v_ret;
  END;
  PROCEDURE pr_not_nue_dispositivo (p_codPersona        IN ba_personas.cod_persona%TYPE,
                                     p_cod_per_vinculada IN ba_personas.cod_persona%TYPE,
                                     p_os                IN VARCHAR2,
                                     p_os_version        IN VARCHAR2,
                                     p_model             IN VARCHAR2,
                                     p_brand             IN VARCHAR2,
                                     p_ip                IN VARCHAR2,
                                     p_ubication         IN VARCHAR2,
                                     p_cod_fac           IN VARCHAR2,
                                     p_cli_type          IN VARCHAR2) IS
     v_mensaje        VARCHAR2(1500);
     v_res_noti_mail  VARCHAR(5);
     v_dir_email      VARCHAR2(300);
     v_suscripto      NUMBER;
     v_nro_telefono   VARCHAR2(20);
     v_tipo_dest      VARCHAR2(12);
     v_destino        typ_mensajerespuesta := typ_mensajerespuesta;
     v_nombre         VARCHAR2(120);
     v_nom_empresa    ba_personas.nom_completo%TYPE;
     v_dispositivo    VARCHAR2(60);
     v_os             VARCHAR2(100);
     v_version     VARCHAR2(100);
   BEGIN

     BEGIN
       SELECT cod_destino
         INTO v_suscripto
         FROM bw_not_cli_destino
        WHERE cod_persona = p_codPersona
          AND activo = 'S'
          AND ROWNUM = 1;
     EXCEPTION
       WHEN OTHERS THEN NULL;
     END;

     --verifiacr si enviar la notificacion cuando es un nuevo acceso Web
     if (p_cli_type = 'WEB' AND fug_obt_pardinamico('NUE_DIS_WEB_ENVIAR') = 'N')THEN
        return;
     END IF;
     v_nombre := fue_obt_nom_persona(p_codPersona);
     v_dir_email := fug_obt_cli_correo_adi(p_codPersona);

     IF (p_os is null) THEN
       v_os := '-';
     ELSE
       v_os := p_os;
     END IF;

     IF (p_cli_type = 'ANDROID' OR p_cli_type = 'IPHONE' OR p_cli_type = 'HUAWEI') THEN
       v_dispositivo := UTL_URL.ESCAPE('Aplicación Móvil', TRUE, 'UTF-8');
     ELSE
       v_dispositivo := 'Navegador Web ('||p_brand||')';
     END IF;

     If(p_os_version is null) THEN
        v_version := '-';
     ELSE        
        IF (p_cli_type = 'ANDROID' OR p_cli_type = 'HUAWEI') THEN
            v_version := SUBSTR(p_os_version, 0, INSTR(p_os_version, '|') -1);
            IF (v_version is null OR v_version = '') THEN
                v_version := '-';
            END IF;
        ELSE
            v_version := p_os_version;
        END IF;
     END IF;

     --enviamos el mail independientemente a que canal está suscripto
     v_mensaje := '<p>Hola '|| UTL_URL.ESCAPE(v_nombre, TRUE, 'UTF-8');
     IF (p_cod_per_vinculada is not null) THEN
       v_nom_empresa := fue_obt_nom_persona(p_cod_per_vinculada);
       v_mensaje := v_mensaje || ' de ' || UTL_URL.ESCAPE(v_nom_empresa, TRUE, 'UTF-8') ;
     END IF;
     v_mensaje := v_mensaje || UTL_URL.ESCAPE(':</p><p>Registramos un inicio de sesión en tu cuenta de <b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b> desde un dispositivo nuevo:</p>', TRUE, 'UTF-8');

     v_mensaje := v_mensaje || UTL_URL.ESCAPE('<p style="margin-left:1em"><b>Código Dispositivo</b>: ', TRUE, 'UTF-8')|| p_cod_fac;
     v_mensaje := v_mensaje || '<br><b>Dispositivo</b>: '|| v_dispositivo;
     v_mensaje := v_mensaje || '<br><b>Sistema Operativo</b>: '|| v_os;
     v_mensaje := v_mensaje || UTL_URL.ESCAPE('<br><b>Versión</b>: ', TRUE, 'UTF-8')|| v_version;
     IF (p_cli_type = 'ANDROID' OR p_cli_type = 'IPHONE' OR p_cli_type = 'HUAWEI') THEN
        v_mensaje := v_mensaje || '<br><b>Modelo</b>: '|| p_brand || ' ' || p_model;
     END IF;

     if fug_obt_pardinamico('NUE_DIS_IP_MOSTRAR') = 'S' THEN

          v_mensaje := v_mensaje || UTL_URL.ESCAPE('</p><p style="margin-left:1em"><b>Dirección IP</b>: ', TRUE, 'UTF-8')|| p_ip;

         IF (p_ubication is not null) THEN
              v_mensaje := v_mensaje || UTL_URL.ESCAPE('<br><b>Ubicación</b>: ', TRUE, 'UTF-8')|| p_ubication ||UTL_URL.ESCAPE(' (puede no ser la ubicación exacta)', TRUE, 'UTF-8');
         END IF;
     END IF;

     v_mensaje := v_mensaje || '</p><p style="margin-left:1em"><b>Fecha y Hora</b>: '|| to_char(sysdate, 'dd/MM/yyyy HH24:MI');
     v_mensaje := v_mensaje || UTL_URL.ESCAPE('</p><p>Te hemos enviado este mensaje para validar esta acción. Si no reconoces este inicio de sesión, recomendamos que cambies tu contraseña de inmediato para resguardar tu cuenta.</p><p>Si necesitas asistencia, contáctanos al teléfono +595 21 417 6000.</p><p>Nuestra prioridad es tu seguridad.</p>', TRUE, 'UTF-8');

     IF v_mensaje is not null THEN
         v_res_noti_mail := fu_env_email_prueba(v_dir_email, v_mensaje, 'PAW_SEG');
     END IF;

     --Solo enviamos a los canales alternativos para PF
     if(p_cod_per_vinculada is null) THEN

          --y si esta suscripto a push o sms tambien enviamos a ese canal.
         IF (v_suscripto = 1) THEN --sms
           v_nro_telefono := fue_obt_tel_principa(p_codPersona);
           v_mensaje := UTL_URL.ESCAPE('Registramos un inicio de sesión en '||fug_obt_pardinamico('NOM_BANCO')||' desde un dispositivo nuevo. Si no fue usted, comuniquese de inmediato al 021 4176000.', TRUE, 'UTF-8');
           IF (v_mensaje is not null and v_nro_telefono is not null) THEN
              v_res_noti_mail := fu_env_sms_prueba(v_nro_telefono, v_mensaje, 'PAW_SEG');
           END IF;
         ELSIF (v_suscripto = 3) THEN --push
           v_destino := fu_obtenerDestinoPush(p_codPersona);
           IF v_destino.nombreRespuesta = 'ANDR' THEN
             v_tipo_dest := 'PUSH_ANDROID';
           ELSIF v_destino.nombreRespuesta = 'IOSX' THEN
             v_tipo_dest := 'PUSH_IOS';
           ELSIF v_destino.nombreRespuesta = 'HUA' THEN
             v_tipo_dest := 'PUSH_HUAWEI';
           END IF;
           v_mensaje := UTL_URL.ESCAPE('Registramos un inicio de sesión en '||fug_obt_pardinamico('NOM_BANCO')||' desde un dispositivo nuevo. Si no fue usted, comuniquese de inmediato al 021 4176000.', TRUE, 'UTF-8');
           IF (v_mensaje is not null) THEN
              v_res_noti_mail := fu_env_push(v_destino.descripcionRespuesta, --bw_not_cli_destino.direccion
                                                     v_mensaje,
                                                     v_tipo_dest,
                                                     'PAW_SEG');
           END IF;

     END IF;

     END IF;
   END;

   PROCEDURE pr_not_nue_dispositivo_error (p_codPersona        IN ba_personas.cod_persona%TYPE,
                                     p_cod_per_vinculada IN ba_personas.cod_persona%TYPE,
                                     p_os                IN VARCHAR2,
                                     p_os_version        IN VARCHAR2,
                                     p_model             IN VARCHAR2,
                                     p_brand             IN VARCHAR2,
                                     p_ip                IN VARCHAR2,
                                     p_ubication         IN VARCHAR2,
                                     p_cod_fac           IN VARCHAR2,
                                     p_cli_type          IN VARCHAR2) IS
     v_mensaje        VARCHAR2(1500);
     v_res_noti_mail  VARCHAR(5);
     v_dir_email      VARCHAR2(300);
     v_suscripto      NUMBER;
     v_nro_telefono   VARCHAR2(20);
     v_tipo_dest      VARCHAR2(12);
     v_destino        typ_mensajerespuesta := typ_mensajerespuesta;
     v_nombre         VARCHAR2(120);
     v_nom_empresa    ba_personas.nom_completo%TYPE;
     v_dispositivo    VARCHAR2(60);
     v_os             VARCHAR2(100);
     v_version     VARCHAR2(100);
   BEGIN

     BEGIN
       SELECT cod_destino
         INTO v_suscripto
         FROM bw_not_cli_destino
        WHERE cod_persona = p_codPersona
          AND activo = 'S'
          AND ROWNUM = 1;
     EXCEPTION
       WHEN OTHERS THEN NULL;
     END;

     --verifiacr si enviar la notificacion cuando es un nuevo acceso Web
     if (p_cli_type = 'WEB' AND fug_obt_pardinamico('NUE_DIS_WEB_ENVIAR') = 'N')THEN
        return;
     END IF;
     v_nombre := fue_obt_nom_persona(p_codPersona);
     v_dir_email := fug_obt_cli_correo_adi(p_codPersona);

     IF (p_os is null) THEN
       v_os := '-';
     ELSE
       v_os := p_os;
     END IF;

     IF (p_cli_type = 'ANDROID' OR p_cli_type = 'IPHONE') THEN
       v_dispositivo := UTL_URL.ESCAPE('Aplicación Móvil', TRUE, 'UTF-8');
     ELSE
       v_dispositivo := 'Navegador Web ('||p_brand||')';
     END IF;

     If(p_os_version is null) THEN
        v_version := '-';
     ELSE        
        IF (p_cli_type = 'ANDROID') THEN
            v_version := SUBSTR(p_os_version, 0, INSTR(p_os_version, '|') -1);
            IF (v_version is null OR v_version = '') THEN
                v_version := '-';
            END IF;
        ELSE
            v_version := p_os_version;
        END IF;
     END IF;

     --enviamos el mail independientemente a que canal está suscripto
     v_mensaje := '<p>Hola '|| UTL_URL.ESCAPE(v_nombre, TRUE, 'UTF-8');
     IF (p_cod_per_vinculada is not null) THEN
       v_nom_empresa := fue_obt_nom_persona(p_cod_per_vinculada);
       v_mensaje := v_mensaje || ' de ' || UTL_URL.ESCAPE(v_nom_empresa, TRUE, 'UTF-8') ;
     END IF;
     v_mensaje := v_mensaje || UTL_URL.ESCAPE(':</p><p>Registramos un intento fallido de inicio de sesión en tu cuenta de <b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b> desde un dispositivo nuevo:</p>', TRUE, 'UTF-8');

     v_mensaje := v_mensaje || UTL_URL.ESCAPE('<p style="margin-left:1em"><b>Código Dispositivo</b>: ', TRUE, 'UTF-8')|| p_cod_fac;
     v_mensaje := v_mensaje || '<br><b>Dispositivo</b>: '|| v_dispositivo;
     v_mensaje := v_mensaje || '<br><b>Sistema Operativo</b>: '|| v_os;
     v_mensaje := v_mensaje || UTL_URL.ESCAPE('<br><b>Versión</b>: ', TRUE, 'UTF-8')|| v_version;
     IF (p_cli_type = 'ANDROID' OR p_cli_type = 'IPHONE') THEN
        v_mensaje := v_mensaje || '<br><b>Modelo</b>: '|| p_brand || ' ' || p_model;
     END IF;

     if fug_obt_pardinamico('NUE_DIS_IP_MOSTRAR') = 'S' THEN

          v_mensaje := v_mensaje || UTL_URL.ESCAPE('</p><p style="margin-left:1em"><b>Dirección IP</b>: ', TRUE, 'UTF-8')|| p_ip;

         IF (p_ubication is not null) THEN
              v_mensaje := v_mensaje || UTL_URL.ESCAPE('<br><b>Ubicación</b>: ', TRUE, 'UTF-8')|| p_ubication ||UTL_URL.ESCAPE(' (puede no ser la ubicación exacta)', TRUE, 'UTF-8');
         END IF;
     END IF;

     v_mensaje := v_mensaje || '</p><p style="margin-left:1em"><b>Fecha y Hora</b>: '|| to_char(sysdate, 'dd/MM/yyyy HH24:MI');
     v_mensaje := v_mensaje || UTL_URL.ESCAPE('</p><p>Te hemos enviado este mensaje para validar esta acción. Si no reconoces este intento de inicio de sesión, recomendamos que cambies tu contraseña de inmediato para resguardar tu cuenta.</p><p>Si necesitas asistencia, contáctanos al teléfono +595 21 417 6000.</p><p>Nuestra prioridad es tu seguridad.</p>', TRUE, 'UTF-8');

     IF v_mensaje is not null THEN
         v_res_noti_mail := fu_env_email_prueba(v_dir_email, v_mensaje, 'PAW_SEG');
     END IF;

     --Solo enviamos a los canales alternativos para PF
     if(p_cod_per_vinculada is null) THEN

          --y si esta suscripto a push o sms tambien enviamos a ese canal.
         IF (v_suscripto = 1) THEN --sms
           v_nro_telefono := fue_obt_tel_principa(p_codPersona);
           v_mensaje := UTL_URL.ESCAPE('Registramos un intento fallido de inicio de sesión en '||fug_obt_pardinamico('NOM_BANCO')||' desde un dispositivo nuevo. Si no fue usted, comuniquese de inmediato al 021 4176000.', TRUE, 'UTF-8');
           IF (v_mensaje is not null and v_nro_telefono is not null) THEN
              v_res_noti_mail := fu_env_sms_prueba(v_nro_telefono, v_mensaje, 'PAW_SEG');
           END IF;
         ELSIF (v_suscripto = 3) THEN --push
           v_destino := fu_obtenerDestinoPush(p_codPersona);
           IF v_destino.nombreRespuesta = 'ANDR' THEN
             v_tipo_dest := 'PUSH_ANDROID';
           ELSIF v_destino.nombreRespuesta = 'IOSX' THEN
             v_tipo_dest := 'PUSH_IOS';
           END IF;
           v_mensaje := UTL_URL.ESCAPE('Registramos un intento fallido inicio de sesión en '||fug_obt_pardinamico('NOM_BANCO')||' desde un dispositivo nuevo. Si no fue usted, comuniquese de inmediato al 021 4176000.', TRUE, 'UTF-8');
           IF (v_mensaje is not null) THEN
              v_res_noti_mail := fu_env_push(v_destino.descripcionRespuesta, --bw_not_cli_destino.direccion
                                                     v_mensaje,
                                                     v_tipo_dest,
                                                     'PAW_SEG');
           END IF;

     END IF;

     END IF;
   END;

 PROCEDURE pr_not_deu_ven_pag_servicios (p_datos IN TYP_LISTAPSNOTIF DEFAULT NULL) IS
    v_respuesta         NUMBER(3);
 BEGIN

    IF p_datos IS NOT NULL THEN

         FOR detalle in p_datos.FIRST .. p_datos.LAST LOOP
           BEGIN
                v_respuesta := fu_not_deu_ven_pag_seg_envio(
                               p_datos(detalle).codigoPersona,
                               p_datos(detalle).tipoPersona,
                               p_datos(detalle).correoCuerpo
                               );

           EXCEPTION
              WHEN OTHERS THEN
                 NULL;
           END;
        END LOOP;
    END IF;

 EXCEPTION
    WHEN OTHERS THEN
        NULL;
 END;

  /**
  * Respuesta 0 : exito sin errores
  * Respuesta 1 : no se pudo enviar el mail pero si la notif
  * Repsuesta 2 : se pudo enviar el mail pero no la notif
  * Repsuesta 3 : no se pudo enviar ni el mail ni la notif
  */
 FUNCTION fu_not_deu_ven_pag_seg_envio(p_cod_persona IN  ba_personas.cod_persona%TYPE,
                                       p_tip_persona IN VARCHAR2,
                                       p_mai_cuerpo IN VARCHAR2
                                      ) RETURN NUMBER IS
    v_cod_evento  bw_not_eventos.cod_evento%TYPE;
    v_horario     bw_not_eventos.horario%TYPE;
    v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
    v_mandatorio  bw_not_eventos.mandatorio%TYPE;
    v_template    bw_not_tip_eventos.template%TYPE;
    v_mensaje     bw_not_mensajes.mensaje%TYPE;
    v_ret         NUMBER(3) := 0;
    v_tip_evento  VARCHAR2(15):='PSDEUNUE';
    v_tipo        VARCHAR(2):='00';
    v_dir_cor_pri VARCHAR2(120);
    v_dir_cor_not VARCHAR2(120) := NULL;
    v_res_noti_mail  VARCHAR(5);
    v_ret_not     NUMBER(3) := 0;
    n pls_integer;
 BEGIN

    --v_nombre := fue_obt_nom_persona(p_cod_persona); --nombre de la persona o empresa
    v_dir_cor_pri := TRIM(UPPER(paw_seg.fu_obt_mail(p_cod_persona))); -- direccion de email registrada en ba_emails

    --Enviamos siempre al mail del cliente en ba_emails.
    BEGIN
        --v_res_noti_mail := fu_env_email_prueba(v_dir_cor_pri,UTL_URL.ESCAPE(p_mai_cuerpo), 'PAW_SEG');
        v_res_noti_mail := fu_env_email_prueba(v_dir_cor_pri,p_mai_cuerpo, 'PAW_SEG');
    EXCEPTION
        WHEN OTHERS THEN
            v_ret := 1;
    END;

    --Verificamos si tiene configuracion de notificaciones para enviar por el canal seleccionado.
    BEGIN
       n := dbms_random.value(1,3); --Random del template
       v_tip_evento := v_tip_evento || n;
       v_ret_not := fu_obt_eve_suscripcion(p_cod_persona, null, v_tip_evento, v_cod_evento, v_horario, 0 ,600, v_ocurrencia, v_mandatorio);

       IF v_ret_not = 0 THEN --esta suscripto

          --verificamos si tiene configurado el canal email para las notificaciones, 
          v_dir_cor_not := lf_ver_destino(p_cod_persona, 'EMAIL'); 

          --entra al bloque solo si la configuracion no es mail o es mail pero el destino es distinto al ya usado
          IF (v_dir_cor_not IS NULL OR TRIM(UPPER(v_dir_cor_not)) <> v_dir_cor_pri) THEN
            IF fu_obt_not_template(v_tip_evento, v_template, v_tipo) <> 0 THEN
               RETURN 20;
            END IF;

            --Usted tiene nuevas facturas de sus servicios favoritos, acceda a la app móvil para realizar el pago y evitar demoras.                                     
             v_ret     := fu_ins_mensaje(v_cod_evento, v_tip_evento, v_template, p_cod_persona, '0', NULL, 'S');

          END IF;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            v_ret := v_ret + 2;
    END;

    RETURN v_ret;
 END;


    FUNCTION fu_not_pag_ban_qr(p_cod_persona IN  ba_personas.cod_persona%TYPE,
                                          p_mai_cuerpo IN VARCHAR2,
                                          p_metodo_pago IN VARCHAR,
                                          p_monto       IN NUMBER,
                                          p_nro_cuenta  IN VARCHAR2,
                                          p_nro_tarjeta IN VARCHAR2,
                                          p_comercio IN VARCHAR2,
                                          p_fecha IN DATE,
                                          p_estado IN VARCHAR2
                                          ) RETURN VARCHAR2 IS
        v_cod_evento  bw_not_eventos.cod_evento%TYPE;
        v_horario     bw_not_eventos.horario%TYPE;
        v_ocurrencia  bw_not_eventos.ocurrencia%TYPE;
        v_mandatorio  bw_not_eventos.mandatorio%TYPE;
        v_template    bw_not_tip_eventos.template%TYPE;
        v_mensaje     bw_not_mensajes.mensaje%TYPE;
        v_ret         VARCHAR2(14) := '0';
        v_tip_evento  VARCHAR2(15):='QRPAGO';
        v_tipo        VARCHAR(2):= '00';
        v_medio         VARCHAR2(16);
        v_prod         VARCHAR2(18);
        v_dir_cor_pri VARCHAR2(120);
        v_dir_cor_not VARCHAR2(120) := NULL;
        v_res_noti_mail  VARCHAR(5);
        v_ret_not     NUMBER(3) := 0;
        v_rechazo VARCHAR2(1):='N';
	n pls_integer;

     BEGIN

        v_dir_cor_pri := TRIM(UPPER(paw_seg.fu_obt_mail(p_cod_persona))); -- direccion de email registrada en ba_emails

        --Enviamos siempre al mail del cliente en ba_emails.
        BEGIN
            v_res_noti_mail := fu_env_email_prueba(v_dir_cor_pri, p_mai_cuerpo, 'PAW_BEL');
            v_ret := v_res_noti_mail;
        EXCEPTION
            WHEN OTHERS THEN
                v_ret := '01';
        END;

        --por ahora solo se enviran las notificaciones para cuando es por debito
        IF p_metodo_pago = 'debit' then
        --Verificamos si tiene configuracion de notificaciones para enviar por el canal seleccionado.
        BEGIN

                if(p_estado<>'S') then
                    v_rechazo:='S';
                    v_tipo:='11';
                end if;
               v_ret_not := fu_obt_eve_suscripcion(p_cod_persona, null, v_tip_evento, v_cod_evento, v_horario, p_monto ,600, v_ocurrencia, v_mandatorio, v_rechazo);
               v_ret := v_ret || v_ret_not;

           IF v_ret_not = 0 THEN --esta suscripto

              --verificamos si tiene configurado el canal email para las notificaciones, 
              v_dir_cor_not := lf_ver_destino(p_cod_persona, 'EMAIL'); 

              --entra al bloque solo si la configuracion no es mail o es mail pero el destino es distinto al ya usado
              IF (v_dir_cor_not IS NULL OR TRIM(UPPER(v_dir_cor_not)) <> v_dir_cor_pri) THEN
                IF fu_obt_not_template(v_tip_evento, v_template, v_tipo) <> 0 THEN
                   v_ret := v_ret || '-20';
                   RETURN v_ret;
                END IF;

                IF p_metodo_pago = 'credit' then
                    v_medio := 'tarjeta';
                    v_prod := p_nro_tarjeta;
                ELSE
                    v_medio := 'cuenta';
                    v_prod := p_nro_cuenta;
                END IF;

                --BBVA le informa: la compra QR de GS %s en %s, con la %s %s el %s
                 v_mensaje := substr(
                                utl_lms.format_message(v_template,
                                                          lf_obt_mto_formateado(p_monto, 600),
                                                          substr(p_comercio, 0, 30),
                                                          v_medio,                                                       
                                                          lf_obt_ult_tarjeta(v_prod),
                                                          lf_obt_fec_tra_formateado(p_fecha)
                                                       )
                                ,0, g_men_longitud);



                 v_ret     := v_ret || '-' || fu_ins_mensaje(v_cod_evento, v_tip_evento, v_mensaje, p_cod_persona, '0', NULL, 'S');

              END IF;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                v_ret := v_ret || '#99';
        END;
        end if;

        RETURN v_ret;
     END;
END PAW_NOT;
/

