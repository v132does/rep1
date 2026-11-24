CREATE OR REPLACE PROCEDURE IT.PRL_ENV_MAI_MSJ_SWIFT
( p_fecha IN ge_movimientos.fecha%TYPE,
  p_hora  IN ge_movimientos.hora%TYPE) IS

  v_fec_actual   date default pag_cal.fu_obt_fec_actual(1);
  v_dir_mail     ba_mails.dir_correo%type;
  v_nom_cliente  ba_personas.nom_completo%type;
  c_dir_mail     ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
  v_texto        varchar2(4000);
  v_tex_pie      varchar2(4000);
  v_msj_swift    varchar2(4000);
  -- Variables para mail
  v_conn         utl_smtp.connection;
  v_asunto       VARCHAR2(2000);
  v_mje_mail     LONG;
  v_mje_mail_pie LONG;
  v_tex_correo   varchar2(4000):= fug_obt_pardinamico('TEX_MAI_MSJ_SWIFT');
  v_hini_mail  ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail  ge_ra_log_mail.hor_fin%type;
  v_det_error  ge_ra_log_mail.det_error%type;
  
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
 

  CURSOR lc_trans IS
  select a.cod_per_solicitante,a.fec_envio,a.nom_solicitante,a.msj_swift
       from lc_transferencias a
      where estado = 'E' --lo q se acaba de marcar como enviado
        and fec_envio = p_fecha
        and hor_envio = p_hora
      order by 1;
      
  FUNCTION lf_obt_dir_mail(P_COD_PERSONA IN ba_personas.cod_persona%type) 
      RETURN VARCHAR2 IS
      v_mail VARCHAR2(320);
   BEGIN
      BEGIN
          select a.dir_correo
            into v_mail
            from ba_mails a
           where a.cod_persona = P_COD_PERSONA
             and a.tipo = 'S';
      EXCEPTION
         WHEN OTHERS THEN
            v_mail := NULL;
      END;
      RETURN v_mail;
   END;
          

begin
  begin
     v_asunto   :='Aviso SWIFT';     
     v_texto    :='<br><br>
                   <br><br>
                   Estimado Cliente '||'
                   <br><br>'
                   ||v_tex_correo;
         
     v_tex_pie := '<br><br>
                  Atentamente.
                  <br><br>
                  <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                  <br><br>
                  <br><br>';
     v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                   chr(10) || chr(10) || chr(10);
     v_mje_mail_pie := v_tex_pie||chr(10) || V_FIN|| chr(10)|| V_PIE;                
     -- Envío de mail
     for t in lc_trans loop 
        v_det_error       := null;
        v_hini_mail       := to_char(sysdate,'hh24:mi:ss');      
        v_nom_cliente := t.nom_solicitante; 
        v_msj_swift := 'Solicitante: '||upper(v_nom_cliente)
                       ||chr(10)||
                       'Fecha Proceso: '||to_char(t.fec_envio,'DD/MM/YYYY')
                       ||chr(10)||
                       'Mensaje Swift: '
                       ||chr(10)||
                       chr(10)||
                       t.msj_swift; 
        v_dir_mail := lf_obt_dir_mail(t.cod_per_solicitante);

        if v_dir_mail  is not null then
            Begin
                v_conn     := it_mail.begin_mail(c_dir_mail,
                                                 v_dir_mail,
                                                 v_asunto,
                                                 IT_MAIL.MULTIPART_MIME_TYPE);
                it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                it_mail.attach_text(v_conn, v_msj_swift, 'text/plain');
                it_mail.attach_text(v_conn, v_mje_mail_pie, 'text/html');
                it_mail.end_mail(v_conn);
            EXCEPTION
              when utl_smtp.transient_error or utl_smtp.permanent_error then
                  begin
                    utl_smtp.quit(v_conn);
                  exception
                  when utl_smtp.transient_error or utl_smtp.permanent_error then
                    null;
                  end;
                  v_det_error := substr(sqlerrm,1,4000);
             END;

              v_hfin_mail := to_char(sysdate,'hh24:mi:ss');
              -- Insertamos en la tabla de log si ocurrio algun error al enviar el mail
              IF v_det_error is not null THEN
                  INSERT INTO ge_ra_log_mail
                   (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                  VALUES
                   (SYSDATE, 'MAIL MSJ. SWIFT Cod. Per.: '||t.cod_per_solicitante, v_dir_mail, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
                  COMMIT;
                  v_det_error    := null;
              END IF;
        end if;
     end loop;
  EXCEPTION
    when others then
     raise_application_error(-20000,'PRL_ENV_MAI_MSJ_SWIFT '||sqlerrm);
  END;
end;
/

