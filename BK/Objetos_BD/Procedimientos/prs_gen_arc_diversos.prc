CREATE OR REPLACE PROCEDURE IT.PRS_GEN_ARC_DIVERSOS(
    p_provisorio IN VARCHAR2 DEFAULT NULL, 
    P_FECHA      IN DATE DEFAULT NULL     
) IS
    v_fec_proceso DATE;
    v_sql         VARCHAR2(4000);
    v_nom_archivo VARCHAR2(100);
    v_provisorio  VARCHAR2(1);

   /* PROCESO LOCAL: Generacion de archivo sin salto de linea al final*/
    PROCEDURE lp_gen_archivo (
        p_nom_archivo IN VARCHAR2, 
        p_sql         IN VARCHAR2
    ) IS
        v_file           UTL_FILE.FILE_TYPE;
        v_cursor         SYS_REFCURSOR;
        v_linea           VARCHAR2(32767);
        v_contenido_clob CLOB;
        v_path           VARCHAR2(200);
        v_buffer         RAW(32767);
        v_amount         BINARY_INTEGER := 32767;
        v_pos            INTEGER := 1;
        v_clob_len       INTEGER;
        -- Variables para FTP
        v_respuesta        VARCHAR2(4000);
        v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
        v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
        v_dir_destino      ge_par_dinamicos.val_parametro%type;
    BEGIN
        -- 1. Obtener ruta del directorio
        v_path := fug_obt_pardinamico('DIR_REP_FTP');

        -- 2. Inicializar CLOB temporal
        DBMS_LOB.CREATETEMPORARY(v_contenido_clob, TRUE);

        -- 3. Cargar datos en el CLOB
        OPEN v_cursor FOR p_sql;
        LOOP
            FETCH v_cursor INTO v_linea;
            EXIT WHEN v_cursor%NOTFOUND;
            v_linea := REGEXP_REPLACE(v_linea, '['||CHR(10)||CHR(13)||']', '');
            DBMS_LOB.WRITEAPPEND(v_contenido_clob, LENGTH(v_linea) + 1, v_linea || CHR(10));
        END LOOP;
        CLOSE v_cursor;

        -- 4.Eliminar el último salto de línea del CLOB
        v_clob_len := DBMS_LOB.GETLENGTH(v_contenido_clob);
        IF v_clob_len > 0 THEN
            DBMS_LOB.TRIM(v_contenido_clob, v_clob_len - 1);
        END IF;

        -- 5. Apertura en modo binario 'wb'
        v_file := UTL_FILE.FOPEN(v_path, p_nom_archivo, 'wb', 32767);

        -- 6. Volcar CLOB al archivo en bloques RAW
        v_clob_len := DBMS_LOB.GETLENGTH(v_contenido_clob);
        LOOP
            EXIT WHEN v_pos > v_clob_len;
            v_buffer := UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(v_contenido_clob, v_amount, v_pos));
            UTL_FILE.PUT_RAW(v_file, v_buffer, TRUE);
            v_pos := v_pos + v_amount;
        END LOOP;

        UTL_FILE.FCLOSE(v_file);
        DBMS_LOB.FREETEMPORARY(v_contenido_clob);
        
        -- ENVIO POR FTP a carpeta compartida..
	       v_dir_destino := fug_obt_pardinamico('DIR_SVR_REP_ARC_TXT');
         v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
         v_respuesta := pa_file_ftp.fu_put_ascii(pag_evo.g_ip, pag_evo.g_port, pag_evo.g_user,
                                                 pag_evo.g_pass, pag_evo.g_repository,
                                                 p_nom_archivo,v_dir_destino||p_nom_archivo);
         v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
         IF v_respuesta != 'OK' THEN
           -- Insertamos el error del envio al directorio compartido
           INSERT INTO ge_ra_log_ftp
            (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
           VALUES
            (SYSDATE, p_nom_archivo, v_respuesta, v_hini_ftp, v_hfin_ftp);
           COMMIT;
         END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF v_cursor%ISOPEN THEN CLOSE v_cursor; END IF;
            IF UTL_FILE.IS_OPEN(v_file) THEN UTL_FILE.FCLOSE(v_file); END IF;
            IF DBMS_LOB.ISTEMPORARY(v_contenido_clob) = 1 THEN DBMS_LOB.FREETEMPORARY(v_contenido_clob); END IF;
            RAISE;
    END lp_gen_archivo;

BEGIN
    IF P_PROVISORIO IS NULL THEN 
       v_provisorio := 'N';
    ELSE
       V_PROVISORIO := P_PROVISORIO;
    END IF;
    -- 1. Definir nombre de archivo
    IF v_provisorio = 'S' THEN
        v_nom_archivo := 'diversos_provisorio.csv';
    ELSE
        v_nom_archivo := 'diversos.csv';
    END IF;
    

    -- 2. Lógica de obtención de fecha 
    IF P_FECHA IS NULL THEN
        SELECT MAX(fecha) INTO v_fec_proceso 
          FROM it.sb_diversos 
         WHERE provisorio = v_provisorio;
    ELSE
        v_fec_proceso := P_FECHA;
    END IF;
   

    -- Si no hay datos para esa fecha/tipo, lanzamos un error controlado
    IF v_fec_proceso IS NULL THEN
        RAISE_APPLICATION_ERROR(-20004, 'No se encontraron datos en it.sb_diversos para procesar.');
    END IF;

    -- 3. Armado de Query
    v_sql := 'SELECT TO_CHAR(fecha, ''YYYYMMDD'') || '';'' || ' ||
             ' (CASE WHEN SUBSTR(cod_rubro, 1, 2) = ''15'' THEN ''145'' ELSE ''146'' END) || '';'' || ' ||
             ' SUBSTR(SUBSTR(cod_rubro, 1, 8) || SUBSTR(cod_rubro, 3, 1) || SUBSTR(cod_rubro, 9), 1, LENGTH(SUBSTR(cod_rubro, 1, 8) || SUBSTR(cod_rubro, 3, 1) || SUBSTR(cod_rubro, 9)) - 2) || '';'' || ' ||
             ' TRIM(REPLACE(REPLACE(MAX(descripcion), '' GS'', ''''), '' USD'', '''')) || '';'' || ' ||
             ' SUM(mto_mon_local) || '';'' || ' ||
             ' SUM(mto_equ_local) ' ||
             ' FROM it.sb_diversos ' ||
             ' WHERE TRUNC(fecha) = TO_DATE(''' || TO_CHAR(v_fec_proceso, 'DD/MM/YYYY') || ''', ''DD/MM/YYYY'') ' ||
             ' AND provisorio = ''' || v_provisorio || ''' ' ||
             ' GROUP BY fecha, ' ||
             ' (CASE WHEN SUBSTR(cod_rubro, 1, 2) = ''15'' THEN ''145'' ELSE ''146'' END), ' ||
             ' SUBSTR(SUBSTR(cod_rubro, 1, 8) || SUBSTR(cod_rubro, 3, 1) || SUBSTR(cod_rubro, 9), 1, LENGTH(SUBSTR(cod_rubro, 1, 8) || SUBSTR(cod_rubro, 3, 1) || SUBSTR(cod_rubro, 9)) - 2) ' ||
             ' ORDER BY 1 ASC';

    -- 4. Ejecución
    lp_gen_archivo(v_nom_archivo, v_sql);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error en PRS_GEN_ARC_DIVERSOS: ' || SQLERRM);
END;
/
