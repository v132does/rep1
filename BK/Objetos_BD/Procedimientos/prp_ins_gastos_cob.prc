CREATE OR REPLACE PROCEDURE IT.PRP_INS_GASTOS_COB is
  cursor c_gastos is
  select a.cod_persona, a.cod_oficina, a.nro_cuenta, a.nro_cuota, a.cod_tra_cargo, a.fec_vencimiento fec_ini_vigencia,
         a.monto, a.cod_empr_cob, pr.cod_modulo, pr.cod_modalidad, pr.cod_moneda
    from pr_gastos_cob a, ge_cta_clientes cl, pr_cta_prestamos pr
   where a.nro_cuenta = cl.nro_cuenta
     and a.cod_persona = cl.cod_persona
     and a.nro_cuenta = pr.nro_cuenta
   order by pr.cod_moneda, a.nro_cuenta, a.nro_cuota; -- para corte de control por moneda
--variables para envio de correo   --DYDMR-1694 
    V_DIR_CORREO_DE                VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');
    V_DIR_CORREO_PARA              VARCHAR2(300):= FUG_OBT_PARDINAMICO('EMAIL_GASTOS_COBRANZA');
    v_conn  utl_smtp.connection;
    V_DIR_CORREO_PARA_USER         VARCHAR2(300);
    V_DIR_CORREO_PARA_ALL          VARCHAR2(300);
    v_cantidad_registros           number(4);
    v_monto_total                  number(18,2);
    v_cantidad_registros_OK        number(4);
    v_monto_total_OK               number(18,2);
    v_usuario_ejecucion            varchar(10):= user;
    v_hora_log                     varchar2(20);
    v_error_mail                   varchar2(4000);
--fin variables para envio de correo
    v_error       pr_gastos_cob_log.error%type;
    v_redondeo    number(1);
    v_monto       pr_cta_gastos.monto%type;
    v_cod_moneda  ba_monedas.cod_moneda%type := 'X'; -- para que entre la primera vez en el ciclo
/*Se pasa la fecha de vencimiento de la cuota en el campo fec_ingreso para que no de error de PK*/
begin
  v_hora_log := to_char(sysdate, 'HH24:MI:SS'); ----DYDMR-1694
   for x in c_gastos loop
      --v_monto := fup_obt_val_cargo(x.nro_cuenta, x.cod_tra_cargo, x.fec_ini_vigencia, x.nro_cuota, null);
      -- se va a enviar, por el que calculamos en IT no es el correcto (va demás)
      /*
      || DYDMR-517 INVENTARIO cta. gs con decimales cta 1066500371 - SPI 3455
      || xpy0038 - 24/junio/2014
      || Se redondea el monto cuando es moneda local,
      ||ya que al importar el archivo PR_GASTOS_COB.XLS puede tener decimales
      */
      if v_cod_moneda <> x.cod_moneda then
         -- Optimiza cantidad de consultas al parámetro de redondeo
         v_cod_moneda := x.cod_moneda;
         v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',
                         x.cod_modulo,x.cod_modalidad,x.cod_moneda);
      end if;
      v_monto := round(nvl(x.monto,0),v_redondeo);
      begin
         insert into pr_cta_gastos(nro_cuenta, cod_transaccion, cod_moneda, monto, fec_ingreso,
            cod_modalidad, cod_modulo, fec_ini_vigencia)
          values(x.nro_cuenta, x.cod_tra_cargo, x.cod_moneda, v_monto/*x.monto*/, x.fec_ini_vigencia,
            x.cod_modalidad, x.cod_modulo, x.fec_ini_vigencia);

      exception
         when others then
           /*Si hay error, se inserta en un log, para que siga con los demás cargos...*/
            v_error := sqlerrm;
            insert into pr_gastos_cob_log(cod_persona, cod_oficina, nro_cuenta, nro_cuota, cod_tra_cargo,
                   fec_vencimiento, monto, cod_empr_cob, error)
                values (x.cod_persona, x.cod_oficina, x.nro_cuenta, x.nro_cuota, x.cod_tra_cargo,
                   x.fec_ini_vigencia, v_monto/*x.monto*/, x.cod_empr_cob, v_hora_log||'Error:'||v_error);
           /* raise_application_error(-20000, 'Error al insertar gasto: '||x.nro_cuenta||'/'||x.nro_cuota
            ||' tra_cargo:'||x.cod_tra_cargo||' Monto:'||v_monto\*x.monto*\||sqlerrm);*/  --se comenta DYDMR-1694
      end;
   end loop;

   --Controles para envio de mail DYDMR-1694
   --control para deternimar los registros correctos
  begin
    select count(*) CANTIDAD_REGISTROS_OK, sum(monto) MONTO_TOTAL_OK
      into v_cantidad_registros_OK, v_monto_total_OK
      from pr_cta_gastos a
     where trunc(a.fec_insercion) = trunc(sysdate)
       --DYDMR-1972-ITGF - Comisiones por Cobranza SC 17075-EGC-19/06/2015
       and a.usu_insercion = user;
  end;
      --control para deternimar los registros incorrectos
  begin
    select count(*) CANTIDAD_REGISTROS, sum(monto) MONTO_TOTAL
      into v_cantidad_registros, v_monto_total
      from pr_gastos_cob_log a
     where trunc(a.fec_insercion) = trunc(sysdate)
       and  substr(error,1, 8) = v_hora_log
       --DYDMR-1972-ITGF - Comisiones por Cobranza SC 17075-EGC-19/06/2015
       and a.usu_insercion = user;
  end;
  --proceso de envios de mail OK  o con error.
  begin
    select a.dir_correo
      into V_DIR_CORREO_PARA_USER
      from ba_usuarios a
     where a.cod_usuario = user;
  exception
    when others then
      raise_application_error(-20000, 'ERROR: '||user||' no cuenta con direccion de correo electrónico');
  end;
  begin
   V_DIR_CORREO_PARA_ALL:= V_DIR_CORREO_PARA || ',' || V_DIR_CORREO_PARA_USER;

    if v_cantidad_registros > 0 then
          --DE, PARA y el ASUNTO
           v_conn := it_mail.begin_mail(V_DIR_CORREO_DE,V_DIR_CORREO_PARA_ALL,'Proceso de Importación de Gasto Cobranza con Errores');
          --Cuerpo del mail
           it_mail.write_text(v_conn,'Usuario: '||v_usuario_ejecucion||' .Total de registros con errores: '||v_cantidad_registros|| ' ,total monto: '||v_monto_total|| ' Para mas detalles verificar la Consulta Dinámica: ERRORES DEL PROCESO GASTOS DE COBRANZAS');
           it_mail.end_mail(v_conn);
    else
          --DE, PARA y el ASUNTO
           v_conn := it_mail.begin_mail(V_DIR_CORREO_DE,V_DIR_CORREO_PARA_ALL,'Proceso de Importación de Gasto Cobranza Exitosa');
          --Cuerpo del mail
           it_mail.write_text(v_conn,'Usuario: '||v_usuario_ejecucion||' .Registros procesados: '||v_cantidad_registros_OK||' ,total monto: '||v_monto_total_OK);
           it_mail.end_mail(v_conn);
    end if;
  exception
    when others then
      v_error_mail := sqlerrm;
      insert into ge_log_mail
        (fec_envio,
         cod_persona,
         dir_correo,
         mensaje,
         det_error,
         nro_cuenta,
         hor_inicio,
         hor_fin)
      values
        (trunc(sysdate),
         null,
         v_dir_correo_para_all,
         'Error en envío de mail Importación de Datos de Cargos por Gestión de Cobranza',
         v_error_mail,
         null,
         v_hora_log,
         v_hora_log);
  end;

exception
   when others then
      raise_application_error(-20001, 'Error al ejecutar procedimiento: '||sqlerrm);
end;
/

