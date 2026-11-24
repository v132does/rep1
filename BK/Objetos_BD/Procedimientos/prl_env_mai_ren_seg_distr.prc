CREATE OR REPLACE PROCEDURE IT.PRL_ENV_MAI_REN_SEG_DISTR(p_mes_ren_prima in number default null,
                                                      p_ano_ren_prima in number default null,
                                                      p_dir_email in varchar2 default null) IS
  ---------------------------------------------------------
  --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)--
  --Envio de emals de aviso para pagos de primas anuales---
  ---------------------------------------------------------

  --Variables--
  v_fec_actual      DATE;
  v_can_vencim      number(6);
  v_asunto varchar2(200);
  v_lugar varchar2(200);
  v_mensaje varchar2(4000);
  v_linea varchar2(4000);
  v_lon_texto number(4);
  v_lon_linea number(4);
  v_para       VARCHAR2(4000);
  v_ano_pag_prima number(4);
  v_mes_pag_prima number(2);

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

 PROCEDURE lp_env_ema_ren_seguros is
   --Cursor Principal--
  cursor c_ren_seguros_cab is
    select 'Primas de ctas a Renovar al '||to_char(v_mes_pag_prima)||'/'||to_char(v_ano_pag_prima) linea
      from dual
    union all
    select '**Resumen**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Cod.Seguro',5,' ')||' -'||chr(9)||
           rpad('Descripcion',20,' ')||' -'||chr(9)||
           rpad('Tran',4,' ')||' -'||chr(9)||
           rpad('Mon',3,' ')||' -'||chr(9)||
           lpad('Cant',6,' ')||' -'||chr(9)||
           lpad('Monto_Prima',18,' ') linea
      from dual
    union all
    -----
    select rpad(to_char(a.cod_ent_seguro),5,' ')||' -'||chr(9)||
           rpad(substr(fue_obt_nom_ente(a.cod_ent_seguro),1,20),20,' ')||' -'||chr(9)||
           rpad(to_char(a.cod_transaccion),4,' ')||' -'||chr(9)||
           rpad(a.cod_moneda,3,' ')||' -'||chr(9)||
           lpad(trim(to_char(nvl(count(distinct(a.nro_cuenta)),0),'999,999')),6,' ')||' -'||chr(9)||
           lpad(trim(to_char(sum(nvl(a.mto_car_pri_com_base,0)),decode(a.cod_moneda,'GS','999,999,999,990', '999,999,999,990.99'))),18,' ') linea
      from pr_cta_gas_seguros a, ge_modalidades b
     where a.ano_pag_prima = v_ano_pag_prima
       and a.mes_pag_prima = v_mes_pag_prima
       and b.cod_modulo = 6
       and b.cod_modalidad = a.cod_modalidad
     group by a.cod_ent_seguro, a.cod_transaccion, a.cod_moneda
    union all
    select chr(10)||'**Detalles**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Cuenta',15,' ')||' - '||
           rpad('Modalidad',20,' ')||' - '||
           rpad('Año',4,' ')||' - '||
           rpad('Mon',3,' ')||' - '||
           lpad('Monto_Prima',20,' ') linea
      from dual;

  cursor c_ren_seguros_det is
    select rpad(a.nro_cuenta,15,' ')||' - '||
           rpad(substr(b.cod_modalidad||'-'||b.descripcion,1,20),20,' ')||' - '||
           rpad(to_char(a.ano),4,' ')||' - '||
           rpad(a.cod_moneda,3,' ')||' - '||
           lpad(trim(to_char(sum(nvl(a.mto_car_pri_com_base,0)),decode(a.cod_moneda,'GS','999,999,999,990','999,999,999,990.99'))),20,' ') linea
      from pr_cta_gas_seguros a, ge_modalidades b
      where a.ano_pag_prima = v_ano_pag_prima
        and a.mes_pag_prima = v_mes_pag_prima
        and b.cod_modulo = 6
        and b.cod_modalidad = a.cod_modalidad
      group by a.nro_cuenta, b.cod_modalidad, b.descripcion, a.ano, a.cod_moneda
      order by a.cod_moneda;     
 BEGIN
  --Verificacion Operaciones a Vencer - General para Mesa--
  v_para := null;
  v_asunto := null;
  v_mensaje := null;
  v_can_vencim := 0;

  select nvl(count(*),0)
    into v_can_vencim
    from lc_ope_futuras a
   where a.estado = 'N'
     and a.fec_vencimiento <= v_fec_actual;

  if nvl(v_can_vencim,0) > 0 then
     --Enviar e-mails a los grupo y otros--
     v_lon_texto := 0;
     FOR det in c_ren_seguros_cab LOOP

         v_linea := trim(det.linea);
         v_lugar := v_linea;
         v_lon_linea := length(v_linea);
         if (v_lon_texto + v_lon_linea) > 3500 then
            exit;
         else
            v_lon_texto := v_lon_texto + v_lon_linea + 1;
            v_mensaje := v_mensaje||v_linea||chr(10);
         end if;
     END LOOP;
     FOR det in c_ren_seguros_det LOOP
         v_linea := trim(det.linea);
         v_lugar := v_linea;
         v_lon_linea := length(v_linea);
         if (v_lon_texto + v_lon_linea) > 3500 then
            exit;
         else
            v_lon_texto := v_lon_texto + v_lon_linea + 1;
            v_mensaje := v_mensaje||v_linea||chr(10);
         end if;
     END LOOP;

     --Envio de Emails--
     if p_dir_email is not null then
        v_para := p_dir_email;
     else
        v_para := fug_obt_pardinamico('ENV_EMA_AVI_OPERACIONES');
     end if;
     if ((v_mensaje is not null) and (v_para is not null)) then
        v_asunto := 'RENOVACION SEGURO DISTRIBUIDO - Primas de ctas a Renovar al '||to_char(v_mes_pag_prima)||'/'||to_char(v_ano_pag_prima);
        lp_tra_env_email(v_para, v_asunto, v_mensaje);
     end if;
   end if;
 END;

--Proceso Principal--
BEGIN
  --Carga de Variables--
  pag_cal.PR_OBT_DAT_CALENDAR(6);
  v_fec_actual  := pag_cal.G_FEC_ACTUAL;
  
  --Validaciones--
  if nvl(p_mes_ren_prima,0) > 12 then
     raise_application_error(-20001, 'Error. Ingresar mes de ren. de prima correcto.');
  end if;
  if nvl(p_mes_ren_prima,0) < 0 then
     raise_application_error(-20001, 'Error. Ingresar año de ren. de prima correcto.');
  end if;
  if p_mes_ren_prima is null then
     v_mes_pag_prima := to_number(to_char(v_fec_actual,'mm'));
  else
     v_mes_pag_prima := p_mes_ren_prima;
  end if;
  if p_ano_ren_prima is null then
     v_ano_pag_prima := to_number(to_char(v_fec_actual,'yyyy'));
  else
     v_ano_pag_prima := p_ano_ren_prima;
  end if;
  lp_env_ema_ren_seguros;

EXCEPTION
   WHEN OTHERS THEN
        raise_application_error(-20001, ' Error en PRL_ENV_MAI_REN_SEG_DISTR '|| SQLERRM);
END;
/

