CREATE OR REPLACE FUNCTION IT.FUE_ENV_BCP_POST(p_parametros IN VARCHAR2,
                                               p_url        IN VARCHAR2,
                                               p_metodo     IN VARCHAR2 DEFAULT 'POST')
  RETURN TYP_POSTRESPUESTA IS
  v_retorno   VARCHAR2(32760) := '';
  v_buffer    VARCHAR2(32760) := '';
  v_req       UTL_HTTP.REQ;
  v_resp      UTL_HTTP.RESP;
  v_respuesta TYP_POSTRESPUESTA := TYP_POSTRESPUESTA();
  v_file      VARCHAR2(200) := fug_obt_pardinamico('WS_URL_TAR_WALLET');
BEGIN
  -- Configurar el wallet
  UTL_HTTP.set_wallet(v_file, null);
  UTL_HTTP.set_transfer_timeout(15);
  BEGIN
    -- Crear la solicitud HTTP
    IF p_metodo = 'POST' THEN
      v_req := UTL_HTTP.BEGIN_REQUEST(url          => p_url,
                                      method       => 'POST',
                                      http_version => 'HTTP/1.1');
      UTL_HTTP.SET_HEADER(r     => v_req,
                          NAME  => 'Content-Type',
                          VALUE => 'application/json');
      UTL_HTTP.SET_HEADER(r     => v_req,
                          NAME  => 'Content-Length',
                          VALUE => length(p_parametros));
      UTL_HTTP.SET_HEADER(r     => v_req,
                          NAME  => 'x-api-key',
                          VALUE => 'CTA_CTE_BANKITTI');
      UTL_HTTP.SET_HEADER(r     => v_req,
                          NAME  => 'x-max-expiration-days',
                          VALUE => 0);
      UTL_HTTP.WRITE_TEXT(r => v_req, data => p_parametros);
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
      WHEN UTL_HTTP.end_of_body THEN
        v_respuesta.codigoError := 0;
        v_respuesta.respuesta   := v_retorno;
        v_respuesta.error       := 'N';
        UTL_HTTP.end_response(v_resp);
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

  RETURN(v_respuesta);
END FUE_ENV_BCP_POST;
/
