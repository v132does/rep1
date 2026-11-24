create or replace procedure it.prw_gen_cla_acceso(
p_cod_persona in varchar2, --empresa
p_cod_per_vinculo in varchar2, --persona vinculada
p_telefono in varchar2 --nro de teléfomo de persona vinculada
) is
/*Para Activacion de clave de Personas Juridicas
  Estado de la clave (N/Nuevo, B/Bloqueado, A/Activo, I/Impreso, X/Anulado).*/
v_lugar varchar2(3000);
v_resultado number;
v_clave      varchar2(100);
v_clave_aux number;
v_actualizo boolean;
v_mail  varchar2(200);
v_dir_correo_ent  varchar2(100) := fug_obt_dir_correo;
v_cod_origen varchar2(200);
v_men_celular varchar2(140);
v_men_email varchar2(1000);
v_empresa   varchar2(1000);
v_cliente   varchar2(1000);
v_nro_doc_cliente varchar2(100);
v_cabecera   VARCHAR2(700)  := NULL;
v_detalle    VARCHAR2(3300) := NULL;
v_pie        VARCHAR2(500)  := NULL;
v_fin_detalle varchar2(3000):= null;


begin
      begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;
      v_lugar:='Al asignar nombre';
      v_cod_origen := 'GENCLAPJ';

      v_mail:= FUG_OBT_DIR_MAIL_PER(p_cod_per_vinculo);




      v_lugar:='Al generar ope clave';
      v_clave := paw_bce.fu_gen_ope_clave('',
                                           p_cod_per_vinculo,
                                           p_cod_persona,
                                           'C',
                                           'A',
                                           v_clave_aux);
      -- Actualizar el valor del estado de la clave a IMPRESA.
      v_lugar:='Actualizar el valor del estado de la clave a IMPRESA';
      v_actualizo := paw_bce.fu_act_est_clave(p_cod_per_vinculo,
                                              p_cod_persona,
                                              'A',
                                              'I');

      if not v_actualizo then
          v_lugar:='cancelo la clave impresa generada';
                --cancelo la clave impresa generada
                  Update bw_ope_claves a
                     Set a.est_clave   = 'X'
                   Where a.cod_persona = p_cod_per_vinculo
                     and a.est_clave = 'I'
                     and a.tip_clave = 'A'
                     and a.cod_per_vinculada = p_cod_persona
                     and trunc(a.fec_modificacion) = trunc(sysdate);
         raise_application_error(-20000,'Error al actualizar el valor de la clave a Impresa: '|| sqlerrm);
      else
         -- Actualizar  el valor del estado de la clave a ACTIVO
         v_actualizo := paw_bce.fu_act_est_clave(p_cod_per_vinculo,
                                              p_cod_persona,
                                              'A',
                                              'A');

         if not v_actualizo then
                 v_lugar:='cancelo la clave Activa generada';
                --cancelo la clave generada
                  Update bw_ope_claves a
                     Set a.est_clave   = 'X'
                   Where a.cod_persona = p_cod_per_vinculo
                     and a.est_clave = 'A'
                     and a.tip_clave = 'A'
                     and a.cod_per_vinculada = p_cod_persona
                     and trunc(a.fec_modificacion) = trunc(sysdate);
                raise_application_error(-20000,'Error al actualizar estado de clave a Activo:' || sqlerrm);
          end if;


      end if;
      v_lugar:='Al obtener nombre de empresa';
      v_empresa:= fue_obt_nom_persona(P_COD_PERSONA);
      --Enviamos SMS
      if p_telefono is not null then
          v_men_celular:=null;
          -- Enviamos mensaje al cliente
          v_lugar:='Al enviar mensaje de prueba';
          --Limpio variable de resultado
          v_resultado := 99;
          --cortamos en 140
          v_men_celular:=trim(substr(trim(fug_obt_parentes(6331,'COD_MEA_CLA_FACIL_PJ_INI')||' '||v_clave_aux||' '||fug_obt_parentes(6331,'COD_MEA_CLA_FACIL_PJ_FIN')||' '||v_empresa),1,140));
          v_lugar:='Al enviar mensaje de prueba..';
          v_resultado:= paw_not.fu_env_sms_prueba(p_telefono,
                                                  v_men_celular,
                                                  v_cod_origen);

          v_lugar:='Al enviar mensaje de prueba..';
          IF v_resultado = -99 THEN
             INSERT INTO tm_mails(env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
             VALUES(v_dir_correo_ent, v_mail, 'Env. Msj.Clave de Acceso PJ', v_men_celular, SYSDATE, null, user, null);

          END IF;
      end if;
      --Enviamos mail al cliente, si tiene correo registrado
      v_lugar:='Al enviar mail al cliente';
      v_resultado := 99;

      if v_mail is not null then
         --Obtenemos los datos del cliente
          v_men_email:=null;
          v_men_email:= fug_obt_parentes(6331,'MEN_COA_CLA_FACIL_PJ')||' '|| p_telefono||'.';
          v_fin_detalle:= fug_obt_parentes(6331,'MEN_FIN_CLA_FACIL_PJ');
          v_nro_doc_cliente:=null;
          v_cliente:= null;
          v_cliente:= fue_obt_nom_persona(p_cod_per_vinculo);
          v_nro_doc_cliente:= fue_obt_nro_doc_persona(p_cod_per_vinculo);
           -- ---------- cabecera --------------
          v_cabecera :=
                -- inicio div
                paw_pro.fu_not_inicio;-- ||
                -- titulo
                --paw_pro.fu_not_titulo(UTL_URL.ESCAPE('Recibo de Clave de Acceso BBVA', TRUE, 'UTF-8'));
                -- subtitulo
                v_cabecera := v_cabecera ||
                paw_pro.fu_not_sub_titulo(UTL_URL.ESCAPE('Estimado/a Cliente:', TRUE, 'UTF-8'));
                v_cabecera := v_cabecera ||
                      -- inicio tabla
                      paw_pro.fu_not_ini_tabla ||
                      -- inicio tbody
                      paw_pro.fu_not_ini_tab_cuerpo;

          -- detalles
          v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Nombre del Cliente ', TRUE, 'UTF-8'), v_cliente);
          v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('C.I ', TRUE, 'UTF-8'), v_nro_doc_cliente);
          v_detalle := v_detalle || paw_pro.fu_not_row_tag(UTL_URL.ESCAPE('Empresa ', TRUE, 'UTF-8'), v_empresa);

           -- fin tbody
          v_detalle := v_detalle ||
          paw_pro.fu_not_fin_tab_cuerpo ||
          -- fin table
          paw_pro.fu_not_fin_tabla;

          v_detalle := v_detalle ||
          paw_pro.fu_not_sub_titulo(UTL_URL.ESCAPE(v_men_email, TRUE, 'UTF-8'));

          v_detalle := v_detalle ||chr(10)||chr(10)||chr(10)||chr(10)||
          paw_pro.fu_not_sub_titulo(UTL_URL.ESCAPE(v_fin_detalle, TRUE, 'UTF-8'));


          -- fin div
          v_pie := paw_pro.fu_not_fin;


          v_resultado:= paw_not.fu_env_email_prueba(v_mail,
                                                  v_cabecera || v_detalle || v_pie,
                                                  v_cod_origen);


            v_lugar:='Al guardar error en envio de mail al cliente';
            IF v_resultado = -99  THEN
               INSERT INTO tm_mails(env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
               VALUES(v_dir_correo_ent, v_mail, 'Notif. Mail Clave de Acceso PJ', v_men_email, SYSDATE, null, user, null);
            END IF;
       end if;

EXCEPTION
  WHEN OTHERS THEN
      raise_application_error(-20000, 'Error Gen.Cla.PJ: '||p_cod_persona||' / '||p_cod_per_vinculo||'-'||v_lugar||'-'|| sqlerrm);
end prw_gen_cla_acceso;
/

