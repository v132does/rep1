CREATE OR REPLACE TRIGGER IT.TA_GE_PROCESOS_AUT
  after UPDATE on ge_procesos_aut
  for each row
declare
  -- local variables here
  V_DIR_CORREO_DE    VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  V_DIR_CORREO_PARA  VARCHAR2(300) := fug_obt_pardinamico('CAM_MAR_DIR_EP');--'ep.py@bbva.com'; 
  V_DIR_CORREO_CC    VARCHAR2(300) := fug_obt_pardinamico('CAM_MAR_DIR_SOP');--'soporte.incidencias.dyd.py.group@bbva.com';
  v_membrete LONG := fug_gen_template('M')|| chr(10); 
  V_FIN      LONG := ' </tbody>
                         </table> <BR> Favor gestionar las incidencias <BR><BR>
                          <table width="600" border="0" cellpadding="0" cellspacing="0">
                         <tbody> '||chr(10)||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P',V_DIR_CORREO_DE);
  --
  V_DETALLE  LONG := '';
  V_CABECERA LONG := '<html>
                  <body>
                  <BR>
                         Buenos días, Favor verificar la tabla GE_PROCESOS_AUT, el siguiente proceso automático ha fallado:
                  <br><br>
                  </p>
                  <table  width: 40%;
                          cellspacing="0"
                          cellpadding="5"
                          border="4">
                  <tr>
                    <td width="10%" bgcolor="B0C4DE"> <b>COD. PROCESO</b></td>
                    <td width="10%" bgcolor="B0C4DE"> <b>NOMBRE DEL PROCESO PROCESO</b></td>
                    <td width="10%" bgcolor="B0C4DE"> <b>ULTIMA EJECUCION</b></td>
                  </tr>';
  
begin
  IF updating then
    if :new.est_ult_eje = 'F' then
         v_DETALLE := V_DETALLE || '<tr>
                                    <td bgcolor="FFFFFF">'||:old.COD_PROCESO||'</td>
                                    <td bgcolor="FFFFFF">'||:old.DESCRIPCION || '</td>
                                    <td bgcolor="FFFFFF">'||:old.ULT_EJECUCION || '</td>
                                  </tr> ';
                                  
         PRG_SEND_MAIL(p_to        => V_DIR_CORREO_PARA,
                       p_from      => V_DIR_CORREO_DE,
                       p_subject   => 'ERROR EN PROCESOS AUTOMATICOS',
                       p_text_msg  => '',
                       p_html_msg  => v_membrete|| V_CABECERA || V_DETALLE || v_fin || v_pie ,
                       p_smtp_host => fug_obt_pardinamico('DIR_SER_CORREOS'),
                       p_smtp_port => 25,
                       pcc         => V_DIR_CORREO_CC);               
    end if;
  END IF;
end TA_GE_PROCESOS_AUT;
/

