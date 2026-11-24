CREATE OR REPLACE FUNCTION IT.FUA_WSI_ENV_ARCHIVOS(p_nom_archivo varchar2,
                                                p_fec_hor_cierre date,
                                                p_cod_procesadora varchar2)  
RETURN varchar2 IS

/* Autor:     Sergio Alejandro Servín Arce
   Propuesta: Función para enviar registro de archivos de alta y relación de cuentas
	          de tarjeta de débitos, por medio de Webservices de Bancard
   Fecha:     31/08/2015
   
   OBS: Cargar v_con_error := 'SI*' para los errores que si o si se tienen que realizar ROLLBACK*/
   
-- Proyecto SDBIN8TDD-1 se agrega dos parametros en el curso c_tarjetas a ser enviados en el alta Nro Cta Banco - Empresa
   cursor c_tarjetas is
   select '{"nroCuenta":"' || TRIM(substr(t.registro, 1, 10)) || '", 
          "tipoCuenta":"' || TRIM(substr(t.registro, 11, 1)) || '", 
          "codMoneda":"' || TRIM(substr(t.registro, 12, 3)) || '", 
          "nroAdherente":"' || TRIM(substr(t.registro, 15, 2)) || '", 
          "nroEmision":"' || TRIM(substr(t.registro, 17, 2)) || '", 
          "nroSucursal":"' || TRIM(substr(t.registro, 19, 2)) || '", 
          "tipoPersona":"' || TRIM(substr(t.registro, 21, 1)) || '", 
          "nombrePlastico":"' || TRIM(substr(t.registro, 22, 26)) || '", 
          "nombre1":"' || TRIM(substr(t.registro, 48, 20)) || '", 
          "nombre2":"' || TRIM(substr(t.registro, 68, 20)) || '", 
          "apellido1":"' || TRIM(substr(t.registro, 88, 20)) || '", 
          "apellido2":"' || TRIM(substr(t.registro, 108, 20)) || '", 
          "razonSocial":"' || TRIM(substr(t.registro, 128, 30)) || '", 
          "fecVencimiento":"' || TRIM(substr(t.registro, 158, 6)) || '", 
          "usuDomicilio":"' || TRIM(substr(t.registro, 164, 60)) || '", 
          "usuLocalidad":"' || TRIM(substr(t.registro, 224, 40)) || '", 
          "usuTel":"' || TRIM(substr(t.registro, 264, 25)) || '", 
          "tipoDocumento":"' || TRIM(substr(t.registro, 289, 3)) || '", 
          "nroDocumento":"' || TRIM(substr(t.registro, 292, 16)) || '", 
          "codFormatEmbozado":"' ||
         TRIM(substr(t.registro, 308, 6)) || '", 
          "nroSecuencia":"' || TRIM(substr(t.registro, 314, 3)) || '", 
          "subNroSecuencia":"' || TRIM(substr(t.registro, 317, 7)) || '", 
          "tipoAccion":"' || TRIM(substr(t.registro, 324, 1)) || '", 
          "ctaBanco":"' || TRIM(substr(t.registro, 325, 15))|| '", 
          "empresa":"' || TRIM(substr(t.registro, 340, 26))
          || '"}' JSON_regs,
         rowid registro,
         t.cod_persona,
         t.nro_cuenta,
         t.relacion
  
    from AH_TAR_DEB_SOL_WS t
  
   where t.registro is not null
     and t.Nom_Archivo = p_nom_archivo
     AND T.FEC_ENVIO is null--los que no fueron enviados satisfactoriamente
     and t.hor_envio is null--los que no fueron enviados satisfactoriamente
     AND T.FEC_HOR_CIERRE = p_fec_hor_cierre
     AND T.COD_PROCESADORA = p_cod_procesadora;

   cursor c_relcuentas is
   select '{"nroCuentaPrincipal":"'||TRIM(substr(t.registro,1,10))||'",
          "nroAdherente":"'||TRIM(substr(t.registro,11,2))||'",
          "codFormatEmbozado":"'||TRIM(substr(t.registro,13,6))||'",
          "nroCuentaSecundaria":"'||TRIM(substr(t.registro,19,10))||'",
          "tipoCuentaSecundaria":"'||TRIM(substr(t.registro,29,1))||'",
          "codMonedaSecundaria":"'||TRIM(substr(t.registro,30,3))||'",
          "tipoAccion":"'||TRIM(substr(t.registro,33,1))||'"}' JSON_regs,
         rowid registro,
         t.nro_cuenta
         
   from AH_TAR_DEB_SOL_WS t
  
   where t.registro is not null
     and t.Nom_Archivo = p_nom_archivo
     AND T.FEC_ENVIO is null--los que no fueron enviados satisfactoriamente
     and t.hor_envio is null--los que no fueron enviados satisfactoriamente
     AND T.FEC_HOR_CIERRE = p_fec_hor_cierre
     AND T.COD_PROCESADORA = p_cod_procesadora;


    v_inicio varchar2(10) := '[';
    v_fin    varchar2(10) := ']';
    v_json   clob;

    v_con_error varchar2(3):= 'NO';

    v_respuesta TYP_POSTRESPUESTACLOB;
    --
    g_url_gateway         ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('BAN_GATEWAY_URL');
    g_url_servicio        ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('BAN_URL_SER_ALTA');
    g_url_apikey          ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('BAN_GATEWAY_API');
    g_url_relcuenta       ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('WSI_REL_CUENTAS');
    g_url_abm_tarjeta    varchar2(2000);
    --
    v_metodo    VARCHAR2(5) := 'POST';
    v_result varchar2(4000);

    v_con_errores number:=0;
    v_con_exito number:=0;
    v_hay_datos varchar2(1):='N';

    --procedimiento interno de manejo de respuesta (formateo)
    procedure lp_pro_respuesta(p_respuesta varchar2,
                               p_codigoError varchar2,
                               p_error varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code varchar2,
                               p_reg_enviado rowid,
                               p_nro_cuenta varchar2,
                               p_cod_persona varchar2,
                               p_adherente varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    v_resp_json typ_json;
    v_resp_num number;
    v_resp_err varchar2(4000);

    begin
       if p_error != 'S' then
          --controlamos que el servicio responda con éxito (200)                
          if p_status_code = '200' then
             v_resp_json := typ_json(p_respuesta);--convertimos a json la respuesta -> estructura json {"result":"999"}
             --Un error suele ser la respuesta {"result":"Usuario/ContraseÃ±a Inactiva"}
             --entonces tratar la respuesta como char
             if length(pag_jex.get_string(v_resp_json, 'result')) > 3 then--respuesta caracter
                v_resp_num := null;--para captuar el error marcamos a null
             else
                v_resp_num := to_number(pag_jex.get_string(v_resp_json, 'result'));--obtenemos el nro de respuesta  
             end if;
             
             
             --v_resp_num = 0 (Sin errores) mayor a 0 (con errores)--se le encamina al usuario para que revise en bancard
             if v_resp_num > 0 then
                v_con_error:='SI';--se marca que en el proceso existe errores de envío de registros.
                v_con_errores:= v_con_errores+v_resp_num;
                --se actualiza que posee (v_resp_num) errores el registro enviado
                begin
                   update Ah_Tar_Deb_Sol_Ws t 
                   set t.det_error = 'Error al enviar registro, contiene ('||v_resp_num||') errores.',
                       t.fec_envio = null,
                       t.hor_envio = null
                   where t.rowid = p_reg_enviado;
                exception
                   when others then
                      RAISE_APPLICATION_ERROR(-20000,'Error: Al actualizar datos de registros enviados: '||SQLERRM); 
                end;
                commit;
             --sin errores 
             elsif v_resp_num = 0 then
                v_con_exito:=v_con_exito+1;--acumulamos registros enviados correctamente
                --asignamos la fecha y hora de envío del registro exitoso
                begin
                   update Ah_Tar_Deb_Sol_Ws t 
                   set t.fec_envio = SYSDATE,-- to_Date(to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'),'DD/MM/YYYY'),
                       t.hor_envio = to_char(sysdate,'hh24:mi'),
                       t.det_error = null
                   where t.rowid = p_reg_enviado;
                exception
                   when others then
                      RAISE_APPLICATION_ERROR(-20000,'Error: Al actualizar datos de registros enviados*: '||SQLERRM); 
                end;

                --ACtualizamos a enviado en ah_tar_debitos o ah_tar_deb_cuentas
                
                if p_nom_archivo = 'TARDEBITO' THEN
                   begin
                      update ah_tar_debitos t
                         set cod_est_solicitud = 4--marca como enviado.
                       where t.fec_envio  = TO_DATE(p_fec_hor_cierre,'dd/mm/rrrr hh24:mi:ss') 
                         and t.cod_ent_procesadora = p_cod_procesadora
                         and t.cod_est_solicitud in(4,5)
                         and t.nro_cuenta = p_nro_cuenta
                         and t.cod_persona = p_cod_persona
                         and t.adherente = p_adherente;
                   exception
                   when others then
                      RAISE_APPLICATION_ERROR(-20000,'Error: Al actualizar datos de ah_tar_debitos: '||SQLERRM);
                   end;                

                elsif p_nom_archivo = 'RELCUENTA' THEN
                   begin
                      update ah_tar_deb_cuentas t
                         set t.Enviado = 'S'--marca como enviado.
                       where t.fec_envio  = TO_DATE(p_fec_hor_cierre,'dd/mm/rrrr hh24:mi:ss')  
                         and t.cod_ent_procesadora = p_cod_procesadora
                         and nvl(t.enviado,'N') = 'N' 
                         and t.nro_cuenta = p_nro_cuenta;
                   exception
                   when others then
                      RAISE_APPLICATION_ERROR(-20000,'Error: Al actualizar datos de ah_tar_deb_cuentas: '||SQLERRM);
                   end;   
                end if;
                
                commit;
             elsif v_resp_num is null then
                v_con_error:='SI*';  
                v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||pag_jex.get_string(v_resp_json, 'result'); 
             end if;
             
          --errores que no deben continuar con el proceso de envío se marca con (SI*)
          --el servicio Web no ha respondido satisfactoriamente.(diferente a 200 con errores gestionados en el WS)
          elsif p_status_code ='400' then--error de formateo de datos en los parámetros enviados
             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: Parámetros de envío inválidos: '||p_respuesta;
             v_con_error:='SI*';
          elsif p_status_code ='404' then--Servicio no disponible, servidor de bancarconector caido
             v_result:= 'Error Servicios de conexión a Bancard no disponibles, utilizat operativa contingente';
             v_con_error:='SI*';
          elsif p_status_code in('503','412','500') then--errores soportados en BancardConector
             v_resp_json := typ_json(p_respuesta);
             v_resp_err := pag_jex.get_string(v_resp_json, 'msgError');--obtenemos el mensaje de error
             
             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||v_resp_err;
             v_con_error:='SI*';
                
             if p_status_code = '503' then
                v_result := 'Error, Servicios Web de Bancard Inactivos.';
             end if;        
          else--otros errores no soportados
             v_result:= 'Error al utilizar Servicios WEB Bancard: '||p_descripcionRespuesta||'-'||p_codigoError||'-'||p_error;   
             v_con_error:='SI*';
          end if;
       
                
       elsif p_error = 'S' then
          v_con_error:='SI*';
          v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||p_descripcionRespuesta;
       end if;
    end lp_pro_respuesta;
    --procedimiento interno para el registro de los mensajes
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

/*SE ENVIARÁ DE A 1 REGISTRO AL WS DE BANCARD*/
BEGIN


   IF p_nom_archivo = 'TARDEBITO' THEN--ABMTARJETAS

      for c in c_tarjetas loop
         v_hay_datos:= 'S' ;
         g_url_abm_tarjeta := g_url_gateway||g_url_servicio||'?access_token='|| g_url_apikey;
         v_json      := to_clob(v_inicio)|| c.JSON_regs ||to_clob(v_fin);--FORMATEO ARRAY JSON [{objeto}]

         --enviamos al WebSevice
         v_respuesta := FUA_WSI_ENV_POST(v_json, g_url_abm_tarjeta, v_metodo);

         -- bitacora de logs
         lp_reg_operacion('/'||v_metodo||'/'||g_url_abm_tarjeta||'/'||v_json, substr(v_respuesta.error || ' - ' ||    
         v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
         --procesamos la respuesta
         lp_pro_respuesta(v_respuesta.respuesta,
                          v_respuesta.codigoError,
                          v_respuesta.error,
                          v_respuesta.descripcionRespuesta,
                          v_respuesta.status_code,
                          c.registro,
                          c.nro_cuenta,
                          c.cod_persona,
                          c.relacion);
         if v_con_error = 'SI*' then
            exit;
         end if;
                                
      end loop;

   ELSIF p_nom_archivo = 'RELCUENTA' THEN--RELACIÓN DE CUENTAS

      for c in c_relcuentas loop
         v_hay_datos := 'S';
         v_json      := to_clob(v_inicio)|| c.JSON_regs ||to_clob(v_fin);--FORMATEO ARRAY JSON [{objeto}]

         --enviamos al WebSevice
         v_respuesta := FUA_WSI_ENV_POST(v_json, g_url_relcuenta, v_metodo);

         -- bitacora de logs
         lp_reg_operacion('/'||v_metodo||'/'||g_url_relcuenta||'/'||v_json, substr(v_respuesta.error || ' - ' ||    
         v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
         --procesamos la respuesta
         lp_pro_respuesta(v_respuesta.respuesta,
                          v_respuesta.codigoError,
                          v_respuesta.error,
                          v_respuesta.descripcionRespuesta,
                          v_respuesta.status_code,
                          c.registro,
                          c.nro_cuenta,
                          null,
                          null);
         if v_con_error = 'SI*' then
            exit;
         end if;
          
      end loop;    

   END IF;

   --si se procesaron datos
   IF v_hay_datos = 'S' THEN
      if v_con_error = 'SI*' then
         ROLLBACK;
         return v_result;
      elsif v_con_error = 'SI' then
         COMMIT;
         return 'Envío de archivo '||p_nom_archivo||' realizado, (Registros correctos ('||v_con_exito||'), Registros incorrectos ('||v_con_errores||') Ver en pantalla Azul de bancard Los datos incorrectos';
      elsif v_con_error = 'NO' then
         commit;
         return 'Envío de archivo '||p_nom_archivo||' realizado exitosamente!';
      end if;
   ELSE-- si no se procesaron datos
      return 'No existen registros de '||p_nom_archivo||' a enviar';   
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20000, '*Error al enviar archivo '||p_nom_archivo||' : '||SQLERRM); 
END FUA_WSI_ENV_ARCHIVOS;
/

