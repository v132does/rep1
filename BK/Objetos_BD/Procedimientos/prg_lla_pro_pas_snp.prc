create or replace procedure it.PRG_LLA_PRO_PAS_SNP --PROCEDIMIENTO QUE LLAMA AL PAS_SNP.PR_OBT_MSJ_MT102_AUT
 IS
v_hora_fin ge_procesos.hor_fin%type := null ;
v_hab_ejecucion varchar2(1) := fug_obt_pardinamico('SNP_102_AUTOMATICO') ;
v_dir_correo ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('SNP_102_DIR_CORREO');
v_sender ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET') ;
g_fec_actual date   := pag_cal.fu_obt_fec_actual(1);

BEGIN
   begin -- verifica que este finalizado el cierre
     select a.hor_fin
       into v_hora_fin
       from ge_procesos a
      where a.cod_proceso = 10 ;
   exception
     when others then
          v_hora_fin := null ;
   end ;
   if v_hora_fin is not null and nvl(v_hab_ejecucion, 'N') = 'S' then
     
       PRG_ACT_LOG_PROCESOS('PAS_SNP.PR_OBT_MSJ_MT102_AUT', 'PR_OBT_MSJ_MT102_AUT',trunc(sysdate),to_char(sysdate,'HH24:mi:ss'),to_char(sysdate,'HH24:mi:ss'),'INICIO DE PROCESO  PAS_SNP.PR_OBT_MSJ_MT102_AUT');
       it_mail.mail_attach_blob(sender => v_sender, 
                                recipients => v_dir_correo, 
                                subject => 'INICIO DE PROCESO SIPAP AUTOMATICO', 
                                message => 'Inicia el proceso PAS_SNP.PR_OBT_MSJ_MT102_AUT que genera los lotes mt102 y deposita en la tabla ge_snp_men enviados.'||chr(10) 
                                  || 'Atentamente.', 
                                data => null, 
                                mime_text => null, 
                                mime_attach => null, 
                                filename => null);
                         
      pas_snp.pr_gen_men_automaticos(g_fec_actual, 'S');--, 'N' ); --procedimiento principal
      
      it_mail.mail_attach_blob(sender => v_sender, 
                                recipients => v_dir_correo, 
                                subject => 'FIN DE PROCESO SIPAP AUTOMATICO', 
                                message => 'Finalizo el proceso PAS_SNP.PR_OBT_MSJ_MT102_AUT que genera los lotes mt102 y deposita en la tabla ge_snp_men enviados.'||chr(10) 
                                  || 'Atentamente.', 
                                data => null, 
                                mime_text => null, 
                                mime_attach => null, 
                                filename => null) ;
        PRG_ACT_LOG_PROCESOS('PAS_SNP.PR_OBT_MSJ_MT102_AUT', 'PR_OBT_MSJ_MT102_AUT',trunc(sysdate),to_char(sysdate,'HH24:mi:ss'),to_char(sysdate,'HH24:mi:ss'),'FIN DE PROCESO PAS_SNP.PR_OBT_MSJ_MT102_AUT.');
  
   else
      PRG_ACT_LOG_PROCESOS('PRG_LLA_PRO_PAS_SNP', 'PRG_LLA_PRO_PAS_SNP',trunc(sysdate),to_char(sysdate,'HH24:mi:ss'),to_char(sysdate,'HH24:mi:ss'),'No se Ejecuto el Proceso PAS_SNP.PR_OBT_MSJ_MT102_AUT Porque no Finalizo el Cierre');
       
       it_mail.mail_attach_blob(sender => v_sender, 
                                recipients => v_dir_correo, 
                                subject => 'PROCESO SIPAP AUTOMATICO', 
                                message => 'No se Ejecuto el Proceso PAS_SNP.PR_OBT_MSJ_MT102_AUT Porque no Finalizo el Cierre o Parametro Desabilitado' || chr(10) || chr(10) || 'Atentamente.', 
                                data => null, 
                                mime_text => null, 
                                mime_attach => null, 
                                filename => null);
       
   end if ;  
   commit ;
END;
/

