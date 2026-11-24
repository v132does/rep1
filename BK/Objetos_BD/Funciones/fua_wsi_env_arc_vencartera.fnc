CREATE OR REPLACE FUNCTION IT.FUA_WSI_ENV_ARC_VENCARTERA(p_nom_archivo varchar2, /*CODIGOSEIS, CODIGOBAJA*/
                                                      p_ref_lote    number)  
RETURN varchar2 IS
/* Función para enviar registro de archivos de alta y relación de
cuentas de tarjeta de débitos, por medio de Webservices de Bancard*/

   cursor c_codigo_seis is
   select '{"nroCuenta":"'||t.nro_cuenta||'",
          "valorCGF":"6",
          "usuActualizacion":"'||user||'"}' JSON_regs,
         rowid registro
    from ge_sal_inv_vta_cartera_his t
   where t.cod_modulo = 5
     and t.estado     = 'C'
     and t.ref_lote   = nvl(p_ref_lote, t.ref_lote);

   cursor c_codigo_baja is
   select '{"nroCuenta":"'||t.nro_cuenta||'",
          "situacion":"B",
          "usuActualizacion":"'||user||'"}' JSON_regs,
         rowid registro
    from ge_sal_inv_vta_cartera_his t
   where t.cod_modulo = 5
     and t.estado     = 'C'
     and t.ref_lote   = nvl(p_ref_lote, t.ref_lote);

    v_inicio          varchar2(10) := '[';
    v_fin             varchar2(10) := ']';
    v_json            clob;
    ---
    v_respuesta       TYP_POSTRESPUESTACLOB;
    v_url_webservice  ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('WSI_BBVA_BANCARD');
    v_metodo          VARCHAR2(5) := 'POST';
    v_result          varchar2(4000);
    ---
    v_con_error       varchar2(3):= 'NO';
    v_con_errores     number:=0;
    v_con_exito       number:=0;
    v_hay_datos       varchar2(1):='N';
    v_cont            number:=0;

    --procedimiento interno de manejo de respuesta (formateo)
    procedure lp_pro_respuesta(p_respuesta varchar2,
                               p_codigoError varchar2,
                               p_error varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code varchar2) is
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
                
             --sin errores 
             elsif v_resp_num = 0 then
                v_con_exito:=v_con_exito+1;--acumulamos registros enviados correctamente
                
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
     END LP_REG_OPERACION;

/*SE ENVIARÁ POR LOTE DE REGISTROS AL WS DE BANCARD*/
BEGIN

   IF p_nom_archivo = 'CODIGOSEIS' THEN
      for c in c_codigo_seis loop
         v_hay_datos := 'S';
         v_cont      := v_cont + 1;
         
         if v_cont = 1 then
            v_json   := v_json||c.JSON_regs;
         else
            v_json   := v_json||','||c.JSON_regs;
         end if;
      end loop;
   ELSIF p_nom_archivo = 'CODIGOBAJA' THEN
      for c in c_codigo_baja loop
         v_hay_datos := 'S';
         v_cont      := v_cont + 1;
         
         if v_cont = 1 then
            v_json   := v_json||c.JSON_regs;
         else
            v_json   := v_json||','||c.JSON_regs;
         end if;
      end loop;   
   END IF;

   --enviamos al WebSevice
   v_respuesta := FUA_WSI_ENV_POST((to_clob(v_inicio)|| v_json ||to_clob(v_fin)/*FORMATEO ARRAY JSON [{objeto}]*/), v_url_webservice, v_metodo);

   -- bitacora de logs
   lp_reg_operacion('/'||v_metodo||'/'||v_url_webservice||'/'||v_json, substr(v_respuesta.error || ' - ' ||    
   v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
   --procesamos la respuesta
   lp_pro_respuesta(v_respuesta.respuesta,
                    v_respuesta.codigoError,
                    v_respuesta.error,
                    v_respuesta.descripcionRespuesta,
                    v_respuesta.status_code);

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
END FUA_WSI_ENV_ARC_VENCARTERA;
/

