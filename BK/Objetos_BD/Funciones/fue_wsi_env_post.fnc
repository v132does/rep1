create or replace function it.FUE_WSI_ENV_POST(P_PARAMETROS in clob
                                           ,P_URL        in varchar2
                                           ,P_CON_TYPE   IN VARCHAR2 DEFAULT 'application/json;charset=UTF-8'
                                           ,P_METODO     in varchar2 default 'POST')
   return TYP_POSTRESPUESTACLOB is

   /* Autor:     Sergio Alejandro Servín Arce
    Propuesta: Función para enviar Datos por medio de Webservices con parámetros
    Fecha:     28/01/2021
   
   */

   V_RETORNO    clob := '';
   V_BUFFER     clob := '';
   V_REQ        UTL_HTTP.REQ;
   V_RESP       UTL_HTTP.RESP;
   V_RESPUESTA  TYP_POSTRESPUESTACLOB := TYP_POSTRESPUESTACLOB();
   V_CODE       varchar2(1) := null;
   V_PARAMETROS varchar2(3000);
   V_PARAM      clob;
   V_CHARSET    varchar2(40); --contendrá el juego de carecteres de la base de datos.
   v_contenlength number;
   --V_DATE       date; --para el delay de 0.5 seg

begin

   --buscamos el juego de caracteres de la base de datos
   begin
      select T.VALUE
        into V_CHARSET
        from NLS_DATABASE_PARAMETERS T
       where T.PARAMETER = 'NLS_CHARACTERSET';
   exception
      when others then
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al buscar caracteres de Base de datos: ' || sqlerrm);
   end;

   --convertimos a UTF8
   begin
      --V_PARAM := CONVERT(P_PARAMETROS, 'AL32UTF8', V_CHARSET);
      
      V_PARAM := convert(dbms_lob.substr(P_PARAMETROS,dbms_lob.getlength(P_PARAMETROS),1),  'UTF8', V_CHARSET);
      v_contenlength := LENGTHB(V_PARAM);
      
   exception
      when others then
         RAISE_APPLICATION_ERROR(-20000,
                                 'Error al convertir a UTF8 los datos a enviar: ' ||
                                 sqlerrm);
   end;
   --V_DATE := PAI_INT.SMG_SLEEP('0.5'); --pausamos 0.5 segundo;(requerido para envío de datos a Bancard)
   begin
      if P_METODO = 'POST' then
         V_REQ := UTL_HTTP.BEGIN_REQUEST(URL          => P_URL,
                                         METHOD       => 'POST',
                                         HTTP_VERSION => 'HTTP/1.1');
      
         UTL_HTTP.SET_HEADER(R     => V_REQ,
                             name  => 'Content-Type',
                             value => P_CON_TYPE);
      
         UTL_HTTP.SET_HEADER(R     => V_REQ,
                             name  => 'Content-Length',
                             value => v_contenlength);
      
         UTL_HTTP.WRITE_TEXT(R => V_REQ, DATA => V_PARAM);
      elsif P_METODO = 'GET' then
         select NVL2(V_PARAM, '?', '')
           into V_CODE
           from DUAL;
         V_PARAMETROS := P_URL || V_CODE || V_PARAM;
         V_REQ        := UTL_HTTP.BEGIN_REQUEST(V_PARAMETROS, 'GET', 'HTTP/1.1');
      end if;
      V_RESP                  := UTL_HTTP.GET_RESPONSE(R => V_REQ);
      V_RESPUESTA.STATUS_CODE := V_RESP.STATUS_CODE;
      V_RESPUESTA.RESPUESTA   := '';
      V_RESPUESTA.ERROR       := 'S';
      begin
         loop
            UTL_HTTP.READ_TEXT(V_RESP, V_BUFFER, 10000);
            V_RETORNO := V_RETORNO || V_BUFFER;
         end loop;
         UTL_HTTP.END_RESPONSE(V_RESP);
         V_RESPUESTA.CODIGOERROR := 0;
         V_RESPUESTA.RESPUESTA   := V_RETORNO;
         V_RESPUESTA.ERROR       := 'N';
      exception
         when UTL_HTTP.END_OF_BODY then
            -- 99% de las veces siempre va a salir porque leyo de mas
            V_RESPUESTA.CODIGOERROR := 0;
            V_RESPUESTA.RESPUESTA   := V_RETORNO;
            V_RESPUESTA.ERROR       := 'N';
            UTL_HTTP.END_RESPONSE(V_RESP);
      end;
   
   exception
      when UTL_TCP.NETWORK_ERROR then
         UTL_HTTP.END_RESPONSE(V_RESP);
         V_RESPUESTA.ERROR                := 'S';
         V_RESPUESTA.CODIGOERROR          := 1;
         V_RESPUESTA.DESCRIPCIONRESPUESTA := 'No hay conexion con el Servidor';
      when UTL_TCP.TRANSFER_TIMEOUT then
         UTL_HTTP.END_RESPONSE(V_RESP);
         V_RESPUESTA.ERROR                := 'S';
         V_RESPUESTA.CODIGOERROR          := 2;
         V_RESPUESTA.DESCRIPCIONRESPUESTA := 'Limite de tiempo de espera';
      when others then
         begin
            UTL_HTTP.END_RESPONSE(V_RESP);
         exception
            when others then
               null;
         end;
         V_RESPUESTA.ERROR                := 'S';
         V_RESPUESTA.DESCRIPCIONRESPUESTA := SUBSTR(sqlerrm, 0, 200);
   end;

   return(V_RESPUESTA);
end FUE_WSI_ENV_POST;
/

