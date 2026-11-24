CREATE OR REPLACE PROCEDURE IT.PRG_ENV_SER_REC_MAIL IS

  v_fec_actual  date default pag_cal.fu_obt_fec_actual(1);

  v_nom_ente        ge_entes.descripcion%type;
  v_cod_per_ente    ge_entes.cod_persona%type;
  v_nom_depositante ge_rec_depositantes.nom_depositante%type;
  v_dir_mail_cre    ge_par_entes.val_parametro%type;--ba_personas.dir_correo%type;
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo;
  v_texto         varchar2(4000);
  v_texto_detalle clob;
  v_resumen       varchar2(4000);

  v_adjunto       clob;
  v_adjunto_error clob;

  v_cabecera      clob;
  v_nom_adj varchar2(500);
  v_total_procesado number ;
  v_total_error number ;

  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  v_db_name  VARCHAR2(20);

  --GAC 12/05/20147 Se agrega membrete de , a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',c_dir_mail);
  --

  CURSOR g_ente is
    select distinct c.cod_ente
      from gv_recaudaciones c
       where c.fec_recaudacion < pag_cal.fu_obt_fec_actual(4) -- informar estados de cheques pend. de confirmaci?n
         and exists (select 1 from ge_log_ser_recaudaciones d
                       where d.cod_ente = c.cod_ente
                         and d.nro_boleta = c.nro_boleta
                         and d.nro_cta_recaudora = c.nro_cta_recaudora
                         and d.cod_moneda = c.cod_moneda
                         and d.tip_deposito = c.tip_deposito
                         and d.est_cheque = 'Pend. de Confirmaci?n') and
              not exists (select 1 from ge_log_ser_recaudaciones e
                       where e.cod_ente = c.cod_ente
                         and e.nro_boleta = c.nro_boleta
                         and e.nro_cta_recaudora = c.nro_cta_recaudora
                         and e.cod_moneda = c.cod_moneda
                         and e.tip_deposito = c.tip_deposito
                         and e.nro_cheque = c.nro_cheque
                         and e.est_cheque in ('Confirmado','Rechazado'))
      union
      select distinct a.cod_ente
        from gv_recaudaciones a
       where a.fec_recaudacion = pag_cal.fu_obt_fec_actual(4)
         and ((a.tip_deposito != 'CHEQUE' -- no volver a enviar lo ya informado si es efectivo
               and
              (not exists (select 1 from ge_log_ser_recaudaciones b
                           where b.fecha = a.fec_recaudacion
                             and b.cod_ente = a.cod_ente
                             and b.nro_boleta = a.nro_boleta
                             and b.fec_recaudacion = a.fec_recaudacion
                             and b.nro_cta_recaudora = a.nro_cta_recaudora
                             and b.cod_moneda = a.cod_moneda
                             and b.tip_deposito = a.tip_deposito)
             )) or -- si son cheques informar solo si a?n no se inform? Confirmado o Rechazado
              (not exists (select 1 from ge_log_ser_recaudaciones b
                           where b.fecha <= a.fec_recaudacion
                             and b.cod_ente = a.cod_ente
                             and b.nro_boleta = a.nro_boleta
                             and b.nro_cta_recaudora = a.nro_cta_recaudora
                             and b.cod_moneda = a.cod_moneda
                             and b.tip_deposito = a.tip_deposito
                             and b.nro_cheque = a.nro_cheque
                             and b.est_cheque in ('Confirmado','Rechazado')) ))
order by 1;

  CURSOR c_detalle(p_cod_ent_detalle ge_entes.cod_ente%TYPE)
   IS
      select * from gv_recaudaciones c
       where c.cod_ente = p_cod_ent_detalle
         and c.fec_recaudacion < pag_cal.fu_obt_fec_actual(4) -- informar estados de cheques pend. de confirmaci?n
         and exists (select 1 from ge_log_ser_recaudaciones d
                       where d.cod_ente = c.cod_ente
                         and d.nro_boleta = c.nro_boleta
                         and d.nro_cta_recaudora = c.nro_cta_recaudora
                         and d.cod_moneda = c.cod_moneda
                         and d.est_cheque = 'Pend. de Confirmaci?n') and
              not exists (select 1 from ge_log_ser_recaudaciones e
                       where e.cod_ente = c.cod_ente
                         and e.nro_boleta = c.nro_boleta
                         and e.nro_cta_recaudora = c.nro_cta_recaudora
                         and e.cod_moneda = c.cod_moneda
                         and e.nro_cheque = c.nro_cheque
                         and e.est_cheque in ('Confirmado','Rechazado'))
      union
      select * from gv_recaudaciones a
       where a.cod_ente = p_cod_ent_detalle
         and a.fec_recaudacion = pag_cal.fu_obt_fec_actual(4)
         and ((a.tip_deposito != 'CHEQUE' -- no volver a enviar lo ya informado si es efectivo
               and
              (not exists (select 1 from ge_log_ser_recaudaciones b
                           where b.fecha = a.fec_recaudacion
                             and b.cod_ente = a.cod_ente
                             and b.nro_boleta = a.nro_boleta
                             and b.fec_recaudacion = a.fec_recaudacion
                             and b.nro_cta_recaudora = a.nro_cta_recaudora
                             and b.cod_moneda = a.cod_moneda
                             and b.tip_deposito = a.tip_deposito)
             )) or -- si son cheques informar solo si a?n no se inform? Confirmado o Rechazado
              (not exists (select 1 from ge_log_ser_recaudaciones b
                           where b.fecha <= a.fec_recaudacion
                             and b.cod_ente = a.cod_ente
                             and b.nro_boleta = a.nro_boleta
                             and b.nro_cta_recaudora = a.nro_cta_recaudora
                             and b.cod_moneda = a.cod_moneda
                             and b.tip_deposito = a.tip_deposito
                             and b.nro_cheque = a.nro_cheque
                             and b.est_cheque in ('Confirmado','Rechazado')) ))
      order by 3,1,5,6,2;

  CURSOR c_resumen(p_cod_ente ge_entes.cod_ente%type) IS
  select x.cod_ente, count(1) can, sum(x.importe) tot_importe, x.cod_moneda, trim(initcap(x.tip_deposito)||' '||x.est_cheque) tip_deposito
    from (  select * from gv_recaudaciones c
       where c.cod_ente = p_cod_ente
         and c.fec_recaudacion < pag_cal.fu_obt_fec_actual(4) -- estados de cheques pend. de confirmaci?n
         and exists (select 1 from ge_log_ser_recaudaciones d
                       where d.cod_ente = c.cod_ente
                         and d.nro_boleta = c.nro_boleta
                         and d.nro_cta_recaudora = c.nro_cta_recaudora
                         and d.cod_moneda = c.cod_moneda
                         and d.est_cheque = 'Pend. de Confirmaci?n') and
              not exists (select 1 from ge_log_ser_recaudaciones e
                       where e.cod_ente = c.cod_ente
                         and e.nro_boleta = c.nro_boleta
                         and e.nro_cta_recaudora = c.nro_cta_recaudora
                         and e.cod_moneda = c.cod_moneda
                         and e.nro_cheque = c.nro_cheque
                         and e.est_cheque in ('Confirmado','Rechazado'))
      union
      select * from gv_recaudaciones a
       where a.cod_ente = p_cod_ente
         and a.fec_recaudacion = pag_cal.fu_obt_fec_actual(4)
         and ((a.tip_deposito != 'CHEQUE' -- no considerar lo ya informado si es efectivo
               and
              (not exists (select 1 from ge_log_ser_recaudaciones b
                           where b.fecha = a.fec_recaudacion
                             and b.cod_ente = a.cod_ente
                             and b.nro_boleta = a.nro_boleta
                             and b.fec_recaudacion = a.fec_recaudacion
                             and b.nro_cta_recaudora = a.nro_cta_recaudora
                             and b.cod_moneda = a.cod_moneda
                             and b.tip_deposito = a.tip_deposito)
             )) or -- si son cheques considerar solo si a?n no se inform? Confirmado o Rechazado
              (not exists (select 1 from ge_log_ser_recaudaciones b
                           where b.fecha <= a.fec_recaudacion
                             and b.cod_ente = a.cod_ente
                             and b.nro_boleta = a.nro_boleta
                             and b.nro_cta_recaudora = a.nro_cta_recaudora
                             and b.cod_moneda = a.cod_moneda
                             and b.tip_deposito = a.tip_deposito
                             and b.nro_cheque = a.nro_cheque
                             and b.est_cheque in ('Confirmado','Rechazado')) ))) x
    group by x.cod_ente, x.cod_moneda, x.tip_deposito, x.est_cheque;

  FUNCTION fu_obt_nom_depositante
    (p_cod_ente ge_rec_depositantes.cod_ente%type,
     p_cod_depositante ge_rec_depositantes.cod_depositante%type)
    RETURN VARCHAR2 IS
    v_nom_depositante ge_rec_depositantes.nom_depositante%type;
  BEGIN
    SELECT a.nom_depositante
      INTO v_nom_depositante
      FROM ge_rec_depositantes a
     WHERE a.cod_ente = p_cod_ente
       AND a.cod_depositante = p_cod_depositante;
    RETURN v_nom_depositante;
  END;

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
    --- OMM Dic/2017 DYDMR-7921 Envio de Correo en Simulaci?n de Cierre.
    SELECT upper(sys_context('USERENV', 'DB_NAME'))
      INTO v_db_name
    FROM dual;

    If nvl(v_db_name,'X') = fug_obt_pardinamico('BD_PROD')  then
      -- Env?o de mail al titular de cta cr?dito.
      for a in g_ente loop
        --GAC 12/05/20147 Se agrega membrete de , a pedido del usuario solicitante
         v_nom_ente        := fue_obt_nom_ente(a.cod_ente);
         v_cod_per_ente    := fue_obt_per_ente(a.cod_ente);

         v_dir_mail_cre    := fug_obt_parentes(a.cod_ente,'DIR_MAIL');
         if v_dir_mail_cre is null then
           v_dir_mail_cre := fug_obt_dir_mail_per(v_cod_per_ente);
         end if;

         v_adjunto       := null;
         v_adjunto_error := null;
         v_total_procesado := 0;
         v_total_error := 0;

            v_cabecera := 'Nro. Boleta' || chr(9)
                      || 'Fecha Recaudaci?n' || chr(9)
                      || 'Nro. Cta. Recaudadora' || chr(9)
                      || 'Moneda' || chr(9)
                      || 'Tipo Dep?sito' || chr(9)
                      || 'Nro. cheque' || chr(9)
                      || 'Banco' || chr(9)
                      || 'Importe' || chr(9)
                      || 'Est. Cheque' || chr(9)
                      || 'Depositante' || chr(9)
                      || 'Tip. Documento' || chr(9)
                      || 'Nro. Documento' || chr(9)
                      || 'Hora' || chr(9)
                      || 'Ref. Pago' || chr(9)
                      || 'Oficina' || chr(9)
                      || chr(10);

           v_resumen := null;
           for k in c_resumen(a.cod_ente) loop
             v_resumen := v_resumen|| 'Total Recaudaciones en '||k.tip_deposito||' '||k.can||
                          ' por '||k.cod_moneda||' '||k.tot_importe||chr(10)||
                          chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9);
           end loop;


           for b in c_detalle(a.cod_ente) loop
               v_adjunto := v_adjunto || b.nro_boleta || chr(9)
                 || to_char(b.fec_recaudacion, 'DD/MM/YYYY') || chr(9)
                 || b.nro_cta_recaudora || chr(9)
                 || b.cod_moneda || chr(9)
                 || b.tip_deposito || chr(9)
                 || b.nro_cheque || chr(9)
                 || b.banco || chr(9)
                 || b.importe || chr(9)
                 || b.est_cheque || chr(9)
                 || b.depositante || chr(9)
                 || b.tip_documento || chr(9)
                 || b.nro_documento || chr(9)
                 || b.hora || chr(9)
                 || b.ref_pago || chr(9)
                 || b.oficina || chr(9)
                 || chr(10);

                 -- Se guarda la informaci?n enviada al Cliente.
                 BEGIN
                   INSERT INTO ge_log_ser_recaudaciones
                   (fecha, cod_ente, nro_boleta, fec_recaudacion,
                    nro_cta_recaudora, cod_moneda, tip_deposito, nro_cheque,
                    banco, importe, est_cheque)
                   VALUES
                   (pag_cal.fu_obt_fec_actual(4), b.cod_ente, b.nro_boleta, b.fec_recaudacion,
                    b.nro_cta_recaudora, b.cod_moneda, b.tip_deposito, b.nro_cheque,
                    b.banco, b.importe, b.est_cheque);
                 EXCEPTION
                   WHEN OTHERS THEN
                     raise_application_error(-20000,'Error '||sqlerrm);
                 END;
          end loop;

              v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                 v_cabecera || chr(10) || v_adjunto || chr(10)||
                                 chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||
                                 v_resumen;
  --                               'Total Dep?sitos :'||chr(9)||v_total_procesado||chr(10);



          v_texto := '<br><br>
                 <br><br>
                   Estimado Cliente: '|| v_nom_ente ||'
                 <br><br>
                   Le informamos que se registraron Operaciones de Dep?sitos en su cuenta en Concepto de Servicio de Recaudaci?n en Ventanilla; correspondiente a la fecha ' ||
                           to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se realizaron las operaciones detalladas en el archivo adjunto.
                 <br><br>
                   Atentamente.
                 <br><br>
                 <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                 <br><br>
                 <br><br>';

            --GAC 12/05/20147 Se agrega membrete de , a pedido del usuario solicitante|
            v_nom_adj := nvl(fug_obt_pardinamico('NOM_ARC_SER_REC_VEN'), 'SER_REC_VEN') || a.cod_ente || '_' ||
                         to_char(v_fec_actual, 'DDMMYY')||'-'||to_char(sysdate,'hh24_mi');

            v_asunto   := 'Servicio de Recaudaci?n en Ventanilla';
            v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                          chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;


                Begin

                  v_conn     := it_mail.begin_mail(c_dir_mail,
                                                   v_dir_mail_cre,
                                                   v_asunto,
                                                   IT_MAIL.MULTIPART_MIME_TYPE);

                  it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                  it_mail.begin_attachment(v_conn,
                                           'text/plain',
                                           false,
                                           v_nom_adj ||'.xls');

                  v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                     'SERVICIO DE RECAUDACION EN VENTANILLA' || CHR(10) ||
                                     v_texto_detalle;


                  it_mail.write_text(v_conn, v_texto_detalle);


                  it_mail.end_mail(v_conn);

                  insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                  values (c_dir_mail, v_dir_mail_cre, v_asunto, v_texto, sysdate, user);


               EXCEPTION
                   when others then
                         insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                        values (c_dir_mail, v_dir_mail_cre, v_asunto, v_texto_detalle, sysdate, user);
                end;


      end loop;
    End if ;
  EXCEPTION
    when others then
     raise_application_error(-20000,'PRG_ENV_SER_REC_MAIL '||sqlerrm);
  END;
end;
/

