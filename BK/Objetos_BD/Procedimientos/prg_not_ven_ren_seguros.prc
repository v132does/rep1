CREATE OR REPLACE PROCEDURE IT.PRG_NOT_VEN_REN_SEGUROS is
  v_email varchar2(100);
  v_ret         NUMBER(4) := 0;
  v_cod_destino NUMBER;
  v_fec_actual  ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_fec_inicio date := TRUNC(v_fec_actual, 'MM');
  v_fec_fin date := TRUNC(LAST_DAY(v_fec_actual));
  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  ---c_dir_mail        ba_personas.dir_correo%type  := 'infobbva@bbva.com';
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');
  v_not_vencimiento varchar2(32000);
  v_texto_detalle  varchar2(32000);
  v_mje_mail LONG;
  v_asunto   VARCHAR2(2000);
  v_conn     utl_smtp.connection;
  --Tipo de Evento de Vencimiento
  v_cod_tip_evento  bw_not_eventos.cod_tip_evento%type := 'SEGNOTVTO';
  v_cod_modulo ba_modulos.cod_modulo%type := 1;
  v_cod_modalidad ge_modalidades.cod_modalidad%type := 2;
  v_nro_cta_not_seg ge_cuentas.nro_cuenta%type := fug_obt_pardinamico('NRO_CTA_VEN_SEGURO');
  v_nom_ente varchar2(100);
  CURSOR c_seguros IS
  SELECT s.cod_persona cod_persona, s.nro_poliza, s.cod_tip_seguro, s.cod_ente, s.mto_capital,
         s.mto_cuota, s.cod_moneda, s.nro_seg_ant, s.fec_ven_pol_ant
    FROM ge_ren_pol_seguros s
   WHERE s.fecha BETWEEN v_fec_inicio AND v_fec_fin
     AND s.estado = 'I';

  FUNCTION FU_OBT_MEN_MAIL (p_cod_tip_seguro ge_ren_pol_seguros.cod_tip_seguro%type) return varchar2  is
     v_not_vencimiento varchar2(32000);
  begin
    IF p_cod_tip_seguro IN('P', 'V', 'H') THEN
  
	  v_not_vencimiento:=fug_obt_pardinamico('SEG_MSJ_REN_EMAIL');

     ELSE
       v_not_vencimiento:='<br><br>
                            Estimado Cliente
                            <br><br>
                            Tu p&oacute;liza de Seguros est&aacute; por vencer y queremos seguir respald&aacute;ndote en cada paso que das con la mejor cobertura que merec&eacute;s.
                            <br><br>
                            Nos pondremos en contacto en la brevedad o si prefer&iacute;s cont&aacute;ctanos al Call Center 4176000 o a trav&eacute;s de tu gestor comercial.
                            <br><br>
                            Gracias por elegirnos.
                            <br><br>
                            <p><small>El banco se encuentra inscripto como Corredor de Seguros seg&uacute;n matricula No. 050, autorizado por Resoluci&oacute;n SS.SG. No.078/11 de la Superintendencia de Seguros del Banco Central del Paraguay. Las P&oacute;lizas de Seguros aqu&iacute; ofrecidas son emitidas por Mapfre Paraguay Cia. de Seguros S.A., Aseguradora Yacyreta S.A, La Consolidada S.A. de Seguros, Aseguradora del Este S.A. de Seguros y Sancor Seguros, conforme al plan.</small></p>
                            <br><br>';
     END IF;
     return v_not_vencimiento;
  end;

BEGIN
  FOR c in c_seguros LOOP
    BEGIN
       DBMS_OUTPUT.put_line(c.cod_persona);
       
       --Obtenemos el nombre del ente
        if c.cod_ente is not null then
                   begin
                    select trim(a.descripcion)
                      into v_nom_ente
                      from ge_entes a
                     where a.cod_ente = c.cod_ente;
                  exception
                    when others then
                      v_nom_ente := 'Ente de Seguros ';
                  end;
       end if;
               
       IF PAW_NOT.fu_obt_suscripcion(c.cod_persona) = 'N' THEN
         BEGIN
           v_email := FUG_OBT_DIR_MAIL_PER(c.cod_persona);
           --BBVA le informa: El Vto.de su póliza %s con %s  ,nos comunicaremos con ud.para la renovacion.
           if v_email is not null then
             BEGIN
               
               v_asunto:='Vencimiento de Poliza de Seguro';
               v_not_vencimiento := FU_OBT_MEN_MAIL(c.cod_tip_seguro);
               v_not_vencimiento:=REPLACE(v_not_vencimiento,'#DESCRIPCION_ENTE',v_nom_ente);
               v_not_vencimiento:=REPLACE(v_not_vencimiento,'#NRO_SEGURO',c.nro_poliza);
               v_not_vencimiento:=REPLACE(v_not_vencimiento,'#FECHA_VENCIMIENTO',to_char(c.fec_ven_pol_ant,'dd/mm/yyyy'));
               v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_not_vencimiento ||
                             chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
               v_conn     := it_mail.begin_mail(c_dir_mail,
                                                v_email,
                                                V_ASUNTO,
                                                IT_MAIL.MULTIPART_MIME_TYPE);


               it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
               it_mail.write_text(v_conn, v_texto_detalle);
               it_mail.end_mail(v_conn);
             EXCEPTION
               when others then
                  v_mje_mail := substr(v_mje_mail || '- ERROR [' || SQLERRM || ']', 1, 4000);
                  insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                  values (c_dir_mail, v_email, v_asunto, v_mje_mail, sysdate, user)  ;
             end;
           else
             begin
               insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                  values (c_dir_mail, null, v_asunto, 'Cliente '||c.cod_persona||' no tiene configurado email.', sysdate, user)  ;
             end;
           end if;
         END;
       ELSE
         BEGIN
           --se envia directo cuando ya tiene suscripcion
           BEGIN
             SELECT d.cod_destino
               INTO v_cod_destino
               FROM bw_not_cli_destino d
              WHERE d.cod_persona = c.cod_persona
                AND d.activo = 'S'
                AND ROWNUM=1;
           EXCEPTION
             WHEN OTHERS THEN
               v_cod_destino := 2;
           END;

           IF v_cod_destino = 3 THEN
              v_ret := paw_not.fu_not_seguros(v_nro_cta_not_seg,
                                              v_cod_modulo,
                                              v_cod_modalidad,
                                              c.cod_persona,
                                              c.nro_poliza,
                                              v_cod_tip_evento,
                                              nvl(c.fec_ven_pol_ant, pag_cal.FU_OBT_FEC_ACTUAL(1)));
           ELSE
             v_email := FUG_OBT_DIR_MAIL_PER(c.cod_persona);
             if v_email is not null then
                BEGIN
                   v_asunto:='Vencimiento de Poliza de Seguro';
                   v_not_vencimiento := FU_OBT_MEN_MAIL(c.cod_tip_seguro);
                   v_not_vencimiento:=REPLACE(v_not_vencimiento,'#DESCRIPCION_ENTE',v_nom_ente);
                   v_not_vencimiento:=REPLACE(v_not_vencimiento,'#NRO_SEGURO',c.nro_poliza);
                   v_not_vencimiento:=REPLACE(v_not_vencimiento,'#FECHA_VENCIMIENTO',to_char(c.fec_ven_pol_ant,'dd/mm/yyyy'));
                   v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_not_vencimiento ||
                                 chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
                   v_conn     := it_mail.begin_mail(c_dir_mail,
                                                    v_email,
                                                    V_ASUNTO,
                                                    IT_MAIL.MULTIPART_MIME_TYPE);


                   it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
                   it_mail.write_text(v_conn, v_texto_detalle);
                   it_mail.end_mail(v_conn);
                 EXCEPTION
                   when others then
                      v_mje_mail := substr(v_mje_mail || '- ERROR [' || SQLERRM || ']', 1, 4000);
                      insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                      values (c_dir_mail, v_email, v_asunto, v_mje_mail, sysdate, user)  ;
                 end;
               else
                 begin
                   insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                   values (c_dir_mail, null, v_asunto, 'Cliente '||c.cod_persona||' no tiene configurado email.', sysdate, user)  ;
               end;
             end if;
           END IF;
         END;
       END IF;
     EXCEPTION
       WHEN no_data_found THEN
         IT.PRG_INS_LOG_ERRORES('PRG_NOT_VEN_REN_SEGUROS',
                                                  sqlerrm,
                                                  null,
                                                  null,
                                                  null,
                                                  null,
                                                  null,
                                                  null);
     END;
  END LOOP;
END;
/

