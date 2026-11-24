CREATE OR REPLACE PROCEDURE IT.PRT_IMP_TMP_PRONET IS
 
-- 02/07/2013-DI-RABP: 
-- Procedimiento para la importacion automatica de archivos de pagos ProNet desde un directorio oracle

  v_fec_actual   DATE          := pag_cal.FU_OBT_FEC_ANTERIOR(5); -- La fecha tiene que de un dia anterior 
  v_directorio   VARCHAR2(200) := 'PRONET'; -- Nombre del directorio oracle en produccion
  v_archivo      utl_file.file_type;
  v_linea        VARCHAR2(32767);
  v_nom_archivo  VARCHAR2(200);
  v_msj          VARCHAR2(4000); 
  v_registro     NUMBER(4) := 0; 
  r_log          TA_LOG_PRONET%ROWTYPE;
  -- Variables para envio de mail --
  c_env_mail     VARCHAR2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com';
  c_rec_mail     VARCHAR2(100) := fug_obt_pardinamico('DIR_IMP_PRONET');    
  c_asunto       VARCHAR2(400) := 'Error durante importacion del archivo Pronet de fecha '||v_fec_actual;
  c_mensaje      VARCHAR2(4000):= 'Error en la importacion del archivo de pagos de Pronet de fecha '||v_fec_actual||'.'||chr(13)||'Nombre del archivo: ';
  
  -- Procedimiento para cargar los datos de la tabla de errores--
  PROCEDURE pr_ins_datos ( p_linea IN VARCHAR2) 
    IS
    v_error        BOOLEAN := TRUE;
  BEGIN
    -- Cargamos los datos correspondientes 
    r_log.fec_envio   := to_char(sysdate,'DD/MM/YYYY');
    r_log.hor_envio   := to_char(sysdate,'hh24:mm:ss');
    if length(p_linea) <= 30 then  -- corresponde al registro cabecera del archivo
      r_log.nro_lote    := 1;
      r_log.nro_boleta  := 1;
      r_log.nro_tarjeta := '1';
    else
      r_log.nro_lote    := NVL(substr(p_linea,17,6),0);
      r_log.nro_boleta  := NVL(substr(p_linea,23,6),0);
      r_log.nro_tarjeta := NVL(substr(p_linea,29,30),'X');
    end if;
    r_log.nro_linea   := v_registro;
    
    -- Ejecutamos el procediento que inserta los datos en la tabla de logs
    begin
       PRT_INS_LOG_PRONET(r_log,v_error);
    exception
      when others then
        RAISE_APPLICATION_ERROR(-20080, 'ERROR 20080 al invocar procedimiento PRT_INS_LOG_PRONET: '||DBMS_UTILITY.format_error_backtrace||SQLERRM);  
    end;
  
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20070, 'ERROR 20070: '||DBMS_UTILITY.format_error_backtrace||SQLERRM);  
  END;
  ------------------------------------------------------
  
BEGIN
  -- Datos para cargar en el logs de errores de ser necesario
	r_log.nom_proceso := 'PRT_IMP_TMP_PRONET';
  
  -- Armamos el nombre del archivo a procesar e indicamos donde se encuentra
  v_nom_archivo     := 'clearingBBVA'|| to_char(v_fec_actual,'DDMMYY')||'.txt';
  r_log.nom_archivo := v_nom_archivo; 
  
  -- Leemos el archivo
  v_archivo := utl_file.fopen(v_directorio, v_nom_archivo, 'R');             
  
  -- Truncamos la tabla temporal para cargar los datos
  sql_util.ejecute_dml('TRUNCATE TABLE TA_COB_TMP_PRONET', v_msj);
  IF v_msj IS NOT NULL THEN
    raise_application_error(-20000, v_msj);
  END IF;
  
  -- Recorremos los registros del archivo y lo depositamos en la tabla temporal
  loop
    begin
      utl_file.get_line(v_archivo, v_linea);
      v_registro := v_registro + 1;
      insert into ta_cob_tmp_pronet (datos) values (v_linea);
    exception
      WHEN NO_DATA_FOUND THEN
        EXIT;
    end; 
  end loop;
  
  -- Cerramos el archivo
  utl_file.fclose(v_archivo);
  
  commit;
  
  --Insertamos los datos de la tabla temporal en la tabla maestra --
	BEGIN
	  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END; 
	  PRT_INS_COB_PRONET;
	EXCEPTION
      WHEN OTHERS THEN
        r_log.comentario := substr('Error al importar pagos a la tabla maestra GE_MOV_PRO_COBRANZAS: '||DBMS_UTILITY.format_error_backtrace,1,4000);
        pr_ins_datos(v_linea);
        PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, 'Error al importar pagos a la tabla maestra GE_MOV_PRO_COBRANZAS. Archivo: '||v_nom_archivo);
	END;
	
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20060: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
    
   WHEN UTL_FILE.INVALID_OPERATION THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20061: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
      
    WHEN UTL_FILE.INVALID_FILEHANDLE THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20062: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
      
    WHEN UTL_FILE.READ_ERROR THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20063: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
      
    WHEN UTL_FILE.INVALID_MODE THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20064: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
      
    WHEN UTL_FILE.INTERNAL_ERROR THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20065: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
    
    WHEN UTL_FILE.INVALID_PATH THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20066: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
      
    WHEN UTL_FILE.INVALID_MAXLINESIZE THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20067: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);
      
    WHEN OTHERS THEN
      UTL_FILE.FCLOSE(v_archivo);
      r_log.comentario := substr('Error al importar archivo de pago Pronet. ERROR 20068: '||DBMS_UTILITY.format_error_backtrace,1,4000);
      pr_ins_datos(v_linea);
      --Comunicamos el error durante la importacion
      PRG_ENV_MAIL(c_env_mail, c_rec_mail, c_asunto, c_mensaje||v_nom_archivo);

END;
/

