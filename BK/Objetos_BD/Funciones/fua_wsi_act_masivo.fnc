create or replace function it.FUA_WSI_ACT_MASIVO(P_NRO_LOTE varchar2) return varchar2 is

   /* Autor:     Sergio Alejandro Servín Arce
   Propuesta: Función para activar / desactivar de tarjeta de débitos, por medio de Webservices de Bancard
   Fecha:     17/12/2020

   OBS: Cargar v_con_error := 'SI*' para los errores que si o si se tienen que realizar ROLLBACK*/
   
  --Proyecto SDBIN8TDD-1: se agrega la funcion fua_obt_cta_ficticia para enviar ese valor para las tdd de mastercard
   cursor C_TARJETAS is
      select T.NRO_CUENTA NRO_CTA_CORE
            ,nvl(fua_obt_cta_ficticia(t.nro_cuenta, t.nro_bin),PAG_SUE.FU_COD_CUENTA(T.NRO_CUENTA)) NRO_CTA_BANCARD
            ,T.NRO_BIN
            ,SUBSTR(TD.NRO_TARJETA, -1) DV
            ,T.ADHERENTE
            ,T.NRO_EMISION
            ,DECODE(T.TIP_PROCESO, 'I', 'D', 'T', 'A') ACCION
            ,'I' INDIVIDUAL
            ,DECODE(T.TIP_PROCESO, 'I', '6', 'T', null) COD_BLOQUEO
            ,T.ROWID REGISTRO
            ,T.COD_PERSONA
        from AH_TAR_DEB_MASIVO T
            ,AH_TAR_DEBITOS    TD
       where T.NRO_LOTE = P_NRO_LOTE
        -- and T.EST_LOTE = 'P' --lote procesado sin error
         and TD.NRO_CUENTA = T.NRO_CUENTA
         and TD.ADHERENTE = T.ADHERENTE
         and TD.NRO_EMISION = T.NRO_EMISION
         and TD.NRO_BIN = T.NRO_BIN
         and T.TIP_TAR_DEBITO NOT IN ('M','P') --distinto a MASTERCARD 8 bines
         UNION
        select fua_obt_cta_cliente(T.NRO_CUENTA, T.NRO_BIN) NRO_CTA_CORE
            ,T.NRO_CUENTA NRO_CTA_BANCARD
            ,T.NRO_BIN
            ,SUBSTR(TD.NRO_TARJETA, -1) DV
            ,T.ADHERENTE
            ,T.NRO_EMISION
            ,DECODE(T.TIP_PROCESO, 'I', 'D', 'T', 'A') ACCION
            ,'I' INDIVIDUAL
            ,DECODE(T.TIP_PROCESO, 'I', '6', 'T', null) COD_BLOQUEO
            ,T.ROWID REGISTRO
            ,T.COD_PERSONA
        from AH_TAR_DEB_MASIVO T
            ,AH_TAR_DEBITOS    TD
       where T.NRO_LOTE = P_NRO_LOTE
        -- and T.EST_LOTE = 'P' --lote procesado sin error
         and TD.NRO_CUENTA = fua_obt_cta_cliente(T.NRO_CUENTA, T.NRO_BIN)
         and TD.ADHERENTE = T.ADHERENTE
         and TD.NRO_EMISION = T.NRO_EMISION
         and T.NRO_BIN = TD.NRO_BIN
         and T.TIP_TAR_DEBITO IN ('M','P') -- MASTERCARD 8 bines
		 order by REGISTRO;
   V_FECHA      date := PAG_CAL.FU_OBT_FEC_ACTUAL(3);
   V_HORA       varchar2(8);
   V_PARAMETROS varchar2(4000);
   --V_INICIO     varchar2(10) := '[';
   --V_FIN        varchar2(10) := ']';
   --V_JSON       clob;
   
   V_CON_ERROR varchar2(3) := 'NO';
   
   V_RESPUESTA       TYP_POSTRESPUESTACLOB;
   V_RESPOST         TYP_POSTRESPUESTA;
   G_URL_ACT_TARJETA GE_PAR_DINAMICOS.VAL_PARAMETRO%type := FUG_OBT_PARDINAMICO('BAN_GATEWAY_URL') ||
                                                            FUG_OBT_PARDINAMICO('BAN_URL_SERVICIO');
   G_API_KEY         GE_PAR_DINAMICOS.VAL_PARAMETRO%type := FUG_OBT_PARDINAMICO('BAN_GATEWAY_API');

   V_METODO varchar2(5) := 'POST';
   V_RESULT varchar2(4000);

   V_CON_ERRORES number := 0;
   V_CON_EXITO   number := 0;
   V_HAY_DATOS   varchar2(1) := 'N';

   --procedimiento interno de manejo de respuesta (formateo)
   procedure LP_PRO_RESPUESTA(P_RESPUESTA            varchar2
                             ,P_CODIGOERROR          varchar2
                             ,P_ERROR                varchar2
                             ,P_DESCRIPCIONRESPUESTA varchar2
                             ,P_STATUS_CODE          varchar2
                             ,P_REG_ENVIADO          rowid
                             ,P_NRO_CUENTA           varchar2
                             ,P_COD_PERSONA          varchar2) is
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

            V_WS_RESPUESTA := PAW_JSON.STRING2JSON(V_RESPOST.RESPUESTA, '"');
            V_STATUS       := PAW_JSON.GETATTRVALUE(V_WS_RESPUESTA, 'status');
            V_DATA         := PAW_JSON.GETATTRVALUE(V_WS_RESPUESTA, 'data');

            V_WS_RESPUESTA_DATA := PAW_JSON.STRING2JSON(V_DATA, '"');
            V_RETURNCOD         := PAW_JSON.GETATTRVALUE(V_WS_RESPUESTA_DATA, 'returnCod');
            V_ERRORMSG          := PAW_JSON.GETATTRVALUE(V_WS_RESPUESTA_DATA, 'errorMsg');

            if V_RETURNCOD = '00' then
               -- Sin errores
               V_CON_EXITO := V_CON_EXITO + 1;
               begin
                  update AH_TAR_DEB_MASIVO Y
                     set Y.MSJ_REGISTRO = Y.MSJ_REGISTRO||' | Bancard Msj: ' || V_ERRORMSG
                        ,Y.EST_LOTE     = 'G' --GENERADO--
                        ,y.est_registro = 'N'--NORMAL
                        ,Y.FEC_GEN_LOTE = V_FECHA
                        ,Y.HOR_GEN_LOTE = V_HORA
                        --,Y.ind_env_bancard = 'S'
                   where Y.ROWID = P_REG_ENVIADO;
               exception
                  when others then
                     RAISE_APPLICATION_ERROR(-20000,
                                             '*Error: Al actualizar datos de registros enviados: ' ||
                                             sqlerrm);
               end;
            else
               --con errores
               V_CON_ERROR   := 'SI';
               V_CON_ERRORES := V_CON_ERRORES + 1;
               begin
                  update AH_TAR_DEB_MASIVO T
                     set T.MSJ_REGISTRO = t.MSJ_REGISTRO||' | Bancard Msj: ' || V_ERRORMSG
                        ,T.EST_REGISTRO = 'E' --ERROR
                        ,T.FEC_GEN_LOTE = V_FECHA
                        ,T.HOR_GEN_LOTE = V_HORA
                        --,T.ind_env_bancard = 'S'
                   where T.ROWID = P_REG_ENVIADO;
               exception
                  when others then
                     RAISE_APPLICATION_ERROR(-20000,
                                             'Error: Al actualizar datos de registros enviados: ' ||
                                             sqlerrm);
               end;
            end if;

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

   for C in C_TARJETAS loop
      V_HORA      := TO_CHAR(sysdate, 'HH24:MI:SS');
      V_HAY_DATOS := 'S';
      --V_JSON      := TO_CLOB(V_INICIO) || C.JSON_REGS || TO_CLOB(V_FIN); --FORMATEO ARRAY JSON [{objeto}]

      V_PARAMETROS := UTL_LMS.FORMAT_MESSAGE('access_token=%s'||'&'||'nro_cuenta=%s'||'&'||'nro_bin=%s'||'&'||'dig_ver=%s'||'&'||'nro_adh=%s'||'&'||'nro_emi=%s'||'&'||'accion=%s'||'&'||'todos=%s'||'&'||'motivo_blo_cod=%s',
                                             G_API_KEY,
                                             C.NRO_CTA_BANCARD,
                                             C.NRO_BIN,
                                             C.DV,
                                             C.ADHERENTE,
                                             C.NRO_EMISION,
                                             C.ACCION,
                                             C.INDIVIDUAL,
                                             C.COD_BLOQUEO);

      --enviamos al WebSevice
      V_RESPOST := FUE_ENV_POST(P_PARAMETROS => V_PARAMETROS, P_URL => G_URL_ACT_TARJETA);

      -- bitacora de logs
      LP_REG_OPERACION('/' || V_METODO || '/' || G_URL_ACT_TARJETA || '/' || V_PARAMETROS,
                       SUBSTR(V_RESPUESTA.ERROR || '-' || V_RESPUESTA.CODIGOERROR || '-' ||
                              V_RESPUESTA.STATUS_CODE || '-' || V_RESPOST.RESPUESTA,
                              1,
                              4000));
      --procesamos la respuesta
      LP_PRO_RESPUESTA(V_RESPOST.RESPUESTA,
                       V_RESPOST.CODIGOERROR,
                       V_RESPOST.ERROR,
                       V_RESPOST.DESCRIPCIONRESPUESTA,
                       V_RESPOST.STATUS_CODE,
                       C.REGISTRO,
                       C.NRO_CTA_CORE,
                       C.COD_PERSONA);
      if V_CON_ERROR = 'SI*' then
         exit;
      end if;

   end loop;

   --si se procesaron datos
   if V_HAY_DATOS = 'S' then
      if V_CON_ERROR = 'SI*' then
         rollback;
         return V_RESULT;
      elsif V_CON_ERROR = 'SI' then
         commit;
         return 'Procesamiento del Lote Nro: ' || P_NRO_LOTE || ' realizado, (Registros correctos (' || V_CON_EXITO || '), Registros incorrectos (' || V_CON_ERRORES || ')' || CHR(10) || 'Verificar en consulta dinámica el detalle del error' || CHR(10) || 'Consulta dinámica: TARDEB - INVENTARIO PROCESO MASIVO TARJETA DE DEBITO' || CHR(10) || 'Columna MSJ_REGISTRO';
      elsif V_CON_ERROR = 'NO' then
         commit;
         return 'Procesamiento del Lote Nro: ' || P_NRO_LOTE || ' realizado exitosamente!' || CHR(10) || 'Verificar registros en Consulta dinámica: TARDEB - INVENTARIO PROCESO MASIVO TARJETA DE DEBITO';
      end if;
   else
      -- si no se procesaron datos
      return 'No existen registros a procesar para el Lote Nro:  ' || P_NRO_LOTE;
   end if;

exception
   when others then
      rollback;
      RAISE_APPLICATION_ERROR(-20000,
                              '*Error al procesar Lote Nro.: ' || P_NRO_LOTE || ' : ' ||
                              sqlerrm);
end FUA_WSI_ACT_MASIVO;
/

