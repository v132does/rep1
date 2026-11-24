CREATE OR REPLACE PROCEDURE IT.PRT_GEN_ALT_ASCII(p_sec_envio in number)
 IS
--- Variables del proceso
   v_fec_proceso ge_calendarios.fec_actual%type;
   v_mes_proceso varchar2(08);
   v_nom_ascii   varchar2(19);
   v_directorio  varchar2(100);
   v_hor_envio   ta_env_cuentas.hor_envio%type;

   --- Cursor de cuentas a enviar--
   cursor c_cuentas IS
   select a.*, a.rowid registro
     from ta_env_cuentas a
    where a.sec_env_datos = p_sec_envio;

   --- Lineas ASCII--
   v_archivo           utl_file.file_type;
   v_lin_cuentas       varchar2(235);
BEGIN
   v_fec_proceso := pag_cal.fu_obt_fec_actual(3);
   v_mes_proceso := to_char(v_fec_proceso,'YYYYMMDD');
   v_directorio  := 'TARJETAS';
   v_hor_envio   := to_char(sysdate,'hh24:mi:ss');

   if utl_file.is_open(v_archivo) then
      utl_file.fclose(v_archivo);
   end if;
   --- Procesar archivo cuentas --
   v_nom_ascii := 'bancard'||v_mes_proceso||'.txt';
   v_archivo   := utl_file.fopen(v_directorio,v_nom_ascii,'w');
   FOR r_cta IN c_cuentas LOOP
      --Armar linea del archivo--
      v_lin_cuentas := null;
      v_lin_cuentas := rpad(r_cta.nro_cuenta,9,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.cod_banco),2,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.cod_sucursal),2,'0');
      v_lin_cuentas := v_lin_cuentas||rpad(nvl(r_cta.nom_usuario,' '),30,' ');
      v_lin_cuentas := v_lin_cuentas||rpad(nvl(r_cta.direccion,' '),35,' ');
      v_lin_cuentas := v_lin_cuentas||rpad(nvl(r_cta.localidad,' '),15,' ');
      v_lin_cuentas := v_lin_cuentas||rpad(nvl(r_cta.cod_zona,' '),2,' ');
      v_lin_cuentas := v_lin_cuentas||rpad(nvl(r_cta.telefono,' '),12,' ');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.cod_encargado,4,'0');
   --   v_lin_cuentas := v_lin_cuentas||lpad(to_char(nvl(r_cta.lim_credito,0)),11,'0');
      v_lin_cuentas := v_lin_cuentas||rpad(r_cta.cod_for_pago,1,' ');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.cta_bancaria),11,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.cod_mod_pago,2,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.tip_tasa,1,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.tip_comision,1,'0');
 --     v_lin_cuentas := v_lin_cuentas||lpad(r_cta.cod_franqueo,1,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.cod_retencion,1,'0');
  --    v_lin_cuentas := v_lin_cuentas||rpad(nvl(r_cta.nom_codeudor,' '),30,' ');
      v_lin_cuentas := v_lin_cuentas||rpad(substr(nvl(r_cta.nro_doc_codeudor,' '),1,9),9,' ');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.tip_cuenta,1,'0');
   --   v_lin_cuentas := v_lin_cuentas||lpad(r_cta.tip_cierre,1,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.fec_novedad,'ddmmyy'),6,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.tip_tarjeta,2,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.cod_afinidad,2,'0');
      v_lin_cuentas := v_lin_cuentas||rpad(r_cta.cta_vip,1,' ');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.fac_vip),4,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(r_cta.cod_gas_financiero,1,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.sec_alta),3,'0');
   --   v_lin_cuentas := v_lin_cuentas||lpad(to_char(nvl(r_cta.lim_cuota,0)),9,'0');
      v_lin_cuentas := v_lin_cuentas||rpad(r_cta.es_personalizado,1,' ');
     -- v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.tas_int_corriente),4,'0');
    -- v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.tas_int_mora),4,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.pag_minimo),9,'0');
      v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.por_pag_minimo),4,'0');
      v_lin_cuentas := v_lin_cuentas||rpad(r_cta.cod_movimiento,1,' ');
    --  v_lin_cuentas := v_lin_cuentas||lpad(to_char(r_cta.int_sob_compras),3,'0');
      utl_file.put_line(v_archivo, v_lin_cuentas);

      --actualizar el registro de la cuenta--
      update ta_env_cuentas x
         set x.fec_envio = v_fec_proceso,
             x.hor_envio = v_hor_envio,
             x.estado = 'E' --Enviado--
       where x.rowid = r_cta.registro;
   END LOOP;
   utl_file.fclose(v_archivo);
   EXCEPTION
     when no_data_found then
        --- Fin del archivo
        utl_file.fclose(v_archivo);
     when utl_file.invalid_path  THEN
        utl_file.fclose(v_archivo);
        raise_application_error(-20000,
        'Directorio invalido');
     when utl_file.invalid_mode  THEN
        utl_file.fclose(v_archivo);
        raise_application_error(-20000,
        'Modo invalido');
     when utl_file.invalid_filehandle THEN
        utl_file.fclose(v_archivo);
        raise_application_error(-20000,
        'Invalida Filehandle');
     when utl_file.invalid_operation  THEN
        --- Fin del archivo
        utl_file.fclose(v_archivo);
     when utl_file.read_error         THEN
        utl_file.fclose(v_archivo);
        raise_application_error(-20000,
        'Lectura errada');
     when utl_file.write_error        THEN
        utl_file.fclose(v_archivo);
        raise_application_error(-20000,
        'Escritura errada');
     when utl_file.internal_error     THEN
        utl_file.fclose(v_archivo);
        raise_application_error(-20000,
        'Error interno');
END PRT_GEN_ALT_ASCII;
/

