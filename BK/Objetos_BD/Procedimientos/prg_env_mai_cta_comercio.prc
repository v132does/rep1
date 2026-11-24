CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAI_CTA_COMERCIO IS
  v_fec_actual  date default pag_cal.fu_obt_fec_actual(1);
  v_dir_mail    ge_par_entes.val_parametro%type;
  v_nom_cliente  ba_personas.nom_completo%type;
  v_dir_gestor   varchar2(1000);
  v_cam_cta_com  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('CCO_CAM_CTA_COMERCIO');
  c_dir_mail     ba_personas.dir_correo%type  := fug_obt_dir_correo; --'infobbva@bbva.com'; -- Modificado DYDMR-9804
  v_texto         varchar2(4000);
  v_texto_detalle  varchar2(32000);
  --- Variables para Mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  V_NOM_BANCO VARCHAR2(100):= fug_obt_pardinamico('NOM_GNB_LAR_HTML');

  CURSOR c_lin_sob_cta_com is
     select c.cod_persona, cl.cod_usu_oficial, d.nro_cuenta, d.cod_moneda, d.monto
       from cc_lin_sobregiros c, cc_lin_sobregiros d, ge_clientes cl
      where c.fec_inicio = v_fec_actual
        and instr(','|| v_cam_cta_com ||',' ,  ','||c.cod_campana||',') > 0
        and c.nro_secuencia = d.nro_sec_padre
        and c.cod_persona = cl.cod_persona;

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
  begin
    for c in c_lin_sob_cta_com loop
       pre_cam_for_numerico('.,'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)

       v_dir_mail := fug_obt_dir_mail_per(c.cod_persona);
       v_dir_mail := fu_val_correo(v_dir_mail);

       v_nom_cliente  := fue_obt_nom_persona(c.cod_persona);
       v_texto_detalle := null;

       v_dir_gestor := fug_obt_dir_mail_usu(c.cod_usu_oficial);

       if v_dir_mail is not null and v_dir_gestor is not null then
          v_dir_mail := v_dir_mail ||'; '||v_dir_gestor;
       elsif v_dir_mail is null and v_dir_gestor is not null then
          v_dir_mail := v_dir_gestor;
       end if;

       if v_dir_mail is not null then
           v_texto := '<br><br>
                       <br><br>
                           Estimado Cliente: '||upper(v_nom_cliente)||'
                         <br><br>
                           Tenemos el agrado de informarle que le ha sido asignada una línea de sobregiro por la suma de '||c.cod_moneda||'. '||c.monto||' en la cuenta '||c.nro_cuenta|| ',<br><br> sujeto a las condiciones vigentes del producto.
                         <br><br>
                           Atentamente.
                         <br><br>
                         <p align="center"><i><b>'||trim(V_NOM_BANCO)||'</b></i></p>
                         <br><br>
                         <br><br>';

           v_asunto   := 'Otorgamiento de Línea de Sobregiro.';
           v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                            chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
           BEGIN
              v_conn     := it_mail.begin_mail(c_dir_mail,
                                               v_dir_mail,
                                               v_asunto,
                                               IT_MAIL.MULTIPART_MIME_TYPE);



              it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
              it_mail.write_text(v_conn, v_texto_detalle);
              it_mail.end_mail(v_conn);
          EXCEPTION
             when others then
                v_texto := substr(v_texto || '- ERROR [' || SQLERRM || ']', 1, 4000);
                insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                              values (c_dir_mail, v_dir_mail, v_asunto, v_texto, sysdate, user)  ;
          end;
        else
          insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                              values (c_dir_mail, v_dir_mail, v_asunto, 'No se encuentra la dirección de mail.', sysdate, user);
        end if;
    end loop;

  EXCEPTION
    when others then
     raise_application_error(-20000,'PRG_ENV_MAI_CTA_COMERCIO '||sqlerrm);
  END;
end;
/

