CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_CON_TARJETAS (
p_cod_ente ge_entes.cod_ente%type default null,
p_fecha date default null
)is
----
  v_fec_actual      date  default pag_cal.fu_obt_fec_actual(1);
  v_fec_imp_det     date := to_date(fug_obt_pardinamico('FEC_IMP_PAGCON_DET'), 'dd/MM/yyyy');
  v_nom_ente        ge_entes.descripcion%type;
  v_dir_mail_deb    ge_par_entes.val_parametro%type;
  v_tip_envio       ge_par_entes.val_parametro%type;
  v_ext_archivo     ge_par_entes.val_parametro%type;
  c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAIL');
  v_texto           varchar2(4000);
  v_texto_detalle   varchar2(32000);
  v_adjunto         varchar2(32000);
  v_cabecera        clob;
  v_nom_adj         varchar2(500);
  v_total_procesado number ;
  v_line            VARCHAR2(32767);
  v_file            UTL_FILE.FILE_TYPE;
  v_name            VARCHAR2(128);-- nombre del archivo
  v_debe            varchar2(200);
  v_haber           varchar2(200);
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
  v_gru_transaccion varchar2(100);
  v_nom_cli_debito  varchar2(100);
  /* -- Variables coneccion*/
  v_repository      VARCHAR2(100);
  g_ip              VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port            VARCHAR2(100) := '21';
  g_user            VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass            VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  v_directorio      VARCHAR2(100);
  v_codigo          number(18):=0;
  v_negocio         varchar2(100);
  v_formato         varchar2(10):='N';
  v_tip_conciliacion VARCHAR2(10);
  --Membrete
  -- DDEVOLUT-40 -- CN: 12/2016 -- Se obtiene a partir de la funcion fug_gen_template
  v_membrete LONG := fug_gen_template('M')|| chr(10);
  V_FIN      LONG := chr(10) ||fug_gen_template('F')|| chr(10);
  V_PIE      LONG := chr(10) ||fug_gen_template('P');
  -- PCCDEEVO-262 Para Facturadores
  v_facturador     varchar2(1);
  v_referencia     varchar2(500);
  v_mai_dif  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_MAI_DIF_REP_PAGCOM');
  -- DDIBEPSA-1 -- 11/2017
  C_GRU_TRA_AC     CONSTANT NUMBER := 101; -- Grupo de Transaccion Acreditaciones a Comercios
  v_cod_bancard ge_entes.cod_ente%TYPE := fug_obt_pardinamico('COD_PAG_COM_BANCARD');
CURSOR g_ente is
    select a.cod_ente,a.cod_persona,b.val_minimo nro_cta
      from ge_entes a, ba_cod_referencias b
        where a.tipo='AC'
          and a.cod_persona=b.val_maximo
          and a.cod_ente= nvl(p_cod_ente,a.cod_ente)
          AND B.DOMINIO='NRO_CTA_ENV_CON'
          and not exists (select 1 from ge_dif_crecom_tmp
                           where nro_cuenta = b.val_minimo)
          order by  b.val_minimo;
CURSOR g_datos is
    select a.* from ge_arc_con_tarjetas_tmp a
        order by a.cod_ente, a.nro_cuenta,a.tipo;
--****** Tarjetas de Debito
CURSOR c_rec(v_cta_debito ge_cuentas.nro_cuenta%TYPE) is
     select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            decode(a.cod_tra_padre,380, 'COMPRA EN NEGOCIOS (POS)','COMPRA EN NEGOCIOS OTRO (POS)') DESCRIPCION,
            --08/03 PCCDEEVO-204 Ajuste de Dato de salida PROCARD
            decode(a.cod_tra_padre,380, decode(a.concepto,'CREDITO TD PROCARD','PROCARD','BANCARD'),trim(substr(a.CONCEPTO,30,30)) ) TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'N' facturador,
            a.nro_documento3,
            0 Nro_Lote
        from ge_movimientos a, ge_gru_transacciones_det b
          WHERE a.fecha=  v_fec_actual
            and a.ESTADO='N'
            and b.cod_gru_transaccion= 100
            and a.cod_tra_padre=b.cod_transaccion
            and a.cod_mod_padre=b.cod_modulo
            and a.cod_mad_padre=b.cod_modalidad
            and nro_cuenta = v_cta_debito
            and a.REVERSADO='N'
            and a.COD_TRA_PADRE=380 --Solo Bancard
    UNION ALL
     select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            'PAGO DE SERVICIOS' DESCRIPCION,
            --08/03 PCCDEEVO-204 Ajuste de Dato de salida PROCARD
            'BANCARD' TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'N' facturador,
            a.nro_documento3,
            0 Nro_Lote
        from ge_movimientos a
          WHERE a.fecha=  v_fec_actual
            and a.ESTADO='N'
            and nro_cuenta = v_cta_debito
            and a.REVERSADO='N'
            and a.COD_TRA_PADRE=488 --Solo Bancard, Pago de Servicios Debito en Cuenta
     union all
       select    a.cod_oficina,
                  a.nro_cuenta,
                  a.cod_persona cod_persona,
                  a.fecha,
                  a.fec_valor,
                  a.cod_moneda,
                  a.monto haber,
                  0 debe,
                  a.estado,
                  upper(b.denominacion) concepto,
                  a.cod_tra_padre,
                  'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                  decode(a.Nro_Documento3,482, 'CABAL',483,'PANAL','BEPSA') TIPO, --Para Cabal/Panal/Bepsa
                  a.nro_documento,
                  upper(a.concepto) negocio,
                  'N' facturador,
                   a.nro_documento3,
                   0 Nro_Lote
              from ge_movimientos a,ge_cuentas b, ge_cta_clientes c
                WHERE a.ESTADO='N'
                  and a.fecha= v_fec_actual
                  and a.NRO_CUENTA =v_cta_debito
                  and a.NRO_DOCUMENTO3 in (482,483,484)
                  and a.nro_cuenta=b.nro_cuenta
                  and C.relacion='P'
                  and a.REVERSADO='N'
                  and a.NRO_CUENTA=c.nro_cuenta
    union all
        select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'PROCARD' TIPO,
                a.nro_documento,
                upper(c.denominacion) negocio ,
                'N' facturador,
                a.nro_documento3,
                0 Nro_Lote
            from ge_movimientos a, ge_pag_comercios b, ge_cuentas c
              WHERE a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.fecha=  v_fec_actual
                and a.REVERSADO='N'
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = 1090 --Solo se toma PROCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
      union all
              select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                b.importe haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'BANCARD' TIPO,
                b.nro_resumen,
                upper(c.denominacion) negocio ,
                'N' facturador,
                a.nro_documento3,
                0 Nro_Lote
            from ge_movimientos a, ge_pag_comercios_det b, ge_cuentas c
              WHERE a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and a.FECHA = b.fec_proceso
                and a.nro_cuenta=c.nro_cuenta
                and a.nro_cuenta = b.nro_cuenta
                and a.fecha=  v_fec_actual
                and a.REVERSADO='N'
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = v_cod_bancard --Solo se BANCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
      union all
            ---- PCCDEEVO-262 Para Facturadores
            select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            'PAGO DE FACTURAS/SERVICIOS - P.O.S.' DESCRIPCION,
            'INFONET COBRANZAS' TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'S' facturador,
             a.nro_documento3,
             0 Nro_Lote
        from ge_movimientos a
          WHERE a.ESTADO='N'
            and nro_cuenta = v_cta_debito
            and a.fecha=  v_fec_actual
            and a.REVERSADO='N'
            and a.COD_TRA_PADRE=227 --Facturacion
       union all
           select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            decode(a.cod_tra_padre,495, 'COMPRA EN NEGOCIOS (ZIMPLE)','COMPRA EN NEGOCIOS OTRO (ZIMPLE)') DESCRIPCION,
            trim(substr(a.CONCEPTO,30,30))  TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'N' facturador,
            a.nro_documento3,
            0 Nro_Lote
            from ge_movimientos a
            WHERE a.fecha=  v_fec_actual
              and a.ESTADO='N'
              and a.cod_tra_padre= 495 --COMPRA EN POS (ZIMPLE)
              and nro_cuenta = v_cta_debito
              and a.REVERSADO='N'
    UNION ALL -- DDIBEPSA-1 -- 11/2017 --
        SELECT a.cod_oficina, a.nro_cuenta, a.cod_persona, a.fecha, a.fec_valor, a.cod_moneda,
               DECODE(th.tipo, 'C', a.monto, 0) haber,
               DECODE(th.tipo, 'D', a.monto, 0) debe,
               a.estado, upper(a.concepto) concepto, a.cod_tra_padre,
               tp.descripcion DESCRIPCION, e.descripcion TIPO,
               a.nro_documento, upper(a.concepto) negocio,
               'N' facturador,a.nro_documento3, ac.nro_lote
          FROM ge_movimientos a, ge_gru_transacciones_det b, ge_transacciones tp,
               ge_acr_comercios ac, ge_entes e, ge_transacciones th
         WHERE a.cod_tra_padre = b.cod_transaccion(+)
           AND a.cod_mod_padre = b.cod_modulo(+)
           AND a.cod_mad_padre = b.cod_modalidad(+)
           AND b.cod_transaccion = tp.cod_transaccion
           AND a.cod_tra_padre = tp.cod_transaccion
           AND a.fecha = ac.fec_movimiento
           AND a.hora = ac.hor_movimiento
           AND a.nro_documento2 = ac.nro_referencia
           AND ac.cod_ente = e.cod_ente
           AND a.cod_transaccion = th.cod_transaccion
           AND a.cod_modulo = th.cod_modulo
           AND a.cod_modalidad = th.cod_modalidad
           AND a.fecha = v_fec_actual
           AND nro_cuenta = v_cta_debito
           AND b.cod_gru_transaccion = C_GRU_TRA_AC
           AND a.ESTADO = 'N'
           AND a.REVERSADO = 'N'
           AND ac.tip_tarjeta = 'TD' -- Tarjeta D?bito
         order by 2,13;

--*****Para Tarjetas de Creditos *************
 CURSOR c_rec_tc(v_cta_debito ge_cuentas.nro_cuenta%TYPE) is

       select   a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(b.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                decode(a.Nro_Documento3,482, 'CABAL',483,'PANAL','BEPSA') TIPO, --Para Cabal/Panal/Bepsa
                a.nro_documento,
                upper(b.denominacion) negocio,
                'N' facturador,
                a.nro_documento3,
                0 Nro_Lote
              from ge_movimientos a,ge_cuentas b, ge_cta_clientes c
                WHERE a.ESTADO='N'
                  and a.fecha= v_fec_actual
                  and a.NRO_CUENTA =v_cta_debito
                  and a.NRO_DOCUMENTO3 in (482,483,484)
                  and a.nro_cuenta=b.nro_cuenta
                  and C.relacion='P'
                  and a.REVERSADO='N'
                  and a.NRO_CUENTA=c.nro_cuenta
    union all
        select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'PROCARD' TIPO,
                a.nro_documento,
                upper(c.denominacion) negocio,
                'N' facturador ,
                a.nro_documento3,
                0 Nro_Lote
            from ge_movimientos a, ge_pag_comercios b, ge_cuentas c
              WHERE a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.fecha=  v_fec_actual
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = 1090 --Solo se toma PROCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
                and a.REVERSADO='N'
        UNION ALL
                select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                b.importe haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'BANCARD' TIPO,
                b.nro_resumen,
                upper(c.denominacion) negocio,
                'N' facturador ,
                a.nro_documento3,
                0 Nro_Lote
            from ge_movimientos a, ge_pag_comercios_det b, ge_cuentas c
              WHERE a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and a.FECHA= b.fec_proceso
                and a.nro_cuenta=c.nro_cuenta
                and a.nro_cuenta = b.nro_cuenta
                and a.fecha=  v_fec_actual
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente =v_cod_bancard --Solo se toma BANCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
                and a.REVERSADO='N'
    UNION ALL -- DDIBEPSA-1 -- 11/2017 --
        SELECT a.cod_oficina, a.nro_cuenta, a.cod_persona, a.fecha, a.fec_valor, a.cod_moneda,
               DECODE(th.tipo, 'C', a.monto, 0) haber,
               DECODE(th.tipo, 'D', a.monto, 0) debe,
               a.estado, upper(a.concepto) concepto, a.cod_tra_padre,
               tp.descripcion DESCRIPCION, e.descripcion TIPO,
               a.nro_documento, upper(a.concepto) negocio,
               'N' facturador, a.nro_documento3, ac.nro_lote
          FROM ge_movimientos a, ge_gru_transacciones_det b, ge_transacciones tp,
               ge_acr_comercios ac, ge_entes e, ge_transacciones th
         WHERE a.cod_tra_padre = b.cod_transaccion(+)
           AND a.cod_mod_padre = b.cod_modulo(+)
           AND a.cod_mad_padre = b.cod_modalidad(+)
           AND b.cod_transaccion = tp.cod_transaccion
           AND a.cod_tra_padre = tp.cod_transaccion
           AND a.fecha = ac.fec_movimiento
           AND a.hora = ac.hor_movimiento
           AND a.nro_documento2 = ac.nro_referencia
           AND ac.cod_ente = e.cod_ente
           AND a.cod_transaccion = th.cod_transaccion
           AND a.cod_modulo = th.cod_modulo
           AND a.cod_modalidad = th.cod_modalidad
           AND a.fecha = v_fec_actual
           AND nro_cuenta = v_cta_debito
           AND b.cod_gru_transaccion = C_GRU_TRA_AC
           AND a.ESTADO = 'N'
           AND a.REVERSADO = 'N'
           AND ac.tip_tarjeta = 'TC' -- Tarjeta Cr?dito
         order by 2,13;
--*****Para Historicos ****************************************
--****** Tarjetas de Debito Historico
CURSOR c_rec_his(v_cta_debito ge_cuentas.nro_cuenta%TYPE) is
     select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            decode(a.cod_tra_padre,380, 'COMPRA EN NEGOCIOS (POS)','COMPRA EN NEGOCIOS OTRO (POS)') DESCRIPCION,
            --08/03 PCCDEEVO-204 Ajuste de Dato de salida PROCARD
            decode(a.cod_tra_padre,380, decode(a.concepto,'CREDITO TD PROCARD','PROCARD','BANCARD'),trim(substr(a.CONCEPTO,30,30)) ) TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'N' facturador,
            a.nro_documento3,
            0 Nro_Lote
        from gv_movimientos a, ge_gru_transacciones_det b
          WHERE a.fecha=  p_fecha
            and a.ESTADO='N'
            and b.cod_gru_transaccion= 100
            and a.cod_tra_padre=b.cod_transaccion
            and a.cod_mod_padre=b.cod_modulo
            and a.cod_mad_padre=b.cod_modalidad
            and nro_cuenta = v_cta_debito
            and a.REVERSADO='N'
            and a.COD_TRA_PADRE=380 --Solo Bancard
     union all
     select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            'PAGO DE SERVICIOS' DESCRIPCION,
            --08/03 PCCDEEVO-204 Ajuste de Dato de salida PROCARD
            'BANCARD' TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'N' facturador,
            a.nro_documento3,
            0 Nro_Lote
        from gv_movimientos a
          WHERE a.fecha=  p_fecha
            and a.ESTADO='N'
            and nro_cuenta = v_cta_debito
            and a.REVERSADO='N'
            and a.COD_TRA_PADRE= 488--Solo Bancard, Pago de Servicios Debito en Cuenta
     union all
       select    a.cod_oficina,
                  a.nro_cuenta,
                  a.cod_persona cod_persona,
                  a.fecha,
                  a.fec_valor,
                  a.cod_moneda,
                  a.monto haber,
                  0 debe,
                  a.estado,
                  upper(b.denominacion) concepto,
                  a.cod_tra_padre,
                  'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                  decode(a.Nro_Documento3,482, 'CABAL',483,'PANAL','BEPSA') TIPO, --Para Cabal/Panal/Bepsa
                  a.nro_documento,
                  upper(a.concepto) negocio,
                  'N' facturador,
                   a.nro_documento3,
                   0 Nro_Lote
              from gv_movimientos a,ge_cuentas b, ge_cta_clientes c
                WHERE a.ESTADO='N'
                  and a.fecha= p_fecha
                  and a.NRO_CUENTA =v_cta_debito
                  and a.NRO_DOCUMENTO3 in (482,483,484)
                  and a.nro_cuenta=b.nro_cuenta
                  and C.relacion='P'
                  and a.REVERSADO='N'
                  and a.NRO_CUENTA=c.nro_cuenta
    union all
        select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'PROCARD' TIPO,
                a.nro_documento,
                upper(c.denominacion) negocio ,
                'N' facturador,
                a.nro_documento3,
                0 Nro_Lote
            from gv_movimientos a, ge_pag_comercios b, ge_cuentas c
              WHERE a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.fecha=  p_fecha
                and a.REVERSADO='N'
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = 1090 --Solo se toma PROCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
      union all
              select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'BANCARD' TIPO,
                a.nro_documento,
                upper(c.denominacion) negocio ,
                'N' facturador,
                a.nro_documento3,
                0 Nro_Lote
            from gv_movimientos a, ge_pag_comercios b, ge_cuentas c
              WHERE trunc(fec_proceso) < v_fec_imp_det
                and a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.nro_cuenta = b.nro_cuenta
                and a.fecha=  p_fecha
                and a.REVERSADO='N'
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = v_cod_bancard --Solo se toma BANCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
      union all
       select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                b.importe haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'BANCARD' TIPO,
                b.nro_resumen,
                upper(c.denominacion) negocio ,
                'N' facturador,
                a.nro_documento3,
                0 Nro_Lote
            from gv_movimientos a, ge_pag_comercios_det b, ge_cuentas c
              WHERE fec_proceso >= v_fec_imp_det
                and a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.NRO_CUENTA = b.nro_cuenta
                and a.fecha=  p_fecha
                and a.REVERSADO='N'
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = v_cod_bancard--Solo se toma BANCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
      union all
            ---- PCCDEEVO-262 Para Facturadores
            select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            'PAGO DE FACTURAS/SERVICIOS - P.O.S.' DESCRIPCION,
            'INFONET COBRANZAS' TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'S' facturador,
             a.nro_documento3,
             0 Nro_Lote
        from gv_movimientos a
          WHERE a.ESTADO='N'
            and nro_cuenta = v_cta_debito
            and a.fecha=  p_fecha
            and a.REVERSADO='N'
            and a.COD_TRA_PADRE=227 --Facturacion
     union all
           select a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.fec_valor,
            a.cod_moneda,
            a.monto haber,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            decode(a.cod_tra_padre,495, 'COMPRA EN NEGOCIOS (ZIMPLE)','COMPRA EN NEGOCIOS OTRO (ZIMPLE)') DESCRIPCION,
            trim(substr(a.CONCEPTO,30,30))  TIPO,
            a.nro_documento,
            upper(a.concepto) negocio,
            'N' facturador,
            a.nro_documento3,
            0 Nro_Lote
            from gv_movimientos a
            WHERE a.fecha=  p_fecha
              and a.ESTADO='N'
              and a.cod_tra_padre= 495 --COMPRA EN POS (ZIMPLE)
              and nro_cuenta = v_cta_debito
              and a.REVERSADO='N'
    UNION ALL -- DDIBEPSA-1 -- 11/2017 --
        SELECT a.cod_oficina, a.nro_cuenta, a.cod_persona, a.fecha, a.fec_valor, a.cod_moneda,
               DECODE(th.tipo, 'C', a.monto, 0) haber,
               DECODE(th.tipo, 'D', a.monto, 0) debe,
               a.estado, upper(a.concepto) concepto, a.cod_tra_padre,
               tp.descripcion DESCRIPCION, e.descripcion TIPO,
               a.nro_documento, upper(a.concepto) negocio,
               'N' facturador, a.nro_documento3, ac.nro_lote
          FROM gv_movimientos a, ge_gru_transacciones_det b, ge_transacciones tp,
               ge_acr_comercios_his ac, ge_entes e, ge_transacciones th
         WHERE a.cod_tra_padre = b.cod_transaccion(+)
           AND a.cod_mod_padre = b.cod_modulo(+)
           AND a.cod_mad_padre = b.cod_modalidad(+)
           AND b.cod_transaccion = tp.cod_transaccion
           AND a.cod_tra_padre = tp.cod_transaccion
           AND a.fecha = ac.fec_movimiento
           AND a.hora = ac.hor_movimiento
           AND a.nro_documento2 = ac.nro_referencia
           AND ac.cod_ente = e.cod_ente
           AND a.cod_transaccion = th.cod_transaccion
           AND a.cod_modulo = th.cod_modulo
           AND a.cod_modalidad = th.cod_modalidad
           AND a.fecha = p_fecha
           AND nro_cuenta = v_cta_debito
           AND b.cod_gru_transaccion = C_GRU_TRA_AC
           AND a.ESTADO = 'N'
           AND a.REVERSADO = 'N'
           AND ac.tip_tarjeta = 'TD' -- Tarjeta D?bito
         order by 2,13;

--*****Para Tarjetas de Creditos *************
 CURSOR c_rec_tc_his(v_cta_debito ge_cuentas.nro_cuenta%TYPE) is
       select   a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(b.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                decode(a.Nro_Documento3,482, 'CABAL',483,'PANAL','BEPSA') TIPO, --Para Cabal/Panal/Bepsa
                a.nro_documento,
                upper(b.denominacion) negocio,
                'N' facturador,
                a.nro_documento3,
                0 Nro_Lote
              from gv_movimientos a,ge_cuentas b, ge_cta_clientes c
                WHERE a.ESTADO='N'
                  and a.fecha= p_fecha
                  and a.NRO_CUENTA =v_cta_debito
                  and a.NRO_DOCUMENTO3 in (482,483,484)
                  and a.nro_cuenta=b.nro_cuenta
                  and C.relacion='P'
                  and a.REVERSADO='N'
                  and a.NRO_CUENTA=c.nro_cuenta
    union all
        select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'PROCARD' TIPO,
                a.nro_documento,
                upper(c.denominacion) negocio,
                'N' facturador ,
                a.nro_documento3,
                0 Nro_Lote
            from gv_movimientos a, ge_pag_comercios b, ge_cuentas c
              WHERE a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.fecha=  p_fecha
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = 1090 --Solo se toma PROCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
                and a.REVERSADO='N'
            union all
         select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                a.monto haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'BANCARD' TIPO,
                a.nro_documento,
                upper(c.denominacion) negocio,
                'N' facturador ,
                a.nro_documento3,
                0 Nro_Lote
            from gv_movimientos a, ge_pag_comercios b, ge_cuentas c
              WHERE trunc(fec_proceso) < v_fec_imp_det
                and a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.fecha=  p_fecha
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = v_cod_bancard --Solo se toma BANCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
                and a.REVERSADO='N'
         union all
         select distinct a.cod_oficina,
                a.nro_cuenta,
                a.cod_persona cod_persona,
                a.fecha,
                a.fec_valor,
                a.cod_moneda,
                b.importe haber,
                0 debe,
                a.estado,
                upper(c.denominacion) concepto,
                a.cod_tra_padre,
                'COMPRA EN NEGOCIOS TC' DESCRIPCION,
                'BANCARD' TIPO,
                b.nro_resumen,
                upper(c.denominacion) negocio,
                'N' facturador ,
                a.nro_documento3,
                0 Nro_Lote
            from gv_movimientos a, ge_pag_comercios_det b, ge_cuentas c
              WHERE b.fec_proceso >= v_fec_imp_det
                and a.ESTADO='N'
                and a.NRO_DOCUMENTO=b.cod_ente
                and trunc(a.FECHA)= trunc(b.fec_proceso)
                and a.nro_cuenta=c.nro_cuenta
                and a.fecha=  p_fecha
                and a.COD_TRA_PADRE=36  --Solo por Pago a Comercios
                and b.cod_ente = v_cod_bancard --Solo se toma BANCARD
                and A.nro_cuenta=v_cta_debito --Cuenta a Informar del Ente
                and a.REVERSADO='N'
    UNION ALL -- DDIBEPSA-1 -- 11/2017 --
        SELECT a.cod_oficina, a.nro_cuenta, a.cod_persona, a.fecha, a.fec_valor, a.cod_moneda,
               DECODE(th.tipo, 'C', a.monto, 0) haber,
               DECODE(th.tipo, 'D', a.monto, 0) debe,
               a.estado, upper(a.concepto) concepto, a.cod_tra_padre,
               tp.descripcion DESCRIPCION, e.descripcion TIPO,
               a.nro_documento, upper(a.concepto) negocio,
               'N' facturador, a.nro_documento3, ac.nro_lote
          FROM gv_movimientos a, ge_gru_transacciones_det b, ge_transacciones tp,
               ge_acr_comercios ac, ge_entes e, ge_transacciones th
         WHERE a.cod_tra_padre = b.cod_transaccion(+)
           AND a.cod_mod_padre = b.cod_modulo(+)
           AND a.cod_mad_padre = b.cod_modalidad(+)
           AND b.cod_transaccion = tp.cod_transaccion
           AND a.cod_tra_padre = tp.cod_transaccion
           AND a.fecha = ac.fec_movimiento
           AND a.hora = ac.hor_movimiento
           AND a.nro_documento2 = ac.nro_referencia
           AND ac.cod_ente = e.cod_ente
           AND a.cod_transaccion = th.cod_transaccion
           AND a.cod_modulo = th.cod_modulo
           AND a.cod_modalidad = th.cod_modalidad
           AND a.fecha = p_fecha
           AND nro_cuenta = v_cta_debito
           AND b.cod_gru_transaccion = C_GRU_TRA_AC
           AND a.ESTADO = 'N'
           AND a.REVERSADO = 'N'
           AND ac.tip_tarjeta = 'TC' -- Tarjeta Cr?dito
         order by 2,13;
--************************************************************
 CURSOR g_diferencias is
    select distinct cod_ente, fecha, nro_cuenta
      from ge_dif_crecom_tmp;

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
  v_hora:= to_char(sysdate,'hh24:mi:ss');


  begin
    delete from ge_dif_crecom_tmp;
  exception
    when others then
    RAISE_APPLICATION_ERROR(-20063, 'No se ha podido eliminar datos temporales.' || sqlerrm);
  end;

  if nvl(p_fecha, v_fec_actual)>= v_fec_imp_det then
    begin
        insert into ge_dif_crecom_tmp
         (select t.fec_proceso fecha, t.cod_ente, t.cod_modulo, t.cod_modalidad, t.nro_cuenta
            from ge_pag_comercios_det t, (select trunc(fec_proceso) fec_proceso, cod_ente, nro_cuenta, sum(monto) monto
                                            from ge_pag_comercios d
                                           where d.cod_ente = v_cod_bancard
                                             and trunc(d.fec_proceso) = nvl(p_fecha, v_fec_actual)
                                             and cod_proceso = 0
                                             and estado = 'R'
                                           group by trunc(fec_proceso), cod_ente, nro_cuenta) sc
           where t.cod_ente = v_cod_bancard
             and t.fec_proceso = sc.fec_proceso
             and t.cod_ente = sc.cod_ente
             and t.nro_cuenta = sc.nro_cuenta
             and cod_proceso = 0
             and exists (select 1
                           from ge_entes a, ba_cod_referencias b
                          where a.tipo='AC'
                            and a.cod_persona=b.val_maximo
                            AND B.DOMINIO='NRO_CTA_ENV_CON'
                            and t.nro_cuenta = b.val_minimo)
           group by t.fec_proceso, t.cod_ente, t.cod_modulo, t.cod_modalidad, t.nro_cuenta, sc.monto
           having sum(importe) <> sc.monto
           union all
           select distinct d.fec_proceso fecha, d.cod_ente, d.cod_modulo, d.cod_modalidad, d.nro_cuenta
             from ge_pag_comercios_det d
            where d.cod_ente = v_cod_bancard
              and fec_proceso = nvl(p_fecha, v_fec_actual)
              and cod_proceso = 0
              and not exists (select 1 from ge_pag_comercios p
                               where cod_ente = v_cod_bancard
                                 and p.cod_ente = d.cod_ente
                                 and trunc(p.fec_proceso) = nvl(p_fecha, v_fec_actual)
                                 and p.nro_cuenta = d.nro_cuenta)
              and exists (select 1
                            from ge_entes a, ba_cod_referencias b
                           where a.tipo='AC'
                             and a.cod_persona=b.val_maximo
                             AND B.DOMINIO='NRO_CTA_ENV_CON'
                             and d.nro_cuenta = b.val_minimo));
      exception
        when others then
          null;
      end;
  end if;
  --Si fecha es nula es proceso de Cierre, o si la fecha es la actual, se toma de ge_movimientos
if p_fecha is null or trunc(p_fecha)= trunc(v_fec_actual) then
  for a in g_ente loop
       v_formato:=null;
       v_tip_conciliacion:=null;
       v_repository:= null;
       v_directorio:= null;
       --Para formato(Nuevo / Anterior) --> TD
       v_formato:= nvl(fug_obt_parentes(a.cod_ente,'FOR_ENV_ARCHIVO'),'N');
       v_tip_conciliacion:= nvl(fug_obt_parentes(a.cod_ente,'TIP_CON_ENVIO'),'TD') ;
        ---******** Datos Comunes para TC y TD
       -- Lo demas
       v_repository:= fug_obt_parentes(a.cod_ente,'DIR_REP_ARCHIVO');--'MAIL';
       v_directorio:= fug_obt_parentes(a.cod_ente,'DIR_DEP_ARCHIVO');--'ramail\DYD\';
       v_nom_ente        := fue_obt_nom_ente(a.cod_ente);
       v_dir_mail_deb    := fug_obt_parentes(a.cod_ente,'DIR_MAIL_CT');
       v_tip_envio      := nvl(fug_obt_parentes(a.cod_ente,'TIP_ENV_ARCHIVO'),'M');
       v_ext_archivo    := nvl(fug_obt_parentes(a.cod_ente,'TIP_ARCHIVO'),'txt');
       v_gru_transaccion := nvl(fug_obt_parentes(a.cod_ente,'GRU_TRANSACCION'),100);
       -- Tipo de Archivo
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

 if v_tip_conciliacion in ('TD','AM') then
         -- Borramos la tabla temporal para volver a cargar
         delete from ge_arc_con_tarjetas_tmp;
         --Seteos iniciales
         v_texto_detalle := null;
         v_adjunto       := null;
         v_total_procesado := 0;  --Seteos iniciales
       /**********Logica para TARJETAS DE DEBITO O AMBOS***********************/
       --Para depositar Archivo
       IF nvl(v_tip_envio,'M') = 'A' THEN
           -- ENVIO FTP
           v_line := null;
           v_name := 'TAR_' || a.nro_cta || '_' ||
                           to_char(v_fec_actual, 'DDMMYY');
           v_name:=lower(v_name);
           if v_directorio is null then
              --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
              insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (c_dir_mail, v_dir_mail_deb,'CONC.COM.TARJ.', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado Directorio parametrizado', sysdate, user);
           end if;
           if v_repository is null then
              --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
              insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
              values (c_dir_mail, v_dir_mail_deb,'CONC.COM.TARJ.', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado Repositorio parametrizado', sysdate, user);
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
           --DYDMR-6621 Se excluye verificaci?n para permitir mas de unas direcci?n de Email
           --v_dir_mail_deb        := fu_val_correo(v_dir_mail_deb);
           v_dir_mail_deb        := trim(v_dir_mail_deb);
           if v_dir_mail_deb is null then
               --Si esta nulo se toma se guarda error
               insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
               values (c_dir_mail, v_dir_mail_deb,'CONCILIACION COMERCIO TARJETAS', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado direccion de mail', sysdate, user);
           end if;

       END IF;
       --Cargamos la nueva tabla temporal con los detalles de operaciones
           for b in c_rec(a.nro_cta) loop
               -- PCCDEEVO-262 Para Facturadores
               v_facturador:= nvl(b.facturador,'N');
               if v_facturador ='S' then --buscamos la referencia
                  begin
                    select UPPER(substr(w.referencia,1,93))
                       into v_referencia
                      from ge_mov_inf_cobranzas w
                          where w.nro_cta_credito= b.nro_cuenta
                             and trunc(w.fecha) <= trunc(b.fecha)
                                  and w.reversado = 'N' and w.liberado = 'S'
                                    and w.nro_documento= b.nro_documento3
                                    and rownum=1;
                  exception
                     when no_data_found then
                        v_referencia:=null;
                     when others then
                        v_referencia:=null;

                  end;
               end if;

               v_total_procesado := v_total_procesado + nvl(b.debe, 0) +  nvl(b.haber, 0);
               begin
                 select nvl(max(a.codigo),0)
                   into v_codigo
                    from ge_arc_con_tarjetas_tmp a;
               exception
                 when others then
                    v_codigo:=0;
               end;
               --06/09 Para Negocio
               v_negocio:=null;
               Begin
                 select a.significado --En el significado lo que quieren que se les envie
                  into v_negocio
                   from ba_cod_referencias a
                   where a.dominio='DEN_CON_ENV_CON'
                    and a.val_maximo=a.nro_cta --En el va_maximo el Nro de cuenta
                     and upper(trim(a.abreviatura))= upper(trim(b.negocio)); --an la abreviatura el concepto;
               Exception
                 when no_data_found then
                   v_negocio:= upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
                 when others then
                   v_negocio:=  upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
               End;
               v_codigo:= nvl(v_codigo,0) +1;
               --07/04 PCCDEEVO-262 Para Facturadores
              insert into ge_arc_con_tarjetas_tmp(CODIGO,COD_ENTE,NRO_CUENTA,FECHA,DESCRIPCION,
                       NRO_DOCUMENTO,DEBE,HABER,COD_MONEDA,TIPO,OBSERVACION,
                       referencia, fec_valor, facturador, nro_lote)
              values(v_codigo, A.COD_ENTE,B.NRO_CUENTA,to_char(B.FECHA,'ddmmyyyy'),B.DESCRIPCION,
                   b.nro_documento, B.DEBE,b.haber,B.COD_MONEDA,B.TIPO,v_negocio,
                   v_referencia, to_char(B.Fec_Valor,'ddmmyyyy'), v_facturador, DECODE(b.nro_lote, 0, NULL, b.nro_lote));


            end loop;
      --Verificamos si se insertaron registros en la tabla para enviar.
     v_cantidad:=0;
      begin
        select count(*)
          into v_cantidad
          from ge_arc_con_tarjetas_tmp;
      exception
        when no_data_found then
          v_cantidad:=0;
        when others then
           v_cantidad:=0;
      end;

  if nvl(v_cantidad,0)> 0 then
         if  nvl(lower(v_ext_archivo),'xls') = 'xls'then
           --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
             if nvl(v_tip_envio,'M') = 'M' then
                  v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) || 'Fecha Transaccion' || chr(9) || 'Descripcion' || chr(9) ||
                           'Nro.Documento' || chr(9) ||'Debe' || chr(9) ||
                          'Haber' || chr(9) ||'Moneda' || chr(9) || 'Tipo'||chr(9)
                          || 'Negocio'||chr(9) || 'Referencia'||chr(9) || 'Nro.Lote'||
                          chr(10);
              else
                  v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) || 'Fecha Transaccion' || chr(9) || 'Descripcion' || chr(9) ||
                           'Nro.Documento' || chr(9) ||'Debe' || chr(9) ||
                          'Haber' || chr(9) ||'Moneda' || chr(9) || 'Tipo'|| chr(9)
                          || 'Negocio'||chr(9) || 'Referencia'||chr(9) || 'Nro.Lote'||
                          chr(10);

              end if;
         elsif nvl(lower(v_ext_archivo),'xls') = 'txt' then
               --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
               if nvl(v_tip_envio,'M') = 'M' then
                   --Negocio Varchar2(50)
                   v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')||rpad('Fec.Tra.',8,' ')|| rpad('Descripcion',35,' ')  ||
                             rpad('Nro.Documento',20,' ')  || lpad('Debe',20,' ')  || lpad('Haber',20,' ')  ||
                             rpad('Mon',3,' ')  || rpad('Tipo',22,' ')|| rpad('Negocio',50,' ')|| rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                            || chr(13) || chr(10);
               else
                   --Negocio Varchar2(50)
                   v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')|| rpad('Fec.Tra.',8,' ') || rpad('Descripcion',35,' ')  ||
                             rpad('Nro.Documento',20,' ')  || lpad('Debe',20,' ')  || lpad('Haber',20,' ')  ||
                             rpad('Mon',3,' ')  || rpad('Tipo',22,' ')|| rpad('Negocio',50,' ')|| rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                             || chr(13) || chr(10);
               end if;

         end if;
             v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente: '|| upper(v_nom_cli_debito) ||'
                   <br><br>
                     Le adjuntamos el Archivo para su Conciliacion de Comercios Tarjetas, correspondiente a la fecha ' ||
                             to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se registraron las operaciones detalladas en el archivo adjunto.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';

          --GAC 12/05/20147 Se agrega membrete, a pedido del usuario solicitante|
          v_nom_adj := lower('TAR_' || a.nro_cta || '_' ||to_char(v_fec_actual, 'DDMMYY'));

          v_asunto   := 'Servicio de Conciliacion de Comercio Tarjetas';
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
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS' || chr(13) || chr(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                 v_cabecera;
                        it_mail.write_text(v_conn, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                        v_texto_detalle := CHR(9) || CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS' || chr(13) || chr(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera;
                        it_mail.write_text(v_conn, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                for w in g_datos loop
                     --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                    if w.facturador  = 'N' then
                        --No facturador -> Referencia Nulo actualmente
                        if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                              w.fecha || chr(9)||
                              w.fec_valor || chr(9)||
                              w.descripcion || chr(9) ||
                              w.nro_documento || chr(9) || w.debe ||chr(9) ||
                              w.haber || chr(9) || w.cod_moneda || chr(9) ||
                              w.tipo||chr(9) ||
                              w.observacion||chr(9) ||  --Negocio
                              null||chr(9) || --Referencia
                              w.nro_lote || chr(9) ||chr(10); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(w.observacion,50,' ') ||   --Negocio
                              rpad(' ',93,' ')  || --Referencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;
                     else
                        --Para Facturadores -- Negocio = Nulo
                        if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                              w.fecha || chr(9)||
                              w.fec_valor || chr(9)||
                              w.descripcion || chr(9) ||
                              w.nro_documento || chr(9) || w.debe ||chr(9) ||
                              w.haber || chr(9) || w.cod_moneda || chr(9) ||
                              w.tipo||chr(9) ||
                              null||chr(9)||  -- Negocio
                              w.referencia||chr(9)|| --Referencia
                              w.nro_lote || chr(9) ||chr(10); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(' ',50,' ') ||   --Negocio
                              rpad(w.referencia,93,' ') || --Referencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;

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
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS'|| chr(13) || chr(10);
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                 v_cabecera;
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                       v_texto_detalle := CHR(9) || CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS';
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera;
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                /*--- DYDMR-7942 18/12/2017 ---*/
                -- Punto para la parte decimal y coma para separador de miles.
                pre_cam_for_numerico('.,');
                for w in g_datos loop
                    --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                    if w.facturador  = 'N' then
                        --No facturador -> Referencia Nulo actualmente
                        if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                             w.fecha || chr(9)||
                             w.fec_valor || chr(9)||
                             w.descripcion || chr(9) ||
                             w.nro_documento || chr(9) || w.debe ||chr(9) ||
                             w.haber || chr(9) || w.cod_moneda || chr(9) ||
                             w.tipo||chr(9) ||
                             w.observacion||chr(9)|| --Negocio
                             null||chr(9)||  --Refereencia
                             w.nro_lote || chr(9); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(w.observacion,50,' ') || --Negocio
                              rpad(' ',93,' ') || --Refereencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;
                     else
                         --Para Facturadores -- Negocio = Nulo
                         if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                             w.fecha || chr(9)||
                             w.fec_valor || chr(9)||
                             w.descripcion || chr(9) ||
                             w.nro_documento || chr(9) || w.debe ||chr(9) ||
                             w.haber || chr(9) || w.cod_moneda || chr(9) ||
                             w.tipo||chr(9) ||
                             null||chr(9)|| --Negocio
                             w.referencia||chr(9)||--Refereencia
                             w.nro_lote || chr(9); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(' ',50,' ') || --Negocio
                              rpad(w.referencia,93,' ') ||--Refereencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;

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
                           (SYSDATE, v_nom_adj, 'ERROR', 'Envio Con.Tarjetas ', v_error,v_hora , v_hora);

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
  end if;

end if;
--****************FIN DE TARJETAS DE DEBITO O AMBOS *************************************************
--*************** PARA TARJETAS DE CREDITO O AMBOS  *************************************************
if v_tip_conciliacion in ('TC','AM') then
    --************Logica para TARJETAS DE CREDITO O AMBOS**********************
          -- Borramos la tabla temporal para volver a cargar
         delete from ge_arc_con_tarjetas_tmp;
         --Seteos iniciales
         v_texto_detalle := null;
         v_adjunto       := null;
         v_total_procesado := 0;
         v_cabecera:= null;
         v_texto:=null;
         v_texto_detalle:=null;
         v_name := null;
         v_line := null;
         --Para depositar Archivo
         IF nvl(v_tip_envio,'M') = 'A' THEN
             -- ENVIO FTP
             v_line := null;
             v_name := 'TAR_' || a.nro_cta || '_' ||
                             to_char(v_fec_actual, 'DDMMYY')||'_TC';
             v_name:=lower(v_name);
             if v_directorio is null then
                --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
                insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                values (c_dir_mail, v_dir_mail_deb,'CONCILIACION COMERCIO TARJETAS-TC', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado Directorio parametrizado', sysdate, user);
             end if;
             if v_repository is null then
                --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
                insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                values (c_dir_mail, v_dir_mail_deb,'CONC. COM. TARJ.-TC', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado Repositorio parametrizado', sysdate, user);
             end if;
              -- Abrir archivo
              if v_repository is not null and v_directorio is not null then
                  v_file := UTL_FILE.FOPEN(v_repository,
                                          lower(v_name) || '.'||lower(v_ext_archivo),
                                          'W',
                                          32767);
              end if;
         elsIF nvl(v_tip_envio,'M') = 'M' THEN
           --DYDMR-6621 Se excluye verificaci?n para permitir mas de unas direcci?n de Email
           --v_dir_mail_deb        := fu_val_correo(v_dir_mail_deb);
           v_dir_mail_deb         := trim(v_dir_mail_deb);
           if v_dir_mail_deb is null then
               --Si esta nulo se toma se guarda error
               insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
               values (c_dir_mail, v_dir_mail_deb,'CONC. COM. TARJ.-TC', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado direccion de mail', sysdate, user);
           end if;
         END IF;

         --Cargamos la nueva tabla temporal con los detalles de operaciones
         --Solo si esta parametrizado se ejecuta TARJETAS DE CREDITO
             for b in c_rec_tc(a.nro_cta) loop
                 -- PCCDEEVO-262 Para Facturadores
                 v_facturador:= nvl(b.facturador,'N');
                 if v_facturador ='S' then --buscamos la referencia
                    begin
                      select upper(substr(trim(w.referencia),1,93))
                         into v_referencia
                        from ge_mov_inf_cobranzas w
                            where w.nro_cta_credito= b.nro_cuenta
                               and trunc(w.fecha) <= trunc(b.fecha)
                                    and w.reversado = 'N' and w.liberado = 'S'
                                      and w.nro_documento= b.nro_documento3
                                      and rownum=1;
                    exception
                       when no_data_found then
                          v_referencia:=null;
                       when others then
                          v_referencia:=null;

                    end;
                 end if;
                 v_total_procesado := v_total_procesado + nvl(b.debe, 0) +  nvl(b.haber, 0);
                 begin
                   select nvl(max(a.codigo),0)
                     into v_codigo
                      from ge_arc_con_tarjetas_tmp a;
                 exception
                   when others then
                      v_codigo:=0;
                 end;
                 --06/09 Para Negocio
                 v_negocio:=null;
                 Begin
                   select upper(substr(trim(a.significado),1,50)) --En el significado lo que quieren que se les envie
                    into v_negocio
                     from ba_cod_referencias a
                     where a.dominio='DEN_COM_ENV_CON'
                      and a.val_maximo=a.nro_cta --En el va_maximo el Nro de cuenta
                       and upper(trim(a.abreviatura))= upper(trim(b.negocio)); --an la abreviatura el concepto;
                 Exception
                   when no_data_found then
                     v_negocio:= upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
                   when others then
                     v_negocio:=  upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
                 End;
                 v_codigo:= nvl(v_codigo,0) +1;
                 --07/04 Facturador
               insert into ge_arc_con_tarjetas_tmp(CODIGO,COD_ENTE,NRO_CUENTA,FECHA,DESCRIPCION,
                      NRO_DOCUMENTO,DEBE,HABER,COD_MONEDA,TIPO,OBSERVACION,
                      referencia, fec_valor,facturador, nro_lote)
               values(v_codigo,A.COD_ENTE,B.NRO_CUENTA,to_char(B.FECHA,'ddmmyyyy'),B.DESCRIPCION,
                       b.nro_documento,nvl(B.DEBE,0),decode(nvl(b.haber,0),0,nvl(B.DEBE,0),nvl(b.haber,0)),B.COD_MONEDA,B.TIPO,v_negocio,
                       trim(b.concepto), to_char(B.Fec_Valor,'ddmmyyyy'), trim(v_facturador),DECODE(b.nro_lote, 0, NULL, b.nro_lote));
              end loop;
        --Verificamos si se insertaron registros en la tabla para enviar.
       v_cantidad:=0;
       begin
          select count(*)
            into v_cantidad
            from ge_arc_con_tarjetas_tmp;
        exception
          when no_data_found then
            v_cantidad:=0;
          when others then
             v_cantidad:=0;
        end;
  if nvl(v_cantidad,0)> 0 then
           if  nvl(lower(v_ext_archivo),'xls') = 'xls'then
             --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                  if nvl(v_tip_envio,'M') = 'M' then
                      v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) ||'Fecha Transaccion' ||
                                chr(9) || 'Descripcion' || chr(9) ||
                               'Total' || chr(9) ||'Moneda' || chr(9) ||'Negocio'|| chr(9) ||'Referencia'||chr(9) || 'Nro.Lote'||
                               chr(10);
                  else
                      v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) ||'Fecha Transaccion' || chr(9)||
                               'Descripcion' || chr(9) ||
                               'Total' || chr(9) ||'Moneda' || chr(9)|| 'Negocio'|| chr(9)|| 'Referencia'||chr(9) || 'Nro.Lote'||
                               chr(10);

                  end if;
           elsif nvl(lower(v_ext_archivo),'xls') = 'txt' then
             if nvl(v_tip_envio,'M') = 'M' then
                 --Negocio Varchar2(50)
                 v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')||rpad('Fec.Tra.',8,' ')|| rpad('Descripcion',35,' ')  ||
                           lpad('Total',20,' ')||rpad('Mon',3,' ')|| rpad('Negocio',50,' ')|| rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                           ||chr(13)||chr(10);
             else
                 --Negocio Varchar2(50)
                 v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')||rpad('Fec.Tra.',8,' ')|| rpad('Descripcion',35,' ')  ||
                           lpad('Total',20,' ')||rpad('Mon',3,' ')  ||rpad('Negocio',50,' ')||rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                           ||chr(13)||chr(10);
             end if;
           end if;
               v_texto := '<br><br>
                     <br><br>
                       Estimado Cliente: '|| upper(v_nom_cli_debito) ||'
                     <br><br>
                       Le adjuntamos el Archivo para su Conciliacion de Comercios Tarjetas(TC), correspondiente a la fecha ' ||
                               to_char(v_fec_actual, 'DD/MM/YYYY') || ',' || ' en el cual se registraron las operaciones detalladas en el archivo adjunto.
                     <br><br>
                       Atentamente.
                     <br><br>
                     <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                     <br><br>
                     <br><br>';

            --GAC 12/05/20147 Se agrega membrete, a pedido del usuario solicitante|
            v_nom_adj := lower('TAR_' || a.nro_cta || '_' ||to_char(v_fec_actual, 'DDMMYY')||'_TC');

            v_asunto   := 'Servicio de Conciliacion de Comercio Tarjetas(TC)';
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
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC' || chr(13) || chr(10);
                          it_mail.write_text(v_conn, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                   v_cabecera;
                          it_mail.write_text(v_conn, v_texto_detalle);
                   elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                          v_texto_detalle := CHR(9) || CHR(9) ||
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC' || CHR(10);
                          it_mail.write_text(v_conn, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                            v_cabecera;
                          it_mail.write_text(v_conn, v_texto_detalle);
                   end if;
                  --************Para Grabar Detalle **************************************
                  for w in g_datos loop
                   --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                   --No facturador -> Referencia Nulo actualmente
                   if w.facturador = 'N' then
                     if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                            w.fecha || chr(9)||
                            w.fec_valor || chr(9)||
                            w.TIPO || chr(9) ||w.haber ||chr(9) ||
                            w.cod_moneda || chr(9) ||
                            trim(w.observacion)||chr(9) || --Negocio
                            null||chr(9) || --Referencia
                            w.nro_lote || chr(9) ||chr(10); --Nro Lote
                      elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                            v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                            v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                            v_adjunto:=null;
                            v_adjunto :=
                            rpad(w.nro_cuenta,20,' ') ||
                            rpad(w.fecha,8,' ') ||
                            rpad(w.fec_valor,8,' ') ||
                            rpad(w.TIPO,35,' ') ||
                            lpad(v_haber,20,' ') ||
                            rpad(w.cod_moneda,3,' ') ||
                            rpad(trim(w.observacion),50,' ') || --Negocio
                            rpad(' ',93,' ') || --Referencia
                            rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                     end if;
                   else
                      --Para Facturadores -- Negocio = Nulo
                      if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                            w.fecha || chr(9)||
                            w.fec_valor || chr(9)||
                            w.TIPO || chr(9) ||w.haber ||chr(9) ||
                            w.cod_moneda || chr(9) ||
                            null||chr(9) || --Negocio
                            trim(w.referencia)|| chr(9) ||--Referencia
                            w.nro_lote || chr(9) ||chr(10); --Nro Lote
                      elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                            v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                            v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                            v_adjunto:=null;
                            v_adjunto :=
                            rpad(w.nro_cuenta,20,' ') ||
                            rpad(w.fecha,8,' ') ||
                            rpad(w.fec_valor,8,' ') ||
                            rpad(w.TIPO,35,' ') ||
                            lpad(v_haber,20,' ') ||
                            rpad(w.cod_moneda,3,' ') ||
                            rpad(' ',50,' ') || --Negocio
                            rpad(trim(w.referencia),93,' ') || --Referencia
                            rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                     end if;

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
                         insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                          values (c_dir_mail, v_dir_mail_deb, v_asunto, v_texto, sysdate, user);
               END;
            end if;
            --********** fin de Logica para envio por email de los archivos ******************
      ELSE
           if v_repository is not null and v_directorio is not null then
              --*****************Para formato de Archivo **********************
               Begin
                  --*********Para Grabar Cabecera ***************************
                   if nvl(lower(v_ext_archivo),'xls') = 'txt' then
                          v_texto_detalle := CHR(9) || CHR(9) || CHR(9) ||
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC'|| chr(13) || chr(10);
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                   v_cabecera;
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                   elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                         v_texto_detalle := CHR(9) || CHR(9) ||
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC';
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' ||chr(13)||chr(10)||
                                            v_cabecera;
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                   end if;
                  --************Para Grabar Detalle **************************************
                  for w in g_datos loop
                     --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                     --No facturador -> Referencia Nulo actualmente
                   if w.facturador  = 'N' then
                          if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                               w.fecha || chr(9)||
                               w.fec_valor || chr(9)||
                               w.TIPO || chr(9) ||
                               w.haber ||chr(9) ||
                               w.cod_moneda || chr(9) ||
                               trim(w.observacion)||chr(9)|| --Negocio
                               null||chr(9)||--Referencia
                               w.nro_lote || chr(9); --Nro Lote
                          elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                                v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                                v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                                v_adjunto:=null;
                                v_adjunto :=
                                rpad(w.nro_cuenta,20,' ') ||
                                rpad(w.fecha,8,' ') ||
                                rpad(w.fec_valor,8,' ') ||
                                rpad(w.TIPO,35,' ') ||
                                lpad(v_haber,20,' ') ||
                                rpad(w.cod_moneda,3,' ') ||
                                rpad(trim(w.observacion),50,' ') || --Negocio
                                rpad(' ',93,' ') || --Referencia
                                rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                         end if;
                   else
                        --Para Facturadores -- Negocio = Nulo
                           if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                               w.fecha || chr(9)||
                               w.fec_valor || chr(9)||
                               w.TIPO || chr(9) ||
                               w.haber ||chr(9) ||
                               w.cod_moneda || chr(9) ||
                               null||chr(9)||--Negocio
                               trim(w.referencia)||chr(9)|| --Referencia
                               w.nro_lote || chr(9); --Nro Lote
                          elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                                v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                                v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                                v_adjunto:=null;
                                v_adjunto :=
                                rpad(w.nro_cuenta,20,' ') ||
                                rpad(w.fecha,8,' ') ||
                                rpad(w.fec_valor,8,' ') ||
                                rpad(w.TIPO,35,' ') ||
                                lpad(v_haber,18,' ') ||
                                rpad(w.cod_moneda,3,' ') ||
                                rpad(' ',50,' ') ||--Negocio
                                rpad(trim(w.referencia),93,' ') || --Referencia
                                rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                         end if;

                   end if;
                       UTL_FILE.PUT_LINE(v_file, v_adjunto);

                   end loop;
                   --************fin de Grabar Detalle **************************************
                   --Se inserta el pie de archivo
                   v_texto_detalle := chr(10)||
                   chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_total_procesado||chr(13)||chr(10);
                   UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
              EXCEPTION
                   when others then
                         v_hora:= to_char(sysdate,'hh24:mi:ss');
                         v_error:= substr(to_char(sqlerrm),1,3000);
                         INSERT INTO ge_ra_log_mail
                             (fec_envio, nom_archivo, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
                            VALUES
                             (SYSDATE, v_nom_adj, 'ERROR', 'Envio Con.Tarjetas TC', v_error,v_hora , v_hora);

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
    end if;
  --*********************FIN DE TARJETAS DE CREDITO *************************
 end if;

 end loop;
--*********************************************************************************************************
else
--******************PARA HISTORICOS **********************************************************************
  for a in g_ente loop

       v_formato:=null;
       v_tip_conciliacion:=null;
       v_repository:= null;
       v_directorio:= null;
       --Para formato(Nuevo / Anterior) --> TD
       v_formato:= nvl(fug_obt_parentes(a.cod_ente,'FOR_ENV_ARCHIVO'),'N');
       v_tip_conciliacion:= nvl(fug_obt_parentes(a.cod_ente,'TIP_CON_ENVIO'),'TD') ;
        ---******** Datos Comunes para TC y TD
       -- Lo demas
       v_repository:= fug_obt_parentes(a.cod_ente,'DIR_REP_ARCHIVO');
       v_directorio:= fug_obt_parentes(a.cod_ente,'DIR_DEP_ARCHIVO');
       v_nom_ente        := fue_obt_nom_ente(a.cod_ente);
       v_dir_mail_deb    := fug_obt_parentes(a.cod_ente,'DIR_MAIL_CT');
       v_tip_envio      := nvl(fug_obt_parentes(a.cod_ente,'TIP_ENV_ARCHIVO'),'M');
       v_ext_archivo    := nvl(fug_obt_parentes(a.cod_ente,'TIP_ARCHIVO'),'txt');
       v_gru_transaccion := nvl(fug_obt_parentes(a.cod_ente,'GRU_TRANSACCION'),100);
       -- Tipo de Archivo
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

 if v_tip_conciliacion in ('TD','AM') then
         -- Borramos la tabla temporal para volver a cargar
         delete from ge_arc_con_tarjetas_tmp;
         --Seteos iniciales
         v_texto_detalle := null;
         v_adjunto       := null;
         v_total_procesado := 0;  --Seteos iniciales
       /**********Logica para TARJETAS DE DEBITO O AMBOS***********************/
       --Para depositar Archivo
       IF nvl(v_tip_envio,'M') = 'A' THEN
           -- ENVIO FTP
           v_line := null;
           v_name := 'TAR_' || a.nro_cta || '_' ||
                           to_char(p_fecha, 'DDMMYY');
           v_name:=lower(v_name);
           if v_directorio is null then
              -- Se devuelve el error
              RAISE_APPLICATION_ERROR(-20062, 'No tiene parametrizado Directorio parametrizado: ' || v_directorio);
           end if;
           if v_repository is null then
              --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
              RAISE_APPLICATION_ERROR(-20062, 'No tiene parametrizado Repositorio parametrizado: ' || v_repository);
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
           --DYDMR-6621 Se excluye verificaci?n para permitir mas de unas direcci?n de Email
           --v_dir_mail_deb        := fu_val_correo(v_dir_mail_deb);
           v_dir_mail_deb        := trim(v_dir_mail_deb);
           if v_dir_mail_deb is null then
               --Si esta nulo se toma se guarda error
               RAISE_APPLICATION_ERROR(-20062, 'El ente ,no tiene parametrizado direccion de mail: ' || v_dir_mail_deb);
           end if;

       END IF;
       --Cargamos la nueva tabla temporal con los detalles de operaciones
           for b in c_rec_his(a.nro_cta) loop
               -- PCCDEEVO-262 Para Facturadores
               v_facturador:= nvl(b.facturador,'N');
               if v_facturador ='S' then --buscamos la referencia
                  begin
                    select UPPER(substr(w.referencia,1,93))
                       into v_referencia
                      from ge_mov_inf_cobranzas w
                          where w.nro_cta_credito= b.nro_cuenta
                             and trunc(w.fecha) <= trunc(b.fecha)
                                  and w.reversado = 'N' and w.liberado = 'S'
                                    and w.nro_documento= b.nro_documento3
                                    and rownum=1;
                  exception
                     when no_data_found then
                        v_referencia:=null;
                     when others then
                        v_referencia:=null;

                  end;
               end if;

               v_total_procesado := v_total_procesado + nvl(b.debe, 0) +  nvl(b.haber, 0);
               begin
                 select nvl(max(a.codigo),0)
                   into v_codigo
                    from ge_arc_con_tarjetas_tmp a;
               exception
                 when others then
                    v_codigo:=0;
               end;
               --06/09 Para Negocio
               v_negocio:=null;
               Begin
                 select a.significado --En el significado lo que quieren que se les envie
                  into v_negocio
                   from ba_cod_referencias a
                   where a.dominio='DEN_CON_ENV_CON'
                    and a.val_maximo=a.nro_cta --En el va_maximo el Nro de cuenta
                     and upper(trim(a.abreviatura))= upper(trim(b.negocio)); --an la abreviatura el concepto;
               Exception
                 when no_data_found then
                   v_negocio:= upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
                 when others then
                   v_negocio:=  upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
               End;
               v_codigo:= nvl(v_codigo,0) +1;
               --07/04 PCCDEEVO-262 Para Facturadores
              insert into ge_arc_con_tarjetas_tmp(CODIGO,COD_ENTE,NRO_CUENTA,FECHA,DESCRIPCION,
                       NRO_DOCUMENTO,DEBE,HABER,COD_MONEDA,TIPO,OBSERVACION,
                       referencia, fec_valor, facturador, nro_lote)
              values(v_codigo, A.COD_ENTE,B.NRO_CUENTA,to_char(B.FECHA,'ddmmyyyy'),B.DESCRIPCION,
                   b.nro_documento, B.DEBE,b.haber,B.COD_MONEDA,B.TIPO,v_negocio,
                   v_referencia, to_char(B.Fec_Valor,'ddmmyyyy'), v_facturador, DECODE(b.nro_lote, 0, NULL, b.nro_lote));


            end loop;
      --Verificamos si se insertaron registros en la tabla para enviar.
     v_cantidad:=0;
      begin
        select count(*)
          into v_cantidad
          from ge_arc_con_tarjetas_tmp;
      exception
        when no_data_found then
          v_cantidad:=0;
        when others then
           v_cantidad:=0;
      end;

  if nvl(v_cantidad,0)> 0 then
         if  nvl(lower(v_ext_archivo),'xls') = 'xls'then
           --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
             if nvl(v_tip_envio,'M') = 'M' then
                  v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) || 'Fecha Transaccion' || chr(9) || 'Descripcion' || chr(9) ||
                           'Nro.Documento' || chr(9) ||'Debe' || chr(9) ||
                          'Haber' || chr(9) ||'Moneda' || chr(9) || 'Tipo'||chr(9)
                          || 'Negocio'||chr(9) || 'Referencia'||chr(9) || 'Nro.Lote'||
                          chr(10);
              else
                  v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) || 'Fecha Transaccion' || chr(9) || 'Descripcion' || chr(9) ||
                           'Nro.Documento' || chr(9) ||'Debe' || chr(9) ||
                          'Haber' || chr(9) ||'Moneda' || chr(9) || 'Tipo'|| chr(9)
                          || 'Negocio'|| chr(9) || 'Referencia'||chr(9) || 'Nro.Lote'||
                          chr(10);

              end if;
         elsif nvl(lower(v_ext_archivo),'xls') = 'txt' then
               --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
               if nvl(v_tip_envio,'M') = 'M' then
                   --Negocio Varchar2(50)
                   v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')||rpad('Fec.Tra.',8,' ')|| rpad('Descripcion',35,' ')  ||
                             rpad('Nro.Documento',20,' ')  || lpad('Debe',20,' ')  || lpad('Haber',20,' ')  ||
                             rpad('Mon',3,' ')  || rpad('Tipo',22,' ')|| rpad('Negocio',50,' ')|| rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                            || chr(13) || chr(10);
               else
                   --Negocio Varchar2(50)
                   v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')|| rpad('Fec.Tra.',8,' ') || rpad('Descripcion',35,' ')  ||
                             rpad('Nro.Documento',20,' ')  || lpad('Debe',20,' ')  || lpad('Haber',20,' ')  ||
                             rpad('Mon',3,' ')  || rpad('Tipo',22,' ')|| rpad('Negocio',50,' ')|| rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                             || chr(13) || chr(10);
               end if;

         end if;
             v_texto := '<br><br>
                   <br><br>
                     Estimado Cliente: '|| upper(v_nom_cli_debito) ||'
                   <br><br>
                     Le adjuntamos el Archivo para su Conciliacion de Comercios Tarjetas, correspondiente a la fecha ' ||
                             to_char(p_fecha, 'DD/MM/YYYY') || ',' || ' en el cual se registraron las operaciones detalladas en el archivo adjunto.
                   <br><br>
                     Atentamente.
                   <br><br>
                   <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                   <br><br>
                   <br><br>';

          --GAC 12/05/20147 Se agrega membrete, a pedido del usuario solicitante|
          v_nom_adj := lower('TAR_' || a.nro_cta || '_' ||to_char(p_fecha, 'DDMMYY'));

          v_asunto   := 'Servicio de Conciliacion de Comercio Tarjetas';
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
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS' || chr(13) || chr(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                 v_cabecera;
                        it_mail.write_text(v_conn, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                        v_texto_detalle := CHR(9) || CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS' || chr(13) || chr(10);
                        it_mail.write_text(v_conn, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera;
                        it_mail.write_text(v_conn, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                for w in g_datos loop
                     --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                    if w.facturador  = 'N' then
                        --No facturador -> Referencia Nulo actualmente
                        if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                              w.fecha || chr(9)||
                              w.fec_valor || chr(9)||
                              w.descripcion || chr(9) ||
                              w.nro_documento || chr(9) || w.debe ||chr(9) ||
                              w.haber || chr(9) || w.cod_moneda || chr(9) ||
                              w.tipo||chr(9) ||
                              w.observacion||chr(9) ||  --Negocio
                              null||chr(9) || --Referencia
                              w.nro_lote || chr(9) ||chr(10); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(w.observacion,50,' ') ||   --Negocio
                              rpad(' ',93,' ')  || --Referencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;
                     else
                        --Para Facturadores -- Negocio = Nulo
                        if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                              w.fecha || chr(9)||
                              w.fec_valor || chr(9)||
                              w.descripcion || chr(9) ||
                              w.nro_documento || chr(9) || w.debe ||chr(9) ||
                              w.haber || chr(9) || w.cod_moneda || chr(9) ||
                              w.tipo||chr(9) ||
                              null||chr(9)||  -- Negocio
                              w.referencia||chr(9)|| --Referencia
                              w.nro_lote || chr(9) ||chr(10); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(' ',50,' ') ||   --Negocio
                              rpad(w.referencia,93,' ') || --Referencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;

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
                   RAISE_APPLICATION_ERROR(-20062, 'Error al enviar mail: '||v_texto||' ' || sqlerrm);
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
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS'|| chr(13) || chr(10);
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                 v_cabecera;
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                       v_texto_detalle := CHR(9) || CHR(9) ||
                                         'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS';
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                        v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                          v_cabecera;
                        UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                 end if;
                --************Para Grabar Detalle **************************************
                for w in g_datos loop
                    --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                    if w.facturador  = 'N' then
                        --No facturador -> Referencia Nulo actualmente
                        if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                             w.fecha || chr(9)||
                             w.fec_valor || chr(9)||
                             w.descripcion || chr(9) ||
                             w.nro_documento || chr(9) || w.debe ||chr(9) ||
                             w.haber || chr(9) || w.cod_moneda || chr(9) ||
                             w.tipo||chr(9) ||
                             w.observacion||chr(9)|| --Negocio
                             null||chr(9)|| --Refereencia
                             w.nro_lote || chr(9); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(w.observacion,50,' ') || --Negocio
                              rpad(' ',93,' ') || --Refereencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;
                     else
                         --Para Facturadores -- Negocio = Nulo
                         if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                             w.fecha || chr(9)||
                             w.fec_valor || chr(9)||
                             w.descripcion || chr(9) ||
                             w.nro_documento || chr(9) || w.debe ||chr(9) ||
                             w.haber || chr(9) || w.cod_moneda || chr(9) ||
                             w.tipo||chr(9) ||
                             null||chr(9)|| --Negocio
                             w.referencia||chr(9)|| --Refereencia
                             w.nro_lote || chr(9); --Nro Lote
                        elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                              v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                              v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                              v_adjunto:=null;
                              v_adjunto :=
                              rpad(w.nro_cuenta,20,' ') ||
                              rpad(w.fecha,8,' ') ||
                              rpad(w.fec_valor,8,' ') ||
                              rpad(w.descripcion,35,' ') ||
                              rpad(w.nro_documento,20,' ') ||
                              lpad(v_debe,20,' ') ||
                              lpad(v_haber,20,' ') ||
                              rpad(w.cod_moneda,3,' ') ||
                              rpad(w.tipo,22,' ') ||
                              rpad(' ',50,' ') || --Negocio
                              rpad(w.referencia,93,' ') || --Refereencia
                              rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                       end if;

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
                       RAISE_APPLICATION_ERROR(-20062, 'Error al depositar archivo: '||v_error);


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
                          RAISE_APPLICATION_ERROR(-20062, 'Error ftp: '||v_respuesta);
                     end if;

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
                        RAISE_APPLICATION_ERROR(-20062, 'Error ftp: '||v_respuesta);
                        -- Insertamos el error del envio al directorio compartido
                     end if;
              end if;
        end if;
     end if;
  end if;

end if;
--****************FIN DE TARJETAS DE DEBITO O AMBOS *************************************************
--*************** PARA TARJETAS DE CREDITO O AMBOS  *************************************************
if v_tip_conciliacion in ('TC','AM') then
    --************Logica para TARJETAS DE CREDITO O AMBOS**********************
          -- Borramos la tabla temporal para volver a cargar
         delete from ge_arc_con_tarjetas_tmp;
         --Seteos iniciales
         v_texto_detalle := null;
         v_adjunto       := null;
         v_total_procesado := 0;
         v_cabecera:= null;
         v_texto:=null;
         v_texto_detalle:=null;
         v_name := null;
         v_line := null;
         --Para depositar Archivo
         IF nvl(v_tip_envio,'M') = 'A' THEN
             -- ENVIO FTP
             v_line := null;
             v_name := 'TAR_' || a.nro_cta || '_' ||
                             to_char(p_fecha, 'DDMMYY')||'_TC';
             v_name:=lower(v_name);
             if v_directorio is null then
                --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
                --insert into tm_mails (env_por, env_para, asunto, detalles, fec_sistema, cod_usuario)
                --values (c_dir_mail, v_dir_mail_deb,'CONCILIACION COMERCIO TARJETAS-TC', 'ENTE: '||A.COD_ENTE ||' No tiene parametrizado Directorio parametrizado', sysdate, user);
                RAISE_APPLICATION_ERROR(-20062, 'No tiene parametrizado Directorio parametrizado');
             end if;
             if v_repository is null then
                --Insertamos en la tabla de logs, para que no caiga el proceso de Cierre
                  RAISE_APPLICATION_ERROR(-20062, 'No tiene parametrizado Repositorio parametrizado');
             end if;
              -- Abrir archivo
              if v_repository is not null and v_directorio is not null then
                  v_file := UTL_FILE.FOPEN(v_repository,
                                          lower(v_name) || '.'||lower(v_ext_archivo),
                                          'W',
                                          32767);
              end if;
         elsIF nvl(v_tip_envio,'M') = 'M' THEN
           --DYDMR-6621 Se excluye verificaci?n para permitir mas de unas direcci?n de Email
           --v_dir_mail_deb        := fu_val_correo(v_dir_mail_deb);
           v_dir_mail_deb         := trim(v_dir_mail_deb);
           if v_dir_mail_deb is null then
               --Si esta nulo se toma se guarda error
                 RAISE_APPLICATION_ERROR(-20062, 'No tiene parametrizado mail para envio');
           end if;
         END IF;

         --Cargamos la nueva tabla temporal con los detalles de operaciones
         --Solo si esta parametrizado se ejecuta TARJETAS DE CREDITO
             for b in c_rec_tc_his(a.nro_cta) loop
                 -- PCCDEEVO-262 Para Facturadores
                 v_facturador:= nvl(b.facturador,'N');
                 if v_facturador ='S' then --buscamos la referencia
                    begin
                      select upper(substr(trim(w.referencia),1,93))
                         into v_referencia
                        from ge_mov_inf_cobranzas w
                            where w.nro_cta_credito= b.nro_cuenta
                               and trunc(w.fecha) <= trunc(b.fecha)
                                    and w.reversado = 'N' and w.liberado = 'S'
                                      and w.nro_documento= b.nro_documento3
                                      and rownum=1;
                    exception
                       when no_data_found then
                          v_referencia:=null;
                       when others then
                          v_referencia:=null;

                    end;
                 end if;
                 v_total_procesado := v_total_procesado + nvl(b.debe, 0) +  nvl(b.haber, 0);
                 begin
                   select nvl(max(a.codigo),0)
                     into v_codigo
                      from ge_arc_con_tarjetas_tmp a;
                 exception
                   when others then
                      v_codigo:=0;
                 end;
                 --06/09 Para Negocio
                 v_negocio:=null;
                 Begin
                   select upper(substr(trim(a.significado),1,50)) --En el significado lo que quieren que se les envie
                    into v_negocio
                     from ba_cod_referencias a
                     where a.dominio='DEN_COM_ENV_CON'
                      and a.val_maximo=a.nro_cta --En el va_maximo el Nro de cuenta
                       and upper(trim(a.abreviatura))= upper(trim(b.negocio)); --an la abreviatura el concepto;
                 Exception
                   when no_data_found then
                     v_negocio:= upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
                   when others then
                     v_negocio:=  upper(trim(b.negocio)); --Sino esta parametrizado Solo concepto
                 End;
                 v_codigo:= nvl(v_codigo,0) +1;
                 --07/04 Facturador
               insert into ge_arc_con_tarjetas_tmp(CODIGO,COD_ENTE,NRO_CUENTA,FECHA,DESCRIPCION,
                      NRO_DOCUMENTO,DEBE,HABER,COD_MONEDA,TIPO,OBSERVACION,
                      referencia, fec_valor,facturador, nro_lote)
               values(v_codigo,A.COD_ENTE,B.NRO_CUENTA,to_char(B.FECHA,'ddmmyyyy'),B.DESCRIPCION,
                       b.nro_documento,nvl(B.DEBE,0),decode(nvl(b.haber,0),0,nvl(B.DEBE,0),nvl(b.haber,0)),B.COD_MONEDA,B.TIPO,v_negocio,
                       trim(b.concepto), to_char(B.Fec_Valor,'ddmmyyyy'), trim(v_facturador),DECODE(b.nro_lote, 0, NULL, b.nro_lote));
              end loop;
        --Verificamos si se insertaron registros en la tabla para enviar.
       v_cantidad:=0;
       begin
          select count(*)
            into v_cantidad
            from ge_arc_con_tarjetas_tmp;
        exception
          when no_data_found then
            v_cantidad:=0;
          when others then
             v_cantidad:=0;
        end;
  if nvl(v_cantidad,0)> 0 then
           if  nvl(lower(v_ext_archivo),'xls') = 'xls'then
             --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                  if nvl(v_tip_envio,'M') = 'M' then
                      v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) ||'Fecha Transaccion' ||
                                chr(9) || 'Descripcion' || chr(9) ||
                               'Total' || chr(9) ||'Moneda' || chr(9) ||'Negocio'|| chr(9) ||'Referencia'||chr(9) || 'Nro.Lote'||
                               chr(10);
                  else
                      v_cabecera := 'Nro.Cuenta' || chr(9) || 'Fecha' || chr(9) ||'Fecha Transaccion' || chr(9)||
                               'Descripcion' || chr(9) ||
                               'Total' || chr(9) ||'Moneda' || chr(9)|| 'Negocio'|| chr(9)|| 'Referencia'||chr(9) || 'Nro.Lote'||
                               chr(10);

                  end if;
           elsif nvl(lower(v_ext_archivo),'xls') = 'txt' then
             if nvl(v_tip_envio,'M') = 'M' then
                 --Negocio Varchar2(50)
                 v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')||rpad('Fec.Tra.',8,' ')|| rpad('Descripcion',35,' ')  ||
                           lpad('Total',20,' ')||rpad('Mon',3,' ')|| rpad('Negocio',50,' ')|| rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                           ||chr(13)||chr(10);
             else
                 --Negocio Varchar2(50)
                 v_cabecera := rpad('Nro.Cuenta',20,' ') || rpad('Fecha',8,' ')||rpad('Fec.Tra.',8,' ')|| rpad('Descripcion',35,' ')  ||
                           lpad('Total',20,' ')||rpad('Mon',3,' ')  ||rpad('Negocio',50,' ')||rpad('Referencia',93,' ')|| rpad('Nro.Lote',15,' ')
                           ||chr(13)||chr(10);
             end if;
           end if;
               v_texto := '<br><br>
                     <br><br>
                       Estimado Cliente: '|| upper(v_nom_cli_debito) ||'
                     <br><br>
                       Le adjuntamos el Archivo para su Conciliacion de Comercios Tarjetas(TC), correspondiente a la fecha ' ||
                               to_char(p_fecha, 'DD/MM/YYYY') || ',' || ' en el cual se registraron las operaciones detalladas en el archivo adjunto.
                     <br><br>
                       Atentamente.
                     <br><br>
                     <p align="center"><i><b>'||fug_obt_pardinamico('CAM_MAR_NOM_FANTASIA')||'</b></i></p>
                     <br><br>
                     <br><br>';

            --GAC 12/05/20147 Se agrega membrete, a pedido del usuario solicitante|
            v_nom_adj := lower('TAR_' || a.nro_cta || '_' ||to_char(p_fecha, 'DDMMYY')||'_TC');

            v_asunto   := 'Servicio de Conciliacion de Comercio Tarjetas(TC)';
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
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC' || chr(13) || chr(10);
                          it_mail.write_text(v_conn, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                   v_cabecera;
                          it_mail.write_text(v_conn, v_texto_detalle);
                   elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                          v_texto_detalle := CHR(9) || CHR(9) ||
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC' || CHR(10);
                          it_mail.write_text(v_conn, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' || chr(10) ||
                                            v_cabecera;
                          it_mail.write_text(v_conn, v_texto_detalle);
                   end if;
                  --************Para Grabar Detalle **************************************
                  for w in g_datos loop
                   --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                   --No facturador -> Referencia Nulo actualmente
                   if w.facturador = 'N' then
                     if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                            w.fecha || chr(9)||
                            w.fec_valor || chr(9)||
                            w.TIPO || chr(9) ||w.haber ||chr(9) ||
                            w.cod_moneda || chr(9) ||
                            trim(w.observacion)||chr(9) || --Negocio
                            null||chr(9) || --Referencia
                            w.nro_lote || chr(9)|| chr(10); --Nro Lote
                      elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                            v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                            v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                            v_adjunto:=null;
                            v_adjunto :=
                            rpad(w.nro_cuenta,20,' ') ||
                            rpad(w.fecha,8,' ') ||
                            rpad(w.fec_valor,8,' ') ||
                            rpad(w.TIPO,35,' ') ||
                            lpad(v_haber,20,' ') ||
                            rpad(w.cod_moneda,3,' ') ||
                            rpad(trim(w.observacion),50,' ') || --Negocio
                            rpad(' ',93,' ') || --Referencia
                            rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                     end if;
                   else
                      --Para Facturadores -- Negocio = Nulo
                      if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                            v_adjunto:=null;
                            v_adjunto := w.nro_cuenta || chr(9) ||
                            w.fecha || chr(9)||
                            w.fec_valor || chr(9)||
                            w.TIPO || chr(9) ||w.haber ||chr(9) ||
                            w.cod_moneda || chr(9) ||
                            null||chr(9) || --Negocio
                            trim(w.referencia)||chr(9) || --Referencia
                            w.nro_lote || chr(9) ||chr(10); --Nro Lote
                      elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                            v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                            v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                            v_adjunto:=null;
                            v_adjunto :=
                            rpad(w.nro_cuenta,20,' ') ||
                            rpad(w.fecha,8,' ') ||
                            rpad(w.fec_valor,8,' ') ||
                            rpad(w.TIPO,35,' ') ||
                            lpad(v_haber,20,' ') ||
                            rpad(w.cod_moneda,3,' ') ||
                            rpad(' ',50,' ') || --Negocio
                            rpad(trim(w.referencia),93,' ') || --Referencia
                            rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                     end if;

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
                          RAISE_APPLICATION_ERROR(-20062, 'Error en envio de mail: '||sqlerrm);
               END;
            end if;
            --********** fin de Logica para envio por email de los archivos ******************
      ELSE
           if v_repository is not null and v_directorio is not null then
              --*****************Para formato de Archivo **********************
               Begin
                  --*********Para Grabar Cabecera ***************************
                   if nvl(lower(v_ext_archivo),'xls') = 'txt' then
                          v_texto_detalle := CHR(9) || CHR(9) || CHR(9) ||
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC'|| chr(13) || chr(10);
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' || CHR(13) || CHR(10) ||
                                   v_cabecera;
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                   elsif nvl(lower(v_ext_archivo),'xls') = 'xls' then
                         v_texto_detalle := CHR(9) || CHR(9) ||
                                           'SERVICIO DE CONCILIACION DE COMERCIO TARJETAS-TC';
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                          v_texto_detalle := 'Operaciones Procesadas' ||chr(13)||chr(10)||
                                            v_cabecera;
                          UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
                   end if;
                  --************Para Grabar Detalle **************************************
                  for w in g_datos loop
                     --PCCDEEVO-262 Archivo de Conciliaciones para Facturadores
                     --No facturador -> Referencia Nulo actualmente
                   if w.facturador  = 'N' then
                          if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                               w.fecha || chr(9)||
                               w.fec_valor || chr(9)||
                               w.TIPO || chr(9) ||
                               w.haber ||chr(9) ||
                               w.cod_moneda || chr(9) ||
                               trim(w.observacion)||chr(9)|| --Negocio
                               null||chr(9)|| --Referencia
                               w.nro_lote || chr(9); --Nro Lote
                          elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                                v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                                v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                                v_adjunto:=null;
                                v_adjunto :=
                                rpad(w.nro_cuenta,20,' ') ||
                                rpad(w.fecha,8,' ') ||
                                rpad(w.fec_valor,8,' ') ||
                                rpad(w.TIPO,35,' ') ||
                                lpad(v_haber,20,' ') ||
                                rpad(w.cod_moneda,3,' ') ||
                                rpad(trim(w.observacion),50,' ') || --Negocio
                                rpad(' ',93,' ') ||  --Referencia
                                rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                         end if;
                   else
                        --Para Facturadores -- Negocio = Nulo
                           if  nvl(lower(v_ext_archivo),'xls') = 'xls' then
                              v_adjunto:=null;
                              v_adjunto := w.nro_cuenta || chr(9) ||
                               w.fecha || chr(9)||
                               w.fec_valor || chr(9)||
                               w.TIPO || chr(9) ||
                               w.haber ||chr(9) ||
                               w.cod_moneda || chr(9) ||
                               null||chr(9)||--Negocio
                               trim(w.referencia)||chr(9)|| --Referencia
                               w.nro_lote || chr(9); --Nro Lote
                          elsif  nvl(lower(v_ext_archivo),'xls') = 'txt' then
                                v_debe := trim(to_char(w.debe,'9G999G999G999G990D99'));
                                v_haber := trim(to_char(w.haber,'9G999G999G999G990D99'));
                                v_adjunto:=null;
                                v_adjunto :=
                                rpad(w.nro_cuenta,20,' ') ||
                                rpad(w.fecha,8,' ') ||
                                rpad(w.fec_valor,8,' ') ||
                                rpad(w.TIPO,35,' ') ||
                                lpad(v_haber,18,' ') ||
                                rpad(w.cod_moneda,3,' ') ||
                                rpad(' ',50,' ') ||--Negocio
                                rpad(trim(w.referencia),93,' ') || --Referencia
                                rpad(w.nro_lote,15,' ') || CHR(13) || CHR(10); --Nro Lote
                         end if;

                   end if;
                       UTL_FILE.PUT_LINE(v_file, v_adjunto);

                   end loop;
                   --************fin de Grabar Detalle **************************************
                   --Se inserta el pie de archivo
                   v_texto_detalle := chr(10)||
                   chr(9)||chr(9)||chr(9)||chr(9)||'Total Procesados :'||chr(9)||v_total_procesado||chr(13)||chr(10);
                   UTL_FILE.PUT_LINE(v_file, v_texto_detalle);
              EXCEPTION
                   when others then
                         v_hora:= to_char(sysdate,'hh24:mi:ss');
                         v_error:= substr(to_char(sqlerrm),1,3000);
                          RAISE_APPLICATION_ERROR(-20062, 'Envio de mail: '||v_error);

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
                          RAISE_APPLICATION_ERROR(-20062, 'Depositar archivo: '||sqlerrm);
                       end if;

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
                          RAISE_APPLICATION_ERROR(-20062, 'Depositar archivo..: '||sqlerrm);
                       end if;
                      COMMIT;
                end if;
          end if;
       end if;
    end if;
  --*********************FIN DE TARJETAS DE CREDITO *************************
 end if;

 end loop;

end if;
--********************************************************************************************************
  declare
    v_nro_cuentas varchar2(2000);
    v_detalle varchar2(4000);
    v_conn           utl_smtp.connection;
    v_det_error        ge_ra_log_mail.det_error%type;
  begin
    for c in g_diferencias loop
       if v_nro_cuentas is null then
          v_nro_cuentas := c.nro_cuenta;
       else
          v_nro_cuentas := v_nro_cuentas ||' - '||c.nro_cuenta;
       end if;

       update ge_pag_comercios_det
          set cod_proceso = 13,
              estado = 'P',
              ind_reproceso = 'N'
        where cod_ente = c.cod_ente
          and fec_proceso = c.fecha
          and nro_cuenta = c.nro_cuenta;
    end loop;

    if v_nro_cuentas is not null then
       V_DETALLE := '<html>
                       <head>
                          <title>Test HTML message</title>
                       </head>
                       <body>
                          <p>Se informa,
                          <br><br>
                          Se informa que no se pudo enviar el Mail de SERVICIO DE CONCILIACION DE COMERCIO TARJETAS a la/s cuenta/s: '||v_nro_cuentas||'.'||
                          '<br><br> Atentamente,
                          </p>
                       </body>
                     </html>';


      BEGIN
        v_conn := it_mail.begin_mail(c_dir_mail,
                                     v_mai_dif,
                                     'Diferencias en el informe de SERVICIO DE CONCILIACION DE COMERCIO TARJETAS' ,
                                     IT_MAIL.MULTIPART_MIME_TYPE);
        it_mail.attach_text(v_conn, v_detalle, 'text/html');
        it_mail.end_mail(v_conn);
      EXCEPTION
        when others then
           v_det_error := sqlerrm;
           INSERT INTO ge_ra_log_mail
             (fec_envio, dir_correo, mensaje, det_error, hor_inicio, hor_fin)
            VALUES
             (SYSDATE, v_mai_dif, 'Diferencias en el informe de SERVICIO DE CONCILIACION DE COMERCIO TARJETAS',
              v_det_error, null, null);
            COMMIT;
      end;
    end if;
  end;

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
     raise_application_error(-20000,'PRG_GEN_ARC_CON_TARJETAS '||sqlerrm);
END PRG_GEN_ARC_CON_TARJETAS;
/

