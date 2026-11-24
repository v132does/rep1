CREATE OR REPLACE PACKAGE BODY IT.PAG_DNA IS

v_sep_envio   VARCHAR2(1) := '#';
v_sep_retorno VARCHAR2(1) := '#';
v_pos              number;

PROCEDURE pr_obt_datos_servidor(p_servidor IN OUT VARCHAR2,
                                p_puerto   IN OUT NUMBER) IS
BEGIN
  --Obtiene datos de Producción
  IF FUG_ES_PRODUCCION = 'S' THEN
    p_servidor := fug_obt_pardinamico('DIR_SVR_DNA_PRODUCCION');
    p_puerto   := fug_obt_pardinamico('DNA_PRO_PUERTO');
  --Obtiene datos de Test
  ELSE 
    p_servidor := fug_obt_pardinamico('DIR_SVR_DNA_TEST');
    p_puerto   := fug_obt_pardinamico('DNA_TES_PUERTO');
  END IF;
END;                                

function f_obt_dv_dna(p_string in varchar) return varchar2 is
    i             NUMBER := 0;
    v_longitud    NUMBER := 0;
    v_posicion    NUMBER := 0;
    v_total       NUMBER := 0;
    v_caracter    VARCHAR2(1);
    v_letra       VARCHAR2(1);
    v_iddepositodna varchar2(18);

    BEGIN
      v_iddepositodna := p_string;
      v_longitud := length(p_string);
      FOR i IN 1 .. v_longitud LOOP
        v_caracter := substr(p_string, i, 1);
        v_posicion := ascii(v_caracter);
        v_total    := v_total + v_posicion;
      END LOOP;
      v_total := MOD(v_total, 23);
      v_total := v_total + 65;
      IF (v_total > 91) THEN
        v_total := 65;
      END IF;
      v_letra := chr(v_total);
      IF (v_letra = 'I') THEN
        v_letra := 'X';
      END IF;
      IF (v_letra = 'O') THEN
        v_letra := 'Y';
      END IF;
      IF (v_letra = 'Q') THEN
        v_letra := 'Z';
      END IF;

      v_iddepositodna := v_iddepositodna||v_letra;
      return v_iddepositodna;

   EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
END;
  procedure lp_act_log(p_cod_error        ge_dna_log.codigoerror%TYPE,
                           p_msj_error        ge_dna_log.msgerror%TYPE,
                           p_status           ge_dna_log.status%TYPE,
                           p_ip               ge_dna_log.ip%TYPE,
                           p_nro_deposito_dna ge_dna_log.iddepositodna%TYPE,
                           p_tipo             ge_dna_log.tipo%TYPE,
                           p_monto            ge_dna_log.monto%TYPE,
                           p_ruc_despachante  ge_dna_log.idtrader%TYPE,
                           p_ruc_importador   ge_dna_log.idbroker%TYPE,
                           p_nro_secuencia    ge_dna_log.id%TYPE,
                           p_request          ge_dna_log.request%type,
                           p_response         ge_dna_log.response%TYPE,
                           p_estado           ge_dna_log.estado%TYPE,
                           p_nom_importador   ge_dna_log.brokername%TYPE,
                           p_nom_despachante  ge_dna_log.tradername%TYPE,
                           p_nro_deposito     ge_dna_log.iddeposito%TYPE,
                           p_mto_cheques      ge_dna_log.requestcheckamount%TYPE,
                           p_mto_efectivo     ge_dna_log.requestcashamount%TYPE)
    as
    PRAGMA AUTONOMOUS_TRANSACTION;
  Begin
    -- Actualiza la tabla de log
    UPDATE ge_dna_log l
       SET l.status             = P_status,
           l.codigoerror        = P_cod_error,
           l.msgerror           = P_msj_error,
           l.ip                 = P_ip,
           l.request            = p_request,
           l.response           = p_response,
           l.iddeposito         = p_nro_deposito,
           l.iddepositodna      = p_nro_deposito_dna,
           l.tradername         = p_nom_despachante,
           l.brokername         = p_nom_importador,
           l.estado             = p_estado,
           l.monto              = decode(nvl(p_monto, 0),
                                         0,
                                         l.monto,
                                         p_monto),
           l.requestcheckamount = p_mto_cheques,
           l.requestcashamount  = p_mto_efectivo,
           l.fechaactualizacion = SYSDATE
     WHERE l.id = p_nro_secuencia;
    COMMIT;

  end;

  /* FUNCION QUE RECUPERA LOS DATOS DEL DEPOSITO DE LA ADUANA
  *  p_nro_deposito : identificador del deposito generado por el banco para la DNA
  *  p_monto
  */
  FUNCTION fu_rec_deposito(p_nro_deposito IN VARCHAR2,
                           p_monto        OUT NUMBER)
  RETURN VARCHAR2 IS
  PRAGMA AUTONOMOUS_TRANSACTION;
    v_tip_operacion  VARCHAR2(1) := 'V';
    v_retorno        VARCHAR2(500);
    v_nro_secuencia  NUMBER(10);
    v_resp           VARCHAR2(2000);
    v_ok             VARCHAR2(1);
    v_msj            VARCHAR2(500);

    v_cod_error        ge_dna_log.codigoerror%TYPE;
    v_msj_error        ge_dna_log.msgerror%TYPE;
    v_status           ge_dna_log.status%TYPE;
    v_ip               ge_dna_log.ip%TYPE;
    v_log              VARCHAR2(4000);

    v_nro_deposito_dna ge_dna_log.iddepositodna%TYPE;
    v_tipo             ge_dna_log.tipo%TYPE;
    v_monto            ge_dna_log.monto%TYPE;
    v_ruc_despachante  ge_dna_log.idtrader%TYPE;
    v_ruc_importador   ge_dna_log.idbroker%TYPE;
    v_fec_recepcion    DATE;
  BEGIN
    -- Id clave a Grabar, llave del archivo
    SELECT s_dna_log.NEXTVAL INTO v_nro_secuencia FROM dual;

    -- Inserto para que el programa del Web service tome los datos
    INSERT INTO ge_dna_log
      (id, iddeposito, fechaoperacion, fechainserccion, usuario, estado, tipooperacion)
    VALUES
      (v_nro_secuencia, p_nro_deposito, SYSDATE, SYSDATE, USER, 'P', v_tip_operacion);

    COMMIT;

    -- Arma el mensaje a enviar
    v_msj := v_tip_operacion || v_sep_envio || p_nro_deposito;

    --obtiene servidor y puerto
    pr_obt_datos_servidor(g_servidor,g_puerto);    
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(p_servidor   => g_servidor,
                                 p_puerto     => g_puerto,
                                 p_tie_espera => g_tie_espera,
                                 p_mensaje    => v_msj,
                                 p_respuesta  => v_resp);

    IF v_ok != 'S' THEN
      -- Hubo problema en el envio
      v_resp := '01-Error de Conexión con el Socket Interno';
      RETURN v_resp;
    END IF;

    -- Recupera los datos
    DECLARE
      v_str   VARCHAR2(2000) := v_resp || v_sep_retorno;
      v_pos   NUMBER(5);
      v_valor VARCHAR2(2000);
      v_nro   NUMBER(3) := 0;
    BEGIN
      LOOP
        v_pos := instr(v_str, v_sep_retorno);
        EXIT WHEN nvl(v_pos,0) = 0;
        v_valor := substr(v_str, 1, v_pos - 1);
        IF substr(v_valor, 1, 4) = 'null' THEN
          v_valor := NULL;
        END IF;
        v_str := substr(v_str, v_pos + 1);
        v_nro := v_nro + 1;
        -- Asgina los valores de acuerdo a la posicion
        IF v_valor IS NOT NULL THEN
          IF v_nro = 1 THEN
            v_cod_error := v_valor;
          ELSIF v_nro = 2 THEN
            v_msj_error := substr(v_valor,1,150);
          ELSIF v_nro = 3 THEN
            v_status := v_valor;
          ELSIF v_nro = 4 THEN
            v_ip := v_valor;
          ELSIF v_nro = 5 THEN
            v_log := REPLACE(v_valor, '|', chr(10));
          ELSIF v_nro = 6 THEN
            v_nro_deposito_dna := v_valor;
          ELSIF v_nro = 7 THEN
            v_tipo := v_valor;
          ELSIF v_nro = 8 THEN
            v_monto := to_number(v_valor);
          ELSIF v_nro = 9 THEN
            v_ruc_despachante := v_valor;
          ELSIF v_nro = 10 THEN
            v_ruc_importador := v_valor;
          ELSIF v_nro = 11 THEN
            v_fec_recepcion := to_date(v_valor, 'yyyymmddhh24miss');
          END IF;
        END IF;
      END LOOP;
    END;

    v_pos := instr(v_log,';}');

    -- Actualiza la tabla de log
    UPDATE ge_dna_log l
       SET l.status = v_status,
           l.codigoerror = v_cod_error,
           l.msgerror = v_msj_error,
           l.ip = v_ip,
           l.request = substr(v_log,1,v_pos+1),
           l.response = substr(v_log,v_pos+2),
           l.fechaoperacion = SYSDATE,
           l.iddepositodna = v_nro_deposito_dna,
           l.idtrader = v_ruc_despachante,
           l.idbroker = v_ruc_importador,
           l.tipo = v_tipo,
           l.monto = v_monto,
           l.estado = 'F',
           l.fechaactualizacion = SYSDATE
     WHERE l.id = v_nro_secuencia;

    COMMIT;

    -- Parametro de salida
    p_monto := v_monto;

    IF v_status in  ('S','OK') AND v_cod_error IN ('0', '2') THEN
      v_retorno := '00-Transaccion Aceptada'; -- No hay error
    ELSE
      -- Busca la descripcion del error
      BEGIN
        SELECT codigo || '-' || mensaje INTO v_retorno
          FROM ge_dna_cod_error
         WHERE codigo = v_cod_error;
      EXCEPTION
        WHEN no_data_found THEN
          v_retorno := '98' || '-' || v_msj_error || ': ' || v_cod_error;
      END;
    END IF;

    RETURN v_retorno;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN '98-Error Interno: ' || SQLERRM;
  END;

  /* FUNCION QUE PROCESA EL DEPOSITO
  *  p_tipo : TDA = Pago de declaraciones, TID = Pago de IVA
  *  p_tip_operacion : R = Validar RUC, C = Deposito
  *  p_nro_caja
  *  p_nro_operacion
  *  p_ruc_importador : idBroker, solo necesita cuando tipo es TDA
  *  p_ruc_despachante : idTrader
  *  p_monto
  *  p_nom_importador
  *  p_nom_despachante
  */
  FUNCTION fu_pro_deposito(p_tipo            IN VARCHAR2,
                           p_tip_operacion   IN VARCHAR2,
                           p_nro_caja        IN VARCHAR2,
                           p_nro_operacion   IN VARCHAR2,
                           p_ruc_importador  IN VARCHAR2 DEFAULT NULL,
                           p_ruc_despachante IN VARCHAR2,
                           p_monto           IN NUMBER,
                           p_nom_importador  OUT VARCHAR2,
                           p_nom_despachante OUT VARCHAR2)
  RETURN VARCHAR2 IS
  PRAGMA AUTONOMOUS_TRANSACTION;
    v_ruc_importador  VARCHAR2(20);
    v_ruc_despachante VARCHAR2(20);
    v_retorno         VARCHAR2(500);
    v_nro_secuencia   NUMBER(10);
    v_resp            VARCHAR2(2000);
    v_ok              VARCHAR2(1);
    v_msj             VARCHAR2(500);

    v_cod_error        ge_dna_log.codigoerror%TYPE;
    v_msj_error        ge_dna_log.msgerror%TYPE;
    v_status           ge_dna_log.status%TYPE;
    v_ip               ge_dna_log.ip%TYPE;
    v_log              VARCHAR2(2000);
    v_nro_deposito     ge_dna_log.iddeposito%TYPE;
    v_nro_deposito_dna ge_dna_log.iddepositodna%TYPE;
    v_nom_despachante  ge_dna_log.tradername%TYPE;
    v_nom_importador   ge_dna_log.brokername%TYPE;
    v_deposito_dna     ge_dna_log.iddepositodna%TYPE;
  BEGIN
    -- Valida el tipo de operacion
    IF p_tipo NOT IN ('TDA', 'TID') THEN
      RETURN '98-Error Tipo de Operacion no es valido: ' || p_tipo;
    END IF;

    -- Valida el metodo a ejecutar
    IF p_tip_operacion NOT IN ('R', 'C') THEN
      RETURN '98-Error Metodo a ejecutar no es valido: ' || p_tip_operacion;
    END IF;

    -- No se va Ñ a la DNA se reemplaza por la /(barra)
    v_ruc_importador  := REPLACE(REPLACE(p_ruc_importador , 'Ñ', '\'),'-','');
    v_ruc_despachante := REPLACE(REPLACE(p_ruc_despachante, 'Ñ', '\'),'-','');

    -- Id clave a Grabar, llave del archivo
    SELECT s_dna_log.NEXTVAL INTO v_nro_secuencia FROM dual;

    -- Inserto para que el programa del Web service tome los datos
    INSERT INTO ge_dna_log
      (id, idbroker, idtrader, monto,
       tipo, fechaoperacion, fechainserccion, usuario, estado, idcajero,
       iddepositobanco, tipooperacion)
    VALUES
      (v_nro_secuencia, v_ruc_importador, v_ruc_despachante, p_monto,
       p_tipo, SYSDATE, SYSDATE, USER, 'P', p_nro_caja,
       p_nro_operacion, p_tip_operacion);

    COMMIT;

    v_deposito_dna := to_char(SYSDATE,'yy') || '007' ||
                      lpad(p_nro_caja,3,'0') || lpad(p_nro_operacion,9,'0');
    v_deposito_dna := f_obt_dv_dna(v_deposito_dna); --para agregar el DV

    -- Arma el mensaje a enviar
    IF p_tip_operacion = 'R' THEN
      v_msj := p_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               v_deposito_dna   || v_sep_envio ||
               p_nro_caja        || v_sep_envio ||
               p_ruc_despachante || v_sep_envio ||
               nvl(p_ruc_importador, '0');
    ELSIF p_tip_operacion= 'C' THEN
      v_msj := p_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               v_deposito_dna   || v_sep_envio ||
               p_nro_caja        || v_sep_envio ||
               p_ruc_despachante || v_sep_envio ||
               nvl(p_ruc_importador, '0') || v_sep_envio ||
               p_monto;
    ELSE
      RETURN '98-Error Metodo a ejecutar no es valido: ' || p_tip_operacion;
    END IF;

    --obtiene servidor y puerto
    pr_obt_datos_servidor(g_servidor,g_puerto);
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(p_servidor   => g_servidor,
                                 p_puerto     => g_puerto,
                                 p_tie_espera => g_tie_espera,
                                 p_mensaje    => v_msj,
                                 p_respuesta  => v_resp);

    IF v_ok != 'S' THEN
      -- Hubo problema en el envio
      v_resp := '01-Error de Conexión con el Socket Interno';
      RETURN v_resp;
    END IF;

    -- Recupera los datos
    DECLARE
      v_str   VARCHAR2(2000) := v_resp || v_sep_retorno;
      v_pos   NUMBER(5);
      v_valor VARCHAR2(2000);
      v_nro   NUMBER(3) := 0;
    BEGIN
      LOOP
        v_pos := instr(v_str, v_sep_retorno);
        EXIT WHEN  nvl(v_pos,0) = 0;
        v_valor := replace(replace(trim(substr(v_str, 1, v_pos - 1)),chr(13),''),chr(10),'');
        IF substr(v_valor, 1, 4) = 'null' THEN
          v_valor := NULL;
        END IF;
        v_str := substr(v_str, v_pos + 1);
        v_nro := v_nro + 1;
        -- Asgina los valores de acuerdo a la posicion
        IF v_valor IS NOT NULL THEN
          IF p_tip_operacion = 'R' THEN -- Para Validacion de RUC
            IF v_nro = 1 THEN
              v_cod_error := v_valor;
            ELSIF v_nro = 2 THEN
              v_msj_error := substr(v_valor,1,150);
            ELSIF v_nro = 3 THEN
              v_status := v_valor;
            ELSIF v_nro = 4 THEN
              v_ip := v_valor;
            ELSIF v_nro = 5 THEN
              v_log := REPLACE(v_valor, '|', chr(10));
            ELSIF v_nro = 7 THEN
              v_nom_despachante := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 8 THEN
              v_nom_importador := REPLACE(v_valor, '\', 'Ñ');
            END IF;
          ELSIF p_tip_operacion = 'C' THEN -- Para Confirmacion de Deposito
            IF v_nro = 1 THEN
              v_cod_error := v_valor;
            ELSIF v_nro = 2 THEN
              v_msj_error := substr(v_valor,1,150);
            ELSIF v_nro = 3 THEN
              v_status := v_valor;
            ELSIF v_nro = 4 THEN
              v_ip := v_valor;
            ELSIF v_nro = 5 THEN
              v_log := REPLACE(v_valor, '|', chr(10));
            ELSIF v_nro = 6 THEN
              v_nro_deposito := v_valor;
            ELSIF v_nro = 7 THEN
              v_nro_deposito_dna := v_valor;
            ELSIF v_nro = 8 THEN
              v_nom_despachante := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 9 THEN
              v_nom_importador := REPLACE(v_valor, '\', 'Ñ');
            END IF;
          END IF;
        END IF;
      END LOOP;
    END;

    -- Parametros de salida
    p_nom_importador  := v_nom_importador;
    p_nom_despachante := v_nom_despachante;

    DECLARE
      v_ret_deposito VARCHAR2(500);
      v_monto_dna    ge_dna_log.monto%type;
    BEGIN
      --Verifico si ya se registro la operación en la DNA
      IF v_cod_error = '44' THEN
        v_ret_deposito := fu_rec_deposito(v_nro_deposito, v_monto_dna);
        IF v_monto_dna = p_monto AND substr(v_ret_deposito,1,2) = '00' THEN
          v_cod_error := '00';
          v_status    := 'S';
        END IF;
      END IF;
    END;

    v_pos := instr(v_log,';}');
    -- Actualiza la tabla de log
    UPDATE ge_dna_log l
       SET l.status = v_status,
           l.codigoerror = v_cod_error,
           l.msgerror = v_msj_error,
           l.ip = v_ip,
           l.request = substr(v_log,1,v_pos+1),
           l.response = substr(v_log,v_pos+2),
           l.iddeposito = v_nro_deposito,
           l.iddepositodna = v_nro_deposito_dna,
           l.tradername = v_nom_despachante,
           l.brokername = v_nom_importador,
           l.estado = 'F',
           l.fechaactualizacion = SYSDATE
     WHERE l.id = v_nro_secuencia;

    COMMIT;

    IF  v_status in  ('S','OK') AND v_cod_error IN ('0', '2') THEN
      v_retorno := '00-Transaccion Aceptada'; -- No hay error
    ELSE
      -- Busca la descripcion del error
      BEGIN
        SELECT codigo || '-' || mensaje INTO v_retorno
          FROM ge_dna_cod_error
         WHERE codigo = v_cod_error;
      EXCEPTION
        WHEN no_data_found THEN
          v_retorno := '98' || '-' || v_msj_error || ': ' || v_cod_error;
      END;
    END IF;

    RETURN v_retorno;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN '98-Error Interno: ' || SQLERRM;
  END;

  /* FUNCION QUE PROCESA EL TICKET
  *  p_tipo : TCA = Pago de Canon Informatico
  *  p_tip_operacion : D = Datos de Ticket, T = Confirmar Ticket
  *  p_nro_caja
  *  p_nro_operacion
  *  p_nro_ticket : nro de boleta de deposito de canon informatico
  *  p_ruc_despachante
  *  p_nom_despachante
  *  p_mto_total
  *  p_mto_efectivo
  *  p_mto_cheques
  */
  FUNCTION fu_pro_ticket(p_tipo            IN VARCHAR2,
                         p_tip_operacion   IN VARCHAR2,
                         p_nro_caja        IN VARCHAR2,
                         p_nro_operacion   IN VARCHAR2,
                         p_nro_ticket      IN VARCHAR2,
                         p_ruc_despachante OUT VARCHAR2,
                         p_nom_despachante OUT VARCHAR2,
                         p_mto_total       in OUT NUMBER,
                         p_mto_efectivo    OUT NUMBER,
                         p_mto_cheques     OUT NUMBER)
  RETURN VARCHAR2 IS
  PRAGMA AUTONOMOUS_TRANSACTION;
    v_retorno       VARCHAR2(500);
    v_nro_secuencia NUMBER(10);
    v_resp          VARCHAR2(2000);
    v_ok            VARCHAR2(1);
    v_msj           VARCHAR2(500);

    v_cod_error        ge_dna_log.codigoerror%TYPE;
    v_msj_error        ge_dna_log.msgerror%TYPE;
    v_status           ge_dna_log.status%TYPE;
    v_ip               ge_dna_log.ip%TYPE;
    v_log              VARCHAR2(2000);
    v_nro_deposito     ge_dna_log.iddeposito%TYPE;
    v_nro_deposito_dna ge_dna_log.iddepositodna%TYPE;
    v_ruc_despachante  ge_dna_log.idtrader%TYPE;
    v_nom_despachante  ge_dna_log.tradername%TYPE;
    v_mto_total        ge_dna_log.monto%TYPE;
    v_mto_cheques      ge_dna_log.requestcheckamount%TYPE;
    v_mto_efectivo     ge_dna_log.requestcashamount%TYPE;
    v_deposito_dna     ge_dna_log.iddepositodna%TYPE;
    v_nro_ticket       varchar2(20);

  BEGIN
    -- Valida el tipo de operacion
  /*IF nvl(p_nro_operacion,'X') = '2915' then --Borrar
     v_retorno := '00-Transaccion Aceptada'; -- No hay error
     p_mto_total       := 280800;
     p_mto_efectivo    := 280800;
     p_mto_cheques     := 0;
     p_ruc_despachante := '8182418';
     p_nom_despachante := 'BOBADILLA GONZALEZ LUIS ALBERT';
     RETURN v_retorno;
  ELSE */--Borrar
    IF p_tipo NOT IN ('TCA') THEN
      RETURN '98-Error Tipo de Operacion no es valido: ' || p_tipo;
    END IF;

    -- Valida el metodo a ejecutar
    IF p_tip_operacion NOT IN ('D', 'T') THEN
      RETURN '98-Error Metodo a ejecutar no es valido: ' || p_tip_operacion;
    END IF;

    -- Id clave a Grabar, llave del archivo
    SELECT s_dna_log.NEXTVAL INTO v_nro_secuencia FROM dual;

    -- Inserto para que el programa del Web service tome los datos
    INSERT INTO ge_dna_log
      (id, tipo, fechaoperacion, fechainserccion, usuario, estado,
       idcajero, iddepositobanco, tipooperacion, idticket, monto)
    VALUES
      (v_nro_secuencia, p_tipo, SYSDATE, SYSDATE, USER, 'P',
       p_nro_caja, p_nro_operacion, p_tip_operacion, p_nro_ticket, p_mto_total );

    COMMIT;


    v_deposito_dna := to_char(SYSDATE,'yy') || '007' ||
                      lpad(p_nro_caja,3,'0') || lpad(p_nro_operacion,9,'0');
    v_deposito_dna := f_obt_dv_dna(v_deposito_dna); --para agregar el DV

    v_nro_ticket := p_nro_ticket;--f_obt_dv_dna(p_nro_ticket);
    -- Arma el mensaje a enviar
    IF p_tip_operacion = 'D' THEN
/*      v_msj := p_tip_operacion || v_sep_envio ||
               v_ticket_dna;*/
      v_msj := p_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               v_deposito_dna   || v_sep_envio ||
               p_nro_caja        || v_sep_envio ||
               nvl(p_ruc_despachante,'0') || v_sep_envio ||
               v_nro_ticket; -- en lugar del importador, se envia ticket
    ELSIF p_tip_operacion= 'T' THEN
/*      v_msj := p_tip_operacion || v_sep_envio ||
               p_nro_ticket    || v_sep_envio ||
               p_nro_operacion || v_sep_envio ||
               p_nro_caja;*/
      v_msj := p_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               v_deposito_dna   || v_sep_envio ||
               p_nro_caja        || v_sep_envio ||
               p_ruc_despachante || v_sep_envio ||
               v_nro_ticket; -- en lugar del importador, se envia ticket
    ELSE
      RETURN '98-Error Metodo a ejecutar no es valido: ' || p_tip_operacion;
    END IF;

    --obtiene servidor y puerto
    pr_obt_datos_servidor(g_servidor,g_puerto);
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(p_servidor   => g_servidor,
                                 p_puerto     => g_puerto,
                                 p_tie_espera => g_tie_espera,
                                 p_mensaje    => v_msj,
                                 p_respuesta  => v_resp);

    IF v_ok != 'S' THEN
      -- Hubo problema en el envio
      v_resp := '01-Error de Conexión con el Socket Interno';
      RETURN v_resp;
    END IF;

    -- Recupera los datos
    DECLARE
      v_str   VARCHAR2(2000) := v_resp || v_sep_retorno;
      v_pos   NUMBER(5);
      v_valor VARCHAR2(2000);
      v_nro   NUMBER(3) := 0;
    BEGIN
      LOOP
        v_pos := instr(v_str, v_sep_retorno);
        EXIT WHEN  nvl(v_pos,0) = 0;
        v_valor := replace(replace(trim(substr(v_str, 1, v_pos - 1)),chr(13),''),chr(10),'');
        IF substr(v_valor, 1, 4) = 'null' THEN
          v_valor := NULL;
        END IF;
        v_str := substr(v_str, v_pos + 1);
        v_nro := v_nro + 1;
        -- Asgina los valores de acuerdo a la posicion
        IF v_valor IS NOT NULL THEN
          IF p_tip_operacion = 'D' THEN -- Para Validacion de Ticket
            IF v_nro = 1 THEN
              v_cod_error := v_valor;
            ELSIF v_nro = 2 THEN
              v_msj_error := substr(v_valor,1,150);
            ELSIF v_nro = 3 THEN
              v_status := v_valor;
            ELSIF v_nro = 4 THEN
              v_ip := v_valor;
            ELSIF v_nro = 5 THEN
              v_log := replace(v_valor, '|', chr(10));
            ELSIF v_nro = 6 THEN
              v_ruc_despachante := substr(REPLACE(v_valor, '\', 'Ñ'), 0, 15);
            ELSIF v_nro = 7 THEN
              v_nom_despachante := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 8 THEN
              v_mto_total := to_number(v_valor);
            ELSIF v_nro = 9 THEN
              v_mto_cheques := to_number(v_valor);
            ELSIF v_nro = 10 THEN
              v_mto_efectivo := to_number(v_valor);
            END IF;
          ELSIF p_tip_operacion = 'T' THEN -- Para Confirmacion de Ticket
            IF v_nro = 1 THEN
              v_cod_error := v_valor;
            ELSIF v_nro = 2 THEN
              v_msj_error := substr(v_valor,1,150);
            ELSIF v_nro = 3 THEN
              v_status := v_valor;
            ELSIF v_nro = 4 THEN
              v_ip := v_valor;
            ELSIF v_nro = 5 THEN
              v_log := replace(v_valor, '|', chr(10));
            ELSIF v_nro = 6 THEN
              v_nro_deposito := v_valor;
            ELSIF v_nro = 7 THEN
              v_nro_deposito_dna := v_valor;
            ELSIF v_nro = 8 THEN
              v_ruc_despachante := substr(REPLACE(v_valor, '\', 'Ñ'), 0, 15);
            ELSIF v_nro = 9 THEN
              v_nom_despachante := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 10 THEN
              v_mto_total := to_number(v_valor);
            ELSIF v_nro = 11 THEN
              v_mto_cheques := to_number(v_valor);
            ELSIF v_nro = 12 THEN
              v_mto_efectivo := to_number(v_valor);
            END IF;
          END IF;
        END IF;
      END LOOP;
    END;

    -- Parametros de salida
    p_ruc_despachante := v_ruc_despachante;
    p_nom_despachante := v_nom_despachante;
    p_mto_total       := v_mto_total;
    p_mto_efectivo    := v_mto_efectivo;
    p_mto_cheques     := v_mto_cheques;

    DECLARE
      v_ret_deposito    VARCHAR2(500);
      --Para casos de duplicacion
      v_deposito_dna    ge_dna_log.iddeposito%type;
      v_monto_dna       ge_dna_log.monto%type;
      v_mto_operacion   ge_dna_log.monto%type;
    BEGIN
      --Verifico si ya se registro la operación en la DNA
      IF v_cod_error IN ('50','44') THEN
        v_deposito_dna := to_char(SYSDATE,'yy') || '007' ||
                          lpad(p_nro_caja,3,'0') || lpad(p_nro_operacion,9,'0');
        v_deposito_dna := f_obt_dv_dna(v_deposito_dna); --para agregar el DV

        SELECT MAX(nvl(monto, 0))
          INTO v_mto_operacion
          FROM ge_dna_log
         WHERE iddepositobanco = p_nro_operacion
           AND idcajero = p_nro_caja
           AND trunc(fechaoperacion) = trunc(SYSDATE);

        v_ret_deposito := fu_rec_deposito(v_deposito_dna,v_monto_dna);

        IF v_monto_dna = v_mto_operacion AND substr(v_ret_deposito,1,2) = '00' THEN
          v_cod_error := '00';
          v_status    := 'S';
          p_mto_total := v_monto_dna;
        END IF;
      END IF;
    END;

    v_pos := instr(v_log,';}');
    -- Actualiza la tabla de log

   lp_act_log(v_cod_error,
                                 v_msj_error,
                                 v_status,
                                 v_ip,
                                 v_nro_deposito_dna,
                                 'F',
                                 v_mto_total,
                                 v_ruc_despachante,
                                 NULL,
                                 v_nro_secuencia,
                                 substr(v_log, 1, v_pos + 1),
                                 substr(v_log, v_pos + 2),
                                 'F',
                                 null,
                                 v_nom_despachante,
                                 v_nro_deposito,
                                 v_mto_cheques,
                                 v_mto_efectivo);


    IF v_status in ('S', 'OK') AND v_cod_error IN ('0', '2') THEN
      v_retorno := '00-Transaccion Aceptada'; -- No hay error
    ELSE
      -- Busca la descripcion del error
      BEGIN
        SELECT codigo || '-' || mensaje INTO v_retorno
          FROM ge_dna_cod_error
         WHERE codigo = v_cod_error;
      EXCEPTION
        WHEN no_data_found THEN
          v_retorno := '98' || '-' || v_msj_error || ': ' || v_cod_error;
      END;
    END IF;
    RETURN v_retorno;
 -- END IF;--BORRAR
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '98-Error Interno: ' || SQLERRM;
  END;

  /* FUNCION QUE PROCESA EL TICKET DNA
  *  p_tipo : TLE = Liquidacion Expedientes
  *  p_tip_operacion : Q = Datos de Ticket, E = Confirmar Ticket
  *  p_nro_caja
  *  p_nro_operacion
  *  p_nro_ticket : nro de ticket
  *  p_ruc_agente1
  *  p_nom_agente1
  *  p_tip_agente1
  *  p_ruc_agente2
  *  p_nom_agente2
  *  p_tip_agente2
  *  p_monto
  */
  FUNCTION fu_pro_dna_ticket(p_tipo            IN VARCHAR2,
                             p_tip_operacion   IN VARCHAR2,
                             p_nro_caja        IN VARCHAR2,
                             p_nro_operacion   IN VARCHAR2,
                             p_nro_ticket      IN VARCHAR2,
                             p_ruc_agente1     OUT VARCHAR2,
                             p_nom_agente1     OUT VARCHAR2,
                             p_tip_agente1     OUT VARCHAR2,
                             p_ruc_agente2     OUT VARCHAR2,
                             p_nom_agente2     OUT VARCHAR2,
                             p_tip_agente2     OUT VARCHAR2,
                             p_monto           in OUT NUMBER)
  RETURN VARCHAR2 IS
  PRAGMA AUTONOMOUS_TRANSACTION;
    v_retorno       VARCHAR2(1000);
    v_nro_secuencia NUMBER(10);
    v_resp          VARCHAR2(2000);
    v_ok            VARCHAR2(1);
    v_msj           VARCHAR2(500);
    v_cod_error        ge_dna_log.codigoerror%TYPE;
    v_msj_error        ge_dna_log.msgerror%TYPE;
    v_status           ge_dna_log.status%TYPE;
    v_ip               ge_dna_log.ip%TYPE;
    v_log              VARCHAR2(2000);
    v_nro_deposito     ge_dna_log.iddeposito%TYPE;
    v_nro_deposito_dna ge_dna_log.iddepositodna%TYPE;
    v_ruc_agente1      ge_dna_log.idtrader%TYPE;
    v_nom_agente1      ge_dna_log.tradername%TYPE;
    v_tip_agente1      VARCHAR2(5);
    v_ruc_agente2      ge_dna_log.idbroker%TYPE;
    v_nom_agente2      ge_dna_log.brokername%TYPE;
    v_tip_agente2      VARCHAR2(5);
    v_monto            ge_dna_log.monto%TYPE;
    v_deposito_dna     ge_dna_log.iddepositodna%TYPE;
  BEGIN
    pre_cam_for_numerico('.,');
    IF p_tipo NOT IN ('TLE') THEN
      RETURN '98-Error Tipo de Operacion no es valido: ' || p_tipo;
    END IF;

    -- Valida el metodo a ejecutar
    IF p_tip_operacion NOT IN ('Q', 'E') THEN
      RETURN '98-Error Metodo a ejecutar no es valido: ' || p_tip_operacion;
    END IF;

    IF p_nro_ticket LIKE '%LMAN%' THEN
      RETURN '98-Error. Este comprobante debe ser pagdo por despacho aduanero';
    END IF;

    -- Id clave a Grabar, llave del archivo
    SELECT s_dna_log.NEXTVAL INTO v_nro_secuencia FROM dual;

    -- Inserto para que el programa del Web service tome los datos
    INSERT INTO ge_dna_log
      (id, tipo, fechaoperacion, fechainserccion, usuario, estado,
       idcajero, iddepositobanco, tipooperacion, idticket, monto)
    VALUES
      (v_nro_secuencia, p_tipo, SYSDATE, SYSDATE, USER, 'P',
       p_nro_caja, p_nro_operacion, p_tip_operacion, p_nro_ticket, p_monto);

    COMMIT;

    v_deposito_dna := to_char(SYSDATE,'yy') || '007' ||
                      lpad(p_nro_caja,3,'0') || lpad(p_nro_operacion,9,'0');
    v_deposito_dna := f_obt_dv_dna(v_deposito_dna); --para agregar el DV

    -- Arma el mensaje a enviar
    IF p_tip_operacion = 'Q' THEN
/*      v_msj := p_tip_operacion || v_sep_envio ||
               v_ticket_dna;*/
      v_msj := p_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               v_deposito_dna   || v_sep_envio ||
               p_nro_caja        || v_sep_envio ||
               nvl(NULL,'0') || v_sep_envio ||
               p_nro_ticket; -- en lugar del importador, se envia ticket
    ELSIF p_tip_operacion= 'E' THEN
/*      v_msj := p_tip_operacion || v_sep_envio ||
               p_nro_ticket    || v_sep_envio ||
               p_nro_operacion || v_sep_envio ||
               p_nro_caja;*/
      v_msj := p_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               v_deposito_dna   || v_sep_envio ||
               p_nro_caja        || v_sep_envio ||
               '0' || v_sep_envio || -- DESPACHANTE
               p_nro_ticket; -- en lugar del importador, se envia ticket
    ELSE
      RETURN '98-Error Metodo a ejecutar no es valido: ' || p_tip_operacion;
    END IF;

/*    -- Arma el mensaje a enviar
    IF p_tip_operacion = 'Q' THEN
      v_msj := p_tip_operacion || v_sep_envio ||
               p_nro_ticket;
    ELSIF p_tip_operacion= 'E' THEN
      v_msj := p_tip_operacion || v_sep_envio ||
               p_nro_ticket    || v_sep_envio ||
               p_nro_operacion || v_sep_envio ||
               p_nro_caja;
    ELSE
      RETURN '98-Error Metodo a ejecutar no es valido: ' || p_tip_operacion;
    END IF;*/

    --obtiene servidor y puerto
    pr_obt_datos_servidor(g_servidor,g_puerto);
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(p_servidor   => g_servidor,
                                 p_puerto     => g_puerto,
                                 p_tie_espera => g_tie_espera,
                                 p_mensaje    => v_msj,
                                 p_respuesta  => v_resp);


    IF v_ok != 'S' THEN
      -- Hubo problema en el envio
      v_resp := '01-Error de Conexión con el Socket Interno';
      RETURN v_resp;
    END IF;

    -- Recupera los datos
    DECLARE
      v_str   VARCHAR2(2000);
      v_pos   NUMBER(5);
      v_valor VARCHAR2(2000);
      v_nro   NUMBER(3) := 0;
    BEGIN
      v_str := substr(v_resp, 1, length(v_resp) - 1) || v_sep_retorno; -- quita el enter final
      LOOP
        v_pos := instr(v_str, v_sep_retorno);
        EXIT WHEN  nvl(v_pos,0) = 0;
        v_valor := replace(replace(trim(substr(v_str, 1, v_pos - 1)),chr(13),''),chr(10),'');
        IF substr(v_valor, 1, 4) = 'null' THEN
          v_valor := NULL;
        END IF;
        v_str := substr(v_str, v_pos + 1);
        v_nro := v_nro + 1;
        -- Asgina los valores de acuerdo a la posicion
        IF v_valor IS NOT NULL THEN
          IF p_tip_operacion = 'Q' THEN -- Para Validacion de Ticket
            IF v_nro = 1 THEN
              v_cod_error := v_valor;
            ELSIF v_nro = 2 THEN
              v_msj_error := substr(v_valor,1,150);
            ELSIF v_nro = 3 THEN
              v_status := v_valor;
            ELSIF v_nro = 4 THEN
              v_ip := v_valor;
            ELSIF v_nro = 5 THEN
              v_log := replace(v_valor, '|', chr(10));
            ELSIF v_nro = 6 THEN
              v_ruc_agente1 := substr(REPLACE(v_valor, '\', 'Ñ'),0,15);
            ELSIF v_nro = 7 THEN
              v_nom_agente1 := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 8 THEN
              v_tip_agente1 := TRIM(v_valor);
            ELSIF v_nro = 9 THEN
              v_ruc_agente2 := substr(REPLACE(v_valor, '\', 'Ñ'),0,15);
            ELSIF v_nro = 10 THEN
              v_nom_agente2 := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 11 THEN
              v_tip_agente2 := TRIM(v_valor);
            ELSIF v_nro = 12 THEN
              v_monto := to_number(trim(v_valor));
            END IF;
          ELSIF p_tip_operacion = 'E' THEN
            -- Para Confirmacion de Ticket
            IF v_nro = 1 THEN
              v_cod_error := v_valor;
            ELSIF v_nro = 2 THEN
              v_msj_error := substr(v_valor, 1, 150);
            ELSIF v_nro = 3 THEN
              v_status := v_valor;
            ELSIF v_nro = 4 THEN
              v_ip := v_valor;
            ELSIF v_nro = 5 THEN
              v_log := replace(v_valor, '|', chr(10));
            ELSIF v_nro = 6 THEN
              v_nro_deposito := v_valor;
            ELSIF v_nro = 7 THEN
              v_nro_deposito_dna := v_valor;
            ELSIF v_nro = 8 THEN
              v_ruc_agente1 := substr(REPLACE(v_valor, '\', 'Ñ'),0,15);
            ELSIF v_nro = 9 THEN
              v_nom_agente1 := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 10 THEN
              v_tip_agente1 := TRIM(v_valor);
            ELSIF v_nro = 11 THEN
              v_ruc_agente2 :=substr(REPLACE(v_valor, '\', 'Ñ'),0,15);
            ELSIF v_nro = 12 THEN
              v_nom_agente2 := REPLACE(v_valor, '\', 'Ñ');
            ELSIF v_nro = 13 THEN
              v_tip_agente2 := TRIM(v_valor);
            ELSIF v_nro = 14 THEN
              v_monto := to_number(trim(v_valor));
            END IF;
          END IF;
        END IF;
      END LOOP;
    END;

    -- Parametros de salida
    p_ruc_agente1 := v_ruc_agente1;
    p_nom_agente1 := v_nom_agente1;
    p_tip_agente1 := v_tip_agente1;
    p_ruc_agente2 := v_ruc_agente2;
    p_nom_agente2 := v_nom_agente2;
    p_tip_agente2 := v_tip_agente2;
    p_monto       := v_monto;

/*
    DECLARE
      v_ret_deposito    VARCHAR2(500);
      --Para casos de duplicacion
      v_deposito_dna    ge_dna_log.iddeposito%type;
      v_monto_dna       ge_dna_log.monto%type;
      v_mto_operacion   ge_dna_log.monto%type;
    BEGIN
      --Verifico si ya se registro la operación en la DNA
      IF v_cod_error IN ('50','44') THEN
        v_deposito_dna := to_char(SYSDATE,'yy') || '007' ||
                          lpad(p_nro_caja,3,'0') || lpad(p_nro_operacion,9,'0');
        v_deposito_dna := f_obt_dv_dna(v_deposito_dna); --para agregar el DV

        SELECT MAX(nvl(monto, 0))
          INTO v_mto_operacion
          FROM ge_dna_log
         WHERE iddepositobanco = p_nro_operacion
           AND idcajero = p_nro_caja
           AND trunc(fechaoperacion) = trunc(SYSDATE);

        v_ret_deposito := fu_rec_deposito(v_deposito_dna,v_monto_dna);

        IF v_monto_dna = v_mto_operacion AND substr(v_ret_deposito,1,2) = '00' THEN
          v_cod_error := '00';
          v_status    := 'S';
          p_monto := v_monto_dna;
        END IF;
      END IF;
    END;
*/
    DECLARE
      v_ruc_despachante ge_dna_log.idtrader%TYPE;
      v_nom_despachante ge_dna_log.tradername%TYPE;
      v_ruc_importador  ge_dna_log.idbroker%TYPE;
      v_nom_importador  ge_dna_log.brokername%TYPE;
    BEGIN
      IF v_tip_agente1 = 'DESP' THEN
        v_ruc_despachante := v_ruc_agente1;
        v_nom_despachante := v_nom_agente1;
      ELSIF v_tip_agente1 = 'IPR' THEN
        v_ruc_importador := v_ruc_agente1;
        v_nom_importador := v_nom_agente1;
      END IF;
      IF v_tip_agente2 = 'DESP' THEN
        v_ruc_despachante := v_ruc_agente2;
        v_nom_despachante := v_nom_agente2;
      ELSIF v_tip_agente2 = 'IPR' THEN
        v_ruc_importador := v_ruc_agente2;
        v_nom_importador := v_nom_agente2;
      END IF;

      v_pos := instr(v_log,';}');
      -- Actualiza la tabla de log

      lp_act_log(v_cod_error,
                                   v_msj_error,
                                   v_status,
                                   v_ip,
                                   v_nro_deposito_dna,
                                   p_tip_operacion,
                                   null,
                                   v_ruc_despachante,
                                   v_ruc_importador,
                                   v_nro_secuencia,
                                   substr(v_log, 1, v_pos + 1),
                                   substr(v_log, v_pos + 2),
                                   'F',
                                   v_nom_importador,
                                   v_nom_despachante,
                                   v_nro_deposito,
                                   null,
                                   null);
    END;

    COMMIT;

    IF  v_status in  ('S','OK') AND v_cod_error IN ('0', '2') THEN
      v_retorno := '00-Transaccion Aceptada'; -- No hay error
    ELSE
      -- Busca la descripcion del error
      BEGIN
        SELECT codigo || '-' || mensaje INTO v_retorno
          FROM ge_dna_cod_error
         WHERE codigo = v_cod_error;
      EXCEPTION
        WHEN no_data_found THEN
          v_retorno := '98' || '-' || v_msj_error || ': ' || v_cod_error;
      END;
    END IF;

    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '98-Error Interno: ' || SQLERRM;
  END;

  /* FUNCION QUE PROCESA EL TICKET DNA
  *  p_tipo : TLE = Liquidacion Expedientes
  *  p_tip_operacion : Q = Datos de Ticket, E = Confirmar Ticket
  *  p_nro_caja
  *  p_nro_operacion
  *  p_nro_ticket : nro de ticket
  *  p_ruc_agente
  *  p_nom_agente
  *  p_monto
  */
  FUNCTION fu_pro_dna_ticket(p_tipo            IN VARCHAR2,
                             p_tip_operacion   IN VARCHAR2,
                             p_nro_caja        IN VARCHAR2,
                             p_nro_operacion   IN VARCHAR2,
                             p_nro_ticket      IN VARCHAR2,
                             p_ruc_agente      OUT VARCHAR2,
                             p_nom_agente      OUT VARCHAR2,
                             p_tip_agente      OUT VARCHAR2,
                             p_monto           in OUT NUMBER)
  RETURN VARCHAR2 IS
    v_retorno     VARCHAR2(1000);
    v_tip_agente2 VARCHAR2(5);
    v_ruc_agente2 VARCHAR2(50);
    v_nom_agente2 VARCHAR2(200);
  BEGIN
    v_retorno := fu_pro_dna_ticket(p_tipo,
                                   p_tip_operacion,
                                   p_nro_caja,
                                   p_nro_operacion,
                                   p_nro_ticket,
                                   p_ruc_agente,
                                   p_nom_agente,
                                   p_tip_agente,
                                   v_ruc_agente2,
                                   v_nom_agente2,
                                   v_tip_agente2,
                                   p_monto);
    RETURN v_retorno;
  END;

  /* FUNCION QUE RECUPERA LOS DATOS DEL DEPOSITO DE LA ADUANA POR RANGO DE FECHA
  *  p_fec_desde : fecha desde
  *  p_fec_hasta : fecha hasta
  */
  FUNCTION fu_rec_dep_rango(p_fec_desde IN DATE,
                            p_fec_hasta IN DATE)
  RETURN VARCHAR2 IS
  PRAGMA AUTONOMOUS_TRANSACTION;
    v_resp VARCHAR2(20000);
    v_ok   VARCHAR2(1);
    v_msj  VARCHAR2(500);
  BEGIN
    -- Arma el mensaje a enviar
    v_msj := 'F' || v_sep_envio || to_char(p_fec_desde, 'yyyymmddhh24miss') || v_sep_envio
                                || to_char(p_fec_hasta, 'yyyymmddhh24miss');

    --obtiene servidor y puerto
    pr_obt_datos_servidor(g_servidor,g_puerto);
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(p_servidor   => g_servidor,
                                 p_puerto     => g_puerto,
                                 p_tie_espera => g_tie_espera,
                                 p_mensaje    => v_msj,
                                 p_respuesta  => v_resp);

    IF v_ok != 'S' THEN
      -- Hubo problema en el envio
      v_resp := '01-Error de Conexión con el Socket Interno';
      RETURN v_resp;
    END IF;

    RETURN v_resp;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN '98-Error Interno: ' || SQLERRM;
  END;

  /* PROCEDIMIENTO PARA ENVIO DE UN EXTRACTO DE CUENTA O ANULACION DE EXTRACTO A LA DNA
  *  p_nro_cuenta: cuenta a informar
  *  p_fecha: Fecha del extracto
  *  p_tip_operacion: X=Enviar Extracto A=anular extracto
  */
  PROCEDURE pr_pro_extracto(p_nro_cuenta     IN VARCHAR2,
                            p_fecha          IN DATE,
                            p_tip_operacion   IN VARCHAR2) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
    v_tipo            VARCHAR2(3) := 'EXT';
    v_retorno         VARCHAR2(500);
    v_nro_secuencia   NUMBER(10);
    v_resp            VARCHAR2(2000);
    v_ok              VARCHAR2(1);
    v_msj             LONG;

    v_cod_error        ge_dna_log.codigoerror%TYPE;
    v_msj_error        ge_dna_log.msgerror%TYPE;
    v_status           ge_dna_log.status%TYPE := 'S';
    v_ip               ge_dna_log.ip%TYPE;
    v_log              VARCHAR2(2000);
    -- datos a enviar
    v_sal_anterior     number(18,2) := 0;
    v_sal_actual       number(18,2) := 0;
    v_detalles         LONG := '';
    v_can_movimientos  number(9) := 0;
    v_concepto         varchar2(10);
    v_mto_debito       number(18,2) := 0;
    v_mto_credito      number(18,2) := 0;
    -- cursor de datos de extractos
    CURSOR movimientos IS
               SELECT  '' || '#' || -- idliquidacion
                       TO_CHAR(fecha,'YYYYMMDD')||REPLACE(hora,':','') || '#' || -- FechaTransaccion
                       (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                        ge_transacciones.tipo,
                                        ge_transacciones.afecta),
                                        'C',
                                        NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0)) || '#' || -- MontoCredito
                       (DECODE(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                        ge_transacciones.tipo,
                                        ge_transacciones.afecta),
                                        'D',
                                        NVL(CC_MOVIMIENTOS_HIS.MONTO,0),0)) || '#' || -- MontoDebito
                       '' || '#' || -- idTransBandna
                       '' || '#' || -- idTransBanco
                       ''  datos, -- Observacion
                       decode(REVERSADO,'S','REV',
                              decode(cc_movimientos_his.cod_tra_padre,309,'TRAN',303,'TRAN',--Ajuste-sipap 28/11/2013
                              decode(fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                                      ge_transacciones.tipo,
                                                      ge_transacciones.afecta),
                                                      'C','CRE','D','DEB'))) concepto,
                       case 
                       when cc_movimientos_his.cod_tra_padre = 309 then
                            pag_dna.fu_obt_cta_destino(cc_movimientos_his.fecha,
                                                  cc_movimientos_his.cod_usuario,
                                                  cc_movimientos_his.hora,
                                                  cc_movimientos_his.cod_tra_padre,
                                                  cc_movimientos_his.cod_transaccion)  
                       when cc_movimientos_his.cod_tra_padre = 303 then   --Ajuste-sipap 28/11/2013
                            cc_movimientos_his.concepto                     
                       else null end cuentaDestino,                         
                       CC_MOVIMIENTOS_HIS.fec_insercion fecha,
                       fug_obt_tra_tipo(ge_transacciones.cod_transaccion,
                                        ge_transacciones.tipo,
                                        ge_transacciones.afecta) tipo,
                        CC_MOVIMIENTOS_HIS.monto monto,
                        reversado
                   FROM GE_TRANSACCIONES, CC_MOVIMIENTOS_HIS
               WHERE CC_MOVIMIENTOS_HIS.NRO_CUENTA = p_nro_cuenta
                 AND CC_MOVIMIENTOS_HIS.FECHA = p_fecha
                 AND (CC_MOVIMIENTOS_HIS.REVERSADO = 'N' OR (CC_MOVIMIENTOS_HIS.REVERSADO = 'S' AND CC_MOVIMIENTOS_HIS.FECHA <> CC_MOVIMIENTOS_HIS.FEC_VALOR))--se arregla la lógica de reversados
                 AND CC_MOVIMIENTOS_HIS.ESTADO = 'N'
                 AND CC_MOVIMIENTOS_HIS.COD_MODULO = GE_TRANSACCIONES.COD_MODULO
                 AND CC_MOVIMIENTOS_HIS.COD_MODALIDAD = GE_TRANSACCIONES.COD_MODALIDAD
                 AND CC_MOVIMIENTOS_HIS.COD_TRANSACCION = GE_TRANSACCIONES.COD_TRANSACCION
                 AND GE_TRANSACCIONES.VE_CLIENTE = 'S'
                 AND GE_TRANSACCIONES.TIPO IN ('C','D')
                 AND cod_tra_padre not in (219,220,222,226) -- se genera en el query
                 AND (NVL(GE_TRANSACCIONES.AFECTA,'XX') = 'B'
                     AND CC_MOVIMIENTOS_HIS.COD_CAUSA IN
                           (select cod_causa
                              from ge_par_causales
                             where parametro = 'COD_CAU_BLO_EXT'
                               and val_parametro = 'S' )
                     OR NVL(GE_TRANSACCIONES.AFECTA,'XX') != 'B' )
           UNION ALL
              SELECT  IDTICKET || '#' || -- idliquidacion
                      SUBSTR(REQUEST,11,14) || '#' || -- FechaTransaccion
                      x.MONTO || '#' || -- MontoCredito
                      '0' || '#' || -- MontoDebito
                      IDDEPOSITODNA || '#' || -- idTransBandna
                      IDDEPOSITO || '#' || -- idTransBanco
                      ''  datos, -- Observacion
                      DECODE(TIPO,'TLE','LIQ','TCA','LIQ',TIPO) concepto,
                      '' cuentaDestino,
                      a.fec_insercion fecha,
                      'C' tipo,
                      x.monto monto,
                      a.reversado
              from  ge_dna_log x, cc_movimientos_his a
              where status in ('S')
              AND   codigoerror = 0
              and   x.tipo = decode(a.cod_tra_padre,226,'TLE',222,'TCA',219,'TDA',220,'TID')
              and   tipooperacion in ('E','T','C')
              and   a.nro_cuenta = p_nro_cuenta
              and   a.fecha = p_fecha
              and   a.cod_tra_padre in (219,220,222,226)
              and   a.estado = 'N'
              and   a.reversado = 'N'
              and   x.monto = a.monto
              and   x.iddepositobanco = nro_documento
              and   trunc(x.fechainserccion) = trunc(a.fec_insercion)
              and   x.usuario = a.cod_usuario
          order by 2;



  BEGIN
    --Limpiamos la tabla temporal
    delete from GE_EXT_DNA_DET_TMP;
 
    -- Valida el metodo a ejecutar
    IF p_tip_operacion NOT IN ('X', 'A') THEN
      raise_application_error(-20001, 'Error Metodo a ejecutar no es valido: ' || p_tip_operacion);
    END IF;

    -- Id clave a Grabar, llave del archivo
    SELECT s_dna_log.NEXTVAL INTO v_nro_secuencia FROM dual;

    -- Inserto para que el programa del Web service tome los datos
    INSERT INTO ge_dna_log
      (tipo,id, nro_cuenta, fechaoperacion, fechainserccion, usuario, estado,tipooperacion)
    VALUES
      ('EXT',v_nro_secuencia, p_nro_cuenta,  p_fecha, SYSDATE, USER, 'P',p_tip_operacion);
    COMMIT;

    -- Arma el mensaje a enviar
    IF p_tip_operacion = 'A' THEN  -- ANULAR UN EXTRACTO
      v_msj := v_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               p_nro_cuenta      || v_sep_envio ||
               to_char(p_fecha,'YYYYMMDD');
    ELSIF p_tip_operacion= 'X' THEN -- ENVIAR UN EXTRATO
      v_detalles :='';
      v_can_movimientos := 0;

     BEGIN
      select nvl(sal_tot_cap,0) - nvl(sal_ret_ade,0) sal_Actual
        into v_sal_actual
        from ge_sal_diarios --cc_cta_corrientes
       where nro_cuenta = p_nro_cuenta
         and fecha = p_fecha;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            -- OMM 02/11/2010 Para enviar Sabado y Domingo
            select nvl(sal_tot_cap,0) - nvl(sal_ret_ade,0) sal_Actual
              into v_sal_actual
              from ge_sal_diarios --cc_cta_corrientes
             where nro_cuenta = p_nro_cuenta
               and fecha = (Select max(fecha)
                            from ge_sal_diarios
                            where nro_cuenta = p_nro_cuenta
                             and fecha < p_fecha);
      END;

      IF v_sal_actual is null then
          raise_application_error(-20000,'Saldo de la Cuenta '||p_nro_Cuenta||' no se encuentra en ge_Sal_diarios para el '||p_fecha);
              end if;
           v_sal_anterior := v_sal_actual;

       FOR dt in MOVIMIENTOS LOOP
              v_concepto := dt.concepto;
              if v_concepto = 'TRAN' and dt.cuentaDestino is null then
                 if dt.REVERSADO='S' then
                    v_concepto := 'REV';
                 elsif dt.tipo = 'D' then
                    v_concepto := 'DEB';
                 else
                    v_concepto := 'CRE';
                 end if;
              end if;
              v_detalles := v_detalles || dt.datos ||'#'||v_concepto||'#'||dt.cuentaDestino||'~';
              v_can_movimientos := v_can_movimientos + 1;
              v_mto_credito := 0;
              v_mto_debito := 0;
              if dt.tipo = 'C' then
                 v_sal_anterior := nvl(v_sal_anterior,0) - nvl(dt.monto,0);
                 v_mto_credito := nvl(dt.monto,0);
              else
                 v_sal_anterior := nvl(v_sal_anterior,0) + nvl(dt.monto,0);
                  v_mto_debito := nvl(dt.monto,0);
              end if;
        begin
        ---se inserta en la tabla temporal los datos que envia en el extracto
        insert into GE_EXT_DNA_DET_TMP
          (fecha,
          tipo,
          monto,
          datos,
          concepto,
          cuentaDestino,
          reversado,
          mto_debito,
          mto_credito
           )
        values
          (dt.fecha,
          dt.tipo,
          dt.monto,
          dt.datos,
          v_concepto,
          dt.cuentaDestino,
          dt.reversado,
          v_mto_debito,
          v_mto_credito
           );
      exception
        when others then
          raise_application_error(-20006, sqlerrm);
      end;
              
        END LOOP;

      v_detalles := substr(v_detalles,1,length(v_detalles)-1);
      v_msj := v_tipo            || v_sep_envio ||
               p_tip_operacion   || v_sep_envio ||
               p_nro_cuenta      || v_sep_envio ||
               to_char(p_fecha,'YYYYMMDD') || v_sep_envio ||
               v_sal_anterior || v_sep_envio ||
               v_sal_actual   || v_sep_envio ||
               trim(lpad(v_can_movimientos,5,'0')) ||
               v_detalles;
    ELSE
      raise_application_error(-20001,'Error Metodo a ejecutar no es valido: ' || p_tip_operacion);
    END IF;
     
    -- raise_application_error(-20001,'P: '||v_msj); -- solo para pruebas
    
    --obtiene servidor y puerto
    pr_obt_datos_servidor(g_servidor,g_puerto);    
    -- Envia el mensaje al servidor
    v_ok := fue_env_tcp_mensajes(p_servidor   => g_servidor,
                                 p_puerto     => g_puerto,
                                 p_tie_espera => g_tie_espera,
                                 p_mensaje    => v_msj,
                                 p_respuesta  => v_resp);

    IF v_ok != 'S' THEN
      -- Hubo problema en el envio
      raise_application_error(-20002,v_resp);
    END IF;

    -- Recupera los datos
    DECLARE
      v_str   VARCHAR2(2000) := v_resp || v_sep_retorno;
      v_pos   NUMBER(5);
      v_valor VARCHAR2(2000);
      v_nro   NUMBER(3) := 0;
    BEGIN
      LOOP
        v_pos := instr(v_str, v_sep_retorno);
        EXIT WHEN  nvl(v_pos,0) = 0;
        v_valor := replace(replace(trim(substr(v_str, 1, v_pos - 1)),chr(13),''),chr(10),'');
        IF substr(v_valor, 1, 4) = 'null' THEN
          v_valor := NULL;
        END IF;
        v_str := substr(v_str, v_pos + 1);
        v_nro := v_nro + 1;
        -- Asgina los valores de acuerdo a la posicion
        IF v_valor IS NOT NULL THEN
            IF v_nro = 1 THEN
              v_cod_error := v_valor;
            ELSIF v_nro = 2 THEN
              v_msj_error := substr(v_valor,1,150);
            ELSIF v_nro = 3 THEN
              v_ip := v_valor;
            ELSIF v_nro = 4 THEN
              v_log := REPLACE(v_valor, '|', chr(10));
            END IF;
        END IF;
      END LOOP;
    END;

    v_pos := instr(v_log,';}');
    -- Actualiza la tabla de log
    UPDATE ge_dna_log l
       SET l.codigoerror = v_cod_error,
           l.msgerror = v_msj_error,
           l.ip = v_ip,
           l.request = substr(v_log,1,v_pos+1),
           l.response = substr(v_log,v_pos+2),
           l.estado = 'F',
           l.fechaactualizacion = SYSDATE
     WHERE l.id = v_nro_secuencia;

    COMMIT;

    IF v_cod_error NOT IN ('0') THEN
       v_retorno := '98' || '-' || v_msj_error || ': ' || v_cod_error;
       raise_application_error(-20006,v_retorno);
    END IF;

 EXCEPTION
    WHEN OTHERS THEN
     v_msj := SQLERRM;
     v_pos := INSTR(v_msj,'ORA-',1,2);
     if v_pos > 20 then
        raise_application_error(-20006,substr(v_msj,1,v_pos-1));
     else
        raise_application_error(-20006,v_msj);
     end if;
/*     IF sqlcode <= -20000 THEN
       raise;
     ELSE
       raise_application_error(-20006,'Error Interno: ' || SQLERRM);
     END IF;*/


  END;
   /* PROCEDIMIENTO PARA ENVIO DE EXTRACTOS A LA DNA AL CIERRE
  *
  */

  PROCEDURE pr_pro_extracto
    IS
   v_cant_dias   NUMBER(2) := 0 ;
   v_fecha       date;
   v_cta_ext_dna ge_cuentas.nro_cuenta%type := fug_obt_pardinamico('NRO_CTA_EXT_DNA');
   v_nro_cuenta  ge_cuentas.nro_cuenta%type;
  BEGIN 
        --verificamos si la cuenta configurada es válida
         begin
             select a.nro_cuenta
                into v_nro_cuenta
                     from ge_cuentas a
                     where a.nro_cuenta = v_cta_ext_dna;
             exception
               when no_data_found then
                 raise_application_error(-20000,'No se encuentra dato para la cuenta '||v_cta_ext_dna||'. Verificar el parámetro NRO_CTA_EXT_DNA');
         end;  
          -- ENVIO EL EXTRACTO DE LA FECHA DE LA CUENTA DEL DNA------------------
          -- OMM 02/11/2010 Se modifico para enviar extracto del Sabado y Domingo
          IF pag_cal.FU_OBT_FEC_ANTERIOR(1) + 1 = pag_cal.FU_OBT_FEC_ACTUAL(1) then
          pag_dna.pr_pro_extracto(v_cta_ext_dna,pag_cal.FU_OBT_FEC_ACTUAL(1),'X');
          ELSE
              v_cant_dias := pag_cal.FU_OBT_FEC_ACTUAL(1) - pag_cal.FU_OBT_FEC_ANTERIOR(1) ;
          FOR i IN 1 .. v_cant_dias LOOP
             v_fecha := pag_cal.FU_OBT_FEC_ANTERIOR(1) + i ;
             pag_dna.pr_pro_extracto(v_cta_ext_dna,v_fecha,'X');
          END LOOP;
           END IF ;
  END;

  /* Retorna el Nro de cuenta destino en transferencias */
  FUNCTION fu_obt_cta_destino(p_fecha in date,
                              p_cod_usuario in varchar2,
                              p_hora in varchar2,
                              p_cod_tra_padre in number,
                              p_cod_transaccion in number)
    RETURN varchar2 is
   v_cta_destino varchar2(20);
   v_concepto varchar2(100);
   BEGIN
      begin   -- cuando se ejecuta de test usa ge
          select nro_cuenta, concepto
            into v_cta_destino, v_concepto
            from ge_movimientos
           where fecha = p_fecha
             and cod_usuario = p_cod_usuario
             and hora = p_hora
             and cod_tra_padre = p_cod_tra_padre
             and nro_secuencia in (1,2)
             and cod_transaccion = decode(p_cod_transaccion,602,503,196,503,602);
      exception
        when no_data_found then  -- cuando se ejecuta de post cierre prd usa gv
          select nro_cuenta, concepto
            into v_cta_destino, v_concepto
            from gv_movimientos
           where fecha = p_fecha
             and cod_usuario = p_cod_usuario
             and hora = p_hora
             and cod_tra_padre = p_cod_tra_padre
             and nro_secuencia in (1,2)
             and cod_transaccion = decode(p_cod_transaccion,602,503,196,503,602);
      end;
      if v_cta_destino = '1101700052' then
         v_cta_destino := '007-'||v_cta_destino;  -- CUENTA INTERNA DEL BBVA
      elsif fue_val_es_numerico(replace(trim(v_concepto),'-',''))='S' then
         v_cta_destino := trim(v_concepto);
      else
         v_cta_destino := null;
      end if;
      return v_cta_destino;
   EXCEPTION
      WHEN OTHERS THEN
          return null;
   END;
END PAG_DNA;
/

