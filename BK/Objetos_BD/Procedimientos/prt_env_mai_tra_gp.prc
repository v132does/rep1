CREATE OR REPLACE PROCEDURE IT.prt_env_mai_tra_gp (p_nro_proceso in it.ah_con_dia_det.nro_con_dia%type) IS
    v_cant_error number;
    v_dir_correo ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('MAI_REG_TRA_TC_GP_ERR');
    v_fec_actual date:= pag_cal.fu_obt_fec_actual(5);
  BEGIN
     begin
       select count(*)
       into v_cant_error
       from AH_CON_DIA_DET z
       where z.nro_con_dia=p_nro_proceso
       and nvl(procesado,'N') <>'S';
       exception
         when no_Data_found then
           v_cant_error:=0;
           when others then
             v_cant_error:=0;
             null;
        end;
       if v_cant_error>0 then --notificaciones@ueno.com.py
          it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                       'Error de procesamiento de mov de GP',
                       'Se ha procesado el archivo de transacciones diarias de Global Procesing. La cantidad de registros con error es de : '||
                       v_cant_error || '.Fecha: ' || to_char(v_fec_actual, 'dd/mm/yyyy') ||' ,correspondiente al proceso nro.' ||p_nro_proceso
                        ||chr(10) || 'Atentamente.');
       end if;

  END;
/

