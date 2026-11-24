create or replace procedure it.prg_env_ext_mail(p_mensual in varchar2 default null,
                                             p_nro_cuenta in varchar2 default null,
                                             p_fecha in date default null) is
 -- Envia extracto por mail en formato txt y xls
 -- Si recibe P_MENSUAL envía el último extracto mensual generado.
 -- Si recibe P_FECHA envía el extracto para una fecha específica correspondiente al mes actual.
 -- Si recibe P_NRO_CUENTA envía el extracto para una cuenta específica.
 -- Si no recibe parámetros envía para todas las cuentas todos los movimientos del mes actual.
  v_nombre           varchar2(100);
  v_asunto           varchar2(100);
  v_contenido        varchar2(400);
  v_dir_correo_de    varchar2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--'bbvanet@bbva.com.py';
  v_fec_ult_extracto ah_cta_vistas.fec_ult_extracto%type;
  v_dato             varchar2(1);
  v_hor_inicio       ge_log_mail.hor_inicio%type;
  v_hor_fin          ge_log_mail.hor_fin%type;
  v_det_error        ge_log_mail.det_error%type;
  v_mensual          varchar2(1);
  conn               utl_smtp.connection;
  --
  v_s varchar2(1) default 'x';
  v_q varchar2(1) default 'x';
  v_m varchar2(1) default 'x';
  v_fec_actual        ge_calendarios.fec_actual%type;
  v_fec_proxima       ge_calendarios.fec_proxima%type;
  v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%type;
  v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%type;
  --
  v_fre_extracto varchar2(10);
  --
  cursor cta is
    select a.cod_persona, a.nro_cuenta, replace(d.val_parametro,' ','') mail,
           fug_obt_paradicional(a.nro_cuenta,'EMAIL_FOR_ESPECIAL') formato, c.fre_extracto
      from ge_cta_clientes a,
           ge_cuentas c,
           ge_cta_dat_adicionales d
     where a.nro_cuenta = c.nro_cuenta
       and a.nro_cuenta = d.nro_cuenta
       and d.parametro = 'EMAIL_ENVIO_EXT_ASCII'
       and a.cod_modulo in (3,4)
       and a.cod_modalidad in (31,41)
       and a.relacion = 'P'
       and c.estado <> 'C'
       and a.nro_cuenta = nvl(p_nro_cuenta,a.nro_cuenta)
     order by cod_persona;
begin
  --
  pag_cal.pr_obt_dat_calendar(1);
  --
  v_fec_actual        := pag_cal.g_fec_actual;
  v_fec_proxima       := pag_cal.g_fec_proxima;
  v_pri_dia_mes_habil := pag_cal.g_pri_dia_mes_habil;
  v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;
  --
  if p_fecha is not null and nvl(p_mensual,'N') = 'N' then
    if p_fecha < v_pri_dia_mes_habil then
      raise_application_error(-20001,'Error. Fecha debe corresponder al Mes Actual.');
    elsif p_fecha >= v_fec_actual then
      raise_application_error(-20002,'Error. Fecha debe ser inferior a la Fecha Actual.');
    end if;
    --
    v_fec_actual  := p_fecha;
    -- Carga con la fecha hábil siguiente.
    v_fec_proxima := pag_cal.fu_obt_fec_habil(v_fec_actual+1,1,1);
  end if;
  --
  v_mensual := nvl(p_mensual,'N');
  --
  if to_number(to_char(v_fec_actual, 'D')) > to_number(to_char(v_fec_proxima,'D')) or
     v_fec_actual = v_ult_dia_mes_habil Then
    v_s := 'S'; -- Frecuencia Semanal.
  end if;

  if v_fec_actual = fug_obt_fec_hab_quincena(v_fec_actual) or
     v_fec_actual = v_ult_dia_mes_habil then
    v_q := 'Q';
  end if;

  If v_fec_actual = v_ult_dia_mes_habil Then
    v_m := 'M';
    v_mensual := 'S';
  end if;
  --
  -- Si es mensual busca la fecha de último Extracto, para el envío.
  if nvl(v_mensual,'N') = 'S' then
    select max(fec_ult_extracto) into v_fec_ult_extracto from ah_cta_vistas;
  else
    --Ref: DESOPIMI-20 - Mejora de Envio de Extracto por Mails--
    --Generacion total Movimimientos p/ Ctas c/ Envio Extracto--
    prg_gen_mov_ext_tmp;
  end if;
  --
  if v_pri_dia_mes_habil = v_fec_actual then
    -- Si es el primer día habil del mes borra el log.
    begin delete ge_log_mail; exception when others then null; end;
  end if;

  for c in cta loop
    v_det_error    := null;
    v_hor_inicio   := null;
    v_hor_fin      := null;
    v_asunto       := null;
    v_fre_extracto := fug_obt_paradicional(c.nro_cuenta,'EXT_ASCII');
    if v_fre_extracto in ('D',v_s,v_q,v_m) then
      if nvl(v_mensual,'N') = 'N' then
        --Ref: DESOPIMI-20 - Mejora de Envio de Extracto por Mails--
        /*-- Genera Extracto a Requerimiento.
        begin
          pae_cnf.g_programa := 'prg_env_ext_mail';
          --
          prg_gen_extracto_tmp(c.cod_persona,c.nro_cuenta,p_fecha);
        exception
          when others then
            v_det_error := substr(sqlerrm,1,4000);
        end;*/
        -- Busca si Generó Extracto a Requerimiento
        begin
          select distinct 'S'
            into v_dato
            from ge_ext_clientes_tmp cli,
                 ge_ext_cli_cuentas_tmp et
           where cli.cod_persona  = et.cod_persona
             and cli.fec_extracto = et.fec_extracto
             and cli.fre_extracto = et.fre_extracto
             and cli.cod_extracto = et.cod_extracto
             and cli.cod_persona  = c.cod_persona
             and cli.fec_extracto = v_fec_actual
             and et.nro_cuenta = c.nro_cuenta;
        exception
          when no_data_found then v_dato := 'N';
        end;
      else
        -- Busca si Generó Extracto
        begin
          select distinct 'S'
            into v_dato
            from ge_ext_clientes cli,
                 ge_ext_cli_cuentas et
           where cli.cod_persona  = et.cod_persona
             and cli.fec_extracto = et.fec_extracto
             and cli.fre_extracto = et.fre_extracto
             and cli.cod_extracto = et.cod_extracto
             and cli.cod_persona  = c.cod_persona
             and cli.fec_extracto = v_fec_ult_extracto
             and et.nro_cuenta = c.nro_cuenta;
        exception
          when no_data_found then v_dato := 'N';
        end;
      end if;
      --
      if nvl(v_dato,'N') = 'S' then
        v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
        --
        v_nombre := 'ex_'||lpad(c.cod_persona, 7, '0' )||'_'||c.nro_cuenta||'.xls';
        v_asunto := 'Extracto de la Cuenta Nro. '||c.nro_cuenta;
        v_contenido := 'Adjunto archivo conteniendo los datos de la Cuenta Nro. '||
                       c.nro_cuenta||
                       chr(13)||chr(13)||fug_obt_nom_entidad||' Extracto.'||chr(13);
        begin
          --**
          conn := it_mail.begin_mail(v_dir_correo_de, c.mail, v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
          it_mail.attach_text(conn,v_contenido,'text/plain');
          it_mail.begin_attachment(conn,'text/plain',false,v_nombre);
          --**

          -- Formato General tipo XLS
          if nvl(v_mensual,'N') = 'N' then
            -- Si no es Mensual --
            v_dato := fug_gen_ext_ascii(c.cod_persona,c.nro_cuenta,'S',conn);
          else
            -- Si es Mensual --
            v_dato := fug_gen_ext_asc_mes(c.cod_persona,c.nro_cuenta,'S',v_fec_ult_extracto,c.fre_extracto,conn);
          end if;
          --**
          it_mail.end_mail(conn);
          --**
        exception
--          when others then
--            it_mail.end_session(conn);
          when utl_smtp.transient_error
            or utl_smtp.permanent_error then
              begin
                  utl_smtp.quit(conn);
              exception
                when utl_smtp.transient_error or
                     utl_smtp.permanent_error then
                null;
              end;
            v_det_error := substr(sqlerrm,1,4000);
          when others then
            begin
                utl_smtp.quit(conn);
            exception
              when utl_smtp.transient_error or
                   utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
        end;
        --
        begin
          -- Formato Especial tipo TXT
          if nvl(c.formato,'N') = 'S' then
            v_nombre := 'ex_'||lpad(c.cod_persona, 7, '0' )||'_'||c.nro_cuenta||'.txt';
            --**
            conn := it_mail.begin_mail(v_dir_correo_de, c.mail, v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
            it_mail.attach_text(conn,v_contenido,'text/plain');
            it_mail.begin_attachment(conn,'text/plain',false,v_nombre);
            --**
            if nvl(v_mensual,'N') = 'N' then
              -- Si no es Mensual --
              v_dato := fug_gen_ext_ascii(c.cod_persona,c.nro_cuenta,'N',conn);
            else
              -- Si es Mensual --
              v_dato := fug_gen_ext_asc_mes(c.cod_persona,c.nro_cuenta,'N',v_fec_ult_extracto,c.fre_extracto,conn);
            end if;
            --**
            it_mail.end_mail(conn);
            --**
          end if;
        exception
--          when others then
--            it_mail.end_session(conn);
          when utl_smtp.transient_error
            or utl_smtp.permanent_error then
              begin
                  utl_smtp.quit(conn);
              exception
                when utl_smtp.transient_error or
                     utl_smtp.permanent_error then
                null;
              end;
            v_det_error := substr(sqlerrm,1,4000);
          when others then
            begin
              utl_smtp.quit(conn);
            exception
              when utl_smtp.transient_error or
                   utl_smtp.permanent_error then
              null;
            end;
            v_det_error := substr(sqlerrm,1,4000);
        end;
        --
        v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      else
        v_asunto := 'Extracto fecha '||nvl(v_fec_ult_extracto,v_fec_actual)||' sin Datos. ';
      end if;
    else
      v_asunto := 'No impreso, extracto de frecuencia '||v_fre_extracto;
    end if;
    --
    insert into ge_log_mail
     (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
    values
     (sysdate, c.cod_persona, substr(c.mail,1,255), v_asunto, v_det_error, c.nro_cuenta, v_hor_inicio, v_hor_fin);
    --
    commit;
    --
  end loop;
exception
  when others then
    raise_application_error(-20000,'Error al Generar Extracto. '||sqlerrm);
end;
/

