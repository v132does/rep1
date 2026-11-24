CREATE OR REPLACE FUNCTION IT.FUG_WSI_REC_EQUIFAX  (P_COD_PERSONA IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
  v_con_error     varchar2(3):= 'NO';
  v_respuesta     TYP_POSTRESPUESTACLOB;
  v_url           varchar2(500) := fug_obt_pardinamico('EQU_URL_WSI_REC_DATOS');
  v_result        varchar2(4000);
  v_metodo        VARCHAR2(5) := 'POST';
  v_can_intentos  number := 0;
  v_retorno       varchar2(3000);
  CURSOR DATOS IS
    Select '{"producto": "'    ||fug_obt_pardinamico('NOM_PRO_EQUIFAX')||'",
             "xml": "'         ||a.dat_consulta ||'",
             "nroSucursal": "' ||1              ||'",
             "numAfiliado": "' ||fug_obt_pardinamico('NRO_CLI_EQUIFAX')||'"}' datos,
           a.dat_consulta ,
           a.cod_persona  , 
           a.fecha        , 
           rowid registro
      from ge_equ_consulta_tmp a
     where a.tip_consulta = 2
       and a.estado       <> 'C'
       and a.cod_persona  = NVL(p_cod_persona,a.cod_persona);

    --Log de Actividades
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

     --procedimiento interno de manejo de respuesta
    procedure lp_pro_respuesta(p_respuesta            varchar2,
                               p_codigoError          varchar2,
                               p_error                varchar2,
                               p_descripcionRespuesta varchar2,
                               p_status_code          varchar2) is
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_resp_json  typ_json;
    v_resp_err   varchar2(4000);
    v_xml        xmltype;
    v_cod_error  varchar2(5);
    v_msn_error  varchar2(1000);
    begin
       if p_error != 'S' then
          --controlamos que el servicio responda con éxito (200)
          if p_status_code = '200' then
             v_resp_json := typ_json(p_respuesta);--convertimos a json la respuesta
             v_xml := xmltype.createxml(pag_jex.get_string(v_resp_json,'data'));
             
             IF v_xml.extract('/experto/CodError/text()') is not null THEN
                v_con_error := 'SI';
                v_cod_error := v_xml.extract('/experto/CodError/text()').getStringVal();
                v_msn_error := v_xml.extract('/experto/Error/text()').getStringVal();
                v_result    := 'Error '||v_cod_error||': '||v_msn_error;
             End IF;  
             If v_xml.extract('/experto/integrantes/datos/accion/text()') is not null Then
                 IF v_xml.extract('/experto/integrantes/datos/accion/text()').getStringVal() = 'SIN_INFORMACION' THEN
                    v_con_error := 'SI';
                    v_cod_error := '00';
                    v_msn_error := 'Persona Inexistente en Equifax';
                    v_result    := 'Error '||v_cod_error||': '||v_msn_error;
                 End If;
             End If;
          elsif p_status_code ='400' then
             v_result    := 'Error al utilizar Servicios del Conector: Parámetros de envío inválidos: '||p_respuesta;
             v_con_error :='SI';
             
          elsif p_status_code ='404' then
             v_result    := 'Servicios de conexión a Equifax no disponibles';
             v_con_error :='SI';
             
          elsif p_status_code in('503','412','500') then
             v_resp_json := typ_json(p_respuesta);
             v_resp_err  := pag_jex.get_string(v_resp_json, 'Error');
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
          v_con_error:='SI';
          v_result:= 'Error al utilizar Servicios WEB Equifax Conector: '||p_descripcionRespuesta;
       end if;
    end lp_pro_respuesta;

    PROCEDURE LP_PRO_RESULTADO (P_COD_PERSONA IN VARCHAR2,
                                P_FECHA       IN DATE    ,
                                P_RESPUESTA   IN VARCHAR2)IS
          v_resp_json typ_json;
          v_xml       xmltype;
          v_dato      varchar2(2000);
          v_cabecera  varchar2(100) := '/experto/integrantes/datos/';
          v_param     varchar2(10) := '/text()';
          
          cursor campos is 
              Select lower(a.val_minimo) campo, a.val_maximo tip_dato, a.abreviatura logitud
                From ba_cod_referencias a
                where a.dominio = 'CAM_RES_EQUIFAX';
                
          procedure LP_INS_DATOS (P_FECHA         IN DATE    ,
                                  P_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE,
                                  P_NOM_CAMPO     IN VARCHAR2,
                                  P_RES_CONSULTA  IN VARCHAR2,
                                  P_BLOQUE        IN VARCHAR2) IS
            BEGIN  
              If P_BLOQUE = 'C' Then
                  BEGIN
                        insert into Ge_Equ_Consultas_Cab(Fecha  , Cod_Persona)
                                                  values(P_FECHA, P_COD_PERSONA);
                  EXCEPTION
                        When Others Then
                            raise_application_error(-20000,'Error al Instar cabecera de respuestas '||sqlerrm);
                  END;
              Else
                  BEGIN
                        insert into GE_EQU_CONSULTAS_DET(FECHA  , COD_PERSONA  , NOM_CAMPO  , RES_CONSULTA  )
                                                  values(P_FECHA, P_COD_PERSONA, P_NOM_CAMPO, P_RES_CONSULTA);
                  EXCEPTION
                       When Others Then
                            raise_application_error(-20000,'Error al Instar detalle de respuestas '||sqlerrm);
                  END;
              End If; 
            END lp_ins_datos;
    BEGIN
        v_resp_json := typ_json(P_RESPUESTA);
        v_xml := xmltype.createxml(pag_jex.get_string(v_resp_json,'data'));
        lp_ins_datos(P_FECHA, P_COD_PERSONA, null, null, 'C');
        for c in campos loop
            IF v_xml.extract(v_cabecera||c.campo||v_param) IS NOT NULL THEN
               --If c.tip_dato = 'T' Then --> Leer Texto
                  v_dato := v_xml.extract(v_cabecera||c.campo||v_param).getStringVal();
               /*Else --> Leer Número
                  v_dato := v_xml.extract(v_cabecera||c.campo||v_param).getNumberVal();
               End If;*/
               lp_ins_datos(P_FECHA, P_COD_PERSONA, upper(c.campo), v_dato, 'D');
            Else
               lp_ins_datos(P_FECHA, P_COD_PERSONA, upper(c.campo), null, 'D');
            END IF;
        end loop;
    END LP_PRO_RESULTADO;
BEGIN
  FOR c IN DATOS LOOP
      v_respuesta := fug_wsi_env_equifax(c.datos ,
                                         v_url   ,
                                         v_metodo);
       -- Logs
       lp_reg_operacion(c.datos,
                        substr(v_respuesta.error || ' - ' ||v_respuesta.codigoError ||' - ' || v_respuesta.respuesta, 1, 4000));

       -- Procesamos la respuesta
       lp_pro_respuesta(v_respuesta.respuesta           ,
                        v_respuesta.codigoError         ,
                        v_respuesta.error               ,
                        v_respuesta.descripcionRespuesta,
                        v_respuesta.status_code         );
       
       If v_con_error = 'SI' then
              If pae_cnf.G_PROGRAMA = 'GEQUIFAX' Then
                  BEGIN
                     update ge_equ_consulta_tmp t
                     set t.estado       = 'E'     ,
                         t.error        = v_result,
                         t.can_intentos = v_can_intentos
                     where t.rowid = c.registro;
                  EXCEPTION
                     when others then
                          raise_application_error(-20000,'Error: Al actualizar datos de registros enviados: '||SQLERRM);
                  END;
              Else 
                  Begin
                       delete ge_equ_consulta_tmp t where t.rowid = c.registro;
                  Exception
                       when others Then
                            raise_application_error(-20000,'Error borrando registro procesado satisfactoriamente '||sqlerrm);
                  End;
              End If;
              v_retorno := 'ERR: '||v_result;
       Else -- Si NO hay errores
            LP_PRO_RESULTADO(c.cod_persona, c.fecha, v_respuesta.respuesta);
            Begin
                 delete ge_equ_consulta_tmp t where t.rowid = c.registro;
            Exception
                 when others Then
                      raise_application_error(-20000,'Error borrando registro procesado satisfactoriamente '||sqlerrm);
            End;
            v_retorno := 'Proceso Concluido Satisfactoriamente';
       End If;
  END LOOP;
       return v_retorno;
EXCEPTION
      When Others Then
           raise_application_error(-20000,'Error en PRG_WSI_REC_EQUIFAX: '||sqlerrm);
           --dbms_output.put_line('Error en PRG_WSI_REC_EQUIFAX: '||sqlerrm);
END;
/

