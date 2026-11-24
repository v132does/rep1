CREATE OR REPLACE PROCEDURE IT.PRG_ENV_MAI_CTA_BASICA IS
  v_dir_mail    ge_par_entes.val_parametro%type;
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_dir_correo; 
  v_texto         varchar2(4000);
  v_texto_detalle  varchar2(32000);
  --- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  V_NOM_BANCO VARCHAR2(100):= fug_obt_pardinamico('NOM_GNB_LAR_HTML');

  CURSOR c_bcp_cta_basica is
    select fua_val_cta_basica(b.cod_persona, 'C') as cta_basica,
           b.cod_persona,
           c.nom_completo,
           b.nro_cuenta,
           a.fec_apertura,
           d.cod_usu_oficial,
           e.nombre,
           nvl(e.dir_correo, fug_obt_pardinamico('DIR_MAIL_CTA_BASICA', 3, 31, null, null, null)) as dir_correo
      from ah_cta_vistas   a,
           ge_cta_clientes b,
           ba_personas     c,
           ge_clientes     d,
           ba_usuarios     e
     where a.cod_sub_modalidad = 26
       and b.relacion = 'P'
       and a.nro_cuenta = b.nro_cuenta
       and c.cod_persona = b.cod_persona
       and d.cod_persona = c.cod_persona
       and e.cod_usuario = d.cod_usu_oficial;
    
  FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2
   ) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
   BEGIN
      IF p_cadena IS NOT NULL THEN
         v_cadena := translate(p_cadena,
                  '???????????????????????????????,+?~|????!"#$%&/()=???*?{}^`?[]:;><??%',
                  'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
         v_cadena := translate(v_cadena,
                  '????????????????????????????Aa\????????????????????????',
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
      || Dominios Gen?ricos
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
    
    for c in c_bcp_cta_basica loop
      
       pre_cam_for_numerico('.,'); 

       v_dir_mail := c.dir_correo;
       v_dir_mail := fu_val_correo(v_dir_mail);
      
       if v_dir_mail is not null and c.cta_basica = 'N' then
           v_texto := '<br><br>
                       <br><br>
                           Estimado '||upper(c.nombre)||'
                         <br><br>
                           Su cliente :'||c.nom_completo||' - codigo persona nro.: '||c.cod_persona||', cuenta con m&aacute;s de '||  
                           fug_obt_pardinamico('MAX_CAN_CTA_BASICAS', 3, 31, 'GS', null, '26')||' cuentas b&aacute;sicas en el sistema financiero.'||
                         '<br><br>
                           Favor pongase en contacto inmediatamente con el mismo, para cancelar la &uacute;ltima aperturada.
                         <br><br>
                         <p align="center"><i><b>'||trim(V_NOM_BANCO)||'</b></i></p>
                         <br><br>
                         <br><br>';

           v_asunto   := 'Cantidad de Cuentas Basicas Superada';
           v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                            chr(10) || chr(10) || chr(10) || V_FIN || chr(10)|| V_PIE;
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
                              values (c_dir_mail, v_dir_mail, v_asunto, 'No se encuentra la direccion de mail.', sysdate, user);
        end if;
    end loop;

  EXCEPTION
    when others then
     raise_application_error(-20000,'PRG_ENV_MAI_CTA_BASICA '||sqlerrm);
  END;
end;
/

