create or replace procedure it.PRG_GEN_NOT_SEGUROS ( p_cod_persona varchar2 default null,
                                                  p_nro_cuenta varchar2 default null,
                                                  p_tipo varchar2,
                                                  p_cod_ente varchar2 default null,
                                                  p_fec_vto date default null,
                                                  p_nro_poliza varchar2 default null) is
  /*Debe recibir o cod_persona o Nro_cuenta para buscar los datos
  p_tipo: R -> Rechazo de cobro de seguros
          V -> Vencimiento de Seguros
  p_cod_ente: codigo de ente
  p_fec_vto: Fecha de Vencimiento de Póliza, solo para tipo 'V'
  */

  v_cod_persona varchar2(100);
  v_tip_persona ba_personas.tipo%type;
  v_direccion bw_not_cli_destino.direccion%type;
  v_email ba_personas.dir_correo%type;
  v_ret number;
  v_alta number;
  v_tip_suscripcion number;
  v_cod_modalidad ge_modalidades.cod_modalidad%type;
  v_cod_modulo  ge_modalidades.cod_modulo%type;
  --
  v_not_rechazo varchar2(3000);
  v_not_vencimiento varchar2(3000);
  v_nom_ente varchar2(100);
  v_par_ente varchar2(100);
  --
  v_cod_tip_evento bw_not_eventos.cod_tip_evento%TYPE;
  v_hora varchar2(20);
  v_error varchar2(3000);
  v_lugar varchar2(3000);
  v_env_mail_jur number;
  --
  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
  v_texto_detalle  varchar2(32000);
  v_mje_mail LONG;
  v_asunto   VARCHAR2(2000);
   v_conn     utl_smtp.connection;
  v_nro_cuenta  varchar2(30):=fug_obt_pardinamico('NRO_CTA_VEN_SEGURO');
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;

  v_lugar:=null;
  --Sino se recibe cod_persona o nro cuenta,no se puede evaluar
  if p_cod_persona is null and p_nro_cuenta is null then
      return;
  end if;
  --Obtenemos el código de persona
  if p_cod_persona is not null then
      begin
        select tipo
          into v_tip_persona
          from ba_personas
         where cod_persona = p_cod_persona;
      exception
        when others then
          v_tip_persona := 'J';
      end;
      v_cod_persona:=p_cod_persona;
  elsif p_nro_cuenta is not null then
    --Obtenemos el cod_persona por el Nro de Cuenta
    begin
        select a.cod_persona
          into v_cod_persona
           from ge_cta_clientes a
             where a.nro_cuenta = p_nro_cuenta
             and rownum=1;
      exception
        when others then
          v_cod_persona := null;
      end;
      --Obtenemos el tipo de Persona
      if v_cod_persona is not null then
         begin
          select tipo
            into v_tip_persona
            from ba_personas
           where cod_persona = v_cod_persona;
        exception
          when others then
            v_tip_persona := 'J';
        end;
      end if;

   end if;
  --Obtenemos el tipo de suscripcion de cliente
  --si es persona física
  if v_cod_persona is not null and v_tip_persona ='F' then
    v_tip_suscripcion:=0;
    --Obtenemos el tipo de suscripcion del cliente
    v_tip_suscripcion:= fuw_not_cli_obt_medio(v_cod_persona);
  elsif v_cod_persona is not null and v_tip_persona ='J' then
    v_tip_suscripcion:= 99; --> 99 mail..si es juridica es envio por mail/No entra en Notificaciones
  else
    return;
  end if;
  v_email:=null;
  --Obtenemos el nombre del ente
  if p_cod_ente is not null then
     v_lugar:='Obtener nombre de Ente: '||p_cod_ente;
     begin
      select trim(a.descripcion)
        into v_nom_ente
        from ge_entes a
       where a.cod_ente = p_cod_ente;
    exception
      when others then
        v_nom_ente := 'Ente de Seguros ';
    end;
 end if;
  --Armamos los mensajes de Salida para Personas Juridicas(Solo email)
  if p_tipo='R' then
    v_lugar:='Cargar mensaje de Rechazo';
    --BBVA le informa: Que el cobro de cuota de %s  ,no fue debitado favor verifique a fin de evitar inconveniente.
    v_not_rechazo:='<br><br>
                      '||fug_obt_pardinamico('NOM_BANCO')||' le informa:
                    <br>
                      Que el cobro de cuota de '||v_nom_ente||' ,no fue debitado.
                    <br>
                      Favor verifique a fin de evitar inconveniente.
                    <br><br>
                    <br><br>
                    <br><br>
                    <br><br>';
    --Seteamos los eventos para envio
      if p_nro_cuenta is not null then
         --Obtenemos la Modalidad de la cuenta
         begin
          select a.cod_modulo,a.cod_modalidad
           into v_cod_modulo, v_cod_modalidad
            from ge_cuentas a
             where a.nro_cuenta= p_nro_cuenta
               and rownum=1;
         exception
            when no_data_found then
              v_cod_modulo:=null;
              v_cod_modalidad:=null;
            when others then
              v_cod_modulo:=null;
              v_cod_modalidad:=null;
         end;

      end if;
      v_cod_tip_evento:= 'SEGNOTREC';

  elsif p_tipo='V' then
    v_lugar:='Cargar mensaje de Vencimianto';
    --BBVA le informa: El Vto.de su póliza %s con %s  ,nos comunicaremos con ud.para la renovacion.
    v_not_vencimiento:='<br><br>
                          '||fug_obt_pardinamico('NOM_BANCO')||' le informa:
                        <br>
                          El Vto.de su póliza '||to_char(p_fec_vto,'dd-mm-yyyy')||' con '||v_nom_ente|| ' ,nos comunicaremos con ud.para la renovacion.
                        <br><br>
                        <br><br>
                        <br><br>
                        <br><br>';

    --Tipo de Evento de Vencimiento
     v_cod_tip_evento:= 'SEGNOTVTO';
     v_cod_modulo:=4;
     v_cod_modalidad:=41;
  end if;

  if v_tip_suscripcion=99 and v_tip_persona ='J' then
     --Si es persona juridica se envia mail
          v_lugar:='Enviar email a Juridicas: '||v_cod_persona;
          v_email := substr(fug_obt_dir_mail_per( v_cod_persona ), 1, 80);
          v_env_mail_jur:=0;
          IF v_email IS NOT NULL THEN
              if p_tipo='R' then
                  begin
                    v_asunto:='Rechazo de Cobro de Cuota de Seguro';
                     v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_not_rechazo ||
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




               elsif p_tipo='V' then
                   begin
                     v_asunto:='Vencimiento de Poliza de Seguro';
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
               END IF;

           END IF;
  elsif v_tip_persona ='F' then
     --Enviamos acorde a parametria, sino tiene enviamos sms
      --Obtenemos la direccion de la persona (Si retorna nulo no tiene)
      v_lugar:='Obtener Direccion- PF: '||v_cod_persona;
      v_direccion := substr(paw_not.fu_obt_cli_des_activo(v_cod_persona), 1, 200);
      v_lugar:='Obtener suscripcion- PF: '||v_cod_persona;
      --Sino esta suscripto, le suscribimos para envio de sms.
      --Si retorna N no esta suscripto
      IF paw_not.fu_obt_suscripcion(p_cod_persona) = 'N' OR v_direccion IS NULL THEN
          v_lugar:='Ins.Alta.Notificacion- PF: '||v_cod_persona;
          v_alta := paw_not.fu_alt_notificacion(v_cod_persona, v_direccion);
          if nvl(v_alta,0)>= 0 then
             v_lugar:='Enviar Not.Seg.Nue.- PF: '||v_cod_persona;
             if v_cod_tip_evento= 'SEGNOTVTO' then
                v_par_ente := p_nro_poliza;
             else
                v_par_ente := v_nom_ente;
             end if;
             --Si se dió el alta, enviamos la notificacion
              v_ret := paw_not.fu_not_seguros(nvl(p_nro_cuenta,v_nro_cuenta),
                       v_cod_modulo,
                       v_cod_modalidad,
                       v_cod_persona,
                       v_par_ente,
                       v_cod_tip_evento,
                       nvl(p_fec_vto, pag_cal.FU_OBT_FEC_ACTUAL(1)));
             if v_ret > 0 then
                       --Si hubo errores guardamos en ge_ra_log_mail
                       v_hora:= to_char(sysdate,'hh24:mi:ss');
                       v_error:= v_ret||'- '||substr(to_char(sqlerrm),1,3000);
                       INSERT INTO ge_ra_log_mail
                           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                          VALUES
                           (SYSDATE, p_nro_cuenta||'-Per: '||v_cod_persona||' Tip: '||v_cod_tip_evento, 'ERROR', 'Not. Seguros ', v_error,v_hora , v_hora);

             end if;
         else
            --No se realizó el alta, salimos
            return;
         end if;
      else
          --Tiene parametrizado para informar
          --Enviamos la notificacion
             v_lugar:='Enviar Not.Seg.Ex.- PF: '||v_cod_persona;
             if v_cod_tip_evento= 'SEGNOTVTO' then
                v_par_ente := p_nro_poliza;
             else
                v_par_ente := v_nom_ente;
             end if;
             v_ret := paw_not.fu_not_seguros(nvl(p_nro_cuenta,v_nro_cuenta),
                       v_cod_modulo,
                       v_cod_modalidad,
                       v_cod_persona,
                       v_par_ente,
                       v_cod_tip_evento,
                       nvl(p_fec_vto, pag_cal.FU_OBT_FEC_ACTUAL(1)));
             if v_ret > 0 then
                       --Si hubo errores guardamos en ge_ra_log_mail
                       v_hora:= to_char(sysdate,'hh24:mi:ss');
                       v_error:= substr(to_char(sqlerrm),1,3000);
                       INSERT INTO ge_ra_log_mail
                           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                          VALUES
                           (SYSDATE, p_nro_cuenta||'-Per: '||v_cod_persona||' Tip: '||v_cod_tip_evento, 'ERROR', 'Not. Seguros ', v_error,v_hora , v_hora);

             end if;
      end if;

  END IF;


EXCEPTION
 when others then
     raise_application_error(-20000,'PRG_GEN_NOT_SEGUROS-'||v_lugar||'-'||sqlerrm);
end PRG_GEN_NOT_SEGUROS;
/

