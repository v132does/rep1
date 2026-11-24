create or replace package body it.pat_igp IS
  /* procedimiento que inserta registros en el log */
  PROCEDURE PR_INS_LOG(p_log   IN TA_LOGS_gp%ROWTYPE,
                       p_error IN BOOLEAN DEFAULT TRUE) IS
    v_log TA_LOGS_gp%ROWTYPE;
    pragma autonomous_transaction;
  BEGIN
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    v_log := p_log;
    IF p_error THEN
      v_log.nro_error := sqlcode;
      v_log.men_error := substr(sqlerrm, 1, 499);
    END IF;
    insert into ta_logs_gp
      (nom_proceso,
       fec_hor_ini,
       fec_hor_fin,
       nro_reg,
       nro_error,
       men_error,
       comentario)
    values
      (v_log.nom_proceso,
       nvl(v_log.fec_hor_ini, sysdate),
       sysdate,
       v_log.nro_reg,
       v_log.nro_error,
       v_log.men_error,
       v_log.comentario);
    commit;
  EXCEPTION
    when others then
      NULL;
  END;

  /* Inicializa registros la tabla TA_LOGS_GP correspondiente a la fecha y procedimiento ejecutado */
  PROCEDURE PR_BOR_LOG(p_fecha       in ta_logs_gp.fec_insercion%type,
                       p_nom_proceso in ta_logs_gp.nom_proceso%type) IS
  pragma autonomous_transaction;
  BEGIN
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    begin
      delete from ta_logs_gp a
       where (trunc(a.fec_hor_ini) = p_fecha or p_fecha is null)
         and (upper(a.nom_proceso) = upper(p_nom_proceso) or
             p_nom_proceso is null);
      commit;
    exception
      when others then
        raise_application_error(-20220,
                                'No se pudo inicializar la tabla de Logs GP. Comuniquese con el administrador del sistema.');
    END;
  END pr_bor_log;

  PROCEDURE PR_VER_LOG(p_fecha       in ta_logs_gp.fec_insercion%type,
                       p_nom_proceso in ta_logs_gp.nom_proceso%type) IS
    v_cont NUMBER(10) := 0;
  BEGIN
    BEGIN
      SELECT COUNT(*)
        INTO v_cont
        FROM ta_logs_gp a
       WHERE comentario NOT LIKE '***%***'
         and trunc(fec_hor_ini) = trunc(p_fecha)
         and upper(a.nom_proceso) = upper(p_nom_proceso); --en la fecha
    EXCEPTION
      WHEN OTHERS THEN
        v_cont := 1;
    END;
    IF nvl(v_cont, 0) > 0 THEN
      raise_application_error(-20110,
                              'Los procesos ejecutados han producido errores. Verifique la tabla de Logs GP.');
    END IF;
  END pr_ver_log;

  FUNCTION FU_VER_FEC_CIERRE RETURN varchar2 IS
    v_fec_cie_proceso  date;
    v_fec_calendario   date;
    v_cod_procesadora  ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_ENT_GLOBAL');
  BEGIN
    begin
      SELECT pag_cal.fu_obt_fec_sig_hab(nvl(pat_imp.fu_obt_fec_cierre(v_cod_procesadora,
                                                                      53,
                                                                      4),
                                            pag_cal.FU_OBT_FEC_ACTUAL(5)),
                                        61) fec_cie_proceso,
             pag_cal.FU_OBT_FEC_ACTUAL(5) fec_calendario
        into v_fec_cie_proceso, v_fec_calendario
        FROM dual;
    exception
      when others then
        v_fec_cie_proceso := null;
        v_fec_calendario  := null;
    end;
  
    if v_fec_cie_proceso is not null and v_fec_calendario is not null then
      IF v_fec_cie_proceso = v_fec_calendario THEN
        RETURN 'S';
      ELSE
        RETURN 'N';
      END IF;
    else
      RETURN 'N';
    end if;
  END FU_VER_FEC_CIERRE;

  /*Recibe un dato CLOB y retorna ese mismo dato codificado en base64 en CLOB*/
  FUNCTION FU_CON_B64_CLOB(a_input CLOB) return CLOB as
    l_chunk_size integer := 57;
    l_offset     integer := 1;
    l_tmp        clob;
    l_result     clob;
    l_chunk      raw(100);
    l_chunk_b64  varchar2(200);
  begin
    dbms_lob.createtemporary(l_tmp, false);
    while l_offset < dbms_lob.getlength(a_input) loop
      l_chunk     := utl_raw.cast_to_raw(DBMS_LOB.SUBSTR(a_input,
                                                         l_chunk_size,
                                                         l_offset));
      l_chunk_b64 := utl_raw.cast_to_varchar2(utl_encode.base64_encode(l_chunk));
      dbms_lob.writeappend(l_tmp, length(l_chunk_b64), l_chunk_b64);
      l_offset := l_offset + l_chunk_size;
    end loop;
    l_result := l_tmp;
    dbms_lob.freetemporary(l_tmp);
    return l_result;
  end FU_CON_B64_CLOB;

  /*Recibe un dato VARCHAR2 y retorna ese mismo dato codificado en base64 en VARCHAR2*/
  function FU_CON_B64_TEXT(a_input in varchar2) return varchar2 is
  begin
    return utl_encode.text_encode(a_input,
                                  'WE8ISO8859P1',
                                  UTL_ENCODE.BASE64);
  end FU_CON_B64_TEXT;

  procedure PR_WS_CONECTOR_CLOB(p_content     clob, -- estructura json
                                p_url         in varchar2, -- url para utilizar si es alta de cuenta o cambio estado
                                p_nro_cta     in varchar2, -- cuando es cambio de estado se requiere el nro de cuenta
                                p_cod_persona in varchar2, -- cod persona del cliente
                                p_accion      in varchar2, -- si es cambio de estado o alta
                                p_metodo      in varchar2, -- es el tipo de metodo PUT, POST, GET
                                p_cod_error   out number,
                                p_men_error   out varchar2) is
  
    v_req        utl_http.req;
    v_res        utl_http.resp;
    v_buffer     clob;
    v_lugar      varchar2(10) default '00';
    v_men_error  clob;
    v_cod_err_ws number(6);
    v_error exception;
  
    v_can_max_espera ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CAN_MAX_ESPERA');
    v_nom_programa   varchar2(50) := 'PAT_IGP.PR_WS_CONECTOR_CLOB(';
    v_pro_correcto   number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                   0);
    v_cod_msg_exito  number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                   200);
    v_err_sql        number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);
    -------------variables para parseo
    content_length number;
    buffer         varchar2(32767);
    amount         NUMBER := 25000;
    offset         NUMBER := 1;
    --i              number := 1;
    ---------------
  
  begin
    --seteamos el tiempo maximo de espera a la respuesta del web service - inicial 60seg.
    
    UTL_HTTP.SET_TRANSFER_TIMEOUT(to_number(v_can_max_espera));
    p_cod_error := v_pro_correcto;
    --solicitud ws
    v_req := utl_http.begin_request(p_url, p_metodo, 'HTTP/1.1');
    v_lugar:='01';
    --verificamos el p_content
    if p_content is not null then
      content_length := DBMS_LOB.getlength(p_content);
      v_lugar:='02';
      --Se verifica si se realiza en paso o parseado
      if content_length <= 32767 then
        v_lugar:='03';
        utl_http.set_header(v_req, 'content-type', 'application/json');
        utl_http.set_header(v_req, 'Content-Length', content_length);
        utl_http.write_text(v_req, p_content);
      elsif content_length > 32767 then
        v_lugar:='04';
        utl_http.set_header(v_req, 'content-type', 'application/json');
        utl_http.set_header(v_req, 'Content-Length', length(p_content));
        utl_http.set_header(v_req, 'Transfer-Encoding', 'chunked');
        WHILE (offset < content_length) LOOP
          v_lugar:='05';
          begin
            v_lugar:='06';
            dbms_lob.read(p_content, amount, offset, buffer);
          exception
            when others then
              v_lugar:='07';
          end;
          begin
            v_lugar:='08';
            utl_http.write_text(v_req, buffer);
          exception
            when others then
              v_lugar:='09';
          end;
          offset := offset + amount;
        END LOOP;
      end if;
    end if;
    --respuesta ws
    v_lugar:='10';
    v_res := utl_http.get_response(v_req);
    ---obtiene el codigo de respuesta
    v_lugar:='11';
    v_cod_err_ws := v_res.status_code;
    --obtiene los datos del WS
    v_lugar:='12';
    utl_http.read_line(v_res, v_buffer);
    --se guarda la repuesta obtenida
    v_men_error := v_buffer;
    v_lugar:='13';
    utl_http.end_response(v_res);
    p_men_error := v_men_error;
  
    if v_cod_err_ws != v_cod_msg_exito then
      v_lugar:='14';
      p_cod_error := v_cod_err_ws;
      prg_ins_log_programas(v_nom_programa,
                            substr('1) Lugar: ' || v_lugar || ' - ' ||
                                   v_cod_err_ws || ' - ' || p_men_error,
                                   1,
                                   4000),
                            p_cod_persona,
                            p_nro_cta);
    else
      p_cod_error := v_cod_err_ws;
    end if;
  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := substr('Lugar: ' || v_lugar || ' - Url: ' || p_url ||
                            ' - WS_Err_Desc : ' ||
                            utl_http.get_detailed_sqlerrm ||
                            ' - Error en PR_WS_CONECTOR: ' || sqlerrm,
                            1,
                            4000);
    
      utl_http.end_response(v_res);
      prg_ins_log_programas(v_nom_programa,
                            p_men_error,
                            p_cod_persona,
                            p_nro_cta);
  end;

   FUNCTION FU_OBT_SIG_FEC_CIERRE
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 4 
   ) RETURN DATE IS
      v_fecha DATE;
   BEGIN
   
      --primero se busca con modalidad
      begin
      SELECT MAX(fec_cierre)
      into v_fecha
      FROM ta_cal_cierres
      WHERE cod_ent_procesadora =p_cod_procesadora
      AND cod_modulo = 5
      AND cod_modalidad = p_cod_modalidad
      AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
      AND fec_cierre <= (      
                        SELECT last_day(add_months(MAX(fec_cierre),1))
                        FROM ta_cal_cierres
                        WHERE cod_ent_procesadora = p_cod_procesadora
                        AND cod_modulo = 5
                        AND cod_modalidad = p_cod_modalidad
                        AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
                        AND fec_cierre <= trunc(sysdate));
      exception
        when no_data_found then
          v_fecha:=null;
        when others then
          v_fecha:=null;
       end;

      --se busca sin la modalidad
      IF v_fecha IS NULL THEN
                SELECT MAX(fec_cierre)
                into v_fecha
                FROM ta_cal_cierres
                WHERE cod_ent_procesadora =p_cod_procesadora
                AND cod_modulo = 5
                AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
                AND fec_cierre <= (      
                                  SELECT last_day(add_months(MAX(fec_cierre),1))
                                  FROM ta_cal_cierres
                                  WHERE cod_ent_procesadora = p_cod_procesadora
                                  AND cod_modulo = 5
                                  AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
                                  AND fec_cierre <= trunc(sysdate)); 
      end if;              
    
      RETURN v_fecha;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                                 'No existe proximo cierre para Proc: ' || to_char(p_cod_procesadora) ||
                                  ' Modal: ' || to_char(nvl(p_cod_modalidad, -1))||
                                  ' p_cod_tip_cierre '||p_cod_tip_cierre);

      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al buscar proximo cierre ' || SQLERRM || ' Proc: ' ||
                                  to_char(p_cod_procesadora) || ' Modal: ' ||
                                  to_char(nvl(p_cod_modalidad, -1)));
    end FU_OBT_SIG_FEC_CIERRE;

    FUNCTION FU_OBT_FEC_CIERRE
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 4,
      p_can_men_dias    IN NUMBER DEFAULT 0
   ) RETURN DATE IS
      v_fecha DATE;
   BEGIN
   
      --primero se busca con modalidad
      begin
      SELECT MAX(fec_cierre)
      into v_fecha
      FROM ta_cal_cierres
      WHERE cod_ent_procesadora = p_cod_procesadora
      AND cod_modulo = 5
      AND cod_modalidad = p_cod_modalidad
      AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
      AND fec_cierre <= (      
                        SELECT last_day(add_months(MAX(fec_cierre),1))
                        FROM ta_cal_cierres
                        WHERE cod_ent_procesadora = p_cod_procesadora
                        AND cod_modulo = 5
                        AND cod_modalidad = p_cod_modalidad
                        AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
                        AND fec_cierre < (trunc(sysdate)-nvl(p_can_men_dias,0)));
      exception
        when no_data_found then
          v_fecha:=null;
        when others then
          v_fecha:=null;
       end;

      --se busca sin la modalidad
      IF v_fecha IS NULL THEN
                SELECT MAX(fec_cierre)
                into v_fecha
                FROM ta_cal_cierres
                WHERE cod_ent_procesadora = p_cod_procesadora
                AND cod_modulo = 5
                AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
                AND fec_cierre <= (      
                                  SELECT last_day(add_months(MAX(fec_cierre),1))
                                  FROM ta_cal_cierres
                                  WHERE cod_ent_procesadora = p_cod_procesadora
                                  AND cod_modulo = 5
                                  AND cod_tip_cierre = nvl(p_cod_tip_cierre,4)
                                  AND fec_cierre < (trunc(sysdate)-nvl(p_can_men_dias,0))); 
      end if;              
    
      RETURN v_fecha;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                                 'No existe proximo cierre para Proc: ' || to_char(p_cod_procesadora) ||
                                  ' Modal: ' || to_char(nvl(p_cod_modalidad, -1))||
                                  ' p_cod_tip_cierre '||p_cod_tip_cierre);

      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al buscar proximo cierre ' || SQLERRM || ' Proc: ' ||
                                  to_char(p_cod_procesadora) || ' Modal: ' ||
                                  to_char(nvl(p_cod_modalidad, -1)));
    end FU_OBT_FEC_CIERRE;

FUNCTION FU_OBT_FEC_VENCIMIENTO
   (
      p_cod_procesadora IN NUMBER,
      p_cod_modalidad   IN NUMBER DEFAULT NULL,
      p_cod_tip_cierre  IN NUMBER DEFAULT 1
   ) RETURN DATE IS
      v_fecha DATE;
   BEGIN
      BEGIN
         SELECT fec_vencimiento
           INTO v_fecha
           FROM ta_cal_cierres
          WHERE cod_ent_procesadora = p_cod_procesadora
            AND cod_modulo = 5
            AND cod_modalidad = p_cod_modalidad
            AND cod_tip_cierre = p_cod_tip_cierre
            AND fec_cierre = (SELECT MAX(fec_cierre)
                                FROM ta_cal_cierres
                               WHERE cod_ent_procesadora = p_cod_procesadora
                                 AND cod_modulo = 5
                                 AND cod_modalidad = p_cod_modalidad
                                 AND cod_tip_cierre = p_cod_tip_cierre
                                 AND fec_cierre < trunc(SYSDATE));
      EXCEPTION
         WHEN no_data_found THEN
            SELECT fec_vencimiento
              INTO v_fecha
              FROM ta_cal_cierres
             WHERE cod_ent_procesadora = p_cod_procesadora
               AND cod_modulo = 5
               AND cod_tip_cierre = p_cod_tip_cierre
               AND fec_cierre = (SELECT MAX(fec_cierre)
                                   FROM ta_cal_cierres
                                  WHERE cod_ent_procesadora = p_cod_procesadora
                                    AND cod_modulo = 5
                                    AND cod_tip_cierre = p_cod_tip_cierre
                                    AND fec_cierre < trunc(SYSDATE));
      END;
      RETURN v_fecha;
   EXCEPTION
      WHEN no_data_found THEN
         raise_application_error(-20000,
                                 'No existe cierre para Proc: ' || to_char(p_cod_procesadora) ||
                                  ' Modal: ' || to_char(nvl(p_cod_modalidad, -1))||
                                  ' Cod tip cierre '||p_cod_tip_cierre );
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'Error al buscar cierre ' || SQLERRM || ' Proc: ' ||
                                  to_char(p_cod_procesadora) || ' Modal: ' ||
                                  to_char(nvl(p_cod_modalidad, -1)));
   END FU_OBT_FEC_VENCIMIENTO;

end pat_igp;
/
