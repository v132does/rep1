create or replace procedure it.prp_env_datos(p_cod_persona in varchar2,
                                             p_estado   in varchar2) is

  v_metodo varchar2(15) := 'POST';
  v_url    varchar2(4000) := fug_obt_pardinamico('WBS_URL_INT_CHE_ROGA');
  --http://192.168.40.10:7000/ms-app-resources/v1/cheroga/insertUpdateCustomerBanner old 12-12-2023
  --http://192.168.40.119:4152/loans/banners/insertUpdateCustomerBanner/ -- new 13-13-2024
  v_cod_err_ws     number(6);
  v_men_error      varchar2(4000);
  v_content        varchar2(4000);
  v_can_max_espera ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_MAX_ESPERA');
  v_cod_msg_exito  number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200);
  v_req            utl_http.req;
  v_res            utl_http.resp;
  v_buffer         varchar2(4000);
  v_nom_programa   varchar2(50) := 'PRP_ENV_DATOS';
  v_error          varchar2(2000);
begin
  --seteamos el tiempo maximo de espera a la respuesta del web service - inicial 120 seg.
  utl_http.set_transfer_timeout(to_number(v_can_max_espera));

  /*Crear la estructura JSON para pasar al WS*/
  v_content := '{"personCode": "' || p_cod_persona || '",
                     "state": "' || p_estado || '"' || ' }';

  /*Crear la solicitud HTTP POST*/
  v_req := utl_http.begin_request(v_url, v_metodo, ' HTTP/1.1');

  /*Establecer encabezados de la solicitud*/
  utl_http.set_header(v_req, 'content-type', 'application/json');

  utl_http.set_header(v_req, 'Content-Length', length(v_content));

  /*Construir los datos del cuerpo de la solicitud*/
  utl_http.write_text(v_req, v_content);

  /*Enviar la solicitud y obtener la respuesta*/
  v_res        := utl_http.get_response(v_req);
  v_cod_err_ws := v_res.status_code;

  /*Leer datos de respuesta*/
  utl_http.read_text(v_res, v_buffer);

  utl_http.end_response(v_res);

  if v_cod_err_ws != v_cod_msg_exito then
    /*Extraer datos JSON*/
    begin
      select error
        into v_error
        from json_table(v_buffer,
                        '$' columns(error varchar2(2000) path '$.error'));
    exception
      when no_data_found then
        v_error := null;
    end;
    prg_ins_log_programas(v_nom_programa,
                          substr('Error en Persona: ' || p_cod_persona ||
                                 ' Error Code :' || v_cod_err_ws || ' - ' ||
                                 v_buffer,
                                 1,
                                 4000),
                          null,
                          null);
  
  end if;

exception
  when others then
    v_men_error := substr('Error en CI: ' || p_estado || ' Error code: ' ||
                          v_cod_err_ws || ' - Url: ' || v_url ||
                          ' - WS_Err_Desc : ' ||
                          utl_http.get_detailed_sqlerrm ||
                          ' - Error en prp_env_datos: ' || sqlerrm,
                          1,
                          4000);
  
    utl_http.end_response(v_res);
    prg_ins_log_programas(v_nom_programa, v_men_error, null, null);
end;
/
