CREATE OR REPLACE PROCEDURE IT.PRA_ENV_MAI_TRA_LOTE(p_lis_lotes in varchar2,
                                                 p_mensaje out varchar2) IS
  ---------------------------------------------------------
  --Proyecto Renovacion Masiva de Tarjetas de Debito--
  --Envio de emals de aviso para pagos de primas anuales---
  ---------------------------------------------------------
  
  PRAGMA AUTONOMOUS_TRANSACTION;
  --Variables--
  v_asunto varchar2(200);
  v_lugar varchar2(4000);
  v_mensaje varchar2(4000);
  v_linea varchar2(4000);
  v_lon_texto number(4);
  v_lon_linea number(4);
  v_para       VARCHAR2(4000);
  v_des_proceso ba_cod_referencias.significado%type;
  v_tie_err_lote varchar2(1);
  v_fecha date;
  v_hora varchar2(8);
  v_cod_procesadora ah_tar_debitos.cod_ent_procesadora%type := fug_obt_pardinamico('COD_PRO_BANCARD');
  v_nro_lote ah_tar_deb_masivo.nro_lote%type;
  v_des_pro_lote ba_cod_referencias.abreviatura%type;
  
  cursor c_res_lotes is
   select distinct x.nro_lote, x.tip_proceso
     from ah_tar_deb_masivo x, ah_tar_deb_sol_ws b
    where instr(p_lis_lotes,x.nro_lote||';') > 0
      and x.nro_lote = b.nro_lote
      and x.ide_reg_lote = b.ide_reg_lote;
 
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
    select '** Resumen Transmisión '||v_des_pro_lote||' Lote '||to_char(v_nro_lote)||' **' linea
      from dual
    union all
    select 'Transmitidos Correctos: '||to_char(
           sum(case 
            when ((a.est_registro = 'N') and 
                  (x.cod_est_solicitud = 4 )) then 1
            else 0 end)
           )||' - '||
       
       'Errores en Transmisión: '||to_char(
       sum(case 
            when ((a.est_registro = 'E') and 
                  (a.msj_registro like 'Error en Transmision de registro%')) then 1
            else 0 end)
                             )||' - '||
       
       'Errores en Validación: '||to_char(
                             sum(case 
            when ((a.est_registro = 'E') and 
                  (a.msj_registro not like 'Error en Transmision de registro%')) then 1
            else 0 end)           
           )||' - '||
       'Pend. de Envío: '||to_char(
                             sum(case 
            when ((a.est_registro = 'N') and 
                  (x.cod_est_solicitud = 5 )) then 1
            else 0 end)
           )||' - '||           
       'Total Reg. del Lote: '||to_char(nvl(count(*),0)) linea
      from ah_tar_deb_masivo a, ah_tar_debitos x
     where a.nro_lote = v_nro_lote
       and a.nro_lote = x.nro_lote(+)
       and a.ide_reg_lote = x.ide_reg_lote(+)
    union all
    select decode(v_tie_err_lote,'S','**Detalle Errores de Transmisión**',
                  'Lote '||to_char(v_nro_lote)||' sin Errores de transmisión') linea
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
           b.det_error linea
       from ah_tar_deb_masivo a, ah_tar_deb_sol_ws b
      where a.nro_lote = b.nro_lote
        and a.ide_reg_lote = b.ide_reg_lote
        and a.nro_lote = v_nro_lote
        and a.est_registro = 'E'
        and b.det_error is not null
      order by a.nro_registro;
   
 BEGIN
  --Verificacion Operaciones a Vencer - General para Mesa--
     --Enviar e-mails a los grupo y otros--
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
 END;
 
--Proceso Principal--
BEGIN
  --Carga de Variables--
  --pag_cal.PR_OBT_DAT_CALENDAR(3);
  
  v_tie_err_lote := null;
  v_fecha := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_hora := to_char(sysdate,'hh24:mi:ss');
  
  --Cargar Titulo--
  v_des_proceso := 'Transmisión Lotes de TD a '||fue_obt_nom_ente(v_cod_procesadora)||
                   ' Fecha '||to_char(v_fecha,'dd/mm/yyyy')||
                   ' Hora '||v_hora;
  
  --Actualizar registros transmitidos por error--
  v_lon_texto := 0;
  v_para := null;
  v_asunto := null;
  v_mensaje := null;
  for res in c_res_lotes loop
      --Cargar Nro. de Lote--
      v_nro_lote := res.nro_lote;
      v_des_pro_lote := upper(fue_obt_sig_refcodes('TIP_PRO_MAS_TARDEB',res.tip_proceso));
      
      --Actualizaciom de errores de transmision
      update ah_tar_deb_masivo x
         set (x.est_registro, x.msj_registro) = 
             (select 'E', 'Error en Transmision de registro: '||
                     b.det_error
                from ah_tar_deb_sol_ws b
               where b.nro_lote = x.nro_lote
                 and b.ide_reg_lote = x.ide_reg_lote
                 and b.det_error is not null)
       where x.nro_lote = v_nro_lote
         and x.est_registro = 'N'
         and exists (select 1 
                       from ah_tar_deb_sol_ws b
                      where b.nro_lote = x.nro_lote
                        and b.ide_reg_lote = x.ide_reg_lote
                        and b.det_error is not null);
      
      --Contabilizar los errores de transmsion del Lote--
      select decode(nvl(count(*),0),0,'N','S')
        into v_tie_err_lote
        from ah_tar_deb_sol_ws a
       where a.nro_lote = v_nro_lote
         and a.det_error is not null;
     
      --Envio de email--
      lp_env_ema_pro_lotes;    
  end loop;
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
  commit;
  
EXCEPTION
   WHEN OTHERS THEN
        raise_application_error(-20001, ' Error en PRA_ENV_MAI_TRA_LOTE '|| SQLERRM);
END;
/

