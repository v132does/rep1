CREATE OR REPLACE PROCEDURE IT.PRG_ENV_PAG_PROVEEDORES IS
  v_fec_actual  date default pag_cal.fu_obt_fec_actual(1);
  v_cod_per_debito  ge_cta_clientes.cod_persona%type;
  v_cod_per_credito ge_cta_clientes.cod_persona%type;
  v_nom_ente        ge_entes.descripcion%type;
  v_dir_mail_deb    ge_par_entes.val_parametro%type;
  --v_dir_mail_cre    ge_par_entes.val_parametro%type;
  v_dir_mail_cre    varchar2(400);
  v_dir_mail_pp     ge_par_entes.val_parametro%type;
  v_tip_envio       ge_par_entes.val_parametro%type;
  v_ext_archivo     ge_par_entes.val_parametro%type;
  v_dir_archivo     ge_par_entes.val_parametro%type;
  v_nom_cli_debito  ba_personas.nom_completo%type;
  v_nom_cli_credito ba_personas.nom_completo%type;
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo; --'info@.com'; -- Modificado DYDMR-9804
  v_texto         varchar2(4000);
  v_texto_detalle  varchar2(32000);
  v_adjunto       varchar2(32000);
  v_cabecera      clob;
  v_nom_adj varchar2(500);
  v_total_procesado number ;
  v_total_error number ;
  v_can_facturas number;
  v_line         VARCHAR2(32767);
  v_buffer       VARCHAR2(32767);
  v_lines        PLS_INTEGER := 0;
  v_eol          CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen       CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline      CONSTANT PLS_INTEGER := 32767;
  v_file         UTL_FILE.FILE_TYPE;
  v_name         VARCHAR2(128);-- nombre del archivo
  v_monto        varchar2(200);
  v_nro_factura  varchar2(2000);
  v_cantidad     number(18):=0;
  v_hora varchar2(12);
  v_error       varchar2(3000);
  -- Variables para mail
  v_conn     utl_smtp.connection;
  v_asunto   VARCHAR2(2000);
  v_mje_mail LONG;
  v_nro_pago varchar2(200);
  -- FTP
  v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;
  v_respuesta VARCHAR2(4000);
  v_tip_nro_pago varchar2(10);
  v_lugar   varchar2(1000);
  v_lon_cabecera number(18):=600;
  v_lon_total number(18):=0;
  v_concepto varchar2(100);
  v_ref_facturas varchar2(3000);
 /* -- Variables coneccion*/
  g_repository         VARCHAR2(100) := 'MAIL';
  --CRO-MB-05/2015: CROMIGDS-3 => Migraci?n de Directorios de un Servidor a Otro
  --g_ip                 VARCHAR2(100) := '192.168.254.136';
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := '21';
  --CRO-MB-05/2015: CROMIGDS-3 => Migraci?n de Directorios de un Servidor a Otro
  --g_user               VARCHAR2(100) := 'ftpramail';
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migraci?n de Directorios de un Servidor a Otro
  --g_pass               VARCHAR2(100) := 'kacha.ma1';
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_dia_max_reversion  number(10) := nvl( fug_obt_pardinamico ( 'SNP_DIA_MAX_REVERSION' ), 0 );
  v_fec_desde date;

  --GAC 12/05/20147 Se agrega membrete de , a pedido del usuario solicitante
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M');
  V_FIN      LONG := fug_gen_template('F');
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  --

  CURSOR g_ente is
   select cod_ente, a.nro_cta_debito
       from ge_pag_proveedores a
      where a.fec_pago = v_fec_actual
        and a.estado in ('N')
        and a.for_pago in ('C','I')
        and a.nro_cta_debito is not null
        and ((a.nro_cta_credito  is not null and a.for_pago = 'C') or
             (a.nro_cta_beneficiario is not null and a.for_pago = 'I'))
    group by cod_ente, a.nro_cta_debito
   UNION
     select cod_ente, a.nro_cta_debito
       from ge_pag_proveedores a
      where --Fecha de Pago menor a hoy - mayor a rango dias SNP
        (trunc(a.fec_pago) between v_fec_desde and  trunc(v_fec_actual))
        and a.estado in ('A')--Anulado
        and a.for_pago in ('I')
        and a.nro_cta_debito is not null
        and ((a.nro_cta_beneficiario is not null and a.for_pago = 'I'))
        --Fecha que se actualiz? sea en el d?a actual
        and trunc(a.fec_modificacion)=trunc(v_fec_actual)
    group by cod_ente, a.nro_cta_debito

    order by 1, 2;
    --order by cod_ente, a.nro_cta_debito;
  CURSOR g_datos is
    SELECT A.* FROM GE_ENV_PAG_PROVEEDORES_TMP A ORDER BY A.CTA_CREDITO;

  CURSOR c_rec(v_ente ge_pag_recaudaciones.cod_ente%TYPE, v_cta_debito ge_cuentas.nro_cuenta%TYPE) is
     select  a.hora hor_mov,
             a.nro_documento nro_doc_mov,
             null nro_secuencia, to_char(a.fec_pago,'YYYYMMDD') fecha,
             a.nro_cta_credito,a.nro_cta_debito,a.tip_carga,a.ref_facturas,case when to_char(a.nro_factura) = to_char(a.nro_orden) then null else to_char(a.nro_factura)end NRO_FACTURA,
             a.monto,a.cod_moneda,a.concepto,a.fec_ingreso,a.fec_pago,
             a.nro_doc_beneficiario,a.cod_tip_doc_beneficiario,null ent_bca_beneficiario,a.nro_cta_beneficiario,
             a.ind_valor,a.nro_orden referencia,a.nro_referencia,a.cod_ente,a.nro_pago,
             null EST_SIPAP, null TIP_RECHAZO, DECODE(A.USU_INSERCION,'HBANK','HOME BANKING','CORE') Canal,
             decode(a.for_pago,'C','CREDITO CUENTA','G', 'CHEQUE GERENCIA') FOR_PAGO1,
             TO_CHAR(A.Fec_Ingreso,'yyyymmdd')||TO_CHAR(A.Nro_Archivo) NRO_LOTE,
             A.NRO_CTA_CREDITO CTA_CRE,null TIP_DOC_BEN_SIPAP, a.ben_dir_correo, 'N' as INTERBANCARIO
          from ge_pag_proveedores a
     where a.fec_pago = v_fec_actual
       and a.estado in ('N')
       and a.for_pago in ('C')
       and a.nro_cta_debito is not null
       and ((a.nro_cta_credito  is not null and a.for_pago = 'C'))
       and a.cod_ente = v_ente
       and a.nro_cta_debito = v_cta_debito
     union all
      select distinct b.hora hor_mov, b.nro_documento nro_doc_mov, 1 nro_secuencia, to_char(b.fecha,'YYYYMMDD') fecha,
             a.nro_cta_credito,a.nro_cta_debito,a.tip_carga,a.ref_facturas,case when to_char(a.nro_factura) = to_char(a.nro_orden) then null else to_char(a.nro_factura)end NRO_FACTURA,
             a.monto,a.cod_moneda,a.concepto,a.fec_ingreso,a.fec_pago,
             a.nro_doc_beneficiario,a.cod_tip_doc_beneficiario,a.ent_bca_beneficiario||'-'||fug_obt_des_banco(a.ent_bca_beneficiario)  ent_bca_beneficiario,a.nro_cta_beneficiario,
             a.ind_valor,a.nro_orden referencia,a.nro_referencia,a.cod_ente,a.nro_pago,
             DECODE(C.ESTADO,NULL,NULL,(select w.abreviatura from ba_cod_referencias w
             where w.dominio ='EST_MSJ_SNP' and w.val_minimo=c.estado  and rownum=1)) EST_SIPAP,
             DECODE(C.TIP_RECHAZO,NULL,NULL,(select w.abreviatura from ba_cod_referencias w
             where w.dominio ='TIP_REC_SNP' and w.val_minimo=c.tip_rechazo and rownum=1)) TIP_RECHAZO
             ,DECODE(A.USU_INSERCION,'HBANK','HOME BANKING','CORE') Canal,
             decode(a.for_pago,'C','CREDITO CUENTA','G', 'CHEQUE GERENCIA','I', 'TRANSFERENCIA INTERBANCARIA') FOR_PAGO1,
             TO_CHAR(a.fec_ingreso,'yyyymmdd')||TO_CHAR(A.Nro_Archivo)  NRO_LOTE
             ,A.NRO_CTA_BENEFICIARIO CTA_CRE, SUBSTR(TRIM(D.ABREVIATURA),1,3) TIP_DOC_BEN_SIPAP, a.ben_dir_correo, 'S' as INTERBANCARIO
          from ge_pag_proveedores a,
               ge_movimientos b, GE_SNP_TRANSFERENCIAS C,BA_TIP_DOCUMENTOS D
     where a.fec_pago = v_fec_actual
       and b.fecha = a.fec_pago
       --and b.nro_documento3 = a.cod_ente --> No s guarda el Dato para Fecha Futura
       and b.monto = a.monto
       and b.nro_documento=a.Nro_Referencia
       and a.estado in ('N','A')
       and a.for_pago in ('I')
       and a.nro_cta_debito is not null
       and a.cod_ente = v_ente
       and a.nro_cta_debito = v_cta_debito
       AND A.NRO_REFERENCIA=C.NRO_REFERENCIA
       AND A.COD_TIP_DOC_BENEFICIARIO= D.COD_TIP_DOCUMENTO
     union all
       select distinct b.hora hor_mov, b.nro_documento nro_doc_mov, 1 nro_secuencia, to_char(b.fecha,'YYYYMMDD') fecha,
             a.nro_cta_credito,a.nro_cta_debito,a.tip_carga,a.ref_facturas,case when to_char(a.nro_factura) = to_char(a.nro_orden) then null else to_char(a.nro_factura)end NRO_FACTURA,
             a.monto,a.cod_moneda,a.concepto,a.fec_ingreso,a.fec_pago,
             a.nro_doc_beneficiario,a.cod_tip_doc_beneficiario,a.ent_bca_beneficiario||'-'||fug_obt_des_banco(a.ent_bca_beneficiario)  ent_bca_beneficiario,a.nro_cta_beneficiario,
             a.ind_valor,a.nro_orden referencia,a.nro_referencia,a.cod_ente,a.nro_pago,
             DECODE(C.ESTADO,NULL,NULL,(select w.abreviatura from ba_cod_referencias w
             where w.dominio ='EST_MSJ_SNP' and w.val_minimo=c.estado  and rownum=1)) EST_SIPAP,
             DECODE(C.TIP_RECHAZO,NULL,NULL,(select w.abreviatura from ba_cod_referencias w
             where w.dominio ='TIP_REC_SNP' and w.val_minimo=c.tip_rechazo and rownum=1)) TIP_RECHAZO
             ,DECODE(A.USU_INSERCION,'HBANK','HOME BANKING','CORE') Canal,
             decode(a.for_pago,'C','CREDITO CUENTA','G', 'CHEQUE GERENCIA','I', 'TRANSFERENCIA INTERBANCARIA') FOR_PAGO1,
             TO_CHAR(a.fec_ingreso,'yyyymmdd')||TO_CHAR(A.Nro_Archivo)  NRO_LOTE
             ,A.NRO_CTA_BENEFICIARIO CTA_CRE, SUBSTR(TRIM(D.ABREVIATURA),1,3) TIP_DOC_BEN_SIPAP, a.ben_dir_correo, 'S' as INTERBANCARIO
          from ge_pag_proveedores a,
               gv_movimientos b, GE_SNP_TRANSFERENCIAS C,BA_TIP_DOCUMENTOS D
     where
       --Fecha de Pago menor a hoy y mayor a rango dias SNP
       (trunc(a.fec_pago) between v_fec_desde and  trunc(v_fec_actual-1))
       --a.fec_pago = v_fec_actual
       and b.fecha = a.fec_pago
       --and b.nro_documento3 = a.cod_ente --> No s guarda el Dato para Fecha Futura
       and b.monto = a.monto
       and b.nro_documento=a.Nro_Referencia
       and a.estado in ('A')
       and a.for_pago in ('I')
       and a.nro_cta_debito is not null
       and a.cod_ente = v_ente
       and a.nro_cta_debito = v_cta_debito
       AND A.NRO_REFERENCIA=C.NRO_REFERENCIA
       AND A.COD_TIP_DOC_BENEFICIARIO= D.COD_TIP_DOCUMENTO
       --Fecha que se actualiz? sea en el d?a actual
       and trunc(a.fec_modificacion)=trunc(v_fec_actual)
     order by cod_ente;

  FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2
   ) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
   BEGIN
      IF p_cadena IS NOT NULL THEN
         v_cadena := translate(p_cadena,
                  '???????????????????????????????,+?~|????!"#$%&/()=???*?{}^`?[]:;><??%',
                  'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
         v_cadena := translate(v_cadena,
                  '????????????????????????????Aa\????????????????????????',
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
      || Dominios Gen?ricos
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
  begin
  v_fec_desde:= trunc(v_fec_actual - v_dia_max_reversion);
  for a in g_ente loop
        pre_cam_for_numerico('.,'); --Primero se define el caracter decimal y luego el separador de grupos (separador de miles)
       -- Borramos la tabla temporal para volver a cargar
       delete from ge_env_pag_proveedores_tmp;
      --GAC 12/05/20147 Se agrega membrete de , a pedido del usuario solicitante
       v_nom_ente        := fue_obt_nom_ente(a.cod_ente);
       v_cod_per_debito  := fug_obt_cli_principal(a.nro_cta_debito);
       v_dir_mail_deb    := fug_obt_parentes(a.cod_ente,'DIR_MAIL_PP');
       v_dir_mail_pp     := fug_obt_parentes(a.cod_ente,'DIR_MAIL_NOT_PP');--BSEVOCORE-70--Env?o de correo con copia a cliente en pago a proveedores
       v_tip_envio      := nvl(fug_obt_parentes(a.cod_ente,'TIP_ENV_SAL_PRV'),'M');
       v_ext_archivo    := nvl(fug_obt_parentes(a.cod_ente,'EXT_ARC_SAL_PRV'),'xls');
       v_dir_archivo    := fug_obt_parentes(a.cod_ente,'DIR_ARC_PRV');


       if v_ext_archivo is not null then
         if lower(v_ext_archivo) != 'xls' or lower(v_ext_archivo) != 'txt' then
           if lower(v_ext_archivo) like '%xls%' then
             v_ext_archivo := 'xls';
           end if;
           if lower(v_ext_archivo) like '%txt%' then
             v_ext_archivo := 'txt';
           end if;
         end if;
         if v_ext_archivo not in ('xls','txt') then
           v_ext_archivo := 'xls';
         end if;
       else
          v_ext_archivo := 'xls';
       end if;
       --
       -- se comenta porque no permite enviar a mas de una cuenta de correo
       -- v_dir_mail_deb        := fu_val_correo(v_dir_mail_deb);
       if v_dir_mail_deb is null then
           v_dir_mail_deb    := fug_obt_dir_mail_per(v_cod_per_debito);
           v_dir_mail_deb        := fu_val_correo(v_dir_mail_deb);
       end if;

       v_nom_cli_debito  := fue_obt_nom_persona(v_cod_per_debito);

       v_texto_detalle := null;
       v_adjunto       := null;
       v_total_procesado := 0;
       v_total_error := 0;
       v_can_facturas := 0;
       --
       IF nvl(v_tip_envio,'M') = 'A' THEN
           -- ENVIO FTP
           v_buffer := null;
           v_line := null;
           v_name := nvl(fug_obt_pardinamico('NOM_ARC_PAG_PROV'),'PAG_PROV_')|| a.cod_ente || '_' ||
                           to_char(v_fec_actual, 'DDMMYY');
           if v_dir_archivo is null then
              raise_application_error(-20000,'Par?metro DIR_ARC_PRV no definido para el Ente: '||a.cod_ente);
           end if;

            -- Abrir archivo
           v_file := UTL_FILE.FOPEN(v_dir_archivo,
                                    v_name || '.'||v_ext_archivo,
                                    'W',
                                    32767);
       END IF;
       for b in c_rec(a.cod_ente, a.nro_cta_debito) loop
          v_cod_per_credito := fug_obt_cli_principal(b.nro_cta_credito);
          v_nom_cli_credito := fue_obt_nom_persona(v_cod_per_credito);

          if b.ben_dir_correo is null then
            v_dir_mail_cre    := trim(fug_obt_dir_mail_per(v_cod_per_credito));
            --Puede tener mas de un correo PCCDEVO-471
            /*v_dir_mail_cre    := fu_eli_acentos(v_dir_mail_cre);
            v_dir_mail_cre    := fu_val_correo(v_dir_mail_cre);*/
          else
            v_dir_mail_cre    := trim(b.ben_dir_correo);
             --Puede tener mas de un correo PCCDEVO-471
            /*v_dir_mail_cre    := fu_eli_acentos(v_dir_mail_cre);
            v_dir_mail_cre    := fu_val_correo(v_dir_mail_cre);*/
          end if;
         --Se informar? los dos Campos PCCDEVO-471
         /* if b.tip_carga = 'H' then
            v_nro_factura := b.ref_facturas;
          else
            IF b.ref_facturas is null then
               v_nro_factura := b.nro_factura;
            else
               v_nro_factura := b.ref_facturas;
            end if;
          end if;*/
         v_ref_facturas:= TRIM(substr(trim(b.ref_facturas),1,300));
         if (v_dir_mail_cre is not null) and (b.interbancario = 'N') then

              v_texto := '<br><br>
                         <br><br>
                           Estimado Cliente: '||upper(v_nom_cli_credito)||'
                         <br><br>
                           Le informamos que se realizo el credito en su cuenta por el servicio solicitado por la empresa: ' ||
                                   upper(v_nom_cli_debito) || '.
                         <br><br>
                           Fecha: '||v_fec_actual||'
                         <br><br>
                           Cuenta de Credito: '||b.nro_cta_credito||'
                         <br><br>
                           Monto: '||to_char(b.monto,'999,999,999,999.99')||'
                         <br><br>
                           Moneda: '||b.cod_moneda||'
                         <br><br>
                           Nro. Factura(s): '||v_nro_factura||'
                         <br><br>
                           Ref. Factura(s): '||v_ref_facturas||'
                         <br><br>
                           Concepto: '||b.concepto||'
                         <br><br>
                           Atentamente.
                         <br><br>
                         <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                         <br><br>
                         <br><br>';

              v_asunto   := 'Acreditaci?n en Cuenta - Pago a proveedores';
              v_mje_mail := v_membrete || chr(10) || chr(10) || chr(10) || v_texto ||
                            chr(10) || chr(10) || chr(10) || V_FIN|| chr(10)|| V_PIE;

             if v_dir_mail_pp is not null then --BSEVOCORE-70--Env?o de correo con copia a cliente en pago a proveedores
                v_dir_mail_cre := v_dir_mail_cre||';'|| v_dir_mail_pp;
             end if;

             BEGIN
               v_conn     := it_mail.begin_mail(c_dir_mail,
                                                 v_dir_mail_cre,
                                                 v_asunto,
                                                 IT_MAIL.MULTIPART_MIME_TYPE);



                it_mail.attach_text(v_conn, v_mje_mail, 'text/html');

                it_mail.write_text(v_conn, v_texto_detalle);

                it_mail.end_mail(v_conn);


              EXCEPTION
                 when others then
                      v_texto := substr(v_texto || '- ERROR [' || SQLERRM || ']', 1, 4000);
                      insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                      values (c_dir_mail, v_dir_mail_cre, v_asunto, v_texto, sysdate, user)  ;
              end;

          end if;

        v_total_procesado := v_total_procesado + nvl(b.monto, 0);
        v_can_facturas := v_can_facturas + 1;
        v_tip_nro_pago:= null;
        v_tip_nro_pago:= nvl(fug_obt_parentes(a.cod_ente,'MOD_ENV_NRO_PAGO'),'2');
        v_nro_pago:=null;
        if v_tip_nro_pago = '1' then
           --Fecha/Hora/Nro_Secuencia
           v_nro_pago := b.nro_pago;
        elsif v_tip_nro_pago = '2' then
           --Nro.de movimiento
           v_nro_pago := b.nro_doc_mov;
        end if;
             --Cargamos los datos en las tablas.
             --Si dice Pago a Proveedores no se ingres? el concepto
              v_concepto:=null;
             if B.CONCEPTO like '%Pago Proveedor%' then
               v_concepto:=null;
             else
               v_concepto:=B.CONCEPTO;
             end if;

             if nvl(lower(v_ext_archivo),'xls') = 'xls' then
                           insert into ge_env_pag_proveedores_tmp(COD_ENTE,BENEFICIARIO,FEC_PAGO,FEC_INGRESO,CTA_DEBITO,
                               CTA_CREDITO,MONTO,COD_MONEDA,NRO_FACTURA,NRO_OPERACION,FOR_PAGO,COD_TIP_DOC_BENEFICIARIO,
                               NRO_DOC_BENEFICIARIO,BCO_BENEFICIARIO,NRO_CTA_BENEFICIARIO,IND_VALOR,CONCEPTO,
                               NRO_IDENTIFICADOR,NRO_LOTE,CANAL,NRO_TRA_SIPAP,EST_PAG_OTR_BANCO,MOT_RECHAZO,REF_FACTURAS)
                           values(b.cod_ente,substr(v_nom_cli_debito,1,120),to_char(b.fec_pago, 'DD/MM/YYYY'),to_char(b.fec_ingreso, 'DD/MM/YYYY'),
                                  substr(b.nro_cta_debito,1,20),substr(b.CTA_CRE,1,20),b.monto,b.cod_moneda,substr(b.nro_factura,1,19),trim(substr(v_nro_pago,1,20)),substr(B.FOR_PAGO1,1,31),substr(b.TIP_DOC_BEN_SIPAP,1,3),
                                  trim(substr(B.NRO_DOC_BENEFICIARIO,1,20)),substr(B.ENT_BCA_BENEFICIARIO,1,20),substr(B.NRO_CTA_BENEFICIARIO,1,35),B.IND_VALOR,substr(v_concepto,1,35),
                                  substr(b.Referencia,1,18), substr(B.NRO_LOTE,1,12), substr(b.canal,1,12),substr(b.Nro_Referencia,1,15), substr(B.EST_SIPAP,1,20),
                                  B.TIP_RECHAZO,trim(substr(B.REF_FACTURAS,1,299)));
              elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                          insert into ge_env_pag_proveedores_tmp(COD_ENTE,BENEFICIARIO,FEC_PAGO,FEC_INGRESO,CTA_DEBITO,
                              CTA_CREDITO,MONTO,COD_MONEDA,NRO_FACTURA,NRO_OPERACION,FOR_PAGO,COD_TIP_DOC_BENEFICIARIO,
                              NRO_DOC_BENEFICIARIO,BCO_BENEFICIARIO,NRO_CTA_BENEFICIARIO,IND_VALOR,CONCEPTO,
                              NRO_IDENTIFICADOR,NRO_LOTE,CANAL,NRO_TRA_SIPAP,EST_PAG_OTR_BANCO,MOT_RECHAZO,REF_FACTURAS)
                               values(b.cod_ente,substr(v_nom_cli_debito,1,120),to_char(b.fec_pago, 'DDMMYYYY'),to_char(b.fec_ingreso, 'DDMMYYYY'),
                                substr(b.nro_cta_debito,1,20),substr(b.CTA_CRE,1,20),b.monto,b.cod_moneda,
                                nvl(substr(b.nro_factura,1,20),'                    '),
                                nvl(substr(v_nro_pago,1,20),'                    '),
                                nvl(substr(B.FOR_PAGO1,1,32),'                               '),
                                nvl(substr(b.TIP_DOC_BEN_SIPAP,1,3),'   '),
                                trim(nvl(substr(B.NRO_DOC_BENEFICIARIO,1,20),'                    ')),
                                nvl(to_char(substr(B.ENT_BCA_BENEFICIARIO,1,20)),'                    '),
                                nvl(substr(B.NRO_CTA_BENEFICIARIO,1,35),'                                  '),
                                nvl(substr(B.IND_VALOR,1,1),' '),
                                nvl(substr(v_concepto,1,35),'                                   '),
                                nvl(substr(b.Referencia,1,18),'        '),
                                nvl(substr(B.NRO_LOTE,1,12),'            '),
                                nvl(substr(b.canal,1,12),'          '),
                                nvl(to_char(substr(b.Nro_Referencia,1,15)),'               '),
                                nvl(substr(B.EST_SIPAP,1,20),'                   '),
                                nvl(substr(B.TIP_RECHAZO,1,30),'                              '),
                                rpad(nvl(substr(B.REF_FACTURAS,1,300),' '),302,' '));

              end if;

    end loop;
      --Verificamos si se insertaron registros en la tabla para enviar.
      begin
        select count(*)
          into v_cantidad
          from ge_env_pag_proveedores_tmp;
      exception
        when no_data_found then
          v_cantidad:=0;
        when others then
           v_cantidad:=0;
      end;
if nvl(v_cantidad,0)> 0 then
         if  nvl(lower(v_ext_archivo),'xls') = 'xls'then
           v_cabecera := 'Empresa Pagadora' || chr(9) || 'Fecha Pago' || chr(9) || 'Fecha Ingreso' || chr(9) ||
                     'Cuenta D?bito' || chr(9) ||'Cuenta Cr?dito' || chr(9) ||
                    'Monto' || chr(9) ||'Moneda' || chr(9) || 'Nro. Factura' ||chr(9) ||
                    'Nro. Operacion'|| chr(9)||'Forma Pago'|| chr(9)||'Tip.Doc.Benef.'|| chr(9)||
                    'Nro. Doc. Benef.'|| chr(9)||'Bco.Benef.'|| chr(9)||'Nro.Cta.Benef.'|| chr(9)||
                    'Ind.Valor'|| chr(9)||'Concepto'|| chr(9)||'Nro.Identif.'|| chr(9)||
                    'Nro.Lote'|| chr(9)||'Canal'|| chr(9)||'Nro.Transf.Sipap'|| chr(9)||
                    'Estado.Pago.SIPAP'|| chr(9)||'Mot.Rechazo.SIPAP'|| chr(9)||'Ref.Facturas'||
                    chr(10);
         elsif nvl(lower(v_ext_archivo),'xls') = 'txt' then
           v_cabecera := rpad('Empresa Pagadora',120,' ') || rpad('Fec.Pago',10,' ')|| rpad('FecIngreso',10,' ')  ||
                    'Cta. D?bito    ' ||'Cta. Cr?dito   ' ||  rpad('Monto',18.2,' ') ||
                    'Mon' || 'Nro. Factura        ' || 'Nro.Operacion       '||
                    'Forma Pago                      ' || 'Tip' || 'Nro.Doc.Beneficiario'||
                    '    Bco.Beneficiario' || 'Nro.Cta.Beneficiario               ' ||
                    'V'||'Concepto                           '||
                    'Nro.Ide.' || 'Nro.Lote    ' ||
                    'Canal     ' || 'Nro.Trans.Sipap' || 'Est.Pago            ' ||
                    'Mot.Rechazo.SIPAP             ' || rpad('Nro.Referencia           ',302,' ')
                    ||chr(10);
         end if;
             v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente: '|| upper(v_nom_cli_debito) ||'
                   <br><br>
                     Le informamos que se realizo el proceso de Pago a Proveedores correspondiente a la fecha ' ||
                             to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se realizaron las operaciones detalladas en el archivo adjunto.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';

          --GAC 12/05/20147 Se agrega membrete de , a pedido del usuario solicitante|
          v_nom_adj := nvl(fug_obt_pardinamico('NOM_ARC_PAG_PROV'),'PAG_PROV_') || a.cod_ente || '_' ||
                       to_char(v_fec_actual, 'DDMMYY');

          v_asunto   := 'Pago a Proveedores';
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
                                         v_nom_adj ||'.'||v_ext_archivo);
                 --*********Para Grabar Cabecera ***************************************
                 if nvl(lower(v_ext_archivo),'xls') = 'txt' then
                        v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                         'SERVICIO DE PAGOS A PROVEEDORES' || CHR(13)|| CHR(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                 v_cabecera|| CHR(13) || CHR(10) ;
                        it_mail.write_text(v_conn, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then

                        v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                         'SERVICIO DE PAGOS A PROVEEDORES' || CHR(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera || chr(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                for w in g_datos loop
                  if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                    v_adjunto:=null;
                    v_adjunto := w.beneficiario || chr(9) ||
                         w.fec_pago || chr(9)||
                         w.fec_ingreso || chr(9) ||
                         w.cta_debito || chr(9) || w.CTA_CREDITO ||chr(9) ||
                         w.monto || chr(9) || w.cod_moneda || chr(9) ||
                         trim(to_char(w.nro_factura)) || chr(9) || w.NRO_OPERACION ||chr(9) ||
                         w.FOR_PAGO|| chr(9) ||w.cod_tip_doc_beneficiario|| chr(9) ||
                         trim(w.NRO_DOC_BENEFICIARIO)|| chr(9) ||w.BCO_BENEFICIARIO|| chr(9) ||
                         w.NRO_CTA_BENEFICIARIO|| chr(9) ||w.IND_VALOR|| chr(9) ||w.CONCEPTO|| chr(9) ||
                         w.nro_identificador|| chr(9) || w.NRO_LOTE||chr(9) || w.canal||chr(9) ||
                         trim(to_char(w.nro_tra_sipap))|| chr(9) || substr(w.est_pag_otr_banco,1,20)||chr(9) ||
                         w.mot_rechazo|| chr(9) || trim(to_char(w.REF_FACTURAS))||chr(9) ||chr(10);
                    elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                          v_monto := trim(to_char(w.monto,'9G999G999G999G990D99'));
                          v_adjunto:=null;
                          v_adjunto :=rpad(v_nom_cli_debito,120,' ') ||
                          rpad(w.fec_pago,10,' ') ||
                          rpad(w.fec_ingreso,10,' ') ||
                          rpad(w.cta_debito,15,' ') ||
                          rpad(w.CTA_CREDITO,15,' ') ||
                          rpad(v_monto,18.2,' ') ||
                          rpad(w.cod_moneda,3,' ') ||
                          rpad(w.nro_factura,20,' ') ||
                          rpad(w.NRO_OPERACION,20,' ') ||
                          rpad(w.FOR_PAGO,32,' ') ||
                          rpad(nvl(to_char(w.cod_tip_doc_beneficiario),' '),3,' ') ||
                          rpad(nvl(w.NRO_DOC_BENEFICIARIO,' '),20,' ') ||
                          rpad(nvl(to_char(w.BCO_BENEFICIARIO),' '),20,' ') ||
                          rpad(nvl(w.NRO_CTA_BENEFICIARIO,' '),35,' ') ||
                          rpad(nvl(w.IND_VALOR,' '),1,' ') ||
                          rpad(w.CONCEPTO,35,' ') ||
                          rpad(w.nro_identificador,8,' ') ||
                          rpad(nvl(w.NRO_LOTE,' ') ,12,' ') ||
                          rpad(nvl(w.canal,' '),10,' ') ||
                          rpad(w.nro_tra_sipap,15,' ') ||
                          rpad(nvl(substr(w.est_pag_otr_banco,1,20),' '),20,' ') ||
                          rpad(nvl(w.TIP_RECHAZO,' '),30,' ') ||
                          rpad(nvl(w.REF_FACTURAS,'          '),302,' ')|| CHR(13) || CHR(10) ;
                   end if;
                    it_mail.write_text(v_conn, v_adjunto);
                 end loop;
                 --************fin de Grabar Detalle **************************************
                 --Se inserta el pie de archivo
                 v_texto_detalle := chr(10)||
                 chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_total_procesado||chr(10);
                 it_mail.write_text(v_conn, v_texto_detalle);

                 it_mail.end_mail(v_conn);

             EXCEPTION
                 when others then
                       v_texto := substr(v_texto || '- ERROR [' || SQLERRM || ']', 1, 4000);
                       insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                        values (c_dir_mail, v_dir_mail_deb, v_asunto, v_texto, sysdate, user);
             END;
               --********** fin de Logica para envio por email de los archivos ******************
          end if;
    ELSE
           --*****************Para formato de Archivo **********************
             Begin

                 --*********Para Grabar Cabecera ***************************
                 if nvl(lower(v_ext_archivo),'xls') = 'txt' then
                        v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                         'SERVICIO DE PAGOS A PROVEEDORES' || CHR(13) || CHR(10);
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                 v_cabecera;--|| CHR(13) || CHR(10) ;
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then

                        v_texto_detalle := chr(10) || CHR(9) || CHR(9) ||
                                         'SERVICIO DE PAGOS A PROVEEDORES' || CHR(10);
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera; --|| chr(10);
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                for w in g_datos loop
                    if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                         v_adjunto:=null;
                         v_adjunto := w.beneficiario || chr(9) ||
                         w.fec_pago || chr(9)||
                         w.fec_ingreso || chr(9) ||
                         w.cta_debito || chr(9) || w.CTA_CREDITO ||chr(9) ||
                         w.monto || chr(9) || w.cod_moneda || chr(9) ||
                         trim(w.nro_factura) || chr(9) || w.NRO_OPERACION ||chr(9) ||
                         w.FOR_PAGO|| chr(9) ||w.cod_tip_doc_beneficiario|| chr(9) ||
                         trim(w.NRO_DOC_BENEFICIARIO)|| chr(9) ||w.BCO_BENEFICIARIO|| chr(9) ||
                         w.NRO_CTA_BENEFICIARIO|| chr(9) ||w.IND_VALOR|| chr(9) ||w.CONCEPTO|| chr(9) ||
                         w.nro_identificador|| chr(9) || w.NRO_LOTE||chr(9) || w.canal||chr(9) ||
                         w.nro_tra_sipap|| chr(9) ||  substr(w.est_pag_otr_banco,1,20)||chr(9) ||
                         w.mot_rechazo|| chr(9) || w.REF_FACTURAS;--||chr(9) ||chr(10);
                    elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                          v_monto := trim(to_char(w.monto,'9G999G999G999G990D99'));
                          v_adjunto:=null;
                          v_adjunto :=rpad(v_nom_cli_debito,120,' ') ||
                          rpad(w.fec_pago,10,' ') ||
                          rpad(w.fec_ingreso,10,' ') ||
                          rpad(w.cta_debito,15,' ') ||
                          rpad(w.CTA_CREDITO,15,' ') ||
                          rpad(v_monto,18.2,' ') ||
                          rpad(w.cod_moneda,3,' ') ||
                          rpad(w.nro_factura,20,' ') ||
                          rpad(w.NRO_OPERACION,20,' ') ||
                          rpad(w.FOR_PAGO,32,' ') ||
                          rpad(nvl(to_char(w.cod_tip_doc_beneficiario),' '),3,' ') ||
                          rpad(nvl(w.NRO_DOC_BENEFICIARIO,' '),20,' ') ||
                          rpad(nvl(to_char(w.BCO_BENEFICIARIO),' '),20,' ') ||
                          rpad(nvl(w.NRO_CTA_BENEFICIARIO,' '),35,' ') ||
                          rpad(nvl(w.IND_VALOR,' '),1,' ') ||
                          rpad(w.CONCEPTO,35,' ') ||
                          rpad(w.nro_identificador,8,' ') ||
                          rpad(nvl(w.NRO_LOTE,' ') ,12,' ') ||
                          rpad(nvl(w.canal,' '),10,' ') ||
                          rpad(w.nro_tra_sipap,15,' ') ||
                          rpad(nvl( substr(w.est_pag_otr_banco,1,20),' '),20,' ') ||
                          rpad(nvl(w.TIP_RECHAZO,' '),30,' ') ||
                          rpad(nvl(w.REF_FACTURAS,'          '),302,' ')||chr(13)|| CHR(10);

                   end if;
                     UTL_FILE.PUT_LINE(v_file, v_adjunto);

                 end loop;
                 --************fin de Grabar Detalle **************************************
                 --Se inserta el pie de archivo
                 v_texto_detalle := chr(10)||
                 chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_total_procesado||chr(10);
                 UTL_FILE.PUT_LINE(v_file, v_texto_detalle);


             EXCEPTION
                 when others then
                       v_hora:= to_char(sysdate,'hh24:mi:ss');
                       v_error:= substr(to_char(sqlerrm),1,3000);
                       INSERT INTO ge_ra_log_mail
                           (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                          VALUES
                           (SYSDATE, v_nom_adj, 'ERROR', 'Envio Pag.Proveedores ', v_error,v_hora , v_hora);

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
                                                            g_repository,
                                                            v_name || '.'||v_ext_archivo,
                                                            v_dir_archivo || v_name|| '.'||v_ext_archivo);

                    v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
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
                                                            g_repository,
                                                            v_name || '.'||v_ext_archivo,
                                                            v_dir_archivo || v_name|| '.'||v_ext_archivo);

                    v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
                    COMMIT;
              end if;
     END IF;
  end if;

end loop;

  EXCEPTION
    when others then
     raise_application_error(-20000,'PRG_ENV_PAG_PROVEEDORES '||sqlerrm);
  END;
end;
/

