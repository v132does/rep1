CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_AXION is
 /*************************************************************************
 Generación de Extracto de Movimientos del Día para Axion, Un archivo por Moneda.
 Servicio de recaudaciones por ventanilla, se enviará inicialmente a las 16:00 Horas
 --
 El archivo tiene 5 tipos de registros:
 1- Encabezado del Archivo --> 1 por cada ente y moneda, en cada archivo una sola vez.
 2- Detalle de movimiento  --> 1 por cada tipo de valor (total de la boleta)
 3- Datos de Factura       --> no se utiliza en bbva py, se completan los datos.
 4- Datos de Valores       --> 1 por cada forma de pago para el mismo movimiento (ej: efectivo, cheque).
 5- Detalle de cheques     --> detalle de cada cheque depositado, si es solo efectivo no se incluye este tipo de registro.
 *************************************************************************/
  v_file                UTL_FILE.FILE_TYPE;
  v_reg                 number default 0;
  v_con_cheq            number default 0;
  v_secuencia           number default 0;
  v_line                clob;
  v_line_1              clob;
  v_line_5              clob;
  v_buffer              clob;
  v_aux_buffer          clob;
  v_buf_che_aprobado    clob;
  v_length_aux_buffer   number;
  v_eol                 CONSTANT VARCHAR2(1) := CHR(10);
  v_name                VARCHAR2(128);
  v_cod_empresa         VARCHAR2(7):='_BBVAPY';
  v_cod_ente            ge_entes.cod_ente%type := 7834; -- Código ente Axion
  v_nro_rendicion       NUMBER(6);
  v_nro_secuencia       number;
  v_est_movimiento      varchar2(1) := 'N';
  v_est_mov_ant         varchar2(1);
  v_est_mov_ainformar   varchar2(1) := 'P'; -- P = Normal, A = Reversado
  v_tot_registro        NUMBER(6);
  v_tot_importe         NUMBER(13,2);
  v_moneda              ba_monedas.cod_mon_iso%TYPE;
  v_cta_hija            VARCHAR2(20):='99999999999999999999';
  v_den_cta             VARCHAR2(40);
  v_nro_mov_comprobante VARCHAR2(18):='000000000000000000';--Nro de Factura
  v_tip_valor           VARCHAR2(2);
  v_fec_actual          DATE := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_fec_anterior        DATE := pag_cal.fu_obt_fec_anterior(1);
  v_hor_corte           varchar2(8);
  v_fec_rendicion       VARCHAR2(8) := to_char(v_fec_actual, 'YYYYMMDD'); --Fec desde y hasta (yyyymmdd)
  v_cabecera            NUMBER(10):=0;
  v_cod_usu_cajero      ba_usuarios.cod_usuario%TYPE;
  v_nro_boleta          ge_rec_movimientos.nro_operacion%TYPE;
  v_can_cheques         NUMBER;
  v_nro_sec_anterior    NUMBER;
  v_liberado            ah_retenciones.liberado%type;
  v_che_devuelto        varchar2(1) default 'N';
  v_dir_archivo         ge_par_entes.val_parametro%type;
  v_cod_banco           cc_che_enviados.cod_banco%TYPE;
  v_fec_cheque          cc_che_enviados.fecha%TYPE;
  v_fec_che_final       cc_che_enviados.fec_final%TYPE;
  v_fec_che_fin_tex     varchar2(8);
  v_est_cheque          cc_che_enviados.estado%TYPE;
  v_che_presentado      varchar2(1);
  v_mto_cheque          cc_che_enviados.monto%TYPE;
  v_cod_retencion       cc_che_enviados.cod_retencion%TYPE;
  v_cod_cau_devolucion  cc_che_enviados.cod_cau_devolucion%TYPE;
  v_cod_usu_cheque      cc_che_enviados.cod_usuario%TYPE;
  v_cau_devolucion      ge_causales.cod_causa%TYPE;
  v_importe             varchar2(15);
  v_imp_linea1          varchar2(15);
  v_tip_deposito        gv_recaudaciones.tip_deposito%type;
  v_cod_depositante     ge_rec_depositantes.cod_depositante%type;
  v_mov_inf_pri_vez     varchar2(1) default 'S';
  v_est_che_real        varchar2(1) default 'P';
  v_che_detallado       varchar2(1) default 'S';
  v_respuesta           VARCHAR2(4000);
  v_hini_ftp            ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp            ge_ra_log_ftp.hor_fin%type;
  v_che_cnb_presentado  varchar2(1) := 'N';
  v_inc_cab_cheque      varchar2(1) := 'S';
  -- Variables de conexión
  g_repository          VARCHAR2(100) := 'MAIL';
  g_ip                  VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port                VARCHAR2(100) := '21';
  g_user                VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass                VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');

  -- Cursor Principal
  cursor c_principal is
  select distinct a.cod_ente, a.cod_moneda
    from gv_recaudaciones a
   where a.cod_ente = v_cod_ente
     and a.fec_recaudacion = v_fec_actual
     and not exists (select 1
          from ge_log_ser_recaudaciones c
         where c.cod_ente = a.cod_ente
           and c.cod_moneda = a.cod_moneda
           and c.nro_boleta = a.nro_boleta
           and c.nro_cta_recaudora = a.nro_cta_recaudora
           and c.tip_deposito = a.tip_deposito
           and c.fec_recaudacion = a.fec_recaudacion
           and c.hora = a.hora)
union
  select distinct a.cod_ente, a.cod_moneda
    from gv_recaudaciones a
   where a.cod_ente = v_cod_ente
     and a.fec_recaudacion < v_fec_actual
     and a.tip_deposito like 'CHEQUE%'
     and (a.est_cheque = 'Confirmado' or a.est_cheque like '%Rechazado')
     and exists (select 1 from ge_log_ser_recaudaciones b
                  where b.cod_ente = a.cod_ente
                    and b.cod_moneda = a.cod_moneda
                    and b.nro_boleta = a.nro_boleta
                    and b.nro_cta_recaudora = a.nro_cta_recaudora
                    and b.tip_deposito = a.tip_deposito
                    and b.est_cheque = 'Pend. de Confirmación'
                    and b.hora = a.hora
                    and b.estado = 'N')
    and not exists (select 1 from ge_log_ser_recaudaciones c
                      where c.cod_ente = a.cod_ente
                        and c.cod_moneda = a.cod_moneda
                        and c.nro_boleta = a.nro_boleta
                        and c.nro_cta_recaudora = a.nro_cta_recaudora
                        and c.tip_deposito = a.tip_deposito
                        and (c.est_cheque = 'Confirmado' or c.est_cheque like '%Rechazado')
                        and c.hora = a.hora)
union
  select distinct a.cod_ente, a.cod_moneda
    from gv_recaudaciones a
   where a.cod_ente = v_cod_ente
     and a.fec_recaudacion = v_fec_anterior
     and a.hora > v_hor_corte
     and a.tip_deposito like 'CHEQUE%'
     and not exists (select 1 from ge_log_ser_recaudaciones b
                  where b.cod_ente = a.cod_ente
                    and b.cod_moneda = a.cod_moneda
                    and b.nro_boleta = a.nro_boleta
                    and b.nro_cta_recaudora = a.nro_cta_recaudora
                    and b.tip_deposito = a.tip_deposito
                    and b.est_cheque = 'Pend. de Confirmación'
                    and b.hora = a.hora
                    and b.estado = 'N')
    and not exists (select 1 from ge_log_ser_recaudaciones c
                      where c.cod_ente = a.cod_ente
                        and c.cod_moneda = a.cod_moneda
                        and c.nro_boleta = a.nro_boleta
                        and c.nro_cta_recaudora = a.nro_cta_recaudora
                        and c.tip_deposito = a.tip_deposito
                        and (c.est_cheque = 'Confirmado' or c.est_cheque like '%Rechazado')
                        and c.hora = a.hora)

union -- si es que hay reversados
  select distinct a.cod_ente, a.cod_moneda
    from ge_rec_movimientos a,
         ge_rec_depositantes b
   where a.cod_ente = v_cod_ente
     and a.estado = 'R'
     and a.fec_operacion = v_fec_anterior
     and b.cod_ente = a.cod_ente
     and b.cod_depositante = a.depositante
     and exists (select 1 from ge_log_ser_recaudaciones b
                  Where b.cod_ente = a.cod_ente
                    and b.fec_recaudacion = a.fec_operacion
                    and b.cod_depositante = a.depositante
                    and b.cod_moneda = a.cod_moneda
                    and b.nro_boleta = a.nro_operacion
                    and b.estado = 'N'
                    and b.hora = a.hora)
-- transf sipap. ingresadas luego del corte
union
  select distinct c.cod_ente, a.cod_moneda
    from ge_movimientos_ant        a,
         ge_snp_transferencias b,
         ge_entes              c,
         ge_par_entes          d,
         ge_rec_depositantes   e
   where a.fecha = v_fec_anterior
     and /*a.hora*/to_char(a.fec_insercion, 'hh24:mi:ss') > v_hor_corte --DYDMR-10712
     and a.hora = b.hora
     and c.cod_ente = v_cod_ente
     and a.cod_usuario = b.cod_usuario
     and a.nro_documento = b.nro_referencia
     and a.reversado = 'N'
     and a.cod_transaccion = 602
     and b.nro_ref_externa is not null
     and b.fec_recepcion is not null
     and c.tipo = 'SV'
     and c.cod_persona = b.cod_per_beneficiario
     and d.cod_ente = c.cod_ente
     and d.parametro in ('NRO_CTA_CRE_GS','NRO_CTA_CRE_USD')
     and d.val_parametro = b.nro_cta_beneficiario
     and e.cod_ente = d.cod_ente
     and ((ltrim(e.nro_documento,'0') = b.nro_doc_solicitante)
       or (instr(e.nro_doc_adicional, b.nro_doc_solicitante) > 0 ))
     and e.cod_depositante = (select max(cod_depositante)
                              from ge_rec_depositantes d
                             where d.nro_documento = e.nro_documento)
     and not exists (select 1 from ge_log_ser_recaudaciones f 
                      where f.fec_recaudacion = b.fecha
                        and f.cod_ente = c.cod_ente
                        and f.nro_boleta = b.nro_referencia
                        and f.cod_moneda = b.cod_moneda
                        and f.cod_depositante = e.cod_depositante)
union
-- transf internas. ingresadas luego del corte
  select distinct g.cod_ente, mov_cre.cod_moneda
    from ge_movimientos_ant mov_cre,
         (select fecha, hora, cod_usuario, nro_cuenta, nro_documento
            from ge_movimientos_ant
           where reversado = 'N'
             and cod_tra_padre = 388
             and cod_transaccion = 503) mov_deb,
         ge_entes c,
         ge_par_entes d,
         ge_cta_clientes e,
         ba_personas f,
         ge_rec_depositantes g
   where mov_cre.cod_tra_padre = 388
     and mov_cre.cod_transaccion = 602
     and mov_cre.reversado = 'N'
     and /*mov_cre.hora*/to_char(mov_cre.fec_insercion, 'hh24:mi:ss') > v_hor_corte --DYDMR-10712
     and mov_deb.fecha = mov_cre.fecha
     and mov_deb.hora = mov_cre.hora
     and mov_deb.cod_usuario = mov_cre.cod_usuario
     and mov_deb.nro_documento = mov_cre.nro_documento
     and c.tipo = 'SV'
     and c.cod_ente = d.cod_ente
     and d.parametro in ('NRO_CTA_CRE_GS', 'NRO_CTA_CRE_USD')
     and d.val_parametro = mov_cre.nro_cuenta
     and e.nro_cuenta = mov_deb.nro_cuenta
     and e.relacion = 'P'
     and f.cod_persona = e.cod_persona
     and ((ltrim(g.nro_documento,'0') = f.nro_documento)
       or (instr(g.nro_doc_adicional, f.nro_documento) > 0))
     and g.cod_depositante =
         (select max(h.cod_depositante)
            from ge_rec_depositantes h
           where h.nro_documento = g.nro_documento)
     and not exists (select 1 from ge_log_ser_recaudaciones log
                      where log.fec_recaudacion = mov_cre.fecha
                        and log.cod_ente = c.cod_ente
                        and log.cod_moneda = mov_cre.cod_moneda
                        and log.nro_cta_recaudora = mov_cre.nro_cuenta 
                        and log.cod_depositante = g.cod_depositante)
;

  -- Cursor Registros 2,3 y 4
  cursor c_reg234(p_cod_ente ge_rec_movimientos.cod_ente%TYPE,
                  p_cod_moneda ge_rec_movimientos.cod_moneda%TYPE) is
-- Mov. Reversados
  select a.cod_ente, a.nro_operacion nro_boleta, a.fec_operacion fec_recaudacion,
         a.nro_cta_credito nro_cta_recaudadora,
         a.cod_moneda,
         case when a.mto_efectivo > 0 then
           'EFECTIVO'
         else
           'CHEQUE'
         end tip_deposito,
         a.tot_deposito importe,
         b.nom_depositante depositante,
         a.depositante cod_depositante,
         fue_obt_tip_doc_abreviatura(b.cod_tip_documento) tip_documento,
         b.nro_documento, a.hora, a.ref_pago,
         fue_obt_des_oficina(a.cod_oficina) Oficina,
         a.cod_oficina,
         a.estado
    from ge_rec_movimientos a,
         ge_rec_depositantes b
   where a.cod_ente = p_cod_ente
     and a.cod_moneda = p_cod_moneda
     and a.estado = 'R'
     and a.fec_operacion = v_fec_anterior
     and b.cod_ente = a.cod_ente
     and b.cod_depositante = a.depositante
     and exists (select 1 from ge_log_ser_recaudaciones b
                  Where b.cod_ente = a.cod_ente
                    and b.fec_recaudacion = a.fec_operacion
                    and b.cod_depositante = a.depositante
                    and b.cod_moneda = a.cod_moneda
                    and b.nro_boleta = a.nro_operacion
                    and b.hora = a.hora
                    and b.estado = 'N')
  union
  -- Movimiento anterior no informado
  select a.cod_ente, a.nro_operacion nro_boleta, a.fec_operacion fec_recaudacion,
         a.nro_cta_credito nro_cta_recaudadora,
         a.cod_moneda,
         case when a.mto_efectivo > 0 then
           'EFECTIVO'
         else
           'CHEQUE'
         end tip_deposito,
         a.tot_deposito importe,
         b.nom_depositante depositante,
         a.depositante cod_depositante,
         fue_obt_tip_doc_abreviatura(b.cod_tip_documento) tip_documento,
         b.nro_documento, a.hora, a.ref_pago,
         fue_obt_des_oficina(a.cod_oficina) Oficina,
         a.cod_oficina,
         a.estado
    from ge_rec_movimientos a,
         ge_rec_depositantes b
   where a.cod_ente = p_cod_ente
     and a.cod_moneda = p_cod_moneda
     and a.estado = 'N'
     and a.fec_operacion = v_fec_anterior
     and b.cod_ente = a.cod_ente
     and b.cod_depositante = a.depositante
     and not exists (select 1 from ge_log_ser_recaudaciones b
                      Where b.cod_ente = a.cod_ente
                        and b.fec_recaudacion = a.fec_operacion
                        and b.hora = a.hora
                        and b.cod_depositante = a.depositante
                        and b.cod_moneda = a.cod_moneda
                        and b.nro_boleta = a.nro_operacion)
  union
  -- transf ingresadas luego del corte
    select c.cod_ente, a.nro_documento nro_boleta, a.fecha fec_recaudacion,
           b.nro_cta_beneficiario nro_cta_recaudadora, a.cod_moneda,
           'TRANSFERENCIA' tip_deposito,
           a.monto importe, e.nom_depositante depositante, e.cod_depositante,
           fue_obt_tip_doc_abreviatura(e.cod_tip_documento) tip_documento,
           e.nro_documento, a.hora, a.concepto ref_pago,
           fue_obt_des_oficina(a.cod_oficina) Oficina,
           a.cod_oficina,
            'N' estado
      from ge_movimientos_ant    a,
           ge_snp_transferencias b,
           ge_entes              c,
           ge_par_entes          d,
           ge_rec_depositantes   e
     where a.fecha = v_fec_anterior
       and /*a.hora*/to_char(a.fec_insercion, 'hh24:mi:ss') > v_hor_corte --DYDMR-10712
       and a.hora = b.hora
       and c.cod_ente = p_cod_ente
       and a.cod_moneda = p_cod_moneda
       and a.cod_usuario = b.cod_usuario
       and a.nro_documento = b.nro_referencia
       and a.reversado = 'N'
       and a.cod_transaccion = 602
       and b.nro_ref_externa is not null
       and b.fec_recepcion is not null
       and c.tipo = 'SV'
       and c.cod_persona = b.cod_per_beneficiario
       and d.cod_ente = c.cod_ente
       and d.parametro in ('NRO_CTA_CRE_GS','NRO_CTA_CRE_USD')
       and d.val_parametro = b.nro_cta_beneficiario
       and e.cod_ente = d.cod_ente
       and ((ltrim(e.nro_documento,'0') = b.nro_doc_solicitante)
        or (instr(e.nro_doc_adicional, b.nro_doc_solicitante) > 0 ))
       and e.cod_depositante = (select max(cod_depositante)
                                from ge_rec_depositantes d
                               where d.nro_documento = e.nro_documento)
       and not exists (select 1 from ge_log_ser_recaudaciones f 
                        where f.fec_recaudacion = b.fecha
                          and f.cod_ente = c.cod_ente
                          and f.nro_boleta = b.nro_referencia
                          and f.cod_moneda = b.cod_moneda
                          and f.cod_depositante = e.cod_depositante)
  union
  -- transf internas. ingresadas luego del corte
  select g.cod_ente,
         mov_cre.nro_documento nro_boleta,
         mov_cre.fecha fec_recaudacion,
         mov_cre.nro_cuenta nro_cta_recaudadora,
         mov_cre.cod_moneda,
         'TRANSFERENCIA' tip_deposito,
         mov_cre.monto importe,
         g.nom_depositante depositante,
         g.cod_depositante,
         fue_obt_tip_doc_abreviatura(g.cod_tip_documento) tip_documento,
         g.nro_documento,
         mov_cre.hora,
         mov_cre.concepto ref_pago,
         fue_obt_des_oficina(mov_cre.cod_oficina) Oficina,
         mov_cre.cod_oficina,
         'N' estado
    from ge_movimientos_ant mov_cre,
         (select fecha, hora, cod_usuario, nro_cuenta, nro_documento
            from ge_movimientos_ant
           where reversado = 'N'
             and cod_tra_padre = 388
             and cod_transaccion = 503) mov_deb,
         ge_entes c,
         ge_par_entes d,
         ge_cta_clientes e,
         ba_personas f,
         ge_rec_depositantes g
   where mov_cre.cod_tra_padre = 388
     and mov_cre.cod_transaccion = 602
     and mov_cre.reversado = 'N'
     and /*mov_cre.hora*/ to_char(mov_cre.fec_insercion, 'hh24:mi:ss') > v_hor_corte --DYDMR-10712
     and mov_cre.cod_moneda = p_cod_moneda
     and mov_deb.fecha = mov_cre.fecha
     and mov_deb.hora = mov_cre.hora
     and mov_deb.cod_usuario = mov_cre.cod_usuario
     and mov_deb.nro_documento = mov_cre.nro_documento
     and c.tipo = 'SV'
     and c.cod_ente = d.cod_ente
     and d.parametro in ('NRO_CTA_CRE_GS', 'NRO_CTA_CRE_USD')
     and d.val_parametro = mov_cre.nro_cuenta
     and e.nro_cuenta = mov_deb.nro_cuenta
     and e.relacion = 'P'
     and f.cod_persona = e.cod_persona
     and ((ltrim(g.nro_documento,'0') = f.nro_documento)
       or (instr(g.nro_doc_adicional, f.nro_documento) > 0))
     and g.cod_depositante =
         (select max(h.cod_depositante)
            from ge_rec_depositantes h
           where h.nro_documento = g.nro_documento)
     and not exists (select 1 from ge_log_ser_recaudaciones log
                      where log.fec_recaudacion = mov_cre.fecha
                        and log.cod_ente = c.cod_ente
                        and log.cod_moneda = mov_cre.cod_moneda
                        and log.nro_cta_recaudora = mov_cre.nro_cuenta 
                        and log.cod_depositante = g.cod_depositante)
  union
  --
     select cod_ente, nro_boleta, fec_recaudacion, nro_cta_recaudora nro_cta_recaudadora,
            cod_moneda, tip_deposito,
            SUM(importe) importe,
            depositante, cod_depositante,
            tip_documento, nro_documento, hora, ref_pago,
            Oficina, cod_oficina,
            'N' estado
      from gv_recaudaciones a
     where a.cod_ente = p_cod_ente
       and a.cod_moneda = p_cod_moneda
     and a.fec_recaudacion = v_fec_actual
       and not exists (select 1
          from ge_log_ser_recaudaciones c
         where c.cod_ente = a.cod_ente
           and c.cod_moneda = a.cod_moneda
           and c.nro_boleta = a.nro_boleta
           and c.nro_cta_recaudora = a.nro_cta_recaudora
           and c.tip_deposito = a.tip_deposito
           and c.fec_recaudacion = a.fec_recaudacion
           and c.hora = a.hora)
  group by cod_ente, nro_boleta, fec_recaudacion, nro_cta_recaudora,
           cod_moneda, tip_deposito,
           depositante, cod_depositante,
           tip_documento, nro_documento, hora, ref_pago,
           oficina, cod_oficina
    union
     select cod_ente, nro_boleta, fec_recaudacion, nro_cta_recaudora nro_cta_recaudadora,
            cod_moneda, tip_deposito,
            SUM(importe) importe,
            depositante, cod_depositante,
            tip_documento, nro_documento, hora, ref_pago,
            Oficina, cod_oficina,
            'N' estado
       from gv_recaudaciones a
      where a.cod_ente = p_cod_ente
        and a.cod_moneda = p_cod_moneda
      and a.fec_recaudacion < v_fec_actual
        and a.tip_deposito like 'CHEQUE%'
        and (a.est_cheque = 'Confirmado' or a.est_cheque like '%Rechazado')
        and exists (select 1 from ge_log_ser_recaudaciones b
                     where b.cod_ente = a.cod_ente
                       and b.cod_moneda = a.cod_moneda
                       and b.nro_boleta = a.nro_boleta
                       and b.nro_cta_recaudora = a.nro_cta_recaudora
                       and b.tip_deposito like 'CHEQUE%'
                       and b.hora = a.hora
                       and (b.est_cheque is null or b.est_cheque = 'Pend. de Confirmación')
                       )
        and not exists (select 1 from ge_log_ser_recaudaciones c
                         where c.cod_ente = a.cod_ente
                           and c.cod_moneda = a.cod_moneda
                           and c.nro_boleta = a.nro_boleta
                           and c.nro_cta_recaudora = a.nro_cta_recaudora
                           and c.tip_deposito like 'CHEQUE%'
                           and c.hora = a.hora
                           and c.est_cheque is not null
                           and (c.est_cheque = 'Confirmado' or c.est_cheque like '%Rechazado'))
    GROUP BY cod_ente, nro_boleta, fec_recaudacion, nro_cta_recaudora,
             cod_moneda, tip_deposito,
             depositante, cod_depositante,
             tip_documento, nro_documento, hora, ref_pago,
             oficina, cod_oficina,
            'N'
  order by 1,2,3,4,12;

  -- Cursor Registro 5
  cursor c_reg5(p_cod_ente ge_rec_movimientos.cod_ente%type,
                p_cod_moneda ge_rec_movimientos.cod_moneda%TYPE,
                p_nro_boleta number) IS
   SELECT cod_ente, nro_boleta, fec_recaudacion, nro_cta_recaudora nro_cta_recaudadora,
          cod_moneda, tip_deposito, banco, cod_banco, nro_cheque,
          importe,
          est_cheque, depositante, cod_depositante,
          tip_documento, nro_documento, hora, ref_pago,
          Oficina, cod_oficina, a.nro_cta_cheque
     FROM gv_recaudaciones a
    WHERE a.cod_ente = p_cod_ente
      AND a.cod_moneda = p_cod_moneda
      and a.nro_boleta = p_nro_boleta
      and a.fec_recaudacion = v_fec_actual
      and a.tip_deposito like 'CHEQUE%'
  union
   SELECT cod_ente, nro_boleta, fec_recaudacion, nro_cta_recaudora nro_cta_recaudadora,
          cod_moneda, tip_deposito, banco, cod_banco, nro_cheque,
          importe,
          est_cheque, depositante, cod_depositante,
          tip_documento, nro_documento, hora, ref_pago,
          Oficina, cod_oficina, a.nro_cta_cheque
     FROM gv_recaudaciones a
    WHERE a.cod_ente = p_cod_ente
      AND a.cod_moneda = p_cod_moneda
      and a.nro_boleta = p_nro_boleta
      and a.fec_recaudacion < v_fec_actual
      and a.tip_deposito like 'CHEQUE%'
      and (a.est_cheque = 'Confirmado' or a.est_cheque like '%Rechazado')
      and exists (select 1 from ge_log_ser_recaudaciones b
                   where b.cod_ente = a.cod_ente
                     and b.cod_moneda = a.cod_moneda
                     and b.nro_boleta = a.nro_boleta
                     and b.nro_cta_recaudora = a.nro_cta_recaudora
                     and b.tip_deposito like 'CHEQUE%'
                     and b.hora = a.hora
                     and (b.est_cheque is null or b.est_cheque = 'Pend. de Confirmación'))
      and not exists (select 1 from ge_log_ser_recaudaciones c
                       where c.cod_ente = a.cod_ente
                         and c.cod_moneda = a.cod_moneda
                         and c.nro_boleta = a.nro_boleta
                         and c.nro_cta_recaudora = a.nro_cta_recaudora
                         and c.tip_deposito like 'CHEQUE%'
                         and c.hora = a.hora
                         and (c.est_cheque = 'Confirmado' or c.est_cheque like '%Rechazado'))
  union
   SELECT cod_ente, nro_boleta, fec_recaudacion, nro_cta_recaudora nro_cta_recaudadora,
          cod_moneda, tip_deposito, banco, cod_banco, nro_cheque,
          importe,
          est_cheque, depositante, cod_depositante,
          tip_documento, nro_documento, hora, ref_pago,
          Oficina, cod_oficina, a.nro_cta_cheque
     FROM gv_recaudaciones a
    WHERE a.cod_ente = p_cod_ente
      AND a.cod_moneda = p_cod_moneda
      and a.nro_boleta = p_nro_boleta
      and a.fec_recaudacion < v_fec_actual
      and a.tip_deposito like 'CHEQUE%'
      and not exists (select 1 from ge_log_ser_recaudaciones b
                   where b.cod_ente = a.cod_ente
                     and b.cod_moneda = a.cod_moneda
                     and b.nro_boleta = a.nro_boleta
                     and b.hora = a.hora
                     and b.nro_cheque = a.nro_cheque
                     and b.est_cheque = a.est_cheque
                     and b.nro_cta_recaudora = a.nro_cta_recaudora
                     and b.tip_deposito like 'CHEQUE%'
                     )
  order by 6,7,10;

  --
  FUNCTION fu_obt_mon_iso(p_cod_moneda ba_monedas.cod_moneda%TYPE)
  RETURN VARCHAR2 IS
  v_cod_mon_iso ba_monedas.cod_mon_iso%TYPE;
  BEGIN
    SELECT a.cod_mon_iso
      INTO v_cod_mon_iso
      FROM ba_monedas a
     WHERE a.cod_moneda = p_cod_moneda;
    RETURN v_cod_mon_iso;
  EXCEPTION
    WHEN OTHERS THEN
    RETURN NULL;
  END;

  -- Busca secuencia anterior si el mov. se reversó
  FUNCTION fu_obt_sec_anterior(p_cod_ente number,
                               p_fec_recaudacion date,
                               p_hora varchar2,
                               p_cod_depositante number)
  RETURN NUMBER IS
  v_sec_anterior ge_log_ser_recaudaciones.nro_secuencia%type;
  BEGIN
    SELECT distinct a.nro_secuencia
      INTO v_sec_anterior
      FROM ge_log_ser_recaudaciones a
     WHERE a.cod_ente = p_cod_ente
       AND a.fec_recaudacion = p_fec_recaudacion
       AND a.hora = p_hora
       AND a.cod_depositante = p_cod_depositante;
    RETURN v_sec_anterior;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULl;
  END;

  --
  FUNCTION fu_obt_sec_cheques(p_fec_recaudacion date,
                              p_cod_ente number,
                              p_nro_boleta number,
                              p_monto number,
                              p_cod_moneda varchar2)
  RETURN NUMBER IS
  v_nro_sec_ant ge_log_ser_recaudaciones.nro_secuencia%type;
  BEGIN
    SELECT distinct a.nro_secuencia
      INTO v_nro_sec_ant
      FROM ge_log_ser_recaudaciones a
     WHERE a.fec_recaudacion = p_fec_recaudacion
       AND a.cod_ente = p_cod_ente
       AND a.nro_boleta = p_nro_boleta
       AND a.tip_deposito like 'CHEQUE%'
       AND a.importe = p_monto
       AND a.cod_moneda = p_cod_moneda;
    RETURN v_nro_sec_ant;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULl;
  END;

begin
  IF trunc(sysdate) = v_fec_actual then
    IF nvl(fug_obt_parentes(v_cod_ente,'SER_ACTIVO_SV'),'N') = 'S' THEN
      Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End;
      v_dir_archivo    := fug_obt_parentes(v_cod_ente,'DIR_ARC_SRV');
      if v_dir_archivo is null then
        raise_application_error(-20000,'Directorio DIR_ARC_SRV no definido para el Ente '||v_cod_ente);
      end if;

      v_hor_corte := fug_obt_parentes(v_cod_ente,'HOR_CORTE');

      FOR tr1 IN c_principal LOOP
        delete ge_axion_tmp;
        v_secuencia := 0;
        v_buffer     := NULL;
        v_aux_buffer := NULL;
        v_line       := NULL;
        v_cod_ente   := tr1.cod_ente;
        v_cabecera   := 0;
        v_tip_valor  := NULL;
        v_cod_depositante := 0;
        v_tip_deposito    := null;

        v_tot_importe   := 0;
        v_reg           := 0;

        v_moneda:= fu_obt_mon_iso(tr1.cod_moneda);
        v_name:= 'BBVAPY'||v_fec_rendicion||v_moneda;

        -- Abrir archivo
        v_file := utl_file.fopen(g_repository,
                                 v_name || '.DAT',
                                 'W',
                                 32767);
        --
        IF v_cabecera=0 THEN
          BEGIN
            SELECT s_nro_rendicion.nextval
              INTO v_nro_rendicion
              FROM dual;
          END;
          v_cabecera:=1;
        END IF;

        v_cta_hija := NULL;
        v_den_cta  := NULL;

        FOR tr2 IN c_reg234(tr1.cod_ente,tr1.cod_moneda) LOOP
          v_est_movimiento := tr2.estado;
          v_aux_buffer := null;
          v_cta_hija := tr2.nro_cta_recaudadora;
          v_den_cta  := rpad(fug_obt_nom_cuenta(tr2.nro_cta_recaudadora),40,' ');

          --- Reversión de Depósito ya Informado.
          if tr2.fec_recaudacion < v_fec_actual and tr2.estado = 'R' then
            v_nro_sec_anterior := fu_obt_sec_anterior(v_cod_ente,
                                                      tr2.fec_recaudacion,
                                                      tr2.hora,
                                                      tr2.cod_depositante);
          elsif tr2.fec_recaudacion < v_fec_actual and tr2.tip_deposito like 'CHEQUE%' then
              -- Novedades de Cheques - Deposito anterior
              v_nro_sec_anterior := fu_obt_sec_cheques(tr2.fec_recaudacion,
                                                       v_cod_ente,
                                                       tr2.nro_boleta,
                                                       tr2.importe,
                                                       tr2.cod_moneda);
              v_mov_inf_pri_vez  := 'N';
          else
            v_nro_sec_anterior := null;
            v_mov_inf_pri_vez  := 'S';
          end if;

          v_can_cheques := 0;
          v_tot_importe := nvl(v_tot_importe,0) + tr2.importe;

          if tr2.tip_deposito like 'CHEQUE%' then
            v_tip_valor := '09';
          elsif tr2.tip_deposito = 'EFECTIVO' then
            v_tip_valor := '01';
          elsif tr2.tip_deposito = 'TRANSFERENCIA' then
            v_tip_valor := '05';
          else
            v_tip_valor := '00';
          end if;
          IF (nvl(v_nro_boleta,'0') != tr2.nro_boleta) or (nvl(v_est_mov_ant,'x') != v_est_movimiento)
            or (nvl(v_tip_deposito,'x') != tr2.tip_deposito) THEN

            v_nro_boleta := tr2.nro_boleta;
            v_tip_deposito := tr2.tip_deposito;

            if v_nro_sec_anterior is null then
              SELECT s_nro_sec_axion.nextval INTO v_nro_secuencia FROM dual;
            end if;
            if nvl(v_est_mov_ant,'x') != v_est_movimiento then
              v_est_mov_ant := v_est_movimiento;
            end if;
            -- Cantidad de cheques por boletas.
            BEGIN
              SELECT COUNT(1)
                INTO v_can_cheques
                FROM gv_recaudaciones a
               WHERE a.cod_ente = tr2.cod_ente
                 AND a.fec_recaudacion = tr2.fec_recaudacion
                 AND a.nro_boleta = tr2.nro_boleta
                 AND a.tip_deposito like 'CHEQUE%';
            EXCEPTION
              WHEN no_data_found THEN
                v_can_cheques := 0;
              WHEN too_many_rows THEN
                raise_application_error(-20000,'Error al Buscar Cantidad de Cheques.');
            END;
          END IF;

          BEGIN
            SELECT DISTINCT a.cod_usuario
              INTO v_cod_usu_cajero
              FROM cj_movimientos a
             WHERE a.fecha = tr2.fec_recaudacion
               AND a.hora = tr2.hora
               AND a.nro_documento = tr2.nro_boleta;
          EXCEPTION
            WHEN OTHERS THEN
              v_cod_usu_cajero := NULL;
          END;

          v_moneda:= fu_obt_mon_iso(tr2.cod_moneda);

          --v_fec_rendicion := to_char(tr2.fec_Recaudacion,'YYYYMMDD');

          if v_nro_sec_anterior is not null then
            v_nro_secuencia := v_nro_sec_anterior;
            v_nro_sec_anterior := null;
          end if;
          --
          v_importe := lpad(trim(replace(replace(to_char(tr2.importe,'999999999999D99'),'.',''),',','')),15,'0');

          if tr2.estado = 'N' then
            v_est_mov_ainformar := 'P';
          else
            v_est_mov_ainformar := 'A';
          end if;

          --Detalle de Datos
          v_line := '2'|| -- Registro de Movimientos
                    v_cod_empresa|| --Nro Convenio
                    lpad(nvl(v_nro_rendicion, 0),6,0) ||--Nro rendicion
                    lpad(nvl(v_nro_secuencia,0),10,0)||--Secuencia
                    lpad(nvl(tr2.cod_oficina,0),3,0) ||--Sucursal de Pago
                    lpad(nvl(tr2.cod_depositante,0), 18, 0)||--Nro de Depositante enviado por la empresa
                    v_nro_mov_comprobante|| -- Nro de Factura
                    v_importe ||--Importe del movimiento
                    v_tip_valor|| --Tipo de Valor ver convalidaciones
                    to_char(tr2.fec_recaudacion, 'yyyymmdd') ||--Fecha Emision
                    to_char(tr2.fec_recaudacion, 'yyyymmdd') || --Fecha Pago
                    lpad(nvl(v_cod_usu_cajero,' '), 8, ' ') || --Nro Legajo
                    REPLACE(tr2.hora,':', '.')||--Hora de Movimiento
                    RPAD(' ',77,' ')|| --filler
                    lPAD(' ',70,' ')|| --Codigo de Barra
                    lpad(nvl(tr2.tip_documento,0),2,0)||--Tipo de documento Depositante
                    lpad(nvl(tr2.nro_documento,0),13,0)||--Numero de documento Depositante
                    rpad(nvl(tr2.depositante,' '),60,' ')||--Nombre Depositante(nombre)
                    to_char(tr2.fec_recaudacion, 'yyyymmdd') || --Fecha Acreditacion
                    'S' || -- no manejamos multifactura
                    nvl(v_mov_inf_pri_vez,'S') || --Flag de Cheques (S se recauda/N se acredita)
                    v_est_mov_ainformar ||-- Estado del movimiento (en rendicion final solo P(aceptados)/Rendición Parcial A(Anulado))
                    RPAD(' ',4,' ')||--filler
                    ' '; --Marca SAP

          v_reg := v_reg + 1;
          v_secuencia := v_secuencia + 1;
          insert into ge_axion_tmp(nro_linea, dato, nro_secuencia, cod_moneda)
          values (2,v_line, v_secuencia, tr2.cod_moneda);

          if v_aux_buffer is null then
            v_aux_buffer := v_line;
          else
            v_aux_buffer := v_aux_buffer || v_eol || v_line;
          end if;

          -------
          v_line := '3'|| -- Registro de Movimientos
                    v_cod_empresa|| --Nro Convenio
                    lpad(nvl(v_nro_rendicion, 0),6,0) ||--Nro rendicion
                    lpad(nvl(v_nro_secuencia,0),10,0)||--Secuencia
                    'D' ||--Débito / nota de crédito
                    'N'||--N si el pago es total, S si el pago es parcial
                    ' '|| -- Filler
                    lpad(nvl(tr2.cod_depositante,0), 18, 0)||--Nro de Depositante enviado por la empresa
                    v_nro_mov_comprobante|| -- Nro de Factura
                    v_importe||--Importe del movimiento
                    to_char(tr2.fec_recaudacion, 'yyyymmdd') ||--Fecha Emision
                    to_char(tr2.fec_recaudacion, 'yyyymmdd') || --Fecha Pago
                    lpad(' ', 24, ' ') || --Cod. concepto
                    lpad(' ', 24, ' ') || --Desc. concepto
                    lpad(' ', 38, ' ') || --Leyenda
                    lpad(' ', 9, ' ') || --Filler
                    lpad(' ', 70, ' ') || --faccodbarra
                    RPAD(' ',14,' ')|| --recibo
                    lPAD(' ',30,' ')|| --observaciones
                    lPAD(' ',46,' ')|| --Filler
                    ' '; --Marca SAP

          v_reg := v_reg + 1;
          v_secuencia := v_secuencia + 1;
          insert into ge_axion_tmp(nro_linea, dato, nro_secuencia, cod_moneda)
          values (3,v_line, v_secuencia, tr2.cod_moneda);

          v_aux_buffer := v_aux_buffer || v_eol || v_line;

          -------
          v_line := '4'|| -- Registro de Movimientos
                    v_cod_empresa|| --Nro Convenio
                    lpad(nvl(v_nro_rendicion, 0),6,0) ||--Nro rendicion
                    lpad(nvl(v_nro_secuencia,0),10,0)||--Secuencia
                    lpad(' ', 39, ' ') || --Filler
                    v_importe ||--Importe del movimiento
                    v_tip_valor||--Tipo de Valor
                    lpad(tr2.nro_boleta,8,0)|| --nro de boleta
                    lpad(v_can_cheques,4,' ')|| -- Cantidad de cheques que corresponden a la boleta
                    lpad(' ', 257, ' ') || --Filler
                    ' '; --Marca SAP

          v_reg := v_reg + 1;
          v_secuencia := v_secuencia + 1;
          insert into ge_axion_tmp(nro_linea, dato, nro_secuencia, cod_moneda)
          values (4,v_line, v_secuencia, tr2.cod_moneda);

          v_aux_buffer := v_aux_buffer || v_eol || v_line;

          -- Se guarda la información enviada al Cliente.
          BEGIN
            INSERT INTO ge_log_ser_recaudaciones
            (fecha, cod_ente, nro_boleta, fec_recaudacion,
             nro_cta_recaudora, cod_moneda, tip_deposito,
             nro_cheque, banco, importe, est_cheque, nro_secuencia, estado,
             cod_depositante, hora)
            VALUES
            (v_fec_actual, tr2.cod_ente, tr2.nro_boleta, tr2.fec_recaudacion,
             tr2.nro_cta_recaudadora, tr2.cod_moneda, tr2.tip_deposito, null,
             null, tr2.importe, null, v_nro_secuencia, v_est_movimiento,
             tr2.cod_depositante, tr2.hora);
          EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20000,'Error al insertar log '||sqlerrm);
          END;
          v_con_cheq := 0;
          --****** CHEQUES POR MOVIMIENTO *************************
          FOR tr5 IN c_reg5(tr2.cod_ente,tr2.cod_moneda,tr2.nro_boleta) LOOP
            v_importe        := null;
            v_cod_banco      := null;
            v_est_che_real   := 'P';
            v_fec_che_final  := null;
            v_cau_devolucion := null;
            v_inc_cab_cheque := 'S';
            IF tr2.tip_deposito like 'CHEQUE%' THEN -- solo cargar en el archivo cheques.
              v_che_presentado := 'P';
              IF nvl(tr5.cod_banco,0) != 7 THEN -- 7 bbvapy
                v_che_detallado := 'S';
                BEGIN
                  SELECT a.cod_banco,
                         a.fecha,
                         a.fec_final,
                         a.estado,
                         a.monto,
                         a.cod_retencion,
                         a.cod_cau_devolucion,
                         a.cod_usuario,
                         a.cod_cau_devolucion
                    INTO v_cod_banco, v_fec_cheque, v_fec_che_final, v_est_cheque,
                         v_mto_cheque, v_cod_retencion, v_cod_cau_devolucion, v_cod_usu_cheque,
                         v_cau_devolucion
                    FROM cc_che_enviados a
                   WHERE a.nro_boleta = tr5.nro_boleta
                     AND a.nro_cheque = tr5.nro_cheque
                     AND a.cod_banco = tr5.cod_banco
                     AND a.fecha = tr5.fec_recaudacion;

                EXCEPTION
                  WHEN no_data_found THEN
                    v_che_detallado := 'N';
                  WHEN others THEN
                    v_che_detallado := 'N';
                END;
              ELSE
                v_cod_banco      := tr5.cod_banco;
                v_fec_che_final  := tr5.fec_recaudacion;
                v_mto_cheque     := tr5.importe;
                v_che_presentado := 'P';
                v_che_detallado  := 'S';
                --
                BEGIN
                  select distinct a.liberado -- a.lib_posterior  -- 01/2016
                    into v_liberado
                    from ah_retenciones a
                   where a.nro_cuenta = tr5.nro_cta_recaudadora
                     and a.nro_documento = tr5.nro_boleta;
                EXCEPTION
                  WHEN no_data_found then
                    v_liberado := 'N';
                  WHEN others then
                    v_liberado := 'N';
                END;

              END IF;

              if v_che_detallado = 'S' then
                v_importe := lpad(trim(replace(replace(to_char(v_mto_cheque,'999999999999D99'),'.',''),',','')),15,'0');
              else
                v_importe := lpad(trim(replace(replace(to_char(tr5.importe,'999999999999D99'),'.',''),',','')),15,'0');
              end if;
              ---
              if tr5.cod_banco != 7 and (tr5.est_cheque = 'Confirmado' or tr5.est_cheque like '%Rechazado') then
                if tr5.est_cheque = 'Confirmado' then
                  v_est_che_real := 'A';
                else
                  v_est_che_real := 'R';
                  v_cod_cau_devolucion := trim(substr(tr5.est_cheque,1,3));
                end if;
              end if;
              --
              if v_fec_che_final is null then
                BEGIN
                  select a.fec_final
                    into v_fec_che_final
                    from ah_retenciones a
                   where a.nro_cuenta = tr5.nro_cta_recaudadora
                     and a.nro_documento = tr5.nro_boleta
                     and a.cod_moneda = tr5.cod_moneda;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                  null;
                  WHEN OTHERS THEN
                  null;
                END;
              end if;
              if v_fec_che_final is null then
                v_fec_che_fin_tex := '00000000';
              else
                v_fec_che_fin_tex := to_char(v_fec_che_final, 'yyyymmdd');
              end if;
              --Detalle de Cheques
              if v_est_che_real = 'R' and v_cau_devolucion is null then
                v_cau_devolucion := 112;
              end if;
              if tr5.cod_banco = 7 then
                begin
                  select 'S'
                    into v_che_cnb_presentado
                    from ge_log_ser_recaudaciones a
                   where a.nro_boleta = tr5.nro_boleta
                     and a.fec_recaudacion = tr5.fec_recaudacion
                     and a.nro_cta_recaudora = tr5.nro_cta_recaudadora
                     and a.tip_deposito = tr5.tip_deposito
                     and a.nro_cheque = tr5.nro_cheque
                     and a.est_cheque = 'Pend. de Confirmación';
                exception
                  when others then
                    null;
                end;
              end if;
              if tr5.cod_banco != 7 or (tr5.cod_banco = 7 and nvl(v_che_cnb_presentado,'N') = 'N') then
                v_line := '5'|| -- Registro de Cheques
                          v_cod_empresa|| --Nro Convenio
                          lpad(nvl(v_nro_rendicion, 0), 6,0) ||--Nro rendicion
                          lpad(nvl(v_nro_secuencia,0),10,0)||--Secuencia
                          rpad(' ',39,' ')|| --filler
                          v_importe||--Importe de Cheque
                          '09'|| --Forma de Pago Cheque fecha cierta
                          lpad(nvl(tr5.nro_boleta,0), 8, 0)||--Nro.Boleta
                          lpad(nvl(tr5.nro_cheque,0), 8, 0)||--Nro.Cheque
                          lpad(nvl(v_cod_banco,0), 4, 0)||--Banco Emisor
                          '0001'||--Sucursal
                          '0000'||--Codigo Postal
                          lpad(nvl(tr2.nro_cta_recaudadora,0), 11, 0)||--Nro.Cuenta
                          v_fec_che_fin_tex ||--Fecha Valor
                          v_est_che_real|| --Estado Aceptado/Rechazado (P (primera vez), A aceptado R Rechazado)
                          rpad(nvl(trim(substr(lpad(v_cau_devolucion, 3, '0'),1,29)),' '),30,' ')||--Desc Error
                          v_est_che_real|| --Estado Aceptado/Rechazado
                          '        '|| -- Feresol
                          '0000000000'||
                          rpad(' ',173,' '); --filler

                 v_reg := v_reg + 1;
                 v_secuencia := v_secuencia + 1;

                 insert into ge_axion_tmp(nro_linea, dato, nro_secuencia, cod_moneda)
                 values (5,v_line, v_secuencia, tr5.cod_moneda);
               elsif tr5.cod_banco = 7 then
                 v_inc_cab_cheque := 'N';
               end if;

               IF tr5.cod_banco = 7 and v_liberado = 'S' THEN
                 BEGIN
                  select 'S', a.cod_causa
                    into v_che_devuelto, v_cau_devolucion
                    from cc_che_devueltos a
                   where a.nro_cuenta = tr5.nro_cta_cheque
                     and a.nro_cheque = tr5.nro_cheque;
                EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                    v_che_devuelto := 'N';
                  WHEN OTHERS THEN
                    v_che_devuelto := 'N';
                END;
                --
                 if v_che_devuelto = 'S' then
                    v_est_che_real := 'R';
                  else
                    v_est_che_real := 'A';
                  end if;
                 -- Se va actualizar la posición 344 al valor N (RCWC2080-DE-MOV-INF-PRIM-VEZ)
                 v_length_aux_buffer := length(v_aux_buffer);
                 v_aux_buffer := substr(v_aux_buffer,1,343)||'N'||substr(v_aux_buffer,345,v_length_aux_buffer);
                 --
                 if v_est_che_real = 'R' and v_cau_devolucion is null then
                   v_cau_devolucion := 112;
                 end if;
                 v_line_5 := '5'|| -- Registro de Cheques
                          v_cod_empresa|| --Nro Convenio
                          lpad(nvl(v_nro_rendicion, 0), 6,0) ||--Nro rendicion
                          lpad(nvl(v_nro_secuencia,0),10,0)||--Secuencia
                          rpad(' ',39,' ')|| --filler
                          v_importe||--Importe de Cheque
                          '09'|| --Forma de Pago Cheque fecha cierta
                          lpad(nvl(tr5.nro_boleta,0), 8, 0)||--Nro.Boleta
                          lpad(nvl(tr5.nro_cheque,0), 8, 0)||--Nro.Cheque
                          lpad(nvl(v_cod_banco,0), 4, 0)||--Banco Emisor
                          '0001'||--Sucursal
                          '0000'||--Codigo Postal
                          lpad(nvl(tr2.nro_cta_recaudadora,0), 11, 0)||--Nro.Cuenta
                          to_char(v_fec_che_final, 'yyyymmdd') ||--Fecha Valor
                          v_est_che_real|| --Estado Aceptado/Rechazado (P (primera vez), A aceptado R Rechazado)
                          rpad(nvl(trim(substr(lpad(v_cau_devolucion, 3, '0'),1,29)),' '),30,' ')||--Desc Error
                          v_est_che_real|| --Estado Aceptado/Rechazado
                          '        '|| -- Feresol
                          '0000000000'||
                          rpad(' ',173,' '); --filler

                   v_con_cheq := v_con_cheq + 1;

                   if v_buf_che_aprobado is null then
                     v_buf_che_aprobado := v_line_5;
                   else
                     v_buf_che_aprobado := v_buf_che_aprobado || v_eol || v_line_5;
                   end if;
                   --
                   BEGIN
                    INSERT INTO ge_log_ser_recaudaciones
                    (fecha, cod_ente, nro_boleta, fec_recaudacion,
                     nro_cta_recaudora, cod_moneda, tip_deposito, nro_cheque,
                     banco, importe, est_cheque, nro_secuencia, estado,
                     cod_depositante, hora)
                    VALUES
                    (v_fec_actual, tr2.cod_ente, tr2.nro_boleta, tr2.fec_recaudacion,
                     tr2.nro_cta_recaudadora, tr2.cod_moneda, tr2.tip_deposito, tr5.nro_cheque,
                     tr5.banco, v_mto_cheque, tr5.est_cheque, v_nro_secuencia, v_est_movimiento,
                     tr5.cod_depositante, tr5.hora);
                  EXCEPTION
                    WHEN OTHERS THEN
                      raise_application_error(-20000,'Error al insertar Log '||sqlerrm);
                  END;
                   --
               END IF;
              -- Se guarda la información enviada al Cliente.
              BEGIN
                INSERT INTO ge_log_ser_recaudaciones
                (fecha, cod_ente, nro_boleta, fec_recaudacion,
                 nro_cta_recaudora, cod_moneda, tip_deposito, nro_cheque,
                 banco, importe, est_cheque, nro_secuencia, estado,
                 cod_depositante, hora)
                VALUES
                (v_fec_actual, tr2.cod_ente, tr2.nro_boleta, tr2.fec_recaudacion,
                 tr2.nro_cta_recaudadora, tr2.cod_moneda, tr2.tip_deposito, tr5.nro_cheque,
                 tr5.banco, v_mto_cheque, tr5.est_cheque, v_nro_secuencia, v_est_movimiento,
                 tr5.cod_depositante, tr5.hora);
              EXCEPTION
                WHEN OTHERS THEN
                  raise_application_error(-20000,'Error al insertar Log '||sqlerrm);
              END;

            END IF;

          END LOOP;
          if v_buf_che_aprobado is not null then
            v_secuencia := v_secuencia + 1;
            if nvl(v_inc_cab_cheque,'S') = 'S' then
              insert into ge_axion_tmp(nro_linea, dato, nro_secuencia, cod_moneda)
              values (2345,v_aux_buffer||v_eol||v_buf_che_aprobado, v_secuencia, tr2.cod_moneda);
              --
              v_aux_buffer := null;
              v_buf_che_aprobado := null;
              v_con_cheq := v_con_cheq + 3;
            else
              insert into ge_axion_tmp(nro_linea, dato, nro_secuencia, cod_moneda)
              values (5,v_buf_che_aprobado, v_secuencia, tr2.cod_moneda);
              --
              v_aux_buffer := null;
              v_buf_che_aprobado := null;
            end if;
          end if;
          v_reg := v_reg + v_con_cheq;
          EXIT WHEN c_reg234%NOTFOUND;
        END LOOP;
        v_tot_registro := v_reg;

        v_imp_linea1 := lpad(trim(replace(replace(to_char(v_tot_importe,'999999999999D99'),'.',''),',','')),15,'0');

        v_line_1 := '1'||
                 v_cod_empresa|| --Nro Convenio
                 lpad(nvl(v_nro_rendicion, 0),6,0) ||--Nro rendicion
                 '0000000000'||--Secuencia de la cabecera 0
                 v_fec_rendicion||--Fecha Desde
                 v_fec_rendicion||--Fecha Hasta
                 lpad(nvl(v_tot_registro, 0),6,0)  || ---Cantidad de registros
                 v_imp_linea1|| --total importe
                 lpad(v_moneda,3,' ')||--Moneda
                 lpad(v_cta_hija,20,0)||--Cta.Hija
                 lpad(v_den_cta,40,' ')||-- titulo cta
                 lpad(v_cta_hija,20,0)|| --cuenta de la empresa
                 RPAD(' ',205,' ')|| --filler
                 ' '; --marca de sap


          v_reg := v_reg + 1;
          v_secuencia := v_secuencia + 1;
          insert into ge_axion_tmp(nro_linea, dato, nro_secuencia, cod_moneda)
          values (1,v_line_1, v_secuencia, tr1.cod_moneda);

      --
      select a.dato
        into v_line
        from ge_axion_tmp a
       where a.nro_linea = 1
         and a.cod_moneda = tr1.cod_moneda;
      UTL_FILE.PUT_LINE(v_file,v_line);
      for k in (select b.nro_linea, b.dato, b.nro_secuencia, b.cod_moneda
                  from ge_axion_tmp b
                 where b.nro_linea != 1
                   and b.cod_moneda = tr1.cod_moneda
              order by b.nro_secuencia) loop
        begin
        select a.dato
          into v_line
          from ge_axion_tmp a
         where a.nro_linea = k.nro_linea
           and a.nro_secuencia = k.nro_secuencia
           and a.cod_moneda = k.cod_moneda;
        exception
          when no_data_found then
            raise_application_error(-20000,'Error 1: '||sqlerrm);
          when others then
            raise_application_error(-20000,'Error 2: '||sqlerrm);
        end;
        UTL_FILE.PUT_LINE(v_file,v_line);
      end loop;
      UTL_FILE.FCLOSE(v_file);

      v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
      v_respuesta := pa_file_ftp.fu_put_ascii(g_ip,
                                            g_port,
                                            g_user,
                                            g_pass,
                                            g_repository,
                                            v_name||'.DAT',
                                            v_dir_archivo || v_name||'.DAT');

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

       END IF;

      END LOOP;
    END IF;
  END IF;
  --Se agrega el commit para que no corte el proceso de axion.
  commit;
  prc_env_mai_cta_tra;

  
EXCEPTION
  WHEN utl_file.invalid_operation THEN
    utl_file.fclose(v_file);
    raise_application_error(-20061, 'Operacion invalida ' || SQLERRM);
  WHEN utl_file.invalid_filehandle THEN
    utl_file.fclose(v_file);
    raise_application_error(-20062, 'Manejador invalido ' || SQLERRM);
  WHEN utl_file.write_error THEN
    utl_file.fclose(v_file);
    raise_application_error(-20063, 'Error de escritura ' || SQLERRM);
  WHEN utl_file.invalid_mode THEN
    utl_file.fclose(v_file);
    raise_application_error(-20064, 'Modo invalido ' || SQLERRM);
  WHEN utl_file.internal_error THEN
    utl_file.fclose(v_file);
    raise_application_error(-20065, 'Internal Error ' || SQLERRM);
end;
/

