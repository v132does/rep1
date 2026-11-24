create or replace package body it.PAG_PPD is

  -- Private type declarations
 -- type <TypeName> is <Datatype>;

  -- Private constant declarations
 -- <ConstantName> constant <Datatype> := <Value>;

  -- Private variable declarations
 --- <VariableName> <Datatype>;

procedure pr_gen_fec_calendario
  is

 v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_buffer           VARCHAR2(32767);
  v_arc_name         VARCHAR2(150) := 'ppd_itgf_calendario.txt'; -- nombre del archivo
  v_separador        varchar2(1) :='|'; --separador de campos
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;
  v_linetit          VARCHAR2(2000);
  v_respuesta        VARCHAR2(4000);
  --
  v_cod_error        number(5):= 0 ;
  v_msg_error        varchar2(4000);
  --

begin
-- Abrir archivo
  v_file := UTL_FILE.FOPEN(pag_ppd.g_directory,v_arc_name,'W',32767);

-- encabezado del archivo
  v_linetit :='PRI_DIA_HAB_MES|FEC_ACTUAL';
  utl_file.put_line(v_file,v_linetit);
  --
  v_line:= to_char(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),'dd/mm/yyyy')||v_separador ||
           to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'dd/mm/yyyy');   -- frecuenca;
  v_buffer := v_line;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);
  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);

    -- ftp
    v_respuesta := fu_put_ftp_ramail(v_arc_name);
    -- logueo de respuesta
end;



/*
Genera archivo con datos de cuentas para envio de extractos por mail.
*/
procedure pr_gen_arc_cta_ext_mail
  is
cursor cta_extractos is
     select b.cod_persona,
            c.cod_oficina,
            c.cod_modulo,
            c.cod_modalidad,
            c.cod_sub_modalidad,
            c.cod_moneda,
            c.nro_cuenta,
            replace(replace(trim(a.val_parametro),CHR(10),''),CHR(13),'') correo,
            c.fec_ult_extracto,
            c.sal_ult_extracto,
            c.sal_total,
            c.sal_retenido,
            c.Sal_Bloqueado,
            c.Sal_Tot_Batch,
            c.sal_ret_batch,
            c.sal_blo_batch
      from ge_cta_dat_adicionales a,
           ge_cta_clientes        b,
           ah_cta_vistas          c
     where a.nro_cuenta = b.nro_cuenta
       and b.relacion = 'P'
       and b.nro_cuenta = c.nro_cuenta
       and a.parametro = 'EMAIL_ENVIO_EXT_ASCII'
       and c.estado <> 'C'
      union
     select b.cod_persona,
            c.cod_oficina,
            c.cod_modulo,
            c.cod_modalidad,
            c.cod_sub_modalidad,
            c.cod_moneda,
            c.nro_cuenta,
            replace(replace(trim(a.val_parametro),CHR(10),''),CHR(13),'') correo,
            c.fec_ult_extracto,
            c.sal_ult_extracto,
            c.sal_total,
            c.sal_retenido,
            c.Sal_Bloqueado,
            c.Sal_Tot_Batch,
            c.sal_ret_batch,
            c.sal_blo_batch
      from ge_cta_dat_adicionales a,
           ge_cta_clientes        b,
           cc_cta_corrientes          c
     where a.nro_cuenta = b.nro_cuenta
       and b.relacion = 'P'
       and b.nro_cuenta = c.nro_cuenta
       and a.parametro = 'EMAIL_ENVIO_EXT_ASCII'
       and c.estado <> 'C';



  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_buffer           VARCHAR2(32767);
  v_arc_name         VARCHAR2(150) := 'ppd_cta_ext_mail.txt'; -- nombre del archivo
  v_separador        varchar2(1) :='|'; --separador de campos
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;
  v_linetit          VARCHAR2(2000);
  v_respuesta        VARCHAR2(4000);
  --
  v_cod_error        number(5):= 0 ;
  v_msg_error        varchar2(4000);
  --
  v_tienepaquete     number(3):=0;
  v_extseparado      varchar2(1):='N';
  v_imprimeextracto  varchar2(1):='N';
  v_horIni           varchar(10);
  v_horFin           varchar(10);
  v_tip_movim        varchar2(1);

    --
  v_s varchar2(1) default 'x';
  v_q varchar2(1) default 'x';
  v_m varchar2(1) default 'x';
  v_mensual varchar2(1) default 'N';
  v_fec_actual        ge_calendarios.fec_actual%type;
  v_fec_proxima       ge_calendarios.fec_proxima%type;
  v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%type;
  v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%type;
  --
  v_fre_extracto varchar2(10);
  --

begin

pag_cal.pr_obt_dat_calendar(1);
  --
  v_fec_actual        := pag_cal.g_fec_actual;
  v_fec_proxima       := pag_cal.g_fec_proxima;
  v_pri_dia_mes_habil := pag_cal.g_pri_dia_mes_habil;
  v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;
    -- Carga con la fecha hábil siguiente.
  v_fec_proxima := pag_cal.fu_obt_fec_habil(v_fec_actual+1,1,1);
  --
  v_mensual := 'N';
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


-- Abrir archivo para comenzar a escribir el encabezado
v_file := UTL_FILE.FOPEN(pag_ppd.g_directory,v_arc_name,'W',32767);

-- encabezado del archivo
v_linetit :='COD_PERSONA'  ||            v_separador ||
             'NRO_CUENTA'  ||            v_separador ||
             'DENOMINACION'||            v_separador ||
             'OFICINA'     ||            v_separador ||
             'COD_MONEDA'  ||            v_separador ||
             'TIP_CUENTA'  ||            v_separador ||
             'FEC_ULT_EXT' ||            v_separador ||
             'SAL_ULT_EXT' ||            v_separador ||
             'CORREO'      ||            v_separador ||
             'SAL_TOTAL'   ||            v_separador ||
             'TIE_PAQUETE' ||            v_separador ||
             'EXT_SEPARADO'||            v_separador ||
             'IMP_EXTRACTO'||            v_separador ||
             'FORMATO_EXT' ||            v_separador ||
             'FRE_EXTRACTO'||            v_separador ||
             'COD_MODALIDAD'||           v_separador ||
             'PRI_DIA_HAB_MES'||         v_separador ||
             'FEC_ACTUAL'||         v_separador ||
             'COD_OFICINA';

  utl_file.put_line(v_file,v_linetit);
  --
  v_horIni := to_char(sysdate,'hh24:mi:ss');
  for cta in cta_extractos loop
    begin
      v_extseparado    :='N';
      v_tienepaquete   :=0;

    v_fre_extracto := fug_obt_paradicional(cta.nro_cuenta,'EXT_ASCII');
    if v_fre_extracto in ('D',v_s,v_q,v_m) then
        begin
          select 'S'
            into v_extseparado
          from ge_dir_envios f
           where f.cod_persona = cta.cod_persona
             and f.nro_cuenta  = cta.nro_cuenta;
        exception
          when no_data_found then
              v_extseparado :='N';
          when others then
              v_extseparado :='N';
        end;

        -- verificamos si la cuenta esta paquetizada
        begin
          select NVL(g.COD_PAQUETE,0)
            into v_tienepaquete
          from ge_paq_cuentas g, ge_paquetes p
           where g.cod_paquete = p.cod_paquete
             and p.estado = 'A'  -- solo si el paquete esta activo
             and g.nro_cuenta  = cta.nro_cuenta
             and g.cod_persona = cta.cod_persona;
        exception
           when no_data_found then
                v_tienepaquete := 0;
           when too_many_rows then
                v_tienepaquete := 1;
        end;

        v_imprimeextracto :='N';

        v_line:= cta.cod_persona ||                           v_separador ||
                 cta.nro_cuenta ||                            v_separador ||
                 fue_obt_nom_persona(cta.cod_persona) ||      v_separador ||
                 cta.cod_oficina ||'-'||fue_obt_des_oficina(cta.cod_oficina)|| v_separador ||
                 cta.cod_moneda ||                            v_separador ||
                 fug_obt_des_modal(cta.cod_modulo, cta.cod_modalidad) ||       v_separador ||
                 to_char(cta.fec_ult_extracto,'ddmmyyyy') ||  v_separador ||
                 cta.sal_ult_extracto ||                      v_separador ||
                 cta.correo ||                                v_separador ||
                 cta.sal_total ||                             v_separador ||
                 v_tienepaquete ||                            v_separador ||
                 v_extseparado ||                             v_separador ||
                 v_imprimeextracto ||                         v_separador ||
                 fug_obt_paradicional(cta.nro_cuenta,'EMAIL_FOR_ESPECIAL')|| v_separador ||
                 fug_obt_paradicional(cta.nro_cuenta,'EXT_ASCII')|| v_separador ||   -- frecuenca;
                 cta.cod_modalidad||                                v_separador ||
                 to_char(pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(1),'DD/MM/YYYY') || v_separador ||
                 to_char(pag_cal.FU_OBT_FEC_ACTUAL(1),'DD/MM/YYYY')|| v_separador ||
                 cta.cod_oficina;

             IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
                v_buffer := v_buffer || v_eol || v_line;
             ELSE
               IF v_buffer IS NOT NULL THEN
                 --Escribes la linea en el fichero
                 UTL_FILE.PUT_LINE(v_file, v_buffer);
               END IF;
                v_buffer := v_line;
             END IF;
              v_lines := v_lines + 1;
       else
          v_msg_error:= 'No impreso, extracto de frecuencia '||v_fre_extracto;
          insert into ge_log_mail
            (fec_envio, cod_persona, dir_correo, mensaje, det_error, nro_cuenta, hor_inicio, hor_fin)
             values
             (sysdate, cta.cod_persona, substr(cta.correo,1,255),v_msg_error , null, cta.nro_cuenta, v_horIni, v_horFin);

          commit;
          v_msg_error:= null;
        end if;
        v_fre_extracto := null;
    EXCEPTION
        WHEN OTHERS THEN
          v_horFin := to_char(sysdate,'hh24:mi:ss');
          v_cod_error := -10;
          v_msg_error := 'Cliente: '||cta.cod_persona||' Cta:' ||cta.nro_cuenta||' '||SUBSTR(SQLERRM,1,3000);
          PRG_ACT_LOG_PROCESOS('PAG_PPD','PR_GEN_ARC_CTA_EXT_MAIL',trunc(sysdate),v_horIni, v_horFin,'ERROR '||v_cod_error||': '||v_msg_error);
          RAISE;
    end;
  end loop;
  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);
  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);

 --logueo de fin de proceso de generacion de archivo
  v_horFin := to_char(sysdate,'hh24:mi:ss');
  PRG_ACT_LOG_PROCESOS('PAG_PPD','PR_GEN_ARC_CTA_EXT_MAIL',trunc(sysdate),v_horIni, v_horFin,'Archivo de cuentas');
  --
    -- invocamos al ftp para la transferencia del archivo al servidor de ppd
  if nvl(v_cod_error,0) = 0 then
    v_horIni :=to_char(sysdate,'hh24:mi:ss');
    -- ftp
    v_respuesta := fu_put_ftp_ramail(v_arc_name);
    -- logueo de respuesta
    v_horFin := to_char(sysdate,'hh24:mi:ss');
    PRG_ACT_LOG_PROCESOS('PAG_PPD','FU_INI_FTP_RAMAIL',trunc(sysdate),v_horIni, v_horFin,'FTP '||v_respuesta||'- Archivo: '||v_arc_name);
  end if;
  ---

/*  if v_respuesta ='OK' then
    v_cod_error:= 0;
    v_msg_error :=   v_respuesta;
  else
    v_cod_error:=-11;
    v_msg_error :=   nvl(v_respuesta,v_msg_error);
  end if;
*/

end;

/******************************************************************************************
Funcion para transferencia de archivos por FTP
*******************************************************************************************/
function fu_put_ftp_ramail(p_nom_archivo in varchar2)
  return varchar2 is


  -- Variables para FTP
  v_respuesta        VARCHAR2(4000);
  v_hini_ftp         ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp         ge_ra_log_ftp.hor_fin%type;
begin
  v_hini_ftp := to_char(sysdate,'hh24:mi:ss');

  -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
  v_respuesta := pa_file_ftp.fu_put_ascii(pag_ppd.g_ppd_svrip, pag_ppd.g_ppd_svrport, pag_ppd.g_ppd_user,
                                          pag_ppd.g_ppd_pass, g_directory,
                                          p_nom_archivo, pag_ppd.g_sha_folder||p_nom_archivo);
  v_hfin_ftp := to_char(sysdate,'hh24:mi:ss');


  IF v_respuesta = 'OK' THEN  --ARCHIVO ENVIADO POR FTP
     return 'OK';
  ELSE  -- ERROR AL ENVIAR ARCHIVO POR FTP
    -- Insertamos el error del envio al directorio compartido
    INSERT INTO ge_ra_log_ftp
     (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES
     (SYSDATE, p_nom_archivo, v_respuesta, v_hini_ftp, v_hfin_ftp);
    COMMIT;

     return v_respuesta;

  END IF;
end;
--

/************************************************************************************************************
Generacion de archivos de movimientos de cuentas de Ahorro y cuenta corriente
************************************************************************************************************/
procedure pr_gen_arc_mov_ext_mail
  is

  v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);

  cursor c_movim is
  select mov.FECHA, mov.HORA, mov.COD_USUARIO, mov.NRO_SECUENCIA, mov.FEC_VALOR, mov.MONTO, mov.NRO_CUENTA, mov.COD_MONEDA,
    mov.COD_OFICINA, mov.COD_OFI_ORIGEN, mov.CONCEPTO, mov.REVERSADO, mov.COD_USU_REVERSION, mov.HOR_REVERSION, mov.COD_TRA_PADRE,
    mov.COD_MOD_PADRE, mov.COD_MAD_PADRE, mov.COD_TRANSACCION, mov.COD_MODULO, mov.COD_MODALIDAD, mov.MTO_EQU_LOCAL, mov.COTIZACION,
    mov.NRO_DOCUMENTO, mov.NRO_DOCUMENTO2, mov.FEC_INSERCION, mov.FEC_MODIFICACION, mov.COD_PERSONA,
    DECODE(fug_obt_tra_tipo(y.cod_transaccion, y.tipo, y.afecta), 'D','D','C') tipoMovim
    from (
    select
         fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, x.nro_cuenta, x.cod_moneda, x.cod_oficina,
         cod_error, x.cod_retencion, fec_fin_retencion, est_cuenta, x.estado, cod_causa, x.cod_banco, cod_ofi_origen,
         concepto, x.cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion, hor_reversion,
         emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre, x.cod_transaccion, x.cod_modulo, x.cod_modalidad,
         mto_equ_local, nro_caja, cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
         nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador, x.usu_insercion, x.fec_insercion,
         x.usu_modificacion, x.fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, x.nro_folio, referencia,
         x.cod_persona, cod_sit_contable, nro_conciliacion
        from ah_movimientos_his x, ah_cta_vistas z, ge_cta_dat_adicionales ad
        where z.nro_cuenta = x.nro_cuenta
          and x.fecha > z.fec_ult_extracto
          and z.nro_cuenta = ad.nro_cuenta
          and ad.parametro = 'EMAIL_ENVIO_EXT_ASCII'
          and x.fecha <= v_fec_actual
          and (x.REVERSADO = 'N' OR
              (x.REVERSADO = 'S' AND
               FEC_VALOR <= z.FEC_ULT_EXTRACTO   AND
               EXISTS (SELECT 1 FROM AH_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                        WHERE x.FEC_VALOR = REV.FECHA
                          AND x.HOR_REVERSION  = REV.HORA
                          AND x.COD_USU_REVERSION = REV.COD_USUARIO
                          AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA)) OR
              (x.REVERSADO = 'S' AND x.COD_TRA_PADRE IN (303,302) AND x.Cod_Mad_Padre = 455))
           AND x.ESTADO = 'N'
           AND x.NRO_FOLIO IS NULL
    union
     select
         fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, x.nro_cuenta, x.cod_moneda, x.cod_oficina,
         cod_error, x.cod_retencion, fec_fin_retencion, est_cuenta, x.estado, cod_causa, x.cod_banco, cod_ofi_origen,
         concepto, x.cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado, cod_usu_reversion, hor_reversion,
         emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre, x.cod_transaccion, x.cod_modulo, x.cod_modalidad,
         mto_equ_local, nro_caja, cotizacion, cod_bco_central, nro_documento, nro_documento2, nro_documento3,
         nro_documento4, protegido, cod_autorizacion, cod_usu_autorizador, x.usu_insercion, x.fec_insercion,
         x.usu_modificacion, x.fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, x.nro_folio, referencia,
         x.cod_persona, cod_sit_contable, nro_conciliacion
        from cc_cta_corrientes z, cc_movimientos_his x, ge_cta_dat_adicionales ad
        where z.nro_cuenta = x.nro_cuenta
          and x.fecha > z.fec_ult_extracto
          and z.nro_cuenta = ad.nro_cuenta
          and ad.parametro = 'EMAIL_ENVIO_EXT_ASCII'
          and x.fecha <= v_fec_actual
          and (x.REVERSADO = 'N' OR
              (x.REVERSADO = 'S' AND
               FEC_VALOR <= z.FEC_ULT_EXTRACTO   AND
               EXISTS (SELECT 1 FROM CC_MOVIMIENTOS_HIS REV  -- CB. 25/09/2013.
                        WHERE x.FEC_VALOR = REV.FECHA
                          AND x.HOR_REVERSION  = REV.HORA
                          AND x.COD_USU_REVERSION = REV.COD_USUARIO
                          AND x.NRO_SECUENCIA = REV.NRO_SECUENCIA)) OR
              (x.REVERSADO = 'S' AND x.COD_TRA_PADRE IN (303,302) AND x.Cod_Mad_Padre = 455))
           AND x.ESTADO = 'N'
           AND x.NRO_FOLIO IS NULL) mov, GE_TRANSACCIONES y
    where mov.COD_MODULO = y.COD_MODULO
     AND mov.COD_MODALIDAD = y.COD_MODALIDAD
     AND mov.COD_TRANSACCION = y.COD_TRANSACCION
     AND y.VE_CLIENTE = 'S'
     AND NVL(y.AFECTA,'XX') != 'B'
     AND y.TIPO IN ('C','D')
     order by mov.fecha, mov.fec_valor, mov.hora ;

   TYPE typ_movim IS TABLE OF c_movim%ROWTYPE;
   mov typ_movim;

  v_file             UTL_FILE.FILE_TYPE;
  v_line             VARCHAR2(32767);
  v_buffer           VARCHAR2(32767);
  v_arc_name         VARCHAR2(150) := 'ppd_mov_ext_mail.txt'; -- nombre del archivo
  v_separador        varchar2(1) :='|'; --separador de campos
  v_lines            PLS_INTEGER := 0;
  v_eol              CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen           CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline          CONSTANT PLS_INTEGER := 32767;
  v_linetit          VARCHAR2(2000);
  v_respuesta        VARCHAR2(4000);
  v_cod_error        number(5):= 0 ;
  v_msg_error        varchar2(4000);
  v_codpersona       ba_personas.cod_persona%type;
  v_destransaccion   ge_transacciones.descripcion%type;
  v_horIni           varchar2(10);
  v_horFin           varchar2(10);
  v_concepto         ge_movimientos.concepto%type;
  v_tip_mvto         varchar2(1);
  v_monto            ge_movimientos.monto%type;
  --
  v_s varchar2(1) default 'x';
  v_q varchar2(1) default 'x';
  v_m varchar2(1) default 'x';
  v_mensual varchar2(1) default 'N';
  v_fec_proxima       ge_calendarios.fec_proxima%type;
  v_pri_dia_mes_habil ge_calendarios.pri_dia_mes_habil%type;
  v_ult_dia_mes_habil ge_calendarios.ult_dia_mes_habil%type;
  --
  v_fre_extracto varchar2(10);
  --

begin

pag_cal.pr_obt_dat_calendar(1);
  --
  v_fec_actual        := pag_cal.g_fec_actual;
  v_fec_proxima       := pag_cal.g_fec_proxima;
  v_pri_dia_mes_habil := pag_cal.g_pri_dia_mes_habil;
  v_ult_dia_mes_habil := pag_cal.g_ult_dia_mes_habil;
    -- Carga con la fecha hábil siguiente.
  v_fec_proxima := pag_cal.fu_obt_fec_habil(v_fec_actual+1,1,1);
  --
  v_mensual := 'N';
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


-- Abrir archivo
v_file := UTL_FILE.FOPEN(pag_ppd.g_directory,v_arc_name,'W',32767);

-- encabezado del archivo
v_linetit := 'FECHA' ||                    v_separador ||
              'HORA' ||                    v_separador ||
              'COD_USUARIO'||              v_separador ||
              'NRO_SEQ'    ||              v_separador ||
              'FEC_VALOR'  ||              v_separador ||
              'MONTO'      ||              v_separador ||
              'NRO_CUENTA' ||              v_separador ||
              'COD_MONEDA' ||              v_separador ||
              'NRO_COMPROBANTE'  ||        v_separador ||
              'NRO_COMPROBANTE2' ||        v_separador ||
              'COD_PERSONA'      ||        v_separador ||
              'TIP_MOVIM'        ||        v_separador ||
              'DESC_TRANSACCION' ||        v_separador ||
              'COD_OFICINA'      ||        v_separador ||
              'COD_OFI_ORIGEN'   ||        v_separador ||
              'CONCEPTO' ||                v_separador ||
              'REVERSADO'||                v_separador ||
              'USU_REVERSION' ||           v_separador ||
              'HORA_REVERSION'||           v_separador ||
              'COD_TRA_PADRE' ||           v_separador ||
              'COD_MOD_PADRE' ||           v_separador ||
              'COD_MODAL_PADRE'  ||        v_separador ||
              'COD_TRANSACCION'  ||        v_separador ||
              'COD_MODULO'       ||        v_separador ||
              'COD_MODALIDAD'    ||        v_separador ||
              'MTO_EQU_MON_LOCAL'||        v_separador ||
              'COTIZACION'       ||        v_separador ||
              'FEC_INSERCION'    ||        v_separador ||
              'FEC_MODIFICACION';

  utl_file.put_line(v_file,v_linetit);
  --
  v_horIni := to_char(sysdate,'hh24:mi:ss');
OPEN c_movim;
 LOOP
   FETCH c_movim BULK COLLECT
      INTO mov LIMIT  10000;
    FOR i IN 1 .. mov.count LOOP
      begin
      v_fre_extracto := nvl(fug_obt_paradicional(mov(i).nro_cuenta,'EXT_ASCII'),'N');
      if v_fre_extracto in ('D',v_s,v_q,v_m) then

          v_codpersona           := fug_obt_cli_principal(mov(i).nro_cuenta);
          v_destransaccion       := fug_obt_des_transaccion(mov(i).cod_mod_padre, mov(i).cod_mad_padre, mov(i).cod_tra_padre);
          v_concepto             := replace(replace(trim(mov(i).concepto),CHR(10),''),CHR(13),'');

          /*
          aqui validar reversados!!
          */
          v_tip_mvto:= null;
          v_monto :=0;

          if ((mov(i).reversado ='S' and mov(i).monto < 0) or (mov(i).reversado ='N' and mov(i).monto < 0))  then
             -- si es un movim de debito reversado con monto negativo, debe visualizarse como crédito
             -- si es un movim de credito reversado con monto negativo, debe visualizarse como debito
             if mov(i).tipomovim ='D' then
                v_tip_mvto:='C';
             else
                v_tip_mvto:='D';
             end if;
             -- el valor absoluto del monto del movimiento
             v_monto :=  abs(mov(i).monto);

          else
             v_tip_mvto := mov(i).tipomovim;
             v_monto    := mov(i).monto;
          end if;


            v_line   := to_char(mov(i).fecha,'dd/mm/yyyy') ||v_separador ||
                        mov(i).hora  ||                    v_separador ||
                        mov(i).cod_usuario   ||            v_separador ||
                        mov(i).nro_secuencia ||            v_separador ||
                        to_char(mov(i).fec_valor,'dd/mm/yyyy')|| v_separador ||
                        v_monto              ||            v_separador ||
                        mov(i).nro_cuenta    ||            v_separador ||
                        mov(i).cod_moneda    ||            v_separador ||
                        mov(i).nro_documento ||            v_separador ||
                        mov(i).nro_documento2||            v_separador ||
                        v_codPersona         ||            v_separador ||
                        v_tip_mvto           ||            v_separador ||
                        v_destransaccion     ||            v_separador ||
                        mov(i).cod_oficina   ||            v_separador ||
                        mov(i).cod_ofi_origen||            v_separador ||
                        v_concepto           ||            v_separador ||
                        mov(i).reversado     ||            v_separador ||
                        mov(i).cod_usu_reversion||         v_separador ||
                        mov(i).hor_reversion ||            v_separador ||
                        mov(i).cod_tra_padre ||            v_separador ||
                        mov(i).cod_mod_padre ||            v_separador ||
                        mov(i).cod_mad_padre ||            v_separador ||
                        mov(i).cod_transaccion||           v_separador ||
                        mov(i).cod_modulo    ||            v_separador ||
                        mov(i).cod_modalidad ||            v_separador ||
                        mov(i).mto_equ_local ||            v_separador ||
                        mov(i).cotizacion    ||            v_separador ||
                        mov(i).fec_insercion ||            v_separador ||
                        mov(i).fec_modificacion ;

               IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
                  v_buffer := v_buffer || v_eol || v_line;
               ELSE
                 IF v_buffer IS NOT NULL THEN
                   --Escribes la linea en el fichero
                   UTL_FILE.PUT_LINE(v_file, v_buffer);
                 END IF;
                  v_buffer := v_line;
               END IF;
                v_lines := v_lines + 1;
         end if;
         v_fre_extracto := null;
     EXCEPTION
        WHEN OTHERS THEN
           dbms_output.put_line('v_buffer: '||LENGTH(v_buffer) ||' v_line; ' ||LENGTH(v_line));
           v_cod_error := -13;
           v_msg_error := 'Cliente: '||mov(i).cod_persona||' Cta:' ||mov(i).nro_cuenta||' '||SUBSTR(SQLERRM,1,3000);
           v_horfin    := to_char(sysdate,'hh24:mi:ss');
           PRG_ACT_LOG_PROCESOS('PAG_PPD','PR_GEN_ARC_MOV_EXT_MAIL_BC',trunc(sysdate),v_horIni, v_horFin,'ERROR '||v_cod_error||': '||v_msg_error);

           RAISE;
    end;
  end loop;
     EXIT WHEN c_movim%NOTFOUND;
END LOOP;

  --Escribes la linea en el fichero
  UTL_FILE.PUT_LINE(v_file, v_buffer);
  --Cerrar el handler al fichero
  UTL_FILE.FCLOSE(v_file);

  --logueo de fin de proceso de generacion de archivo
  v_horFin := to_char(sysdate,'hh24:mi:ss');
  PRG_ACT_LOG_PROCESOS('PAG_PPD','PR_GEN_ARC_MOV_EXT_MAIL',trunc(sysdate),v_horIni, v_horFin,'Archivo de MOVIMIENTOS');
  --
    -- invocamos al ftp para la transferencia del archivo al servidor de ppd
  if nvl(v_cod_error,0) = 0 then
    v_horIni :=to_char(sysdate,'hh24:mi:ss');
    -- ftp
    v_respuesta := fu_put_ftp_ramail(v_arc_name);
    -- logueo de respuesta
    v_horFin := to_char(sysdate,'hh24:mi:ss');
    PRG_ACT_LOG_PROCESOS('PAG_PPD','FU_INI_FTP_PPD',trunc(sysdate),v_horIni, v_horFin,'FTP '||v_respuesta||'- Archivo: '||v_arc_name);
  end if;

  /*if v_respuesta ='OK' then
    v_cod_error:= 0;
    v_msg_error :=   v_respuesta;
  else
    v_cod_error:=-11;
    v_msg_error :=   nvl(v_respuesta,v_msg_error);
  end if;
*/

END;

/*
proceso principal
*/
procedure pr_pro_gen_ext_mail is
  begin
    pr_gen_fec_calendario;
    pr_gen_arc_cta_ext_mail;
    pr_gen_arc_mov_ext_mail;
  end;

/******************************************************************************************/

end PAG_PPD;
/

