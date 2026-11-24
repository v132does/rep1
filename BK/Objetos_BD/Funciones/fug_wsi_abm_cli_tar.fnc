CREATE OR REPLACE FUNCTION IT.FUG_WSI_ABM_CLI_TAR (p_nro_tarjeta varchar2)
RETURN varchar2 IS

/* Funcion para enviar registro de tarjetas por medio de Webservices a la Procesadora */

  CURSOR c_tarjetas IS
     SELECT '{"TitNroDoc": "'      || pe.nro_documento || '",
              "TitTpoPer": "'      || pe.tipo || '",
              "TitTpoDoc": "'      || CASE TRIM(td.abreviatura)
                                      WHEN 'CI' THEN 'CIP'
                                      ELSE TRIM(td.abreviatura)
                                      END || '",
              "TitNombre1": "'     || REPLACE(substr(pf.pri_nombre,1,20),';',' ') ||  '",
              "TitNombre2": "'     || REPLACE(substr(pf.seg_nombre,1,20),';',' ') || '",
              "TitApellido1": "'   || REPLACE(substr(pf.pri_apellido,1,20),';',' ') || '",
              "TitApellido2": "'   || REPLACE(substr(pf.seg_apellido,1,20),';',' ') || '",
              "TitPaisNac": "'     || bp.ref_externa || '",
              "TitSexo": "'        || pf.cod_sexo || '",
              "TitFchNac": "'      || to_char(pf.fec_nacimiento, 'DD/MM/YY') || '",
              "TitLugNac": "'      || substr(bp.descripcion, 1, 15) || '",
              "TitEstCiv": "'      || decode(pf.est_civil, 'S', 'S', 'C', 'C', 'V', 'V', 'D', 'D', 'B', 'C', 'S') || '",
              "TitOcupacion": "'   || nvl(pr.ref_externa, 1807) || '",
              "TitEmail": "'       || REPLACE(REPLACE(substr(pe.dir_correo, 1, 60),';',' '), chr(10), '') || '",
              "TitTpoDocNuevo": "' || CASE TRIM(td.abreviatura)
                                      WHEN 'CI' THEN 'CIP'
                                      ELSE TRIM(td.abreviatura)
                                      END || '",
              "TitNroDocNuevo": "' || pe.nro_documento || '",
              "NroControl": '      || 'null' || ',
              "IdAfinidad":'       || 'null' || ',
              "IdCuenta":'         || 'null' || ',
              "NroTarjeta": "'     || ta.nro_tarjeta || '",
              "TpoTarjeta": '      || 'null' || ',
              "TpoPlastico": '     || 'null' || ',
              "Duracion": "'       || ti.plz_dur_tarjeta || '",
              "NomPlastico": "'    || REPLACE(substr(pf.pri_nombre||' '||pf.pri_apellido,1,20),';',' ') ||  '",
              "AdicionalPer": '    || 'null' || ',
              "NroDocProm": '      || 'null' || ',
              "TpoDocProm": '      || 'null' || ',
              "Situacion": '       || 'null' || ',
              "RenovAutom": "'     || 'S'    || '",
              "Ordenamiento1": '   || 'null' || ',
              "Ordenamiento2": '   || 'null' || ',
              "Emboza": "'         || 'S'    || '",
              "PromNroDoc": '      || 'null' || ',
              "PromTpoPer": '      || 'null' || ',
              "PromTpoDoc": '      || 'null' || ',
              "PromNombre1": '     || 'null' || ',
              "PromNombre2": '     || 'null' || ',
              "PromApellido1": '   || 'null' || ',
              "PromApellido2": '   || 'null' || ',
              "PromSexo": '        || 'null' || ',
              "PromFchNac": '      || 'null' || ',
              "PromLugNac": '      || 'null' || ',
              "PromEstCiv": '      || 'null' || ',
              "PromOcupacion": '   || 'null' || ',
              "PromEmail": '       || 'null' || ',
              "PlanContado": '     || 'null' || ',
              "OperPlanCont": '    || 'null' || ',
              "ImpPrsPlanCont": '  || 'null' || ',
              "PorcPrsPlanCont": ' || 'null' || ',
              "PlanAdeEfectivo": ' || 'null' || ',
              "OperPlanAdeEfec": ' || 'null' || ',
              "ImpPrsPlanAdeEfec":'|| 'null' || ',
              "PorcPrsPlanAdeEfec":'|| 'null'||',
              "PermitFinanciar": ' || 'null' || ',
              "UsuActualizacion": '|| 'null' || ',
              "NroSocio": '        || 'null' || ',
              "MotNovTrj": '       || 'null' || '}' JSON_regs,
              ta.nro_cuenta, ta.nro_tarjeta
       FROM ba_personas       pe, 
            ba_per_fisicas    pf, 
            ta_tarjetas       ta, 
            ta_cta_tarjetas   ct, 
            ge_cta_clientes   cl,
            ba_tip_documentos td,
            ba_paises         bp,
            ba_profesiones    pr,
            ta_tipos          ti
      WHERE pe.cod_persona=pf.cod_persona 
        AND cl.cod_persona=pe.cod_persona 
        AND cl.nro_cuenta=ct.nro_cuenta 
        AND cl.cod_persona=ta.cod_persona
        AND ct.nro_cuenta=ta.nro_cuenta
        AND pe.cod_tip_documento=td.cod_tip_documento 
        AND pf.cod_pai_nacionalidad=bp.cod_pais(+) 
        AND pf.cod_profesion=pr.cod_profesion(+)
        AND ct.afinidad=ti.afinidad
        AND ta.nro_tarjeta=p_nro_tarjeta;        

    v_inicio               varchar2(10) := '[';
    v_fin                  varchar2(10) := ']';
    v_json                 clob;
    ---
    v_respuesta            TYP_POSTRESPUESTACLOB;
    v_url_web_ser_bancard  ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('WSI_ABM_TAR_BANCARD_NEW');
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
             v_resp_json := typ_json(p_respuesta);--convertimos a json la respuesta -> estructura json {"result":"999"}
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
                v_result:= 'Error al utilizar Servicios WEB Bancard Conector: '||pag_jex.get_string(v_resp_json, 'result');
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
       IF v_con_error = 'SI*' AND instr(upper(v_result), 'SUBMITIDO') > 0 THEN
          UPDATE ta_tar_nominadas
             SET env_tarjeta = 'S'
           WHERE nro_cuenta = p_nro_cuenta
             AND nro_tarjeta = p_nro_tarjeta;
       END IF;
       COMMIT;
    EXCEPTION
       WHEN OTHERS THEN
         raise_application_error(-20000, sqlerrm);
    END;

/*SE ENVIARA DE A 1 REGISTRO AL WS DE BANCARD*/
BEGIN

   FOR c IN c_tarjetas LOOP
      v_hay_datos:= 'S' ;		                      
      v_json      := to_clob(v_inicio)|| c.json_regs ||to_clob(v_fin);--FORMATEO ARRAY JSON [{objeto}]

      --enviamos al WebSevice
      v_respuesta := FUA_WSI_ENV_POST(v_json, v_url_web_ser_bancard, v_metodo);

      -- bitacora de logs
      lp_reg_operacion('/'||v_metodo||'/'||v_url_web_ser_bancard||'/'||v_json, substr(v_respuesta.error || ' - ' ||
      v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));
      --procesamos la respuesta
      lp_pro_respuesta(v_respuesta.respuesta,
                       v_respuesta.codigoError,
                       v_respuesta.error,
                       v_respuesta.descripcionRespuesta,
                       v_respuesta.status_code);
      lp_act_nominadas(c.nro_cuenta, c.nro_tarjeta);
   END LOOP;

   --si se procesaron datos
   IF v_hay_datos = 'S' THEN
      IF v_con_error = 'SI*' THEN
         IF instr(upper(v_result), 'SUBMITIDO') = 0 THEN
            ROLLBACK;
         END IF;
         RETURN 'TAR-'||v_result;
      ELSIF v_con_error = 'SI' THEN
         COMMIT;
         RETURN 'TAR-Envio realizado, (Registros correctos ('||v_con_exito||'), Registros incorrectos ('||v_con_errores||') Ver en pantalla Azul de bancard Los datos incorrectos';
      ELSIF v_con_error = 'NO' THEN
         COMMIT;
         RETURN 'TAR-Envio realizado exitosamente!';
      END IF;
   ELSE-- si no se procesaron datos
      RETURN 'TAR-No existen registros de a enviar';
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      RAISE_APPLICATION_ERROR(-20000, 'TAR*Error al enviar : '||SQLERRM);
END FUG_WSI_ABM_CLI_TAR;
/

