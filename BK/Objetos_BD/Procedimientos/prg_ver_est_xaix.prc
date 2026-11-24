create or replace procedure it.prg_ver_est_xaix is
 -- url      sphttp.SPI_URL_TYP;
  v_result varchar2(256);
  v_url    varchar2(100) := fug_obt_pardinamico('SPI_URL');
  --v_url        varchar2(100) := '192.165.33.77';
  v_port       varchar2(10) := fug_obt_pardinamico('SPI_PORT');
  v_type       varchar2(10) := fug_obt_pardinamico('SPI_TYPE');
  v_cantidad   number(1) := 0;
  v_sid_base   varchar2(30);
  v_dir_correo ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SPI_MAIL_ALERTA');
  v_sender     ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');
  v_subject    varchar2(300);
  v_message    varchar2(1000);
  v_fec_hora   date;
  v_cant_per   number(10) := fug_obt_pardinamico('XAIX_CAN_CONS');
  v_res_sms    number(10);
begin
  --url := SPHTTP.SPI_URL_TYP(v_url, v_port, v_type);

  --resultado de la consulta de estado
  while nvl(v_result, 'X') <> 'UP' and v_cantidad < 2 loop
    begin
      v_fec_hora := sysdate;
    --  v_result   := sphttp.xaix.do_xaix_status(url);
    exception
      when others then
        v_result := null;
    end;
    v_cantidad := v_cantidad + 1;
  end loop;

  --base de datos
  select g.global_name into v_sid_base from global_name g;

  v_message := 'Estado del XAIX: ' || v_result || CHR(13) ||
               'Hora de consulta: ' ||
               to_char(v_fec_hora, 'YYYY-MM-DD HH24:MI:SS');

  --de acuerdo a la respuesta            
  if NVL(v_result, 'X') <> 'UP' then
    --Leticia Valdez
    v_res_sms := paw_not.fu_env_sms_prueba('0981441475',
                                           'XAIX sin respuesta ' || v_result,
                                           'XAIX');
    --Joel Samudio
    v_res_sms := paw_not.fu_env_sms_prueba('0982135682',
                                           'XAIX sin respuesta ' || v_result,
                                           'XAIX');
    --Arnaldo Portillo 
    v_res_sms := paw_not.fu_env_sms_prueba('0981711695',
                                           'XAIX sin respuesta ' || v_result,
                                           'XAIX');
  
    --Israel Infran 
    v_res_sms := paw_not.fu_env_sms_prueba('0984329435',
                                           'XAIX sin respuesta ' || v_result,
                                           'XAIX');
  
    v_subject := '<ALERTA XAIX SIN RESPUESTA> BD: ' || v_sid_base;
    v_message := v_message || CHR(13) ||
                 'No se recibió respuesta del XAIX, Favor verificar urgente. - ' ||
                 v_res_sms;
    it_mail.mail(sender     => v_sender,
                 recipients => v_dir_correo,
                 subject    => v_subject,
                 message    => v_message);
  
  else
    v_subject  := '<XAIX ESTA ARRIBA> BD: ' || v_sid_base;
    v_cant_per := v_cant_per + 1;
  
    begin
      BEGIN
        PRE_INI_APLICACION;
        PAE_CNF.G_COD_MODULO := 1;
      end;
      update ge_par_dinamicos a
         set a.val_parametro = v_cant_per
       where a.parametro = 'XAIX_CAN_CONS';
    exception
      when others then
        null;
    end;
  
    if v_cant_per < 5 then
      v_res_sms := paw_not.fu_env_sms_prueba('0981441475',
                                             'XAIX ARRIBA ',
                                             'XAIX');
      --Israel Infran 
      v_res_sms := paw_not.fu_env_sms_prueba('0984329435',
                                             'XAIX ARRIBA ',
                                             'XAIX');
      it_mail.mail(sender     => v_sender,
                   recipients => v_dir_correo,
                   subject    => v_subject,
                   message    => v_message || CHR(13) || v_res_sms);
    
    end if;
  end if;
  commit;
end prg_ver_est_xaix;
/

