CREATE OR REPLACE PROCEDURE IT.PRL_ENV_MAI_VEN_FORWARD IS

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
       (SYSDATE, null, p_para, p_asunto||chr(10)|| p_mensaje,
        v_det_error, v_hin_mail, v_hfi_mail);
     commit;
   END;
 END lp_tra_env_email;

 PROCEDURE lp_env_ema_general is
   --Cursor Principal--
  cursor c_ven_forward_cab is
    select '**Totales**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Tipo',10,' ')||' -'||chr(9)||
           rpad('Mon',3,' ')||' -'||chr(9)||
           lpad('Cant.',7,' ')||' -'||chr(9)||
           lpad('Monto',18,' ') linea
      from dual
    union all
    select rpad(to_char(a.cod_mad_transaccion)||'-'||substr(b.descripcion,1,6),10,' ')||' -'||chr(9)||
           rpad(a.cod_moneda,3,' ')||' -'||chr(9)||
           lpad(trim(to_char(nvl(count(*),0),'999,999')),7,' ')||' -'||chr(9)||
           lpad(trim(to_char(sum(nvl(a.monto,0)),'999,999,999,990.99')),18,' ') linea
      from lc_ope_futuras a, ge_modalidades b
     where a.estado = 'N'
       and a.fec_vencimiento <= v_fec_actual
       and b.cod_modulo = 7
       and b.cod_modalidad = a.cod_mad_transaccion
    group by a.cod_mad_transaccion, b.descripcion, a.cod_moneda
    union all
    select chr(10)||'**Detalles**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Cliente',25,' ')||' - '||
           rpad('Nr.Op',5,' ')||' - '||
           rpad('Fec.Operac',10,' ')||' - '||
           rpad('Fec.Vencim',10,' ')||' - '||
           rpad('Plazo',6,' ')||' - '||
           rpad('Tipo',6,' ')||' - '||
           rpad('T.Liq',3,' ')||' - '||
           rpad('Cot.Pactada',12,' ')||' - '||
           rpad('Mon',3,' ')||' - '||
           lpad('Monto',18,' ')||' - '||
           lpad('Oficial',10,' ') linea
      from dual;

  cursor c_ven_forward_det is
    select rpad(x.cod_persona||'-'||substr(x.nom_completo,1,15+(10-(length(x.cod_persona)))),25,' ')||' - '||
           to_char(a.nro_operacion)||' - '||
           to_char(a.fec_operacion,'dd/mm/yyyy')||' - '||
           to_char(a.fec_vencimiento,'dd/mm/yyyy')||' - '||
           lpad(trim(to_char(a.plazo)),6,' ')||' - '||
           rpad(substr(b.descripcion,1,6),6,' ')||' - '||
           rpad(a.tip_liquidacion,3,' ')||' - '||
           lpad(trim(to_char(a.cot_vencimiento,'999,990.9999')),12,' ')||' - '||
           rpad(a.cod_moneda,3,' ')||' - '||
           trim(to_char(a.monto,'999,999,999,990.99'))||' - '||
           trim(y.cod_usu_oficial) linea
      from lc_ope_futuras a, ba_personas x, ge_modalidades b, ge_clientes y
     where a.estado = 'N'
       and a.fec_vencimiento <= v_fec_actual
       and x.cod_persona = a.cod_persona
       and b.cod_modulo = 7
       and b.cod_modalidad = a.cod_mad_transaccion
       and y.cod_persona = a.cod_persona
     order by x.cod_persona, a.cod_moneda, a.fec_vencimiento, a.monto;
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
     FOR det in c_ven_forward_cab LOOP

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
     FOR det in c_ven_forward_det LOOP
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
     v_para := fug_obt_pardinamico('ENV_EMA_AVI_MESA');
     if ((v_mensaje is not null) and (v_para is not null)) then
        v_asunto := 'FORWARD - Vencimiento de '||to_char(v_can_vencim)||' Operaciones Futuras al '||to_char(v_fec_actual,'dd/mm/yyyy')||' - A procesar.';
        lp_tra_env_email(v_para, v_asunto, v_mensaje);
     end if;
   end if;
 END;

PROCEDURE lp_env_ema_oficiales is

  v_cod_usu_oficial ge_clientes.cod_usu_oficial%type;
  v_nombre ba_usuarios.nombre%type;
  v_dir_correo ba_usuarios.dir_correo%type;

  cursor c_oficiales is
    select distinct b.cod_usu_oficial, c.nombre, c.dir_correo
      from lc_ope_futuras a, ge_clientes b, ba_usuarios c
     where a.estado = 'N'
       and a.fec_vencimiento <= v_fec_actual
       and b.cod_persona = a.cod_persona
       and c.cod_usuario = b.cod_usu_oficial;

   --Cursor Principal--
  cursor c_ven_forward_cab_ofi is
    select '**Totales**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Tipo',10,' ')||' -'||chr(9)||
           rpad('Mon',3,' ')||' -'||chr(9)||
           lpad('Cant.',7,' ')||' -'||chr(9)||
           lpad('Monto',18,' ') linea
      from dual
    union all
    select rpad(to_char(a.cod_mad_transaccion)||'-'||substr(b.descripcion,1,6),10,' ')||' -'||chr(9)||
           rpad(a.cod_moneda,3,' ')||' -'||chr(9)||
           lpad(trim(to_char(nvl(count(*),0),'999,999')),7,' ')||' -'||chr(9)||
           lpad(trim(to_char(sum(nvl(a.monto,0)),'999,999,999,990.99')),18,' ') linea
      from lc_ope_futuras a, ge_modalidades b, ge_clientes y
     where a.estado = 'N'
       and a.fec_vencimiento <= v_fec_actual
       and b.cod_modulo = 7
       and b.cod_modalidad = a.cod_mad_transaccion
       and y.cod_persona = a.cod_persona
       and y.cod_usu_oficial = v_cod_usu_oficial
    group by a.cod_mad_transaccion, b.descripcion, a.cod_moneda
    union all
    select chr(10)||'**Detalles**' linea
      from dual
    union all
    select '============' linea
      from dual
    union all
    select rpad('Cliente',25,' ')||' - '||
           rpad('Nr.Op',5,' ')||' - '||
           rpad('Fec.Operac',10,' ')||' - '||
           rpad('Fec.Vencim',10,' ')||' - '||
           rpad('Plazo',6,' ')||' - '||
           rpad('Tipo',6,' ')||' - '||
           rpad('T.Liq',3,' ')||' - '||
           rpad('Cot.Pactada',12,' ')||' - '||
           rpad('Mon',3,' ')||' - '||
           lpad('Monto',18,' ') linea
      from dual;

  cursor c_ven_forward_det_ofi is
    select rpad(x.cod_persona||'-'||substr(x.nom_completo,1,15+(10-(length(x.cod_persona)))),25,' ')||' - '||
           to_char(a.nro_operacion)||' - '||
           to_char(a.fec_operacion,'dd/mm/yyyy')||' - '||
           to_char(a.fec_vencimiento,'dd/mm/yyyy')||' - '||
           lpad(trim(to_char(a.plazo)),6,' ')||' - '||
           rpad(substr(b.descripcion,1,6),6,' ')||' - '||
           rpad(a.tip_liquidacion,3,' ')||' - '||
           lpad(trim(to_char(a.cot_vencimiento,'999,990.9999')),12,' ')||' - '||
           rpad(a.cod_moneda,3,' ')||' - '||
           trim(to_char(a.monto,'999,999,999,990.99')) linea
      from lc_ope_futuras a, ba_personas x, ge_modalidades b, ge_clientes y
     where a.estado = 'N'
       and a.fec_vencimiento <= v_fec_actual
       and x.cod_persona = a.cod_persona
       and b.cod_modulo = 7
       and b.cod_modalidad = a.cod_mad_transaccion
       and y.cod_persona = a.cod_persona
       and y.cod_usu_oficial = v_cod_usu_oficial
     order by x.cod_persona, a.cod_moneda, a.fec_vencimiento, a.monto;
 BEGIN
   --Verificacion Operaciones a Vencer - Por Oficiales--
  for ges in c_oficiales loop
      v_cod_usu_oficial := ges.cod_usu_oficial;
      v_nombre := ges.nombre;
      v_dir_correo := ges.dir_correo;
      v_para := null;
      v_asunto := null;
      v_mensaje := null;
      v_can_vencim := 0;

      select nvl(count(*),0)
        into v_can_vencim
        from lc_ope_futuras a, ge_clientes b
       where a.estado = 'N'
         and a.fec_vencimiento <= v_fec_actual
         and b.cod_persona = a.cod_persona
         and b.cod_usu_oficial = v_cod_usu_oficial;

      if nvl(v_can_vencim,0) > 0 then
         --Enviar e-mails a los grupo y otros--
         v_lon_texto := 0;
         FOR det in c_ven_forward_cab_ofi LOOP

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
         FOR det in c_ven_forward_det_ofi LOOP
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
         v_para := v_dir_correo;
         if ((v_mensaje is not null) and (v_para is not null)) then
            v_asunto := 'FORWARD - Vcto. '||to_char(v_can_vencim)||' Op.Futuras al '||to_char(v_fec_actual,'dd/mm/yyyy')||
                        ' - Oficial:'||v_cod_usu_oficial||'-'||initcap(v_nombre);
            lp_tra_env_email(v_para, v_asunto, v_mensaje);
         end if;
       end if;
   end loop;
 END;

 PROCEDURE lp_env_ema_car_curvas is
   v_nom_dia ge_calendarios.nom_dia%type;

 BEGIN
  --Envio de emails para carga de curvas--
  if v_fec_actual = fug_obt_pri_dia_hab_semana(v_fec_actual) then
     v_para := null;
     v_asunto := null;
     v_mensaje := null;

     --Envio de Emails--
     v_nom_dia := pag_cal.FU_OBT_NOM_DIA(v_fec_actual);
     v_mensaje := 'Cargar en ITGF datos de Curvas de Forward y Curvas Cupon Cero desde pagina web de BCP'||CHR(10)||
                  'Pagina WEB BCP: www.bcp.gov.py'||CHR(10)||
                  'Datos de Semana anterior al '||to_char(v_fec_actual,'dd/mm/yyyy')||CHR(10)||
                  '- Bajar archivos en excel'||CHR(10)||
                  '- Importar en opciones habilitadas en ITGF';
     v_para := fug_obt_pardinamico('ENV_EMA_AVI_MESA');
     if ((v_mensaje is not null) and (v_para is not null)) then
        v_asunto := 'FORWARD Recordatorio: Cargar datos de Curvas p/ Valor Economico - Cargar hoy '||v_nom_dia||' '||to_char(v_fec_actual,'dd/mm/yyyy')||' antes del Cierre';
        lp_tra_env_email(v_para, v_asunto, v_mensaje);
     end if;
   end if;
 END;

--Proceso Principal--
BEGIN
  --Carga de Variables--
  v_fec_actual := pag_cal.fu_obt_fec_actual(7);
  lp_env_ema_general;
  lp_env_ema_oficiales;
  lp_env_ema_car_curvas;

EXCEPTION
   WHEN OTHERS THEN
        raise_application_error(-20001, ' Error en PRL_ENV_MAI_VEN_FORWARD '|| SQLERRM);
END;
/

