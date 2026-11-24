CREATE OR REPLACE PACKAGE BODY IT.PAC_MIG IS
  -- Paquete utilizado para integraci¿n contable ITGF y BANTOTAL
  -- Fecha: 18/06/2021
  -- Autor: Gabriel Capo
  ---------------------------------------------------------------------------

function FU_OBT_RUB_PARSEADO(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE,
                                                   p_tipo      varchar2)
  return varchar2 is
  -- Se foramtea el rubro de tal manera que el plazo se repite en la 9 posici¿n del rubro

begin
  if p_cod_rubro is not null then
    if trim(upper(p_tipo)) is not null then
      case
        when trim(upper(p_tipo)) = 'CAPITULO' then
          return substr(p_cod_rubro, 1, 1);
        when trim(upper(p_tipo)) = 'BCP1A' then
          return substr(p_cod_rubro, 1, 2);
        when trim(upper(p_tipo)) = 'PLAZO' then
          return substr(p_cod_rubro, 3, 1);
        when trim(upper(p_tipo)) = 'BCP1B' then ---
          return substr(p_cod_rubro, 4, 2);
        when trim(upper(p_tipo)) = 'BCP2A' then ---
          return substr(p_cod_rubro, 6, 3);
        when trim(upper(p_tipo)) = 'BCP2B' then ---
          return substr(p_cod_rubro, 9, 2);
        when trim(upper(p_tipo)) = 'SEC' then ---
          return substr(p_cod_rubro, 11, 3);
        when trim(upper(p_tipo)) = 'MONEDA' then ---
          return substr(p_cod_rubro, 14, 2);
        when trim(upper(p_tipo)) = 'BCP2AB' then ---
          return substr(p_cod_rubro, 6, 3)||substr(p_cod_rubro, 9, 2);
        else
          return null;
      end case;
    else
      return null;
    end if;
  else
    return null;
  end if;
  EXCEPTION
  when others then
    return null;

end;

function FU_OBT_RUB_BTW_MON(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE)
  return varchar2 is
  -- Se foramtea el rubro de tal manera que el plazo se repite en la 9 posici¿n del rubro
  v_capitulo    varchar2(1);
  v_moneda      varchar2(3);
begin
  if p_cod_rubro is not null then
    v_capitulo := FU_OBT_RUB_PARSEADO(P_COD_RUBRO, 'CAPITULO');
    v_moneda   := FU_OBT_RUB_PARSEADO(P_COD_RUBRO, 'MONEDA');
    case
      when v_capitulo = '1' and v_moneda = '03' then
        return '9';
      when v_capitulo = '1' and v_moneda = '05' then
        return '1';
      when v_capitulo = '1' and v_moneda = '07' then
        return '5';
      when v_capitulo = '1' and v_moneda = '10' then
        return '2';
      when v_capitulo = '1' and v_moneda = '14' then
        return '15';
      when v_capitulo = '1' and v_moneda = '15' then
        return '10';
      when v_capitulo = '1' and v_moneda = '17' then
        return '62';
      when v_capitulo = '1' and v_moneda = '28' then
        return '3';
      when v_capitulo = '1' and v_moneda = '99' then
        return '6900';
      when v_capitulo = '2' and v_moneda = '99' then
        return '6900';
      when v_capitulo = '2' and v_moneda = '05' then
        return '1';
      when v_capitulo = '2' and v_moneda = '17' then
        return '62';
      when v_capitulo = '2' and v_moneda = '07' then
        return '5';
      when v_capitulo = '2' and v_moneda = '10' then
        return '2';
      when v_capitulo = '2' and v_moneda = '15' then
        return '10';
      when v_capitulo = '2' and v_moneda = '03' then
        return '9';
      when v_capitulo = '2' and v_moneda = '14' then
        return '15';
      when v_capitulo = '2' and v_moneda = '28' then
        return '3';
      when v_capitulo = '3' and v_moneda = '99' then
        return '6900';
      when v_capitulo = '4' and v_moneda = '99' then
        return '6900';
      when v_capitulo = '4' and v_moneda = '05' then
        return '1';
      when v_capitulo = '4' and v_moneda = '17' then
        return '62';
      when v_capitulo = '4' and v_moneda = '14' then
        return '15';
      when v_capitulo = '4' and v_moneda = '07' then
        return '5';
      when v_capitulo = '4' and v_moneda = '10' then
        return '2';
      when v_capitulo = '5' and v_moneda = '99' then
        return '6900';
      when v_capitulo = '5' and v_moneda = '05' then
        return '1';
      when v_capitulo = '5' and v_moneda = '17' then
        return '62';
      when v_capitulo = '5' and v_moneda = '14' then
        return '15';
      when v_capitulo = '5' and v_moneda = '07' then
        return '5';
      when v_capitulo = '5' and v_moneda = '10' then
        return '2';
      when v_capitulo = '5' and v_moneda = '03' then
        return '9';
      when v_capitulo = '5' and v_moneda = '15' then
        return '10';
      when v_capitulo = '5' and v_moneda = '28' then
        return '3';
      when v_capitulo = '6' and v_moneda = '99' then
        return '6900';
      when v_capitulo = '6' and v_moneda = '05' then
        return '6900';
      when v_capitulo = '6' and v_moneda = '17' then
        return '6900';
      when v_capitulo = '6' and v_moneda = '98' then
        return '6900';
      when v_capitulo = '7' and v_moneda = '99' then
        return '6900';
      when v_capitulo = '7' and v_moneda = '05' then
        return '6900';
      when v_capitulo = '7' and v_moneda = '17' then
        return '6900';
      when v_capitulo = '7' and v_moneda = '98' then
        return '6900';
      else
        return null;
    end case;
  else
    return null;
  end if;
EXCEPTION
  when others then
    return null;
end;

function FU_OBT_RUB_BTW_INT(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE)
  return varchar2 is
  -- Se foramtea el rubro de tal manera que el plazo se repite en la 9 posici¿n del rubro
  v_capitulo    varchar2(1);
  v_moneda      varchar2(3);
begin
  if p_cod_rubro is not null then
     v_capitulo := FU_OBT_RUB_PARSEADO(P_COD_RUBRO, 'CAPITULO');
     v_moneda   := FU_OBT_RUB_PARSEADO(P_COD_RUBRO, 'MONEDA');
      case
         when v_capitulo between 1 and 5 then
           return '988';
         when v_capitulo = 6 and v_moneda = '99' then
           return '988';
         when v_capitulo = 7 and v_moneda = '99' then
           return '988';
         when v_capitulo > 5 and v_moneda <> '99' then
           return '987';
        else
          return null;
      end case;
    else
      return null;
    end if;
  EXCEPTION
  when others then
    return null;
end;

function FU_OBT_RUB_BANTOTAL(P_COD_RUBRO CB_RUBROS.COD_RUBRO%TYPE)
  return varchar2 is
  -- Se foramtea el rubro de tal manera que el plazo se repite en la 9 posici¿n del rubro
  v_btw_rub_int varchar2(3);
  v_plazo       varchar2(3);
  v_BCP2A      varchar2(3);
  v_BCP2B      varchar2(3);
  v_rub_btw    varchar2(10);
begin
  if p_cod_rubro is not null then
     v_plazo := FU_OBT_RUB_PARSEADO(P_COD_RUBRO, 'PLAZO');
     v_BCP2A := FU_OBT_RUB_PARSEADO(P_COD_RUBRO, 'BCP2A');     --BCP2A
     v_BCP2B := FU_OBT_RUB_PARSEADO(P_COD_RUBRO, 'BCP2B');     --BCP2B
     v_btw_rub_int := FU_OBT_RUB_BTW_INT(P_COD_RUBRO);
     v_rub_btw := v_BCP2A||v_plazo||v_BCP2B||v_btw_rub_int;
     return v_rub_btw;
  end if;
EXCEPTION
  when others then
    return null;

end;

-------------------------------------------------------------------------------------------------------------------------------------
-- Balance Rubricado
PROCEDURE PR_ARC_BALRUB_BT(p_tipo varchar2 default 'H')
IS

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);
  v_name             VARCHAR2(128) := 'BALRUB_ITGF_V0'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_count            number := 0;
  v_cabecera         number := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha            GE_CALENDARIOS.FEC_ACTUAL%TYPE;
  v_fecha_arc        VARCHAR2(8);
  v_hora             VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;

CURSOR cu_rub_itgf(p_fecha ge_calendarios.fec_actual%type) IS
SELECT substr(r.cod_rubro,1,2)||substr(r.cod_rubro,3,1)||substr(r.cod_rubro,4,2) as Codigo,
       substr(r.cod_rubro,6,3)||substr(r.cod_rubro,3,1)||substr(r.cod_rubro,9,2) as Cuenta,
       NVL(C.SAL_MON_LOC_ANT, 0)*-1 SAL_ANTERIOR,
       NVL(C.DEB_MON_LOCAL, 0) DEBITO,
       NVL(C.CRE_MON_LOCAL, 0) CREDITO,
       NVL(+NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) -
       NVL(C.CRE_MON_LOCAL, 0),0)*-1 as sal_actual
  FROM BA_MONEDAS B, CB_SAL_CONSOLIDADOS_DIA C, CB_RUBROS R
 WHERE R.COD_RUBRO = C.COD_RUBRO
   AND B.COD_MONEDA = R.COD_MONEDA
   AND C.FECHA = p_fecha
   and (abs(NVL(C.SAL_MON_LOC_ANT, 0)) <> 0 OR NVL(C.DEB_MON_LOCAL, 0) <> 0 OR
       NVL(C.CRE_MON_LOCAL, 0) <> 0)
   and not exists (select 1
          from cb_rubros t
         where substr(t.cod_rubro, 9, 2) = '01'
           and nivel = 5
           and r.cod_rubro = t.cod_rub_padre)
   and r.nivel = '5'
 order by to_number(substr(R.cod_rubro, 1, 2) || substr(R.cod_rubro, 4) ||
                    substr(R.cod_rubro, 3, 1));
  v_fec_hab_ant varchar2(10);
BEGIN
  -- Obtenemos la fecha del sistema de cierre
  v_fecha_arc := to_char(pag_cal.fu_obt_fec_anterior(2),'YYYYMMDD');
  v_fec_hab_ant := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(to_date(v_fecha_arc,'YYYYMMDD'), 1),'YYYYMMDD');
--  v_fecha_arc := '20211014';
  v_fecha := to_char(pag_cal.fu_obt_fec_anterior(2));
--  V_FECHA := '14/OCT/2021';
  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
   v_file := UTL_FILE.FOPEN(pac_mig.g_repository,v_name||'.csv','W',32767);

-- Definir una linea en blanco para separar los datos del titulo de los campos
FOR REC IN cu_rub_itgf(v_fecha) LOOP
  v_cabecera := v_cabecera + 1;
  EXIT WHEN cu_rub_itgf%NOTFOUND;
END LOOP;
--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_rub_itgf(v_fecha) LOOP

  v_count := v_count + 1;

  if v_count = 1 then
   v_linetit := 'CABECERA'||CHR(9)||v_fecha_arc||CHR(9)||v_fec_hab_ant||CHR(9)||CHR(9)||CHR(9)||CHR(9)||v_cabecera;
   utl_file.put_line(v_file,v_linetit);
     -- Colocar el titulo a los campos
   v_linetit := 'CODIGO'||CHR(9)||'CUENTA'||CHR(9)||'SAL_ANTERIOR'||CHR(9)||'DEBITO'||CHR(9)||'CREDITO'||CHR(9)||'SAL_ACTUAL'||CHR(9)||'SECUENCIA';
   utl_file.put_line(v_file,v_linetit);
  end if;

  v_line := to_char(rec.codigo)||chr(9)||to_char(rec.cuenta)||chr(9)||to_char(rec.sal_anterior,'999999999999999999999D00')||chr(9)||
             to_char(rec.debito,'999999999999999999999D00')||chr(9)||to_char(rec.credito,'999999999999999999999D00')||chr(9)||
             to_char(rec.sal_actual,'999999999999999999999D00')||chr(9)||v_count;

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

  EXIT WHEN cu_rub_itgf%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  if p_tipo = 'H' then
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                            pac_mig.g_pass, pac_mig.g_repository,
                                            v_name||'.csv', g_contabilidad||v_fecha_arc||'_'||v_name||'_'||v_hora||'.xls');
  else
        -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                            pac_mig.g_pass, pac_mig.g_repository,
                                            v_name||'.csv', g_contabilidad||v_fecha_arc||'_'||v_name||'.xls');
  end if;

  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

/*  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pac_mig.FU_OBT_VALOR_PAR('RA','REPORTES','SALDO_IMPUTABLE');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Abierto Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente direcci¿n: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pac_mig.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
      EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pac_mig.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Abierto Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas informaci¿n verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pac_mig.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
      EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  END IF;*/


COMMIT;
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
END PR_ARC_BALRUB_BT;
-------------------------------------------------------------------------------------------------------------------------------------

-- Balance Rubricado
PROCEDURE PR_XLSX_BALRUB(p_tipo varchar2 default 'H')
IS
  v_file             UTL_FILE.FILE_TYPE;
  v_name             VARCHAR2(128) := 'BALRUB_ITGF_V0'; -- nombre del archivo

  -- Variables de fechas
  v_fecha_arc        VARCHAR2(8);
  v_fecha            GE_CALENDARIOS.FEC_ACTUAL%TYPE;
  v_fec_hab_ant      varchar2(10);
  v_hora             VARCHAR2(8);

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
  v_can_registro     number;

BEGIN
  v_fecha := to_char(pag_cal.fu_obt_fec_anterior(2));
  v_hora := to_char(sysdate,'hh24miss');
  
  --v_file := UTL_FILE.FOPEN(pac_mig.g_repository,v_name||'.xls','W',32767);
  -- Abrir archivo
  begin
    select count(*) into v_can_registro from bv_bal_rub_bt;
  exception
    when others then
      v_can_registro := 0;
  end;
  ---
  if p_tipo = 'H' then
     v_fecha_arc := to_char(pag_cal.fu_obt_fec_anterior(2),'YYYYMMDD');
     v_fec_hab_ant := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(to_date(v_fecha_arc,'YYYYMMDD'), 1),'YYYYMMDD');
     as_xlsx.query2sheet_balrub ( 'select codigo, cuenta, ' ||
                                  'sal_anterior, debito, credito, sal_actual, ' ||
                                  'rownum secuencia ' ||
                                  'from bv_bal_rub_his order by rub_bt',
                                   true, v_fecha_arc, v_fec_hab_ant, v_can_registro );
  else
     v_fecha_arc := to_char(pag_cal.FU_OBT_FEC_ACTUAL(2),'YYYYMMDD');
     v_fec_hab_ant := to_char(pag_cal.FU_OBT_FEC_ANT_HAB(to_date(v_fecha_arc,'YYYYMMDD'), 1),'YYYYMMDD');
     as_xlsx.query2sheet_balrub ( 'select codigo, cuenta, ' ||
                                  'sal_anterior, debito, credito, sal_actual, ' ||
                                  'rownum secuencia ' ||
                                  'from bv_bal_rub_bt order by rub_bt',
                                   true, v_fecha_arc, v_fec_hab_ant, v_can_registro );
  end if;
  as_xlsx.save( pac_mig.g_repository, v_name||'.xlsx');
  ---
  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  if p_tipo = 'H' then
     -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
     v_respuesta := pa_file_ftp.fu_put_binary(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                              pac_mig.g_pass, pac_mig.g_repository,
                                              v_name||'.xlsx', g_contabilidad||v_fecha_arc||'_'||v_name||'.xlsx');
  else
     -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
     v_respuesta := pa_file_ftp.fu_put_binary(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                              pac_mig.g_pass, pac_mig.g_repository,
                                              v_name||'.xlsx', g_contabilidad||v_fecha_arc||'_'||v_name||'_'||v_hora||'.xlsx');

  end if;
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  INSERT INTO ge_ra_log_ftp
  (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
  VALUES
  (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.xlsx', v_respuesta, v_hini_ftp, v_hfin_ftp);
  COMMIT;
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
END PR_XLSX_BALRUB;

-------------------------------------------------------------------------------------------------------------------------------------
-- Balance Rubricado
PROCEDURE PR_ARC_BAL_BT_CSV(p_tipo varchar2 default 'H')
IS


  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_linetit          VARCHAR2(2000);
  v_buffer           VARCHAR2(32767);

  v_name             VARCHAR2(128) := 'BALANCE_ITGF_V0'; -- nombre del archivo
  v_lines            PLS_INTEGER := 0;
  v_count            number := 0;
  v_cabecera         number := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;

  -- Variables de fechas
  v_fecha_arc        VARCHAR2(8);
  v_fecha            GE_CALENDARIOS.FEC_ACTUAL%TYPE;
  v_hora             VARCHAR2(8);

  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             VARCHAR2(500);
  v_asunto           VARCHAR2(2000);
  v_mje_mail         VARCHAR2(4000);
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;

CURSOR cu_rub(P_FECHA GE_CALENDARIOS.FEC_ACTUAL%TYPE) IS
    --BALANCE ITGF A BTW CONSOLIDADO
select xx.rub_btw as Cuenta,
       'Rubro ITGF' as Descripcion,
       case
         when xx.itgf_mon = 'GS' then
              'PYG'
          else xx.itgf_mon
            end moneda,
       case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         /*when xx.btw_moneda = '1' then
          sum(xx.saldo_me)
         when xx.btw_moneda = '62' then
          sum(xx.saldo_me)*/
         else
          xx.saldo_me
       end saldo,
       case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         /*when xx.btw_moneda = '1' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         when xx.btw_moneda = '62' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)*/
         else
           sum(xx.acum_cre_ml - xx.acum_deb_ml)
       end Saldo_MN,
       case
         when xx.btw_moneda = '6900' then
          round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', P_FECHA),2)
         when xx.btw_moneda = '1' then
          sum(xx.saldo_me)
         --when xx.btw_moneda = '62' then
         else
          round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', P_FECHA),2)
         --else
          --0
       end equ_dolares
  from (select '0' || substr(k.cod_rub_padre, 1, 5) bcp1,
               FU_OBT_RUB_BTW_INT(k.cod_rubro) as rub_int_btw,
               k.cod_rub_externo as rub_btw,
               pag_mig.FU_OBT_COD_BANTOTAL(k.cod_moneda,'BA_MONEDAS') as btw_moneda,
               --k.cod_moneda as itgf_mon,
               decode(substr(k.cod_rubro, 1, 1), 6, 'PYG', 7, 'PYG', k.cod_moneda) as itgf_mon,
               k.Descripcion Descripcion,
               (nvl(s.sal_mon_rub_ant, 0) + nvl(s.deb_mon_rubro, 0) -
               nvl(s.cre_mon_rubro, 0)) * -1 saldo_me,
               case
                 when (nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0)) > 0 then
                  abs(nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0))
                 else
                  0
               end acum_deb_ml,
               case
                 when (nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0)) < 0 then
                  abs(nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) -
                      nvl(s.cre_mon_local, 0))
                 else
                  0
               end acum_cre_ml,
               k.cod_rubro,
               k.cod_rub_padre,
               k.cod_moneda,
               s.fecha,
               'Balance Abierto' Tip_Balance
          from cb_sal_consolidados_dia s, cb_rubros k
         where s.cod_rubro = k.cod_rubro
           and k.imputable = 'S'
           and s.fecha = P_FECHA
           and abs(nvl(s.sal_mon_loc_ant, 0) + nvl(s.deb_mon_local, 0) - nvl(s.cre_mon_local, 0)) <> 0
         order by 3) xx
 group by xx.rub_btw, xx.btw_moneda, xx.itgf_mon
 having case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         /*when xx.btw_moneda = '1' then
          sum(xx.saldo_me)
         when xx.btw_moneda = '62' then
          sum(xx.saldo_me)
         else
          0*/
        else
          sum(xx.saldo_me)
       end +
       case
         when xx.btw_moneda = '6900' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         /*when xx.btw_moneda = '1' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         when xx.btw_moneda = '62' then
          sum(xx.acum_cre_ml - xx.acum_deb_ml)
         else
          0*/
         else
           sum(xx.acum_cre_ml - xx.acum_deb_ml)
       end  +
       case
         when xx.btw_moneda = '6900' then
          round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', p_fecha),2)
         when xx.btw_moneda = '1' then
          sum(xx.saldo_me)
         /*when xx.btw_moneda = '62' then
          round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', p_fecha),2)
         else
          0*/
         else
           round(sum(xx.acum_cre_ml - xx.acum_deb_ml) /
                fug_obt_cotizacion('USD', p_fecha),2)
       end <> 0
 order by 3;




BEGIN
  v_fecha_arc := to_char(pag_cal.fu_obt_fec_anterior(2),'YYYYMMDD');
--  v_fecha_arc := '20211014';
  v_fecha := to_char(pag_cal.fu_obt_fec_anterior(2));
--    V_FECHA := '14/OCT/2021';
  -- Obtenemos la hora de la base de datos
  v_hora := to_char(sysdate,'hh24miss');

-- Abrir archivo
   v_file := UTL_FILE.FOPEN(pac_mig.g_repository,v_name||'.xls','W',32767);

-- Definir una linea en blanco para separar los datos del titulo de los campos
FOR REC IN cu_rub(v_fecha) LOOP
  v_cabecera := v_cabecera + 1;
  EXIT WHEN cu_rub%NOTFOUND;
END LOOP;

--CUENTA DESCRIPCI¿N MONEDA SALDO EQUIVALENTE EN M/N EQUIVALENTE EN D¿LARES SECUENCIA

--Definir un cursor for loop que recorre los datos obtenidos
FOR REC IN cu_rub(v_fecha)LOOP

   v_count := v_count + 1;

  if v_count = 1 then
   v_linetit := 'CABECERA'||CHR(9)||v_fecha_arc||CHR(9)||CHR(9)||CHR(9)||CHR(9)||CHR(9)||v_cabecera;
   utl_file.put_line(v_file,v_linetit);
     -- Colocar el titulo a los campos
   v_linetit := 'CUENTA'||CHR(9)||'DESCRIPCION'||CHR(9)||'MONEDA'||CHR(9)||'MO'||CHR(9)||'MN'||CHR(9)||'EQUIVALENTE EN DOLARES'||CHR(9)||'SECUENCIA';
   utl_file.put_line(v_file,v_linetit);
  end if;

  v_line := to_char(rec.Cuenta)||chr(9)||to_char(rec.Descripcion)||chr(9)||to_char(rec.moneda)||chr(9)||
            to_char(rec.saldo,'999999999999999999999D00')||chr(9)||
             to_char(rec.Saldo_MN,'999999999999999999999D00')||chr(9)||to_char(rec.equ_dolares,'999999999999999999999D00')||chr(9)||v_count;


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

  EXIT WHEN cu_rub%NOTFOUND;
END LOOP;
--Escribes la linea en el fichero
UTL_FILE.PUT_LINE(v_file, v_buffer);

--Cerrar el handler al fichero
UTL_FILE.FCLOSE(v_file);
COMMIT;

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  if p_tipo = 'H' then
       -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
      v_respuesta := pa_file_ftp.fu_put_ascii(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                              pac_mig.g_pass, pac_mig.g_repository,
                                              v_name||'.xls', g_contabilidad||v_fecha_arc||'_'||v_name||'_'||v_hora||'.xls');
  else
      -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
      v_respuesta := pa_file_ftp.fu_put_ascii(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                              pac_mig.g_pass, pac_mig.g_repository,
                                              v_name||'.xls', g_contabilidad||v_fecha_arc||'_'||v_name||'.xls');

  end if;
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

/*  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      -- Obtenemos los direcciones de correo para quien o quienes va el correo
      v_para := pac_mig.FU_OBT_VALOR_PAR('RA','REPORTES','SALDO_IMPUTABLE');

      -- Damos valor a los demas datos
      v_asunto := 'Reporte Balance Abierto Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'El archivo con los datos del reporte lo tiene disponible en la siguiente direcci¿n: '||g_compartido||g_balances||'

    Nombre del Archivo: '||v_name||'_'||v_fecha||'_'||v_hora||'.txt';

     -- Enviamos el mail
      v_det_error    := null;
      v_hini_mail    := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pac_mig.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
      EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    v_det_error    := null;

    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

    --Enviamos el mail a soporte
     -- Obtenemos direccion de correo de soporte
     v_para := pac_mig.FU_OBT_VALOR_PAR('RA','REPORTES','SOPORTE');

    -- Damos valor a los demas datos
      v_asunto := 'Error Reporte Balance Abierto Historico a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP.

    Error: '||v_respuesta||'.

    Para mas informaci¿n verificar la tabla GE_RA_LOG_FTP';

      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
         v_conn := it_mail.begin_mail(pac_mig.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn,v_mje_mail,'text/plain');
        it_mail.end_mail(v_conn);
      EXCEPTION
        when utl_smtp.transient_error or utl_smtp.permanent_error then
            begin
              utl_smtp.quit(v_conn);
            exception
            when utl_smtp.transient_error or utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
      END;

      v_hfin_mail := to_char(sysdate,'hh24:mi:ss');

      -- Insertamos en la tabla de log  si ocurrio algun error al enviar el mail
      IF v_det_error is not null THEN
          INSERT INTO ge_ra_log_mail
           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES
           (SYSDATE, v_name||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

  END IF;*/


COMMIT;
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
END PR_ARC_BAL_BT_CSV;

-------------------------------------------------------------------------------------------------------------------------------------
-- Balance Rubricado
PROCEDURE PR_ARC_BAL_BT(p_tipo varchar2 default 'H')
IS
  v_file             UTL_FILE.FILE_TYPE;
  v_name             VARCHAR2(128) := 'BALANCE_ITGF_V0'; -- nombre del archivo

  -- Variables de fechas
  v_fecha_arc        VARCHAR2(8);
  v_fecha            GE_CALENDARIOS.FEC_ACTUAL%TYPE;
  v_hora             VARCHAR2(8);

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
  v_can_registro     number;

BEGIN
  v_hora := to_char(sysdate,'hh24miss');
  
  --v_file := UTL_FILE.FOPEN(pac_mig.g_repository,v_name||'.xls','W',32767);
  -- Abrir archivo
  begin
    select count(*) into v_can_registro from BV_BAL_RUBRICADO;
  exception
    when others then
      v_can_registro := 0;
  end;
  
  if p_tipo = 'H' then
     v_fecha_arc := to_char(pag_cal.fu_obt_fec_anterior(2),'YYYYMMDD');
     as_xlsx.query2sheet_balance( 'select cuenta, descripcion, moneda, mo, mn, '||
                                  'equivalente "EQUIVALENTE EN DOLARES", secuencia '||
                                  'from BV_BAL_RUBRICADO_HIS order by secuencia',
                                  true, v_fecha_arc, v_can_registro );
  else
     v_fecha_arc := to_char(pag_cal.FU_OBT_FEC_ACTUAL(2),'YYYYMMDD');
     as_xlsx.query2sheet_balance( 'select cuenta, descripcion, moneda, mo, mn, '||
                                  'equivalente "EQUIVALENTE EN DOLARES", secuencia '||
                                  'from BV_BAL_RUBRICADO order by secuencia',
                                  true, v_fecha_arc, v_can_registro );
  end if;
  as_xlsx.save( pac_mig.g_repository, v_name||'.xlsx');

  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
  if p_tipo = 'H' then
     -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
     v_respuesta := pa_file_ftp.fu_put_binary(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                              pac_mig.g_pass, pac_mig.g_repository,
                                              v_name||'.xlsx', g_contabilidad||
                                              v_fecha_arc||'_'||v_name||'.xlsx');
  else
     -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
     v_respuesta := pa_file_ftp.fu_put_binary(pac_mig.g_ip, pac_mig.g_port, pac_mig.g_user,
                                              pac_mig.g_pass, pac_mig.g_repository,
                                              v_name||'.xlsx', g_contabilidad||
                                              v_fecha_arc||'_'||v_name||'_'||v_hora||'.xlsx');

  end if;
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');

  INSERT INTO ge_ra_log_ftp
  (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
  VALUES
  (SYSDATE, v_name||'_'||v_fecha||'_'||v_hora||'.xls', v_respuesta, v_hini_ftp, v_hfin_ftp);
  COMMIT;
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
END PR_ARC_BAL_BT;
END PAC_MIG;
/

