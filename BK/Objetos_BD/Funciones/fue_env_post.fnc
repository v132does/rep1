CREATE OR REPLACE FUNCTION IT.FUE_ENV_POST (p_parametros IN VARCHAR2, p_url IN VARCHAR2, p_metodo IN VARCHAR2 DEFAULT 'POST') RETURN TYP_POSTRESPUESTA IS
   v_retorno   VARCHAR2(32760) := '';
   v_buffer    VARCHAR2(32760) := '';
   v_req       UTL_HTTP.REQ;
   v_resp      UTL_HTTP.RESP;
   v_respuesta TYP_POSTRESPUESTA:= TYP_POSTRESPUESTA() ;
   v_code      VARCHAR2(1) := NULL;
   v_parametros VARCHAR2(3000);
BEGIN
   UTL_HTTP.set_transfer_timeout(160);
   BEGIN            
      IF p_metodo = 'POST' THEN
         v_req       := UTL_HTTP.BEGIN_REQUEST(url => p_url, method => 'POST', http_version => 'HTTP/1.1');
         UTL_HTTP.SET_HEADER(r => v_req, NAME => 'Content-Type', VALUE => 'application/x-www-form-urlencoded;charset=utf-8');
         UTL_HTTP.SET_HEADER(r => v_req, NAME => 'Content-Length', VALUE => length(p_parametros));
         UTL_HTTP.WRITE_TEXT(r => v_req, data => p_parametros);
      ELSIF p_metodo = 'GET' THEN                  
         SELECT nvl2(p_parametros, '?', '') INTO v_code FROM dual;
         v_parametros := p_url||v_code||p_parametros;
         v_req       := UTL_HTTP.BEGIN_REQUEST(v_parametros, 'GET', 'HTTP/1.1');
      END IF;
      v_resp                  := UTL_HTTP.GET_RESPONSE(r => v_req);
      v_respuesta.status_code := v_resp.status_code;
      v_respuesta.respuesta   := '';
      v_respuesta.error       := 'S';
      BEGIN
         LOOP
            UTL_HTTP.read_text(v_resp, v_buffer, 10000);
            v_retorno := v_retorno || v_buffer;
         END LOOP;
         UTL_HTTP.end_response(v_resp);
         v_respuesta.codigoError := 0;
         v_respuesta.respuesta   := v_retorno;
         v_respuesta.error       := 'N';
      EXCEPTION 
         WHEN UTL_HTTP.end_of_body THEN -- 99% de las veces siempre va a salir porque leyo de mas
         v_respuesta.codigoError := 0;
         v_respuesta.respuesta   := v_retorno;
         v_respuesta.error       := 'N';
            UTL_HTTP.end_response(v_resp);
      END;
   
      --UTL_FILE.fclose(v_req);
   
   
   EXCEPTION
      WHEN utl_tcp.network_error THEN
         UTL_HTTP.end_response(v_resp);
         v_respuesta.error                := 'S';
         v_respuesta.codigoError          := 1;
         v_respuesta.descripcionRespuesta := 'No hay conexion con el Servidor';
      WHEN utl_tcp.transfer_timeout THEN
         UTL_HTTP.end_response(v_resp);
         v_respuesta.error                := 'S';
         v_respuesta.codigoError          := 2;
         v_respuesta.descripcionRespuesta := 'Limite de tiempo de espera';
      WHEN OTHERS THEN
         BEGIN
            UTL_HTTP.end_response(v_resp);
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
         v_respuesta.error                := 'S';
         v_respuesta.descripcionRespuesta := substr(SQLERRM, 0, 200);
   END;


   RETURN(v_respuesta);
END fue_env_post;
/

