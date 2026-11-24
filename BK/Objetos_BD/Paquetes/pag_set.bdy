CREATE OR REPLACE PACKAGE BODY IT.PAG_SET IS
  --
  g_url_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_SOCK'));  
  g_url_ots        ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_OT'));
  g_url_ots_update ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GTW_UPDATE_OT'));
  g_api_gateway    ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GATEWAY_API'));
  g_hor_inicio     ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('HOB_HOR_SET_INI_PAG'));
  g_hor_cierre     ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('HOB_HOR_SET_CIE_PAG'));
  g_url_ot_set     ge_par_dinamicos.val_parametro%TYPE := trim(fug_obt_pardinamico('SET_GTW_RESET_OT'));

  PROCEDURE LP_REG_OPERACION(p_mensaje IN LONG, p_respuesta IN VARCHAR2) is
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
      raise_application_error(-20000, sqlerrm);
  END;

  FUNCTION fu_obt_cod_cuenta(p_cod_impuesto IN ge_set_impuestos.cod_impuesto%TYPE)
    RETURN VARCHAR2 IS
    v_retorno ge_set_impuestos.cod_cuenta%TYPE;
  BEGIN
    SELECT gi.cod_cuenta
      INTO v_retorno
      FROM ge_set_impuestos gi
     WHERE gi.cod_impuesto = TRIM(p_cod_impuesto);
    RETURN v_retorno;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  /*<SET>
     <Pago era="7" tipoInformacion="2" sucursalEra="7" cajero="999" consecutivo="1" formulario="97" version="1" fechaDocumento="04/09/2014" impuesto="0" hash="">
        <numeroOt>700000001</numeroOt>
        <numeroDocumento>84000000057</numeroDocumento>
        <numeroDocumentoPagar></numeroDocumentoPagar>
        <ruc>12345678</ruc>
        <dv>0</dv>
        <valorPagado>240000</valorPagado>
        <periodo></periodo>
     </Pago>
     <Respuesta>
        <Era>7</Era>
        <NumeroDocumento>97000018679</NumeroDocumento>
        <FechaRecepcion>12/02/2008 15:18</FechaRecepcion>
        <Estado>ACEPTADO</Estado>
        <Pagos>
           <Pago>
              <Identificador>25326914</Identificador>
              <Impuesto>311</Impuesto>
              <DescripcionImpuesto>IKP . SELECTIVO AL CONSUNO???GENERAL</DescripcionImpuesto>
              <ValorPagado>240000</ValorPagado>
           <Estado>Aceptado</Estado>
           </Pago>
        </Pagos>
        <Errores />
     </Respuesta>
  </SET>
     */
  PROCEDURE pr_act_estado(p_ruc           IN VARCHAR2,
                          p_nro_boleta    IN VARCHAR2,
                          p_fec_documento IN DATE,
                          p_estado        IN VARCHAR2,
                          p_xml           IN xmltype,
                          p_can_reintento IN NUMBER DEFAULT 0) IS
    v_cod_set       ge_set_pagos.cod_set%TYPE := NULL;
    v_cod_mensaje   ge_set_pagos.cod_error%TYPE := NULL;
    v_msj_error     ge_set_pagos.msg_error%TYPE := NULL;
    v_estado        ge_set_pagos.estado%TYPE := p_estado;
    v_ruc           ge_set_pagos.ruc%TYPE := p_ruc;
    v_nro_boleta    ge_set_pagos.nro_boleta%TYPE := p_nro_boleta;
    v_fec_documento ge_set_pagos.fec_pago%TYPE := p_fec_documento;
    v_numero_ot     ge_set_pagos.nro_orden%TYPE;
    v_consecutivo   ge_set_pagos.nro_consecutivo%TYPE;
    v_cod_token     ge_set_pagos.cod_token%TYPE;
    v_est_respuesta ge_set_pagos.est_respuesta%TYPE;
    v_nro_cuenta    ge_set_pagos.nro_cta_debito%TYPE;
    v_nro_operacion ge_set_pagos.nro_operacion%TYPE;
    v_monto         ge_set_pagos.monto%TYPE;
    v_dir_correo    ba_mails.dir_correo%TYPE;
    v_number        NUMBER;
    v_db_name       VARCHAR2(20);
    v_ult_reintento NUMBER := 0;
    v_texto         VARCHAR2(2000);
    v_titulo        VARCHAR2(1000);
    v_cabecera   VARCHAR2(2000)  := NULL;
    v_detalle    VARCHAR2(3300) := NULL;
    v_pie        VARCHAR2(500)  := NULL;
    v_tag        VARCHAR2(50);
    v_nombre     VARCHAR2(100);
  BEGIN
    IF v_ruc IS NULL THEN
      v_ruc := substr(p_xml.extract('/SET/Pago/ruc/text()').getStringVal(), 1, 10);
    END IF;
  
    IF v_nro_boleta IS NULL THEN
      v_nro_boleta := p_xml.extract('/SET/Pago/numeroDocumento/text()').getNumberVal();
    END IF;
  
    IF v_fec_documento IS NULL THEN
      v_fec_documento := to_date(p_xml.extract('/SET/Pago/@fechaDocumento').getStringVal(), 'dd/mm/yyyy');
    END IF;
  
    IF p_xml.extract('/SET/Respuesta/Errores/Errores/TipoError/text()') IS NOT NULL THEN
      v_cod_set := substr(p_xml.extract('/SET/Respuesta/Errores/Errores/TipoError/text()').getStringVal(), 1, 10);      
    END IF;
    
    v_est_respuesta := UPPER(TRIM(substr(p_xml.extract('/SET/Respuesta/Estado/text()').getStringVal(), 1, 30)));
    
    IF v_est_respuesta <> 'ACEPTADO' THEN
       v_estado  := 'E';
       IF v_est_respuesta = 'TIMEOUT' THEN
          v_texto := 'Estimado Cliente, le informamos que registramos la siguiente operación de Pago a la SET realizada a través del <br>Home Banking. La misma se encuentra sujeta a confirmación por parte de la <br>Subsecretaria de Estado de Tributación.  Le sugerimos que confirme el pago de la boleta, accediendo <br>al portal <b><a href="https://marangatu.set.gov.py/eset">Marangatu</a></b>, en la opción<br> <b>Consultar Pagos</b>.';
          v_titulo :='PAGO A CONFIRMAR EN LA SET';          
       ELSE
          v_texto := 'Estimado Cliente, le informamos que registramos el rechazo del Pago a la SET realizado a través del Home Banking.';
          v_titulo :='PAGO RECHAZADO EN LA SET';                    
       END IF;
    ELSE
      v_texto := 'Estimado Cliente, le informamos que registramos la siguiente operación de Pago a la SET realizado a través del<br> Home Banking. Le sugerimos que confirme el pago de la boleta, accediendo al portal <b><a href="https://marangatu.set.gov.py/eset">Marangatu</a></b>, en la opción<br> <b>Consultar Pagos</b>.';
      v_titulo :='PAGO PROCESADO EN LA SET';         
    END IF;
  
    IF p_xml.extract('/SET/Respuesta/Errores/Errores/RECHAZAR/text()') IS NOT NULL THEN
      v_cod_mensaje := substr(p_xml.extract('/SET/Respuesta/Errores/Errores/RECHAZAR/text()').getStringVal(), 1, 15);
    END IF;
  
    IF p_xml.extract('/SET/Respuesta/Errores/Errores/DESCRIPCIONERROR/text()') IS NOT NULL THEN
      v_msj_error := substr(p_xml.extract('/SET/Respuesta/Errores/Errores/DESCRIPCIONERROR/text()').getStringVal(), 1, 150);
    END IF;
  
    IF nvl(p_can_reintento, 0) <> 0 THEN
       v_numero_ot   := p_xml.extract('/SET/Pago/numeroOt/text()').getStringVal();
       v_consecutivo := p_xml.extract('/SET/Pago/@consecutivo').getNumberVal();
       IF p_xml.extract('/SET/lastRetry') IS NOT NULL THEN
          v_ult_reintento := p_xml.extract('/SET/lastRetry/text()').getNumberVal();
       END IF;
    END IF;
      
    v_cod_token     := p_xml.extract('/SET/token/text()').getStringVal();
  
    UPDATE ge_set_pagos
       SET estado          = v_estado,
           cod_set         = v_cod_set,
           cod_error       = v_cod_mensaje,
           msg_error       = v_msj_error,
           est_respuesta   = v_est_respuesta,
           nro_consecutivo = decode(p_can_reintento, 0, nro_consecutivo, v_consecutivo),
           nro_orden       = decode(p_can_reintento, 0, nro_orden, v_numero_ot),
           cant_renvio     = nvl(cant_renvio, 0) + nvl(p_can_reintento, 0),
           fec_renvio      = decode(p_can_reintento, 0, fec_renvio, sysdate)
     WHERE ruc = v_ruc
       AND nro_boleta = v_nro_boleta
       --AND fec_documento = v_fec_documento
       AND cod_token = v_cod_token
       AND estado NOT IN ('P', 'C')
       RETURNING nro_cta_debito, nro_operacion, monto INTO v_nro_cuenta, v_nro_operacion, v_monto;
    -- si es error de reintento, no se debe notificar al cliente
    IF v_estado = 'E' AND nvl(p_can_reintento, 0) <> 0 AND v_ult_reintento = 0 THEN
       RETURN;
    END IF;
    --obtenemos el nombre del cliente
    v_nombre :=  fue_obt_nom_persona(fug_obt_cli_principal(v_nro_cuenta));
    
    BEGIN
       -- armamos el mensaje
        -- ---------- cabecera --------------
        v_cabecera :=
              -- inicio div
              paw_pro.fu_not_inicio ||
              -- titulo
              paw_pro.fu_not_titulo(UTL_URL.ESCAPE(v_titulo, TRUE, 'UTF-8'));
        -- subtitulo
        v_cabecera := v_cabecera ||
        paw_pro.fu_not_sub_titulo(UTL_URL.ESCAPE(v_texto, TRUE, 'UTF-8'));
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
        -- detalles

        v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nombre del Cliente', TRUE, 'UTF-8'), v_nombre);
        v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nro. Cuenta Débito', TRUE, 'UTF-8'), v_nro_cuenta);
        v_detalle := v_detalle || paw_pro.fu_not_row_tag('RUC', v_ruc);
		    v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro. Boleta', v_nro_boleta);
        v_detalle := v_detalle || paw_pro.fu_not_row_tag('Monto', to_char(nvl(v_monto, 0), '999G999G999G999G999'));
	      v_detalle := v_detalle || paw_pro.fu_not_row_tag('Fecha'||v_tag, to_char(v_fec_documento, 'dd/mm/yyyy'));
        v_detalle := v_detalle || paw_pro.fu_not_row_tag('Nro. Comprobante', v_nro_operacion);
        -- fin div
        v_pie := v_pie || paw_pro.fu_not_fin;
    
       SELECT upper(sys_context('USERENV', 'DB_NAME'))
         INTO v_db_name
         FROM dual;
       v_dir_correo := paw_seg.fu_obt_mail(fug_obt_cli_principal(v_nro_cuenta));
       IF fug_ind_produccion = 'S' OR nvl(v_dir_correo, 'x') = fug_obt_pardinamico('TST_NOT_MAIL') THEN
          v_number := paw_not.fu_env_email_prueba(v_dir_correo, v_cabecera || v_detalle || v_pie, 'Yaguarete');
          -- si hay error, notificar tambien a lista interna para manejo
          IF v_estado = 'E' THEN
             v_number := paw_not.fu_env_email_prueba(TRIM(fug_obt_pardinamico('DIR_SET_SAU')), v_cabecera || v_detalle || v_pie, 'Yaguarete');
          END IF;
       END IF;
    EXCEPTION
       WHEN OTHERS THEN
          lp_reg_operacion('paw_not.fu_env_email_prueba', sqlerrm);
    END;
  END;
  
  -- procedimiento para establecer la secuencia de OT por contingencia
  PROCEDURE pr_ot_establecer(p_nro_secuencia IN NUMBER, p_tip_ot IN NUMBER) IS
    v_respuesta  TYP_POSTRESPUESTA;
    v_parametros ge_par_dinamicos.val_parametro%TYPE;
  BEGIN
    v_parametros := utl_lms.format_message('access_token=%s&nro_secuencia=%s&tipo_ot=%s', g_api_gateway, to_char(p_nro_secuencia), to_char(p_tip_ot));
    v_respuesta  := fue_env_post(v_parametros, g_url_gateway || g_url_ot_set);
    lp_reg_operacion(g_url_gateway || g_url_ot_set || v_parametros, v_respuesta.error || '-' || v_respuesta.codigoError 
                                                   || '-' || v_respuesta.status_code 
                                                   || '-' || v_respuesta.descripcionRespuesta);
  END;
  
  -- procedimiento para llamar al API para actualizar las OTs
  PROCEDURE pr_ot_actualizar IS
    v_respuesta   TYP_POSTRESPUESTA;
    v_parametros  ge_par_dinamicos.val_parametro%TYPE;
    v_fec_valor   VARCHAR2(10) := to_char(pag_cal.fu_obt_fec_actual(9), 'dd/mm/yyyy');
    v_fec_val_ant VARCHAR2(10) := to_char(pag_cal.fu_obt_fec_anterior(9), 'dd/mm/yyyy');
    v_fec_inicial DATE := to_date(v_fec_val_ant || ' ' || g_hor_inicio, 'dd/mm/yyyy hh24:mi:ss');
    v_fec_final   DATE := to_date(v_fec_valor || ' ' || g_hor_cierre, 'dd/mm/yyyy hh24:mi:ss');
    v_existe      VARCHAR2(1);
  BEGIN
    -- verificar si es dia habil
    IF v_fec_valor = to_char(SYSDATE, 'dd/mm/yyyy') THEN
       BEGIN
          SELECT 'S'
            INTO v_existe
            FROM ge_set_pagos p             
           WHERE p.fec_insercion between v_fec_inicial and v_fec_final
             AND estado = 'P'
             AND rownum = 1;
       
          v_parametros := utl_lms.format_message('access_token=%s', g_api_gateway);
          v_respuesta  := fue_env_post(v_parametros, g_url_gateway || g_url_ots_update);
          lp_reg_operacion(g_url_ots_update, v_respuesta.error || '-' || v_respuesta.codigoError 
                                                               || '-' || v_respuesta.status_code 
                                                               || '-' || v_respuesta.descripcionRespuesta);
       EXCEPTION
          WHEN NO_DATA_FOUND THEN
             lp_reg_operacion(g_url_ots_update, 'ini: '|| to_char(v_fec_inicial, 'dd/mm/yyyy hh24:mi:ss') ||', fin: '||to_char(v_fec_final, 'dd/mm/yyyy hh24:mi:ss')||', err: sin datos');
          WHEN OTHERS THEN
             lp_reg_operacion(g_url_ots_update, sqlerrm);
             BEGIN
                prg_env_mail(fug_obt_dir_correo, TRIM(fug_obt_pardinamico('DIR_MAIL_SET')), 'Error en Actualizacion de OT', 'No se pudo rotar la OT del dia ' || to_char(sysdate, 'dd/mm/yyyy'));
             EXCEPTION
                WHEN OTHERS THEN
                   NULL;
             END;
       END;
    ELSE
        lp_reg_operacion(g_url_ots_update,'Sysdate: '||sysdate||' <> fecha actual: '||v_fec_valor);
    END IF;
  END;

  FUNCTION fu_env_ot(p_fecha         IN DATE,
                     p_nro_documento IN ge_set_pagos.nro_orden%TYPE,
                     p_tip_ot        IN ge_set_pagos.tip_orden%TYPE,
                     p_importe       IN ge_set_pagos.monto%TYPE,
                     p_cta_bcp       IN ge_set_impuestos.cod_cuenta%TYPE,
                     p_consulta      IN VARCHAR2 DEFAULT 'S')
    RETURN typ_postrespuesta IS
    v_fecha         VARCHAR2(10);
    v_nro_documento ge_set_pagos.nro_orden%TYPE;
    v_tip_ot        ge_set_pagos.tip_orden%TYPE;
    v_cta_bcp       ge_set_impuestos.cod_cuenta%TYPE;
    v_metodo        VARCHAR2(8);
    v_parametros    ge_par_dinamicos.val_parametro%TYPE;
    json_ot         ge_par_dinamicos.val_parametro%TYPE;
    v_respuesta     TYP_POSTRESPUESTA;
  BEGIN
    -- consulta : S, indica que es una consulta de OT, se envia por GET
    --          : N, indica que es para guardar la OT, se envia por POST
    SELECT decode(nvl(p_consulta, 'S'), 'S', 'GET', 'POST')
      INTO v_metodo
      FROM DUAL;
  
    v_fecha         := to_char(p_fecha, 'dd/mm/yyyy');
    v_nro_documento := paw_bel.depurarAlfanumerico(p_nro_documento, 15);
    v_tip_ot        := substr(p_tip_ot, 1, 1);
    v_cta_bcp       := paw_bel.depurarAlfanumerico(p_cta_bcp, 3);
  
    -- armamos el parametro json para el gateway
    json_ot := utl_lms.format_message('{ "fechaDocumento": "%s", "numeroDocumento": %s, "tipoOt": %s, "importeTransferir": %s, "cuentaBCP" : %s }',
                                      v_fecha,
                                      v_nro_documento,
                                      v_tip_ot,
                                      to_char(p_importe),
                                      v_cta_bcp);
  
    -- preparamos los parametros                                  
    v_parametros := utl_lms.format_message('access_token=%s&json_ot=%s', g_api_gateway, utl_url.escape(json_ot));
  
    -- enviamos la ot (v_metodo : GET->consultarOT, POST->guardarOT)
    v_respuesta := fue_env_post(v_parametros, g_url_gateway || g_url_ots, v_metodo);
  
    -- bitacora de logs
    lp_reg_operacion('/'||v_metodo||'/'||g_url_ots||'/'||v_parametros, substr(v_respuesta.status_code ||' - ' || v_respuesta.respuesta, 1, 4000));
    RETURN v_respuesta;
  END;

  FUNCTION lf_cal_dig_ver_modulo11(p_numero  IN VARCHAR2,
                                   p_basemax IN NUMBER DEFAULT 11)
    RETURN NUMBER IS
  
    v_total      NUMBER(6);
    v_resto      NUMBER(2);
    k            NUMBER(2);
    v_numero_aux NUMBER(1);
    v_numero_al  VARCHAR2(255);
    v_caracter   VARCHAR2(1);
    v_digit      NUMBER;
  BEGIN
    FOR i IN 1 .. length(p_numero) LOOP
      v_caracter := substr(p_numero, i, 1);
      IF ascii(upper(v_caracter)) NOT BETWEEN 48 AND 57 THEN
        -- de 0 a 9
        v_numero_al := v_numero_al || ascii(v_caracter);
      ELSE
        v_numero_al := v_numero_al || v_caracter;
      END IF;
    END LOOP;
    k       := 2;
    v_total := 0;
  
    FOR i IN REVERSE 1 .. length(v_numero_al) LOOP
      IF k > p_basemax THEN
        k := 2;
      END IF;
      v_numero_aux := to_number(substr(v_numero_al, i, 1));
      v_total      := v_total + (v_numero_aux * k);
      k            := k + 1;
    END LOOP;
  
    v_resto := MOD(v_total, 11);
    IF v_resto > 1 THEN
      v_digit := 11 - v_resto;
    ELSE
      v_digit := 0;
    END IF;
    RETURN v_digit;
  END;

  /*-- Funcion que genera el numero de OT
  FUNCTION fu_generar_ot RETURN VARCHAR2 IS
     v_numero_ot       VARCHAR2(11);
     v_dig_verificador NUMBER;
     v_nro_secuencia   VARCHAR2(8);
     v_cod_era         VARCHAR2(2);
  BEGIN
     v_cod_era := substr(TRIM(fug_obt_pardinamico('HOB_COD_SET_ERA')), 1, 2);
     -- obtenemos la ultima secuencia 
     SELECT nro_secuencia
       INTO v_nro_secuencia
       FROM ge_set_secuencia;
     
     v_dig_verificador := lf_cal_dig_ver_modulo11(v_cod_era || v_nro_secuencia);
     v_numero_ot       := v_cod_era || lpad(v_nro_secuencia, 8, '0') || v_dig_verificador;
     RETURN v_numero_ot;
  EXCEPTION
     WHEN OTHERS THEN
        RETURN NULL;
  END;
  
  -- actualiza la secuencia para las OT
  -- OJO!: este procedimiento se debe ejecutar unicamente en el cierre diario
  -- de pago a la SET, nunca invocar a mano
  PROCEDURE pr_act_secuencia IS
     PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
     UPDATE ge_set_secuencia a
        SET a.nro_secuencia = a.nro_secuencia + 1;
        
     COMMIT;
  END;
*/

  -- obtener tipo OT
  FUNCTION fu_obt_tip_ot(p_cod_impuesto IN ge_set_impuestos.cod_impuesto%TYPE)
    RETURN NUMBER IS
    v_cuenta ge_set_impuestos.cod_cuenta%TYPE;
  BEGIN
    SELECT p.cod_cuenta
      INTO v_cuenta
      FROM ge_set_impuestos p
     WHERE p.cod_impuesto = p_cod_impuesto;
  
    IF v_cuenta = '460' THEN
      RETURN 1;
    ELSIF v_cuenta = '432' THEN
      RETURN 2;
    ELSE
      RETURN - 2;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END;
  
  PROCEDURE lp_depurar(p_respuesta IN OUT VARCHAR2) IS
  BEGIN
     p_respuesta := REPLACE( p_respuesta, '\u003c', '<' );
     p_respuesta := REPLACE( p_respuesta, '\u003e', '>' );
     p_respuesta := REPLACE( p_respuesta, '\u003d', '=' );
     p_respuesta := REPLACE( p_respuesta, '\"', '"' );
     p_respuesta := REPLACE( p_respuesta, '\n', '' );
  EXCEPTION
     WHEN OTHERS THEN
        NULL;
  END;

  PROCEDURE PR_GEN_PAG_SET_OT(p_nro_orden in ge_set_ordenes.nro_orden%type default null) IS
    v_fec_orden   date;
    v_fec_pago    date;
    v_fec_reenvio date;
    v_fec_val   VARCHAR2(10) := to_char(pag_cal.FU_OBT_FEC_ACTUAL(9), 'dd/mm/yyyy');
    v_fec_val_ant VARCHAR2(10) := to_char(pag_cal.fu_obt_fec_anterior(9), 'dd/mm/yyyy');
    v_fec_ini DATE := to_date(v_fec_val_ant|| ' ' || g_hor_inicio, 'dd/mm/yyyy hh24:mi:ss');
    v_fec_fin   DATE := to_date(v_fec_val|| ' ' || g_hor_cierre, 'dd/mm/yyyy hh24:mi:ss');
    v_mon_total   ge_set_ordenes.monto%type;
    v_nro_cta_bcp ge_set_ordenes.nro_cta_bcp%type;
    v_nro_reenvio ge_set_ordenes.nro_sec_renvio%type;
    v_secuencia   ge_set_ordenes.nro_secuencia%type;
   
    --variables p/manejo de errores.
    v_cod_error  ge_set_ordenes.cod_error%type;
    v_msg_error  ge_set_ordenes.msg_error%type;
    v_cod_set    ge_set_ordenes.cod_set%type;
    v_existe_err varchar2(1);
    --variables p/ el envio de mail.
    v_para     varchar2(200);
    v_asunto   varchar2(2000);
    v_mje_mail varchar2(2000) := null;
    --variables p/ post respuesta.
    v_respuesta TYP_POSTRESPUESTA;
    v_xml xmltype;
    v_respuesta_ot ge_set_pagos.est_respuesta%TYPE;
    --variables p/ transferencia
    --credito
    v_cta_credito        ge_movimientos.nro_cuenta%type;
    v_hora               ge_movimientos.hora%type := to_char(sysdate,'hh24:mi:ss');
    v_cod_mon_cta_cre    ge_movimientos.cod_moneda%type;
    v_monto_cre          ge_movimientos.monto%type;
    v_cod_transaccion    ge_movimientos.cod_tra_padre%type;
    v_cre_cod_tra_hijo   ge_movimientos.cod_transaccion%type;
    v_nro_documento      ge_movimientos.nro_documento%type;
    v_cotizacion         ge_movimientos.cotizacion%type;
    v_cdofici            ge_movimientos.cod_oficina%type;
    v_cod_mod_padre      ge_movimientos.cod_modulo%type;
    v_cod_mad_padre      ge_movimientos.cod_modalidad%type;
    v_nro_secuencia      ge_movimientos.nro_secuencia%type := 0;
    v_fec_valor          ge_movimientos.fecha%type;
    v_mto_equ_local      ge_movimientos.mto_equ_local%type;
    --debito
    v_cta_debito         ge_movimientos.nro_cuenta%type;
    v_cod_mon_cta_deb    ge_movimientos.cod_moneda%type;
    v_imp_debito         ge_movimientos.monto%type;
    v_cod_tra_pad_debito ge_movimientos.cod_tra_padre%type;
    v_cod_tra_hij_debito ge_movimientos.cod_transaccion%type;
    v_cantidad           number := 0;
    v_intentos           number; -- total intentos debito/credito
    -- DDSI-212 -- 01/2018
    v_dir_correo         VARCHAR2(100) := NVL(fug_obt_dir_correo,fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'));
    v_activo             VARCHAR2(1) := 'N';
    C_COD_PRV_SET        CONSTANT VARCHAR2(1) := '2'; -- Codigo de Proveedor asignado a la SET
    -- cursor principal de pagos
    CURSOR C_SET_PAGOS IS
      select nro_orden, tip_orden, sum(monto) monto
        from ge_set_pagos
       where ((fec_insercion between v_fec_ini and v_fec_fin and p_nro_orden is null) or 
              (p_nro_orden is not null and nro_orden = p_nro_orden))
         and estado = 'P'
         group by nro_orden, tip_orden;

    -- armar mensaje de error     
    PROCEDURE lp_err_cargar IS
    BEGIN
       v_cod_set := NULL;
       v_cod_error := NULL;
       v_msg_error := NULL;
       
       FOR c IN ( SELECT tipo, rechazar, descripcion
                    FROM xmltable('/Errores' passing (SELECT cells FROM xmltable('/Respuesta/Errores' passing v_xml columns CELLS  XMLTYPE PATH './Errores'))                   
                                                           columns tipo VARCHAR(10) PATH './TipoError',
                                                                   rechazar VARCHAR(15) PATH './Rechazar',
                                                                   descripcion VARCHAR(150) PATH './DescripcionError'
                                  )
               )
       LOOP
          IF c.rechazar <> 'INFORMATIVO' THEN
             v_cod_set   := substr(v_cod_set || c.tipo, 1, 10);
             v_cod_error := substr(v_cod_error || c.rechazar, 1, 15);
             v_msg_error := substr(v_msg_error || c.descripcion, 1, 150);
             v_mje_mail  := substr(chr(10)||chr(13)||v_msg_error||v_mje_mail, 1, 2000);
          END IF;
       END LOOP;
    END;
    
    -- insercion nueva de orden
    PROCEDURE lp_ins_orden(p_tip_orden ge_set_ordenes.tip_orden%type,
                           p_nro_orden ge_set_ordenes.nro_orden%type) IS
       PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
       INSERT INTO ge_set_ordenes
          (fec_orden, nro_secuencia, nro_orden, fec_pago,
           nro_cta_bcp, monto, tip_orden, estado)
        VALUES
          (v_fec_orden, v_secuencia, p_nro_orden, v_fec_pago,
           v_nro_cta_bcp, v_mon_total, p_tip_orden, 'N');
       -- se comitea para poder identificar reintentos
       COMMIT;    
    END;
    
    -- insercion movimiento
    PROCEDURE lp_ins_movimiento(p_nro_orden in ge_set_pagos.nro_orden%type, p_can_intentos out number) IS
       PRAGMA AUTONOMOUS_TRANSACTION;
       v_ins_movimiento  VARCHAR2(1) := 'N';
       v_can_intentos    NUMBER := 1;
       v_err_movimiento  VARCHAR2(500);
    BEGIN
       -- manejo de reintento de debito/credito por concurrencia HBANK
       WHILE v_ins_movimiento = 'N' AND v_can_intentos <= 10 LOOP
          BEGIN
             -- Procesamos el credito
             pag_cta.pr_act_operacion(v_cta_credito,
                                      v_hora, 
                                      'C',
                                      v_cod_mon_cta_cre, --Moneda de la Operaci?n
                                      v_monto_cre,
                                      nvl(v_cod_transaccion,487),
                                      nvl(v_cre_cod_tra_hijo,602),
                                      p_nro_orden,
                                      v_cotizacion, 
                                      v_cdofici,                 --cod_ofi_origen
                                      nvl(v_cod_mod_padre, 3),   --cod_mod_padre
                                      nvl(v_cod_mad_padre, 31),  --cod_mad_padre
                                      null,                      --cod_tasa
                                      null,                      --val_tasa
                                      'Transferencia de Cta. Transitoria a Definitiva.',
                                      'S',                       --emi_aviso
                                      v_nro_secuencia,
                                      trunc(v_fec_valor),
                                      null,
                                      null,
                                      v_mto_equ_local);  
             -- Procesamos el debito  
             pag_cta.pr_act_operacion(v_cta_debito,
                                      v_hora,--HORA
                                      'D',
                                      v_cod_mon_cta_deb,
                                      v_imp_debito,
                                      nvl(v_cod_tra_pad_debito,487),
                                      nvl(v_cod_tra_hij_debito,503),
                                      p_nro_orden,
                                      v_cotizacion,             --COTIZACION
                                      v_cdofici,    --cod_ofi_origen
                                      nvl(v_cod_mod_padre, 3),    --cod_mod_padre
                                      nvl(v_cod_mad_padre, 31), --cod_mad_padre
                                      null, --cod_tasa
                                      null, --val_tasa
                                      'Transferencia de Cta. Transitoria a Definitiva.',
                                      'S', --emi_aviso
                                      v_nro_secuencia,
                                      trunc(v_fec_valor),
                                      null, 
                                      null,
                                      v_mto_equ_local ); 
             v_ins_movimiento := 'S';
          EXCEPTION
             WHEN OTHERS THEN
                ROLLBACK;
                v_hora := fug_obt_hor_disponible(v_fec_valor, v_hora, USER, 'N' /*v_es_mov_noc*/);
                v_ins_movimiento := 'N';
                v_can_intentos   := v_can_intentos + 1;
                v_err_movimiento := substr(SQLERRM, 1, 500);
          END;
       END LOOP;
       p_can_intentos := v_can_intentos;
       -- si no se pudo procesar el debito y credito, reportamos un error
       IF v_ins_movimiento = 'N' THEN
          BEGIN
             PRG_ENV_MAIL(fug_obt_dir_correo, v_para, 'Error en Generacion de movimiento de OT '||p_nro_orden, 'No se pudo generar el movimiento asociado a la OT');
          EXCEPTION
             WHEN OTHERS THEN
                NULL;
          END;
          raise_application_error(-20000, v_err_movimiento);
       ELSE
          COMMIT;
       END IF;
    END;  
    -- Actualizar Saldos de Cuentas -- DDSI-212 -- 01/2018
    PROCEDURE pr_act_bat_saldos IS
    BEGIN
       PAG_BAT.pr_act_bat_saldos;
       lp_reg_operacion(g_url_ots || ' - PAG_BAT.pr_act_bat_saldos: ', 'Actualizacion de Saldos de Cuentas realizado');
    EXCEPTION
       WHEN OTHERS THEN
          lp_reg_operacion(g_url_ots || ' - PAG_BAT.pr_act_bat_saldos: ', SQLERRM);
          -- enviamos correo de notificacion de error
          v_asunto   := substr('Error en Actualizacion de Saldos de Cuentas en Generacion de OT.', 1, 2000);
          v_mje_mail := substr('Se registraron los siguientes errores al intentar actualizar Saldos de Cuentas al generar la OT.' || v_mje_mail, 1, 2000);
          BEGIN
             PRG_ENV_MAIL(v_dir_correo, v_para, v_asunto, v_mje_mail);
          EXCEPTION
             WHEN OTHERS THEN
                lp_reg_operacion(g_url_ots || ' - Error en Envío de mail en Actualizacion de Saldos de Cuentas en Generacion de OT - PRG_ENV_MAIL: ', SQLERRM);
          END;
          ROLLBACK;
          raise_application_error(-20000, SQLERRM);
    END;  
  BEGIN
    IF v_fec_val <> to_char(SYSDATE, 'dd/mm/yyyy') and p_nro_orden is null THEN
       lp_reg_operacion(g_url_ots, 'Sysdate: '||sysdate||' <> fecha actual: '||v_fec_val);
       RETURN;
    END IF;
    -- direccion de correo para notificacion
    BEGIN
       v_para := TRIM(FUG_OBT_PARDINAMICO('DIR_MAIL_SET'));
    EXCEPTION
       WHEN OTHERS THEN
          NULL;
    END;
    
    -- Actualizar Saldos de Cuentas cuando esta activo para el provedor SET -- DDSI-212 -- 01/2018
    BEGIN
       BEGIN
          SELECT 'S'
            INTO v_activo
            FROM TABLE(fug_obt_tab_registro(fug_obt_pardinamico('GE_ACT_SAL_BAT_PROV')))
           WHERE COLUMN_VALUE = C_COD_PRV_SET;
       EXCEPTION
         WHEN OTHERS THEN
           v_activo := 'N';
       END;
       IF NVL(v_activo, 'N') = 'S' THEN
          pr_act_bat_saldos;
       END IF;
    END;
    
    v_fec_orden   := pag_cal.fu_obt_fec_actual(1);
    v_fec_pago    := pag_cal.fu_obt_fec_actual(1);
    v_fec_reenvio := pag_cal.fu_obt_fec_actual(1);
    for pag in c_set_pagos loop
      v_cantidad := v_cantidad + 1;
      v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      v_mje_mail := NULL;
      
      v_nro_secuencia := 0; 
      begin
        select 'S', nro_sec_renvio
          into v_existe_err, v_nro_reenvio
          from ge_set_ordenes
         where estado = 'E'
           and nro_orden = pag.nro_orden;
      Exception
        When no_data_found then
          v_existe_err  := 'N';
          v_nro_reenvio := 0;
        When others then
          v_existe_err  := 'N';
          v_nro_reenvio := 0;
      End;
      -- secuencia 
      select s_set_nro_sec_ordenes.nextval 
        into v_secuencia
        from dual; 
      --
      v_mon_total := pag.monto;
      if pag.tip_orden = 1 then
         v_nro_cta_bcp := 460;
         v_cta_credito := fug_obt_pardinamico('NRO_CTA_CREDITO_460');
         v_cod_mon_cta_cre := fug_obt_mon_cta(v_cta_credito);
      else
         v_nro_cta_bcp := 432;
         v_cta_credito := fug_obt_pardinamico('NRO_CTA_CREDITO_432');
         v_cod_mon_cta_cre := fug_obt_mon_cta(v_cta_credito);
      end if;
      if nvl(v_existe_err, 'N') = 'N' then -- no es reintento
        /*   
        insert into ge_set_ordenes
          (fec_orden, nro_secuencia, nro_orden, fec_pago,
           nro_cta_bcp, monto, tip_orden, estado)
        values
          (v_fec_orden, v_secuencia, pag.nro_orden, v_fec_pago,
           v_nro_cta_bcp, v_mon_total, pag.tip_orden, 'N'); */
        lp_ins_orden(pag.tip_orden, pag.nro_orden);
                
        -- notificamos a la SET la OT
        v_respuesta := fu_env_ot(v_fec_orden,
                                 pag.nro_orden,
                                 pag.tip_orden,
                                 v_mon_total,
                                 v_nro_cta_bcp,
                                 'N');
        lp_depurar(v_respuesta.respuesta);
        v_respuesta.respuesta := substr(v_respuesta.respuesta, 2, length(v_respuesta.respuesta)-2);
        
        -- parseo el xml
        v_xml := xmltype.createxml(v_respuesta.respuesta);
        v_respuesta_ot := UPPER(TRIM(substr(v_xml.extract('/Respuesta/Estado/text()').getStringVal(), 1, 30)));        
        IF v_respuesta_ot <> 'ACEPTADO' THEN -- OT rechazada en la SET
           if v_xml.extract('/Respuesta/Errores/Errores/TipoError') is not null then
              lp_err_cargar;
              
              update ge_set_ordenes
                 set cod_set        = v_cod_set,
                     cod_error      = v_cod_error,
                     msg_error      = v_msg_error,
                     estado         = 'E',
                     nro_sec_renvio = v_nro_reenvio
               where nro_orden = pag.nro_orden
                 and estado <> 'P';
              -- enviamos correo de notificacion de error              
              v_asunto   := substr('Generación de OT ' ||pag.nro_orden||' con Errores', 1, 2000);
              v_mje_mail := substr('Se registraron los siguientes errores al generar la OT [' ||
                            pag.nro_orden || '].'||v_mje_mail, 1, 2000);
              BEGIN
                 PRG_ENV_MAIL(fug_obt_dir_correo, v_para, v_asunto, v_mje_mail);
              EXCEPTION
                 WHEN OTHERS THEN
                    lp_reg_operacion(g_url_ots ||' - PRG_ENV_MAIL: ', sqlerrm);
              END;
           end if;
        ELSE -- OT Aceptada en la SET
           -- conciliamos la OT
           update ge_set_ordenes
              set estado = 'P'
            where nro_orden = pag.nro_orden;
           -- conciliamos los pagos
           update ge_set_pagos
              set estado = 'C'
            where nro_orden = pag.nro_orden
              and estado = 'P';
           --setear variables
           v_monto_cre := v_mon_total;
           v_nro_documento := fug_obt_cli_principal(v_cta_credito);
           v_cdofici := fug_obt_ofi_cliente(v_nro_documento);
           /*-- Actualiza la Cuenta Cr?dito / Destino
           pag_cta.pr_act_operacion(v_cta_credito,
     						                   v_hora,                                    --HORA
     						                   'C',
     						                   v_cod_mon_cta_cre,                        --Moneda de la Operaci?n
     					                     v_monto_cre,
            					             nvl(v_cod_transaccion,487),
     					                     nvl(v_cre_cod_tra_hijo,602),
     						                   pag.nro_orden,
     						                   v_cotizacion,                                     --COTIZACION
     						                   v_cdofici,                                        --cod_ofi_origen
     						                   nvl(v_cod_mod_padre, 3),                          --cod_mod_padre
    						                   nvl(v_cod_mad_padre, 31),                         --cod_mad_padre
    						                   null,                                             --cod_tasa
    						                   null,                                             --val_tasa
    						                   'Transferencia de Cta. Transitoria a Definitiva.',
    						                   'S',                                              --emi_aviso
    						                   v_nro_secuencia,
    						                   trunc(v_fec_valor),
    						                   null, 
    						                   null,
    						                   v_mto_equ_local); */ 
             -- setea variables para el debito
           v_cta_debito := fug_obt_pardinamico('NRO_CTA_SET_TRANSITORIA');
           v_cod_mon_cta_deb := fug_obt_mon_cta(v_cta_debito);
           v_imp_debito := v_mon_total;
           /*  -- Actualiza la Cuenta Origen / D?bito   
           pag_cta.pr_act_operacion(v_cta_debito,
                                    v_hora,--HORA
                                    'D',
                                    v_cod_mon_cta_deb,
                                    v_imp_debito,
                                    nvl(v_cod_tra_pad_debito,487),
                                    nvl(v_cod_tra_hij_debito,503),
                                    pag.nro_orden,
                                    v_cotizacion,             --COTIZACION
                                    v_cdofici,    --cod_ofi_origen
                                    nvl(v_cod_mod_padre, 3),    --cod_mod_padre
                                    nvl(v_cod_mad_padre, 31), --cod_mad_padre
                                    null, --cod_tasa
                                    null, --val_tasa
                                    'Transferencia de Cta. Transitoria a Definitiva.',
                                    'S', --emi_aviso
                                    v_nro_secuencia,
                                    trunc(v_fec_valor),
                                    null, 
                                    null,
                                    v_mto_equ_local ); */
          -- generamos los movimientos debito/credito
          lp_ins_movimiento(pag.nro_orden, v_intentos);
          -- notificamos la generacion de movimientos
          v_asunto   := substr('Generación de OT ' ||pag.nro_orden||' Exitosa', 1, 2000);
          v_mje_mail := substr('Se realizo el pago de la OT número [' || pag.nro_orden || '].'||chr(10)||chr(13)||
                               'Total de intentos ' || v_intentos, 1, 2000);
          BEGIN
             PRG_ENV_MAIL(fug_obt_dir_correo, v_para, v_asunto, v_mje_mail);
          EXCEPTION
             WHEN OTHERS THEN
                lp_reg_operacion(g_url_ots ||' - PRG_ENV_MAIL: ', sqlerrm);
          END;
        end if;
      else -- se reintenta el envio de la OT
         v_nro_reenvio := v_nro_reenvio + 1;
         -- notificamos a la SET
         v_respuesta := fu_env_ot(v_fec_orden,
                                 pag.nro_orden,
                                 pag.tip_orden,
                                 v_mon_total,
                                 v_nro_cta_bcp,
                                 'N');
        
        lp_depurar(v_respuesta.respuesta);
        v_respuesta.respuesta := substr(v_respuesta.respuesta, 2, length(v_respuesta.respuesta)-2);
        
        v_xml       := xmltype.createxml(v_respuesta.respuesta);
        v_respuesta_ot := UPPER(TRIM(substr(v_xml.extract('/Respuesta/Estado/text()').getStringVal(), 1, 30)));
        IF v_respuesta_ot <> 'ACEPTADO' THEN -- Reintento de OT rechazada en la SET
           if v_xml.extract('/Respuesta/Errores/Errores/TipoError') is not null then
              lp_err_cargar;
              
              update ge_set_ordenes
                 set cod_set   = v_cod_set,
                     cod_error = v_cod_error,
                     msg_error = v_msg_error,
                     estado    = 'E',
                     nro_sec_renvio = v_nro_reenvio
               where nro_orden = pag.nro_orden
                 and estado <> 'P';
              -- enviamos correo de notificacion de error
              v_asunto   := substr('Generación de OT ' ||pag.nro_orden||' con Errores', 1, 2000);
              v_mje_mail := substr('Se registraron los siguientes errores al reintentar generar la OT [' ||
                            pag.nro_orden || '].'||v_mje_mail, 1, 2000);
              BEGIN
                 PRG_ENV_MAIL(fug_obt_dir_correo, v_para, v_asunto, v_mje_mail);
              EXCEPTION
                 WHEN OTHERS THEN
                    lp_reg_operacion(g_url_ots ||' - PRG_ENV_MAIL: ', sqlerrm);
              END;
            end if;
        ELSE -- Reintento de OT Aceptada en la SET
          -- conciliamos la OT, indicamos la cantidad del reintento
          update ge_set_ordenes
             set estado = 'P', 
                 fec_renvio = v_fec_reenvio, 
                 nro_sec_renvio = v_nro_reenvio,
                 monto = v_mon_total
           where nro_orden = pag.nro_orden;
          -- conciliamos los pagos la OT reintentada
          update ge_set_pagos
             set estado = 'C'
           where nro_orden = pag.nro_orden
             and estado = 'P';
          --setear variables
          v_monto_cre := v_mon_total;
          v_nro_documento := fug_obt_cli_principal(v_cta_credito);
          v_cdofici := fug_obt_ofi_cliente(v_nro_documento);
          /*-- Actualiza la Cuenta Cr?dito / Destino
          pag_cta.pr_act_operacion(v_cta_credito,
     						                   v_hora,                                    --HORA
     						                   'C',
     						                   v_cod_mon_cta_cre,                        --Moneda de la Operaci?n
     					                     v_monto_cre,
            					             nvl(v_cod_transaccion,487),
     					                     nvl(v_cre_cod_tra_hijo,602),
     						                   pag.nro_orden,
     						                   v_cotizacion,                                     --COTIZACION
     						                   v_cdofici,                                        --cod_ofi_origen
     						                   nvl(v_cod_mod_padre, 3),                          --cod_mod_padre
    						                   nvl(v_cod_mad_padre, 31),                         --cod_mad_padre
    						                   null,                                             --cod_tasa
    						                   null,                                             --val_tasa
    						                   'Transferencia de Cta. Transitoria a Definitiva.',
    						                   'S',                                              --emi_aviso
    						                   v_nro_secuencia,
    						                   trunc(v_fec_valor),
    						                   null, 
    						                   null,
    						                   v_mto_equ_local);*/  
             -- setea variables para el debito
           v_cta_debito := fug_obt_pardinamico('NRO_CTA_SET_TRANSITORIA');
           v_cod_mon_cta_deb := fug_obt_mon_cta(v_cta_debito);
           v_imp_debito := v_mon_total;
           /*  -- Actualiza la Cuenta Origen / D?bito   
           pag_cta.pr_act_operacion(v_cta_debito,
                                    v_hora,--HORA
                                    'D',
                                    v_cod_mon_cta_deb,
                                    v_imp_debito,
                                    nvl(v_cod_tra_pad_debito,487),
                                    nvl(v_cod_tra_hij_debito,503),
                                    pag.nro_orden,
                                    v_cotizacion,             --COTIZACION
                                    v_cdofici,    --cod_ofi_origen
                                    nvl(v_cod_mod_padre, 3),    --cod_mod_padre
                                    nvl(v_cod_mad_padre, 31), --cod_mad_padre
                                    null, --cod_tasa
                                    null, --val_tasa
                                    'Transferencia de Cta. Transitoria a Definitiva.',
                                    'S', --emi_aviso
                                    v_nro_secuencia,
                                    trunc(v_fec_valor),
                                    null, 
                                    null,
                                    v_mto_equ_local ); */
          -- generamos los movimientos debito/credito
          lp_ins_movimiento(pag.nro_orden, v_intentos);
          -- notificamos la generacion de movimientos
          v_asunto   := substr('Generación de OT ' ||pag.nro_orden||' Exitosa', 1, 2000);
          v_mje_mail := substr('Se realizo el pago de la OT número [' || pag.nro_orden || '].'||chr(10)||chr(13)||
                               'Total de intentos ' || v_intentos, 1, 2000);
          BEGIN
             PRG_ENV_MAIL(fug_obt_dir_correo, v_para, v_asunto, v_mje_mail);
          EXCEPTION
             WHEN OTHERS THEN
                lp_reg_operacion(g_url_ots ||' - PRG_ENV_MAIL: ', SQLERRM);
          END;
        end if;
      end if;
    End Loop;
    COMMIT;
    -- registramos en la bitacora si no hubieron OTs generadas
    IF v_cantidad = 0 THEN
       IF p_nro_orden IS NULL THEN
          v_mje_mail := substr('No se encontraron OTs para la fecha ' || v_fec_val, 1, 2000);
       ELSE
          v_mje_mail := substr('No se encontraron datos para la OT ' || p_nro_orden || ' en fecha ' || to_char(sysdate, 'dd/mm/yyyy hh24:mi:ss'), 1, 2000); 
       END IF; 
       lp_reg_operacion(g_url_ots, v_mje_mail);
       BEGIN
         PRG_ENV_MAIL(fug_obt_dir_correo, v_para, 'Aviso Generacion de OT', v_mje_mail);
       EXCEPTION
         WHEN OTHERS THEN
            lp_reg_operacion(g_url_ots ||'Sin OT - PRG_ENV_MAIL: ', SQLERRM);
       END;
    END IF;
  EXCEPTION
     WHEN OTHERS THEN
        lp_reg_operacion(g_url_ots, SQLERRM);
        BEGIN
           prg_env_mail(fug_obt_dir_correo, TRIM(fug_obt_pardinamico('DIR_MAIL_SET')), 'Error en Proceso de OT', 'No se pudo conciliar la OT del dia ' || to_char(sysdate, 'dd/mm/yyyy'));
        EXCEPTION
           WHEN OTHERS THEN
              NULL;
        END;
        raise_application_error(-20000, SQLERRM);      
  END;
  
  FUNCTION fu_val_api(p_api_key IN VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
     IF p_api_key = g_api_gateway THEN
        RETURN 'S';
     END IF;
     
     RETURN 'N';
  END;
END PAG_SET;
/

