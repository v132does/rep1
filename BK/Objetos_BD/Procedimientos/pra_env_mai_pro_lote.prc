CREATE OR REPLACE PROCEDURE IT.PRA_ENV_MAI_PRO_LOTE(p_nro_lote in number,
                                                 p_mensaje out varchar2) IS
  ---------------------------------------------------------
  --Proyecto Renovacion Masiva de Tarjetas de Debito--
  --Envio de emals de aviso para pagos de primas anuales---
  ---------------------------------------------------------

  --Variables--
  v_asunto varchar2(200);
  v_lugar varchar2(200);
  v_mensaje varchar2(4000);
  v_linea varchar2(4000);
  v_lon_texto number(4);
  v_lon_linea number(4);
  v_para       VARCHAR2(4000);
  v_des_proceso ba_cod_referencias.significado%type;
  v_tip_proceso varchar2(1);
  v_fec_pro_lote date;
  v_hor_pro_lote varchar2(8);
  v_archivo ge_archivos.archivo%type;
  v_tie_err_lote varchar2(1);

 PROCEDURE lp_tra_env_email(p_para in varchar2,p_asunto in varchar2, p_mensaje in varchar2) IS
   -- Variables para mail
   v_hin_mail ge_ra_log_mail.hor_inicio%type;
   v_hfi_mail ge_ra_log_mail.hor_fin%type;
   v_det_error ge_ra_log_mail.det_error%type;
   PRAGMA AUTONOMOUS_TRANSACTION;
 BEGIN
   BEGIN
     v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
     it_mail.mail(fug_obt_dir_correo, p_para, p_asunto, p_mensaje);
     v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
   EXCEPTION
     when others then
       v_det_error := substr(sqlerrm, 1, 4000);
       INSERT INTO ge_ra_log_mail
       (fec_envio, nom_archivo, dir_correo, mensaje,
        det_error, hor_inicio, hor_fin)
       VALUES
       (SYSDATE, null, substr(p_para,1,4000), substr(p_asunto||chr(10)|| p_mensaje,1,2000),
        substr(v_det_error,1,4000), v_hin_mail, v_hfi_mail);
     commit;
   END;
 END lp_tra_env_email;

 PROCEDURE lp_env_ema_pro_lotes is
   --Cursor Principal--
  cursor c_env_pro_lotes_cab is
    select v_des_proceso linea
      from dual
    union all
    select '**Resumen Lote: '||to_char(p_nro_lote)||' - '||'Archivo: '||v_archivo||'**' linea
      from dual
    union all
    select 'Procesados: '||to_char(nvl(count(*),0))||' - '||  
           'Correctos: '||to_char(nvl(sum(decode(a.est_registro,'N',1,0)),0))||' - '||           
           'Con Error: '||to_char(nvl(sum(decode(a.est_registro,'E',1,0)),0)) linea        
      from ah_tar_deb_masivo a
     where a.nro_lote = p_nro_lote
    union all
    select decode(v_tie_err_lote,'S','**Detalles de Errores**',
                  'Lote '||to_char(p_nro_lote)||' sin Errores de validacion') linea
      from dual
    union all
    select decode(v_tie_err_lote,'S',
           rpad('Nro.Reg.',7,' ')||' - '||
           rpad('Nro.Cuenta',15,' ')||' - '||
           'Error',null) linea
      from dual;

  cursor c_env_pro_lotes_det is
    select rpad(a.nro_registro,7,' ')||' - '||
           rpad(a.nro_cuenta,15,' ')||' - '||
           a.msj_registro linea
       from ah_tar_deb_masivo a
      where a.nro_lote = p_nro_lote
        and a.est_registro = 'E'
      order by a.nro_registro; 
 BEGIN
  --Verificacion Operaciones a Vencer - General para Mesa--
  v_para := null;
  v_asunto := null;
  v_mensaje := null;
     --Enviar e-mails a los grupo y otros--
     v_lon_texto := 0;
     FOR cab in c_env_pro_lotes_cab LOOP
         v_linea := trim(cab.linea);
         v_lugar := v_linea;
         v_lon_linea := length(v_linea);
         if (v_lon_texto + v_lon_linea) > 3500 then
            exit;
         else
            v_lon_texto := v_lon_texto + v_lon_linea + 1;
            v_mensaje := v_mensaje||v_linea||chr(10);
         end if;
     END LOOP;
     FOR det in c_env_pro_lotes_det LOOP
         if det.linea is not null then
            v_linea := trim(det.linea);
            v_lugar := v_linea;
            v_lon_linea := length(v_linea);
            if (v_lon_texto + v_lon_linea) > 3500 then
               exit;
            else
               v_lon_texto := v_lon_texto + v_lon_linea + 1;
               v_mensaje := v_mensaje||v_linea||chr(10);
            end if;
         end if;
     END LOOP;

     --Envio de Emails--
     select decode(fug_obt_pardinamico('ENV_EMA_PRO_LOT_TARDEB'),null,
            lower(FUG_OBT_DIR_MAIL_USU(user)),
            lower(FUG_OBT_DIR_MAIL_USU(user))||';'||
            fug_obt_pardinamico('ENV_EMA_PRO_LOT_TARDEB'))
       into v_para
       from dual;
     --if p_dir_email is not null then
     --   v_para := p_dir_email;     
     --end if;
     if ((v_mensaje is not null) and (v_para is not null)) then
        v_asunto := v_des_proceso;
        lp_tra_env_email(v_para, v_asunto, v_mensaje);
        p_mensaje := v_mensaje;
     end if;
   
 END;

--Proceso Principal--
BEGIN
  --Carga de Variables--
  --pag_cal.PR_OBT_DAT_CALENDAR(3);
  
  v_tip_proceso := null;
  v_fec_pro_lote := null;
  v_hor_pro_lote := null;
  v_archivo := null;
  v_tie_err_lote := null;
  
  --Traer tipo de proceso y fecha--
  select a.tip_proceso, a.fec_pro_lote, a.hor_pro_lote
    into v_tip_proceso, v_fec_pro_lote, v_hor_pro_lote
    from ah_tar_deb_masivo a
   where a.nro_lote = p_nro_lote
     and rownum = 1;
     
  select decode(nvl(count(*),0),0,'N','S')
    into v_tie_err_lote
    from ah_tar_deb_masivo a
   where a.nro_lote = p_nro_lote
     and a.est_registro = 'E';
  
  --Trar el nombre del archivo--
  select a.archivo
    into v_archivo
    from ge_archivos a
   where a.referencia = fue_obt_val_max_refcodes('TIP_PRO_MAS_TARDEB',v_tip_proceso);
  
  v_des_proceso := upper(fue_obt_sig_refcodes('TIP_PRO_MAS_TARDEB',v_tip_proceso))||
                   ' Lote '||to_char(p_nro_lote)||
                   ' Fecha '||to_char(v_fec_pro_lote,'dd/mm/yyyy')||
                   ' Hora '||v_hor_pro_lote;
  --Envio de email--
  lp_env_ema_pro_lotes;

EXCEPTION
   WHEN OTHERS THEN
        raise_application_error(-20001, ' Error en PRA_ENV_MAI_PRO_LOTE '|| SQLERRM);
END;
/

