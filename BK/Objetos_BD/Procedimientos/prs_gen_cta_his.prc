create or replace procedure it.prs_gen_cta_his is
  v_cod_persona   ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('PERSONA_CONSULTA_HIS');
  v_nro_documento varchar2(60);

  cursor c_historic is
  select cuenta, pais, tipo_documento, numero_documento, tipo_operacion_bcp,
         moneda, descripcion_moneda, rubro, modalidad, nro_operacion,
         fecha_contabilizacion, tasa, fecha_vto, fecha_pago, dias_atraso,
         monto_cuota, capital, interes, saldo_a_cobrar_capital,
         saldo_a_cobrar_interes, saldo_a_pagar_capital, saldo_a_pagar_interes,
         estado, categoria, nro_cuota
    from ge_ope_cuentas_his a
   where a.cod_persona = v_cod_persona
   order by a.nro_operacion, a.nro_cuota, a.fecha_inicio;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'Historico_operaciones_'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;

  -- Variables de fechas
  v_fec_sist         DATE;
  v_fecha            VARCHAR2(8);

begin

  -- Obtenemos la fecha del sistema
  select pag_cal.FU_OBT_FEC_ACTUAL(1)
  into v_fec_sist
  from dual;

  v_fecha := to_char(v_fec_sist,'YYYYMMDD');
  v_file := UTL_FILE.FOPEN(pag_evo.g_repository,v_name||'.txt','W',32767);

  v_linetit := 'CUENTA'||CHR(9)||'PAIS'||CHR(9)||
               'TIPO_DOCUMENTO'||CHR(9)||'NUMERO_DOCUMENTO'||CHR(9)||'TIPO_OPERACION_BCP'||CHR(9)||
               'MONEDA'||CHR(9)||'DESCRIPCION_MONEDA'||CHR(9)||
               'RUBRO'||CHR(9)||'MODALIDAD' ||CHR(9)||'NRO_OPERACION'||CHR(9)||
               'FECHA_CONTABILIZACION'||CHR(9)||'TASA'||CHR(9)||'FECHA_VTO'||CHR(9)||'FECHA_PAGO'||CHR(9)||
               'DIAS_ATRASO'||CHR(9)||'MONTO_CUOTA'||CHR(9)||'CAPITAL'||CHR(9)||'INTERES'||CHR(9)||
               'SALDO_A_COBRAR_CAPITAL'||CHR(9)||'SALDO_A_COBRAR_INTERES'||CHR(9)||
               'SALDO_A_PAGAR_CAPITAL'||CHR(9)||'SALDO_A_PAGAR_INTERES'||CHR(9)||
               'ESTADO'||CHR(9)||'CATEGORIA'||CHR(9)||'NRO_CUOTA';

   utl_file.put_line(v_file,v_linetit);
   -- Definir una linea en blanco para separar los datos del titulo de los campos
   v_linetit := ' ';
   utl_file.put_line(v_file,v_linetit);
   
   delete ge_ope_cuentas_his a
    where a.cod_persona = v_cod_persona;
   
   begin
      insert into ge_ope_cuentas_his(
                  cuenta, pais, tipo_documento, numero_documento, tipo_operacion_bcp,
                  moneda, descripcion_moneda, rubro, modalidad, nro_operacion,
                  fecha_contabilizacion, tasa, fecha_vto, fecha_pago, dias_atraso,
                  monto_cuota, capital, interes, saldo_a_cobrar_capital,
                  saldo_a_cobrar_interes, saldo_a_pagar_capital, saldo_a_pagar_interes,
                  estado, categoria, nro_cuota, cod_persona, fecha_inicio)
           select cod_persona, pais, tip_doc, nro_documento, tip_operacion,
                  cod_mon_bco_central, moneda, rubro_bcp, modalidad, nro_cuenta,
                  fec_contabilizacion, val_tasa, fec_vencimiento, fec_ult_pago, atraso,
                  mto_cuota, mto_capital, mto_interes, sal_capital, sal_interes,
                  saldo_pagar_capital, saldo_pagar_interes, estado_sit, categoria,
                  nro_cuota, cod_persona, to_char(fec_inicio,'YYYYMMDD')
             from gv_ope_cuentas_his a
            where a.cod_persona = v_cod_persona
            order by a.nro_cuenta, a.nro_cuota, a.fec_inicio;
   exception
      when others then
         raise_application_error(-20000,'Al Ins.GE_OPE_CUENTAS_HIS: '||sqlerrm);
   end;

   for rec in c_historic loop
      v_line :=
         rec.cuenta||chr(9)||rec.pais||chr(9)||rec.tipo_documento||chr(9)||rec.numero_documento||chr(9)||
         rec.tipo_operacion_bcp||chr(9)||rec.moneda||chr(9)||rec.descripcion_moneda||chr(9)||rec.rubro||chr(9)||
         rec.modalidad||chr(9)||rec.nro_operacion||chr(9)||rec.fecha_contabilizacion||chr(9)||rec.tasa||chr(9)||
         rec.fecha_vto||chr(9)||rec.fecha_pago||chr(9)||rec.dias_atraso||chr(9)||rec.monto_cuota||chr(9)||
         rec.capital||chr(9)||rec.interes||chr(9)||rec.saldo_a_cobrar_capital||chr(9)||
         rec.saldo_a_cobrar_interes||chr(9)||rec.saldo_a_pagar_capital||chr(9)||rec.saldo_a_pagar_interes||chr(9)||
         rec.estado||chr(9)||rec.categoria||chr(9)||rec.nro_cuota;

      IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
         v_buffer := v_buffer || v_eol || v_line;
      ELSE
        IF v_buffer IS NOT NULL THEN
          --Escribes la linea en el fichero
          UTL_FILE.PUT_LINE(v_file, v_buffer);
        END IF;
         v_buffer := v_line;
      END IF;

      v_lines := v_lines + 1;
      if v_nro_documento is null then
         v_nro_documento := rec.numero_documento;
      end if;
   end loop;
   --Escribes la linea en el fichero
   UTL_FILE.PUT_LINE(v_file, v_buffer);
   --Cerrar el handler al fichero
   UTL_FILE.FCLOSE(v_file);

   v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
   -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
   v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                           pag_evo.g_pass, pag_evo.g_repository,
                                           v_name||'.txt',
                                           pag_evo.g_operaciones||v_name||v_nro_documento||'_'||v_fecha||'.csv');
   v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

   IF v_respuesta <> 'OK' THEN  -- ERROR AL ENVIAR ARCHIVO POR FTP
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
         (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
         (SYSDATE, v_name||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;
      raise_application_error(-20000,'ERROR AL ENVIAR ARCHIVO POR FTP: '||sqlerrm);
  END IF;

EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20061,'Operacion invalida '||sqlerrm);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062,'Manejador invalido '||sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063,'Error de escritura '||sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064,'Modo invalido '||sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065,'Internal Error '||sqlerrm);
end prs_gen_cta_his;
/

