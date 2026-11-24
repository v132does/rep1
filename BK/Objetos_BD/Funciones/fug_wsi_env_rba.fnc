CREATE OR REPLACE FUNCTION IT.FUG_WSI_ENV_RBA(p_parametros IN clob,
                                           p_url        IN VARCHAR2,
                                           p_metodo     IN VARCHAR2 DEFAULT 'POST')
  RETURN TYP_POSTRESPUESTACLOB IS

  v_retorno   CLOB := '';
  v_buffer    CLOB := '';
  v_req       UTL_HTTP.REQ;
  v_resp      UTL_HTTP.RESP;
  v_respuesta TYP_POSTRESPUESTACLOB := TYP_POSTRESPUESTACLOB();
  v_reqXML    varchar2(32760);

BEGIN
  v_reqXML := p_parametros;
  BEGIN
    IF p_metodo = 'POST' THEN
      v_req := UTL_HTTP.BEGIN_REQUEST(p_url, 'POST');
    
      UTL_HTTP.SET_HEADER(v_req, 'Content-Type', 'text/xml');
    
      UTL_HTTP.SET_HEADER(v_req, 'Content-Length', lengthb(v_reqXML));
    
      UTL_HTTP.WRITE_TEXT(v_req, v_reqXML);
    END IF;
  
    v_resp                  := utl_http.get_response(r => v_req);
    v_respuesta.status_code := v_resp.status_code;
    v_respuesta.respuesta   := '';
    v_respuesta.error       := 'S';
  
    BEGIN
      LOOP
        UTL_HTTP.read_text(v_resp, v_buffer, 10000);
        v_retorno := v_retorno || v_buffer;
        if instr(v_buffer,'has not been defined') > 0 then
          UTL_HTTP.end_response(v_resp);
          v_respuesta.codigoError := 3;
          v_respuesta.respuesta   := 'Servicio RBA no habilitado';
          v_respuesta.error       := 'S';
          goto fin;
        end if;
      END LOOP;
      UTL_HTTP.end_response(v_resp);
      v_respuesta.codigoError := 0;
      v_respuesta.respuesta   := v_retorno;
      v_respuesta.error       := 'N';
    EXCEPTION
      WHEN utl_http.end_of_body THEN
        -- 99% de las veces siempre va a salir porque leyo de mas
        v_respuesta.codigoError := 0;
        v_respuesta.respuesta   := v_retorno;
        v_respuesta.error       := 'N';
        utl_http.end_response(v_resp);
    END;
  
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
  <<fin>>
  RETURN(v_respuesta);

END FUG_WSI_ENV_RBA;
/

