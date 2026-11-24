CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_PINES (p_nro_lote in bw_ope_claves.nro_lote%type) IS
  v_directorio  varchar2(100);
--  v_archivo     Client_Text_IO.File_Type;
  v_file        UTL_FILE.FILE_TYPE;
  v_line        VARCHAR2(32767);
  v_buffer      VARCHAR2(32767);
  v_eol         CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen      CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline     CONSTANT PLS_INTEGER := 32767;
  v_hini_ftp    ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp    ge_ra_log_ftp.hor_fin%type;
  v_para        VARCHAR2(500);
  v_asunto      VARCHAR2(2000);
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --v_compartido  VARCHAR2(100) := fug_obt_pardinamico('CCO_CHE_CAS_COMPARTIDO',null,null,null,null,null);
  v_compartido  VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  v_mje_mail    VARCHAR2(4000);
  v_respuesta   VARCHAR2(4000);
  v_repositorio VARCHAR2(100) := 'MAIL';
  v_nombre      VARCHAR2(100) := 'IMP_MAS_PINES';
  v_fecha       VARCHAR2(20);
  v_servicios    varchar2(100) := fug_obt_pardinamico('DIR_REP_IMPMASPINES');
  --v_compartido  VARCHAR2(100) := fug_obt_pardinamico('CCO_CHE_CAS_COMPARTIDO',null,null,null,null,null);
  v_grupo        varchar2(100);
  cursor c_dat_claves is
  select rpad('0',18,'0') guia,
         '009' tip_documento,
         to_char(pag_cal.fu_obt_fec_actual(1),'yyyy') ano,
         to_char(pag_cal.fu_obt_fec_actual(1),'mm') mes,
         lpad('2',6,'0') cod_tip_producto,
         ' ' nro_cuenta,
         to_char(pag_cal.fu_obt_fec_actual(1),'yyyymmdd') fecha,
         lpad(a.nro_lote,12,'0') nro_lote,
         ' ' nro_doc,
         ' ' id_grupo,
         ' ' referencia,
         ' ' origen,
         a.cod_persona cliente,
         b.cod_tip_documento,
         b.nro_documento,
         b.nom_completo,
         c.direccion dir_envio,
         d.area||'-'||d.telefono telefono,
         fue_obt_des_ciudad(c.cod_pais,c.cod_ciudad) ciudad,
         fue_obt_des_pais(c.cod_pais) pais
    from bw_ope_claves  a,
         ba_personas    b,
         ba_direcciones c,
         ba_telefonos   d
   where a.tip_clave   = 'A'
     and a.est_clave   = 'A'
     and a.cod_persona = b.cod_persona
     and c.cod_persona = a.cod_persona
     and c.principal   = 'S'
     and d.cod_persona = a.cod_persona
     and d.principal   = 'S'
     and a.nro_lote = p_nro_lote;
BEGIN
  v_file := UTL_FILE.FOPEN(v_repositorio,v_nombre||'.txt','W',32767);
  for arc in c_dat_claves loop
    v_line := arc.guia||
              arc.tip_documento||
              rpad(arc.ano,4,' ')||
              rpad(arc.mes,2,' ')||
              arc.cod_tip_producto||
              rpad(arc.nro_cuenta,10,' ')||
              rpad(arc.fecha,8,' ')||
              arc.nro_lote||
              rpad(arc.nro_doc,20,' ')||
              rpad(arc.id_grupo,4,' ')||
              rpad(arc.referencia,20,' ')||
              rpad(arc.origen,10,' ')||
              rpad(arc.cliente,10,' ')||
              rpad(arc.cod_tip_documento,3,' ')||
              rpad(arc.nro_documento,15,' ')||
              rpad(arc.nom_completo,60,' ')||
              rpad(arc.dir_envio,100,' ')||
              rpad(arc.telefono,15,' ')||
              rpad(arc.ciudad,20,' ')||
              rpad(arc.pais,2,' ')
              ;

    -- Acumulamos todas las lineas posibles antes de escribir en el archivo
    IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
      v_buffer := v_buffer || v_eol || v_line;
    ELSE
      IF v_buffer IS NOT NULL THEN
        --Escribes la linea en el archivo
        UTL_FILE.PUT_LINE(v_file, v_buffer);
      END IF;
      v_buffer := v_line;
    END IF;
    EXIT WHEN c_dat_claves%NOTFOUND;
  end loop;
  --Escribes la linea en el archivo
  UTL_FILE.PUT_LINE(v_file, v_buffer);

--  pl_arc_cerrar(v_archivo);

  --Cerrar el handler al fichero
        UTL_FILE.FCLOSE(v_file);
        COMMIT;

        -- Enviamos el archivo por FTP y comunicamos por mail
        v_fecha := to_char(pag_cal.fu_obt_fec_actual(4),'YYYYMMDD')||'_'||to_char(sysdate,'hh24mmss');

        v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

        v_respuesta := FUG_ENV_FTP(v_repositorio,v_nombre||'.txt',v_servicios,v_nombre||'_'||v_fecha||'.txt');

        v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

        IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
            -- Obtenemos los direcciones de correo para quien o a quienes va el mail
            v_para := FUG_OBT_PARDINAMICO('ARE_SER_MAIL');

            -- Damos valor a los demas datos
            v_asunto := 'Grupo de Impresión masiva de Pines de fecha '||to_char(pag_cal.fu_obt_fec_actual(1),'DD/MM/YYYY')||'.';
            v_mje_mail := 'El archivo con los datos se encuentra en la siguiente dirección: '||v_compartido||v_servicios||'

            Nombre del Archivo: '||v_nombre||'_'||v_fecha||'.txt'||chr(10)||
            'Grupo enviado: '||v_grupo;

             -- Enviamos el mail
              PRG_ENV_MAIL(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                            v_para,
                            v_asunto,
                            v_mje_mail
                           );

        ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP

            -- Insertamos el error del envio al directorio compartido
            INSERT INTO ge_ra_log_ftp
             (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_nombre||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
            COMMIT;

             -- Obtenemos los direcciones de correo para quien o a quienes va el mail
            v_para := FUG_OBT_PARDINAMICO('ARE_SER_MAIL');

            -- Damos valor a los demas datos
            v_asunto := 'Error archivo de Grupo de Impresión masiva de Pines de fecha '||to_char(pag_cal.fu_obt_fec_actual(4),'DD/MM/YYYY')||'.';
            v_mje_mail := 'Error al enviar el archivo a la carpeta compartida '||/*v_compartido||*/v_servicios||'

            Nombre del Archivo: '||v_nombre||'_'||v_fecha||'.txt'||chr(10)||
            'Grupo enviado: '||v_grupo||'

            Reenviar este mail a las personas que corresponden para su verificación.

            Error: '||v_respuesta||'.

            Para mas información verificar la tabla GE_RA_LOG_FTP';

           -- Enviamos el mail
            PRG_ENV_MAIL(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                          v_para,
                          v_asunto,
                          v_mje_mail
                         );
        END IF;
END;
/

