create or replace PROCEDURE                      IT.PRG_GEN_INVENTARIOS IS

    /* MJ  24-10-2025 Procedimiento que genera reporte inventarios diarios y los deja en el servidor FTP
                      Para el tipo de reporte Inv_Diario generara el mismo agregandole el saldo de la fecha anterior para posterior comparacion
                      Se suma este ultimo reporte por pedido del usuario


       MJ 01-02-2026  Se agrega fn_get_nombre_versionado para tener control del nombre de los archivos por requerimiento TN-946 para que duren los archivos
                      en el servidor segun configuracion solicitada por el usuario
                      Se modifica el nombre de los archivos quitandole la fecha para que se pisen en el servidor*/
                      


    c_dir       CONSTANT VARCHAR2(30) := 'DIR_TXT';
    c_delim     CONSTANT VARCHAR2(1)  := CHR(9);

    v_file      UTL_FILE.FILE_TYPE;
    v_file_rep  UTL_FILE.FILE_TYPE;
    v_file_rep_abierto BOOLEAN := FALSE;

    v_line      VARCHAR2(32767);
    v_line_rep  VARCHAR2(32767);
    v_respuesta VARCHAR2(2000);
    v_hini_ftp  VARCHAR2(10);
    v_hfin_ftp  VARCHAR2(10);
    v_saldo_fecha2 NUMBER;
    v_diferencia NUMBER(18,2);  
    v_dia_ant DATE := fug_obt_fec_anterior(6); --Calcula fecha dia anterior para comparacion
	v_fecha DATE :=   TRUNC(TO_DATE(TO_CHAR(IT.FUG_OBT_FEC_HABIL_ANT(SYSDATE), 'DD/MM/YYYY'),'DD/MM/YYYY'));
    v_nombre_rep_versionado VARCHAR2(200);
    v_nombre_versionado VARCHAR2(200);
    v_can_dias NUMBER;


    TYPE t_archivo IS RECORD (
        nombre VARCHAR2(100),
        filtro VARCHAR2(4000),
        doble_fecha CHAR(1)
                              );

    TYPE t_lista IS TABLE OF t_archivo;

    v_lista t_lista := t_lista(
        t_archivo(
            'Inv_Diario_automatico',
            'T.COD_TIP_DEUDOR (+) = C.COD_TIP_DEUDOR AND '||
            'T.COD_SEC_CONTABLE (+) = C.COD_SEC_CONTABLE AND '||
            '((C.COD_MODULO = ''3'' AND C.COD_MODALIDAD NOT IN (''36'') AND C.TIP_SALDO IN (''C'',''A'',''I'')) OR '||
            '(C.COD_MODULO = ''4'' AND C.COD_MODALIDAD = ''41'' AND C.TIP_SALDO IN (''C'',''Q'')) OR '||
            '(C.COD_MODULO = ''3'' AND C.COD_MODALIDAD IN (''36'') AND C.TIP_SALDO IN (''C'')) OR '||
            '(C.COD_MODULO = ''10'' AND C.COD_MODALIDAD IN (''126'') AND C.TIP_SALDO IN (''C''))) AND '||
            'D.SAL_ACTUAL <> 0 AND SUBSTR(COD_RUBRO,1,1) = ''2''',
            'Y'
        ),
        t_archivo( 
            'Inv_Diario_Tip_D_automatico',
            'T.COD_TIP_DEUDOR (+) = C.COD_TIP_DEUDOR AND '||
            'T.COD_SEC_CONTABLE (+) = C.COD_SEC_CONTABLE AND '||
            '((C.COD_MODULO IN (''3'') AND C.TIP_SALDO IN (''D'')) OR '||
            '(C.COD_MODULO = ''10'' AND C.COD_MODALIDAD = ''126'' AND C.TIP_SALDO IN (''D''))) AND '||
            'D.SAL_ACTUAL <> 0',
            'N'
        ),
        t_archivo(
            'Inv_Diario_not_3_4_5_automatico',
            'T.COD_TIP_DEUDOR (+) = C.COD_TIP_DEUDOR AND '||
            'T.COD_SEC_CONTABLE (+) = C.COD_SEC_CONTABLE AND '||
            'C.COD_MODULO NOT IN (''3'',''4'',''5'',''2'',''9'',''10'') AND '||
            'C.TIP_SALDO NOT IN (''K'',''D'',''E'',''J'',''L'',''U'',''X'',''Z'',''N'') AND '||
            'D.SAL_ACTUAL <> 0',
            'N'
        ),
        t_archivo(
            'Inv_Diario_Mod_5_TC_automatico',
            'T.COD_TIP_DEUDOR (+) = C.COD_TIP_DEUDOR AND '||
            'T.COD_SEC_CONTABLE (+) = C.COD_SEC_CONTABLE AND '||
            'C.COD_MODULO = ''5'' AND '||
            'C.TIP_SALDO NOT IN (''K'',''D'',''O'') AND '||
            'D.SAL_ACTUAL <> 0',
            'N'
        ),
        t_archivo(
            'Inv_Diario_4_Act_automatico',
            'T.COD_TIP_DEUDOR (+) = C.COD_TIP_DEUDOR AND '||
            'T.COD_SEC_CONTABLE (+) = C.COD_SEC_CONTABLE AND '||
            'C.COD_MODULO = ''4'' AND '||
            'C.COD_MODALIDAD = ''41'' AND '||
            'C.TIP_SALDO NOT IN (''K'',''D'',''O'') AND '||
            'C.TIP_SALDO IN (''C'',''V'') AND '||
            'D.SAL_ACTUAL <> 0 AND '||
            'SUBSTR(COD_RUBRO,1,1) = ''1''',
            'N'
        )
    );


     FUNCTION fn_get_nombre_versionado ( p_nombre_base IN VARCHAR2) RETURN VARCHAR2
     IS
        v_cant_dias   NUMBER;
        v_ult_nombre  VARCHAR2 (100);
        v_version     NUMBER := 1;

        BEGIN

        SELECT val_parametro
        INTO v_cant_dias -- cantidad dias retencion del archivo 
        FROM it.ge_par_dinamicos
        WHERE parametro = 'PRG_GEN_INV_DURACION';

        IF v_cant_dias = 1 THEN
            RETURN p_nombre_base || '_1';
        END IF;

        SELECT nom_archivo
        INTO v_ult_nombre
        FROM (
            SELECT nom_archivo
            FROM ge_ra_log_ftp
            WHERE nom_archivo LIKE p_nombre_base || '\_%' ESCAPE '\'
            ORDER BY fec_envio DESC
             )
        WHERE ROWNUM = 1;

        v_version := NVL( TO_NUMBER(REGEXP_SUBSTR(v_ult_nombre, '[0-9]+$')),0) + 1;

        IF v_version > v_cant_dias THEN
           v_version := 1;
        END IF;

        RETURN p_nombre_base || '_' || v_version;

            EXCEPTION
            WHEN NO_DATA_FOUND THEN
            RETURN p_nombre_base || '_1';

    END fn_get_nombre_versionado;



    --------------------------------------------------------------------------
    PROCEDURE generar_archivo(
        p_fecha         DATE,
        p_archivo       VARCHAR2,
        p_filtro        VARCHAR2,
        p_fecha_compara DATE DEFAULT NULL
    ) IS
        v_sql CLOB;

        TYPE t_rec IS RECORD (
            FECHA DATE,
            TIP_DEUDOR VARCHAR2(60),
            NRO_CUENTA VARCHAR2(50),
            COD_PERSONA VARCHAR2 (50),
            DOCUMENTO VARCHAR2 (50),
            NOMBRE VARCHAR2(120),
            COD_MODULO VARCHAR2(50),
            COD_MODALIDAD VARCHAR2(50),
            MODAL VARCHAR2 (50),
            COD_OFICINA NUMBER (3),
            DES_OFI VARCHAR2 (50),
            COD_MONEDA VARCHAR2(3),
            TIP_SALDO VARCHAR2 (3),
            SITUACION VARCHAR2 (3),
            ESTADO VARCHAR2 (200),
            FEC_APERTURA DATE,
            FEC_VENCIMIENTO DATE,
            VAL_TASA NUMBER (20,4),
            COD_RUBRO VARCHAR2(50),
            DES_RUBRO varchar2 (500),             
            SALDO NUMBER (18,2)
        );

        v_rec t_rec;
        c1 SYS_REFCURSOR;

     BEGIN 
        v_file := UTL_FILE.FOPEN(c_dir, p_archivo||'.txt','W',32767);
          UTL_FILE.PUT_LINE(v_file,
                            '"FECHA"'           || c_delim ||
                            '"TIP_DEUDOR"'      || c_delim ||
                            '"NRO_CUENTA"'      || c_delim ||
                            '"COD_PERSONA"'     || c_delim ||
                            '"DOCUMENTO"'       || c_delim ||
                            '"NOMBRE"'          || c_delim ||
                            '"COD_MODULO"'      || c_delim ||
                            '"COD_MODALIDAD"'   || c_delim ||
                            '"MODAL"'           || c_delim ||
                            '"COD_OFICINA"'     || c_delim ||
                            '"DES_OFI"'         || c_delim ||
                            '"COD_MONEDA"'      || c_delim ||
                            '"TIP_SALDO"'       || c_delim ||
                            '"SITUACION"'       || c_delim ||
                            '"ESTADO"'          || c_delim ||
                            '"FEC_APERTURA"'    || c_delim ||
                            '"FEC_VENCIMIENTO"' || c_delim ||
                            '"VAL_TASA"'        || c_delim ||
                            '"COD_RUBRO"'       || c_delim ||
                            '"DES_RUBRO"'       || c_delim ||
                            '"SALDO"'
                            );

    v_sql :=  'SELECT 
                 C.FECHA,
                 T.DESCRIPCION TIP_DEUDOR,
                 D.NRO_CUENTA,
                 S.COD_PERSONA,
                 FUE_OBT_NRO_DOC_PERSONA(S.COD_PERSONA) DOCUMENTO,
                 REGEXP_REPLACE(
               REPLACE(
                     REPLACE(
                       REPLACE(TRIM(FUE_OBT_NOM_PERSONA(S.COD_PERSONA)), CHR(9), '' ''),   -- quita tabulaciones
                       CHR(10), '' ''),                                                    -- quita salto de línea LF
                     CHR(13), '' ''),                                                      -- quita retorno de carro CR
                   ''[[:space:]]+'', '' ''
                      ) NOMBRE,
                 C.COD_MODULO,
                 C.COD_MODALIDAD,
                 TRIM(FUG_OBT_DES_MODAL(C.COD_MODULO, C.COD_MODALIDAD)) MODAL,
                 C.COD_OFICINA,
                 TRIM(FUE_OBT_DES_OFICINA(C.COD_OFICINA)) DES_OFI,
                 C.COD_MONEDA,
                 C.TIP_SALDO,
                 C.SITUACION,
                 TRIM(FUG_OBT_DES_EST_CTA(P.COD_MODULO, P.COD_MODALIDAD, C.SITUACION)) ESTADO,
                 P.FEC_APERTURA,
                 P.FEC_VENCIMIENTO,
                 P.VAL_TASA,
                 C.COD_RUBRO,
                 FUB_OBT_DES_CTA_CONTABLE(C.COD_RUBRO) DES_RUBRO,
                 NVL(D.SAL_ACTUAL, 0) SALDO
              FROM  CB_SAL_INVENTARIOS_HIS C,
                    CB_SAL_INVENTARIOS_DET_HIS D,
                    GE_CTA_CLIENTES S,
                    GE_CUENTAS P,
                    GE_TIP_DEUDORES T
              WHERE D.NRO_REFERENCIA = C.NRO_REFERENCIA
                AND D.FECHA = C.FECHA
                AND S.NRO_CUENTA = D.NRO_CUENTA
                AND P.NRO_CUENTA = S.NRO_CUENTA
                AND S.RELACION = ''P''
                AND C.FECHA = :1
                AND ' || p_filtro || '
              ORDER BY 
                C.FECHA, C.COD_MODULO, C.COD_MODALIDAD, C.COD_RUBRO';

        OPEN c1 FOR v_sql USING p_fecha;
        LOOP
            FETCH c1 INTO v_rec;
            EXIT WHEN c1%NOTFOUND;

         -- Archivo principal
            v_line := 
            TO_CHAR(v_rec.FECHA, 'DD/MM/YYYY')                  || c_delim ||   -- FECHA
            '"'||v_rec.TIP_DEUDOR||'"'                          || c_delim ||   -- TIP_DEUDOR
            '"'||v_rec.NRO_CUENTA||'"'                          || c_delim ||   -- NRO_CUENTA
            '"'||v_rec.COD_PERSONA||'"'                         || c_delim ||   -- COD_PERSONA
            '"'||v_rec.DOCUMENTO||'"'                           || c_delim ||   -- DOCUMENTO
            '"'||REPLACE(v_rec.NOMBRE, '"', '')||'"'            || c_delim ||   -- NOMBRE
            v_rec.COD_MODULO                                    || c_delim ||   -- COD_MODULO
            v_rec.COD_MODALIDAD                                 || c_delim ||   -- COD_MODALIDAD
            '"'||v_rec.MODAL||'"'                               || c_delim ||   -- MODAL
            v_rec.COD_OFICINA                                   || c_delim ||   -- COD_OFICINA
            '"'||v_rec.DES_OFI||'"'                             || c_delim ||   -- DES_OFI
            '"'||v_rec.COD_MONEDA||'"'                          || c_delim ||   -- COD_MONEDA
            '"'||v_rec.TIP_SALDO||'"'                           || c_delim ||   -- TIP_SALDO
            '"'||v_rec.SITUACION||'"'                           || c_delim ||   -- SITUACION
            '"'||v_rec.ESTADO||'"'                              || c_delim ||   -- ESTADO
            TO_CHAR(v_rec.FEC_APERTURA,'DD/MM/YYYY')            || c_delim ||   -- FEC_APERTURA
            TO_CHAR(v_rec.FEC_VENCIMIENTO,'DD/MM/YYYY')         || c_delim ||   -- FEC_VENCIMIENTO
            v_rec.VAL_TASA                                      || c_delim ||   -- VAL_TASA
            '"'||v_rec.COD_RUBRO||'"'                           || c_delim ||   -- COD_RUBRO
            '"'||v_rec.DES_RUBRO||'"'                           || c_delim ||   -- DES_RUBRO
            TO_CHAR(v_rec.saldo,
                    'FM9999999999990D99',
                    'NLS_NUMERIC_CHARACTERS='',.''' );
            UTL_FILE.PUT_LINE(v_file, v_line);


            -- Si es archivo Inv_Diario, escribir diferencias
            IF p_archivo LIKE 'Inv_Diario_automatico%' THEN
                BEGIN
                    SELECT NVL(D.SAL_ACTUAL,0)
                    INTO v_saldo_fecha2
                    FROM CB_SAL_INVENTARIOS_HIS C2,
                         CB_SAL_INVENTARIOS_DET_HIS D
                    WHERE D.NRO_REFERENCIA = C2.NRO_REFERENCIA
                      AND D.FECHA = v_dia_ant
                      AND D.NRO_CUENTA = v_rec.NRO_CUENTA
                      AND C2.COD_MODULO = v_rec.COD_MODULO
                      AND C2.COD_MODALIDAD = v_rec.COD_MODALIDAD
                      AND COD_RUBRO = v_rec.COD_RUBRO;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        v_saldo_fecha2 := NULL;
                END;


                -- Escribir en archivo de diferencias
                IF v_file_rep_abierto THEN
                    v_diferencia := NVL(v_saldo_fecha2, 0) - NVL(v_rec.saldo, 0);

                    v_line_rep := v_rec.NRO_CUENTA||c_delim||
                                  TO_CHAR(p_fecha,'DD/MM/YYYY')||c_delim||
                                  NVL(TO_CHAR(p_fecha_compara,'DD/MM/YYYY'),'')||c_delim||
                                  v_rec.cod_rubro||c_delim||
                                  v_rec.saldo ||c_delim||
                                  v_saldo_fecha2 ||c_delim||
                                  v_diferencia;
                    UTL_FILE.PUT_LINE(v_file_rep, v_line_rep);

                END IF;
            END IF;



        END LOOP;

        CLOSE c1;
        UTL_FILE.FCLOSE(v_file);

        -- Enviar archivo individual al FTP
        v_hini_ftp := TO_CHAR(SYSDATE,'HH24:MI:SS');
        v_respuesta := pa_file_ftp.fu_put_ascii(
                            pag_evo.g_ip,
                            pag_evo.g_port,
                            pag_evo.g_user,
                            pag_evo.g_pass,
                            pag_evo.g_repository,
                            p_archivo||'.txt',
                            p_archivo||'.txt'
                        );

        v_hfin_ftp := TO_CHAR(SYSDATE,'HH24:MI:SS');



        INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES (sysdate, p_archivo,v_respuesta,v_hini_ftp, v_hfin_ftp);
        COMMIT;

        EXCEPTION
        WHEN OTHERS THEN

        v_respuesta := NVL(v_respuesta, SUBSTR(SQLERRM,1,4000));

        INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES (sysdate, p_archivo, v_respuesta, v_hini_ftp, v_hfin_ftp);

            IF  UTL_FILE.IS_OPEN(v_file) THEN
                UTL_FILE.FCLOSE(v_file);
            END IF;


    END generar_archivo;
    --------------------------------------------------------------------------

BEGIN

        v_nombre_rep_versionado :=
        fn_get_nombre_versionado('Reporte_Inv_Diario_Diferencias_automatico');

    -- Abrir archivo de diferencias una sola vez
    v_file_rep := UTL_FILE.FOPEN(c_dir, v_nombre_rep_versionado || '.txt','W',32767);

    UTL_FILE.PUT_LINE(v_file_rep, 'NRO_CUENTA'||c_delim||'FECHA_ACTUAL'||c_delim||'FECHA_ANTERIOR'||c_delim||'COD_RUBRO'||c_delim||'SALDO_ACTUAL'||c_delim||'SALDO_ANTERIOR'||c_delim||'DIFERENCIA');
    v_file_rep_abierto := TRUE;


    -- Generar todos los archivos
    FOR i IN v_lista.FIRST .. v_lista.LAST LOOP

            BEGIN
                v_nombre_versionado :=
                    fn_get_nombre_versionado(v_lista(i).nombre);

                generar_archivo(v_fecha,v_nombre_versionado,
                    v_lista(i).filtro, CASE
                                       WHEN v_lista(i).doble_fecha = 'Y'
                                       THEN v_dia_ant
                                       ELSE NULL
                                        END
                                 );
            END;

    END LOOP;

   BEGIN

   v_respuesta := NULL;

    -- Cerrar y enviar archivo de diferencias al FTP
    IF v_file_rep_abierto THEN
        UTL_FILE.FCLOSE(v_file_rep);

        v_hini_ftp := TO_CHAR(SYSDATE,'HH24:MI:SS');
        v_respuesta := pa_file_ftp.fu_put_ascii(
                            pag_evo.g_ip,
                            pag_evo.g_port,
                            pag_evo.g_user,
                            pag_evo.g_pass,
                            pag_evo.g_repository,
                            v_nombre_rep_versionado||'.txt',
                            v_nombre_rep_versionado||'.txt'
                        );

        v_hfin_ftp := TO_CHAR(SYSDATE,'HH24:MI:SS');
         END IF;         

        INSERT INTO ge_ra_log_ftp (fec_envio,nom_archivo,det_error,hor_inicio,hor_fin)
        VALUES (sysdate,v_nombre_rep_versionado,v_respuesta,v_hini_ftp,v_hfin_ftp);

    COMMIT;

    EXCEPTION
    WHEN OTHERS THEN

        v_respuesta := NVL(v_respuesta, SUBSTR(SQLERRM,1,4000));

        INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
        VALUES (sysdate, v_nombre_rep_versionado, v_respuesta, v_hini_ftp, v_hfin_ftp);
        COMMIT;

        IF UTL_FILE.IS_OPEN(v_file) THEN
           UTL_FILE.FCLOSE(v_file);
        END IF;
        
            IF v_file_rep_abierto AND UTL_FILE.IS_OPEN(v_file_rep) THEN
            UTL_FILE.FCLOSE(v_file_rep);
            END IF;    

        END;

        BEGIN
            
            SELECT VAL_PARAMETRO
            INTO v_can_dias
            FROM ge_par_dinamicos
            WHERE PARAMETRO = 'PRG_GEN_INV_DURACION';
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error obteniendo PRG_GEN_INV_DURACION: ' || SQLERRM);
            
        END;
            
            
        BEGIN
            
                DELETE FROM ge_ra_log_ftp
                WHERE ROWID IN (
                                SELECT rid
                                FROM (
                                     SELECT ROWID rid,
                                     ROW_NUMBER() OVER (ORDER BY fec_envio DESC, ROWID DESC) rn
                                     FROM ge_ra_log_ftp
                                     WHERE nom_archivo LIKE '%automatico_%'
                                     )
                               WHERE rn > 6 * v_can_dias
                              );
    
                COMMIT;
            
        EXCEPTION
        WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error en Delete ge_ra_log_ftp inventarios: ' || SQLERRM);
         END;
                                  
END PRG_GEN_INVENTARIOS;
/