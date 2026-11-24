create or replace procedure it.prb_arc_con_cidesa is
  --cursor de cuentas
  cursor c_cuentas is
    select a.nro_cuenta nro_cuenta,
           a.libro libro, 
           count(*) can_mov,
           min(a.fecha) fec_ini,
           max(a.fecha) fec_fin
      from cb_inf_con_tmp a
     where instr(fug_obt_pardinamico('EXC_CTA_INF_CORRESPONSAL'), ','||a.nro_cuenta||',') = 0 -- Excluir Cuentas Operativas - Pedido de José Sala 29/04/2015  
     group by a.nro_cuenta, a.libro
     order by 1,2;
     
  --cursor de cabecera de Movimientos
  cursor c_cab_mov(p_nro_cuenta varchar2,p_fec_inicio date, p_fec_anterior date, p_cod_mon_local varchar2) is
    select distinct 'I' mov,fug_obt_cod_entidad cod_banco, lpad(g.cod_banco,4,0) cod_ban_conciliar
    ,
    lpad(decode(nvl(c.saldo_ant,0),0,'+',decode(abs(c.saldo_ant),c.saldo_ant,'-','+'))
    ||
    TRUNC(nvl(abs(c.saldo_ant),0)),13,CHR(32))||'.'||
    substr(rpad(nvl(abs(c.saldo_ant),0) - trunc(nvl(abs(c.saldo_ant),0)),3,0),-2) sal_inicial
    ,
    lpad(decode(nvl(c.saldo_act,0),0,'+',decode(abs(c.saldo_act),c.saldo_act,'-','+'))
    ||
    TRUNC(nvl(abs(c.saldo_act),0)),13,CHR(32))||'.'||
    substr(rpad(nvl(abs(c.saldo_act),0) - trunc(nvl(abs(c.saldo_act),0)),3,0),-2) sal_final
    ,to_char(p_fec_inicio,'ddmmyyyy') fec_inicio
    --,p_fec_inicio fec_inicio
    ,decode(cc.cod_moneda,p_cod_mon_local,'6900','USD','6100','EUR','6300') cod_mon_cidesa
    , 7 cod_bco_central,cc.cod_moneda,cc.cod_modalidad,'I','D'
    from
      ge_bancos g, cc_cta_bancarias cc,
    (select cc.cod_banco,cc.nro_cuenta, sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,p_fec_inicio,cc.cod_moneda),0) +
           nvl(FUB_OBT_SAL_CONTABLE(fug_obt_paradicional(cc.nro_cuenta,'COD_RUB_SOB_CTA_BAN'),p_fec_inicio,cc.cod_moneda),0)))saldo_act,
           sum((nvl(FUB_OBT_SAL_CONTABLE(CC.Cod_Rubro,to_date(to_char(p_fec_anterior,'dd/mm/yyyy'),'dd/mm/yyyy'),cc.cod_moneda),0) +
           nvl(FUB_OBT_SAL_CONTABLE(fug_obt_paradicional(cc.nro_cuenta,'COD_RUB_SOB_CTA_BAN'),p_fec_anterior,cc.cod_moneda),0)))saldo_ant
           from cc_cta_bancarias cc
           --where cc.cod_modalidad=455
           group by cc.cod_banco,cc.nro_cuenta
           )c
    where c.nro_cuenta(+)=cc.nro_cuenta
      and g.cod_banco = cc.cod_banco
      and cc.cod_banco = c.cod_banco
    --and cc.cod_modalidad = '455'
    and cc.nro_cuenta = p_nro_cuenta;
      
  --cursor de cabecera de Extractos    
  cursor c_cab_ext(p_nro_cuenta varchar2,p_fec_inicio date, p_fec_fin date, p_cod_mon_local varchar2) is
    select distinct 'I' mov,g.cod_banco cod_banco, lpad(fug_obt_cod_entidad,4,0) cod_ban_conciliar
    ,
    lpad( decode(nvl(c.saldo_ant,0),0,'+',decode(abs(c.saldo_ant),c.saldo_ant,'+','-'))
    ||
    TRUNC(nvl(abs(c.saldo_ant),0)),13,CHR(32))||'.'||
    substr(rpad(nvl(abs(c.saldo_ant),0) - trunc(nvl(abs(c.saldo_ant),0)),3,0),-2) sal_inicial
    ,
    lpad( decode(nvl(c.saldo_act,0),0,'+',decode(abs(c.saldo_act),c.saldo_act,'+','-'))
    ||
    TRUNC(nvl(abs(c.saldo_act),0)),13,CHR(32))||'.'||
    substr(rpad(nvl(abs(c.saldo_act),0) - trunc(nvl(abs(c.saldo_act),0)),3,0),-2) sal_final
    ,to_char(p_fec_inicio,'ddmmyyyy') fec_inicio
    ,decode(cc.cod_moneda,p_cod_mon_local,'6900','USD','6100','EUR','6300') cod_mon_cidesa
    , 7 cod_bco_central,cc.cod_moneda,cc.cod_modalidad,'I','D'
    from
      ge_bancos g, cc_cta_bancarias cc,
    ( select x.nro_cuenta, 
       sum(x.saldo_act) saldo_act,
       sum(x.saldo_ant) saldo_ant
      from ( 
            select e.nro_cuenta,
                   0 saldo_act,
                   e.sal_anterior saldo_ant
              from ge_ext_swift e
             where e.fec_mensaje = p_fec_inicio 
               and e.nro_secuencia = ( select min(nro_secuencia) 
                                         from ge_ext_swift ext
                                        where ext.nro_cuenta = e.nro_cuenta
                                          and ext.fec_mensaje = e.fec_mensaje
                                      )
            union                          
            select e.nro_cuenta,
                   e.sal_actual saldo_act,
                   0 saldo_ant
              from ge_ext_swift e
             where e.fec_mensaje = p_fec_fin
               and e.nro_secuencia = ( select max(nro_secuencia) 
                                         from ge_ext_swift ext
                                        where ext.nro_cuenta = e.nro_cuenta
                                          and ext.fec_mensaje = e.fec_mensaje
                                      )
            ) x                                                    
            group by x.nro_cuenta
     ) c
    where c.nro_cuenta(+)=cc.nro_cuenta
      and g.cod_banco = cc.cod_banco
    and cc.nro_cuenta = p_nro_cuenta;
            
  --cursor del contenido del archivo a generar--
  cursor c_cursor(p_nro_cuenta varchar2, p_tipo in varchar2) is
    select a.libro,
           a.nro_cuenta,
           a.cod_moneda,
           a.nro_documento,
           a.tipo,
           --a.monto,
           replace(lpad(trunc(nvl(abs(a.monto),0)),13,chr(32)),chr(32),'0')||'.'||substr(rpad(nvl(abs(a.monto),0) - trunc(nvl(abs(a.monto),0)),3,0),-2) monto,
           --replace(lpad(substr(nvl(a.ref_movimiento,''),1,60),60,chr(32)),chr(32),' ') ref_movimiento,
           translate(replace(lpad(substr(nvl(a.ref_movimiento,''),1,60),60,chr(32)),chr(32),' '),',/','  ') ref_movimiento,
           a.cta_monto,
           a.mov_monto,
           a.credito,
           a.debito,
           a.nro_secuencia,
           to_char(a.fecha,'ddmmyyyy') fecha,
           a.hora,
           a.cod_usuario,
           a.mov_tipo,
           a.cod_modulo,
           a.cod_modalidad,
           a.cod_rubro,
           a.nro_ref_externa,
           a.nro_conciliacion,
           --replace(lpad(nvl(a.ref_con_automatica,'0'),15,chr(32)),chr(32),'0') ref_con_automatica,
           translate(replace(lpad(nvl(a.ref_con_automatica,'0'),15,chr(32)),chr(32),'0'),',/','  ') ref_con_automatica,
           a.observacion --RE DE-1015 se agrega el campo observacion para reflejar en el archivo generado
           
      from cb_inf_con_tmp a
     where a.nro_cuenta = p_nro_cuenta
       and a.libro = p_tipo;

  --Variables--
  v_file       utl_file.file_type;
  v_line       varchar2(32767);
  v_buffer     varchar2(32767);
  v_name       varchar2(128) := ''; -- nombre del archivo, se crea dinamicamente en cursor
  v_lines      pls_integer := 0;
  v_eol        constant varchar2(1) := chr(10);
  v_separador  constant varchar2(1) := ','; --';'; --','; --chr(9);
  v_eollen     constant pls_integer := length(v_eol);
  v_maxline    constant pls_integer := 32767;
  v_fecha         varchar2(8);
  v_fec_inicio    date;
  v_fec_fin       date;
  v_fec_anterior  date;
  v_cod_mon_local ba_monedas.cod_moneda%type;
  v_cod_banco     varchar2(4);
  
  -- Variables para mail
  v_conn             utl_smtp.connection;
  v_para             varchar2(500);
  v_asunto           varchar2(2000);
  v_mje_mail         varchar2(4000);
  v_mje_mail_det     varchar2(2000) := '';
  v_hini_mail        ge_ra_log_mail.hor_inicio%type;
  v_hfin_mail        ge_ra_log_mail.hor_fin%type;
  v_det_error        ge_ra_log_mail.det_error%type;

  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
  
  v_observacion cb_inf_con_tmp.observacion%type;--RE DE-1015 
  
  function lf_obt_cod_banco( p_nro_cuenta cc_cta_bancarias.nro_cuenta%type ) return number is
    v_ret number;
  begin
    select cod_banco
    into v_ret
    from cc_cta_bancarias cc
    where cc.nro_cuenta = p_nro_cuenta;
    return v_ret;
  exception
    when others then
      return null;
  end;
BEGIN
  -- Obtenemos la fecha del sistema de contabilidad--
  v_fecha := to_char(pag_cal.fu_obt_fec_actual(2),'YYYYMMDD');
  v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
   
  --Nombre del Archivo--
   v_name:='Conciliacion-Cuentas-Corresponsales';
   for i in c_cuentas loop 
    v_fec_inicio := i.fec_ini;
    v_fec_fin := i.fec_fin;
    select pag_cal.FU_OBT_FEC_ANT_HAB (v_fec_inicio,31,1)
      into v_fec_anterior
      from dual;
    if i.libro = 'N' then -- Movimientos   
      -- Abrir archivo
      v_cod_banco := lpad(substr(to_char(fug_obt_cod_entidad),1,4),4,'0');
      v_file := utl_file.fopen(pa_rep_aut.g_repository,v_name||'_'||i.nro_cuenta||'_'||v_cod_banco||'.txt','W',32767); 
      --v_file := utl_file.fopen('/oradata/utl',v_name||'.txt','W',32767);
      for k in c_cab_mov(i.nro_cuenta, v_fec_inicio, v_fec_anterior, v_cod_mon_local) loop
        v_buffer := k.mov||v_separador||
                    k.cod_banco||v_separador||
                    k.cod_ban_conciliar||v_separador||
                    k.sal_inicial||v_separador||
                    k.sal_final||v_separador||
                    to_char(v_fec_inicio,'ddmmyyyy')||v_separador||
                    to_char(v_fec_fin,'ddmmyyyy')||v_separador||
                    k.cod_mon_cidesa||v_separador||
                    replace(lpad(i.can_mov,5,chr(32)),chr(32),'0');

        utl_file.put_line(v_file, v_buffer);
        v_lines := v_lines + 1;
      end loop;
    else -- Extracto
      -- Abrir archivo
      v_cod_banco := lpad(substr(to_char(lf_obt_cod_banco(i.nro_cuenta)),1,4),4,'0');
      v_file := utl_file.fopen(pa_rep_aut.g_repository,v_name||'_'||i.nro_cuenta||'_'||v_cod_banco||'.txt','W',32767);
      --v_file := utl_file.fopen('/oradata/utl',v_name||'.txt','W',32767);
      for k in c_cab_ext(i.nro_cuenta, v_fec_inicio, v_fec_fin, v_cod_mon_local) loop
        v_buffer := k.mov||v_separador||
                    k.cod_banco||v_separador||
                    k.cod_ban_conciliar||v_separador||
                    k.sal_inicial||v_separador||
                    k.sal_final||v_separador||
                    to_char(v_fec_inicio,'ddmmyyyy')||v_separador||
                    to_char(v_fec_fin,'ddmmyyyy')||v_separador||
                    k.cod_mon_cidesa||v_separador||
                    replace(lpad(i.can_mov,5,chr(32)),chr(32),'0');

        utl_file.put_line(v_file, v_buffer);
        v_lines := v_lines + 1;
      end loop;
    end if;
    v_buffer := null;
    --Consulta y recorre el contenido del archivo actual
    FOR rec IN c_cursor(i.nro_cuenta,i.libro) LOOP
      --RE DE-1015 
      v_observacion := NULL;
      IF ltrim(rtrim(rec.observacion)) IS NOT NULL THEN
         v_observacion := '//'||rec.observacion;
      END IF;
      --Generar la linea, agregando un separador de campo
      v_line := rec.tipo||v_separador||
                rec.fecha||v_separador||
                rec.fecha||v_separador||
                rec.ref_movimiento||v_observacion||v_separador||
                rec.ref_con_automatica||v_separador||
                rec.monto; --RE DE-1015 se agrega el campo observación por cada linea dentro del archivo
     
      IF length(v_buffer) + v_eollen + length(v_line) <= v_maxline THEN
        v_buffer := v_buffer || v_eol || v_line;
      ELSE
        IF v_buffer IS NOT NULL THEN
          --Escribes la linea en el fichero
          utl_file.put_line(v_file, v_buffer);
        END IF;
        v_buffer := v_line;
      END IF;
      v_lines := v_lines + 1;
      
      EXIT WHEN c_cursor%NOTFOUND;
    END LOOP;
    
    IF v_buffer IS NOT NULL THEN
      --Escribes la linea en el fichero
      utl_file.put_line(v_file, v_buffer);
      v_buffer := null;
    END IF;
    
    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);
    COMMIT;
--COMENTAR PARA PRUEBAS
    v_hini_ftp := to_char(sysdate,'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_binary(pa_rep_aut.g_ip, pa_rep_aut.g_port, pa_rep_aut.g_user,
                                            pa_rep_aut.g_pass, pa_rep_aut.g_repository,
                                            v_name||'_'||i.nro_cuenta||'_'||v_cod_banco||'.txt', 
                                            pa_rep_aut.g_infocidesa ||v_name||'_'||i.nro_cuenta||'_'||v_fecha||'_'||v_cod_banco||'.txt');


    v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');
--*/
    --v_respuesta := 'OK'; --DESCOMENTAR PARA PRUEBAS
    IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
      v_mje_mail_det := v_mje_mail_det|| v_name||'_'||i.nro_cuenta||'_'||v_fecha||'_'||v_cod_banco||'.txt'||v_eol;
    ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
      v_det_error    := null;
      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp(fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES(SYSDATE, v_name||'_'||i.nro_cuenta||'_'||v_fecha||'.txt', v_respuesta, v_hini_ftp, v_hfin_ftp);
      COMMIT;

      --Enviamos el mail a soporte
      -- Obtenemos direccion de correo de soporte
      v_para := pa_rep_aut.fu_obt_valor_par('RA','REPORTES','SOPORTE');

      -- Damos valor a los demas datos
      v_asunto := 'Error Informes de Conciliacion de Cuentas Corresponsal para Cidesa a la fecha '||v_fecha||'.';
      v_mje_mail := 'Error al enviar archivo por FTP. '||v_eol||v_eol||
                    'Error: '||v_respuesta||'.'||v_eol||v_eol||
                    'Para mas información verificar la tabla GE_RA_LOG_FTP.';

      v_mje_mail_det := v_name||'_'||i.nro_cuenta||'_'||v_fecha||'.txt ERROR al generar este archivo';
      v_hini_mail := to_char(sysdate,'hh24:mi:ss');

      BEGIN
        v_conn := it_mail.begin_mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
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

      -- Insertamos en la tabla de log si ocurrio algun error al enviar el mail
      IF v_det_error IS NOT NULL THEN
          INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
          VALUES(SYSDATE, v_name||'_'||i.nro_cuenta||'_'||v_fecha||'.txt', v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
          COMMIT;
      END IF;

    END IF;
    
    end loop;
    
    -- Enviamos el mail al usuario
    -- Obtenemos los direcciones de correo para quien o quienes va el correo
    v_para := pa_rep_aut.fu_obt_valor_par('RA','REPORTES','ARC_CON_CIDESA');
    -- Damos valor a los demas datos
    v_asunto := 'Informes de Conciliacion de Cuentas Corresponsal para Cidesa a la fecha '||v_fecha||'.';
    v_mje_mail := 'Los archivos con los datos del reporte lo tiene disponible en la siguiente dirección: '||
               pa_rep_aut.g_compartido||pa_rep_aut.g_infocidesa||v_eol||v_eol||
               'Archivos: '||v_mje_mail_det;

    v_det_error    := null;
    v_hini_mail    := to_char(sysdate,'hh24:mi:ss');
    BEGIN
      v_conn := it_mail.begin_mail(pa_rep_aut.g_envia_mail,v_para,v_asunto,IT_MAIL.MULTIPART_MIME_TYPE);
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
      INSERT INTO ge_ra_log_mail(fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
      VALUES(SYSDATE, substr(v_mje_mail_det,1,200), v_para, v_asunto, v_det_error, v_hini_mail, v_hfin_mail);
      COMMIT;
    END IF;
    -- fin envio de email al usuario

exception
  when utl_file.invalid_operation then
    utl_file.fclose(v_file);
    raise_application_error(-20061,'Operacion inválida '||sqlerrm);
  when utl_file.invalid_filehandle then
    utl_file.fclose(v_file);
    raise_application_error(-20062,'Manejador inválido '||sqlerrm);
  when utl_file.write_error then
    utl_file.fclose(v_file);
    raise_application_error(-20063,'Error de escritura '||sqlerrm);
  when utl_file.invalid_mode then
    utl_file.fclose(v_file);
    raise_application_error(-20064,'Modo inválido '||sqlerrm);
  when utl_file.internal_error then
    utl_file.fclose(v_file);
    raise_application_error(-20065,'Internal Error '||sqlerrm);
end;
/

