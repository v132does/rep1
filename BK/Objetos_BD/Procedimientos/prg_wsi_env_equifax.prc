CREATE OR REPLACE PROCEDURE IT.PRG_WSI_ENV_EQUIFAX  (P_NOM_ARCHIVO IN VARCHAR2 DEFAULT NULL,
                                                  P_TIP_PROCESO IN VARCHAR2 DEFAULT NULL) IS
  v_con_error     varchar2(3)   := 'NO';
  v_respuesta     TYP_POSTRESPUESTACLOB;
  v_url           varchar2(500) := fug_obt_pardinamico('EQU_URL_WSI_ENV_DATOS');
  v_result        varchar2(4000);
  v_metodo        VARCHAR2(5)   := 'POST';
  v_dir_mail      VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  v_conn          utl_smtp.connection;
  v_para          VARCHAR2(3000):= fug_obt_pardinamico ('DIR_MAIL_EQUIFAX');
  v_asunto        VARCHAR2(2000);
  v_mje_mail      VARCHAR2(4000);
  v_hini_mail     ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail     ge_ra_log_mail.hor_fin%type;
  v_det_error     ge_ra_log_mail.det_error%type;
  v_Date          date;--para reintentar el envio en caso de error
  v_can_intentos  number := 0;
  v_fec_actual    date := pag_cal.FU_OBT_FEC_ACTUAL(1);
  CURSOR DATOS IS
    Select '{"fecha": "'       ||a.fecha        ||'",
             "tipPersona": "'  ||a.tip_persona  ||'",
             "nomArchivo": "'  ||a.nom_archivo  ||'",
             "estado": "'      ||a.estado       ||'",
             "tipOperacion": "'||a.tip_operacion||'",
             "comentario": "'  ||null           ||'",
             "md5": "'         ||null           ||'"}' w_datos,
             a.*,
             rowid registro
      from ge_equ_datos a
     where a.estado <> 'N'
       and nvl(DECODE(P_NOM_ARCHIVO,'TODOS',NULL,P_NOM_ARCHIVO),a.nom_archivo) = a.nom_archivo
       and nvl(P_TIP_PROCESO,a.tip_proceso) = a.tip_proceso;

    --procedimiento interno para el registro de los mensajes
     PROCEDURE LP_REG_OPERACION(p_mensaje   IN LONG,
                                p_respuesta IN VARCHAR2) is
       PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
       v_respuesta ba_log_mensajeria.respuesta%type;
     BEGIN
       v_respuesta := substr(p_respuesta, 1, 4000);
       insert into ba_log_mensajeria(mensaje    ,
                                     respuesta  )
                              values(p_mensaje  ,
                                     v_respuesta);
       commit;
     EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000, sqlerrm);
     END;

     --procedimiento interno de manejo de respuesta (formateo)
    procedure lp_pro_respuesta(p_respuesta            varchar2,
                               p_codigoError          varchar2,
                               p_error                varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code          varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    v_resp_json  typ_json;
    v_resp_err   varchar2(4000);
    v_xml        xmltype;
    v_cod_error  varchar2(5);
    v_msn_error  varchar2(1000);
    begin
       if p_error != 'S' then
          --controlamos que el servicio responda con éxito (200)
          if p_status_code = '200' then
             v_resp_json := typ_json(p_respuesta);
             v_xml := xmltype.createxml(pag_jex.get_string(v_resp_json,'data'));
             
             IF v_xml.extract('/WSUpload/Resultado/text()') is not null THEN
                IF v_xml.extract('/WSUpload/Resultado/text()').getStringVal() = 'Transaccion Fallida' THEN
                    v_con_error := 'SI';
                    v_cod_error := v_xml.extract('/WSUpload/Resultado/Datos/CodError/text()').getStringVal();
                    v_msn_error := v_xml.extract('/WSUpload/Resultado/Datos/Error/text()').getStringVal();
                    v_result    := 'Error '||v_cod_error||': '||v_msn_error;
                End If;
             End IF;
          elsif p_status_code ='400' then
             v_result    := 'Error al utilizar Servicios del Conector: Parámetros de envío inválidos: '||p_respuesta;
             v_con_error :='SI';
          elsif p_status_code ='404' then
             v_result    := 'Servicios de conexión a Equifax no disponibles';
             v_con_error :='SI';
          elsif p_status_code in('503','412','500') then
             v_resp_json := typ_json(p_respuesta);
             v_resp_err  := pag_jex.get_string(v_resp_json, 'msgError');
             v_result    := 'Error al utilizar Servicios WEB Equifax Conector: '||v_resp_err;
             v_con_error :='SI';

             if p_status_code = '503' then
                v_result := 'Error, Servicios Web de Equifax Inactivos.';
             end if;
          else--otros errores no soportados
             v_result    := 'Error al utilizar Servicios WEB Equifax: '||p_descripcionRespuesta||'-'||p_codigoError||'-'||p_error;
             v_con_error :='SI';
          end if;
       elsif p_error = 'S' then
          v_con_error :='SI';
          v_result    := 'Error al utilizar Servicios WEB Equifax Conector: '||p_descripcionRespuesta;
       end if;
    end LP_PRO_RESPUESTA;

BEGIN
  FOR c IN DATOS LOOP
      <<REINTENTAR>>
      v_respuesta := fug_wsi_env_equifax(c.w_datos ,
                                         v_url   ,
                                         v_metodo);
       -- bitacora de logs
       lp_reg_operacion(c.nom_archivo||' : '||c.tip_proceso,
                        substr(v_respuesta.error || ' - ' ||v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
       
       --procesamos la respuesta
       lp_pro_respuesta(v_respuesta.respuesta           ,
                        v_respuesta.codigoError         ,
                        v_respuesta.error               ,
                        v_respuesta.descripcionRespuesta,
                        v_respuesta.status_code         );
       If v_con_error = 'SI' Then
          If v_can_intentos < fug_obt_pardinamico('CAN_INT_ENV_EQUIFAX') Then
             v_can_intentos := v_can_intentos + 1;
             v_Date         := pai_int.smg_sleep(fug_obt_pardinamico('TIE_ESP_ENV_EQUIFAX'));
             GOTO REINTENTAR;
          Else-- Enviar correo
              v_can_intentos := 0;
              -- Damos valor a los demas datos
              v_asunto     := 'EQUIFAX: Existen Errores en el proceso de envío de datos: '||pag_cal.FU_OBT_FEC_ACTUAL(1)||'.';
              v_mje_mail   := 'El archivo '|| c.nom_archivo||'.'||c.tip_archivo ||' contiene el siguiente error : '||v_result;
              v_det_error  := null;
              v_hini_mail  := to_char(sysdate,'hh24:mi:ss');
              BEGIN
                 v_conn := it_mail.begin_mail(v_dir_mail  ,
                                              v_para      ,
                                              v_asunto    ,
                                              it_mail.multipart_mime_type);
                 it_mail.attach_text(v_conn      ,
                                     v_mje_mail  ,
                                     'text/plain');
                 it_mail.end_mail(v_conn);
              EXCEPTION
                when utl_smtp.transient_error or utl_smtp.permanent_error then
                    begin
                        utl_smtp.quit(v_conn);
                    exception
                        when utl_smtp.transient_error or utl_smtp.permanent_error then
                             null;
                    end;
                    v_det_error := substr(sqlerrm,1,4000);
              END;
              v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
              -- Marcamos el registro con error.-
              BEGIN
                 update GE_EQU_DATOS t
                    set t.estado = 'E',
                        t.error  = v_result
                  where t.rowid  = c.registro;
              EXCEPTION
                 when others then
                      raise_application_error(-20000,'Error: Al actualizar datos de registros enviados: '||SQLERRM);
              END;
              -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
              IF v_det_error is not null THEN
                  INSERT INTO ge_ra_log_mail (fec_envio  , 
                                              nom_archivo, 
                                              dir_correo , 
                                              mensaje    , 
                                              det_error  , 
                                              hor_inicio , 
                                              hor_fin    )
                                      VALUES (SYSDATE      , 
                                              c.nom_archivo, 
                                              v_para       , 
                                              v_asunto     , 
                                              v_det_error  , 
                                              v_hini_mail  , 
                                              v_hfin_mail  );
                  COMMIT;
              END IF;
          End If;
       Else -- No Hubo Errores
           Begin
               update ge_equ_datos a 
                  set a.estado     = 'N',
                      a.comentario = 'Proceso Satisfactorio'
                where a.rowid = c.registro;
           Exception
                When Others Then
                     raise_application_error(-20000,'Error al actualizar registro procesado correctamente '||sqlerrm);
           End;
           COMMIT;
           Begin
                insert into ge_equ_datos_his (fecha          ,
                                              hora           ,
                                              num_cliente    ,
                                              datos          ,
                                              tip_persona    ,
                                              nom_archivo    ,
                                              tip_operacion  ,
                                              comentario     ,
                                              tip_archivo    ,
                                              dat_base64     ,
                                              tip_proceso    ,
                                              estado         ,
                                              error          )
                                       values(v_fec_actual   ,
                                              to_char(sysdate,'HH24:MM:SS'),
                                              c.num_cliente  ,
                                              c.datos        ,
                                              c.tip_persona  ,
                                              c.nom_archivo  ,
                                              c.tip_operacion,
                                              c.comentario   ,
                                              c.tip_archivo  ,
                                              c.dat_base64   ,
                                              c.tip_proceso  ,
                                              'N'            ,
                                              'Proceso Satisfactorio');
           Exception
                  When Others Then
                       raise_application_error(-20000,'Error Traslando datos al histórico PRG_WSI_ENV_EQUIFAX. '||sqlerrm);
           End;
           COMMIT;
           delete ge_equ_datos x where x.rowid = c.registro;
       End if;
  END LOOP;
EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20000,'Error en PRG_WSI_ENV_EQUIFAX '||sqlerrm);
END;
/

