CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARCHIVO_TXT
  (p_archivo in varchar2,
   p_sql in varchar2,
   p_con_cabecera in varchar2 default 'N',
   p_separador in varchar2 default null,
   p_agrega    in varchar2 default 'N') is
  /* Procesa la sentencia sql generando el archivo */
  v_file UTL_FILE.FILE_TYPE;
  -- el directorio debe estar definido en el init.ora, tal
  -- como sigue: utl_file_dir=/home/oracle/itgf/dat     ---
  --v_Path varchar2(200) := '/home/oracle/itgf/dat';
  -- prueba en IT - oratest
  ---v_Path varchar2(200) := '/oradata/Documentos/IT/temp';
  v_Path varchar2(200) := fug_obt_pardinamico('DIR_REP_FTP');
  --v_path varchar2(100) := 'TEMP_ARCHIVOS'; --'/tmp/archivos'

  v_tipo varchar2(01) := 'w'; -- reemplazar / a-agregar
  v_resultado varchar2(5000) := '';
  v_result           boolean;
  v_cursor           number;
  v_rows             number(10) := 1;
  v_filas            number(9) := 0;
  v_val_campo        varchar2(500);    -- contendra el valor del campo
  v_columnas         number(2) := 2;   -- cantidad de columnas a leer
  v_col_varchar2     varchar2(500);
  v_encabezado       varchar2(400) := ''; -- contendra el encabezado
/* --- DYDMR-3600 - RE - 05/05/2016*/
   -- Variables para FTP
    v_respuesta        VARCHAR2(4000);
    v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
    v_dir_destino      ge_par_dinamicos.val_parametro%type;
   --
    v_err_archivo1      exception;
    v_err_archivo2      exception;
    v_msg_error         varchar2(300);
    
    v_charset     varchar2(40);--contendrá el juego de carecteres de la base de datos.
    v_res_utf8    varchar2(5000) := '';
begin
   --buscamos el juego de caracteres de la base de datos
  BEGIN
    select T.VALUE
       INTO V_CHARSET
    from nls_database_parameters T
    WHERE T.PARAMETER = 'NLS_CHARACTERSET';
  EXCEPTION
     WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000,'Error al buscar caracteres de Base de datos: '||SQLERRM);
  end;
  
    if p_agrega = 'S' then
      v_tipo := 'a'; -- append
    else
      v_tipo := 'w'; -- reWrite
    end if;
    if p_sql is null  then
       raise_application_error(-20000,'Sentencia sql esta nula'); -- sin datos o con valores no reemplazados
    end if;
    --  obtengo la cantidad de columnas de la sentencia select y el encabezado formateado
    prj_obt_tit_columnas(p_sql, v_columnas, v_encabezado);
    if v_columnas <= 0 then -- retorno sin datos
      raise_application_error(-20001,'No existen columnas en el Select');
    end if;
    if p_sql is not null and v_columnas > 0 then
      v_result := dbms_sql.is_open(v_cursor);
      if not v_result then
        v_cursor     := dbms_sql.open_cursor;
        v_result := dbms_sql.is_open(v_cursor);
        if v_result then
         dbms_sql.parse(v_cursor,p_sql,dbms_sql.native); --1 = NATIVE, 2 = V7 Y 0 = V6
         --Variables en el cursors
         for i in 1..v_columnas loop
           dbms_sql.define_column(v_cursor,i,v_col_varchar2,500);
         end loop;
         v_rows := dbms_sql.execute(v_cursor);
        end if;
      end if;
      -- abre el archivo
          IF UTL_FILE.IS_OPEN(v_file) = FALSE THEN
            begin            
                v_file := UTL_FILE.FOPEN(v_Path,p_archivo, v_tipo);
            exception
              when others then
                v_msg_error := substr(sqlerrm,1,300);
                raise v_err_archivo1;
            end;
          ELSE
            v_msg_error := substr(sqlerrm,1,300);
            raise v_err_archivo2;
          END IF;
      if NVL(p_con_cabecera,'S') = 'S' then
         UTL_FILE.PUT_LINE(v_file, replace(substr(v_encabezado,2),'#',p_separador)); -- graba una linea
      end if;
      -- ciclo de lectura de registros
      v_rows :=  dbms_sql.fetch_rows(v_cursor);
      loop exit when v_rows = 0;
          v_filas := v_filas + 1;
          v_resultado := null;
          for i in 1..v_columnas loop
           dbms_sql.column_value(v_cursor,i,v_val_campo);
           if i = v_columnas then
              v_resultado := v_resultado  || nvl(v_val_campo,' ');
           else
              v_resultado := v_resultado  || nvl(v_val_campo,' ')|| p_separador;
           end if;
          end loop;
          --**--
          --convertimos a UTF8
          begin
            v_res_utf8 := convert(v_resultado,'UTF8',V_CHARSET);
          EXCEPTION
             WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20000,'Error al convertir a UTF8 los datos a enviar: '||SQLERRM);
          end;
          --**--
          --UTL_FILE.PUT_LINE(v_file, v_resultado); -- graba una linea
          UTL_FILE.PUT_LINE(v_file, v_res_utf8); -- graba una linea utf8
          -- leo el sigte registro
          v_rows :=  dbms_sql.fetch_rows(v_cursor);
       end loop;
           dbms_sql.close_cursor(v_cursor);
       -- cierra el archivo
       UTL_FILE.FCLOSE(v_file);
	   UTL_FILE.FCLOSE_ALL;
       IF UTL_FILE.IS_OPEN(v_file) THEN
          UTL_FILE.FCLOSE(v_file);
       END IF;
          -- ENVIO POR FTP -- ARCHIVO CLI.TXT Y CLIT.TXT -- DYDMR-3600 - RE - 05/05/2016
	         v_dir_destino := fug_obt_pardinamico('DIR_SVR_REP_ARC_TXT');
           v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
           v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                                   pag_evo.g_pass, pag_evo.g_repository,
                                                   p_archivo,v_dir_destino||p_archivo);
           v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
           IF v_respuesta != 'OK' THEN
             -- Insertamos el error del envio al directorio compartido
             INSERT INTO ge_ra_log_ftp
              (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
             VALUES
              (SYSDATE, p_archivo, v_respuesta, v_hini_ftp, v_hfin_ftp);
             COMMIT;
           END IF;
           --*************************************
    end if;
exception
   when v_err_archivo1 then
     IF DBMS_SQL.IS_OPEN(v_cursor) THEN
        DBMS_SQL.CLOSE_CURSOR(v_cursor);
     END IF;
     UTL_FILE.FCLOSE(v_file);
	 UTL_FILE.FCLOSE_ALL;
     raise_application_error(-20002, ' ***Archivo '||pag_evo.g_repository||'\'||p_archivo||' con error - Descripcion: '||v_msg_error);
   when v_err_archivo2 then
     IF DBMS_SQL.IS_OPEN(v_cursor) THEN
        DBMS_SQL.CLOSE_CURSOR(v_cursor);
     END IF;
     UTL_FILE.FCLOSE(v_file);
	 UTL_FILE.FCLOSE_ALL;
     raise_application_error(-20003, ' ***Archivo '||pag_evo.g_repository||'\'||p_archivo||' con error - Descripcion: '||v_msg_error);
   when others then
     IF DBMS_SQL.IS_OPEN(v_cursor) THEN
        DBMS_SQL.CLOSE_CURSOR(v_cursor);
     END IF;
     UTL_FILE.FCLOSE(v_file);
	 UTL_FILE.FCLOSE_ALL;
     return; -- se retorna como si no existiera
end PRG_GEN_ARCHIVO_TXT;
/
