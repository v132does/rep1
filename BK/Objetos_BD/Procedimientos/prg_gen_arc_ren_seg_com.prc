CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_REN_SEG_COM(p_fecha date default null)is
  v_fec_actual      date  default pag_cal.fu_obt_fec_actual(1);
  v_ext_archivo     ge_par_entes.val_parametro%type;
  v_adjunto         varchar2(32000);
  v_total_procesado number ;
  v_file            UTL_FILE.FILE_TYPE;
  v_line            VARCHAR2(32767);  
  v_name            VARCHAR2(128);-- nombre del archivo
  v_hora            varchar2(12);
  v_error           varchar2(3000);
  -- FTP
  v_hini_ftp        ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp        ge_ra_log_ftp.hor_fin%type;
  v_respuesta       VARCHAR2(4000);
  /* -- Variables coneccion*/
  v_repository      VARCHAR2(100);
  g_ip              VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');--'62.12.240.24'
  g_port            VARCHAR2(100) := '21';
  g_user            VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass            VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_directorio      VARCHAR2(100);
  v_membrete LONG := fug_gen_template('M')|| chr(10); 
  --variables de mail
  v_dir_mail        ge_par_dinamicos.val_parametro%type;
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
  v_conn            utl_smtp.connection;
  v_texto           varchar2(4000);
  v_texto_detalle   varchar2(32000);    
  v_nom_adj         varchar2(500);
  v_asunto          VARCHAR2(2000);
  v_mje_mail        LONG;  
  v_cabecera        clob;
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P');  
  v_men_error  varchar2(4000);
  v_fec_desde ge_calendarios.fec_actual%type := trunc(v_fec_actual, 'MM');
  v_fec_ini_ven_seg ge_pol_seguros.fec_inicial%type := TRUNC(add_months(v_fec_actual,1 ), 'MM');
  v_fec_fin_ven_seg ge_pol_seguros.fec_final%type := TRUNC(LAST_DAY(add_months(v_fec_actual, 1)));
--****** Tarjetas de Debito
CURSOR c_seg is
  select 'A_VENCER' origen, p.nom_completo, r.cod_persona, p.nro_documento, s.codigo cod_sebaot, s.nro_poliza, se.significado seccion, s.sub_seccion,
         s.fec_inicial, s.fec_final, s.fec_propuesta, r.cod_ente, e.descripcion aseguradora, s.mto_prima,
         s.cod_moneda, si.significado situacion, es.significado estado
    from ge_ren_pol_seguros r, ge_pol_seguros s, ba_personas p, ge_entes e, 
         ba_cod_referencias se, ba_cod_referencias si, ba_cod_referencias es
   where r.fecha >= v_fec_desde
     and r.nro_seg_ant = s.codigo
     and r.cod_persona = p.cod_persona
     and r.cod_ente = e.cod_ente
     and se.dominio = 'SEC_SEGURO'
     and se.val_minimo = s.seccion
     and si.dominio = 'SIT_POLIZA'
     and si.val_minimo = s.situacion
     and es.dominio = 'EST_POLIZA'
     and es.val_minimo = s.estado
     and R.estado = 'I'
     AND not exists (select w.referencia
                       from Ge_Pol_Seguros w
                      where w.referencia = r.nro_poliza
                        and w.codigo > r.nro_seg_ant)
  union all
  select 'A_VENCER' origen, p.nom_completo, s.cod_persona, p.nro_documento, s.codigo cod_sebaot, s.nro_poliza, se.significado seccion, s.sub_seccion,
         s.fec_inicial, s.fec_final, s.fec_propuesta, s.cod_ente, e.descripcion aseguradora, s.mto_prima,
         s.cod_moneda, si.significado situacion, es.significado estado
    from ge_pol_seguros s, ba_personas p, ge_entes e, 
         ba_cod_referencias se, ba_cod_referencias si, ba_cod_referencias es
   where s.cod_persona = p.cod_persona
     and s.cod_ente = e.cod_ente
     and se.dominio = 'SEC_SEGURO'
     and se.val_minimo = s.seccion
     and si.dominio = 'SIT_POLIZA'
     and si.val_minimo = s.situacion
     and es.dominio = 'EST_POLIZA'
     and es.val_minimo = s.estado
     AND s.estado in(2, 3) 
     AND s.situacion in(1, 2, 3) 
     AND s.FEC_FINAL BETWEEN v_fec_ini_ven_seg AND v_fec_fin_ven_seg
     AND not exists (SELECT nro_poliza FROM ge_ren_pol_seguros where nro_seg_ant = s.codigo)
     AND s.sub_seccion NOT LIKE '%CAUCION%' AND s.sub_seccion NOT LIKE '%R.C. INTERNACIONAL%'
     AND exists (select 1 from ba_cod_referencias where dominio = 'EXC_ENT_REN_SEG' 
                    and val_minimo = decode(s.seccion, 'V', decode(s.cod_sub_seccion, '0401', 'P', s.seccion), s.seccion)||s.cod_ente
                    and val_maximo = 'S')
     AND not exists (select w.referencia
                       from Ge_Pol_Seguros w
                      where w.referencia = s.nro_poliza
                        and w.codigo > s.codigo);
     
  FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2
   ) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
   BEGIN
      IF p_cadena IS NOT NULL THEN
         v_cadena := translate(p_cadena,
                  'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
                  'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
         v_cadena := translate(v_cadena,
                  'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                  'aeiouAEIOUAaDO     a  o  y yAa                           ');
         v_cadena := translate(v_cadena,
                  '''',
                  '  ');
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
      v_pos_coma     NUMBER(3);
      v_pos_punto    NUMBER(3);
   BEGIN
      --- Identificar el primer correo
      v_pos_punto    := instr(v_mail, ';'); -- hasta el punto y coma
      v_pos_coma     := instr(v_mail, ','); -- hasta la coma
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
      IF instr(v_nom_dominio,'.com',1) > 0 OR
         instr(v_nom_dominio,'.net',1) > 0 OR
         instr(v_nom_dominio,'.org',1) > 0 OR
         instr(v_nom_dominio,'.mil',1) > 0 OR
         instr(v_nom_dominio,'.gov',1) > 0 OR
         instr(v_nom_dominio,'.edu',1) > 0 OR
         instr(v_nom_dominio,'.int',1) > 0 OR
         instr(v_nom_dominio,'.biz',1) > 0 OR
         instr(v_nom_dominio,'.coop',1) > 0 OR
         instr(v_nom_dominio,'.info',1) > 0 OR
         instr(v_nom_dominio,'.mobi',1) > 0 THEN
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
      IF v_posicion <= 1 OR
         v_posicion = length(v_mail) OR
         v_con_caracter > 1 THEN
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
begin
  v_hora:= to_char(sysdate,'hh24:mi:ss');
  v_repository:= fug_obt_pardinamico('REN_SEG_CI_ARC_REP');--'MAIL';
  v_directorio:= fug_obt_pardinamico('REN_SEG_CI_ARC_DIR');--'ramail\DYD\';
  v_ext_archivo := nvl(fug_obt_pardinamico('REN_SEG_CI_ARC_EXT'),'csv');
  v_dir_mail := fug_obt_pardinamico('REN_SEG_CI_DIR_COR');
    
  -- Tipo de Archivo
  if v_ext_archivo is not null then
     if lower(v_ext_archivo) != 'xls' or lower(v_ext_archivo) != 'txt' or lower(v_ext_archivo) != 'csv' then
        if lower(v_ext_archivo) like '%xls%' then
           v_ext_archivo := 'xls';
        end if;
        if lower(v_ext_archivo) like '%txt%' then
           v_ext_archivo := 'txt';
        end if;
        if lower(v_ext_archivo) like '%csv%' then
           v_ext_archivo := 'csv';
        end if;
     end if;
     if v_ext_archivo not in ('xls','txt', 'csv') then
        v_ext_archivo := 'xls';
     end if;
  else
     v_ext_archivo := 'xls';
  end if;
  
  v_cabecera := 'ORIGEN' || ';' || 'NOMBRE' || ';' || 'COD. CLIENTE' || ';' || 'NRO. DOCUMENTO' || ';' ||
                'COD. SEBAOT' || ';' ||'NRO. POLIZA' || ';' ||
                'SECCION' || ';' || 'SUB SECCION'|| ';' || 'FEC. INICIAL' || ';' ||'FEC FINAL'|| ';' ||
                'FEC. PROPUESTA' || ';' || 'COD. ENTE'|| ';' || 'ASEGURADORA' || ';' ||'MTO. PRIMA'|| ';' ||
                'COD. MONEDA' || ';' || 'SITUACION'|| ';' || 'ESTADO' || ';' ;


  --Seteos iniciales
  v_line := null;
  v_adjunto       := null;
  v_total_procesado := 0;  --Seteos iniciales
  v_texto_detalle := null;
  v_name := 'segurosAVencer-' || to_char(v_fec_actual, 'MMYYYY');
  v_name:=lower(v_name);

  if v_directorio is null then
     --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,v_name,' No tiene parametrizado Directorio parametrizado', sysdate, user);
  end if;

  if v_repository is null then
     --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,v_name,' No tiene parametrizado Repositorio parametrizado', sysdate, user);
  end if;
  
  v_dir_mail        := trim(v_dir_mail);
  if v_dir_mail is null then
     --Si esta nulo se toma se guarda error
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail, v_name, ' No tiene parametrizado direccion de mail', sysdate, user);
  end if;

  if v_repository is not null and v_directorio is not null then
     v_file := UTL_FILE.FOPEN(v_repository,
                              v_name || '.'||lower(v_ext_archivo),
                              'W',
                              32767);
  end if;
  
  if v_repository is not null and v_directorio is not null then
     v_texto := '<br><br>
                     <br><br>
                       Estimados,
                     <br><br>
                       Adjunto el listados se seguros a Vencer. 
                     <br><br>
                       Atentamente.
                     <br><br>
                     <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                     <br><br>
                     <br><br>';  
     v_nom_adj := v_name;
     v_asunto   := 'Servicio de Notificación de Renovación Seguros para Inteligencia Comercial';
     v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                          chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
                                                
     UTL_FILE.PUT_LINE(v_file, v_cabecera);                          
     --ENVIO DE MAIL
     if v_dir_mail is not null then                     
        Begin
          v_conn     := it_mail.begin_mail(c_dir_mail,
                                           v_dir_mail,
                                           v_asunto,
                                           IT_MAIL.MULTIPART_MIME_TYPE);

          it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

          it_mail.begin_attachment(v_conn,
                                   'text/plain',
                                    false,
                                    v_nom_adj ||'.'||lower(v_ext_archivo));
                                    
          it_mail.write_text(v_conn, v_cabecera||chr(10));     
          
          for w in c_seg loop
            v_total_procesado := v_total_procesado + 1;
            
            v_adjunto:=null;
            v_adjunto := w.origen||';'||w.nom_completo||';'||w.cod_persona||';'||w.nro_documento|| ';' ||
                         w.cod_sebaot|| ';' ||w.nro_poliza|| ';' ||w.seccion|| ';' ||w.sub_seccion|| ';' ||
                         to_char(w.fec_inicial, 'DD/MM/YYYY')|| ';' ||to_char(w.fec_final, 'dd/mm/yyyy')|| ';' ||
                         to_char(w.fec_propuesta, 'DD/MM/YYYY')|| ';' ||w.cod_ente|| ';' ||w.aseguradora|| ';' ||
                         w.mto_prima|| ';' ||w.cod_moneda|| ';' ||w.situacion|| ';' ||w.estado|| ';' ||chr(10);
     
            it_mail.write_text(v_conn, v_adjunto);
          end loop;
          --************fin de Grabar Detalle **************************************
          it_mail.end_mail(v_conn);
       end;
     end if;                          
     --*****************Para Depositar en archivo**********************
     Begin
        -- Punto para la parte decimal y coma para separador de miles.
        pre_cam_for_numerico('.,');
        for w in c_seg loop
           v_total_procesado := v_total_procesado + 1;
           v_adjunto:=null;           
           v_adjunto := w.origen||';'||w.nom_completo||';'||w.cod_persona||';'||w.nro_documento|| ';' ||
                        w.cod_sebaot|| ';' ||w.nro_poliza|| ';' ||w.seccion|| ';' ||w.sub_seccion|| ';' ||
                        to_char(w.fec_inicial, 'DD/MM/YYYY')|| ';' ||to_char(w.fec_final, 'dd/mm/yyyy')|| ';' ||
                        to_char(w.fec_propuesta, 'DD/MM/YYYY')|| ';' ||w.cod_ente|| ';' ||w.aseguradora|| ';' ||
                        w.mto_prima|| ';' ||w.cod_moneda|| ';' ||w.situacion|| ';' ||w.estado|| ';';
           UTL_FILE.PUT_LINE(v_file, v_adjunto);
         end loop;
      EXCEPTION
         when others then
           v_hora:= to_char(sysdate,'hh24:mi:ss');
           v_error:= substr(to_char(sqlerrm),1,3000);
           INSERT INTO ge_ra_log_mail
                      (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                 VALUES
                      (SYSDATE, v_nom_adj, 'ERROR', 'Envio Sol. Ren. Seguro ', v_error,v_hora , v_hora);

      END;

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);
      COMMIT;
      v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
      -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
      v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                               g_port,
                                               g_user,
                                               g_pass,
                                               v_repository,
                                               lower(v_name) || '.'||lower(v_ext_archivo),
                                               lower(v_directorio) || lower(v_name)|| '.'||lower(v_ext_archivo));
       v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
       IF v_respuesta <> 'OK' THEN
       -- Insertamos el error del envio al directorio compartido
         INSERT INTO ge_ra_log_ftp
                            (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
              VALUES (SYSDATE, v_name, v_respuesta, v_hini_ftp, v_hfin_ftp);
       end if;
       COMMIT;
  end if;
  
  -- Actualiza el estado de inteligencia comercial
  begin
    update ge_ren_pol_seguros r
       set r.ind_int_comercial = 'S'
     where r.fecha >= v_fec_desde
       and r.estado = 'I';
  END;

--*********************************************************************************************************
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
  WHEN OTHERS THEN
     raise_application_error(-20000,'PRG_GEN_ARC_REN_SEG_COM '||sqlerrm);
END PRG_GEN_ARC_REN_SEG_COM;
/

