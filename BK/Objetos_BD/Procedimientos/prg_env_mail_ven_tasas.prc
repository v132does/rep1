CREATE OR REPLACE PROCEDURE IT.prg_env_mail_ven_tasas IS
  v_fec_actual      date default pag_cal.fu_obt_fec_actual(1);
  v_nom_ente        ge_entes.descripcion%type;
  v_cod_per_ente    ge_entes.cod_persona%type;
  v_cod_per_oficial ba_usuarios.cod_persona%type;
  v_dir_mail_cre    ge_par_entes.val_parametro%type;
  v_dir_mail_usu    ge_par_dinamicos.val_parametro%type;
  v_mail_destino    varchar2(1000);
  c_dir_mail        ba_personas.dir_correo%type := fug_obt_dir_correo;
  v_texto           varchar2(4000);
  v_texto_detalle   clob;
  v_adjunto         clob;
  v_adjunto_error   clob;
  v_total_procesado number;
  v_total_error     number;

  --- Variables para mail
  v_conn            utl_smtp.connection;
  v_asunto          VARCHAR2(2000);
  v_mje_mail        LONG;
  v_cod_usu_oficial ge_clientes.cod_usu_oficial%type;

  --GAC 12/05/20147 Se agrega membrete de BBVA, a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M') || chr(10);
  V_FIN      LONG := chr(10) || fug_gen_template('F') || chr(10);
  V_PIE      LONG := chr(10) || fug_gen_template('P', c_dir_mail);
  V_NOM_BANCO VARCHAR2(100):= fug_obt_pardinamico('NOM_GNB_LAR_HTML');
  --
  -- DYDMR-5958 -- 01/2017 -- Se modifica el cursor -- 30 dias antes de la fecha de vencimiento --
  CURSOR c_tasas is
      select a.cod_tasa, a.fec_vigencia, b.cod_persona
        from ge_tas_fechas a, ge_entes b
       where a.cod_persona = b.cod_persona 
         and a.fec_vigencia > v_fec_actual
         and (a.fec_vigencia - v_fec_actual) between 1 and 30 
    union
      select a.cod_tasa, a.fec_vigencia, b.cod_persona
        from ge_tas_rangos a, ge_entes b
       where a.cod_persona = b.cod_persona
         and a.fec_vigencia > v_fec_actual
         and (a.fec_vigencia - v_fec_actual) between 1 and 30; 
  --
  FUNCTION fu_eli_acentos(p_cadena VARCHAR2) RETURN VARCHAR2 IS
    v_cadena VARCHAR2(4000);
  BEGIN
    IF p_cadena IS NOT NULL THEN
      v_cadena := translate(p_cadena,
                            'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
                            'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
      v_cadena := translate(v_cadena,
                            'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                            'aeiouAEIOUAaDO     a  o  y yAa                           ');
      v_cadena := translate(v_cadena, '''', '  ');
    END IF;
    RETURN(v_cadena);
  END;

  Function fu_val_correo(p_mail VARCHAR2) RETURN VARCHAR2 IS
    v_mail         VARCHAR2(319) := lower(p_mail);
    v_nom_usuario  VARCHAR2(64);
    v_nom_dominio  VARCHAR2(254);
    v_caracter     VARCHAR2(1);
    v_posicion     NUMBER(3);
    v_car_invalido NUMBER(3);
    v_con_caracter NUMBER(3) := 0;
    --
    v_pos_coma  NUMBER(3);
    v_pos_punto NUMBER(3);
  BEGIN
    --- Identificar el primer correo
    v_pos_punto := instr(v_mail, ';'); -- hasta el punto y coma
    v_pos_coma  := instr(v_mail, ','); -- hasta la coma
    IF v_pos_punto = 0 and v_pos_coma = 0 THEN
      v_posicion := length(v_mail);
    ELSIF v_pos_coma = 0 THEN
      v_posicion := v_pos_punto - 1;
    ELSIF v_pos_punto = 0 THEN
      v_posicion := v_pos_coma - 1;
    ELSIF v_pos_coma > v_pos_punto THEN
      v_posicion := v_pos_punto - 1;
    ELSIF v_pos_punto > v_pos_coma THEN
      v_posicion := v_pos_coma - 1;
    ELSE -- Contiene solo 1 correo
      v_posicion := length(v_mail);
    END IF;
    v_mail := substr(v_mail, 1, v_posicion);
    --
    v_posicion    := instr(v_mail, '@');
    v_nom_usuario := substr(v_mail, 1, instr(v_mail, '@') - 1);
    v_nom_dominio := substr(v_mail, instr(v_mail, '@') + 1);
    ---
    /*
    || Dominios Genéricos
    || ==================
    || .com .net .org
    || .mil .gov .edu .int .coop
    || .info .biz
    || .mobi
    */
    IF instr(v_nom_dominio, '.com', 1) > 0 OR
       instr(v_nom_dominio, '.net', 1) > 0 OR
       instr(v_nom_dominio, '.org', 1) > 0 OR
       instr(v_nom_dominio, '.mil', 1) > 0 OR
       instr(v_nom_dominio, '.gov', 1) > 0 OR
       instr(v_nom_dominio, '.edu', 1) > 0 OR
       instr(v_nom_dominio, '.int', 1) > 0 OR
       instr(v_nom_dominio, '.biz', 1) > 0 OR
       instr(v_nom_dominio, '.coop', 1) > 0 OR
       instr(v_nom_dominio, '.info', 1) > 0 OR
       instr(v_nom_dominio, '.mobi', 1) > 0 THEN
      null;
    ELSE
      return null;
    END IF;
    v_mail := fu_eli_acentos(v_mail);
    ---
    FOR i IN 1 .. length(v_mail) LOOP
      v_caracter := substr(v_mail, i, 1);
      IF v_caracter = '@' THEN
        v_con_caracter := v_con_caracter + 1;
      END IF;
    END LOOP;
    ---
    IF v_posicion <= 1 OR v_posicion = length(v_mail) OR v_con_caracter > 1 THEN
      return null;
    ELSIF substr(v_nom_usuario, 1, 1) = '.' OR
          substr(v_nom_usuario, length(v_nom_usuario), 1) = '.' THEN
      return null;
    ELSIF substr(v_nom_dominio, 1, 1) = '.' OR
          substr(v_nom_dominio, length(v_nom_dominio), 1) = '.' OR
          instr(v_nom_dominio, '.') = 0 THEN
      return null;
    ELSIF v_car_invalido > 0 THEN
      return null;
    ELSIF instr(v_mail, '..') > 0 THEN
      return null;
    ELSIF length(v_nom_usuario) > 64 THEN
      return null;
    ELSIF length(v_nom_dominio) > 255 THEN
      return null;
    END IF;
    RETURN v_mail;
  END;
  
  -- DYDMR-5958 -- 01/2017 -- Funcion para obtener la Descripcion del Ente
  FUNCTION lf_obt_nom_ente(p_cod_persona ba_personas.cod_persona%type) RETURN ge_entes.descripcion%type IS
    v_descripcion ge_entes.descripcion%type;
  BEGIN
   select descripcion
     into v_descripcion
     from ge_entes
    where cod_persona = p_cod_persona
      and rownum=1;
    RETURN v_descripcion;
  EXCEPTION
    WHEN OTHERS THEN
      return null;
  END;
  --
begin
  begin
    -- Envío de mail al titular de cta crédito.
    for a in c_tasas loop
      -- DYDMR-5958 -- 01/2017 --
      v_nom_ente     := lf_obt_nom_ente(a.cod_persona);
      v_cod_per_ente := a.cod_persona;
      --
      begin
        select a.cod_usu_oficial
          into v_cod_usu_oficial
          from ge_clientes a
         where a.cod_persona = v_cod_per_ente;
      exception
        when no_data_found then
          v_cod_usu_oficial := null;
      end;
    
      begin
        select a.cod_persona
          into v_cod_per_oficial
          from ba_usuarios a
         where a.cod_usuario = v_cod_usu_oficial;
      exception
        when no_data_found then
          v_cod_per_oficial := null;
      end;
    
      v_dir_mail_cre := fug_obt_dir_mail_per(v_cod_per_oficial);
      v_dir_mail_usu := fug_obt_pardinamico('MAIL_VEN_TAS_ENTE');
      v_mail_destino := v_dir_mail_usu || ';' || v_dir_mail_cre;
    
      v_adjunto         := null;
      v_adjunto_error   := null;
      v_total_procesado := 0;
      v_total_error     := 0;
    
      /*v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
      v_cabecera || chr(10) || v_adjunto || chr(10)||
      chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||
      v_resumen;*/
      --                               'Total Depósitos :'||chr(9)||v_total_procesado||chr(10);
    
      v_texto := '<br><br>
               <br><br>
                 Estimado ' || '
               <br><br>
                 Le informamos que la Tasa ' || a.cod_tasa ||
                 ' Correspondiente al Ente ' || v_nom_ente ||
                 ', con fecha de vigencia ' ||
                 to_char(a.fec_vigencia, 'DD/MM/YYYY') || ',' ||
                 ' se encuentra dentro de los 30 días de vencimiento.
               <br><br>
                 Atentamente.
               <br><br>
               <p align="center"><i><b>'||trim(V_NOM_BANCO)||'</b></i></p>
               <br><br>
               <br><br>';
      
      v_asunto   := 'Vencimiento Tasa Entes.';
      v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                    chr(10) || chr(10) || chr(10) || V_FIN || chr(10) ||
                    V_PIE;
    
      Begin
      
        v_conn := it_mail.begin_mail(c_dir_mail,
                                     v_mail_destino,
                                     v_asunto,
                                     IT_MAIL.MULTIPART_MIME_TYPE);
      
        it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
      
        /*it_mail.begin_attachment(v_conn,
        'text/plain',
        false,
        v_nom_adj ||'.xls');*/
      
        /*v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
        'SERVICIO DE RECAUDACION EN VENTANILLA' || CHR(10) ||
        v_texto_detalle;*/
      
        --it_mail.write_text(v_conn, v_texto_detalle);
      
        it_mail.end_mail(v_conn);
      
        insert into tm_mails
          (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
        values
          (c_dir_mail, v_dir_mail_cre, v_asunto, v_texto, sysdate, user);
      
      EXCEPTION
        when others then
          insert into tm_mails
            (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
          values
            (c_dir_mail,
             v_dir_mail_cre,
             v_asunto,
             v_texto_detalle,
             sysdate,
             user);
      end;
    
    end loop;
  
  EXCEPTION
    when others then
      raise_application_error(-20000, 'prg_env_mail_ven_tasas ' || sqlerrm);
  END;
end;
/

