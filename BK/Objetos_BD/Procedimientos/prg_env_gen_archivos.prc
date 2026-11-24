CREATE OR REPLACE PROCEDURE IT.PRG_ENV_GEN_ARCHIVOS ( p_archivo IN VARCHAR2,   --tipo de archivo a enviar
                                                   p_accion IN VARCHAR2,    --tipo de accion a realizar
                                                   p_lote IN VARCHAR2,      --numero de lote de cartera
                                                   p_usupro IN VARCHAR2,    --valor del campo 'Usuario Bancar'
                                                   p_desc_mov IN VARCHAR2,  --valor del campo 'Descripcion Movimiento'
                                                   p_procesado OUT VARCHAR2 --control de si se proceso correctamente
                                                  ) IS
/*
P_ARCHIVO:
  CS: Cargos Suspendidos.
  ME: Movimientos Especiales - Cancelación de Saldos.
  NI: Código de No generar intereses.
  BC: Código de Baja de Ctas.
P_ACCION:
  E: si se Envía a bancard
  G: si se Genera en un directorio local
*/
  v_ws_respuesta   VARCHAR2(1000) := NULL;
  v_arc_car_susp   VARCHAR2(100) := fug_obt_pardinamico('NOM_ARC_CARGOS_SUSPENDIDOS');
  v_arc_mov_esp     VARCHAR2(100) := fug_obt_pardinamico('NOM_ARC_MOV_ESPECIALES');
  v_arc_cod_seis   VARCHAR2(100) := fug_obt_pardinamico('NOM_ARC_COD_6');
  v_arc_cod_baja   VARCHAR2(100) := fug_obt_pardinamico('NOM_ARC_COD_BAJA');

  -- Para envio FTP
  v_file           UTL_FILE.FILE_TYPE;
  v_line           VARCHAR2(32767);
  v_buffer         VARCHAR2(32767);
  v_lines          PLS_INTEGER := 0;
  v_eol            CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen         CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline        CONSTANT PLS_INTEGER := 32767;
  v_respuesta      VARCHAR2(4000);

  -- Generar datos en el servidor
  v_ip             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  v_port           VARCHAR2(100) := '21';
  v_user           VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  v_pass           VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_repository     VARCHAR2(100) := fug_obt_pardinamico('DIR_AUT_BANCARD');
  v_destino         VARCHAR2(100) := fug_obt_pardinamico('DIR_REP_LOCAL');
  b_ip             VARCHAR2(100) := fug_obt_pardinamico('DIR_FTP_ASCII_BANCARD');
  b_user           VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_ASCII_BANCARD');
  b_pass           VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_ASCII_BANCARD');

  CURSOR c_car_suspendido
     IS select '48'||
               rpad(a.nro_cuenta, 9)||
               rpad(p_usupro, 10)||
               '       '||
               to_char(sysdate, 'yyyymmdd') as line
          from ge_sal_inv_vta_cartera_his a
         where a.cod_modulo  = 5
           and a.estado      = 'C'
           and a.ref_lote    = nvl(p_lote, a.ref_lote)
           and a.dia_atrasos > 60;

  CURSOR c_mov_especiales
    IS --SAL_FACTURAR
        select rpad(to_char(a.nro_tarjeta), 19)||';'||
               to_char(sysdate, 'yyyymmdd')||';'||
               rpad(p_desc_mov,40)||';'||
               '600'||';'||
               rpad(c.sal_facturar,15)||';'||
               '33 '||';'||
               '1  '||';'||
               'C'||';'||
               'S'||';'||
               rpad(user,10)||';'||
               '?'||';'||
               '   '||';'||
               'N' as line
          from ge_sal_inv_vta_cartera_his a, ta_tarjetas b, ta_cta_tarjetas c
         where a.cod_modulo   = 5
           and a.estado       = 'C'
           and a.ref_lote     = nvl(p_lote, a.ref_lote)
           and a.nro_cuenta   = b.nro_cuenta
           and a.nro_tarjeta  = b.nro_tarjeta
           and b.nro_cuenta   = c.nro_cuenta
           and c.sal_facturar > 0
        UNION ALL
        -- SAL_FACTURADO
        select rpad(to_char(a.nro_tarjeta), 19)||';'||
               to_char(sysdate, 'yyyymmdd')||';'||
               rpad(p_desc_mov,40)||';'||
               '600'||';'||
               rpad(c.sal_facturado,15)||';'||
               '33 '||';'||
               '2  '||';'||
               'C'||';'||
               'S'||';'||
               rpad(user,10)||';'||
               '?'||';'||
               '   '||';'||
               'N' as line
          from ge_sal_inv_vta_cartera_his a, ta_tarjetas b, ta_cta_tarjetas c
         where a.cod_modulo   = 5
           and a.estado       = 'C'
           and a.ref_lote     = nvl(p_lote, a.ref_lote)
           and a.nro_cuenta   = b.nro_cuenta
           and a.nro_tarjeta  = b.nro_tarjeta
           and b.nro_cuenta   = c.nro_cuenta
           and c.sal_facturado > 0
        UNION ALL
        -- SAL_FINANCIADO
        select rpad(to_char(a.nro_tarjeta), 19)||';'||
               to_char(sysdate, 'yyyymmdd')||';'||
               rpad(p_desc_mov,40)||';'||
               '600'||';'||
               rpad(c.Sal_Financiado,15)||';'||
               '33 '||';'||
               '3  '||';'||
               'C'||';'||
               'S'||';'||
               rpad(user,10)||';'||
               '?'||';'||
               '   '||';'||
               'N' as line
          from ge_sal_inv_vta_cartera_his a, ta_tarjetas b, ta_cta_tarjetas c
         where a.cod_modulo   = 5
           and a.estado       = 'C'
           and a.ref_lote     = nvl(p_lote, a.ref_lote)
           and a.nro_cuenta   = b.nro_cuenta
           and a.nro_tarjeta  = b.nro_tarjeta
           and b.nro_cuenta   = c.nro_cuenta
           and c.Sal_Financiado > 0;

  CURSOR c_no_gen_intereses
    IS select ';;;;;;;;;;;;;;;;;;;;'||a.nro_cuenta||';;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;6;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'||user||';' as line
         from ge_sal_inv_vta_cartera_his a where a.cod_modulo = 5 and a.estado = 'C' and a.ref_lote  = nvl(p_lote, a.ref_lote);

  CURSOR c_cod_baja
    IS select ';;;;;;;;;;;;;;;;;;;;'||a.nro_cuenta||';;;;;;;;;;;;;;;;;;;;;;;;;;B;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'||user||';' as line
         from ge_sal_inv_vta_cartera_his a where a.cod_modulo = 5 and a.estado = 'C' and a.ref_lote  = nvl(p_lote, a.ref_lote);

BEGIN
  p_procesado := 'S';
---------------------------------------------------------------------------------------------------
    if p_archivo = 'CS' then
---------------------------------------------------------------------------------------------------
      -- Abrir archivo
       v_file := UTL_FILE.FOPEN(v_repository,v_arc_car_susp||'.txt','W');

      FOR reg IN c_car_suspendido LOOP
        --Generar la linea, agregando si es necesario un delimitador de campo (tabulador chr(9), salto de linea chr(10), retorno de carro chr(13))
        v_line := to_char(REG.LINE)||chr(13);

        IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
            v_buffer := v_buffer || v_eol || v_line;
        ELSE
            IF v_buffer IS NOT NULL THEN
                --Escribe la linea en el fichero
                UTL_FILE.PUT_LINE(v_file, v_buffer);
            END IF;
            v_buffer := v_line;
        END IF;

        v_lines := v_lines + 1;

        EXIT WHEN c_car_suspendido%NOTFOUND;
      END LOOP;

      --Escribes la linea en el fichero
      UTL_FILE.PUT_LINE(v_file, v_buffer);

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);

      IF p_accion = 'G' THEN-- Enviar a Ramail
         v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,   --> ip ramail
                                                 v_port, --> puerto ramail (21)
                                                 v_user, --> user ramail
                                                 v_pass, --> pass ramail
                                                 v_repository,
                                                 v_arc_car_susp||'.txt',
                                                 v_destino||v_arc_car_susp||'.txt');
      ELSIF p_accion = 'E' THEN-- Enviar a Bancard
          v_respuesta := pa_file_ftp.fu_put_ascii(b_ip,   --ip bancard
                                                 v_port, --puerto bancard
                                                 b_user, --usuario bancard
                                                 b_pass, --password bancard
                                                 v_repository, --ubicacion del archivo
                                                 v_arc_car_susp||'.txt', --archivo a envíar
                                                 '/'||v_arc_car_susp); --ubicacion y nombre destino
      END IF;

      --CONTROL DE RESPUESTA
      IF v_respuesta <> 'OK' THEN
        p_procesado := 'N';
        If v_respuesta like '%No such file or directory%' Then
          raise_application_error(-20000, 'Archivo '||v_arc_car_susp||'.txt no generado');
        Else
          raise_application_error(-20001, 'Error al descargar el archivo '||v_arc_car_susp||'.txt'||' => '||v_respuesta);
        End If;
      ELSIF v_respuesta = 'OK' and p_accion = 'G' THEN
        dbms_output.put_line('Archivo '||v_arc_car_susp||'.txt fue generado correctamente');
      ELSIF v_respuesta = 'OK' and p_accion = 'E' THEN
        dbms_output.put_line('Archivo '||v_arc_car_susp||' fue enviado correctamente');
      END IF;
---------------------------------------------------------------------------------------------------
    elsif p_archivo = 'ME' then
---------------------------------------------------------------------------------------------------
      -- Abrir archivo
       v_file := UTL_FILE.FOPEN(v_repository,v_arc_mov_esp||'.txt','W');

      FOR reg IN c_mov_especiales LOOP
        --Generar la linea, agregando si es necesario un delimitador de campo (tabulador chr(9), salto de linea chr(10), retorno de carro chr(13))
        v_line := to_char(REG.LINE)||chr(13);

        IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
            v_buffer := v_buffer || v_eol || v_line;
        ELSE
            IF v_buffer IS NOT NULL THEN
                --Escribe la linea en el fichero
                UTL_FILE.PUT_LINE(v_file, v_buffer);
            END IF;
            v_buffer := v_line;
        END IF;

        v_lines := v_lines + 1;

        EXIT WHEN c_mov_especiales%NOTFOUND;
      END LOOP;

      --Escribes la linea en el fichero
      UTL_FILE.PUT_LINE(v_file, v_buffer);

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);

      IF p_accion = 'G' THEN-- Enviar a Ramail
         v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,   --> ip ramail
                                                 v_port, --> puerto ramail (21)
                                                 v_user, --> user ramail
                                                  v_pass, --> pass ramail
                                                 v_repository,
                                                 v_arc_mov_esp||'.txt',
                                                 v_destino||v_arc_mov_esp||'.txt');
      ELSIF p_accion = 'E' THEN-- Enviar a Bancard
         v_respuesta := pa_file_ftp.fu_put_ascii(b_ip,
                                                 v_port,
                                                 b_user,
                                                 b_pass,
                                                 v_repository,
                                                 v_arc_mov_esp||'.txt',
                                                 '/trndatoent/v07/'||v_arc_mov_esp);
      END IF;

      --CONTROL DE RESPUESTA
      IF v_respuesta <> 'OK' THEN
        p_procesado := 'N';
        If v_respuesta like '%No such file or directory%' Then
          raise_application_error(-20000, 'Archivo '||v_arc_mov_esp||'.txt no generado');
        Else
          raise_application_error(-20001, 'Error al descargar el archivo '||v_arc_mov_esp||'.txt'||' => '||v_respuesta);
        End If;
      ELSIF v_respuesta = 'OK' and p_accion = 'G' THEN
        dbms_output.put_line('Archivo '||v_arc_mov_esp||'.txt fue generado correctamente');
      ELSIF v_respuesta = 'OK' and p_accion = 'E' THEN
        dbms_output.put_line('Archivo '||v_arc_mov_esp||' fue enviado correctamente');
      END IF;
---------------------------------------------------------------------------------------------------
    elsif p_archivo = 'NI' then
---------------------------------------------------------------------------------------------------
      -- Abrir archivo
       v_file := UTL_FILE.FOPEN(v_repository,v_arc_cod_seis||'.txt','W');

      FOR reg IN c_no_gen_intereses LOOP
        --Generar la linea, agregando si es necesario un delimitador de campo (tabulador chr(9), salto de linea chr(10), retorno de carro chr(13))
        v_line := to_char(REG.LINE)||chr(13);

        IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
            v_buffer := v_buffer || v_eol || v_line;
        ELSE
            IF v_buffer IS NOT NULL THEN
                --Escribe la linea en el fichero
                UTL_FILE.PUT_LINE(v_file, v_buffer);
            END IF;
            v_buffer := v_line;
        END IF;

        v_lines := v_lines + 1;

        EXIT WHEN c_no_gen_intereses%NOTFOUND;
      END LOOP;

      --Escribes la linea en el fichero
      UTL_FILE.PUT_LINE(v_file, v_buffer);

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);

      IF p_accion = 'G' THEN-- Enviar a Ramail
         v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,   --> ip ramail
                                                  v_port, --> puerto ramail (21)
                                                 v_user, --> user ramail
                                                 v_pass, --> pass ramail
                                                  v_repository,
                                                 v_arc_cod_seis||'.txt',
                                                 v_destino||v_arc_cod_seis||'.txt');
      ELSIF p_accion = 'E' THEN-- Enviar a Bancard
         v_ws_respuesta := FUA_WSI_ENV_ARC_VENCARTERA('CODIGOSEIS', p_lote);
         dbms_output.put_line('Respuesta Bancard: '||v_ws_respuesta);
      END IF;

      --CONTROL DE RESPUESTA
      IF v_respuesta <> 'OK' THEN
        p_procesado := 'N';
        If v_respuesta like '%No such file or directory%' Then
          raise_application_error(-20000,'Archivo '||v_arc_cod_seis||'.txt no generado');
        Else
          raise_application_error(-20000,'Error al descargar el archivo '||v_arc_cod_seis||'.txt'||' => '||v_respuesta);
        End If;
      ELSIF v_respuesta = 'OK' and p_accion = 'G' THEN
        dbms_output.put_line('Archivo '||v_arc_cod_seis||'.txt generado correctamente');
      END IF;
---------------------------------------------------------------------------------------------------
    elsif p_archivo = 'BC' then
---------------------------------------------------------------------------------------------------
      -- Abrir archivo
       v_file := UTL_FILE.FOPEN(v_repository,v_arc_cod_baja||'.txt','W');

      FOR reg IN c_cod_baja LOOP
        --Generar la linea, agregando si es necesario un delimitador de campo (tabulador chr(9), salto de linea chr(10), retorno de carro chr(13))
        v_line := to_char(REG.LINE)||chr(13);

        IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
            v_buffer := v_buffer || v_eol || v_line;
        ELSE
            IF v_buffer IS NOT NULL THEN
                --Escribe la linea en el fichero
                UTL_FILE.PUT_LINE(v_file, v_buffer);
            END IF;
            v_buffer := v_line;
        END IF;

        v_lines := v_lines + 1;

        EXIT WHEN c_cod_baja%NOTFOUND;
      END LOOP;

      --Escribes la linea en el fichero
      UTL_FILE.PUT_LINE(v_file, v_buffer);

      --Cerrar el handler al fichero
      UTL_FILE.FCLOSE(v_file);

      IF p_accion = 'G' THEN-- Enviar a Ramail
         v_respuesta := pa_file_ftp.fu_put_ascii(v_ip,   --> ip ramail
                                                 v_port, --> puerto ramail (21)
                                                 v_user, --> user ramail
                                                 v_pass, --> pass ramail
                                                 v_repository,
                                                 v_arc_cod_baja||'.txt',
                                                 v_destino||v_arc_cod_baja||'.txt');
      ELSIF p_accion = 'E' THEN-- Enviar a Bancard
        v_ws_respuesta := FUA_WSI_ENV_ARC_VENCARTERA('CODIGOBAJA', p_lote);
        dbms_output.put_line('Respuesta Bancard: '||v_ws_respuesta);
      END IF;

      --CONTROL DE RESPUESTA
      IF v_respuesta <> 'OK' THEN
        p_procesado := 'N';
        If v_respuesta like '%No such file or directory%' Then
          raise_application_error(-20000,'Archivo '||v_arc_cod_baja||'.txt no generado');
        Else
          raise_application_error(-20000,'Error al descargar el archivo '||v_arc_cod_baja||'.txt'||' => '||v_respuesta);
        End If;
      ELSIF v_respuesta = 'OK' and p_accion = 'G' THEN
        dbms_output.put_line('Archivo '||v_arc_cod_baja||'.txt generado correctamente');
      END IF;
    end if;
END;
/

