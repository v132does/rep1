CREATE OR REPLACE PROCEDURE IT.prt_env_arc_seg_fraude IS
  r_log           ta_logs_gp%ROWTYPE;
  v_cod_msg_exito number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200);
  v_separador     clob := ';';
  v_salto_linea   clob := chr(13);
  v_archivo       clob;
  v_valor_64      clob;
  ----------
  v_correos    varchar(4000);
  v_url        varchar2(4000) := it.fug_obt_pardinamico('WS_ENV_MAI_ADJ');
  v_content    clob;
  v_men_error_1  varchar2(4000);
  v_cod_err_ws_1 number(6);
  v_men_error_2  varchar2(4000);
  v_cod_err_ws_2 number(6);
  cant         number := 0;
  v_correo1    varchar2(50);
  v_correo2    varchar2(50);
  v_exi_procesado varchar(1);
  ---------

  CURSOR c_cuentas IS
SELECT IT.fug_obt_pardinamico('NRO_BIN_TAR_CRE')||'******'||t.nro_tarjeta nro_tarjeta,
           t.nro_cuenta,
           p.nom_completo nom_cliente,
           (SELECT w.abreviatura
              FROM ba_tip_documentos w
             WHERE w.cod_tip_documento = p.cod_tip_documento) tip_documento,
           p.nro_documento,
           to_date(to_char(t.fec_vencimiento,'DD/MM/YYYY')) fec_vencimiento,
           to_date(to_char(trunc(SYSDATE),'DD/MM/YYYY')) fecha,
           to_char(SYSDATE, 'HH24:MM:SS') hora,
           fug_obt_pardinamico('MON_SEG_FRAUDE_GP') monto
      FROM ta_cta_tarjetas s, ta_tarjetas t, ba_personas p
     WHERE s.cod_modalidad = '53'
       AND s.nro_cuenta = t.nro_cuenta
       AND t.cod_persona = p.cod_persona
       AND s.estado != 'C'
       and t.vigente like 'S';
procedure pr_carga_correos(mail varchar2)is
  pos_separador number;
  pos_ini number;
  longitud number;
begin

  select instr(mail,';',1),length(mail)
  into pos_separador,longitud
  from dual;
  pos_ini:=1;
  select trim(substr(mail,pos_ini,pos_separador-1))
  into v_correo1
  from dual;
  pos_ini:=pos_separador+1;
  select trim(substr(mail,pos_ini,longitud))
  into v_correo2
  from dual;
end pr_carga_correos;


BEGIN
  /*Setear valores-llamar procedimiento de ta_logs de inicio de proceso*/
  IT.PRE_INI_APLICACION;
  pae_cnf.g_cod_modulo := 1;
  r_log.nom_proceso    := 'PRT_ENV_ARC_SEG_FRAUDE';
  r_log.fec_hor_ini    := SYSDATE;
  r_log.comentario     := '*** Inicio proceso de archivo de Seguro contra Fraude ***';
  pat_igp.pr_ins_log(r_log, FALSE);

  --Se valida que solo sea ejecutado una vez por mes
    begin
    select distinct 'S'
    into v_exi_procesado
    from it.ta_dat_seg_fraude_gp t
    where to_char(t.fec_afectacion,'mm/yyyy')=to_char(sysdate,'mm/yyyy');
  exception
    when others then
      v_exi_procesado := 'N';
  end;

  if nvl(v_exi_procesado, 'N')= 'S' THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'El Informe de Seguro contra Fraude ya fue enviado en este mes'||' - '||
                            to_char(sysdate, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm;
    r_log.men_error:='El Informe ya fue enviado en este mes,verificar mediante consulta dinamica';
    r_log.nro_error:='-20000';
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000,'El Informe ya fue enviado en este mes,verificar mediante consulta dinamica-'||sqlerrm);
  end if;

  --se inicializa la cabecera
  v_archivo := 'Nro. Tarjeta' || v_separador || 'Nro. Cuenta' ||
               v_separador || 'Nombre Cliente' || v_separador ||
               'Tipo Documento' || v_separador || 'Nro. Documento' ||
               v_separador || 'Vencimiento TC.' || v_separador ||
               'Fecha Afectacion' || v_separador || 'Hora Afectacion' ||
               v_separador || 'Monto' || v_salto_linea;
  FOR i IN c_cuentas LOOP
    v_archivo := v_archivo || i.nro_tarjeta || v_separador || i.nro_cuenta ||
                 v_separador || i.nom_cliente || v_separador ||
                 i.tip_documento || v_separador || i.nro_documento ||
                 v_separador || trunc(i.fec_vencimiento) || v_separador || i.fecha ||
                 v_separador || i.hora || v_separador || i.monto ||
                 v_salto_linea;
    cant      := cant + 1;
  END LOOP;
  --armar nuestro base 64
  v_valor_64 := PAT_IGP.FU_CON_B64_CLOB(v_archivo);
  --se eliminan saltos de lineas o tabuladores
  v_valor_64 := REPLACE(REPLACE(v_valor_64, CHR(13), ''), CHR(10), '');
  --Se cargan los correos
  /*IMPORTANTE:se establecio el envio del correo a dos destinatarios,estos
  deben ser cargados en el parametro dinamico ENV_MAIL_SEG_FRAUDE_GP
  y ambos correos deben estar separados por un punto y coma (";").
  En el caso de que se requiera enviar a un solo correo,indicar ese correo unico y
  agregarle punto y coma (";") al final */

  v_correos:=it.fug_obt_pardinamico('ENV_MAIL_SEG_FRAUDE_GP');
  pr_carga_correos(v_correos);

-------se manda primer correo
 if v_correo1 is not null then
  v_content := '{"destinationMail": "' || v_correo1 || '",' ||
               '"subject": "Informe Seguro contra Fraudes",' ||
               '"message": "<h1>\" + Informe Seguro contra Fraudes + \"</h1>",' ||
               '"attachments": [' || '{"attachmentContent":"' || v_valor_64 || '",' ||
               ' "attachmentName": "reporte_seguro_contra_fraude.csv"' ||
               '}]}';
  --llamar al servicio
  PAT_IGP.PR_WS_CONECTOR_CLOB(v_content,
                              v_url,
                              null,
                              null,
                              'M',
                              'POST',
                              v_cod_err_ws_1,
                              v_men_error_1);
  --dbms_output.put_line('Cod_error:' || v_cod_err_ws_1);
  --dbms_output.put_line('Mensaje de error:' || v_men_error_1);
  end if;

  -------se manda segundo correo
  if v_correo2 is not null then
  v_content := '{"destinationMail": "' || v_correo2 || '",' ||
               '"subject": "Informe Seguro contra Fraudes",' ||
               '"message": "<h1>\" + Informe Seguro contra Fraudes + \"</h1>",' ||
               '"attachments": [' || '{"attachmentContent":"' || v_valor_64 || '",' ||
               ' "attachmentName": "reporte_seguro_contra_fraude.csv"' ||
               '}]}';
  --llamar al servicio
  PAT_IGP.PR_WS_CONECTOR_CLOB(v_content,
                              v_url,
                              null,
                              null,
                              'M',
                              'POST',
                              v_cod_err_ws_2,
                              v_men_error_2);
  --dbms_output.put_line('Cod_error:' || v_cod_err_ws_2);
  --dbms_output.put_line('Mensaje de error:' || v_men_error_2);
  end if;


  if v_cod_err_ws_1 = v_cod_msg_exito or v_cod_err_ws_2 = v_cod_msg_exito then
    FOR i IN c_cuentas LOOP
      begin
      insert into it.ta_dat_seg_fraude_gp
        (nro_tarjeta,
         nro_cuenta,
         nom_cliente,
         tip_documento,
         nro_documento,
         fec_vencimiento,
         fec_afectacion,
         hor_afectacion,
         monto)
      values
        (i.nro_tarjeta,
         i.nro_cuenta,
         i.nom_cliente,
         i.tip_documento,
         i.nro_documento,
         i.fec_vencimiento,
         trunc(i.fecha),
         i.hora,
         i.monto);
         exception
           when others then
                   r_log.comentario :=substr( 'Error al insertar. ' || r_log.nom_proceso || ' - '||'Nro cuenta:'||i.nro_cuenta||' - Monto: '||i.monto||
                            to_char(sysdate, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,400);
          pat_igp.pr_ins_log(r_log);
         end;
    end loop;

  else
      r_log.comentario := 'Error al remitir correo.'||' - '||
                            'Correo1:'||v_correo1||'Error1:'||substr(v_men_error_1,1,50)||
                            ' .Correo2:'||v_correo2||'Error2:'||substr(v_men_error_2,1,50);
      pat_igp.pr_ins_log(r_log);
  end if;

  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de archivo de Seguro contra Fraude ***';
  pat_igp.pr_ins_log(r_log, FALSE);
 commit;
EXCEPTION
  when others then
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||
                            to_char(sysdate, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,400);
    r_log.men_error:='El Informe ya fue enviado en este mes,verificar mediante consulta dinamica';
    r_log.nro_error:='-20000';
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000,'El Informe ya fue enviado en este mes,verificar mediante consulta dinamica.');
END;
/

