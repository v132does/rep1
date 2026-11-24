CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_CON_INF_BATCH(
p_cod_ente ge_entes.cod_ente%type default null,
p_fecha date default null
)is
  v_fec_actual      date  default pag_cal.fu_obt_fec_actual(1);
  v_nom_ente        ge_entes.descripcion%type;
  v_dir_mail_deb    ge_par_entes.val_parametro%type;
  v_tip_envio       ge_par_entes.val_parametro%type;
  v_ext_archivo     ge_par_entes.val_parametro%type;
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'info@correo.com';
  v_texto           varchar2(4000);
  v_texto_detalle   varchar2(32000);
  v_adjunto         varchar2(32000);
  v_cabecera        clob;
  v_nom_adj         varchar2(500);
  v_total_procesado number ;
  v_line            VARCHAR2(32767);
  v_file            UTL_FILE.FILE_TYPE;
  v_name            VARCHAR2(128);-- nombre del archivo
  v_cantidad        number(18):=0;
  v_hora            varchar2(12);
  v_error           varchar2(3000);
  -- Variables para mail
  v_conn            utl_smtp.connection;
  v_asunto          VARCHAR2(2000);
  v_mje_mail        LONG;
  -- FTP
  v_hini_ftp        ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp        ge_ra_log_ftp.hor_fin%type;
  v_respuesta       VARCHAR2(4000);
  v_nom_cli_debito  varchar2(100);
  /* -- Variables coneccion*/
  v_repository      VARCHAR2(100);
  g_ip              VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port            VARCHAR2(100) := '21';
  g_user            VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass            VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_directorio      VARCHAR2(100);
  v_fec_ant48 ge_inf_cob_batch.fec_archivo%type := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ANT_HAB(nvl(p_fecha, v_fec_actual), 1), 1);
  --v_formato         varchar2(10):='N';
  --v_tip_conciliacion VARCHAR2(10);
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
CURSOR g_ente is
    select a.cod_ente,a.cod_persona,b.val_minimo nro_cta, p.nom_completo 
      from ge_entes a, ba_cod_referencias b, ba_personas p
        where a.tipo='CI'
          and a.cod_persona=b.val_maximo
          AND B.DOMINIO='NRO_CTA_ENV_CON_INF_COB'
          and a.cod_ente= nvl(p_cod_ente,a.cod_ente)
          and a.cod_persona = p.cod_persona
          order by  b.val_minimo;
--****** Tarjetas de Debito
CURSOR c_rec(v_nro_cuenta ge_cuentas.nro_cuenta%TYPE) is
  select decode (c.fec_archivo, d.fec_acreditacion, 'TARJETA DEBITO',  'EFECTIVO/TDC') tipo,
                 d.nro_transaccion, to_char(d.fec_cobro, 'dd/mm/yyyy') fec_cobro,
                 d.hor_referencia, d.dat_adicional, to_char(c.fec_proceso, 'dd/mm/yyyy') fec_proceso, d.hor_credito,
                 d.mto_facturador mto_factura, nvl(d.monto, 0)- nvl(d.mto_facturador,0) mto_comision, nvl(d.monto,0) tot_transaccion, 
                 c.nro_cuenta, to_char(fec_acreditacion, 'dd/mm/yyyy') fec_acreditacion
            from ge_inf_cob_batch c, ge_inf_cob_batch_det d
           where c.nro_cuenta = v_nro_cuenta
             and d.fec_acreditacion = nvl(p_fecha, v_fec_actual)
             and c.nro_proceso = d.nro_proceso
             and d.nom_archivo = 'MOVIMIENTO'
           order by nro_transaccion;

  FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2
   ) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
   BEGIN
      IF p_cadena IS NOT NULL THEN
         v_cadena := translate(p_cadena,
                  'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
                  'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
         v_cadena := translate(v_cadena,
                  'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                  'aeiouAEIOUAaDO     a  o  y yAa                           ');
         v_cadena := translate(v_cadena,
                  '''',
                  '  ');
      END IF;
      RETURN(v_cadena);
   END;

  Function fu_val_correo(p_mail VARCHAR2) RETURN VARCHAR2 IS
      v_mail         VARCHAR2(319) := lower(p_mail);
      v_nom_usuario  VARCHAR2(64);
      v_nom_dominio  VARCHAR2(254);
      v_caracter     VARCHAR2(1);
      v_posicion     NUMBER(3);
      v_car_invalido NUMBER(3);
      v_con_caracter NUMBER(3) := 0;
      --
      v_pos_coma     NUMBER(3);
      v_pos_punto    NUMBER(3);
   BEGIN
      --- Identificar el primer correo
      v_pos_punto    := instr(v_mail, ';'); -- hasta el punto y coma
      v_pos_coma     := instr(v_mail, ','); -- hasta la coma
      IF v_pos_punto = 0 and v_pos_coma = 0 THEN
         v_posicion := length(v_mail);
      ELSIF v_pos_coma = 0 THEN
         v_posicion := v_pos_punto - 1;
      ELSIF v_pos_punto = 0 THEN
         v_posicion := v_pos_coma - 1;
      ELSIF v_pos_coma > v_pos_punto THEN
         v_posicion := v_pos_punto - 1;
      ELSIF v_pos_punto > v_pos_coma THEN
         v_posicion := v_pos_coma - 1;
      ELSE -- Contiene solo 1 correo
         v_posicion := length(v_mail);
      END IF;
      v_mail := substr(v_mail, 1, v_posicion);
      --
      v_posicion    := instr(v_mail, '@');
      v_nom_usuario := substr(v_mail, 1, instr(v_mail, '@') - 1);
      v_nom_dominio := substr(v_mail, instr(v_mail, '@') + 1);
      ---
      /*
      || Dominios Genéricos
      || ==================
      || .com .net .org
      || .mil .gov .edu .int .coop
      || .info .biz
      || .mobi
      */
      IF instr(v_nom_dominio,'.com',1) > 0 OR
         instr(v_nom_dominio,'.net',1) > 0 OR
         instr(v_nom_dominio,'.org',1) > 0 OR
         instr(v_nom_dominio,'.mil',1) > 0 OR
         instr(v_nom_dominio,'.gov',1) > 0 OR
         instr(v_nom_dominio,'.edu',1) > 0 OR
         instr(v_nom_dominio,'.int',1) > 0 OR
         instr(v_nom_dominio,'.biz',1) > 0 OR
         instr(v_nom_dominio,'.coop',1) > 0 OR
         instr(v_nom_dominio,'.info',1) > 0 OR
         instr(v_nom_dominio,'.mobi',1) > 0 THEN
         null;
      ELSE
         return null;
      END IF;
      v_mail := fu_eli_acentos(v_mail);
      ---
      FOR i IN 1 .. length(v_mail) LOOP
         v_caracter := substr(v_mail, i, 1);
         IF v_caracter = '@' THEN
            v_con_caracter := v_con_caracter + 1;
         END IF;
      END LOOP;
      ---
      IF v_posicion <= 1 OR
         v_posicion = length(v_mail) OR
         v_con_caracter > 1 THEN
         return null;
      ELSIF substr(v_nom_usuario, 1, 1) = '.' OR
            substr(v_nom_usuario, length(v_nom_usuario), 1) = '.' THEN
         return null;
      ELSIF substr(v_nom_dominio, 1, 1) = '.' OR
            substr(v_nom_dominio, length(v_nom_dominio), 1) = '.' OR
            instr(v_nom_dominio, '.') = 0 THEN
         return null;
      ELSIF v_car_invalido > 0 THEN
         return null;
      ELSIF instr(v_mail, '..') > 0 THEN
         return null;
      ELSIF length(v_nom_usuario) > 64 THEN
         return null;
      ELSIF length(v_nom_dominio) > 255 THEN
         return null;
      END IF;
      RETURN v_mail;
   END;
begin
  v_hora:= to_char(sysdate,'hh24:mi:ss');


  --Si fecha es nula es proceso de Cierre, o si la fecha es la actual, se toma de ge_movimientos
-- p_fecha is null or trunc(p_fecha)= trunc(v_fec_actual) then
  for a in g_ente loop
       --v_tip_conciliacion:=null;
       v_repository:= null;
       v_directorio:= null;
        ---******** Datos Comunes para TC y TD
       -- Lo demas
       v_repository:= fug_obt_parentes(a.cod_ente,'DIR_REP_ARCHIVO_CI');--'MAIL';
       v_directorio:= fug_obt_parentes(a.cod_ente,'DIR_DEP_ARCHIVO_CI');--'ramail\DYD\';
       v_nom_ente        := fue_obt_nom_ente(a.cod_ente);
       v_dir_mail_deb    := fug_obt_parentes(a.cod_ente,'DIR_MAIL_CI');
       v_tip_envio      := nvl(fug_obt_parentes(a.cod_ente,'TIP_ENV_ARCHIVO_CI'),'M');
       v_ext_archivo    := nvl(fug_obt_parentes(a.cod_ente,'TIP_ARCHIVO_CI'),'txt');
       -- Tipo de Archivo
       if v_ext_archivo is not null then
           if lower(v_ext_archivo) != 'xls' or lower(v_ext_archivo) != 'txt' or lower(v_ext_archivo) != 'csv' then
             if lower(v_ext_archivo) like '%xls%' then
               v_ext_archivo := 'xls';
             end if;
             if lower(v_ext_archivo) like '%txt%' then
               v_ext_archivo := 'txt';
             end if;
             if lower(v_ext_archivo) like '%csv%' then
               v_ext_archivo := 'csv';
             end if;
           end if;
           if v_ext_archivo not in ('xls','txt', 'csv') then
             v_ext_archivo := 'xls';
           end if;
       else
          v_ext_archivo := 'xls';
       end if;
         
       --Seteos iniciales
       v_texto_detalle := null;
       v_adjunto       := null;
       v_total_procesado := 0;  --Seteos iniciales
       /**********Logica para TARJETAS DE DEBITO O AMBOS***********************/
       --Para depositar Archivo
       IF nvl(v_tip_envio,'M') = 'A' THEN
           -- ENVIO FTP
           v_line := null;
           v_name := 'CON_INF_' || a.nro_cta || '_' ||
                           to_char(v_fec_actual, 'DDMMYY');
           v_name:=lower(v_name);
           if v_directorio is null then
              --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
              insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (c_dir_mail, v_dir_mail_deb,'CONC.INF.COB.BATCH', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado Directorio parametrizado', sysdate, user);
           end if;
           if v_repository is null then
              --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
              insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (c_dir_mail, v_dir_mail_deb,'CONC.INF.COB.BATCH', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado Repositorio parametrizado', sysdate, user);
           end if;
            -- Abrir archivo
           if v_repository is not null and v_directorio is not null then
                v_file := UTL_FILE.FOPEN(v_repository,
                                        lower(v_name) || '.'||lower(v_ext_archivo),
                                        'W',
                                        32767);
           end if;
        --
        elsIF nvl(v_tip_envio,'M') = 'M' THEN
           --DYDMR-6621 Se excluye verificación para permitir mas de unas dirección de Email
           --v_dir_mail_deb        := fu_val_correo(v_dir_mail_deb);
           v_dir_mail_deb        := trim(v_dir_mail_deb);
           if v_dir_mail_deb is null then
               --Si esta nulo se toma se guarda error
               insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
               values (c_dir_mail, v_dir_mail_deb,'CONCILIACION INFONET COBRANZAS BATCH', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado direccion de mail', sysdate, user);
           end if;

       END IF;

       if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
           v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fec. Lote ' || chr(9) || 'Tipo' || chr(9) || 'Nro Transacción' || chr(9) ||
                         'Fecha de Cobro' || chr(9) ||'Hora' || chr(9) ||
                         'Monto Facturador' || chr(9) || 'Monto Comisión'|| chr(9) || 'Total Factura' ||chr(9)||'Fec. Acreditacion'||chr(10);
       elsif  nvl(lower(v_ext_archivo),'xls') = 'csv' then
           v_cabecera := 'Nro.Cuenta' || ';' || 'Fec. Lote ' || ';' || 'Tipo' || ';' || 'Nro Transacción' || ';' ||
                         'Fecha de Cobro' || ';' ||'Hora' || ';' ||
                         'Monto Facturador' || ';' || 'Monto Comisión'|| ';' || 'Total Factura' || ';' ||'Fec. Acreditacion'||chr(10);
       elsif nvl(lower(v_ext_archivo),'xls') = 'txt' then
           v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fec. Lote',10,' ')|| rpad('Tipo',35,' ')  ||
                         rpad('Nro. Transaccion',20,' ')  || rpad('Fec. Cobro',10,' ')|| rpad('Hora',10,' ')  || lpad('Monto Facturador',20,' ')  ||
                         lpad('Monto Comisión',20,' ')  ||lpad('Total Factura',20,' ')||rpad('Fec. Acr.',10,' ')
                         || chr(13) || chr(10);
       end if;
       
       declare
         v_tipo varchar2(30);
         v_monto number;
         v_mto_comision number;
         v_mto_factura number;
         v_cantidad number;
         v_tipo_48 varchar2(30);
         v_monto_48 number;
         v_mto_comision_48 number;
         v_mto_factura_48 number;
         v_cantidad_48 number;
         v_fec_lote ge_inf_cob_batch.fec_archivo%type;
       begin
         begin
           select 'TDD' tipo,  sum(d.mto_facturador) mto_factura, sum(monto) monto,
                  sum(nvl(d.monto, 0)- nvl(d.mto_facturador,0)) mto_comision,
                  count(*) cantidad
             into v_tipo, v_mto_factura, v_monto, v_mto_comision, v_cantidad
             from ge_inf_cob_batch c, ge_inf_cob_batch_det d
            where c.nro_cuenta = a.nro_cta
              and d.fec_acreditacion = nvl(p_fecha, v_fec_actual)
              and d.cod_tra_padre <> 227
              and c.nro_proceso = d.nro_proceso
              and d.nom_archivo = 'MOVIMIENTO'
            order by nro_transaccion;
          exception
            when others then
              v_tipo := null;
          end;
               
          begin
            select 'TDC' tipo,  sum(d.mto_facturador) mto_factura, sum(monto) monto,
                    sum(nvl(d.monto, 0)- nvl(d.mto_facturador,0)) mto_comision,
                    count(*) cantidad
               into v_tipo_48, v_mto_factura_48, v_monto_48, v_mto_comision_48, v_cantidad_48 
               from ge_inf_cob_batch c, ge_inf_cob_batch_det d
              where c.nro_cuenta = a.nro_cta
                and d.fec_acreditacion = nvl(p_fecha, v_fec_actual)
                and d.cod_tra_padre = 227
                and c.nro_proceso = d.nro_proceso
                and d.nom_archivo = 'MOVIMIENTO'
              order by nro_transaccion;
           exception
              when others then
                 v_tipo_48 := null;
           end;
           
           if v_tipo_48 is not null then
             v_texto := '<br><br>
                     <br><br>
                       Estimado Cliente: '|| upper(a.nom_completo) ||'
                     <br><br>
                       Adjunto encontrar&aacute; el archivo de detalle de operaciones acreditadas en fecha ' || to_char(nvl(p_fecha, v_fec_actual), 'DD/MM/YYYY') ||' por el cobro de sus facturas en la Red Infonet Cobranzas.'||
                     '<br><br>
                      Medio de Pago: Tarjeta de d&eacute;bito/D&eacute;bito en cuenta
                      <br>
                      Cantidad: '||v_cantidad||'<br>
                      Importe Acreditado: '|| to_char(v_monto, '999G999G999G999')||'<br>
                      Fecha Lote: '||to_char(nvl(p_fecha, v_fec_actual), 'DD/MM/YYYY')||'
                     <br><br>
                      Medio de Pago: Efectivo/Cheque/Tarjeta de Cr&eacute;dito
                      <br>
                      Cantidad: '||v_cantidad_48||'<br>
                      Importe Acreditado: '|| to_char(v_monto_48, '999G999G999G999')||'<br>
                      Fecha Lote: '||to_char(v_fec_ant48, 'DD/MM/YYYY')||'
                     <br><br>
                       Atentamente.
                     <br><br>
                     <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                     <br><br>
                     <br><br>';
           else
             v_texto := '<br><br>
                     <br><br>
                       Estimado Cliente: '|| upper(a.nom_completo) ||'
                     <br><br>
                       Adjunto encontrar&aacute; el archivo de detalle de operaciones acreditadas en fecha ' || to_char(nvl(p_fecha, v_fec_actual), 'DD/MM/YYYY') ||' por el cobro de sus facturas en la Red Infonet Cobranzas.'||
                     '<br><br>
                      Medio de Pago: Tarjeta de d&eacute;bito/D&eacute;bito en cuenta
                      <br>
                      Cantidad: '||v_cantidad||'<br>
                      Importe Acreditado: '|| to_char(v_monto, '999G999G999G999')||'<br>
                      Fecha Lote: '||to_char(nvl(p_fecha, v_fec_actual), 'DD/MM/YYYY')||'
                     <br><br>
                       Atentamente.
                     <br><br>
                     <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                     <br><br>
                     <br><br>';
           end if;
        end;

        v_nom_adj := lower('CON_INF_' || a.nro_cta || '_' ||to_char(v_fec_actual, 'DDMMYY'));

        v_asunto   := 'Servicio de Conciliacion Operaciones de Infonet';
        v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                          chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;
        IF nvl(v_tip_envio,'M') = 'M' THEN
          if v_dir_mail_deb  is not null then
              --********** Logica para envio por email de los archivos ******************
              Begin
                v_conn     := it_mail.begin_mail(c_dir_mail,
                                                 v_dir_mail_deb,
                                                 v_asunto,
                                                 IT_MAIL.MULTIPART_MIME_TYPE);

                it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                it_mail.begin_attachment(v_conn,
                                         'text/plain',
                                         false,
                                         v_nom_adj ||'.'||lower(v_ext_archivo));
                 --*********Para Grabar Cabecera ***************************************
                 if nvl(lower(v_ext_archivo),'xls') = 'txt' then
                        v_texto_detalle := CHR(9) || CHR(9) ||CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE OPERACIONES INFONET' || chr(13) || chr(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                 v_cabecera;
                        it_mail.write_text(v_conn, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') in ('xls', 'csv') then
                        v_texto_detalle := CHR(9) || CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE OPERACIONES INFONET' || chr(13) || chr(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera;
                        it_mail.write_text(v_conn, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                for w in c_rec(a.nro_cta) loop
                  --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                  v_total_procesado := v_total_procesado + 1;
                  if nvl(lower(v_ext_archivo),'xls') = 'xls' then
                     v_adjunto:=null;
                     v_adjunto := w.nro_cuenta || chr(9) ||
                                  w.fec_acreditacion || chr(9)||
                                  w.tipo || chr(9)||
                                  w.nro_transaccion || chr(9) ||
                                  w.fec_cobro || chr(9) || w.hor_referencia ||chr(9) ||
                                  w.mto_factura || chr(9) || w.mto_comision || chr(9) ||
                                  w.tot_transaccion || chr(9) || w.fec_proceso ||chr(9) ||chr(10); --Nro Lote
                  elsif nvl(lower(v_ext_archivo),'xls') = 'csv' then
                     v_adjunto:=null;
                     v_adjunto := w.nro_cuenta || ';' ||
                                  w.fec_acreditacion || ';' ||
                                  w.tipo || ';' ||
                                  w.nro_transaccion || ';' ||
                                  w.fec_cobro || ';' || w.hor_referencia || ';' ||
                                  w.mto_factura || ';' || w.mto_comision || ';' ||
                                  w.tot_transaccion || ';' || w.fec_proceso || ';' ||chr(10); --Nro Lote
                  elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                      --v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                      --v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                      v_adjunto:=null;
                      v_adjunto := rpad(w.nro_cuenta,20,' ') ||
                                   rpad(w.fec_acreditacion,10,' ') ||
                                   rpad(w.tipo,35,' ') ||
                                   rpad(w.nro_transaccion,20,' ') ||
                                   rpad(w.fec_cobro,10,' ') ||
                                   rpad(w.hor_referencia,10,' ') ||
                                   lpad(w.mto_factura,20,' ') ||
                                   lpad(w.mto_comision,20,' ') ||
                                   lpad(w.tot_transaccion,20,' ')||
                                   rpad(w.fec_proceso,10,' ') || CHR(13) || CHR(10); --Nro Lote
                   end if;
                   it_mail.write_text(v_conn, v_adjunto);
                 end loop;
                 --************fin de Grabar Detalle **************************************
                 --Se inserta el pie de archivo
                 v_texto_detalle := chr(10)||
                 chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_total_procesado|| chr(13) || chr(10);
                 it_mail.write_text(v_conn, v_texto_detalle);

                 it_mail.end_mail(v_conn);

             EXCEPTION
                 when others then
                       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                        values (c_dir_mail, v_dir_mail_deb, v_asunto, v_texto, sysdate, user);
             END;
          end if;
          --********** fin de Logica para envio por email de los archivos ******************
      ELSE
         if v_repository is not null and v_directorio is not null then
            --*****************Para Depositar en archivo**********************
             Begin
                --*********Para Grabar Cabecera ***************************
                 if nvl(lower(v_ext_archivo),'xls') = 'txt' then
                        v_texto_detalle := CHR(9) || CHR(9) || CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE OPERACIONES DE INFONET'|| chr(13) || chr(10);
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                           v_cabecera;
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') in ('xls', 'csv') then
                       v_texto_detalle := CHR(9) || CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE OPERACIONES DE INFONET';
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera;
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                /*--- DYDMR-7942 18/12/2017 ---*/
                -- Punto para la parte decimal y coma para separador de miles.
                pre_cam_for_numerico('.,');
                for w in c_rec(a.nro_cta) loop
                     v_total_procesado := v_total_procesado + 1;
                    --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                        --No facturador -> Referencia Nulo actualmente
                        if  nvl(lower(v_ext_archivo),'xls') = 'xls' then 
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                                  w.fec_acreditacion || chr(9)||
                                  w.tipo || chr(9)||
                                  w.nro_transaccion || chr(9) ||
                                  w.fec_cobro || chr(9) || w.hor_referencia ||chr(9) ||
                                  w.mto_factura || chr(9) || w.mto_comision || chr(9) ||
                                  w.tot_transaccion ||chr(9)||w.fec_proceso ||chr(9); --Nro Lote; --Nro Lote
                        elsif nvl(lower(v_ext_archivo),'xls') = 'csv' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || ';' ||
                                  w.fec_acreditacion || ';' ||
                                  w.tipo || ';' ||
                                  w.nro_transaccion || ';' ||
                                  w.fec_cobro || ';' || w.hor_referencia || ';' ||
                                  w.mto_factura || ';' || w.mto_comision || ';' ||
                                  w.tot_transaccion || ';' ||w.fec_proceso || ';' ; --Nro Lote; --Nro Lote                          
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                             --_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                             --_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fec_acreditacion,10,' ') ||
                              rpad(w.tipo,35,' ') ||
                              rpad(w.nro_transaccion,20,' ') ||
                              rpad(w.fec_cobro,10,' ') ||
                              rpad(w.hor_referencia,10,' ') ||
                              lpad(w.mto_factura,20,' ') ||
                              lpad(nvl(w.mto_comision, 0),20,' ') ||
                              lpad(w.tot_transaccion,20,' ')||
                              rpad(w.fec_proceso,10,' ')|| CHR(13) || CHR(10); --Nro Lote
                       end if;
                     UTL_FILE.PUT_LINE(v_file, v_adjunto);
                 end loop;
                 --************fin de Grabar Detalle **************************************
                 --Se inserta el pie de archivo
                 v_texto_detalle := chr(10)||
                 chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_total_procesado|| CHR(13) || CHR(10);
                 UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
            EXCEPTION
                 when others then
                       v_hora:= to_char(sysdate,'hh24:mi:ss');
                       v_error:= substr(to_char(sqlerrm),1,3000);
                       INSERT INTO ge_ra_log_mail
                           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                          VALUES
                           (SYSDATE, v_nom_adj, 'ERROR', 'Envio Con.Infonet Cobranza ', v_error,v_hora , v_hora);

             END;

             if nvl(lower(v_ext_archivo),'xls') = 'txt' then
                    --Cerrar el handler al fichero
                    UTL_FILE.FCLOSE(v_file);
                    COMMIT;
                    v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
                    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
                    v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                                            g_port,
                                                            g_user,
                                                            g_pass,
                                                            v_repository,
                                                            lower(v_name) || '.'||lower(v_ext_archivo),
                                                            lower(v_directorio) || lower(v_name)|| '.'||lower(v_ext_archivo));
                     v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
                     IF v_respuesta <> 'OK' THEN
                          -- Insertamos el error del envio al directorio compartido
                          INSERT INTO ge_ra_log_ftp
                            (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
                          VALUES
                            (SYSDATE,
                             v_name,
                             v_respuesta,
                             v_hini_ftp,
                             v_hfin_ftp);
                     end if;
                     COMMIT;
              else
                    -- xls
                    --Cerrar el handler al fichero
                    UTL_FILE.FCLOSE(v_file);
                    COMMIT;
                  v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
                    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
                    v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                                            g_port,
                                                            g_user,
                                                            g_pass,
                                                            v_repository,
                                                            lower(v_name) || '.'||lower(v_ext_archivo),
                                                            lower(v_directorio) || lower(v_name)|| '.'||lower(v_ext_archivo));

                     v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
                     IF v_respuesta <> 'OK' THEN
                        -- Insertamos el error del envio al directorio compartido
                        INSERT INTO ge_ra_log_ftp
                          (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
                        VALUES
                          (SYSDATE,
                           v_name,
                           v_respuesta,
                           v_hini_ftp,
                           v_hfin_ftp);
                     end if;
                    COMMIT;
              end if;
        end if;
     end if;


end loop;
--*********************************************************************************************************
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
  WHEN OTHERS THEN
     raise_application_error(-20000,'PRG_GEN_ARC_CON_INF_BATCH '||sqlerrm);
END PRG_GEN_ARC_CON_INF_BATCH;
/

