create or replace procedure it.prg_env_sms(p_cod_persona  in BA_ENV_SMS.cel_destinatario%type,
                                        p_cod_modalidad  in varchar2,
                                        p_cod_error     out number,
                                        p_men_error     out varchar2)
                         is

    v_url        varchar2(4000) := fug_obt_pardinamico('WS_URL_ENV_SMS'); --url Web Service para envío de SMS;
    v_content    varchar2(4000);
    v_men_error  varchar2(4000);
    v_cod_err_ws number(6);
    v_error exception;
    v_movement        varchar2(5);
    v_text_sms      ba_env_sms.texto_sms%type;
    v_nro_sms it.ba_env_sms.nro_sms%TYPE := NULL;
    v_cel_dest it.ba_env_sms.cel_destinatario%TYPE := NULL;
    v_texto_sms VARCHAR2(4000):= fug_obt_pardinamico('GEN_ENV_SMS_PRE_APR');
    v_pro_correcto        number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                      0);
    v_pro_cor_pen         number := nvl(fug_obt_pardinamico('COD_MEN_PRO_PEN'),
                                      1);
    v_err_sql             number := nvl(fug_obt_pardinamico('COD_ERR_SQL'),
                                      999);
    v_cod_msg_exito       number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'),
                                      200);
  begin
   --Se recupera siguiente nro.
   select nvl(max(nro_sms),0)+1 into v_nro_sms from it.ba_env_sms;
   BEGIN
   --SE recupera el nro de teléfono del cliente
   select k.area||k.telefono
    into v_cel_dest
    from ba_telefonos k
   where k.cod_persona = p_cod_persona
     and k.principal = 'S'
     and k.tip_linea = 'C';
    EXCEPTION
         WHEN OTHERS then
            null;
    END;
    -- se crea la estructura json para pasar al ws
    v_content := '{"phoneNumber": "' || v_cel_dest || '",
                     "message": "' || v_texto_sms || '"}';

    pat_tgl.pr_ws_conector(v_content,
                           v_url,
                           null,
                           null,
                           'M',
                           'POST',
                           v_cod_err_ws,
                           v_men_error); -- llama al web service

    if v_cod_err_ws != v_cod_msg_exito then
      --Error
      p_cod_error := v_cod_err_ws;
      p_men_error := v_men_error;
      BEGIN
      insert into it.ba_env_sms t
             (nro_sms,cod_persona,tip_producto,estado,fec_registro,fec_envio,msj_error,texto_sms,cel_destinatario)
            values
             (v_nro_sms,p_cod_persona,p_cod_modalidad,'P',sysdate,null,p_cod_error||' '||p_men_error,v_texto_sms,v_cel_dest);
      EXCEPTION
         WHEN OTHERS then
            raise_application_error(-20006, 'Error al insertar en la tabla ba_env_sms ' || SQLERRM);
      END;
      prg_ins_log_programas('PRG_ENV_SMS',
                            substr('Lugar: ' || NULL || ' - ' || v_cod_err_ws||' '||v_men_error,
                                   1,
                                   4000),
                            null,
                            null);
    else
      --Exito en envío de SMS
      p_cod_error := v_cod_msg_exito;
      p_men_error := nvl(fug_obt_pardinamico('DES_MSG_EXITO'),
                         'Transaccion Exitosa!');
      BEGIN
      insert into it.ba_env_sms t
             (nro_sms,cod_persona,tip_producto,estado,fec_registro,fec_envio,msj_error,texto_sms,cel_destinatario)
            values
             (v_nro_sms,p_cod_persona,p_cod_modalidad,'S',sysdate,sysdate,p_cod_error||' '||p_men_error,v_texto_sms,v_cel_dest);

      EXCEPTION
         WHEN OTHERS then
            raise_application_error(-20006, 'Error al insertar en la tabla ba_env_sms ' || SQLERRM);
      END;
    end if;

  exception
    when others then
      p_cod_error := v_err_sql;
      p_men_error := 'Error en proceso PRG_ENV_SMS ' ||
                     substr('Lugar: ' || NULL || ' - ' || sqlerrm,
                            1,
                            4000);
      prg_ins_log_programas('PRG_ENV_SMS',
                            substr('Lugar: ' || NULL || ' - ' || sqlerrm,
                                   1,
                                   4000),
                            null,
                            null);
  end;
/

