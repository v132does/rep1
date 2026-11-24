CREATE OR REPLACE FUNCTION IT.FUE_ENV_HTTP(p_url     IN VARCHAR2,
                                        p_metodo  IN VARCHAR2,
                                        p_headers IN typ_listaEtiquetaValor DEFAULT NULL,
                                        p_body    IN LONG DEFAULT NULL,
                                        p_version IN VARCHAR2 DEFAULT 'HTTP/1.1') RETURN typ_postRespuesta IS
   v_retorno    VARCHAR2(32760) := '';
   v_buffer     VARCHAR2(32760) := '';
   v_req        UTL_HTTP.req;
   v_resp       UTL_HTTP.resp;
   v_respuesta  typ_postRespuesta:= typ_postRespuesta();
   
   PROCEDURE lp_set_error(p_cod_error IN NUMBER,
                          p_respuesta IN VARCHAR2,
                          p_error     IN VARCHAR2) IS
   BEGIN
      v_respuesta.codigoError := p_cod_error;
      v_respuesta.respuesta   := p_respuesta;
      v_respuesta.error       := p_error;
   END;
BEGIN
   UTL_HTTP.set_transfer_timeout(160);
   BEGIN
      v_req := UTL_HTTP.begin_request(p_url, p_metodo, p_version);
      -- si hay headers
      IF p_headers IS NOT NULL THEN
         FOR i in 1..p_headers.count LOOP
            UTL_HTTP.set_header(v_req, p_headers(i).etiqueta, p_headers(i).valor);
         END LOOP;
      END IF;
      -- si tiene body
      IF p_body IS NOT NULL THEN
         UTL_HTTP.write_text(v_req, p_body);
      END IF;
      -- 
      v_resp                  := UTL_HTTP.get_response(r => v_req);
      v_respuesta.status_code := v_resp.status_code;
      lp_set_error(0, '', 'S');
      BEGIN
         LOOP
            UTL_HTTP.read_text(v_resp, v_buffer, 10000);
            v_retorno := v_retorno || v_buffer;
         END LOOP;
         UTL_HTTP.end_response(v_resp);
         lp_set_error(0, v_retorno, 'N');
      EXCEPTION 
         WHEN UTL_HTTP.end_of_body THEN -- 99% de las veces siempre va a salir porque leyo de mas    
         UTL_HTTP.end_response(v_resp);
         lp_set_error(0, v_retorno, 'N');
      END;
   EXCEPTION
      WHEN utl_tcp.network_error THEN
         UTL_HTTP.end_response(v_resp);
         lp_set_error(1, 'No hay conexion con el Servidor', 'S');
      WHEN utl_tcp.transfer_timeout THEN
         UTL_HTTP.end_response(v_resp);
         lp_set_error(2, 'Limite de tiempo de espera', 'S');
      WHEN OTHERS THEN
         lp_set_error(-9, substr(SQLERRM, 0, 200), 'S');
         BEGIN
            UTL_HTTP.end_response(v_resp);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
   END;

   RETURN v_respuesta;
END;
/

