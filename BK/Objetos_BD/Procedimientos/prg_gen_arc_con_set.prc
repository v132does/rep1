CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_CON_SET(
p_fecha date default null
)is
  v_fec_actual      date  default pag_cal.fu_obt_fec_actual(1);
  v_dir_mail        ge_par_dinamicos.val_parametro%type;
  v_dir_mail_val    ge_par_dinamicos.val_parametro%type;
  v_ext_archivo     ge_par_dinamicos.val_parametro%type;
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'infobbva@bbva.com';
  v_texto           varchar2(4000);
  v_texto_detalle   varchar2(32000);
  v_adjunto         varchar2(32000);
  v_cabecera        clob;
  v_nom_adj         varchar2(500);
  v_total_procesado number ;
  v_file            UTL_FILE.FILE_TYPE;
  v_hora            varchar2(12);
  -- Variables para mail
  v_conn            utl_smtp.connection;
  v_asunto          VARCHAR2(2000);
  v_mje_mail        LONG;
  /* -- Variables coneccion*/
  v_repository      VARCHAR2(100);
  v_can_dias        number := fug_obt_pardinamico('CAN_DIA_TRA_SNP_SET');
  v_cta_bcp_460     ge_cuentas.nro_cuenta%type := fug_obt_pardinamico('NRO_CTA_CREDITO_460'); 
  v_cta_bcp_432     ge_cuentas.nro_cuenta%type:= fug_obt_pardinamico('NRO_CTA_CREDITO_432');
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  v_can_registro   number;
  v_can_con_set    number;
  v_can_registro_bbva   number;
  v_can_con_set_bbva    number;
  v_exi_inconsistencia varchar2(1);
  v_concepto       varchar2(200);

--****** Operaciones de conciliación de la set
CURSOR c_set is
  select s.fecha, to_char(d.nro_ord_transferencia) nro_ot, t.nro_referencia nro_ope_sipap, d.nro_cta_destino, r.val_maximo nro_cta_beneficiario, d.monto, 
         'BANCARD' ent_recaudadora, t.nom_solicitante beneficiario
    from ge_con_cre_ope_set s, GE_CON_CRE_OPE_SET_DET d, ge_snp_transferencias t, ba_cod_referencias r
   Where s.fecha = nvl(p_fecha, v_fec_actual) 
     and s.nro_proceso = d.nro_proceso
     and s.estado = 'F'
     and d.nro_cta_destino = t.nro_cta_solicitante
     and d.monto = t.monto
     and d.cod_moneda = t.cod_moneda
     and t.cod_modulo = 4
     and t.cod_modalidad = 455
     and t.cod_tra_padre = 303
     and t.estado = 'A'
     and s.fecha between s.fecha and fug_obt_fec_habil(s.fecha+v_can_dias-1,1)
     and r.dominio = 'COD_REL_CTA_BCP'
     and r.val_minimo = d.nro_cta_destino
   union all
    select t.fecha, p.nro_orden, t.nro_referencia nro_ope_sipap, 
           decode(p.nro_cta_bcp, 460, v_cta_bcp_460, v_cta_bcp_432), p.nro_cta_bcp nro_cta_beneficiario, p.monto, 'BBVA' ent_recaudadora,
           t.nom_solicitante beneficiario
      from ge_set_ordenes p, ge_snp_transferencias t
     Where t.fecha = nvl(p_fecha, v_fec_actual) 
       and p.estado = 'P'
       and decode(p.nro_cta_bcp, 460, v_cta_bcp_460, v_cta_bcp_432) = t.nro_cta_solicitante
       and p.monto = t.monto
       and t.cod_modulo = 4
       and t.cod_modalidad = 455
       and t.cod_tra_padre = 303
       and t.estado = 'A'
       and p.fec_pago between p.fec_pago and fug_obt_fec_habil(p.fec_pago+v_can_dias-1,1);
  
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

  v_repository:= fug_obt_pardinamico('DIR_REP_ARCHIVO_SET');--'MAIL';
  v_dir_mail    := fug_obt_pardinamico('DIR_COR_SET');
  v_ext_archivo    := nvl(fug_obt_pardinamico('EXT_ARCHIVO_SET'),'csv');
  v_dir_mail_val := fug_obt_pardinamico('DIR_COR_SET_VAL');
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
       
  v_dir_mail        := trim(v_dir_mail);
  if v_dir_mail is null then
     --Si esta nulo se toma se guarda error
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,'CONCILIACION INFONET COBRANZAS SET', 'No tiene parametrizado direccion de mail', sysdate, user);
  end if;
  --validacion bancard
  begin
    select count(*)
      into v_can_registro
      from ge_con_cre_ope_set s, GE_CON_CRE_OPE_SET_DET d, ge_snp_transferencias t
     Where s.fecha = nvl(p_fecha, v_fec_actual) 
       and s.nro_proceso = d.nro_proceso
       and s.estado = 'F'
       and d.nro_cta_destino = t.nro_cta_solicitante
       and d.monto = t.monto
       and d.cod_moneda = t.cod_moneda
       and t.cod_modulo = 4
       and t.cod_modalidad = 455
       and t.cod_tra_padre = 303
       and t.estado = 'A'
       and t.fecha between s.fecha and fug_obt_fec_habil(s.fecha+v_can_dias-1,1);
  exception
    when others then 
      v_can_registro := 0;
  end;
  
  begin
    select count(*)
      into v_can_con_set
      from ge_con_cre_ope_set s, ge_con_cre_ope_set_det d
     where s.fecha = nvl(p_fecha,v_fec_actual)
       and s.nro_proceso = d.nro_proceso
       and s.estado = 'F';
  exception
    when others then
      v_can_con_set := 0;
  end;
  
  if nvl(v_can_registro,0) = 0 then
     v_exi_inconsistencia := 'S';
     v_concepto := 'No existen acreditaciones para la SET (Entidad Recaudadora Bancard).';

     --Si esta nulo se toma se guarda error
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,'CONCILIACION INFONET COBRANZAS SET', v_concepto, sysdate, user);
  end if;
  if nvl(v_can_registro,0) <> nvl(v_can_con_set,0) and  nvl(v_can_registro,0) > 0 then
     v_exi_inconsistencia := 'S';
     v_concepto := 'Existe diferencia entre el importe de recaudaci&oacute;n en la cuenta de la SET y la transferencia del SIPAP (Entidad Recaudadora Bancard).';
     --Si esta nulo se toma se guarda error
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,'CONCILIACION INFONET COBRANZAS SET', v_concepto, sysdate, user);
  end if;

  
  --validacion BBVA
  begin
    select count(*) 
      into v_can_registro_bbva
      from ge_set_ordenes p, ge_snp_transferencias t
     Where t.fecha = nvl(p_fecha, v_fec_actual) 
       and p.estado = 'P'
       and decode(p.nro_cta_bcp, 460, v_cta_bcp_460, v_cta_bcp_432) = t.nro_cta_solicitante
       and p.monto = t.monto
       and t.cod_modulo = 4
       and t.cod_modalidad = 455
       and t.cod_tra_padre = 303
       and t.estado = 'A'
       and p.fec_pago between p.fec_pago and fug_obt_fec_habil(p.fec_pago+v_can_dias-1,1);
  exception
    when others then
      v_can_registro_bbva := 0;
  end;
 
  begin
    select count(*)
      into v_can_con_set_bbva
      from ge_set_ordenes p
     where p.fec_pago = nvl(p_fecha, v_fec_actual) 
       and p.estado = 'P';
  exception
    when others then
      v_can_con_set_bbva := 0;
  end;
  
  if nvl(v_can_registro_bbva,0) = 0 then
     v_exi_inconsistencia := 'S';
     v_concepto := 'No existen acreditaciones para la SET (Entidad Recaudadora Banco).';
     --Si esta nulo se toma se guarda error
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,'CONCILIACION INFONET COBRANZAS SET', v_concepto, sysdate, user);
  end if;
  if nvl(v_can_registro_bbva,0) <> nvl(v_can_con_set_bbva,0) and  nvl(v_can_registro_bbva,0) > 0 then
     v_exi_inconsistencia := 'S';
     v_concepto := 'Existe diferencia entre el importe de recaudaci&oacute;n en la cuenta de la SET y la transferencia del SIPAP (Entidad Recaudadora Banco).';
     --Si esta nulo se toma se guarda error
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,'CONCILIACION INFONET COBRANZAS SET', v_concepto, sysdate, user);
  end if;
  
  if nvl(v_can_registro_bbva,0) = 0 and nvl(v_can_registro,0) = 0 then
     v_exi_inconsistencia := 'S';
     v_concepto := 'No existen acreditaciones a informar a la SET.';
     --Si esta nulo se toma se guarda error
     insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
     values (c_dir_mail, v_dir_mail,'CONCILIACION INFONET COBRANZAS SET', v_concepto, sysdate, user);
  end if;
  --s.fecha, d.nro_ord_transferencia nro_ot, t.nro_referencia nro_ope_sipap, d.nro_cta_destino, t.nro_cta_beneficiario, d.monto
  if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
      v_cabecera := 'Fecha' || chr(9) || 'Nro. OT ' || chr(9) || 'Nro. Sipap' || chr(9) || 'Nro. cuenta origen' || chr(9) || 
                    '"Nro. cuenta destino' || chr(9) ||'Beneficiario'|| chr(9) ||'Monto' ||'Entidad Recaudadora'|| chr(9) ||chr(10);
  elsif  nvl(lower(v_ext_archivo),'xls') = 'csv' then
      v_cabecera := 'Fecha' || ';' || 'Nro. OT ' || ';' || 'Nro. Sipap' || ';' || 'Nro. cuenta origen' || ';' ||
                    'Nro. cuenta destino' || ';' ||'Beneficiario'|| ';' ||'Monto' || ';' ||'Entidad Recaudadora'|| ';' ||chr(10);
  elsif nvl(lower(v_ext_archivo),'xls') = 'txt' then
      v_cabecera := rpad('Fecha',10,' ') || lpad('Nro. OT',20,' ')|| lpad('Nro. Sipap',20,' ')  ||rpad('Nro. Cuenta origen',20,' ')||
                    rpad('Nro. cuenta destino',20,' ')|| rpad('Beneficiario',100,' ')||  lpad('Monto',20,' ') || rpad('Entidad Recaudadora',50,' ')|| chr(13) || chr(10);
  end if;
  
  if nvl(v_exi_inconsistencia, 'N') <> 'S' then   
    begin
      v_texto := '<br><br>
                  <br><br>
                      Estimado Cliente:
                  <br><br>
                      Adjunto encontrar&aacute; el detalle de transferencias procesadas en fecha ' || to_char( nvl(p_fecha, v_fec_actual) , 'DD/MM/YYYY') ||' a favor del Ministerio de Hacienda en concepto de recaudaci&oacute;n de tributos fiscales.'||
                  '<br><br>
                      Atentamente.
                  <br><br>
                  <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                  <br><br>
                  <br><br>';
    end;

    v_nom_adj := lower('CON_INF_SET_'||to_char(v_fec_actual, 'DDMMYY'));

    v_asunto   := 'NOTIFICACION: TRANSFERENCIAS PROCESADAS POR RECAUDACION DE TRIBUTOS FISCALES';
    v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                  chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

    if v_dir_mail  is not null then
       --********** Logica para envio por email de los archivos ******************
       Begin
         v_conn     := it_mail.begin_mail(c_dir_mail,
                                          v_dir_mail,
                                          v_asunto,
                                          IT_MAIL.MULTIPART_MIME_TYPE);

         it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

         it_mail.begin_attachment(v_conn,
                                  'text/plain',
                                  false,
                                  v_nom_adj ||'.'||lower(v_ext_archivo));
         --*********Para Grabar Cabecera ***************************************
         if nvl(lower(v_ext_archivo),'xls') = 'txt' then
            v_texto_detalle := CHR(9) || CHR(9) ||CHR(9) ||'SERVICIO DE NOTIFICACION DE TRANSFERENCIAS PROCESADAS POR RECAUDACIONES DE TRIBUTOS FISCALES' || chr(13) || chr(10);
            it_mail.write_text(v_conn, v_texto_detalle);
            v_texto_detalle := 'Transferencias procesadass' || CHR(13) || CHR(10) ||v_cabecera;
            it_mail.write_text(v_conn, v_texto_detalle);
         elsif nvl(lower(v_ext_archivo),'xls') in ('xls', 'csv') then
            v_texto_detalle := CHR(9) || CHR(9) ||'SERVICIO DE NOTIFICACION DE TRANSFERENCIAS PROCESADAS POR RECAUDACIONES DE TRIBUTOS FISCALES'  || chr(13) || chr(10);
            it_mail.write_text(v_conn, v_texto_detalle);
            v_texto_detalle := 'Transferencias procesadas' || chr(10) || v_cabecera;
            it_mail.write_text(v_conn, v_texto_detalle);
         end if;
         --************Para Grabar Detalle **************************************
         for w in c_set loop
             v_total_procesado := v_total_procesado + 1;
             if nvl(lower(v_ext_archivo),'xls') = 'xls' then
                v_adjunto:=null;
                v_adjunto := w.fecha || chr(9) || w.nro_ot || chr(9)||
                             w.nro_ope_sipap || chr(9)|| w.nro_cta_destino || chr(9) ||
                             w.nro_cta_beneficiario || chr(9) || w.beneficiario|| chr(9) ||w.monto || chr(9) ||w.ent_recaudadora||chr(9) ||chr(10); --Nro Lote
             elsif nvl(lower(v_ext_archivo),'xls') = 'csv' then
                v_adjunto:=null;
                v_adjunto := w.fecha || ';' || w.nro_ot || ';' ||
                             w.nro_ope_sipap || ';' || w.nro_cta_destino || ';' || 
                             w.nro_cta_beneficiario || ';' ||w.beneficiario || ';' ||w.monto || ';' ||w.ent_recaudadora|| ';' ||chr(10); --Nro Lote
              elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                        --v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                        --v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                v_adjunto:=null;
                v_adjunto := rpad(w.fecha,10,' ') ||
                             rpad(w.nro_ot,20,' ') ||
                             rpad(w.nro_ope_sipap,20,' ') ||
                             rpad(w.nro_cta_destino,20,' ') ||
                             rpad(w.beneficiario,100,' ') ||
                             rpad(w.nro_cta_beneficiario,20,' ') ||
                             rpad(w.beneficiario, 100, ' ')||
                             rpad(w.monto,20,' ') || CHR(13) || CHR(10); --Nro Lote
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
                          values (c_dir_mail, v_dir_mail, v_asunto, v_texto, sysdate, user);
        END;
     end if;
  ELSE
   begin
      v_texto := '<br><br>
                  <br><br>
                      Estimados:
                  <br><br>
                      Se informa que el archivo de conciliaci&oacute;n no fu&eacute; enviado en fecha '||to_char( nvl(p_fecha, v_fec_actual) , 'DD/MM/YYYY')||'.'||
                  '<br><br>
                  Motivo: '||v_concepto||'
                  <br><br>
                       Favor verificar.
                  <br><br>
                         Atentamente.
                       <br><br>
                       <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                       <br><br>
                       <br><br>';
    end;
    v_nom_adj := lower('CON_INF_SET_'||to_char(v_fec_actual, 'DDMMYY'));
    v_asunto   := 'Servicio de Conciliación de Recaudaciones de Tributos Fiscales';
    v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                  chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

    if v_dir_mail_val  is not null then
       --********** Logica para envio por email de los archivos ******************
       Begin
         v_conn     := it_mail.begin_mail(c_dir_mail,
                                          v_dir_mail_val,
                                          v_asunto,
                                          IT_MAIL.MULTIPART_MIME_TYPE);

         it_mail.attach_text(v_conn, v_mje_mail, 'text/html');
         it_mail.begin_attachment(v_conn,
                                  'text/plain',
                                  false,
                                  v_nom_adj ||'.'||lower(v_ext_archivo));
        
         
         --*********Para Grabar Cabecera ***************************************
         if nvl(lower(v_ext_archivo),'xls') = 'txt' then
            v_texto_detalle := CHR(9) || CHR(9) ||CHR(9) ||'SERVICIO DE NOTIFICACION DE TRANSFERENCIAS PROCESADAS POR RECAUDACIONES DE TRIBUTOS FISCALES'  || chr(13) || chr(10);
            it_mail.write_text(v_conn, v_texto_detalle);
            v_texto_detalle := 'Transferencias procesadass' || CHR(13) || CHR(10) ||v_cabecera;
            it_mail.write_text(v_conn, v_texto_detalle);
         elsif nvl(lower(v_ext_archivo),'xls') in ('xls', 'csv') then
            v_texto_detalle := CHR(9) || CHR(9) ||'SERVICIO DE NOTIFICACION DE TRANSFERENCIAS PROCESADAS POR RECAUDACIONES DE TRIBUTOS FISCALES'  || chr(13) || chr(10);
            it_mail.write_text(v_conn, v_texto_detalle);
            v_texto_detalle := 'Transferencias procesadas' || chr(10) || v_cabecera;
            it_mail.write_text(v_conn, v_texto_detalle);
         end if;
         
         if v_can_registro > 0 or v_can_registro_bbva > 0 then
           v_total_procesado := 0;
           --************Para Grabar Detalle **************************************
           for w in c_set loop
             v_total_procesado := v_total_procesado + 1;
             if nvl(lower(v_ext_archivo),'xls') = 'xls' then
                v_adjunto:=null;
                v_adjunto := w.fecha || chr(9) || w.nro_ot || chr(9)||
                             w.nro_ope_sipap || chr(9)|| w.nro_cta_destino || chr(9) ||
                             w.nro_cta_beneficiario || chr(9) || w.beneficiario|| chr(9) ||w.monto || chr(9) ||w.ent_recaudadora||chr(9) ||chr(10); --Nro Lote
             elsif nvl(lower(v_ext_archivo),'xls') = 'csv' then
                v_adjunto:=null;
                v_adjunto := w.fecha || ';' || w.nro_ot || ';' ||
                             w.nro_ope_sipap || ';' || w.nro_cta_destino || ';' || 
                             w.nro_cta_beneficiario || ';' ||w.beneficiario || ';' ||w.monto || ';' ||w.ent_recaudadora|| ';' ||chr(10); --Nro Lote
              elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                        --v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                        --v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                v_adjunto:=null;
                v_adjunto := rpad(w.fecha,10,' ') ||
                             rpad(w.nro_ot,20,' ') ||
                             rpad(w.nro_ope_sipap,20,' ') ||
                             rpad(w.nro_cta_destino,20,' ') ||
                             rpad(w.beneficiario,100,' ') ||
                             rpad(w.nro_cta_beneficiario,20,' ') ||
                             rpad(w.beneficiario, 100, ' ')||
                             rpad(w.monto,20,' ') || CHR(13) || CHR(10); --Nro Lote
              end if;
              it_mail.write_text(v_conn, v_adjunto);
           end loop;
         end if;
           --************fin de Grabar Detalle **************************************
           --Se inserta el pie de archivo
         v_texto_detalle := chr(10)||
         chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||nvl(v_total_procesado,0)|| chr(13) || chr(10);
         it_mail.write_text(v_conn, v_texto_detalle);
         it_mail.end_mail(v_conn);
       end;
       
    end if;
  END IF;   
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
     raise_application_error(-20000,'PRG_GEN_ARC_CON_SET '||sqlerrm);
END PRG_GEN_ARC_CON_SET;
/

