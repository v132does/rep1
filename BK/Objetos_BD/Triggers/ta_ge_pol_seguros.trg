CREATE OR REPLACE TRIGGER IT.TA_GE_POL_SEGUROS
  after insert or update on ge_pol_seguros
  for each row
declare
  --- local variables here
  v_mime_type VARCHAR2(10) := 'text/html';
begin
  if inserting then
      if fug_obt_pardinamico('POL_ENV_MAIL') = 'S' then
         begin
         PRG_ENV_MAI_HTML(fug_obt_dir_correo,
                      fug_obt_dir_mail_per(:new.cod_persona),
                      'Seguro Contratado',

                      '<html><body>' ||
                      '<h3 style="color:#074CA9; font-family: Helvetica Neue, Helvetica, Arial, sans-serif; margin-top:0px">SEGURO CONTRATADO</h3>' ||
                      '<p style="font-family: Helvetica Neue, Helvetica, Arial, sans-serif; font-size:14px">' ||
                          
                      'Estimado Cliente: <b>' || fue_obt_nom_persona(:new.cod_persona) || '</b> <br><br>' ||

                      'Le informamos que su p&oacute;liza de seguro de <b>' || :new.sub_seccion || '</b> <br>' ||
                      'de la Empresa <b>' || fue_obt_nom_ente(:new.cod_ente) || '</b> contratado en el '|| fug_obt_pardinamico('NOM_BANCO')||', <br>' || 
                      'se encuentra en proceso de emisi&oacute;n para su entrega en la brevedad. <br><br>' ||

                      'Le recomendamos la lectura de la Gu&iacute;a del Asegurado y de su P&oacute;liza para su informaci&oacute;n, <br>' ||
                      'ingresando al link <a href="'|| fug_obt_pardinamico('URL_BANCO')||'/public/seguros.jsp">Gu&iacute;a del Asegurado</a> <br><br>' ||

                      'Para su tranquilidad registre el n&uacute;mero de asistencia del seguro <b>' ||
                      fug_obt_parentes(:new.cod_ente,'NRO_TEL_ASISTENCIA') || '</b> <br><br>' ||
                      'Para consulta estamos a su disposici&oacute;n. <br><br>' ||

                      fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA') ||' Corredor de Seguros. <br>' ||
                      'Call Center 417 6000' ||

                      '<br></p>' ||
                      '</body></html>',

                      v_mime_type
                      );
          exception
            when others then
                 null;          
          end;                      
      end if;
  elsif updating then -- 17/06/2016 – EVO : DE-2212
      if fug_obt_pardinamico('POL_ENV_MAIL') = 'S' then
        if ((:new.nro_poliza is not null) and  (nvl(:new.nro_poliza,'X') <> nvl(:old.nro_poliza,'X')))  then
              begin
               PRG_ENV_MAI_HTML(fug_obt_dir_correo,
                            fug_obt_dir_mail_per(:old.cod_persona),
                            'Seguro Contratado',

                            '<html><body>' ||
                            '<h3 style="color:#074CA9; font-family: Helvetica Neue, Helvetica, Arial, sans-serif; margin-top:0px">SEGURO CONTRATADO</h3>' ||
                            '<p style="font-family: Helvetica Neue, Helvetica, Arial, sans-serif; font-size:14px">' ||
                          
                            'Estimado Cliente: <b>' || fue_obt_nom_persona(:old.cod_persona) || '</b> <br><br>' ||

                            'Le informamos que el n&uacute;mero de su p&oacute;liza de seguro de <b>' || :old.sub_seccion || '</b> <br>' ||
                            'de la Empresa <b>' || fue_obt_nom_ente(:old.cod_ente) || '</b> contratado en el '|| fug_obt_pardinamico('NOM_BANCO')||', <br>' ||
                            'es el <b>' || :new.nro_poliza || '</b> <br><br>' ||
                            
                            'Le recomendamos la lectura de la Gu&iacute;a del Asegurado y de su P&oacute;liza para su informaci&oacute;n, <br>' ||
                            'ingresando al link <a href="'|| fug_obt_pardinamico('URL_BANCO')||'/public/seguros.jsp">Gu&iacute;a del Asegurado</a> <br><br>' ||
                            
                            'Para su tranquilidad registre el n&uacute;mero de asistencia del seguro <b>' ||
                            fug_obt_parentes(:old.cod_ente,'NRO_TEL_ASISTENCIA') || '</b> <br><br>' ||
                            'Para consulta estamos a su disposici&oacute;n las 24 horas del d&iacute;a todo el a&ntilde;o. <br><br>' ||

                            fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')|| ' Corredor de Seguros. <br>' ||
                            'Call Center 417 6000' ||

                            '<br></p>' ||
                            '</body></html>',

                            v_mime_type
                            );
                exception
                  when others then
                       null;          
                end;                     
          end if;      
      end if;
  end if;
end TA_GE_POL_SEGUROS;
/

