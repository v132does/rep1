CREATE OR REPLACE FUNCTION IT.FUA_WSI_DES_PINES(p_cod_procesadora varchar2)
 RETURN varchar2 IS
/* Autor:     Sergio Alejandro Servín Arce
   Propuesta: Función para desencriptar pines TDD de Bancard, por medio de Webservices          
   Fecha:     31/08/2015
   
   OBS: Cargar v_con_error := 'SI*' para los errores que si o si se tienen que realizar ROLLBACK*/
  v_exc_cue_error ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CTA_ERR_DES_PINES');
 cursor c_pines is
    select '{"data":"'||t.registro||'"}' registro,
           ROWID FILA
    from AH_TAR_DEB_PINES t
    where length(t.pin_encriptado) = 15
    and   t.det_error is null
    and   instr(nvl(v_exc_cue_error,'0'),t.nro_cuenta) = 0 
    order by nro_cuenta;
 
 v_respuesta TYP_POSTRESPUESTACLOB;
 g_url       ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('WSI_DESENC_PINES');
 v_metodo    VARCHAR2(5) := 'POST';


 v_result varchar2(4000);

 v_aux varchar2(4000);
 v_pin_desencriptado varchar2(4);
 v_con_error varchar2(3):= 'NO';

 v_resp_linea varchar2(4000);
 v_resp_err_pass varchar2(4000);
 v_resp_err_mesg varchar2(4000);
 v_cant_pines number:=0;
 v_lugar varchar2(4000);


--procedimiento interno de manejo de respuesta (formateo)
    procedure lp_pro_respuesta(p_respuesta varchar2,
                               p_codigoError varchar2,
                               p_error varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code varchar2,
                               p_reg_enviado rowid) is
    v_resp_json typ_json;
    
    v_resp_err varchar2(4000);

    begin

       if p_error != 'S' then
          --controlamos que el servicio responda con éxito (200)                
          if p_status_code = '200' then
             --convertimos a json la respuesta -> estructura json {"errorPas":"","msgError":"","linea":"ASDASD...N"}
             v_resp_json := typ_json(p_respuesta);
             --obtenemos los campos
             v_resp_linea := pag_jex.get_string(v_resp_json, 'linea');--obtenemos la linea
             v_resp_err_pass:= pag_jex.get_string(v_resp_json, 'errorPas');--obtenemos la linea
             v_resp_err_mesg:= pag_jex.get_string(v_resp_json, 'msgError');--obtenemos la linea
             
             --si no se tiene errores y se obtiene respuesta
             if v_resp_err_pass is null 
                and v_resp_err_mesg is null 
                and v_resp_linea is not null then
                
                --obtenemos el pin desencriptado
                pra_tar_deb_rec_archivo(v_resp_linea,
                                        p_cod_procesadora,
                                        v_aux,
                                        v_aux,
                                        v_aux,
                                        v_aux,
                                        v_aux,
                                        v_aux,
                                        v_aux,
                                        v_pin_desencriptado);
                
                --guardamos encriptado en tabla de pines CON LA ENCRIPTACIÓN DE ITGF
                begin
                   UPDATE AH_TAR_DEB_PINES T SET T.PIN_ENCRIPTADO = pag_gen.fu_enc_pin(v_pin_desencriptado) 
                   WHERE T.ROWID = p_reg_enviado;
                exception
                when others then
                   v_con_error:='SI*';
                   v_result := '01-Error al guardar el pin encriptado:'||sqlerrm;
                end;                        

             else
                v_con_error:='SI*';
                v_result:='02-Error: '||v_resp_err_mesg;
             end if;
  
          --errores que no deben continuar con el proceso de envío se marca con (SI*)
          --el servicio Web no ha respondido satisfactoriamente.(diferente a 200 con errores gestionados en el WS)
          elsif p_status_code ='400' then--error de formateo de datos en los parámetros enviados
             v_result:= '03-Error al utilizar Servicios WEB Bancard Conector: Parámetros de envío inválidos: '||p_respuesta;
             v_con_error:='SI*';
          elsif p_status_code ='404' then--Servicio no disponible, servidor de bancarconector caido
             v_result:= '04-Servicios de conexión a Bancard no disponibles, utilizat operativa contingente';
             v_con_error:='SI*';
          elsif p_status_code in('503','412','500') then--errores soportados en BancardConector
             v_resp_json := typ_json(p_respuesta);    
             v_resp_err := pag_jex.get_string(v_resp_json, 'msgError');--obtenemos el mensaje de error

             v_result:= '05-Error al utilizar Servicios WEB Bancard Conector: '||v_resp_err;
             v_con_error:='SI*';         

             if p_status_code = '503' then
                v_result := '06-Error, Servicios Web de Bancard Inactivos.';
             end if;      
          else--otros errores no soportados
             v_result:= '07-Error al utilizar Servicios WEB Bancard: '||p_descripcionRespuesta||'-'||p_codigoError||'-'||p_error;   
             v_con_error:='SI*';
          end if;
       
                
       elsif p_error = 'S' then
          v_con_error:='SI*';
          v_result:= '08-Error al utilizar Servicios WEB Bancard Conector: '||p_descripcionRespuesta;
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


BEGIN

   for c in c_pines loop
     v_cant_pines := v_cant_pines+1;
     v_lugar := 'punto 1' || c.registro;
         --Enviamos el registro de pines desencriptados a Bancard
         --c.registro Formato: {"data":"AAAA..N"}
         v_respuesta := FUA_WSI_ENV_POST(c.registro, g_url, v_metodo);
         
        v_lugar := v_lugar || ' *punto 2';

         -- bitacora de logs
         lp_reg_operacion('/'||v_metodo||'/'||g_url||'/'||c.registro, substr(v_respuesta.error || ' - ' ||    
         v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
         --procesamos la respuesta
         lp_pro_respuesta(substr(v_respuesta.respuesta,1,4000),
                          v_respuesta.codigoError,
                          v_respuesta.error,
                          v_respuesta.descripcionRespuesta,
                          v_respuesta.status_code,
                          c.fila);                         


              v_lugar := v_lugar || ' *punto 3';
           if v_con_error = 'SI*' then
              exit;
           end if;                         

   end loop;

   if v_cant_pines > 0 then
      if v_con_error = 'SI*' then
         ROLLBACK;
         return v_lugar ||'-'|| v_result;
      elsif v_con_error = 'NO' then
         commit;
         return 'Proceso finalizado, se desencriptaron ('||v_cant_pines||') pines exitosamente!';
      end if;
   else
      return 'No existen pines a desencriptar!';
   end if;


EXCEPTION
   WHEN OTHERS THEN
      lp_reg_operacion('Error al desencriptar pines',v_lugar);
      ROLLBACK;
   
      RAISE_APPLICATION_ERROR(-20000, '*Error al desencriptar pines : '||v_lugar||SQLERRM);
END FUA_WSI_DES_PINES;
/

