create or replace function it.FUT_WSI_ENT_TDC_MASIVO(P_NRO_LOTE varchar2) return varchar2 is

   /* Autor:     Sergio Alejandro Servín Arce
   Propuesta: Función para procesar entregas de TDC de forma masiva, por medio de Webservices de Bancard
   Fecha:     28/01/2021
   
   OBS: Cargar v_con_error := 'SI*' para los errores que si o si se tienen que realizar ROLLBACK*/

   cursor C_TARJETAS is
      select '{"cardNumber":"' || T.NRO_TARJETA || '"}' TARJETA
        from TA_TAR_ENT_MASIVO T
       where T.NRO_LOTE = P_NRO_LOTE;

   V_FECHA        date := PAG_CAL.FU_OBT_FEC_ACTUAL(3);
   V_HORA         varchar2(8) := TO_CHAR(sysdate, 'HH24:MI:SS');
   V_PARAMETROS   varchar2(4000);
   V_INICIO       varchar2(10) := '[';
   V_FIN          varchar2(10) := ']';
   V_JSON_MENSAJE clob;
   V_PRI_REG      varchar2(1) := 'S';

   V_CON_ERROR varchar2(3) := 'NO';

   V_RESPUESTA TYP_POSTRESPUESTACLOB;

   V_RESPOST         TYP_POSTRESPUESTA;
   G_URL_ACT_TARJETA GE_PAR_DINAMICOS.VAL_PARAMETRO%type := FUG_OBT_PARDINAMICO('BAN_GATEWAY_URL') ||
                                                            FUG_OBT_PARDINAMICO('BAN_URL_TDCENT');
   G_API_KEY         GE_PAR_DINAMICOS.VAL_PARAMETRO%type := FUG_OBT_PARDINAMICO('BAN_GATEWAY_API');

   V_METODO varchar2(5) := 'POST';
   V_RESULT varchar2(4000);

   V_CON_ERRORES number := 0;
   V_CON_EXITO   number := 0;
   V_HAY_DATOS   varchar2(1) := 'N';
   V_URL         varchar2(4000);

   JSON_RESPUESTA   TYP_JSON;
   JSON_LIST        TYP_JSONLIST;
   JSON_LIS_TARJETA TYP_JSONLIST;
   JSON_TARJETA     TYP_JSONVALUE;
   REG_TARJETA      varchar2(1000);
   LISTA_TARJETA    varchar2(4000);
   NRO_TARJETA      varchar2(50);
   MSJ_BANCARD      varchar2(4000);

   V_MENSAJE_LOG varchar2(4000);
   V_NRO_TARJETA TA_TAR_ENT_MASIVO.NRO_TARJETA%type;

   --procedimiento interno de manejo de respuesta (formateo)
   procedure LP_PRO_RESPUESTA(P_RESPUESTA            varchar2
                             ,P_CODIGOERROR          varchar2
                             ,P_ERROR                varchar2
                             ,P_DESCRIPCIONRESPUESTA varchar2
                             ,P_STATUS_CODE          varchar2) is
      pragma autonomous_transaction; --- para que grabe solo esta transaccion
      V_RESP_JSON TYP_JSON;
      V_RESP_NUM  number;
      V_RESP_ERR  varchar2(4000);
      V_STATUS    varchar2(4000);
      V_DATA      varchar2(4000);
   
      V_RETURNCOD varchar2(4000);
      V_ERRORMSG  varchar2(4000);
   
      V_WS_RESPUESTA      PAW_JSON.JSONSTRUCTOBJ;
      V_WS_RESPUESTA_DATA PAW_JSON.JSONSTRUCTOBJ;
   
   begin
      if P_ERROR != 'S' then
         --controlamos que el servicio responda con éxito (200)
         if P_STATUS_CODE = '200' then
         
            /*TODO: PROCESO DE RESPUESTA*/
            null;
            JSON_RESPUESTA   := TYP_JSON(P_RESPUESTA);
            JSON_RESPUESTA   := PAG_JEX.GET_TYP_JSON(JSON_RESPUESTA, 'data');
            JSON_LIS_TARJETA := PAG_JEX.GET_JSON_LIST(JSON_RESPUESTA, 'response');
         
            for I in 1 .. JSON_LIS_TARJETA.COUNT loop
               V_HAY_DATOS := 'S'; -- hay datos para procesar
               MSJ_BANCARD := null;
               NRO_TARJETA := null;
               V_NRO_TARJETA := null;
               if JSON_LIS_TARJETA.COUNT > 1 then
                  if I != JSON_LIS_TARJETA.COUNT then
                     V_CON_ERROR  := 'SI';
                     JSON_TARJETA := JSON_LIS_TARJETA.GET(I);
                     REG_TARJETA  := JSON_TARJETA.STR;
                     --Tarjeta 4236999334190855 no existe en Maestro de Tarjetas
                     NRO_TARJETA   := SUBSTR(REG_TARJETA, 9, 16);
                     MSJ_BANCARD   := SUBSTR(REG_TARJETA, 25);
                     V_NRO_TARJETA := NRO_TARJETA;
                  
                    
                  
                     /*TODO: ACTUALIZAR EL REGISTRO CON EL MENSAJE DE BANCARD*/
                     --DBMS_OUTPUT.PUT_LINE(I || ' Nro_tarjeta: ' || NRO_TARJETA ||
                     --' - Mensaje:' || MSJ_BANCARD);
                     /*Se actualiza el mensaje recibido de bancard y se marca en fec_gen_lote y hor_gen_lote como generado y procesado*/
                     begin
                        update TA_TAR_ENT_MASIVO T
                           set T.MSJ_RESPUESTAS = T.MSJ_RESPUESTAS || ' | Msj Bancard:' || MSJ_BANCARD
                              ,T.FEC_GEN_LOTE   = V_FECHA
                              ,T.HOR_GEN_LOTE   = V_HORA
                              ,t.est_registro = 'E'
                         where T.NRO_LOTE = P_NRO_LOTE
                           and T.NRO_TARJETA = V_NRO_TARJETA;
                     exception
                        when others then
                           V_RESULT    := 'Error al actualizar mensaje con error: ' ||
                                          sqlerrm;
                           V_CON_ERROR := 'SI*';
                        
                     end;
                  
                  else
                     --registro totalizador de errores y correctos
                     JSON_TARJETA := JSON_LIS_TARJETA.GET(I);
                     REG_TARJETA  := JSON_TARJETA.STR;
                     /*TODO: ACTUALIZAR EL REGISTRO CON EL MENSAJE DE BANCARD*/
                     --DBMS_OUTPUT.PUT_LINE(I || ' ' || REG_TARJETA);
                     /*Se actualiza a con el mensaje de procesado correctamente todos los registros que no se hayan procesado anteriormente como registros con error*/
                     begin
                        update TA_TAR_ENT_MASIVO T
                           set T.MSJ_RESPUESTAS = T.MSJ_RESPUESTAS || ' | ' ||
                                                  'Msj Bancard:Marcado como entregado con éxito'
                              ,T.FEC_GEN_LOTE   = V_FECHA
                              ,T.HOR_GEN_LOTE   = V_HORA
                              ,T.EST_REGISTRO = 'N'
                         where T.NRO_LOTE = P_NRO_LOTE
                           and T.FEC_GEN_LOTE is null
                           and T.HOR_GEN_LOTE is null;
                     exception
                        when others then
                           V_RESULT    := 'Error al actualizar mensaje con error: ' ||
                                          sqlerrm;
                           V_CON_ERROR := 'SI*';
                        
                     end;
                  
                     V_RESULT := REG_TARJETA;
                  end if;
               else
                  /*todo correcto: cuando retorna solo una línea de respuesta totalizador*/
                  --  DBMS_OUTPUT.PUT_LINE('todas las tarjetas correctas');
                  begin
                     update TA_TAR_ENT_MASIVO T
                        set T.MSJ_RESPUESTAS = T.MSJ_RESPUESTAS || ' | ' ||
                                               'Marcado como entregado con éxito'
                      where T.NRO_LOTE = P_NRO_LOTE;
                  exception
                     when others then
                        V_RESULT    := 'Error al actualizar mensaje de éxito: ' || sqlerrm;
                        V_CON_ERROR := 'SI*';
                     
                  end;
               
               end if;
            
            end loop;
         
            --errores que no deben continuar con el proceso de envío se marca con (SI*)
            --el servicio Web no ha respondido satisfactoriamente.(diferente a 200 con errores gestionados en el WS)
         elsif P_STATUS_CODE = '400' then
            --error de formateo de datos en los parámetros enviados
            V_RESULT    := 'Error al utilizar Servicios WEB Bancard Conector: Parámetros de envío inválidos: ' ||
                           P_RESPUESTA;
            V_CON_ERROR := 'SI*';
         elsif P_STATUS_CODE = '404' then
            --Servicio no disponible, servidor de bancarconector caido
            V_RESULT    := 'Error Servicios de conexión a Bancard no disponibles, utilizat operativa contingente';
            V_CON_ERROR := 'SI*';
         elsif P_STATUS_CODE in ('503', '412', '500') then
            V_RESULT    := 'Error al utilizar Servicios WEB Bancard Conector: ' ||
                           P_RESPUESTA;
            V_CON_ERROR := 'SI*';
         else
            --otros errores no soportados
            V_RESULT    := 'Error al utilizar Servicios WEB Bancard: ' ||
                           P_DESCRIPCIONRESPUESTA || '-' || P_CODIGOERROR || '-' || P_ERROR;
            V_CON_ERROR := 'SI*';
         end if;
      
      elsif P_ERROR = 'S' then
         V_CON_ERROR := 'SI*';
         V_RESULT    := 'Error al utilizar Servicios WEB Bancard Conector: ' ||
                        P_DESCRIPCIONRESPUESTA;
      end if;
      commit;
   end LP_PRO_RESPUESTA;
   --procedimiento interno para el registro de los mensajes
   procedure LP_REG_OPERACION(P_MENSAJE   in long
                             ,P_RESPUESTA in varchar2) is
      pragma autonomous_transaction; --- para que grabe solo esta transaccion
      V_RESPUESTA BA_LOG_MENSAJERIA.RESPUESTA%type;
   begin
      V_RESPUESTA := SUBSTR(P_RESPUESTA, 1, 4000);
      insert into BA_LOG_MENSAJERIA
         (MENSAJE
         ,RESPUESTA)
      values
         (P_MENSAJE
         ,V_RESPUESTA);
      commit;
   exception
      when others then
         RAISE_APPLICATION_ERROR(-20000, sqlerrm);
   end;

   /*SE ENVIARÁ DE A 1 REGISTRO AL WS DE BANCARD*/
begin

   /*se prepara el body del mensaje (json de listado de objetos de tarjeta*/
   V_JSON_MENSAJE := TO_CLOB(V_INICIO);
   for C in C_TARJETAS loop
      if V_PRI_REG = 'S' then
         V_JSON_MENSAJE := V_JSON_MENSAJE || C.TARJETA;
         V_PRI_REG      := 'N';
      else
         V_JSON_MENSAJE := V_JSON_MENSAJE || ',' || C.TARJETA;
      end if;
   end loop;
   V_JSON_MENSAJE := V_JSON_MENSAJE || TO_CLOB(V_FIN);

   V_URL := G_URL_ACT_TARJETA || '?' || 'access_token=' || G_API_KEY;
   --enviamos al WebSevice
   V_RESPUESTA := FUE_WSI_ENV_POST(V_JSON_MENSAJE,
                                   V_URL,
                                   'application/json;charset=UTF-8',
                                   V_METODO);

   LP_REG_OPERACION('/' || V_METODO || '/' || V_URL || '/' || V_JSON_MENSAJE,
                    SUBSTR(V_RESPUESTA.ERROR || ' - ' || V_RESPUESTA.CODIGOERROR || ' - ' ||
                           V_RESPUESTA.RESPUESTA,
                           1,
                           4000));
   --procesamos la respuesta
   LP_PRO_RESPUESTA(V_RESPUESTA.RESPUESTA,
                    V_RESPUESTA.CODIGOERROR,
                    V_RESPUESTA.ERROR,
                    V_RESPUESTA.DESCRIPCIONRESPUESTA,
                    V_RESPUESTA.STATUS_CODE);

   --si se procesaron datos
   if V_HAY_DATOS = 'S' then
      if V_CON_ERROR = 'SI*' then
         rollback;
         return V_RESULT;
      elsif V_CON_ERROR = 'SI' then
         commit;
         return 'Procesamiento del Lote Nro: ' || P_NRO_LOTE || ' realizado,' || CHR(10) || V_RESULT || CHR(10) || 'Verificar en consulta dinámica el detalle del error' || CHR(10) || 'Consulta dinámica: TDCENT - INVENTARIO ENTREGAS DE TDC' || CHR(10) || 'Columna MSJ_RESPUESTAS';
      elsif V_CON_ERROR = 'NO' then
         commit;
         return 'Procesamiento del Lote Nro: ' || P_NRO_LOTE || ' realizado exitosamente!' || CHR(10) || 'Verificar registros en Consulta dinámica: TDCENT - INVENTARIO ENTREGAS DE TDC';
      end if;
   else
      -- si no se procesaron datos
      return 'No existen registros a procesar para el Lote Nro:  ' || P_NRO_LOTE|| CHR(10) ||V_RESPUESTA.RESPUESTA
;
   end if;

exception
   when others then
      rollback;
      RAISE_APPLICATION_ERROR(-20000,
                              '*Error al procesar Lote Nro.: ' || P_NRO_LOTE || ' : ' ||
                              sqlerrm);
end FUT_WSI_ENT_TDC_MASIVO;
/

