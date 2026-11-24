create or replace function it.fug_gen_template( p_tipo   in varchar2,
                                             p_mail   in varchar2 default null 
                                             ) return long is
/* 
@p_tipo: Tipo de template a generar. Valores permitidos: M = Membrete, F = Fin, P = Pie.
@p_mail: Direccion de mail a mostrar en el Pie.
*/
  v_result   long;
  v_mail     ba_mails.dir_correo%type;
begin
  if upper(p_tipo) not in('M','F','P') then
    Raise_application_error(-20000, 'El tipo solo puede ser M=Membrete, F=Fin o P=Pie');
  end if;
  
  v_mail := nvl(p_mail,fug_obt_dir_correo);
  
  if  upper(p_tipo) = 'M' then
    v_result := '<html>
   <head>
   <meta charset="UTF-8">
   <meta name="viewport" content="width=device-width, initial-scale=1.0">
   <meta http-equiv="X-UA-Compatible" content="IE=edge">
   <title>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</title>
   </head>
   <body width="100%" height="100%" bgcolor="#e0e0e0" style="margin: 0;" yahoo="yahoo">
      <table cellpadding="0" cellspacing="0" border="0" height="100%" width="100%" bgcolor="#e0e0e0" style="border-collapse:collapse;">
     <tr>
       <td><div align="center" style="width: 100%;">
         <div style="max-width: 680px;"> 
             <!-- Email Header : BEGIN -->
         <table cellspacing="0" cellpadding="0" border="0" align="center" bgcolor="#7AB83F" width="100%" style="max-width: 680px;">
         <tr>
             <td style="padding: 20px 0; text-align: center; background-color:#7AB83F"><img src="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'NW_BBVA_WHITE')||'" width="250" alt=""/></td>
           </tr>
         </table>
           <!-- Email Header : END --> 
           
           <table cellspacing="0" cellpadding="0" border="0" align="center" width="100%" style="max-width:680px; min-width:600px; padding: 0px 30px; background-color:#ffffff;">
           <tr><td width="1"></td></tr>
           <tr style="background-color: #FFFFFF; padding: 0px 50px;" >';
  end if;
  
  
  if  upper(p_tipo) = 'F' then                   
    v_result :=  
      '</tr> 
      </table>
      <table cellpadding="0" cellspacing="0" border="0" height="100%" align="center" width="100%" bgcolor="#e0e0e0" style="border-collapse:collapse; max-width: 680px;">
        <tr>
          <td style="background-color: #AFD48B; padding: 10px">
            <table cellspacing="0" cellpadding="0" border="0" width="100%">
              <tr>
                <td style="padding: 4px 10px; font-family: sans-serif; font-size: 12px; text-align: center; mso-height-rule: exactly; line-height: 15px; color: #fff;">
                Seguinos en
                </td>
              </tr>
            </table>

            <table cellspacing="0" cellpadding="0" border="0" width="15%" style="font-family: sans-serif; font-size: 13px; text-align: center; color:#fff" align="center">
              <tr>
                <td style="mso-height-rule: exactly"><span><a href="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'LINK_FACEBOOK')||'"><img style="margin:5px 10px;" src="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'NW_FACEBOOCK')||'" width="24" height="24" alt=""/></a></span></td>
                <td style="mso-height-rule: exactly"><span><a href="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'LINK_TWITTER')||'"><img style="margin:5px 20px;" src="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'NW_TWITTER')||'" width="24" height="24" alt=""/></a></span></td>
                <td style="mso-height-rule: exactly"><span><a href="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'LINK_INSTAGRAM')||'"><img style="margin:5px 10px;" src="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'NW_INSTAGRAM')||'" width="24" height="24" alt=""/></a></span></td>
              </tr>
            </table>
          </td>  
        </tr>
      </table>';
  end if;
  
  if  upper(p_tipo) = 'P' then
    v_result := '<!-- Email Footer : BEGIN -->
                    <table cellspacing="0" cellpadding="0" border="0" align="center" width="100%" style="max-width: 680px; background-color: #7AB83F">
                      <tr>
                        <td style="padding: 13px 10px; font-size: 12px; font-family: sans-serif; mso-height-rule: exactly; line-height:25px; text-align: center; color: #FFFFFF;">
                          <table cellspacing="0" cellpadding="0" border="0" width="45%" style="font-family:sans-serif;font-size:12px;text-align:center;color:#fff" align="center">
                          <tr>
                          <td>	
                            <img style="float:left;margin-top:4px;margin-left:20px;" src="' || fue_obt_val_max_refcodes('DIR_MAI_LINK', 'PHONE_ICON') || '" width="20" height="20" alt=""/>
                            <span style="float:left;margin:2px 5px;font-size:12px;">021 417 6000</span>
                          </td>
                          <td>                          
                            <img style="float:left;margin-left:10px;margin-top:4px" src="' || fue_obt_val_max_refcodes('DIR_MAI_LINK', 'NW_WHATSAPP') ||'" width="20" height="20" alt=""/>
                            <a style="float:left;margin:2px 5px;font-size:12px;color:#ffffff" href="'|| fue_obt_val_max_refcodes('DIR_MAI_LINK', 'LINK_WHATSAPP') ||'">WhatsApp</a>
                          </td>
                          </tr>
                          </table>
                          <table cellspacing="0" cellpadding="0" border="0" width="100%" style="font-family:sans-serif;font-size:12px;text-align:center;color:#fff" align="center">
                          <tr>
                          <td>	                            
                            <a href="'||fug_obt_pardinamico('URL_BANCO')||'" style="margin-top:15px;font-size:12px;color: #FFFFFF">'||fug_obt_pardinamico('URL_BANCO')||'</a>
                          </td>
                          </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                    <!-- Email Footer : END --> 
                    <table cellspacing="0" cellpadding="0" border="0" align="center" width="100%" style="max-width: 680px; background-color: #F4F4F4">
                      <tr>
                         <td style="padding-top: 5px; mso-height-rule: exactly; text-align: center">
                         <img src="'||fue_obt_val_max_refcodes('DIR_MAI_LINK', 'NW_BBVA_BLUE')||'" width="250" alt=""/></td>
                       </tr>
                      <tr>
                        <td style="padding: 0px 10px 15px 10px; font-size: 11px; font-weight: 400; font-family: sans-serif; mso-height-rule: exactly; line-height:13px; text-align: center; color: #666666;">'
                        || to_char(sysdate, 'yyyy')
                        || ' '
                        || fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')
                        || ' '
                        || pag_htm.FU_CON_HTML('Avda. Mariscal López esquina Torreani Viera, Asunción, Paraguay')
                        || '
                        </td>
                      </tr>
                    </table>
                    <table cellspacing="0" cellpadding="0" border="0" align="center" width="100%" style="max-width: 680px; background-color: #fff">
                     <tr>
                        <td style="padding: 32px; font-size: 10px; font-family: sans-serif; mso-height-rule: exactly; line-height:14px; text-align: left; color: #666666;">
                          Vale informar, que la '|| pag_htm.FU_CON_HTML('dirección') ||' de correo '||v_mail||' es 
                          aplicable exclusivamente a la '|| pag_htm.FU_CON_HTML('remisión automática') ||' de las 
                          notificaciones del servicio, por lo tanto rogamos se abstenga a responder y/o dirigir
                          consultas adicionales con destino a la misma. Recuerde, que por '|| pag_htm.FU_CON_HTML('política') ||' 
                          de seguridad, el '||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||' NO le ' || pag_htm.FU_CON_HTML('solicitará') || ' responder por correo '|| pag_htm.FU_CON_HTML('electrónico') ||' 
                          ninguna consulta y/o pedido de '|| pag_htm.FU_CON_HTML('información') ||' respecto a sus claves y/o 
                          sobre '|| pag_htm.FU_CON_HTML('actualización') ||' de sus datos personales .
                        </td>
                     </tr>
                    </table>
              </div>
             </div></td>
            </tr>
           </table>
          </body>
         </html>';
  end if;
 
  return(v_result);

exception
  when others then
    Raise_application_error(-20000, 'Error en la funcion FUG_GEN_TEMPLATE. '||sqlerrm);
end fug_gen_template;
/

