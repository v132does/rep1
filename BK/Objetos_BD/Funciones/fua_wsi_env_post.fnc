CREATE OR REPLACE FUNCTION IT.FUA_WSI_ENV_POST (p_parametros IN clob, p_url IN VARCHAR2, p_metodo IN VARCHAR2 DEFAULT 'POST') RETURN TYP_POSTRESPUESTACLOB IS
  
/* Autor:     Sergio Alejandro Servín Arce
   Propuesta: Función para enviar Datos por medio de Webservices
   Fecha:     31/08/2015

  */


   v_retorno   CLOB:='';
   v_buffer    CLOB:='';
   v_req       UTL_HTTP.REQ;
   v_resp      UTL_HTTP.RESP;
   v_respuesta TYP_POSTRESPUESTACLOB:= TYP_POSTRESPUESTACLOB() ;
   v_code      VARCHAR2(1) := NULL;
   v_parametros VARCHAR2(3000);
   v_param clob;
   V_CHARSET VARCHAR2(40);--contendrá el juego de carecteres de la base de datos.
   v_Date date;--para el delay de 0.5 seg

BEGIN

--buscamos el juego de caracteres de la base de datos
  BEGIN
    select T.VALUE
       INTO V_CHARSET
    from nls_database_parameters T
    WHERE T.PARAMETER = 'NLS_CHARACTERSET';
  EXCEPTION
     WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al buscar caracteres de Base de datos: '||SQLERRM);
  end;

  --convertimos a UTF8
  begin
   
  
   --v_param := convert(p_parametros,'UTF8',V_CHARSET);
   V_PARAM := convert(dbms_lob.substr(P_PARAMETROS,dbms_lob.getlength(P_PARAMETROS),1),  'UTF8', V_CHARSET);
   
    
    
  EXCEPTION
     WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al convertir a UTF8 los datos a enviar: '||SQLERRM);
  end;
  v_Date := pai_int.smg_sleep('0.5');--pausamos 0.5 segundo;(requerido para envío de datos a Bancard)
   BEGIN
      IF p_metodo = 'POST' THEN
         v_req       := UTL_HTTP.BEGIN_REQUEST(url => p_url, method => 'POST', http_version => 'HTTP/1.1');

         UTL_HTTP.SET_HEADER(r => v_req, NAME => 'Content-Type', VALUE => 'application/json;charset=UTF-8');

         UTL_HTTP.SET_HEADER(r => v_req, NAME => 'Authorization', VALUE => 'Basic YWRtaW46YWRtaW4xMjM=');

         UTL_HTTP.SET_HEADER(r => v_req, NAME => 'Content-Length', VALUE => lengthb(v_param));

         UTL_HTTP.WRITE_TEXT(r => v_req, data => v_param);
      ELSIF p_metodo = 'GET' THEN
         SELECT nvl2(v_param, '?', '') INTO v_code FROM dual;
         v_parametros := p_url||v_code||v_param;
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
END FUA_WSI_ENV_POST ;
/

