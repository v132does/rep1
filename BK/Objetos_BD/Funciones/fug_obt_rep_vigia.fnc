CREATE OR REPLACE FUNCTION IT.fug_obt_rep_vigia(p_nombre VARCHAR2,
                                                p_cedula varchar2)
  RETURN varchar2 IS

  v_metodo         VARCHAR2(15) := 'POST';
  v_url            VARCHAR2(4000) := fug_obt_pardinamico('GEN_URL_WS_VIGIA');
  v_cod_err_ws     NUMBER(6);
  v_men_error      VARCHAR2(4000);
  v_content        VARCHAR2(4000);
  v_can_max_espera ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_MAX_ESPERA');
  v_cod_msg_exito  NUMBER := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200);
  v_req            utl_http.req;
  v_res            utl_http.resp;
  v_buffer         VARCHAR2(4000);
  v_referencia     VARCHAR2(150);
  v_documento      VARCHAR2(80);
  v_nombres        VARCHAR2(250);
  v_apellidos      VARCHAR2(250);
  v_accion         VARCHAR2(50);
  v_explicacion    VARCHAR2(350);
  v_fec_nacimiento VARCHAR2(50);
  v_nom_programa   VARCHAR2(50) := 'FUG_OBT_REP_VIGIA';
  v_error          VARCHAR2(2000);
  v_pas            VARCHAR2(200) := fug_obt_pardinamico('GEN_PAS_WS_VIGIA');
  v_niv            NUMBER := fug_obt_pardinamico('MINLEVEL'); --DA-7308
  v_character      varchar(4000);
  v_respuesta      VARCHAR2(4000);
  v_length         varchar2(4000);

BEGIN
  
  --seteamos el tiempo maximo de espera a la respuesta del web service - inicial 60seg.
  sql_util.ejecute_dml('ALTER SESSION SET CURRENT_SCHEMA=IT', v_error);

  -- UTL_HTTP.SET_TRANSFER_TIMEOUT(to_number(v_can_max_espera));
  -- se crea la estructura json para pasar al ws
  
   v_content := '{ "name": "' || p_nombre || '",
     "password": "'           || v_pas || '",
     "min-level": "'          || v_niv || '",
     "ci": "'                 || p_cedula || '"'||' }';

  v_length  :=  lengthb(v_content)+1;
  v_req := utl_http.begin_request(v_url, v_metodo);
  utl_http.set_body_charset(v_req, 'UTF-8'); 
  utl_http.set_header(v_req, 'content-type', 'application/json ; charset=UTF-8' );
  utl_http.set_header(v_req, 'Content-Length', v_length);
  utl_http.write_text(v_req, v_content);

  v_res := utl_http.get_response(v_req);
  v_cod_err_ws := v_res.status_code;
  utl_http.read_text(v_res, v_buffer);
  v_respuesta := v_buffer;
  utl_http.end_response(v_res);

  IF v_cod_err_ws != v_cod_msg_exito THEN
  
    BEGIN
      SELECT error
        INTO v_error
        FROM json_table(v_buffer,
                        '$' columns(error VARCHAR2(2000) path '$.error'));
    EXCEPTION
      WHEN no_data_found THEN
        v_error := NULL;
    END;
    prg_ins_log_programas(v_nom_programa,
                          substr('Error en CI: ' || p_nombre ||
                                 ' Error Code :' || v_cod_err_ws || ' - ' ||
                                 v_buffer,
                                 1,
                                 4000),
                          null,
                          null);
  
    v_accion      := 'ERROR';
    v_explicacion := v_error;
  
  END IF;
  RETURN(v_respuesta);
END;
/

