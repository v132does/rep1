create or replace procedure it.prm_env_mail_vto_repo is
v_dir_correo_para varchar2(200);
cursor cuentas is
   select nro_cuenta
     from md_cta_documentos m
    where m.fec_ven_repo <= pag_cal.FU_OBT_FEC_PROXIMA(10);
    
begin
  v_dir_correo_para:= fug_obt_pardinamico('CAM_MAR_DIR_REPO');--'hbengoa@bbva.com.py'||',amartinez@bbva.com.py'||',ecandia@bbva.com.py'||',lduarte@bbva.com.py'||',mrios@bbva.com.py'||',hkorpershoek@bbva.com.py';
 for cta in cuentas loop
     it_mail.mail(fug_obt_dir_correo,
      v_dir_correo_para,
      'Vencimientos REPO',
      'Informamos el vencimiento de la Cuenta '||cta.nro_cuenta || ', favor proceder a la baja operativamente '||
       'caso contrario el proceso de cierre diario dará curso a la baja automática. '||
      chr(10)||'Atentamente.');
 end loop;
exception
  when others then
    raise_application_error(-20000,'Error '||'-'||sqlerrm);
end;
/

