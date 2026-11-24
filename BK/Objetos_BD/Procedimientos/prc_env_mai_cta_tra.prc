CREATE OR REPLACE PROCEDURE IT.prc_env_mai_cta_tra(p_tip_proceso varchar2 default 'J') IS
  v_fec_actual  date default pag_cal.fu_obt_fec_actual(1);
  v_dir_mail        ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAI_CTA_TRA_BANCARD');
  v_ext_archivo     ge_par_entes.val_parametro%type := 'xls';
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');
  v_texto         varchar2(4000);
  v_texto_detalle  varchar2(32000);
  v_adjunto       varchar2(32000);
  v_cabecera      clob;
  v_nom_adj varchar2(500);
  v_total_procesado number ;
  v_total_error number ;
  v_can_facturas number;

  v_file         UTL_FILE.FILE_TYPE;

  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;

 /* -- Variables coneccion*/
  g_repository         VARCHAR2(100) := 'MAIL';
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_ip                 VARCHAR2(100) := '192.168.254.136';
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := '21';
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_user               VARCHAR2(100) := 'ftpramail';
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_pass               VARCHAR2(100) := 'kacha.ma1';
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_dia_max_reversion  number(10) := nvl( fug_obt_pardinamico ( 'SNP_DIA_MAX_REVERSION' ), 0 );

  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  --

  CURSOR c_cta_transaccional is
    select c.nro_cuenta, c.cod_moneda, c.denominacion,
           decode(p_tip_proceso, 'C', c.sal_total, fuc_obt_sal_act_cta_tra(c.nro_cuenta, 'S')) sal_total
      from cc_cta_corrientes c, cc_cta_transaccionales ct
     where c.nro_cuenta = ct.nro_cuenta
       and ct.tip_cta_transaccional = 'BA'
       and nvl(fuc_ver_cta_transaccional(c.nro_cuenta), 'N') = 'S'
       and c.cod_sub_modalidad = 25
    order by 1;

  FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2
   ) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
   BEGIN
      IF p_cadena IS NOT NULL THEN
         v_cadena := translate(p_cadena,
                  'áéíóúrcenuäëdöüÁÉÍÓÚÝÄËDÖÜRCENU,+´~|°sS¬!"#$%&/()=??z*¨{}^`z[]:;><Çç%',
                  'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
         v_cadena := translate(v_cadena,
                  'âeîôuÂEÎÔUAaÐO×RÝTßlcdor÷ýt?Aa\?L¤A¦§©«®Z±?lµ¶·¸as»L?lz',
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
  begin
    pre_cam_for_numerico('.,'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
    v_texto_detalle := null;
    v_adjunto       := null;

    v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente:
                   <br><br>
                     Le informamos el saldo actual de las cuentas transaccionales en la fecha ' ||
                             to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' el cual detalla en el archivo adjunto.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';

    v_nom_adj := nvl(fug_obt_pardinamico('NOM_ARC_CTA_TRA'),'CTA_TRA_') ||to_char(v_fec_actual, 'DDMMYY');

    v_asunto   := 'Informe Cuentas Transaccionales';
    v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                  chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

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
                                  v_nom_adj ||'.'||v_ext_archivo);
         --*********Para Grabar Cabecera ***************************************
         v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                            'INFORME DE CUENTAS TRANSACCIONALES' || CHR(10)||CHR(10);
         it_mail.write_text(v_conn, v_texto_detalle);


         v_cabecera := 'Nro. Cuenta' || chr(9) || 'Denominación' || chr(9) ||
                       'Cod. Moneda' || chr(9) ||'Saldo Actual'|| chr(10);
         it_mail.write_text(v_conn, v_cabecera);

         --************Para Grabar Detalle **************************************
         for c in c_cta_transaccional loop
           v_adjunto:=null;
           v_adjunto := c.nro_cuenta || chr(9) ||
                        c.denominacion|| chr(9)||
                        c.cod_moneda || chr(9) ||
                        c.sal_total  ||chr(9) ||chr(10);

           it_mail.write_text(v_conn, v_adjunto);
         end loop;
         --************fin de Grabar Detalle **************************************
         it_mail.end_mail(v_conn);
      EXCEPTION
         when others then
           v_texto := substr(v_texto || '- ERROR [' || SQLERRM || ']', 1, 4000);
           insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
           values (c_dir_mail, v_dir_mail, v_asunto, v_texto, sysdate, user);
      END;

      UTL_FILE.FCLOSE(v_file);
      COMMIT;
    end if;


  EXCEPTION
    when others then
       v_texto := substr(v_texto || '- ERROR [' || SQLERRM || ']', 1, 4000);
       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
       values (c_dir_mail, v_dir_mail, v_asunto, v_texto, sysdate, user);
  END;
end;
/

