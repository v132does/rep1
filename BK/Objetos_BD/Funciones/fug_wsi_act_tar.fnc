CREATE OR REPLACE FUNCTION IT.FUG_WSI_ACT_TAR (p_nro_tarjeta varchar2)
RETURN varchar2 IS

/* Funcion para enviar registro de archivos por medio de Webservices a la Procesadora */

  CURSOR c_tarjetas IS
    SELECT  '{"orden":'         || 1 || ',
              "numeroCuenta":'  || 'null' || ',
              "numeroTarjeta":"'|| t.nro_tarjeta || '",
              "cobrarCosto":'   || 'false' ||',
              "importe":'       || 'null' || '}' JSON_regs,
              t.nro_cuenta, t.nro_tarjeta
      FROM ta_tarjetas t
     WHERE t.nro_tarjeta = p_nro_tarjeta;

    v_inicio               varchar2(10) := '[';
    v_fin                  varchar2(10) := ']';
    v_json                 clob;
    ---
    v_respuesta            TYP_POSTRESPUESTACLOB;
    v_url_web_ser_bancard  ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('WSI_ACT_TAR_BANCARD');
    v_metodo               VARCHAR2(5) := 'POST';
    v_result               varchar2(4000);
    --
    v_con_error            varchar2(3):= 'NO';
    v_con_errores          number:=0;
    v_con_exito            number:=0;
    v_hay_datos            varchar2(1):='N';

    --procedimiento interno de manejo de respuesta (formateo)
    PROCEDURE lp_pro_respuesta(p_respuesta varchar2,
                               p_codigoError varchar2,
                               p_error varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code varchar2) IS
    PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    v_resp_json typ_json;
    v_resp_num number;
    v_resp_err varchar2(4000);

    BEGIN
       IF p_error != 'S' THEN
          --controlamos que el servicio responda con exito (200)
          IF p_status_code = '200' THEN
             IF instr(lower(p_respuesta), 'la tarjeta ya esta activa') = 0 THEN
                v_resp_json := typ_json(p_respuesta);--convertimos a json la respuesta -> estructura json {"result":"999"}
             END IF;
             --Un error suele ser la respuesta {"result":"Usuario/Contrase??a Inactiva"}
             --entonces tratar la respuesta como char
             IF length(pag_jex.get_string(v_resp_json, 'result')) > 3 THEN--respuesta caracter
                v_resp_num := null;--para captuar el error marcamos a null
             ELSE
                v_resp_num := to_number(pag_jex.get_string(v_resp_json, 'result'));--obtenemos el nro de respuesta
             END IF;
             --v_resp_num = 0 (Sin errores) mayor a 0 (con errores)--se le encamina al usuario para que revise en bancard
             IF v_resp_num > 0 THEN
                v_con_error:='SI';--se marca que en el proceso existe errores de envio de registros.
                v_con_errores:= v_con_errores+v_resp_num;
             --sin errores
             ELSIF v_resp_num = 0 THEN
                v_con_exito:=v_con_exito+1;--acumulamos registros enviados correctamente
             ELSIF v_resp_num is null THEN
                v_con_error:='SI*';
                IF instr(lower(p_respuesta), 'la tarjeta ya esta activa') > 0 THEN
                   v_result:= 'La tarjeta ya esta activa';
                ELSE
                   v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||pag_jex.get_string(v_resp_json, 'result');
                END IF;
             END IF;
          --errores que no deben continuar con el proceso de envio se marca con (SI*)
          --el servicio Web no ha respondido satisfactoriamente.(diferente a 200 con errores gestionados en el WS)
          ELSIF p_status_code ='400' THEN--error de formateo de datos en los parametros enviados
             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: Parametros de envio invalidos: '||p_respuesta;
             v_con_error:='SI*';
          ELSIF p_status_code ='404' THEN--Servicio no disponible, servidor de bancarconector caido
             v_result:= 'Error Servicios de conexion a Bancard no disponibles, utilizar operativa contingente';
             v_con_error:='SI*';
          ELSIF p_status_code in('503','412','500') THEN--errores soportados en BancardConector
             v_resp_json := typ_json(p_respuesta);
             v_resp_err := substr(pag_jex.get_string(v_resp_json, 'msgError'), 4000);--obtenemos el mensaje de error

             v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||v_resp_err;
             v_con_error:='SI*';

             IF p_status_code = '503' THEN
                v_result := 'Error, Servicios Web de Bancard Inactivos.';
             END IF;
          ELSE--otros errores no soportados
             v_result:= 'Error al utilizar Servicios WEB Bancard: '||p_descripcionRespuesta||'-'||p_codigoError||'-'||p_error;
             v_con_error:='SI*';
          END if;
       ELSIF p_error = 'S' THEN
          v_con_error:='SI*';
          v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||p_descripcionRespuesta;
       END IF;
    END lp_pro_respuesta;
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
    --procedimiento interno que actualiza ta_tar_nominadas
    PROCEDURE LP_ACT_NOMINADAS(p_nro_cuenta IN VARCHAR2, p_nro_tarjeta IN VARCHAR2) is
       PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
    BEGIN
       IF v_con_error = 'SI*' AND instr(lower(v_result), 'tarjeta ya esta activa') > 0 THEN
          UPDATE ta_tar_nominadas
             SET env_activacion = 'S'
           WHERE nro_cuenta = p_nro_cuenta
             AND nro_tarjeta = p_nro_tarjeta;
       END IF;
       COMMIT;
    EXCEPTION
       WHEN OTHERS THEN
         null;
    END;

/*SE ENVIARA DE A 1 REGISTRO AL WS DE BANCARD*/
BEGIN

   FOR c IN c_tarjetas LOOP
      v_hay_datos:= 'S' ;
      v_json      := to_clob(v_inicio)|| c.JSON_regs ||to_clob(v_fin);--FORMATEO ARRAY JSON [{objeto}]

      --enviamos al WebSevice
      v_respuesta := FUA_WSI_ENV_POST(v_json, v_url_web_ser_bancard, v_metodo);

      -- bitacora de logs
      lp_reg_operacion('/'||v_metodo||'/'||v_url_web_ser_bancard||'/'||v_json, substr(v_respuesta.error || ' - ' ||
      v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
      --procesamos la respuesta
      lp_pro_respuesta(substr(v_respuesta.respuesta,2,length(v_respuesta.respuesta)-2) ,
                       v_respuesta.codigoError,
                       v_respuesta.error,
                       v_respuesta.descripcionRespuesta,
                       v_respuesta.status_code);
      lp_act_nominadas(c.nro_cuenta, c.nro_tarjeta);
   END LOOP;

   --si se procesaron datos
   IF v_hay_datos = 'S' THEN
      IF v_con_error = 'SI*' THEN
         IF instr(lower(v_result), 'tarjeta ya esta activa') = 0 THEN
            ROLLBACK;
         END IF;
         RETURN 'ACT-'||v_result;
      ELSIF v_con_error = 'SI' THEN
         COMMIT;
         RETURN 'ACT-'||'Envio realizado, (Registros correctos ('||v_con_exito||'), Registros incorrectos ('||v_con_errores||') Ver en pantalla Azul de bancard Los datos incorrectos';
      ELSIF v_con_error = 'NO' THEN
         COMMIT;
         RETURN 'ACT-'||'Envio realizado exitosamente!';
      END IF;
   ELSE-- si no se procesaron datos
      RETURN 'ACT-'||'No existen registros a enviar';
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20000, 'ACT-Error al enviar: '||SQLERRM);
END FUG_WSI_ACT_TAR;
/

