CREATE OR REPLACE PROCEDURE IT.PRG_REV_OPERACION
(
   p_fecha             IN ge_movimientos.fecha%TYPE,
   p_hora              IN ge_movimientos.hora%TYPE,
   p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
   p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
   p_cod_mad_padre     IN ge_movimientos.cod_mad_padre%TYPE,
   p_cod_tra_padre     IN ge_movimientos.cod_tra_padre%TYPE,
   p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE DEFAULT USER,
   p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE DEFAULT to_char(SYSDATE, 'HH24:MI:SS'),
   p_es_nocturno       IN VARCHAR2 DEFAULT 'N',
   p_concepto          IN VARCHAR2 DEFAULT NULL,
   p_nro_lote          IN NUMBER DEFAULT NULL,
   p_cod_transaccion   IN NUMBER DEFAULT NULL,
   p_nro_documento     IN ge_movimientos.nro_documento%TYPE DEFAULT NULL,
   p_mov_orden         IN VARCHAR2 DEFAULT NULL, /* DYDMR-4088 Julio/2016 */
   p_nro_ncredito      IN ge_movimientos.nro_documento3%TYPE DEFAULT NULL
) IS
  
   r_gmovi              ge_movimientos%ROWTYPE;
   r_mov_cam_est        ge_movimientos%ROWTYPE; --Para guardar el registro de cambio de estado para insertarlo dentro del grupo de DCTO de cheques que no tenga dicho cambio de estado.
   v_gen_estado         VARCHAR2(1) := 'N'; --Bandera para generar reversion de estado para la modalidad DCTO. DE CHEQUES
   v_es_nocturno        VARCHAR2(1);
   v_est_modulo         ba_modulos.estado%TYPE;
   v_fec_actual         ge_calendarios.fec_actual%TYPE;
   v_ope_pendiente      VARCHAR2(1) := 'N';
   v_ope_ahorros        VARCHAR2(1) := 'N';
   v_cod_gru_iva        ge_gru_transacciones.cod_gru_transaccion%TYPE := fug_obt_pardinamico('COD_GRU_TRA_IVA');
   v_fec_ini_dev        ah_devengados.fec_inicio%TYPE;
   v_cod_usu_lib        ta_cobros.cod_usuario%TYPE; --usuario registrado en ta_cobros
   v_hora_insercion     ge_movimientos.hora%TYPE; --fecha de insercion de ge_mov a ta_cob
   v_est_envio          ta_cobros.est_envio%TYPE;
   v_transferencia      VARCHAR2(1);
   v_afe_libranza       VARCHAR2(1);
   v_mto_apl_reversar   NUMBER(18, 2) := 0;
   v_con_pro_garantia   NUMBER(5) := 0;
   v_fec_envio          DATE;
   v_devengo            VARCHAR2(1) := 'N';
   v_ope_cambios        ge_movimientos.cod_tip_ope_cambio%TYPE;
   v_nro_transf         lc_transferencias.nro_operacion%TYPE;
   v_mad_hijo           ge_modalidades.cod_modalidad%TYPE;
   r_ah_retenciones     ah_retenciones%ROWTYPE;
   --Variables de SNP --sipap
   rg_snp_msj              pas_snp.rg_msj;
   v_snp_exi_transferencia VARCHAR(1) := 'N';
   v_snp_env_alerta        VARCHAR(1) := 'N';
   --- Transaccion 346
   v_ord_pago ge_pag_proveedores.nro_orden%TYPE;
   v_cod_ente ge_entes.cod_ente%TYPE;
   -- tr 2801 --DYDMR-7799 - Incidencia SAU - ITGF - Incidencia al Reversar las facturas de proveedores
   v_cod_compra          pv_compras.cod_compra%TYPE;
   v_cod_tra_pago        ge_transacciones.Cod_Transaccion%type := 2602;
   v_cod_tra_rubro       ge_transacciones.Cod_Transaccion%type := 2615;

   
   v_rrr_desembolso      NUMBER;
   v_can_bie_adjudicados NUMBER;
   v_sig_hor_reversion   ge_movimientos.hor_reversion%TYPE DEFAULT to_char(SYSDATE, 'HH24:MI:SS');
   v_hor_reversion       ge_movimientos.hor_reversion%TYPE DEFAULT to_char(SYSDATE, 'HH24:MI:SS');
   v_referencia          ge_movimientos.referencia%TYPE;
   v_nro_documento       ge_movimientos.nro_documento%TYPE;
   v_mto_sobrante        ge_movimientos.monto%TYPE;
   v_est_sobrante        VARCHAR2(1);
   v_cod_tra_sobrante    ge_movimientos.cod_transaccion%TYPE;
   v_nro_sobrante        cj_sobrantes.nro_sobrante%TYPE;
   v_cta_sobrante        cj_sobrantes.nro_cuenta%TYPE;
   v_mov_sobrante        NUMBER := 0;
   v_cod_empresa         ge_entes.cod_ente%TYPE;
   v_ult_dia_mes_habil   date;
   v_est_transferencia            varchar2(10);
   v_sit_transferencia            varchar2(10);
   v_hora                ge_movimientos.hora%type;
   v_afecta             varchar2(1):= (fug_obt_pardinamico('COD_MOD_EST_AFECTA',p_cod_mod_padre));-- C.D Fase II
   v_error               VARCHAR2(1000);
   v_existe              varchar2(1);
   v_mto_impuesto        ge_movimientos.monto%type;
   v_nro_referencia      lc_transferencias.nro_referencia%type;
   v_cat_ren_anterior    ge_cla_operaciones_his.cat_ren_anterior%type;
   v_fec_ult_categorizacion pr_cta_prestamos.fec_ult_categorizacion%type;
   v_nro_cta_credito     ge_cuentas.nro_cuenta%type;
   v_nro_doc_deposito    ge_movimientos.nro_documento%TYPE;
   v_fec_deposito        ge_movimientos.fecha%type;
   v_cod_ret_deposito    ge_movimientos.cod_retencion%type;
   v_cod_mad_deposito    ge_movimientos.cod_modalidad%type;
   v_entro               VARCHAR2(1) := 'N';
   v_cob_pre_che         VARCHAR2(1) := 'N';
   v_est_cobro           VARCHAR2(1) := 'X';
   v_nro_cheque          NUMBER(8);
   v_cta_operativa       VARCHAR2(15);
   v_nro_secuencia       ge_movimientos.nro_secuencia%TYPE;
   v_hor_cre_pp          ge_movimientos.hora%TYPE;
   v_mto_credito         ge_movimientos.monto%TYPE;
   v_nro_cuenta          ge_movimientos.nro_cuenta%type;
   v_monto               NUMBER(18, 2) := 0;
   v_cnmovim             varchar2(50);
   v_cdofior             NUMBER (03);
   v_cod_moneda_sue      VARCHAR2(3);
   v_monto_cre           NUMBER(18, 2) := 0;
   v_max_sec_use_fgdiari NUMBER(07);
   v_cuenta_ente         varchar2(50);
   v_mov_orden           VARCHAR2(10) := nvl(p_mov_orden, 'DESC'); -- DYDMR-4088 Julio/2016

   /*   PARA OPERACIONES DE CAMBIO DYDMR-1741  */

   vb_fecha              ge_movimientos.fecha%TYPE;
   vb_hora              ge_movimientos.hora%TYPE;
   vb_cod_usuario        ge_movimientos.cod_usuario%TYPE;
   vb_cod_mod_padre      ge_movimientos.cod_mod_padre%TYPE;
   vb_cod_mad_padre     ge_movimientos.cod_mad_padre%TYPE;
   vb_cod_tra_padre      ge_movimientos.cod_tra_padre%TYPE;
   --vb_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE DEFAULT USER,
   vb_hor_reversion      ge_movimientos.hor_reversion%TYPE DEFAULT to_char(SYSDATE, 'HH24:MI:SS');
   --vb_es_nocturno       IN VARCHAR2 DEFAULT 'N',
   --vb_concepto          IN VARCHAR2 DEFAULT NULL,
   vb_nro_documento      ge_movimientos.nro_documento%TYPE DEFAULT NULL;
   v_cod_mon_local       ba_monedas.cod_moneda%type := pag_gen.FU_OBT_MON_LOCAL;
   v_sal_cta_imp         cx_cta_importaciones.saldo%type := 0;
   v_cta_importacion     cx_cta_importaciones.nro_cuenta%type;
   ---
   v_cod_gru_cob_com ge_gru_transacciones.cod_gru_transaccion%TYPE := fug_obt_pardinamico('COD_GRU_COB_COM');
   v_cod_tra_cargo    ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_TRA_CARGOS');

   --DYDMR-4001 (ALV - jul/2016)
   v_nro_tarjeta     ta_tarjetas.nro_tarjeta%type;
   -- DDSI-212 -- 2017/12
   v_exi_movimiento  VARCHAR2(1) := 'N';
   v_ord_pag_dna     varchar2(30);
   v_nro_doc_cliente varchar2(30);
   v_tip_doc_cliente varchar2(30);
   v_respuesta_dna varchar2(3000);
   v_error_dna varchar2(3000);
   v_tie_cob_seg_distr varchar2(1);

   v_mod_habilitados varchar2(30);
   v_enc_gv_mov_par varchar2(1);

   --Proyecto SDSEGVID-144--Seguro Anual de Consumo--
   v_pre_hab_cal_seg_anual ge_par_dinamicos.val_parametro%type;

   ---
   CURSOR c_bienes(p_cod_tra_padre in number, p_cod_transaccion in number) IS
      SELECT hora
        FROM gv_movimientos g
       WHERE g.fecha = p_fecha
         AND g.hora <> p_hora
         AND g.cod_usuario = p_cod_usuario
         AND g.monto <> 0
         AND g.cod_modulo = 26
         AND g.reversado = 'N'
         AND g.referencia = (SELECT m.referencia
                               FROM gv_movimientos m
                              WHERE m.fecha = p_fecha
                                AND m.hora = p_hora
                                AND m.cod_usuario = p_cod_usuario
                                AND m.monto <> 0
                                AND m.cod_modulo = 26
                                AND m.cod_tra_padre = p_cod_tra_padre
                                AND m.cod_transaccion = p_cod_transaccion);

   --------------------------------------
   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE
   );
   /* Crea los movimientos para insertarlos en GE_MOVIMIENTOS. */
   PROCEDURE lp_ins_movimientos
   (
      rp_gmovi            IN ge_movimientos%ROWTYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_es_nocturno       IN VARCHAR2 := 'X'
   );
   /* obtiene datos de garantia de operaciones vencidas */
   FUNCTION lf_obt_mto_apl_reversar
   (
      p_nro_cuenta   IN VARCHAR2,
      p_cod_garantia IN NUMBER,
      p_nro_garantia IN NUMBER,
      p_fecha        IN DATE,
      p_hora         IN VARCHAR2,
      p_cod_usuario  IN VARCHAR2
   ) RETURN NUMBER;
   /* Validar que no permita reversar operaciones de IVA */
   PROCEDURE lp_val_iva(rp_gmovi IN ge_movimientos%ROWTYPE);
   /* Actualiza los movimientos historicos a reversado. */
   PROCEDURE lp_act_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_nro_secuencia     IN ge_movimientos.nro_secuencia%TYPE,
      p_cod_usu_insercion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_cod_modulo        IN ge_movimientos.cod_modulo%TYPE
   );

    FUNCTION lf_obt_hor_max_movimiento
    (
       p_fecha       in date,
       p_hora3        in varchar2,
       p_cod_usuario in varchar2
    ) return varchar2;

 /*procedure interno cheque de favor-CRO-CHE_FAVOR CROCF-3 CHEQUES DE FAVOR CROCF-10 - Sergio
   Servín 27/06/2014*/
  PROCEDURE lp_rev_che_cust(p_tip_control   varchar2, /*A= transacciones 59, B= transacciones 58*/
                             p_cod_tra_padre varchar2,
                             p_cod_mod_padre varchar2,
                             p_cod_mad_padre varchar2,
                             p_nro_documento ge_movimientos.nro_documento%TYPE);
   /* BSEVOCORE-40 Reversion de Exoneraciones de Prestamos */
   PROCEDURE lp_eli_exoneraciones
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
      p_cod_autorizacion  IN ge_autorizaciones.cod_autorizacion%TYPE default null,
      p_modo              IN varchar2 default 'D' -- del dia; H - historico
    );
   CURSOR cur_gmovi IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado, /* PN 08/04/2014 DI: Las reversiones deben mantener el estado del movimiento a reversar. SPI 3361*/
             --decode(v_afecta,'S',(decode(estado,'P',estado,estado)),decode(estado,'P','N', estado))estado,-- C.D. Fase II
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable,
             nro_conciliacion
        FROM ge_movimientos
       WHERE fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
         AND reversado = 'N'
       ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC; -- DYDMR-4088 Julio/2016
   --
     CURSOR cur_gmovi_sue IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado,
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable,
             nro_conciliacion
        FROM ge_movimientos
       WHERE fecha = p_fecha
         AND nro_documento2 = p_nro_lote
         AND cod_usuario = p_cod_usuario
         AND reversado = 'N'
         and cod_tra_padre in (304,1304,1305,1306)
       ORDER BY nro_secuencia DESC;
       cursor cur_movi_sue_ta (p_nro_cuenta varchar2) is
           SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado,
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable,
             nro_conciliacion
        FROM ge_movimientos
       WHERE fecha = p_fecha
         AND nro_documento2 = p_nro_lote
         AND cod_usuario = p_cod_usuario
         AND reversado = 'N'
         AND cod_tra_padre in (186,986)
         AND nro_cuenta = p_nro_cuenta
         union
         SELECT g.fecha,
                g.hora,
                g.cod_usuario,
                g.nro_secuencia,
                g.fec_valor,
                g.monto,
                g.nro_cuenta,
                g.cod_moneda,
                g.cod_oficina,
                g.cod_error,
                g.cod_retencion,
                g.fec_fin_retencion,
                g.est_cuenta,
                g.estado,
                g.cod_causa,
                g.cod_banco,
                g.cod_ofi_origen,
                g.concepto,
                g.cod_tasa,
                g.val_tasa,
                g.cod_rubro,
                g.cod_ref_cambio,
                g.reversado,
                g.cod_usu_reversion,
                g.hor_reversion,
                g.emi_aviso,
                g.cod_tra_padre,
                g.cod_mod_padre,
                g.cod_mad_padre,
                g.cod_transaccion,
                g.cod_modulo,
                g.cod_modalidad,
                g.mto_equ_local,
                g.nro_caja,
                g.cotizacion,
                g.cod_bco_central,
                g.nro_documento,
                g.nro_documento2,
                g.nro_documento3,
                g.nro_documento4,
                g.protegido,
                g.cod_autorizacion,
                g.cod_usu_autorizador,
                g.usu_insercion,
                g.fec_insercion,
                g.usu_modificacion,
                g.fec_modificacion,
                g.tip_mov_rubro,
                g.cod_tip_ope_cambio,
                g.referencia,
                g.cod_persona,
                g.cod_sit_contable,
                g.nro_conciliacion
        FROM ge_movimientos g, ta_cta_tarjetas t
       WHERE g.fecha = p_fecha
         AND g.nro_documento2 = p_nro_lote
         AND g.cod_usuario = p_cod_usuario
         AND g.reversado = 'N'
         and t.nro_cta_debito= p_nro_cuenta
         AND g.cod_tra_padre in (186,986)
         AND g.nro_cuenta = t.nro_cuenta
     ORDER BY 3 DESC;
     CURSOR cur_gmovi_car IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado,
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable,
             nro_conciliacion
        FROM ge_movimientos
       WHERE fecha = p_fecha
         AND nro_documento2 =p_nro_lote
         AND cod_usuario = p_cod_usuario
         AND reversado = 'N'
         and cod_tra_padre in (304,1304,1305,1306)
         and cod_transaccion not in (503,602)
       ORDER BY nro_secuencia DESC;
   ---
   CURSOR cur_gmono IS
      SELECT fecha,
             hora,
             cod_usuario,
             nro_secuencia,
             fec_valor,
             monto,
             nro_cuenta,
             cod_moneda,
             cod_oficina,
             cod_error,
             cod_retencion,
             fec_fin_retencion,
             est_cuenta,
             estado,
             cod_causa,
             cod_banco,
             cod_ofi_origen,
             concepto,
             cod_tasa,
             val_tasa,
             cod_rubro,
             cod_ref_cambio,
             reversado,
             cod_usu_reversion,
             hor_reversion,
             emi_aviso,
             cod_tra_padre,
             cod_mod_padre,
             cod_mad_padre,
             cod_transaccion,
             cod_modulo,
             cod_modalidad,
             mto_equ_local,
             nro_caja,
             cotizacion,
             cod_bco_central,
             nro_documento,
             nro_documento2,
             nro_documento3,
             nro_documento4,
             protegido,
             cod_autorizacion,
             cod_usu_autorizador,
             usu_insercion,
             fec_insercion,
             usu_modificacion,
             fec_modificacion,
             tip_mov_rubro,
             cod_tip_ope_cambio,
             referencia,
             cod_persona,
             cod_sit_contable,
             nro_conciliacion
        FROM ge_movimientos_noc
       WHERE fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND reversado = 'N'
       ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC; -- DYDMR-4088 Julio/2016
   --

   CURSOR garantias(v_nro_cuenta VARCHAR2) IS
      SELECT t.mto_aplicado, t.nro_garantia, t.cod_garantia
        FROM pr_cta_garantias_nov t
       WHERE t.fecha = p_fecha
         AND t.hora = p_hora
         AND t.cod_usuario = p_cod_usuario
         AND t.nro_cuenta = v_nro_cuenta;

   -- cursor de garantias de operaciones vencidas
   CURSOR garantias_ov(v_nro_cuenta VARCHAR2) IS
      SELECT t.mto_aplicado, t.nro_garantia, t.cod_garantia
        FROM ov_cta_garantias_nov t
       WHERE t.fecha = p_fecha
         AND t.hora = p_hora
         AND t.cod_usuario = p_cod_usuario
         AND t.nro_cuenta = v_nro_cuenta;

   --Traer datos de la retencion
   PROCEDURE lp_obt_retencion
   (
      p_nro_cuenta      ah_retenciones.nro_cuenta%TYPE,
      p_nro_documento   ah_retenciones.nro_documento%TYPE,
      p_cod_retencion   ah_retenciones.cod_retencion%TYPE,
      p_fec_inicio      ah_retenciones.fec_inicio%TYPE,
      rp_ah_retenciones IN OUT ah_retenciones%ROWTYPE
   );

    FUNCTION lf_obt_hor_max_movimiento
    (
       p_fecha       in date,
       p_hora3        in varchar2,
       p_cod_usuario in varchar2
    ) return varchar2 is
    v_hora ge_movimientos.hora%type;
    pragma autonomous_transaction;
    BEGIN
       BEGIN
          SELECT max(v.hora)
            INTO v_hora
            FROM ge_movimientos v
           WHERE (v.fecha, v.referencia, v.cod_usuario) in
                 (SELECT g.fecha, g.referencia, g.cod_usuario
                    FROM ge_movimientos g
                   WHERE G.fecha = p_fecha
                     AND G.hora =  p_hora3
                     AND G.cod_usuario = p_cod_usuario
                     AND g.referencia = v.referencia
                     AND G.referencia IS NOT NULL)
             and v.reversado = 'N'
          group by v.fecha, v.referencia, v.cod_usuario;
       EXCEPTION
          WHEN OTHERS THEN
             v_hora := null;
       END;
       return v_hora;
    END;
   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE
   ) IS
      CURSOR cur_modulos IS
         SELECT fecha,
                hora,
                cod_usuario,
                nro_secuencia,
                fec_valor,
                monto,
                nro_cuenta,
                cod_moneda,
                cod_oficina,
                cod_error,
                cod_retencion,
                fec_fin_retencion,
                est_cuenta,
                estado,
                cod_causa,
                cod_banco,
                cod_ofi_origen,
                concepto,
                cod_tasa,
                val_tasa,
                cod_rubro,
                cod_ref_cambio,
                reversado,
                cod_usu_reversion,
                hor_reversion,
                emi_aviso,
                cod_tra_padre,
                cod_mod_padre,
                cod_mad_padre,
                cod_transaccion,
                cod_modulo,
                cod_modalidad,
                mto_equ_local,
                nro_caja,
                cotizacion,
                cod_bco_central,
                nro_documento,
                nro_documento2,
                nro_documento3,
                nro_documento4,
                protegido,
                cod_autorizacion,
                cod_usu_autorizador,
                usu_insercion,
                fec_insercion,
                usu_modificacion,
                fec_modificacion,
                tip_mov_rubro,
                cod_tip_ope_cambio,
                referencia,
                cod_persona,
                cod_sit_contable,
                nro_conciliacion
           FROM gv_movimientos
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND reversado = 'N'
            AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
          ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC; -- DYDMR-4088 Julio/2016
      v_cob_pre_che_otbco varchar2(1) := 'N';
      CURSOR cur_mod_lote IS
         SELECT fecha,
                hora,
                cod_usuario,
                nro_secuencia,
                fec_valor,
                monto,
                nro_cuenta,
                cod_moneda,
                cod_oficina,
                cod_error,
                cod_retencion,
                fec_fin_retencion,
                est_cuenta,
                estado,
                cod_causa,
                cod_banco,
                cod_ofi_origen,
                concepto,
                cod_tasa,
                val_tasa,
                cod_rubro,
                cod_ref_cambio,
                reversado,
                cod_usu_reversion,
                hor_reversion,
                emi_aviso,
                cod_tra_padre,
                cod_mod_padre,
                cod_mad_padre,
                cod_transaccion,
                cod_modulo,
                cod_modalidad,
                mto_equ_local,
                nro_caja,
                cotizacion,
                cod_bco_central,
                nro_documento,
                nro_documento2,
                nro_documento3,
                nro_documento4,
                protegido,
                cod_autorizacion,
                cod_usu_autorizador,
                usu_insercion,
                fec_insercion,
                usu_modificacion,
                fec_modificacion,
                tip_mov_rubro,
                cod_tip_ope_cambio,
                referencia,
                cod_persona,
                cod_sit_contable,
                nro_conciliacion
           FROM gv_movimientos
          WHERE fecha = p_fecha
            AND nro_documento2 = p_nro_lote
            AND cod_usuario = p_cod_usuario
            AND reversado = 'N'
          ORDER BY nro_secuencia DESC;
      v_control VARCHAR2(1) := NULL;
   BEGIN
     --REVERSIONES DE MOVIMIENTO HISTORICO POR NRO DE LOTE(TOTAL) -->pago de sueldos/aguinaldo/credito/comision
     IF p_cod_tra_padre in (304,1304,1305,1306) and p_cod_transaccion = 503  and p_nro_lote is not null THEN
          FOR c1o IN cur_mod_lote LOOP
         --- Procesar reversion
         IF v_control IS NULL THEN
            v_control := 'S';
         END IF;
         IF  c1o.cod_tra_padre not in (186,986) THEN -- no incluye TA
             lp_ins_movimientos(c1o, p_cod_usu_reversion, p_hor_reversion);
         END IF;
         --- Actualiza Historicos (304,1304,1305,1306)
          IF v_ope_pendiente = 'N' THEN
            UPDATE ah_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND nro_documento2 = p_nro_lote
               AND cod_usuario = p_cod_usuario
               AND reversado = 'N'
               AND cod_tra_padre in (304,1304,1305,1306);


               UPDATE ta_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND nro_documento2 = p_nro_lote
               AND cod_usuario = p_cod_usuario
               AND nvl(reversado,'N') = 'N';

           END IF;
         --- Actualizar Historicos
         --AHORRO
         IF c1o.cod_modulo = 3 THEN
            UPDATE ah_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND nro_documento2 = p_nro_lote
               AND cod_usuario = p_cod_usuario
               AND reversado = 'N';

         END IF;

         END LOOP;
--REVERSION DE MOVIMIENTO HISTORICO INDIVIDUAL -->pago de sueldos/aguinaldo/credito/comision
     ELSE

      FOR c1 IN cur_modulos LOOP
         --- Procesar reversion
         IF v_control IS NULL THEN
            v_control := 'S';
         END IF;
         If c1.cod_transaccion = 515 and c1.cod_mod_padre = 6 Then --CRO-HO-CROCPCCB-27/08/15 se asigna valor a la variable
               v_mto_credito := c1.monto;
         else
            --- Procesar reversion
            lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
        End IF;

           IF v_ope_pendiente = 'N' THEN
                  UPDATE ah_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND reversado = 'N'
               AND (cod_transaccion NOT IN (941, 661) OR cod_transaccion IS NULL);
               -- Tarjetas His.
                 UPDATE ta_movimientos_his
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha = p_fecha
                   AND nro_documento2 = p_nro_lote
                   AND cod_usuario = p_cod_usuario
                   and nro_cuenta = (select t.nro_cuenta from ta_cta_tarjetas t
                                       where t.nro_cta_debito= c1.nro_cuenta)
                   AND nvl(reversado,'N') = 'N';
          END IF;
         --REVERSIONES DE MOVIMIENTO INDIVIDUAL -->PAGO SUELDOS/AGUINALDO...DESDE
           if p_nro_lote is not null and p_cod_tra_padre in (304,1304,1305,1306) then
         --busca cuenta de debito(ente) para actualizar monto pago de sueldos
               begin
                   select monto, nro_cuenta,cod_ente,cod_moneda
                   into v_monto, v_nro_cuenta,v_cod_ente, v_cod_moneda_sue
                   from ge_pag_sueldos
                   where nro_lote=p_nro_lote
                   and tipo='D';
               exception
                 when others then
                   raise_application_error(-20002, 'No puede actualizar la cuenta de debito');
               end;
            --Obtener el monto de reversion individual de la cuenta credito
               begin
                 select monto
                 into v_monto_cre
                 from ah_movimientos_his
                  where nro_cuenta= p_nro_ncredito
                  and cod_tra_padre in (304,1304,1305,1306)
                  and cod_transaccion = 602
                   and nro_documento2=p_nro_lote
                    and cod_mad_padre =p_cod_mad_padre
                    and cod_mod_padre = p_cod_mod_padre
                   and reversado='S'
                   and monto > 0;
               exception
                 when others then
                   raise_application_error(-20002, 'No puede obtener el monto de reversión');
               end;
              if v_nro_cuenta is not null and p_cod_tra_padre in (304,1304,1305,1306)  then
               UPDATE ge_pag_sueldos
               SET monto= (v_monto - v_monto_cre)--v_monto_cre se resta al monto total
               WHERE nro_lote=p_nro_lote
               and nro_cuenta= v_nro_cuenta
               and monto = v_monto
               and tipo='D';
               v_max_sec_use_fgdiari := fug_obt_nro_sec_sueldo(p_nro_lote,p_cod_usu_reversion);--obtener nro secuencia +1
               v_cdofior := fug_obt_ofi_usuario(p_cod_usu_reversion);--obtener oficina nro cuenta
               v_cnmovim := fug_obt_concepto_his(v_nro_cuenta,p_nro_lote,p_cod_mad_padre,p_cod_mod_padre,p_cod_tra_padre);
             --actualiza acreditacion a cuenta debito(del ente)
               PAG_CTA.PR_ACT_OPERACION(v_nro_cuenta,
                              p_hor_reversion,
                              'C',
                              v_cod_moneda_sue,
                              v_monto_cre,
                              p_cod_tra_padre,
                              602,
                              v_cod_ente,
                              NULL,
                              v_cdofior,
                              p_cod_mod_padre,
                              p_cod_mad_padre,
                              NULL,
                              NULL,
                             v_cnmovim,
                              'S',
                               v_max_sec_use_fgdiari,
                               p_fecha);
          --actualiza nro_documento2 para cuenta acreditada(ente) luego de la reversion individual
                      UPDATE GE_MOVIMIENTOS
                           SET nro_documento2 = p_nro_lote
                         WHERE nro_cuenta = v_nro_cuenta
                           and hora = p_hor_reversion
                           and cod_tra_padre in (304,1304,1305,1306)
                           and nro_documento = v_cod_ente
                           and cod_mod_padre = p_cod_mod_padre
                           and cod_mad_padre = p_cod_mad_padre
                           and cod_transaccion=602
                           and fec_valor = p_fecha;
                  end if;
            end if;
              if v_nro_cuenta is not null and p_cod_tra_padre in (304,1304,1305,1306) and p_nro_lote is not null  then
            --consulta monto=0 cuando la reversion es individual
             begin
                   select monto,nro_cuenta
                   into v_monto,v_cuenta_ente
                   from ge_pag_sueldos
                   where nro_lote=p_nro_lote
                   and tipo='D';
               end;
            --si v_monto=0 se reversa los cargos generados al ente en el procesamiento de pago
             if p_cod_tra_padre in (304,1304,1305,1306) and v_monto=0 then
              FOR c1s IN cur_gmovi_car LOOP
                lp_ins_movimientos(c1s, p_cod_usu_reversion, p_hor_reversion, 'N');
              END LOOP;
              end if;
             --Reversa de lote completo de forma individual, si el monto =0
                if v_monto = 0 then
                 UPDATE ah_movimientos_his
                 SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
                   WHERE fec_valor = p_fecha
                     AND nro_documento2 = p_nro_lote
                     AND cod_usuario = p_cod_usuario
                     AND reversado = 'N'
                     AND cod_tra_padre in (304,1304,1305,1306);
                 end if;
          --Borra los registros de ge_pag_sueldos al reversar cuando el monto=0 luego de reversion individual
          if v_monto = 0 and p_cod_mad_padre=31 and p_cod_tra_padre in (304,1304,1305,1306) then
           delete ge_pag_sueldos where nro_lote=p_nro_lote
           and nro_cuenta= v_nro_cuenta and procesado='S';
          end if;
          end if;
         --- Actualizar Historicos
         --AHORRO
         IF c1.cod_modulo = 3 THEN
            UPDATE ah_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- CUENTA CORRIENTE
         ELSIF c1.cod_modulo = 4 THEN
            UPDATE cc_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- TARJETA
         ELSIF c1.cod_modulo = 5 THEN
            --NO EXISTE
            UPDATE ta_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- PRESTAMO
         ELSIF c1.cod_modulo = 6 THEN
            /*CRO-HO-CROCPCCB-16/09/15: Cuando el cobro se realizo con chque cargo otros bancos,
              No se puede reversar la liberación del Cheque.-*/
            If c1.cod_tra_padre = 515 Then
               v_cob_pre_che_otbco := 'S';

            Elsif v_cob_pre_che_otbco = 'S' then
                UPDATE pr_movimientos_his
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha             = p_fecha
                   AND hora              = p_hora
                   AND cod_usuario       = p_cod_usuario
                   AND nro_documento     = c1.nro_documento
                   and nro_secuencia     = c1.nro_secuencia
                   AND reversado         = 'N';
            Else
                UPDATE pr_movimientos_his
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha = p_fecha
                   AND hora = p_hora
                   AND cod_usuario = p_cod_usuario
                   AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
                   AND reversado = 'N';
            End If;
            --  CAMBIOS
         ELSIF c1.cod_modulo = 7 THEN
            UPDATE lc_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- COMERCIO EXTERIOR
         ELSIF c1.cod_modulo = 8 THEN
            UPDATE cx_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- MESA DE DINERO
         ELSIF c1.cod_modulo = 10 THEN
            UPDATE md_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
         ELSIF c1.cod_modulo = 13 THEN
            UPDATE af_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
         --ELSIF (c1.cod_modulo = 28 OR (c1.cod_mod_padre = 28 AND c1.cod_modulo IS NULL)) THEN
         ELSIF (nvl(c1.cod_modulo, 15) IN (15, 16, 28) OR
                (c1.cod_modulo = 9 AND c1.cod_mod_padre IN (15, 16, 9, 28))) then
            UPDATE ov_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
         END IF;
         -- BSEVOCORE-40 Reversion de Exoneraciones de Prestamos
         lp_eli_exoneraciones( p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, c1.cod_autorizacion, 'H');
      END LOOP;
      END IF;
      IF v_gen_estado = 'S' THEN
         --Genera reversion de cambio de estado para DESCUENTO DE CHEQUES.
         lp_ins_movimientos(r_mov_cam_est, p_cod_usu_reversion, p_hor_reversion, 'N');
      END IF;
   END;
   /* Busca en los historicos los movimientos a reversar. */
   PROCEDURE lp_bus_dat_histo_par
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE
   ) IS
      CURSOR cur_modulos IS
         SELECT fecha,
                hora,
                cod_usuario,
                nro_secuencia,
                fec_valor,
                monto,
                nro_cuenta,
                cod_moneda,
                cod_oficina,
                cod_error,
                cod_retencion,
                fec_fin_retencion,
                est_cuenta,
                estado,
                cod_causa,
                cod_banco,
                cod_ofi_origen,
                concepto,
                cod_tasa,
                val_tasa,
                cod_rubro,
                cod_ref_cambio,
                reversado,
                cod_usu_reversion,
                hor_reversion,
                emi_aviso,
                cod_tra_padre,
                cod_mod_padre,
                cod_mad_padre,
                cod_transaccion,
                cod_modulo,
                cod_modalidad,
                mto_equ_local,
                nro_caja,
                cotizacion,
                cod_bco_central,
                nro_documento,
                nro_documento2,
                nro_documento3,
                nro_documento4,
                protegido,
                cod_autorizacion,
                cod_usu_autorizador,
                usu_insercion,
                fec_insercion,
                usu_modificacion,
                fec_modificacion,
                tip_mov_rubro,
                cod_tip_ope_cambio,
                referencia,
                cod_persona,
                cod_sit_contable,
                nro_conciliacion
           FROM gv_movimientos_par
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND reversado = 'N'
            AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
          ORDER BY CASE WHEN v_mov_orden = 'DESC' THEN nro_secuencia END DESC,
         CASE WHEN v_mov_orden <> 'DESC' THEN nro_secuencia END ASC; -- DYDMR-4088 Julio/2016
      v_cob_pre_che_otbco varchar2(1) := 'N';
   BEGIN

      --SETEA LOS PARÁMETROS PARA LA VISTA
       PAG_PAR.PR_SET_REV_COD_USUARIO(p_cod_usuario);
       PAG_PAR.PR_SET_REV_FECHA(p_fecha);
       PAG_PAR.PR_SET_REV_HORA(p_hora);
       PAG_PAR.PR_SET_REV_REVERSADO('N');

      FOR c1 IN cur_modulos LOOP
         If c1.cod_transaccion = 515 and c1.cod_mod_padre = 6 Then --CRO-HO-CROCPCCB-27/08/15 se asigna valor a la variable
               v_mto_credito := c1.monto;
         Else
            --- Procesar reversion
            lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
         End IF;
         --- Actualizar Historicos
         --AHORRO
         IF c1.cod_modulo = 3 THEN
            UPDATE ah_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- CUENTA CORRIENTE
         ELSIF c1.cod_modulo = 4 THEN
            UPDATE cc_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- TARJETA
         ELSIF c1.cod_modulo = 5 THEN
            --NO EXISTE
            UPDATE ta_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- PRESTAMO
         ELSIF c1.cod_modulo = 6 THEN
            /*CRO-HO-CROCPCCB-16/09/15: Cuando el cobro se realizo con chque cargo otros bancos,
              No se puede reversar la liberación del Cheque.-*/
            If c1.cod_tra_padre = 515 Then
               v_cob_pre_che_otbco := 'S';

            Elsif v_cob_pre_che_otbco = 'S' then
                UPDATE pr_movimientos_his
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha             = p_fecha
                   AND hora              = p_hora
                   AND cod_usuario       = p_cod_usuario
                   AND nro_documento     = c1.nro_documento
                   and nro_secuencia     = c1.nro_secuencia
                   AND reversado         = 'N';
            Else
                UPDATE pr_movimientos_his
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha = p_fecha
                   AND hora = p_hora
                   AND cod_usuario = p_cod_usuario
                   AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
                   AND reversado = 'N';
            End If;
            --  CAMBIOS
         ELSIF c1.cod_modulo = 7 THEN
            UPDATE lc_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- COMERCIO EXTERIOR
         ELSIF c1.cod_modulo = 8 THEN
            UPDATE cx_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
            -- MESA DE DINERO
         ELSIF c1.cod_modulo = 10 THEN
            UPDATE md_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
         ELSIF c1.cod_modulo = 13 THEN
            UPDATE af_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
         --ELSIF (c1.cod_modulo = 28 OR (c1.cod_mod_padre = 28 AND c1.cod_modulo IS NULL)) THEN
         ELSIF (nvl(c1.cod_modulo, 15) IN (15, 16, 28) OR
                (c1.cod_modulo = 9 AND c1.cod_mod_padre IN (15, 16, 9, 28))) then
            UPDATE ov_movimientos_his
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
               AND reversado = 'N';
         END IF;
         -- BSEVOCORE-40 Reversion de Exoneraciones de Prestamos
         lp_eli_exoneraciones( p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, c1.cod_autorizacion, 'H');
      END LOOP;
      IF v_gen_estado = 'S' THEN
         --Genera reversion de cambio de estado para DESCUENTO DE CHEQUES.
         lp_ins_movimientos(r_mov_cam_est, p_cod_usu_reversion, p_hor_reversion, 'N');
      END IF;
   END;
   /* Validar que no permita reversar operaciones de IVA */
   PROCEDURE lp_val_iva(rp_gmovi IN ge_movimientos%ROWTYPE) IS
      v_existe VARCHAR2(01) := 'N';
   BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ge_transacciones t, ge_gru_transacciones_det g
       WHERE g.cod_gru_transaccion = v_cod_gru_iva
         AND t.cod_modulo = g.cod_modulo
         AND t.cod_modalidad = g.cod_modalidad
         AND t.cod_transaccion = g.cod_transaccion
         AND t.cod_modulo = rp_gmovi.cod_modulo
         AND t.cod_modalidad = rp_gmovi.cod_modalidad
         AND t.cod_transaccion = rp_gmovi.cod_transaccion;
      IF v_existe = 'S' THEN
         raise_application_error(-20001, 'No puede reversar operaciones con IVA de fechas pasadas');
      END IF;
   EXCEPTION
      WHEN no_data_found THEN
         NULL;
      WHEN too_many_rows THEN
         raise_application_error(-20002, 'No puede reversar operaciones con IVA de fechas pasadas');
   END;
      -- Valida si existen movimientos de distribución de gastos por seguro de vida y realiza la reversión

   PROCEDURE lp_ver_rev_car_seguro(p_fecha ge_movimientos.fecha%type, p_referencia ge_movimientos.referencia%type,  p_nro_documento3 ge_movimientos.nro_documento3%type ) IS
         v_can_seguro NUMBER(8);
         v_hor_dis_car GE_MOVIMIENTOS.HORA%TYPE;
         v_usu_dis_car GE_MOVIMIENTOS.COD_USUARIO%TYPE;
         v_cod_mod_padre GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE;
         v_cod_mad_padre GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
         v_cod_tra_padre GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE;
         v_fec_implementacion GE_MOVIMIENTOS.FECHA%TYPE := to_date(fug_obt_pardinamico('FEC_IMP_REV_COB_SEG_CUO'), 'DD/MM/YYYY');

      BEGIN
        BEGIN
         SELECT hora, cod_usuario, cod_mod_padre, cod_mad_padre, cod_tra_padre
           INTO v_hor_dis_car, v_usu_dis_car, v_cod_mod_padre, v_cod_mad_padre, v_cod_tra_padre
           FROM gv_movimientos
          WHERE referencia = p_referencia
            and nro_documento3 = p_nro_documento3
            and cod_mod_padre = 6
            and cod_tra_padre in (370, 366)
            and fecha = p_fecha
            AND reversado = 'N'
            AND monto > 0
            AND rownum = 1;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_hor_dis_car := null;
            WHEN OTHERS THEN
              raise_application_error(-20001, 'Error al obterner los Movimientos de Cobro de Cargos de Seguros en cuotas. '||sqlerrm);
         END;
         -- Si v_hor_dis_car is not null, posee cargos distribuidos y debe reversar los mismos
         if v_hor_dis_car is not null and p_fecha >= v_fec_implementacion then

            v_hor_reversion := fug_obt_hor_disponible(p_fecha,p_hor_reversion,p_cod_usu_reversion,'N');

            PRG_REV_OPERACION(p_fecha,
                              v_hor_dis_car,
                              v_usu_dis_car,
                              v_cod_mod_padre,
                              v_cod_mad_padre,
                              v_cod_tra_padre,
                              p_cod_usu_reversion,
                              v_hor_reversion,
                              'N',
                              p_concepto);
        end if;
   END;


   /* Crea los movimientos para insertarlos en GE_MOVIMIENTOS. */
   PROCEDURE lp_ins_movimientos
   (
      rp_gmovi            IN ge_movimientos%ROWTYPE,
      p_cod_usu_reversion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_es_nocturno       IN VARCHAR2 := 'X'
   ) IS

      r_gmovi           ge_movimientos%ROWTYPE;
      v_est_anterior    VARCHAR2(1) := NULL;
      v_fec_cam_est_ant DATE := NULL;
      v_fec_ult_mov_ant DATE := NULL;
      v_hor_ult_mov_ant VARCHAR2(8) := NULL;
      v_fec_ult_cap_ant DATE := NULL; /*DYDMR-4896 Se agrega para actualizar el campo fec_ult_capitalizacion en tabla maestra (ALV-SET/2016)*/
      -- DATOS DE LA REVERSION DE LA CUENTA
      v_afecta             ge_transacciones.afecta%TYPE := 'N';
      v_afe_sal_total      NUMBER := 0;
      v_afe_sal_retenido   NUMBER := 0;
      v_afe_sal_bloqueado  NUMBER := 0;
      v_act_ult_movimiento VARCHAR2(1) := 'N';
      v_tip_movimiento     ge_transacciones.tipo%TYPE;
      r_docu               md_cta_documentos%ROWTYPE;
      -- PRESTAMOS
      -- Variables para reversion de préstamos
      v_capital        pr_cuotas.sal_capital%TYPE;
      v_interes        pr_cuotas.sal_interes%TYPE;
      v_int_adelantado pr_cuotas.sal_int_documentado%TYPE;
      v_devengado      pr_cta_prestamos.dev_acumulado%TYPE;
      v_dev_no_cobrado pr_cta_prestamos.dev_no_cobrado%TYPE;
      v_dev_suspenso   pr_cta_prestamos.dev_no_cobrado%TYPE;

      v_cu_dev_acumulado  pr_cta_prestamos.dev_acumulado%TYPE;
      v_mto_dev_actual    pr_cta_prestamos.dev_acumulado%TYPE;
      v_cu_dev_no_cobrado pr_cta_prestamos.dev_no_cobrado%TYPE;
      v_cu_dev_suspenso   pr_cta_prestamos.dev_no_cobrado%TYPE;

      v_val_recargo       pr_cuotas.val_recargo%TYPE;
      v_sal_recargo       pr_cuotas.val_recargo%TYPE;
      v_int_descontado    pr_cuotas.mto_int_descontado%TYPE;
      v_cap_adelantado    pr_cuotas.mto_cap_adelantado%TYPE;
      v_fec_ult_pago      pr_cuotas.fec_ult_pago%TYPE;
      v_estado            pr_cuotas.estado%TYPE;
      v_est_cuenta        pr_cta_prestamos.estado%TYPE;
      r_pcpre             pr_cta_prestamos%ROWTYPE;
      v_nro_cuo_desde     pr_cuotas.nro_cuota%TYPE;
      v_nro_cuo_hasta     pr_cuotas.nro_cuota%TYPE;
      v_fec_ult_devengado pr_cta_prestamos.fec_ult_devengado%TYPE;
      v_nro_solicitud     pr_cta_prestamos.nro_solicitud%TYPE;
      v_nro_sol_prestamo  cc_lib_ant_cheques.nro_sol_prestamo%TYPE;
      v_est_liberacion    cc_lib_ant_cheques.estado%TYPE;
      v_categoria         ge_clientes.cat_automatica%TYPE;
      v_tip_devengado     VARCHAR2(01);
      v_capital_deven pr_devengados.capital%TYPE;
      v_mto_cap_cuota pr_cuotas.mto_capital%TYPE;
      v_mto_int_docum pr_cuotas.mto_int_documentado%TYPE;
      v_redondeo      NUMBER(2);
      v_est_cuo_cobro pr_cuotas.estado%TYPE;

      -- Variables para reversar cheques
      v_msj_cheque VARCHAR2(1000);
      v_tip_importe cc_sal_camara.tip_importe%type;
      -- Variables para reversar gastos varios
      v_mto_gas_original NUMBER(18, 2);
      v_nro_linea        pr_cta_prestamos.nro_linea%TYPE;
      v_nro_cta_cliente  VARCHAR2(30);
      --variables para reversar servicios: cobro y remisión
      v_remision    VARCHAR2(1) := NULL;
      v_pri_vez     VARCHAR2(1) := 'S';
      v_proveedor   ge_entes.cod_ente%TYPE;
      v_fec_proceso DATE;
      v_tipo        ge_entes.tipo%TYPE;
      --comex
      v_nro_sol_cci   pr_solicitudes.nro_solicitud%TYPE;
      v_nro_cta_cci   pr_cta_prestamos.nro_cuenta%TYPE;
      v_est_solicitud pr_solicitudes.estado%TYPE;
      v_ult_embarque  NUMBER;
      v_pagado        VARCHAR2(1) := NULL;
      -- variables para reversar operaciones vencidas
      r_vcven            ov_cta_vencidas%ROWTYPE;
      v_con_garantia_ven NUMBER(5) := 0;
      --Para controlar firmantes de Cheques--
      v_can_che_devueltos  number;
      r_tacobros_gp        ta_cobros_gp%ROWTYPE;
      v_cod_procesadora    ta_tipos.cod_ent_procesadora%TYPE;
      v_pag_lin_habilitado ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('TA_PAG_LINEA');
      v_liberado           ah_retenciones.liberado%type := 'N';
      v_cod_usuario        ba_usuarios.cod_usuario%type := upper(user);  --usuario
      v_hor_actual         varchar2(08) := to_char(sysdate,'HH24:MI:SS');   -- Hora actual

      /*cursor custodias is select c.cod_val_custodia,
                          c.nro_cuota,
                          c.nro_valor,
                          b.val_maximo
                     from cv_val_custodias c,
                          ba_cod_referencias b
                    where c.nro_operacion = rp_gmovi.nro_cuenta
                      and c.estado = b.val_minimo
                      and b.dominio = 'EST_VALORES';*/

      -- Cursor de cuotas a re-estructurar
      CURSOR c_cobros IS
         SELECT *
           FROM pr_cobros
          WHERE nro_cuenta = rp_gmovi.nro_cuenta
            AND nro_cuota >= v_nro_cuo_desde
            AND nro_cuota <= v_nro_cuo_hasta
          ORDER BY nro_cuota;
      --Cursor de documentos relacionados
      CURSOR documentos IS
         SELECT * FROM md_cta_documentos WHERE nro_cta_padre = rp_gmovi.nro_cuenta;







      /* obtiene datos de la transaccion */
      PROCEDURE pr_obt_tip_transaccion
      (
         p_cod_transaccion IN ge_transacciones.cod_transaccion%TYPE,
         p_cod_modulo      IN ge_transacciones.cod_modulo%TYPE,
         p_cod_modalidad   IN ge_transacciones.cod_modalidad%TYPE,
         p_tipo            OUT VARCHAR2,
         p_afecta          OUT VARCHAR2
      ) IS
      BEGIN
         SELECT tipo, afecta
           INTO p_tipo, p_afecta
           FROM ge_transacciones
          WHERE cod_modulo = p_cod_modulo
            AND cod_modalidad = p_cod_modalidad
            AND cod_transaccion = p_cod_transaccion;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20004,
                                    'Transaccion inexistente ' || to_char(nvl(p_cod_modulo, 0)) || '-' ||
                                     to_char(nvl(p_cod_modalidad, 0)) || '-' ||
                                     to_char(p_cod_transaccion));
         WHEN OTHERS THEN
            raise_application_error(-20005, SQLERRM);
      END;
      --- Obtiene el rubro de reversion
      FUNCTION fl_obt_rub_reversion(p_cod_rubro IN VARCHAR2) RETURN VARCHAR2 IS
         v_rub cb_rubros.cod_rubro%TYPE;
      BEGIN
         BEGIN
            SELECT cod_rub_reversion
              INTO v_rub
              FROM cb_rub_reversiones
             WHERE cod_rubro = p_cod_rubro;
         EXCEPTION
            WHEN OTHERS THEN
               v_rub := NULL;
         END;
         RETURN v_rub;
      END;
      /* Obtiene datos del ultimo cambio de estado para la transacción DESCUENTO DE CHEQUES,
         este cambio de estado se generará cuando se desee reversar alguna cuota que no haya sido la ultima.
      */
      PROCEDURE pr_gen_cam_estado(r_movest ge_movimientos%ROWTYPE) IS
         v_nro_cuenta pr_cta_prestamos.nro_cuenta%TYPE;
      BEGIN
         /*
           Si es DESCUENTO DE CHEQUE, las cuotas se pueden reversar en cualquier orden,
           si el préstamo ya está CANCELADO y la cuota a reversar no es la última, entonces
           hay que generar un registro en GE_MOVIMIENTOS reversando también el cambio de
           estado de dicho préstamo, para ello averiguo si dentro del grupo de registros
           a ser reversardo NO EXISTE ya un cambio de estado para así poder generarla,
           para cualquier otro caso no se genera nada.
         */
         --Se Obtiene el nro de cuenta si es necesario
         v_nro_cuenta := nvl(r_movest.nro_cuenta,
                             fui_obt_mov_cuenta(r_movest.fecha, r_movest.hora, r_movest.cod_usuario));
         IF nvl(fup_obt_tip_descuento(r_movest.cod_modalidad), 'x') = 'C' THEN
            DECLARE
               CURSOR c_cur_est IS
                  SELECT fecha,
                         hora,
                         cod_usuario,
                         nro_secuencia,
                         fec_valor,
                         monto,
                         nro_cuenta,
                         cod_moneda,
                         cod_oficina,
                         cod_error,
                         cod_retencion,
                         fec_fin_retencion,
                         est_cuenta,
                         estado,
                         cod_causa,
                         cod_banco,
                         cod_ofi_origen,
                         concepto,
                         cod_tasa,
                         val_tasa,
                         cod_rubro,
                         cod_ref_cambio,
                         reversado,
                         cod_usu_reversion,
                         hor_reversion,
                         emi_aviso,
                         cod_tra_padre,
                         cod_mod_padre,
                         cod_mad_padre,
                         cod_transaccion,
                         cod_modulo,
                         cod_modalidad,
                         mto_equ_local,
                         nro_caja,
                         cotizacion,
                         cod_bco_central,
                         nro_documento,
                         nro_documento2,
                         nro_documento3,
                         nro_documento4,
                         protegido,
                         cod_autorizacion,
                         cod_usu_autorizador,
                         usu_insercion,
                         fec_insercion,
                         usu_modificacion,
                         fec_modificacion,
                         tip_mov_rubro,
                         cod_tip_ope_cambio,
                         referencia,
                         cod_persona,
                         cod_sit_contable,
                         nro_conciliacion
                    FROM gv_movimientos
                   WHERE nro_cuenta = v_nro_cuenta
                     AND ((fec_valor > r_movest.fec_valor) OR
                         (fec_valor = r_movest.fec_valor AND hora > r_movest.hora))
                     AND reversado = 'N'
                     AND nvl(cod_tip_movimiento, 'x') = 'E' -- si hubo otro cambio de estado posterior
                     AND est_cuenta IS NOT NULL
                   ORDER BY fec_insercion DESC;
            BEGIN
               --Recupera el Ultimo cambio de estado que canceló la cuenta.
               r_mov_cam_est := NULL;
               v_gen_estado  := 'N';
               FOR ce IN c_cur_est LOOP
                  IF ce.fecha = r_movest.fecha AND ce.hora = r_movest.hora AND
                     ce.cod_usuario = r_movest.cod_usuario THEN
                     /*El cambio de estado esta dentro del grupo que se quiere reversar
                       por tanto ya no es necesario que se genere otro cambio de estado
                     */
                     v_gen_estado := 'X';
                     EXIT;
                  END IF;
                  --
                  --Genera el nuevo registro de cambio de estado con el sgte. segundo
                  --para volver a cambiar el estado de la cuenta.
                  r_mov_cam_est               := ce;
                  r_mov_cam_est.nro_secuencia := 1;
                  r_mov_cam_est.est_cuenta    := r_movest.est_cuenta;
                  r_mov_cam_est.concepto      := substr('Cambio de estado de la Cuota ' ||
                                                        to_char(ce.nro_documento3) || ' . Fec.: ' ||
                                                        to_char(ce.fecha, 'DD/MM/YYYY') ||
                                                        ' Hora: ' || ce.hora || ' Usuario: ' ||
                                                        ce.cod_usuario, 1, 100);
                  --
                  v_gen_estado := 'S';
                  EXIT;
               END LOOP;
            EXCEPTION
               WHEN no_data_found THEN
                  v_gen_estado  := 'N';
                  r_mov_cam_est := NULL;
               WHEN OTHERS THEN
                  v_gen_estado  := 'N';
                  r_mov_cam_est := NULL;
                  raise_application_error(-20001,
                                          'Error al buscar el estado de la cuenta ' || v_nro_cuenta ||
                                           ' para intentar reversarla. ' || SQLERRM);
            END;
         END IF;
      END pr_gen_cam_estado;

      PROCEDURE lp_env_mov_cob_pen(p_nro_cuenta ge_movimientos.nro_cuenta%type, p_monto ge_movimientos.monto%type, p_concepto ge_movimientos.concepto%type, p_cod_moneda ge_movimientos.cod_moneda%type)
      IS
         c_dir_mail        ba_personas.dir_correo%type  := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');
         v_para     VARCHAR2(4000);
         -- Variables para mail
         v_conn     utl_smtp.connection;
         v_asunto   VARCHAR2(2000);
         v_texto LONG;
         v_hin_mail ge_ra_log_mail.hor_inicio%type;
         v_hfi_mail ge_ra_log_mail.hor_fin%type;
         v_det_error ge_ra_log_mail.det_error%type;
         v_nom_cliente ba_personas.nom_completo%type;

      BEGIN
         BEGIN
           SELECT p.cod_persona ||'-'|| nom_completo
             INTO v_nom_cliente
             FROM ge_cta_clientes c, ba_personas p
            WHERE c.nro_cuenta = p_nro_cuenta
              AND c.relacion = 'P'
              AND c.cod_persona = p.cod_persona;
         EXCEPTION
           when others then
              v_nom_cliente := null;
         END;

         v_texto := '<br><br>
                     <b><i>Cobro de Tarjeta Pendiente Reversado por el Proceso de Cierre del Dia</b></i>
                     <br><br>
                     <p>El Proceso de Cierre del Dia ha procedido a la Reversión de un Cobro de TC encontrado como estado P-Pendiente, el mismo ya fue enviado a la Procesadora.</p>
                     <p>Proceder a las regularizaciones correspondientes.</p>
                     <br><br>
                     <i><b>Datos:</b></i>
                     <p>Cuenta: '||p_nro_cuenta||'</p>
                     <p>Nro tarjeta: *****'||substr(p_concepto, -4)||'</p>
                     <p>Cliente: '||v_nom_cliente||'</p>
                     <p>Monto: '||to_char(p_monto,'999,999,999,999.99')||' '||p_cod_moneda||'.</p>';


          v_asunto   := 'Reversion de Cobro TDC pendiente';

          BEGIN
            v_hin_mail := to_char(sysdate, 'hh24:mi:ss');

            v_para := fug_obt_pardinamico('ENV_REV_COB_TAR_PEN');

            v_conn     := it_mail.begin_mail(c_dir_mail,
                                             v_para,
                                             v_asunto,
                                             IT_MAIL.MULTIPART_MIME_TYPE);


            it_mail.attach_text(v_conn, v_texto, 'text/html');


            it_mail.end_mail(v_conn);

            v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');

          EXCEPTION
            when others then
              v_det_error := substr(sqlerrm, 1, 4000);

              INSERT INTO ge_ra_log_mail
                          (fec_envio,
                           nom_archivo,
                           dir_correo,
                           mensaje,
                           det_error,
                           hor_inicio,
                           hor_fin)
                   VALUES (SYSDATE,
                           null,
                           v_para,
                           v_asunto,
                           v_det_error,
                           v_hin_mail,
                           v_hfi_mail);


          END;
      END lp_env_mov_cob_pen;
      ---
      PROCEDURE lp_val_mov_especial IS
         v_cod_gru_transaccion ge_gru_transacciones_det.cod_gru_transaccion%TYPE := fug_obt_pardinamico('COD_GRU_ENV_DEBCRE');
         v_existe              VARCHAR2(1) := 'N';
         /*
         || Verifica si la operación a reversar corresponde a un movimiento especial.
         || Si ya fue enviado a Bancard, entonces no permite su reversión.
         || XPY0038 - 28/03/2014 - MP-2383-AUT_MOV_INTERESES
         */
      BEGIN
         BEGIN
            SELECT 'S'
              INTO v_existe
              FROM ta_env_debcre_his a, ge_gru_transacciones_det gru
             WHERE gru.cod_gru_transaccion = v_cod_gru_transaccion
               AND gru.cod_transaccion = rp_gmovi.cod_transaccion
               AND gru.cod_modulo = rp_gmovi.cod_modulo
               AND gru.cod_modalidad = rp_gmovi.cod_modalidad
               AND a.fec_envio = rp_gmovi.fecha
               AND a.nro_cuenta = rp_gmovi.nro_cuenta
               AND a.cod_transaccion = rp_gmovi.cod_transaccion
               AND a.cod_modulo = rp_gmovi.cod_modulo
               AND a.cod_modalidad = rp_gmovi.cod_modalidad
               AND a.monto = rp_gmovi.monto
               AND a.cod_usuario = rp_gmovi.cod_usuario
               AND TRIM(nvl(a.concepto, '')) = TRIM(nvl(rp_gmovi.concepto, ''))
               AND nvl(a.tip_saldo, 0) = nvl(rp_gmovi.nro_documento2, 0)
               AND nvl(a.financia, 0) = nvl(rp_gmovi.nro_documento3, 0);
         EXCEPTION
            WHEN no_data_found THEN
               v_existe := 'N';
            WHEN too_many_rows THEN
               v_existe := 'S';
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Al Obt.Mov.Especial:' || SQLERRM);
         END;
         IF nvl(v_existe, 'N') = 'S' THEN
            raise_application_error(-20000, 'No se puede reversar Mov.Especial de Tarjetas ya enviado.');
         END IF;
      END lp_val_mov_especial;
      ------------------------------------------------------------------------------
   BEGIN

      --> Valida movimientos Especiales de Tarjetas
      lp_val_mov_especial;
      --<

      -- Traspaso los datos del registro leido en el nuevo
      r_gmovi := rp_gmovi;
      --
      r_gmovi.fecha         := nvl(v_fec_actual,r_gmovi.fecha);/*FSOP-20695*/
      r_gmovi.fec_valor     := p_fecha;
      r_gmovi.cod_usuario   := p_cod_usu_reversion;
      r_gmovi.monto         := rp_gmovi.monto * -1;
      r_gmovi.mto_equ_local := rp_gmovi.mto_equ_local * -1;

      -- Para DESCUENTO DE CHEQUES, sólo el cambio de estado generado no debe tener el indicador N, ni los datos de reversion
      IF nvl(fup_obt_tip_descuento(rp_gmovi.cod_modalidad), 'x') = 'C' AND rp_gmovi.monto IS NULL AND
         rp_gmovi.nro_secuencia = 1 AND r_mov_cam_est.fecha IS NOT NULL AND
         r_mov_cam_est.hora IS NOT NULL AND r_mov_cam_est.cod_usuario IS NOT NULL THEN
         --La reversion diaria permite reversar ESTADOS entonces, para que no entre aqui se pregunta si hay algun valor dentro de r_mov_cam_est
         r_gmovi.hora              := pag_gen.fu_obt_sig_segundo(p_hor_reversion);
         r_gmovi.reversado         := 'N';
         r_gmovi.hor_reversion     := NULL;
         r_gmovi.cod_usu_reversion := NULL;
      ELSE
         r_gmovi.hora              := p_hor_reversion;
         r_gmovi.reversado         := 'S';
         r_gmovi.hor_reversion     := rp_gmovi.hora;
         r_gmovi.cod_usu_reversion := rp_gmovi.cod_usuario;
         r_gmovi.concepto          := substr(p_concepto, 1, 100);
      END IF;

      -- Reversion de IVA Facturado
      -- Verificar si el movimiento original fue facturado
      IF pab_iva.fu_mov_facturado(rp_gmovi.fecha, rp_gmovi.hora, rp_gmovi.cod_usuario) THEN
         DECLARE
            v_rub_rev     cb_rubros.cod_rubro%TYPE;
            v_tip_mov_rub ge_movimientos.tip_mov_rubro%TYPE;
         BEGIN
            v_tip_mov_rub := r_gmovi.tip_mov_rubro;
            v_rub_rev     := fl_obt_rub_reversion(nvl(r_gmovi.cod_rubro,
                                                      fub_obt_rub_transaccion(r_gmovi.cod_modulo,
                                                                               r_gmovi.cod_modalidad,
                                                                               r_gmovi.cod_transaccion,
                                                                               r_gmovi.cod_moneda, NULL,
                                                                               NULL, v_tip_mov_rub)));
            IF v_rub_rev IS NOT NULL THEN
               r_gmovi.cod_rubro       := v_rub_rev;
               r_gmovi.tip_mov_rubro   := v_tip_mov_rub;
               r_gmovi.cod_transaccion := NULL;
            END IF;
         END;
      END IF;
      --
      IF r_gmovi.cod_tra_padre NOT IN (101, 102, 358, 359, 360, 362, 364, 139) THEN
         --- 358 desemb.prest. y pase a op.venc., 139 cobros de op.v.
         IF r_gmovi.cod_tra_padre = 59 THEN
          --(1)-control de reversión de alta de cheque de favor (tr.  59)
          lp_rev_che_cust('A',r_gmovi.cod_tra_padre,r_gmovi.cod_mod_padre,r_gmovi.cod_mad_padre, r_gmovi.nro_documento);
         END IF;

         pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         IF r_gmovi.cod_tra_padre IN (59,58) THEN
          --(2)-reversión de bajas y altas de cheque de favor (tr. 58 y tr 59)
          lp_rev_che_cust('B',r_gmovi.cod_tra_padre,r_gmovi.cod_mod_padre,r_gmovi.cod_mad_padre, r_gmovi.nro_documento);
         END IF;

     --reversión pagos de caja de seguridad(Pago de Alquiler/recargo por visitas)
         IF r_gmovi.cod_tra_padre IN (369,to_number(fug_obt_pardinamico('CAJ_SEG_COD_TRA_CUOTA')),
           to_number(fug_obt_pardinamico('CAJ_SEG_COD_TRA_RECAR'))) then
           paq_caj.PR_GEN_REVERSION(r_gmovi.nro_documento, p_hora, p_fecha);
         end if;

      ELSE
         --- Préstamos y operaciones vencidas
         IF r_gmovi.cod_mod_padre <> 9 THEN
            IF r_gmovi.estado = 'N' AND r_gmovi.nro_caja IS NOT NULL --- Existen operaciones de cobros automaticos de cheques custodia
               AND r_gmovi.cod_transaccion IN (840, 740, 607, 610, 632, 606) THEN
               --- Reversion de operacion de cheque o efectivo que no se
               --- inicio en caja
               --- Esto funciona porque la ultima secuencia corresponde a la
               --- forma de pago pendiente de pasar por caja
               --CRO-HO-CROCPCCB-16/09/15: Solo debe cambiar de estado si la operación NO es un cobro de préstamos con cheque cargo otros banco
               If (r_gmovi.cod_modulo = 6 and r_gmovi.cod_transaccion not in (607, 610, 632)
                   or r_gmovi.cod_modulo <> 6 )Then
                   UPDATE ge_movimientos
                      SET estado      = 'J',
                          nro_caja    = NULL,
                          cod_oficina = cod_ofi_origen
                    WHERE fecha = rp_gmovi.fecha
                      AND hora = rp_gmovi.hora
                      AND nro_secuencia = rp_gmovi.nro_secuencia
                      AND cod_usuario = rp_gmovi.cod_usuario;
               End IF;
            END IF;
            IF v_ope_pendiente = 'N' THEN
               pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
               -- AAP- Si tiene pr_cta_gastos, debo dejar
               -- disponible para un nuevo cobro.
               UPDATE pr_cta_gastos cg
                  SET cg.fec_ult_pago = NULL,
                      cg.hor_ult_pago = NULL
                WHERE cg.fec_ult_pago = rp_gmovi.fecha
                  AND cg.hor_ult_pago = rp_gmovi.hora
          AND cg.nro_cuenta   = rp_gmovi.nro_cuenta;
            END IF;
         ELSE
            --- Reversion de una operacion que se inicio y cerro en caja
            pag_gen.pr_ins_ge_movimiento(r_gmovi, v_es_nocturno);
         END IF;
      END IF;

    --No debe controlar mov posteriores para usuarios de SPI
    --
    IF instr(','||fug_obt_pardinamico('SPI_USU_MOVIMIENTOS')||',', ','||UPPER(p_cod_usuario)||',') > 0 THEN
      -- Veo si hubo cambio de estado o fecha de movimiento
      DECLARE
         v_can_cambios NUMBER(8); -- para contar cambios o mov posteriores
      BEGIN
         -- Verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
         ---- Verifico Si es Préstamo Asociaciones debe buscar los cambios por la Fecha del Movimiento, de lo contrario por la Fecha Valor del Movimiento.
         IF r_gmovi.cod_mad_padre = 627 AND fug_obt_tip_implementacion = 1 THEN
            SELECT COUNT(*)
              INTO v_can_cambios
              FROM gv_movimientos
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND ((fec_valor > rp_gmovi.fecha) OR
                   (fec_valor = rp_gmovi.fecha AND hora > rp_gmovi.hora))
               AND reversado = 'N'
               AND ((est_cuenta IS NOT NULL AND nvl(cod_tip_movimiento, 'x') = 'E') OR
                   v_est_anterior IS NOT NULL) -- si hubo otro cambio de estado posterior
               AND cod_tra_padre NOT IN (150, 200, 730, 731, 945) /*150 Valuaciones - 200 Desafec.de Garantias- 730 Constitucion de Prevision - 731 Extorno de Prev. - 945 Cambio de Sit. */
               AND rownum = 1;
            IF nvl(v_can_cambios, 0) > 0 THEN
               raise_application_error(-20000,
                                       'La cuenta ' || rp_gmovi.nro_cuenta ||
                                        ' tiene movimientos posteriores que deben ser reversados previamente.');
            END IF;
         ELSE
            SELECT COUNT(*)
              INTO v_can_cambios
              FROM gv_movimientos
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND ((fec_valor > rp_gmovi.fec_valor) OR
                   (fec_valor = rp_gmovi.fec_valor AND hora > rp_gmovi.hora))
               AND reversado = 'N'
               AND ((est_cuenta IS NOT NULL AND nvl(cod_tip_movimiento, 'x') = 'E') OR
                   v_est_anterior IS NOT NULL) -- si hubo otro cambio de estado posterior
               AND cod_tra_padre NOT IN (150, 200, 730, 731, 945) /*150 Valuaciones - 200 Desafec.de Garantias - 730 Constitucion de Prevision - 731 Extorno de Prev. - 945 Cambio de Sit. */
               AND rownum = 1;
            IF nvl(v_can_cambios, 0) > 0 THEN
               raise_application_error(-20000,
                                       'La cuenta ' || rp_gmovi.nro_cuenta ||
                                        ' tiene movimientos posteriores que deben ser reversados previamente.');
            END IF;
         END IF;
         ----
         IF v_fec_ult_mov_ant IS NOT NULL THEN
            -- verifico sino hubo movimientos posteriores de la cuenta
            SELECT COUNT(*)
              INTO v_can_cambios
              FROM gv_movimientos
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND ((fecha > rp_gmovi.fecha) OR (fecha = rp_gmovi.fecha AND hora > rp_gmovi.hora))
               AND reversado = 'N'
               AND monto > 0 -- si hubo un mov posterior
               AND rownum = 1;
            IF nvl(v_can_cambios, 0) > 0 THEN
               -- en este caso nada mas no se actualiza los datos del ultimo mov
               v_fec_ult_mov_ant := NULL;
               v_hor_ult_mov_ant := NULL;
            END IF;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            v_est_anterior    := NULL;
            v_fec_cam_est_ant := NULL;
            v_fec_ult_mov_ant := NULL;
            v_hor_ult_mov_ant := NULL;
         WHEN OTHERS THEN
            raise_application_error(-20000, SQLERRM || ' 1 Buscando ge_cuentas_nov ');
      END;
      END IF;
      ---Borra los registros de ge_pag_sueldos al reversar
      IF rp_gmovi.cod_modalidad=31 and rp_gmovi.cod_tra_padre in(304,1303,1304,1305,1306)  then
       delete ge_pag_sueldos where nro_cuenta=rp_gmovi.nro_cuenta
       and fec_proceso=rp_gmovi.fecha and procesado='S' and nro_lote=p_nro_lote;
      END IF;

      --************************---
        /* FM 17/04/2015 DYDMR-1741*/
   declare
    cursor rev_ope_cam is
           select val_minimo
           from ba_cod_referencias
           where val_maximo = p_hora
           and dominio = 'DAT_OPE_RELACION';
    begin

        for c_cam in rev_ope_cam
            loop
              --DYDMR-3627 ITGF - Inconveniente para Aprobar una Reversión 352 - Deposito de Cheque SC 27822. Manejo de Excepción
              begin
                SELECT COD_MOD_PADRE, COD_MAD_PADRE, COD_TRA_PADRE, NRO_DOCUMENTO
                  INTO VB_COD_MOD_PADRE, VB_COD_MAD_PADRE, VB_COD_TRA_PADRE, VB_NRO_DOCUMENTO
                  FROM GE_MOVIMIENTOS
                 WHERE HORA = c_cam.val_minimo
                   AND FECHA = P_FECHA
                   AND COD_USUARIO = P_cod_USUARIO
                   AND NRO_SECUENCIA = 1;
               exception
                 when others then
                   VB_COD_MOD_PADRE:= null;
                   VB_COD_MAD_PADRE:= null;
                   VB_COD_TRA_PADRE:= null;
                   VB_NRO_DOCUMENTO:= null;
               end;

               if vb_cod_tra_padre is not null then
                  vb_hor_reversion := fug_obt_hor_disponible(p_fecha,vb_hor_reversion,p_cod_usu_reversion,'N');

                  PRG_REV_OPERACION(p_fecha,
                                    c_cam.val_minimo,
                                    p_cod_usuario,
                                    vb_cod_mod_padre,
                                    vb_cod_mad_padre,
                                    vb_cod_tra_padre,
                                    p_cod_usu_reversion,
                                    vb_hor_reversion,
                                    'N',
                                    p_concepto,
                                    vb_nro_documento);
               END IF;
            end loop;
        IF vb_cod_tra_padre is not null then
           delete from ba_cod_referencias
            where val_maximo =   P_HORA
              and dominio   = 'DAT_OPE_RELACION';
        END IF;
      end;


   -- EXCEPTION
    -- WHEN OTHERS THEN
     --  VB_HORA := NULL;
   --END;

   --IF VB_HORA IS NOT NULL THEN
     /*SELECT COD_MOD_PADRE, COD_MAD_PADRE, COD_TRA_PADRE, NRO_DOCUMENTO
       INTO VB_COD_MOD_PADRE,
            VB_COD_MAD_PADRE,
            VB_COD_TRA_PADRE,
            VB_NRO_DOCUMENTO
       FROM GE_MOVIMIENTOS
      WHERE HORA = VB_HORA
        AND FECHA = P_FECHA
        AND COD_USUARIO = P_cod_USUARIO
        AND NRO_SECUENCIA = 1;*/

        --vb_hor_reversion := fug_obt_hor_disponible(p_fecha,vb_hor_reversion,p_cod_usu_reversion,'N');

/*     PRG_REV_OPERACION(p_fecha,
                       vb_hora,
                       p_cod_usuario,
                       vb_cod_mod_padre,
                       vb_cod_mad_padre,
                       vb_cod_tra_padre,
                       p_cod_usu_reversion,
                      vb_hor_reversion,
                       'N',
                       p_concepto,
                       vb_nro_documento);

    delete from ba_cod_referencias
    where val_maximo =   P_HORA
      and dominio   = 'DAT_OPE_RELACION';

    end if;*/



    /* if ((r_gmovi.cod_modulo = 4) and
           (r_gmovi.cod_modalidad = 455) and
           (R_GMOVI.COD_TRA_PADRE = 303)) then
        --  if :cuentas.U_COD_MONEDA <> :CUENTAS.U_CRE_COD_MONEDA THEN
              IF r_gmovi.cod_moneda = v_cod_mon_local THEN --503 / COMPRA - 71
                PRL_PRO_OPE_CAM_SIPAP(r_gmovi.hora, r_gmovi.cod_usuario , r_gmovi.nro_documento, 'C');
              else --602 / VENTA - 72
                 PRL_PRO_OPE_CAM_SIPAP(r_gmovi.hora, r_gmovi.cod_usuario , r_gmovi.nro_documento, 'V');
              END IF;
         --  END IF;
      end if;    */
 --************************---
 if (rp_gmovi.cod_tra_padre <> 8592) then--UPS-759 Verifica que no sea pago de servicios wepa
   -- Veo si hubo cambio de estado o fecha de movimiento (Sino es movimiento SIPAP)
  if  (rp_gmovi.cod_mad_padre <> 455) then
    --Detalle de Cheques TED (09/07/2024)
    IF (rp_gmovi.cod_tra_padre <> 395) THEN  
      DECLARE
         v_can_cambios NUMBER(8); -- para contar cambios o mov posteriores
      BEGIN
         SELECT t.est_anterior, t.fec_cam_est_ant, t.fec_ult_mov_ant, t.hor_ult_mov_ant, t.fec_ult_cap_ant --DYDMR-4896
           INTO v_est_anterior, v_fec_cam_est_ant, v_fec_ult_mov_ant, v_hor_ult_mov_ant, v_fec_ult_cap_ant
           FROM ge_cuentas_nov t
          WHERE t.fecha = rp_gmovi.fecha
            AND t.hora = rp_gmovi.hora
            AND t.cod_usuario = rp_gmovi.cod_usuario
            AND t.nro_cuenta = rp_gmovi.nro_cuenta;
         BEGIN
            --Verifica que no existan movimientos posteriores.
            SELECT (CASE
                      WHEN ((nvl(v.est_cuenta, 'x') != 'N' AND v.cod_modulo != 6
                             AND p_cod_mod_padre <> 6 AND p_cod_mad_padre <> nvl(fug_obt_pardinamico('COD_MAD_PRE_APROBADOS'), 'x') ) OR
                           (v.cod_modulo = 6 AND
                            (nvl(fup_obt_tip_descuento(v.cod_modalidad), 'x') != 'C') )
                           --Para el módulo de PRESTAMOS con el tipo diferente a descuento CHEQUES o PRE-APROBADOS
                           --ya que para todas las otras modalidades del módulo PRESTAMOS,
                           --QUE NO SEAN DE DESCUENTO DE CHEQUES, SE DEBE REVERSAR en el orden inverso en que fueron cargados.
                           ) THEN
                       1
                      ELSE
                       0
                   END)
              INTO v_can_cambios
              FROM (SELECT est_cuenta, cod_modulo, cod_modalidad
                      FROM gv_movimientos
                     WHERE nro_cuenta = rp_gmovi.nro_cuenta
                       AND ((fec_valor > rp_gmovi.fec_valor) OR
                           (fec_valor = rp_gmovi.fec_valor AND hora > rp_gmovi.hora))
                       AND reversado = 'N'
                       AND ((est_cuenta IS NOT NULL AND nvl(cod_tip_movimiento, 'x') = 'E') OR
                           (v_est_anterior IS NOT NULL)) -- si hubo otro cambio de estado posterior
                     ORDER BY fec_insercion DESC) v
             WHERE rownum = 1;
         EXCEPTION
            WHEN no_data_found THEN
               v_can_cambios := 0;
         END;
         IF nvl(v_can_cambios, 0) > 0
           and (rp_gmovi.cod_tra_padre <> 890 and rp_gmovi.cod_mad_padre not in (81,82) and rp_gmovi.nro_secuencia <> 1) then --agregado para el AP1465
            raise_application_error(-20006,
                                    'La cuenta ' || rp_gmovi.nro_cuenta ||
                                     ' tiene movimientos posteriores que deben ser reversados previamente.');
         END IF;
         IF v_fec_ult_mov_ant IS NOT NULL THEN
            -- verifico sino hubo movimientos posteriores de la cuenta
            SELECT COUNT(*)
              INTO v_can_cambios
              FROM gv_movimientos
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND ((fecha > rp_gmovi.fecha) OR (fecha = rp_gmovi.fecha AND hora > rp_gmovi.hora))
               AND reversado = 'N'
               AND monto > 0 -- si hubo un mov posterior
               AND rownum = 1;
            IF nvl(v_can_cambios, 0) > 0 THEN
               -- en este caso nada mas no se actualiza los datos del ultimo mov
               v_fec_ult_mov_ant := NULL;
               v_hor_ult_mov_ant := NULL;
            END IF;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            v_est_anterior    := NULL;
            v_fec_cam_est_ant := NULL;
            v_fec_ult_mov_ant := NULL;
            v_hor_ult_mov_ant := NULL;
            v_fec_ult_cap_ant := NULL;
         WHEN OTHERS THEN
            raise_application_error(-20007, SQLERRM || ' Buscando ge_cuentas_nov ');
      END;
    END IF;
   end if;
 end if;
      -- ITGF - Rev.Histórica no Genera Mov.Inversos en Rubro 240402600205499 - Seg.Vida por Cobrar - SC 14952
      -- cobros de cuotas, cancelacion anticip. parcial, cancelacion total, debito automatico prestamos
      IF rp_gmovi.cod_tra_padre in (360,362,359,364 ) then
         lp_ver_rev_car_seguro( rp_gmovi.fecha, rp_gmovi.nro_cuenta, rp_gmovi.nro_documento3);
      END IF;


      --restauro el estado de la cuenta de préstamos x reversión de incobrables
      IF rp_gmovi.cod_tra_padre = 945 AND rp_gmovi.cod_transaccion = 438 AND --pase a incobrable
         rp_gmovi.cod_modulo = 6 AND rp_gmovi.nro_cuenta IS NOT NULL AND v_est_anterior IS NOT NULL THEN
         --actualizar las cuotas y el préstamo
         pap_mes.pr_act_est_cuotas(rp_gmovi.nro_cuenta, v_est_anterior); --actualiza estado de cuotas
         pap_mes.pr_act_est_prestamo(rp_gmovi.nro_cuenta, v_est_anterior); --actualiza estado de prestamo
      END IF;

      --restauro el estado de la cuenta de operaciones vencidas x reversión de incobrables
      IF rp_gmovi.cod_tra_padre = 945 AND rp_gmovi.cod_transaccion = 438 AND --pase a incobrable
         rp_gmovi.cod_modulo = 15 AND -- operaciones vencidas
         rp_gmovi.nro_cuenta IS NOT NULL AND v_est_anterior IS NOT NULL THEN
         --actualizar estado de la cuenta de operaciones vencidas
         BEGIN
            UPDATE ov_cta_vencidas
               SET estado         = est_anterior,
                   fec_cam_estado = rp_gmovi.fecha
             WHERE nro_cuenta = rp_gmovi.nro_cuenta;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20090, 'Al actualizar estado op. vencida' || SQLERRM);
         END;
      END IF;

      -- restauro el estado de la cuenta --
      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.est_cuenta IS NOT NULL AND
         v_est_anterior IS NOT NULL AND r_gmovi.cod_modulo IN (3, 4, 7, 8) THEN
         --and /* solo reversa ahorros por ahora */
         --       r_gmovi.cod_modalidad <> 82 then -- Comex CCE se hace aparte
         pag_cta.pr_act_est_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, v_est_anterior,
                                v_fec_cam_est_ant);
      END IF;
      -- restauro el estado del cupon   -- POR AHORA SOLO POR CANCELACION
      IF rp_gmovi.cod_transaccion IN (407, 423) -- Cambio estado del cupon
         AND rp_gmovi.cod_tra_padre = 301 -- Cancelacion
         AND rp_gmovi.cod_modulo IN (3, 4) AND rp_gmovi.est_cuenta = 'P' THEN
         UPDATE ah_cupones
            SET estado   = decode(rp_gmovi.cod_transaccion, 407, 'E', 'V'),
                fec_pago = NULL
          WHERE nro_cuenta = rp_gmovi.nro_cuenta
            AND nro_cupon = rp_gmovi.nro_documento;
      END IF;
      -- verificar si es cobro de servicios
      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.cod_modalidad IN (31, 41) AND
         (fug_es_servicio(rp_gmovi.nro_cuenta, rp_gmovi.cod_tra_padre) = 'S' OR --transaccion o tra_comision
         fug_es_servicio(rp_gmovi.nro_cuenta, rp_gmovi.cod_tra_padre, rp_gmovi.cod_tra_padre) = 'S') THEN
         --ver si es la remisión o el cobro lo que se reversa
         IF rp_gmovi.nro_documento2 IS NOT NULL THEN
            --si corresponde al servicio
            BEGIN
               SELECT 'x'
                 INTO v_remision
                 FROM ge_cob_ser_parametros
                WHERE cod_servicio = rp_gmovi.nro_documento2;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20060,
                                          'Recup.Servicio ' || rp_gmovi.nro_documento2 || '.' ||
                                           SQLERRM);
            END;
         END IF;
         IF v_remision IS NULL THEN
            --es un cobro
            -- borrar el registro de cobro de servicios
            DECLARE
               v_nro_remision ge_cob_servicios.nro_remision%TYPE;
               v_fec_remision ge_cob_servicios.fec_remision%TYPE;
            BEGIN
               SELECT nro_remision, fec_remision
                 INTO v_nro_remision, v_fec_remision
                 FROM ge_cob_servicios s
                WHERE s.fecha = p_fecha
                  AND s.hora = p_hora
                  AND s.cod_usuario = p_cod_usuario;
               IF v_nro_remision IS NOT NULL OR v_fec_remision IS NOT NULL THEN
                  raise_application_error(-20059,
                                          'El cobro ya fue remitido. Rem.Nro. ' || v_nro_remision);
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  --porque esto hace x mov., y una sola vez encuentra y luego borra
                  NULL;
            END;
            --actualizar las cuotas si corresponde
            BEGIN
               UPDATE ge_cob_ser_cuotas
                  SET estado    = 'I',
                      fec_cobro = NULL
                WHERE estado = 'P'
                  AND fec_cobro = p_fecha
                  AND (cod_servicio, nro_cuenta, referencia, nro_cuota) IN
                      (SELECT cod_servicio, nro_cuenta, referencia1, nro_cuota
                         FROM ge_cob_servicios s
                        WHERE s.fecha = p_fecha
                          AND s.hora = p_hora
                          AND s.cod_usuario = p_cod_usuario
                          AND s.nro_remision IS NULL
                          AND s.fec_remision IS NULL
                          AND s.tip_cobro IN ('P', 'M') --proceso o manual (si el proceso no pudo cobrar)
                          AND EXISTS (SELECT '*'
                                 FROM ge_cob_ser_parametros x -- esto funciona porque uno de los mov
                                WHERE nro_cuenta = rp_gmovi.nro_cuenta --es el crédito a la cta del serv
                                  AND nvl(cod_transaccion, 215) = rp_gmovi.cod_tra_padre
                                  AND s.cod_servicio = x.cod_servicio));
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20055, 'Act.Cuotas.Srv. ' || SQLERRM);
            END;
            BEGIN
               DELETE ge_cob_servicios s
                WHERE s.fecha = p_fecha
                  AND s.hora = p_hora
                  AND s.cod_usuario = p_cod_usuario
                  AND s.nro_remision IS NULL
                  AND s.fec_remision IS NULL
                  AND EXISTS (SELECT '*'
                         FROM ge_cob_ser_parametros x -- esto funciona porque uno de los mov
                        WHERE nro_cuenta = rp_gmovi.nro_cuenta --es el crédito a la cta del serv
                          AND nvl(cod_transaccion, 215) = rp_gmovi.cod_tra_padre
                          AND s.cod_servicio = x.cod_servicio);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20055, 'Al eliminar el servicio ' || SQLERRM);
            END;
         ELSE
            --es una remisión
            --ver que sea la última remisión realizada, no se puede reversar en cualquier orden
            IF v_pri_vez = 'S' THEN
               --sólo una vez, luego se borra el resumen
               v_pri_vez := 'N';
               DECLARE
                  v_ult_remision ge_cob_servicios_res.nro_remision%TYPE;
               BEGIN
                  SELECT nvl(MAX(nro_remision), 0)
                    INTO v_ult_remision
                    FROM ge_cob_servicios_res
                   WHERE cod_servicio = rp_gmovi.nro_documento2
                     AND fec_remision = p_fecha;
                  IF v_ult_remision > rp_gmovi.nro_documento THEN
                     raise_application_error(-20062,
                                             'Existen remisiones posteriores del servicio que deben ser reversardas previamente.');
                  END IF;
               END;
            END IF;
            --los débitos se reversan normalmente x la cuenta
            --actualizar los cobros a no remitidos
            UPDATE ge_cob_servicios
               SET nro_remision = NULL,
                   fec_remision = NULL
             WHERE fec_remision = p_fecha
               AND nro_remision = rp_gmovi.nro_documento
               AND cod_servicio = rp_gmovi.nro_documento2;
            --eliminar resumen de remisión
            DELETE ge_cob_servicios_res
             WHERE cod_servicio = rp_gmovi.nro_documento2
               AND fec_remision = p_fecha
               AND nro_remision = rp_gmovi.nro_documento;
            -----ACTUALIZAR LA TABLA GE_COB_SER_PARAMETROS----
            DECLARE
               v_fec_rem_ant ge_cob_servicios_res.fec_remision%TYPE;
               v_nro_rem_ant ge_cob_servicios_res.nro_remision%TYPE;
            BEGIN
               BEGIN
                  SELECT fec_remision, nro_remision
                    INTO v_fec_rem_ant, v_nro_rem_ant
                    FROM ge_cob_servicios_res
                   WHERE cod_servicio = rp_gmovi.nro_documento2
                     AND nro_remision =
                         (SELECT MAX(nro_remision) --x si hubiera mas de una remisión x fecha
                            FROM ge_cob_servicios_res
                           WHERE cod_servicio = rp_gmovi.nro_documento2);
               EXCEPTION
                  WHEN no_data_found THEN
                     v_fec_rem_ant := NULL;
                     v_nro_rem_ant := NULL;
               END;
               UPDATE ge_cob_ser_parametros
                  SET fec_ult_remision = v_fec_rem_ant,
                      sig_nro_remision = nvl(v_nro_rem_ant, 0) + 1
                WHERE cod_servicio = rp_gmovi.nro_documento2;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20061,
                                          'Act.Ser.Param. ' || rp_gmovi.nro_documento2 || ' - ' ||
                                           SQLERRM);
            END;
         END IF;
      END IF;
      -- fin cobro de servicios
      -- pago a proveedores
      IF rp_gmovi.nro_documento3 IS NOT NULL THEN
         --recuperar datos del ente
         BEGIN
            SELECT tipo INTO v_tipo FROM ge_entes WHERE cod_ente = rp_gmovi.nro_documento3;
         EXCEPTION
            WHEN no_data_found THEN
               NULL;
         END;
         IF v_tipo = 'PR' THEN
            --reversión del pago
            IF rp_gmovi.nro_documento IS NOT NULL THEN
               --verificar si hay orden de pago en proveedores por ese nro.
               BEGIN
                  SELECT DISTINCT cod_ente, fec_proceso
                    INTO v_proveedor, v_fec_proceso
                    FROM ge_pag_proveedores
                   WHERE referencia = rp_gmovi.nro_documento2
                     AND cod_ente = rp_gmovi.nro_documento3
                     AND estado = 'N'; --pagado
               EXCEPTION
                  WHEN no_data_found THEN
                    NULL;
               END;
               --actualizar proveedores
               IF v_proveedor IS NOT NULL THEN
                  --sólo si no se debitó la comisión
                  IF v_fec_proceso IS NOT NULL THEN
                     raise_application_error(-20554,
                                             'No puede reversar el pago. Ya se realizó el débito a la empresa.');
                  END IF;

                  DECLARE
                     CURSOR c_fac IS
                        SELECT g.nro_factura,
                               g.for_pago,
                               g.referencia,
                               cod_ente,
                               p.cod_ent_proveedor,
                               g.nro_orden,
                               p.timbrado
                          FROM ge_pag_proveedores g, pv_compras p
                         WHERE cod_ente = v_proveedor
                           AND referencia = rp_gmovi.nro_documento2
                           AND g.nro_factura = p.nro_factura
                           AND g.fec_mov_pago is null
                           AND g.nro_orden = rp_gmovi.nro_documento -- DYDMR-6158 NAF 03/2017
                           AND g.beneficiario = p.nom_proveedor
                     UNION ALL
                     SELECT g.nro_factura,
                            g.for_pago,
                            g.referencia,
                            cod_ente,
                            p.cod_ent_proveedor,
                            g.nro_orden,
                            p.timbrado
                       FROM ge_pag_proveedores g, pv_compras p
                      WHERE cod_ente = v_proveedor
                        AND referencia = rp_gmovi.nro_documento2
                        AND g.nro_factura = p.nro_factura
                        AND g.fec_mov_pago = rp_gmovi.fecha
                        AND g.hor_mov_pago = rp_gmovi.hora
                        AND g.usu_mov_pago = rp_gmovi.cod_usuario
                        AND g.beneficiario = p.nom_proveedor;
                  BEGIN
                     FOR c IN c_fac LOOP
                        UPDATE ge_pag_proveedores
                           SET estado     = 'C',
                               nro_recibo = NULL,
                               nro_cheque = NULL,
                               fec_mov_pago = NULL,
                               hor_mov_pago = NULL,
                               usu_mov_pago = NULL
                         WHERE cod_ente = v_proveedor
                           AND referencia = c.referencia
                           AND cod_ente = c.cod_ente
                           AND nro_orden = c.nro_orden; -- DYDMR-6158 NAF 03/2017

                        UPDATE ge_ret_proveedores r
                           SET estado = 'A'
                         WHERE r.nro_factura = c.nro_factura
                           AND r.cod_proveedor = c.cod_ent_proveedor
                           AND r.fec_insercion = (select max(rp.fec_insercion) from ge_ret_proveedores rp
                                                   WHERE r.nro_factura  = rp.nro_factura
                                                     AND r.cod_proveedor = rp.cod_proveedor);

                        UPDATE pv_compras a
                           SET a.ind_pagado = 'N',
                               a.estado = 'A' /*09/01/2014 PN DI: Se agrega porque no rebertia el estado de la compra (SPI 2923)*/
                         WHERE a.nro_factura = c.nro_factura
                           AND a.cod_ent_proveedor = c.cod_ent_proveedor
                           AND a.timbrado = c.timbrado;--DYDMR-7799 - Incidencia SAU - ITGF - Incidencia al Reversar las facturas de proveedores

                     END LOOP;
                  EXCEPTION
                     WHEN OTHERS THEN
                        raise_application_error(-20555, 'Act. ge_pag_proveedores ' || v_proveedor);
                  END;

               END IF;
            END IF;
            --reversión del cobro de comisión
            IF rp_gmovi.referencia IS NOT NULL AND rp_gmovi.nro_secuencia = 1 THEN
               --para q haga una vez
               --actualizar proveedores
               BEGIN
                  UPDATE ge_pag_proveedores
                     SET fec_proceso = NULL,
                         hora        = NULL
                   WHERE cod_ente = rp_gmovi.nro_documento3
                     AND fec_proceso IS NOT NULL
                     AND hora = p_hora
                     AND estado IN ('N', 'C');
                  IF SQL%NOTFOUND THEN
                     raise_application_error(-20556,
                                             'No encontró débito por comisión pago a proveedor ' ||
                                              rp_gmovi.nro_documento3);
                  END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     IF SQLCODE <= -20000 THEN
                        RAISE;
                     ELSE
                        raise_application_error(-20556,
                                                'Act. fec_proceso ge_pag_proveedores ' ||
                                                 v_proveedor);
                     END IF;
               END;
            END IF;
            --
         END IF; --proveedor
      END IF;
      -- fin pago a proveedores
      -- restauro el estado del certificado -- POR AHORA SOLO POR CANCELACION
      IF rp_gmovi.cod_transaccion = 422 -- Cambio estado del certificado
         AND rp_gmovi.cod_tra_padre = 301 -- Cancelacion
         AND rp_gmovi.cod_modulo IN (3, 4) AND rp_gmovi.est_cuenta = 'V' THEN
         UPDATE ah_cta_certificados
            SET est_certificado = 'E'
          WHERE nro_cuenta = rp_gmovi.nro_cuenta;
      END IF;
      -- restauro el estado del certificado -- Cuando se realiza una cancelacion anticipada
      IF rp_gmovi.cod_transaccion = 405 -- Cambio estado del certificado
         AND rp_gmovi.cod_tra_padre = 301 -- Cancelacion
         AND rp_gmovi.cod_modulo = 3 AND rp_gmovi.est_cuenta = 'P' THEN
         UPDATE ah_cta_certificados
            SET est_certificado = 'E',
                fec_ult_capitalizacion = v_fec_ult_cap_ant, /*DYDMR-4896 Se actualiza la fecha de ultima capitalización*/
                cod_cau_cancelacion = null   /*DYDMR-4896 Se elimina el codigo de causa de cancelación*/
          WHERE nro_cuenta = rp_gmovi.nro_cuenta;
         UPDATE sb_encajes_esp
            set dia_transcurrido = 0
          where nro_cuenta = rp_gmovi.nro_cuenta;
      END IF;
      IF rp_gmovi.cod_transaccion = 903 --- Reversion de ajuste del devengado
         AND rp_gmovi.cod_tra_padre = 301 AND rp_gmovi.cod_modulo IN (3, 4) THEN
         v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', rp_gmovi.cod_modulo,
                                           rp_gmovi.cod_modalidad, rp_gmovi.cod_moneda);
         UPDATE ah_devengados
            SET mto_interes       = round((val_tasa * sal_acumulado / 36500), v_redondeo), --- Devengado de un dia
                mto_dev_acumulado = nvl(mto_dev_acumulado, 0) + (nvl(rp_gmovi.monto, 0) * -1)
          WHERE nro_cuenta = rp_gmovi.nro_cuenta
            AND fecha = rp_gmovi.fecha;
         --- Reversar historico de devengado
         UPDATE ah_devengados_his
            SET mto_interes = mto_interes + (rp_gmovi.monto * -1)
          WHERE nro_cuenta = rp_gmovi.nro_cuenta
            AND ano = to_number(to_char(rp_gmovi.fecha, 'YYYY'))
            AND mes = to_number(to_char(rp_gmovi.fecha, 'MM'));
      END IF;
      IF rp_gmovi.cod_transaccion = 522 AND rp_gmovi.cod_tra_padre = 321 AND
         rp_gmovi.cod_modulo IN (3, 4) THEN
         --Reversion de cheques devueltos
         UPDATE ge_cheques_det
            SET estado = 'I'
          WHERE nro_cuenta = rp_gmovi.nro_cuenta
            AND nro_cheque = to_number(rp_gmovi.nro_documento)
            AND monto = rp_gmovi.monto;
      END IF;
      IF rp_gmovi.cod_tra_padre = 229 AND rp_gmovi.cod_modulo IN (3, 4) AND
         (rp_gmovi.nro_cuenta IS NOT NULL OR rp_gmovi.cod_rubro IS NOT NULL) THEN
         -- giros emitidos
         DECLARE
            v_cod_estado VARCHAR2(1);
         BEGIN
            SELECT cod_estado
              INTO v_cod_estado
              FROM ge_giros
             WHERE nro_operacion = rp_gmovi.nro_documento
               AND nro_cta_debito = nvl(rp_gmovi.nro_cuenta, rp_gmovi.cod_rubro)
               AND monto = rp_gmovi.monto;
            IF v_cod_estado = '3' THEN
               -- pagado
               raise_application_error(-20000, 'El giro ya fue pagado.');
            ELSIF v_cod_estado <> '2' THEN
               -- cobrado
               raise_application_error(-20000, 'Estado del giro no permite reversion.');
            END IF;
            -- actualiza el estado del giro
            UPDATE ge_giros
               SET cod_estado = '4' -- anulado
             WHERE nro_operacion = rp_gmovi.nro_documento;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000,
                                       'No se encontró la operacion de giro emitido. ' ||
                                        rp_gmovi.nro_documento);
            WHEN OTHERS THEN
               raise_application_error(-20000,
                                       'Problema al obtener datos de giro emitido. ' || SQLERRM);
         END;
      END IF;

      --DYDMR-2996--Se agrega para reversiones de traslado de cheques descontados USD
      --Actualización de la oficina de Cámara-- 11/07/2016
      IF rp_gmovi.cod_tra_padre = 143 AND rp_gmovi.cod_transaccion = 143 AND
         rp_gmovi.cod_modulo = 6 THEN
         --Reversion de cheques custodias
         UPDATE ge_che_custodias
            SET cod_ofi_camara = cod_oficina
          WHERE nro_cheque = to_number(rp_gmovi.nro_documento)
            AND estado = 'C'
            AND monto = rp_gmovi.monto
            AND cod_moneda = rp_gmovi.cod_moneda ;
      END IF;

      -- retorno el monto del saldo de la cuenta
      IF rp_gmovi.nro_cuenta IS NOT NULL AND
         (rp_gmovi.estado = 'N' OR --- Los movimientos 'J' no actualizan la cuenta
         --DYDMR-6864
         (rp_gmovi.estado = 'P' AND (instr(v_cod_tra_cargo,','||rp_gmovi.cod_tra_padre||',') > 0))  or ---rp_gmovi.cod_tra_padre in (578,8110)) or--DYDMR-5909 -- cargos de CCI
         (rp_gmovi.estado = 'P' AND rp_gmovi.cod_transaccion = 610)) AND--Para casos de DNA con CHQ
          rp_gmovi.monto <> 0 AND r_gmovi.cod_modulo IN (3, 4, 6) AND
          v_ope_pendiente = 'N' THEN -- AP 2595 - Solo si no pasó por caja.
         /* Se agrego el modulo 6, por cheques custodia*/
         v_ope_ahorros := 'S';
         IF v_fec_ult_mov_ant IS NOT NULL THEN
            v_act_ult_movimiento := 'S'; -- debe actualizar la fecha y hora
         END IF;
         -- obtengo el tipo d/c y a que saldo afecto
         IF r_gmovi.cod_modulo <> 6 THEN
            pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                   rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         END IF;
   -- rbpa - 20/jun/14 - Se agrega 3322 p/Compensacion Camara interna - SPI 2441
         IF rp_gmovi.cod_tra_padre IN (138, 132, 322, 3322) AND rp_gmovi.nro_cuenta IS NOT NULL AND
            rp_gmovi.cod_modulo = 4 THEN
            -- cheques devueltos
            -- reversion de cheques devueltos nuestro banco
            IF rp_gmovi.cod_tra_padre in (322, 3322) THEN
               UPDATE cc_che_recibidos
                  SET est_cheque         = 'P',
                      cod_cau_devolucion = NULL
                WHERE nro_cheque = rp_gmovi.nro_documento
                  AND fec_proceso = (SELECT MAX(fec_proceso)
                                       FROM cc_che_recibidos
                                      WHERE nro_cheque = rp_gmovi.nro_documento
                                        AND monto = rp_gmovi.monto
                                        AND est_cheque = 'R')
                  AND est_cheque = 'R';
            END IF;

            /*DELETE FROM cc_che_dev_firmantes
                 WHERE nro_cuenta = rp_gmovi.nro_cuenta
                   AND nro_cheque = rp_gmovi.nro_documento
                   AND trunc(fec_insercion) =
                       (SELECT trunc(MAX(fec_insercion))
                          FROM cc_che_dev_firmantes
                         WHERE nro_cuenta = rp_gmovi.nro_cuenta
                           AND nro_cheque = rp_gmovi.nro_documento);*/

            --- pongo regularizado el cheque anterior
            UPDATE cc_che_devueltos
               SET regularizado     = 'S',
                   fec_modificacion = fec_modificacion
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND nro_cheque = rp_gmovi.nro_documento
               AND fecha < (SELECT MAX(fecha)
                              FROM cc_che_devueltos
                             WHERE nro_cuenta = rp_gmovi.nro_cuenta
                               AND nro_cheque = rp_gmovi.nro_documento);
            ---
              DELETE FROM cc_che_devueltos
               WHERE nro_cuenta = rp_gmovi.nro_cuenta
                 AND nro_cheque = rp_gmovi.nro_documento
               AND hora = rp_gmovi.hora
               AND fecha = (SELECT MAX(fecha)
                                FROM cc_che_devueltos
                               WHERE nro_cuenta = rp_gmovi.nro_cuenta
                               AND nro_cheque = rp_gmovi.nro_documento);

            --Validacion si le quedan cheques devueltos anteriores--
            select nvl(count(*),0)
              into v_can_che_devueltos
              from cc_che_devueltos
             where nro_cuenta = rp_gmovi.nro_cuenta
               and nro_cheque = rp_gmovi.nro_documento;
            --Elimina cc_che_dev_firmantes solo si no existe otra devolucion anterior firme--
            if nvl(v_can_che_devueltos,0) = 0 then --Debe eliminar el firmante--
               DELETE FROM cc_che_dev_firmantes
               WHERE nro_cuenta = rp_gmovi.nro_cuenta
                 AND nro_cheque = rp_gmovi.nro_documento
                  AND trunc(fec_insercion) =
                       (SELECT trunc(MAX(fec_insercion))
                          FROM cc_che_dev_firmantes
                         WHERE nro_cuenta = rp_gmovi.nro_cuenta
                           AND nro_cheque = rp_gmovi.nro_documento);
             end if;
            --actualizar el estado del cheque, volver a 'P'agado
   -- rbpa - 20/jun/14 - Se agrega 3322 p/Compensacion Camara interna - SPI 2441
            IF rp_gmovi.cod_tra_padre IN (132, 322, 3322) THEN
               -- actualizar cc_che_pagados
               UPDATE cc_che_pagados
                  SET cod_cau_devolucion = NULL
                WHERE nro_cheque = rp_gmovi.nro_documento
                  AND monto = rp_gmovi.monto
                  AND fecha = (SELECT MAX(fecha)
                                 FROM cc_che_pagados b
                                WHERE b.nro_cheque = rp_gmovi.nro_documento
                                  AND b.monto = rp_gmovi.monto);
               BEGIN
                  SELECT nro_cuenta
                    INTO v_nro_cta_cliente
                    FROM cc_che_certificados a
                   WHERE a.nro_cta_certificado = rp_gmovi.nro_cuenta
                     AND a.nro_cheque = rp_gmovi.nro_documento;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_nro_cta_cliente := rp_gmovi.nro_cuenta;
               END;
               IF rp_gmovi.cod_transaccion IN (602, 608, 668, 631, 630) THEN
                  UPDATE cc_chequeras
                     SET est_cheques = substr(est_cheques, 1,
                                              (rp_gmovi.nro_documento - nro_che_inicial + 1) - 1) || 'P' ||
                                       substr(est_cheques,
                                              (rp_gmovi.nro_documento - nro_che_inicial + 1) + 1)
                   WHERE nro_cuenta = v_nro_cta_cliente
                     AND rp_gmovi.nro_documento >= nro_che_inicial
                     AND rp_gmovi.nro_documento < nro_che_inicial + can_cheques
                     AND rp_gmovi.nro_documento BETWEEN nro_che_inicial AND nro_che_final;
                  IF SQL%NOTFOUND THEN
                     raise_application_error(-20333,
                                             'No encuentra Cheque ' || rp_gmovi.nro_documento);
                  END IF;
                  IF rp_gmovi.cod_modalidad = 43 THEN
                     --Actualizar la fecha de pago de cc_che_ger_emitidos--
                     UPDATE cc_che_ger_emitidos k
                        SET k.fec_pago = (SELECT fecha
                                            FROM cc_che_pagados x
                                           WHERE x.nro_cheque = rp_gmovi.nro_documento
                                             AND x.nro_cuenta = v_nro_cta_cliente
                                             AND x.fecha = (SELECT max(fecha)
                                                              FROM cc_che_pagados b
                                                             WHERE b.nro_cheque = rp_gmovi.nro_documento
                                                               AND b.monto = rp_gmovi.monto)),
                            k.cod_usu_pagador = (SELECT x.cod_usuario
                                            FROM cc_che_pagados x
                                           WHERE x.nro_cheque = rp_gmovi.nro_documento
                                             AND x.nro_cuenta = v_nro_cta_cliente
                                             AND x.fecha = (SELECT max(fecha)
                                                              FROM cc_che_pagados b
                                                             WHERE b.nro_cheque = rp_gmovi.nro_documento
                                                               AND b.monto = rp_gmovi.monto))
                     WHERE k.nro_cuenta = v_nro_cta_cliente
                       AND k.nro_cheque = rp_gmovi.nro_documento
                       AND exists (SELECT 1
                                     FROM cc_che_pagados x
                                    WHERE x.nro_cheque = rp_gmovi.nro_documento
                                      AND x.nro_cuenta = v_nro_cta_cliente
                                      AND x.fecha = (SELECT max(fecha)
                                                       FROM cc_che_pagados b
                                                      WHERE b.nro_cheque = rp_gmovi.nro_documento
                                                        AND b.monto = rp_gmovi.monto));

                     IF sql%notfound THEN
                        raise_application_error(-20333,'Error al actualizar fecha de Pago de Cheque Gerencia nro. '||rp_gmovi.nro_documento);
                     END IF;
                  END IF;
               END IF;
            END IF;
         ELSIF rp_gmovi.cod_tra_padre = 321 THEN
            -- reversion de cheques devueltos otros bancos
            UPDATE cc_che_remitidos
               SET cod_cau_devolucion = NULL
             WHERE cod_banco = rp_gmovi.cod_banco
               AND nro_cheque = rp_gmovi.nro_documento
               AND monto = rp_gmovi.monto
               AND cod_cau_devolucion IS NOT NULL;
            UPDATE cc_che_enviados
               SET cod_cau_devolucion = NULL,
                   estado             = 'E'
             WHERE cod_banco = rp_gmovi.cod_banco
               AND nro_cheque = rp_gmovi.nro_documento
               AND estado = 'D';
            UPDATE ge_che_custodias
               SET cod_cau_devolucion = NULL,
                   estado             = 'A'
             WHERE cod_banco = rp_gmovi.cod_banco
               AND nro_cheque = rp_gmovi.nro_documento
               AND estado = 'B';
            UPDATE ge_che_exterior
               SET cod_cau_devolucion = NULL,
                   estado             = 'E'
             WHERE cod_bco_corresponsal = rp_gmovi.cod_banco
               AND nro_cheque = rp_gmovi.nro_documento
               AND estado = 'D';
        --DYDMR-2996--Se agrega para reversiones de Envio a Compensación Cheques descontados USD. 11/07/2016
        --Actualización del estado del Cheque Custodia--
         ELSIF rp_gmovi.cod_tra_padre = 184 and rp_gmovi.cod_modalidad = 442 then
                UPDATE ge_che_custodias
                 SET estado = 'C'
               WHERE nro_cheque = rp_gmovi.nro_documento
                 AND monto = rp_gmovi.monto
                 AND cod_moneda = rp_gmovi.cod_moneda
                 AND estado = 'A';
         END IF;
         IF rp_gmovi.cod_retencion IS NOT NULL AND rp_gmovi.cod_transaccion NOT IN (515, 565, 560) THEN
            -- afecto la retencion, trato de borrar la retencion
            DELETE ah_retenciones
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND nro_documento = rp_gmovi.nro_documento
               AND cod_retencion = rp_gmovi.cod_retencion
               AND fec_inicio = rp_gmovi.fecha
               AND liberado = 'N';
            IF SQL%NOTFOUND THEN
               v_afecta := 'S'; -- se cambia  ya que no debe reversar el retenido, solo el saldo
               DELETE ah_retenciones
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND nro_documento = rp_gmovi.nro_documento
                  AND cod_retencion = rp_gmovi.cod_retencion
                  AND fec_inicio = rp_gmovi.fecha
                  AND liberado = 'S';
               -- borro el movimiento de la liberacion para que no actualice el saldo batch
               DELETE FROM ge_movimientos
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND nro_documento = rp_gmovi.nro_documento
                  AND cod_retencion = rp_gmovi.cod_retencion
                  AND fecha = rp_gmovi.fecha
                  AND monto = rp_gmovi.monto
                  AND cod_transaccion IN (515, 565, 560);
            END IF;
         ELSIF rp_gmovi.cod_retencion IS NOT NULL AND rp_gmovi.cod_transaccion IN (515, 565, 560) THEN

            --Modif. para reversar liberaciones x Cheque
            UPDATE ah_retenciones
               SET liberado      = 'N',
                   sal_retenido  = nvl(sal_retenido, 0) + rp_gmovi.monto,
                   lib_posterior = 'N'
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND nro_documento = rp_gmovi.nro_documento
               AND cod_retencion = rp_gmovi.cod_retencion
               AND fec_inicio = rp_gmovi.fec_valor
            ;

            --Obtener Datos de la retención
            lp_obt_retencion(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento, rp_gmovi.cod_retencion,
                             rp_gmovi.fec_valor, r_ah_retenciones);
            /*
            || CROLIANC-4 AT - Liberacion Anticipada Cheques C/O con Creación de Cuentas de Préstamos
            */
            IF nvl(r_ah_retenciones.lib_anticipada,'N') = 'S' then
               select nro_sol_prestamo, estado
                 into v_nro_sol_prestamo, v_est_liberacion
                 from cc_lib_ant_cheques a
                where a.nro_cuenta = r_ah_retenciones.nro_cuenta
                  and a.nro_documento = r_ah_retenciones.nro_documento
                  and a.cod_retencion = r_ah_retenciones.cod_retencion
                  and a.fec_final = r_ah_retenciones.fec_final;
               if v_est_liberacion = 'D' then
                  update cc_lib_ant_cheques
                     set estado = 'S'
                   where nro_sol_prestamo = v_nro_sol_prestamo;
               end if;
            END IF;
            --Fue una liberación por cheque, se debe actualizar el estado del cheque
            IF rp_gmovi.nro_documento2 IS NOT NULL THEN
               IF rp_gmovi.cod_transaccion IN (515, 565) THEN
                  --Plaza Local
                  UPDATE cc_che_enviados z
                     SET z.liberado      = 'N',
                         z.lib_posterior = 'N'
                   WHERE z.nro_boleta = rp_gmovi.nro_documento
                     AND z.nro_cuenta = rp_gmovi.nro_cuenta
                     AND z.cod_retencion = rp_gmovi.cod_retencion
                     AND z.cod_banco = rp_gmovi.cod_banco
                     AND z.nro_cheque = rp_gmovi.nro_documento2
                     AND z.liberado = 'S';
               ELSE
                  --560, Plaza Extranjera
                  UPDATE ge_che_exterior d
                     SET d.liberado      = 'N',
                         d.lib_posterior = 'N'
                   WHERE d.nro_boleta = rp_gmovi.nro_documento
                     AND d.nro_cuenta = rp_gmovi.nro_cuenta
                     AND d.cod_retencion = rp_gmovi.cod_retencion
                     AND d.cod_banco = rp_gmovi.cod_banco
                     AND d.nro_cheque = rp_gmovi.nro_documento2
                     AND d.liberado = 'S';
               END IF;
            ELSE
               --Liberación por el Saldo de la Boleta, actualizar los cheques que no fueron liberados individualmente (LIB_POSTERIOR=N)
               IF rp_gmovi.cod_transaccion IN (515, 565) THEN
                  --Plaza Local
                  UPDATE cc_che_enviados z
                     SET z.liberado = 'N'
                   WHERE z.nro_boleta = rp_gmovi.nro_documento
                     AND z.nro_cuenta = rp_gmovi.nro_cuenta
                     AND z.cod_retencion = rp_gmovi.cod_retencion
                     AND z.liberado = 'S'
                     AND z.lib_posterior = 'N'
                     AND z.fec_final = r_ah_retenciones.fec_final;
               ELSE
                  --560, Plaza Extranjera
                  UPDATE ge_che_exterior d
                     SET d.liberado = 'N'
                   WHERE d.nro_boleta = rp_gmovi.nro_documento
                     AND d.nro_cuenta = rp_gmovi.nro_cuenta
                     AND d.cod_retencion = rp_gmovi.cod_retencion
                     AND d.cod_banco = rp_gmovi.cod_banco
                     AND d.liberado = 'S'
                     AND d.lib_posterior = 'N'
                     AND d.fec_final = r_ah_retenciones.fec_final;
               END IF;
            END IF;
         END IF;
         -- DDSI-212 -- 2017/12 -- Verificar que no se haya insertado como para actualizacion de saldo en batch
         v_exi_movimiento := pag_bat.fu_ver_exi_movimiento(rp_gmovi.nro_cuenta,rp_gmovi.fecha,rp_gmovi.hora,rp_gmovi.cod_usuario,
                                                           rp_gmovi.cod_tra_padre, rp_gmovi.cod_transaccion, rp_gmovi.monto);
         IF nvl(v_exi_movimiento,'N') = 'N' THEN
            --23/08 Cta.SIPAP - Se ajusta para que no llavee Sipap Cta Interbancaria
            IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad, rp_gmovi.nro_cuenta, v_es_nocturno)/*UPS-633*/ = 'N' AND
               r_gmovi.cod_modulo <> 6 and rp_gmovi.cod_modalidad not in (43,455) THEN
               --solo para 3 y 4 por el momento
               -- cuenta llaveada
               raise_application_error(-20000, 'Cuenta ' || rp_gmovi.nro_cuenta || ' llaveada ');
            END IF;
         END IF;
         IF r_gmovi.cod_modulo = 6 THEN
            v_afecta := NULL;
         END IF;
         IF v_afecta = 'R' THEN
            -- afecta al saldo retenido
            IF v_tip_movimiento = 'C' THEN
               v_afe_sal_total     := r_gmovi.monto;
               v_afe_sal_retenido  := r_gmovi.monto;
               v_afe_sal_bloqueado := 0;
            ELSIF v_tip_movimiento = 'D' THEN
               v_afe_sal_total     := 0;
               v_afe_sal_retenido  := r_gmovi.monto;
               v_afe_sal_bloqueado := 0;
            END IF;
         ELSIF v_afecta IN ('C', 'I', 'S') AND (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') < 1) THEN--DYDMR-6864 ---p_cod_tra_padre NOT IN (578,8110) THEN --DYDMR-5909 se excluye las transacciones padre 578,8110 de cobro de cargos.- COMEX
            -- afecta al saldo total,capital o interes
            v_afe_sal_total  := r_gmovi.monto;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := 0;
         ELSIF v_afecta = 'B' AND (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') < 1) THEN --DYDMR-6864 p_cod_tra_padre --NOT IN (578,8110) THEN --DYDMR-5909 se excluye las transacciones padre 578,8110 de cobro de cargos. - COMEX
            -- afecta al saldo bloqueado
            v_afe_sal_total     := 0;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := r_gmovi.monto;
        ELSIF v_afecta IN ('C', 'I', 'S') and (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') > 0)/*--DYDMR-6864 p_cod_tra_padre IN (578,8110)*/ AND rp_gmovi.estado = 'N' THEN--DYDMR-5909 -para que afecte el saldo total con estado de movimiento Normal -COMEX - 13/03/2017
            -- afecta al saldo total,capital o interes
            v_afe_sal_total     := r_gmovi.monto;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := 0;
         ELSIF v_afecta IN ('C', 'I', 'S') and (instr(v_cod_tra_cargo,','||p_cod_tra_padre||',') > 0)/*--DYDMR-6864 p_cod_tra_padre IN (578,8110)*/ AND rp_gmovi.estado = 'P' THEN--DYDMR-5909 --debe afectar el saldo bloqueado ya que el movimiento queda con estado pendiente -COMEX - 13/03/2017
            -- afecta al saldo bloqueado
            v_afe_sal_total     := 0;
            v_afe_sal_retenido  := 0;
            v_afe_sal_bloqueado := rp_gmovi.monto;--se envia el monto positivo ya que es un debito a realizar
         END IF;
         IF nvl(v_afe_sal_total, 0) <> 0 OR nvl(v_afe_sal_retenido, 0) <> 0 OR
            nvl(v_afe_sal_bloqueado, 0) <> 0 THEN
            pag_cta.pr_obt_cuenta(rp_gmovi.nro_cuenta);
            -- DDSI-212 -- 2017/12 -- Verificar que no se haya insertado como para actualizacion de saldo en batch
            IF nvl(v_exi_movimiento,'N') = 'N' THEN
              --12/03/2018 - Optimizacion - No se actualizara on line SIPAP
              if rp_gmovi.cod_modalidad <> 455 then
                 -- retorno el monto al saldo
                 pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, v_tip_movimiento,
                                       v_fec_ult_mov_ant, v_hor_ult_mov_ant, v_afe_sal_total,
                                       v_afe_sal_retenido, v_afe_sal_bloqueado, NULL,
                                       /* autorizacion pendiente */ v_act_ult_movimiento);
              end if;
            ELSE -- DDSI-212 -- 2017/12 -- Se actualiza el estado en la tabla GE_BAT_MOVIMIENTOS
              UPDATE GE_BAT_MOVIMIENTOS m
                 SET m.est_pro_batch = 'R'
                WHERE m.cod_tra_padre = rp_gmovi.cod_tra_padre
                AND m.fecha = rp_gmovi.fecha
                AND m.monto = rp_gmovi.monto
                AND m.hora = rp_gmovi.hora
                AND m.cod_transaccion = rp_gmovi.cod_transaccion
                AND cod_usuario = rp_gmovi.cod_usuario
                AND nro_cuenta = rp_gmovi.nro_cuenta
                AND m.est_pro_batch = 'N';
            END IF;
            -- Actualizar Saldo Retenido a la Cuenta de deposito.
            /*Se comenta está porción de código; porque ahora se toma el movimiento
            por la liberación automatica para reversar la operación del detalle y con
            esta reversión ya actualiza el saldo retenido*/
            /*If p_cod_tra_padre = 355 then
               Begin
                  Select ab.nro_cuenta,ab.nro_documento,ab.fecha,
                         ab.cod_retencion,ab.cod_modalidad
                     Into v_nro_cta_credito,v_nro_doc_deposito,v_fec_deposito,
                          v_cod_ret_deposito,v_cod_mad_deposito
                     From ge_movimientos ab
                  Where ab.nro_documento = (Select a.nro_doc_referencia
                                            From cj_movimientos a
                                             Where a.cod_usuario = rp_gmovi.cod_usuario
                                             and a.hora = rp_gmovi.hora
                                             and a.cod_tra_padre = p_cod_tra_padre
                                             and a.nro_secuencia = rp_gmovi.nro_secuencia)
                     and ab.cod_mod_padre = 9
                     and ab.cod_mad_padre = 91
                     and ab.cod_tra_padre = 351
                     and ab.cod_transaccion = 606;

                  --Actualiza retenciones
                  Update ah_retenciones
                  Set liberado      = 'N',
                      sal_retenido  = nvl(sal_retenido, 0) + rp_gmovi.monto,
                      lib_posterior = 'N',
                      detallado     = 'N'
                  Where nro_cuenta  = v_nro_cta_credito
                  and nro_documento = v_nro_doc_deposito
                  and fec_inicio    = v_fec_deposito
                  and cod_retencion = v_cod_ret_deposito;
                  --Actualizar Saldo Retenido de la Cta.
                  pag_cta.pr_act_sal_cta(v_nro_cta_credito, v_cod_mad_deposito,'C',
                                         null, null, null,
                                         rp_gmovi.monto, null, NULL,
                                         null);
               EXCEPTION
                  WHEN OTHERS THEN
                     raise_application_error(-20000, 'Al actualizar Saldo Retenido de la Cta. de depóstio.' || SQLERRM);
               End;
            End If;*/
      -- veo si es cda, y si se pago interes o capital
            IF rp_gmovi.cod_modalidad IN (33, 34, 35, 36) THEN
               IF v_tip_movimiento = 'D' THEN
                  IF v_afecta = 'I' THEN
                     -- cupon de interes
                     UPDATE ah_cupones
                        SET fec_pago = NULL,
                            estado   = 'V' -- vuelvo el cupon a vencido
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta
                        AND nro_cupon = rp_gmovi.nro_documento;
                     IF SQL%NOTFOUND THEN
                        raise_application_error(-20000, 'Cupon no existe ');
                     END IF;
                  ELSIF v_afecta = 'C' THEN
                     -- capital
                     UPDATE ah_cta_certificados
                        SET est_certificado = 'V', -- vuelvo el cda a vencido
                            fec_pago        = NULL
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                     IF SQL%NOTFOUND THEN
                        raise_application_error(-20000, 'Certificado no existe ');
                     END IF;
                  END IF;
               END IF;
            END IF;
      -- Verificar si corresponde a Reversión de Cobro de Mov. Pendiente --SPI 3637
            IF rp_gmovi.concepto like 'Aplicación de Mov.Pendiente:%' then
               BEGIN
                  SELECT g.MONTO --Impuesto del movimiento pendiente
                    INTO v_mto_impuesto
                    FROM gv_movimientos g
                   WHERE g.fecha = rp_gmovi.fecha
                     AND g.hora = rp_gmovi.hora
                     AND g.cod_usuario = rp_gmovi.cod_usuario
                     AND g.nro_secuencia = rp_gmovi.nro_secuencia + 1
                     AND g.fec_valor = rp_gmovi.fec_valor
                     and g.NRO_CUENTA = rp_gmovi.nro_cuenta
                     and g.concepto = 'IVA s/Cargos'
                     AND g.monto <> 0
                     AND g.reversado = 'N'
                     AND g.cod_tra_padre = 517;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     v_mto_impuesto:= 0;
               END;


               UPDATE ge_mov_pendientes
                  SET estado = 'I',
                      saldo = nvl(saldo,0) + (nvl(rp_gmovi.monto,0) + nvl(v_mto_impuesto,0))
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND fecha = rp_gmovi.fec_valor
                  AND cod_tra_padre = rp_gmovi.cod_tra_padre
                  AND cod_mod_padre = rp_gmovi.cod_mod_padre
                  AND cod_mad_padre = rp_gmovi.cod_mad_padre
                  AND nvl(substr(to_char(cod_movimiento),length(to_char(cod_movimiento))+1 -15,15),cod_movimiento) = rp_gmovi.nro_documento3
                  AND estado = 'P';

               IF SQL%NOTFOUND THEN
                  raise_application_error(-20000, 'Movimiento pendiente no existe. Cod Mov.: '||rp_gmovi.nro_documento3);
               END IF;
            END IF;
         END IF;
         /*IF (rp_gmovi.cod_modalidad = 43 AND fug_obt_tip_implementacion <> 1) OR --- Reversar cheque emitido
            (rp_gmovi.cod_transaccion = 603 AND fug_obt_tip_implementacion = 1) THEN
            v_msj_cheque := pac_che.fu_eli_che_ger_emi(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento);
            IF v_msj_cheque IS NOT NULL THEN
               raise_application_error(-20000, 'Reversion del Cheq. Gerencia ' || v_msj_cheque);
            END IF;
         END IF;*/
         IF (rp_gmovi.cod_modalidad = 43 AND
            --No debe existir en el grupo de transacciones hija excluidas 203
            fup_exi_gru_transac(fug_obt_pardinamico('TRA_HIJ_REV_EXCLUIDAS'), rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo, rp_gmovi.cod_modalidad ) = 'N' AND
            --No debe existir en el grupo de transacciones padre excluidas 202
            fup_exi_gru_transac(fug_obt_pardinamico('TRA_PAD_REV_EXCLUIDAS'), rp_gmovi.cod_tra_padre, rp_gmovi.cod_modulo, rp_gmovi.cod_modalidad ) = 'N' ) -- Reversar Cheque Emitido
      
          OR (rp_gmovi.cod_modalidad = 43 AND rp_gmovi.cod_transaccion =503 AND
            rp_gmovi.cod_tra_padre IN (305, 311, 329, 358, 1729, 360) and rp_gmovi.referencia is not null) THEN
            -- Rev. Ch.Ger, Pago Cupón o CDA o Desembolso con Ch. Gerencia
            if rp_gmovi.cod_mod_padre <> 28 then--El modulo debe ser diferente a proveedores ya que la emision se elimina mas arriba.
               v_msj_cheque := pac_che.fu_eli_che_ger_emi(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento/*,
                                                       rp_gmovi.referencia*/);

               IF v_msj_cheque IS NOT NULL THEN
                  raise_application_error(-20000, 'Reversion del Cheq. Gerencia ' || v_msj_cheque);
               END IF;
            end if;
         ELSIF rp_gmovi.cod_modalidad = 43 AND rp_gmovi.cod_transaccion in (654, 653, 655) AND
               rp_gmovi.cod_tra_padre = 652  /*AND rp_gmovi.fecha = v_fec_actual*/ THEN
            --depósito de cheques realizados en el día
            --actualiza depósitos de cheques
            BEGIN

               IF rp_gmovi.cod_transaccion <> 655 THEN
                  UPDATE cc_che_enviados
                     SET estado           = 'I',
                         nro_bol_deposito = NULL,
                         nro_cta_deposito = NULL
                   WHERE nro_bol_deposito = rp_gmovi.nro_documento
                     AND nro_cta_deposito = rp_gmovi.nro_cuenta
                     AND estado IN ('C', 'E');
                END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20000, 'Boleta de Depósito inexistente');

            END;
         END IF;
         IF rp_gmovi.cod_tra_padre = 323 AND rp_gmovi.cod_transaccion = 503 AND
            rp_gmovi.cod_tasa IS NULL THEN
            -- emision de cheque certificado
            DECLARE
               v_cta_certificado VARCHAR2(20);
            BEGIN
               IF nvl(pac_che.fu_act_cam_est_che(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento, 'E',
                                                 -- vuelve a emitido
                                                 v_msj_cheque, v_cta_certificado), 'x') <> 'C' THEN
                  raise_application_error(-20000, 'Reversion de Certificacion ' || v_msj_cheque);
               END IF;
            END;
            IF v_msj_cheque IS NOT NULL THEN
               raise_application_error(-20000, 'Reversion de Certificacion ' || v_msj_cheque);
            END IF;
         END IF;
         --Si es cheque pagado por camara, debe reversar el pago
         --DYDMR-2335 ITGF - Reversión de cheques recibidos de cámara - Interior - Trx 3320 SC 19765
         IF rp_gmovi.cod_tra_padre in (320, 3320) AND --CHEQUE PAGADO P/ CAMARA
            rp_gmovi.cod_modulo = 4 AND v_tip_movimiento = 'D' THEN
            -- Rerversion del estado del cheque
            v_msj_cheque := pac_che.fu_rev_pag_cheque(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento,
                                                      rp_gmovi.monto, rp_gmovi.fecha, rp_gmovi.hora);
            IF v_msj_cheque IS NOT NULL THEN
               raise_application_error(-20000, 'Reversion del estado del cheque ' || v_msj_cheque);
            END IF;
            --Borrar de cheques recibidos
            DELETE cc_che_recibidos
             WHERE nro_cheque = rp_gmovi.nro_documento
             AND fec_proceso = r_gmovi.fec_valor
             AND cod_usuario = rp_gmovi.cod_usuario
             AND est_cheque = 'P';
            IF SQL%NOTFOUND THEN
               raise_application_error(-20000,
                                       'Cheque recibido de Camara ya no puede ser reversado: '||rp_gmovi.nro_documento);
            END IF;
            --Actualizar el resumen de cheques recibidos de camara
            UPDATE cc_che_recibidos_res
               SET tot_cheques = nvl(tot_cheques, 0) - nvl(rp_gmovi.monto, 0),
                   can_cheques = can_cheques - 1
             WHERE cod_oficina = rp_gmovi.cod_ofi_origen
               AND cod_banco = rp_gmovi.cod_banco
               AND cod_moneda = rp_gmovi.cod_moneda;
            --Actualizar los montos
            IF rp_gmovi.monto >= to_number(fug_obt_pardinamico('MTO_CHE_RET_CERO', null, null, rp_gmovi.cod_moneda)) THEN
               v_tip_importe := 1;
            ELSE
               v_tip_importe := 0;
            END IF;
            UPDATE cc_sal_camara
               SET sis_che_recibidos = nvl(sis_che_recibidos, 0) - nvl(rp_gmovi.monto, 0)
             WHERE cod_ofi_camara = rp_gmovi.cod_ofi_origen
               AND cod_moneda = rp_gmovi.cod_moneda
               AND fecha = rp_gmovi.fec_valor
               AND tip_importe = v_tip_importe;

         END IF;
      END IF;

      --
      --Si es cheque pagado por cheques hibridos, debe reversar el pago
       IF rp_gmovi.cod_tra_padre = 345 AND --CHEQUE PAGADO EN CAJA DE GNBPY
          rp_gmovi.cod_modulo    = 4   AND
          rp_gmovi.nro_cuenta IS NOT NULL AND
          v_tip_movimiento = 'D' THEN

          --desde el GMAPRAUT ya realiza el reverso del cheque y actualizacion de la tabla cc_che_hibridos
          -- por eso solo en caso que se reverse desde otro programa el movimiento o el estado sea Normal
          -- reversamos el estado del cheque y se actualizan las tablas
          if ((rp_gmovi.estado = 'X' and pae_cnf.G_PROGRAMA <> 'GMAPRAUT') or rp_gmovi.estado = 'N') then

              -- Rerversion del estado del cheque
              v_msj_cheque := pac_che.fu_rev_pag_cheque(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento,
                                                        rp_gmovi.monto, rp_gmovi.fecha, rp_gmovi.hora);
              IF v_msj_cheque IS NOT NULL THEN
                 raise_application_error(-20000, 'Reversion del estado del cheque ' || v_msj_cheque);
              END IF;
              -- actualizo la tabla hibridos
              update cc_che_hibridos
                  set situacion = 'V'
              where fecha      = rp_gmovi.fecha
                and hora         = rp_gmovi.hora
                and cod_usuario = rp_gmovi.cod_usuario
                and nro_cheque  =  rp_gmovi.nro_documento
                and situacion   <> 'R';
              -- pedido reversado
              if rp_gmovi.estado = 'X' then
                UPDATE ge_aut_pedidos
                  SET respuesta   = 'R',
                      estado      = 'A',
                      observacion = 'Reversado desde ' ||pae_cnf.G_PROGRAMA
                WHERE fecha = rp_gmovi.fecha
                  AND hora = rp_gmovi.hora
                  AND cod_usuario = rp_gmovi.cod_usuario
                  AND respuesta <> 'R';
              end if;
          end if;
       END IF;
       --- HASTA ACA UPD POR CHEQUES HIBRIDOS


      --
      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.estado IN ('P', 'X', 'J') AND --- Los movimientos 'J' no actualizan la cuenta
         rp_gmovi.monto <> 0 AND r_gmovi.cod_modulo IN (3, 4) AND
         --CROEFEBCO-28: Mejoras en la Operativa de Efectivo
         (r_gmovi.cod_mod_padre IN (3, 4, 5, 9) or (r_gmovi.cod_mod_padre = 7 and r_gmovi.cod_mad_padre in (71,72)
          and r_gmovi.cod_transaccion = 606)) THEN
         /* solo reversa ahorros por ahora */
         IF v_fec_ult_mov_ant IS NOT NULL THEN
            v_act_ult_movimiento := 'S'; -- debe actualizar la fecha y hora
         END IF;
         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         IF v_tip_movimiento = 'D' THEN
            -- si es un debito
            -- control de llaveo de cuenta DYDMR-3263
            IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad, rp_gmovi.nro_cuenta, v_es_nocturno) = 'N' THEN
              -- cuenta llaveada
              raise_application_error(-20000, 'Cuenta ' || rp_gmovi.nro_cuenta || ' llaveada ');
            END IF;

            -- retorno el monto al saldo
            pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, 'D', rp_gmovi.fecha,
                                   rp_gmovi.hora, 0, 0, rp_gmovi.monto,
                                   -- el saldo bloqueado
                                   NULL, /* autorizacion pendiente */ v_act_ult_movimiento);
            IF rp_gmovi.estado = 'X' AND rp_gmovi.cod_tra_padre = 354 THEN
               UPDATE ge_aut_pedidos
                  SET respuesta   = 'R',
                      estado      = 'A',
                      observacion = p_concepto
                WHERE fecha = rp_gmovi.fecha
                  AND hora = rp_gmovi.hora
                  AND cod_usuario = rp_gmovi.cod_usuario
                  AND respuesta <> 'R';
            END IF;
         END IF;
      END IF;
      --operaciones de cambios, sólo las q debitan ctas se reversan porque los movimientos
      --se generan en estado J y no se reversan x el proceso normal, el resto sique el circuito normal
      IF rp_gmovi.cod_mod_padre = 7 THEN
         IF rp_gmovi.fecha < v_fec_actual THEN
            raise_application_error(-20000,
                                    'No se pueden reversar movimientos históricos de Cambios');
         END IF;
         IF rp_gmovi.monto <> 0 AND rp_gmovi.cod_transaccion IN (503, 190) AND --sólo débito de ctas.
            rp_gmovi.cod_modulo IN (3, 4) THEN
            IF rp_gmovi.estado IN ('J', 'P', 'X') THEN
               --actualizar saldo bloqueado
               IF pag_cta.fu_llavear_cuenta(rp_gmovi.cod_modalidad, rp_gmovi.nro_cuenta, v_es_nocturno) = 'N' THEN
                  -- cuenta llaveada
                  raise_application_error(-20000, 'Cuenta ' || rp_gmovi.nro_cuenta || ' llaveada ');
               END IF;
               -- retorno el monto al saldo
               pag_cta.pr_act_sal_cta(rp_gmovi.nro_cuenta, rp_gmovi.cod_modalidad, 'D',
                                      rp_gmovi.fecha, rp_gmovi.hora, 0, 0, rp_gmovi.monto,
                                      -- el saldo bloqueado
                                      NULL, /* autorizacion pendiente */ v_act_ult_movimiento);
            END IF;
         END IF;
         IF rp_gmovi.estado = 'X' THEN
            UPDATE ge_aut_pedidos
               SET respuesta   = 'R',
                   estado      = 'A',
                   observacion = p_concepto
             WHERE fecha = rp_gmovi.fecha
               AND hora = rp_gmovi.hora
               AND cod_usuario = rp_gmovi.cod_usuario
               AND respuesta <> 'R';
         END IF;
         --reversar la posición de cambios, solo el estado Normal actualiza posición
         IF rp_gmovi.monto <> 0 AND
            (rp_gmovi.nro_secuencia = 1 OR --el mov. principal
            (rp_gmovi.nro_secuencia = 2 AND rp_gmovi.cod_mad_padre IN (73, 74))) AND --cualquiera de canje o arb
            rp_gmovi.estado = 'N' THEN
            pal_cam.pr_act_posiciones(rp_gmovi.cod_tip_ope_cambio, rp_gmovi.cod_moneda,
                                      pal_cam.fu_obt_ofi_cambio(rp_gmovi.cod_ofi_origen),
                                      r_gmovi.monto, r_gmovi.mto_equ_local, rp_gmovi.cod_bco_central);
         END IF;
         --eliminar operaciones pendientes,no importa el estado N,J,X
         --ya no se elimina, se actualiza. 13/09/05

         IF rp_gmovi.monto <> 0 AND
            (rp_gmovi.nro_secuencia = 1 OR --el mov. principal
            (rp_gmovi.nro_secuencia = 2 AND rp_gmovi.cod_mad_padre IN (73, 74))) THEN
            --cualquiera de canje o arb
            IF rp_gmovi.nro_secuencia = 1 THEN
               --el mov. principal
               --delete lc_ope_pendientes
               UPDATE lc_ope_pendientes
                  SET liquidado           = 'N',
                      cod_usu_liquidacion = NULL,
                      fec_liquidacion     = NULL
                WHERE nro_operacion = rp_gmovi.nro_documento;

                --Proyecto DDARBDIG-1-Arbitraje Digital----
                UPDATE lc_ope_pen_cambios
                  SET liquidado           = 'N',
                      cod_usu_liquidacion = NULL,
                      fec_liquidacion     = NULL
                WHERE nro_operacion = rp_gmovi.nro_documento;
            END IF;
            --si es compra o venta de transferencia,eliminar la misma
            v_transferencia := NULL;
            v_afe_libranza  := NULL;
            v_mad_hijo      := NULL;
            BEGIN
               SELECT afe_transferencia, afe_libranza, cod_mad_hijo
                 INTO v_transferencia, v_afe_libranza, v_mad_hijo
                 FROM lc_tip_ope_oficinas b, lc_tip_operaciones a
                WHERE b.cod_tip_operacion = a.cod_tip_operacion
                  AND a.cod_tip_operacion = rp_gmovi.cod_tip_ope_cambio
                  AND nivel = 1
                  AND b.cod_oficina = rp_gmovi.cod_ofi_origen
                  AND b.cod_moneda = rp_gmovi.cod_moneda;
               IF v_transferencia = 'S' THEN
                  IF v_mad_hijo = 72 THEN
                       --WA:01/11/2014 Si es TTE WEB, buscamos el Nro de referencia
                        if r_gmovi.cod_usuario= 'HBANK' then
                           v_nro_referencia:=null;
                           begin
                             select a.nro_referencia
                                into v_nro_referencia
                                 from lc_transferencias a
                                   where a.nro_operacion=to_number(r_gmovi.nro_documento)
                                    and a.cod_modalidad = 72;
                           exception
                             when no_data_found then
                                 v_nro_referencia:=null;
                             when others then
                                 v_nro_referencia:=null;
                           end;

                        end if;
                         --Para DNA, Reversamos la TTE
                         begin
                             select a.nro_ord_pag_dna, b.nro_documento,b.cod_tip_documento
                                into v_ord_pag_dna,v_nro_doc_cliente,v_tip_doc_cliente
                                 from lc_transferencias a, ba_personas b
                                   where a.nro_operacion=to_number(r_gmovi.nro_documento)
                                          and a.cod_per_solicitante=b.cod_persona;
                           exception
                             when no_data_found then
                                 v_ord_pag_dna:=null;
                             when others then
                                 v_ord_pag_dna:=null;
                           end;
                        if  v_ord_pag_dna is not null then
                          begin
                              --grabamos la reversion
                              pal_tra.PR_REV_DNA(v_ord_pag_dna,
                              v_nro_doc_cliente,
                              v_tip_doc_cliente,
                              'Reversado por Entidad', v_respuesta_DNA,v_error_DNA );
                          exception
                            when others then
                                 null;
                          end;

                        end if;

                     --vta,arb,cje
                     DELETE FROM lc_transferencias
                      WHERE nro_operacion = to_number(r_gmovi.nro_documento)
                        AND cod_modalidad = 72
                     RETURNING fec_envio INTO v_fec_envio;
                     IF v_fec_envio IS NOT NULL THEN
                        raise_application_error(-20000,
                                                'No puede reversar. La Transferencia ha sido enviada.');
                     ELSE
                        --cargar variables para envío de mail
                        v_ope_cambios := r_gmovi.cod_tip_ope_cambio;
                        v_nro_transf  := to_number(r_gmovi.nro_documento);

                        --WA:01/11/2014 Si es TTE WEB, anulamos el movimiento en HB
                        if r_gmovi.cod_usuario= 'HBANK' and v_nro_referencia is not null then
                              --Verificar como anulamos
                              update bw_mov_pendientes W
                              set W.estado = 'A'
                               where trunc(W.fec_hora) = v_fec_actual
                                and w.referencia= v_nro_referencia
                                and w.cod_tip_mensaje='227'; --227 para TTE/HB
                        end if;

                     END IF;
                  ELSE
                     --compra
                     --eliminar la transferencia
                     DELETE lc_transferencias
                      WHERE cod_tip_referencia = rp_gmovi.cod_ref_cambio
                        AND nro_referencia = rp_gmovi.nro_documento2;
                  END IF;
               END IF;
               --actualizar la libranza, sólo si no fue enviada aún
               IF v_afe_libranza = 'S'
                THEN
                  DECLARE
                     v_enviada VARCHAR2(1);
                  BEGIN
                     SELECT enviada
                       INTO v_enviada
                       FROM lc_transferencias
                      WHERE cod_tip_referencia = rp_gmovi.cod_ref_cambio
                        AND nro_referencia = rp_gmovi.nro_documento2;
                     IF nvl(v_enviada, 'N') = 'S' THEN
                        raise_application_error(-20000,
                                                'No puede reversar. Ya se realizó el envío de mail de transferencias confirmadas.');
                     ELSE
                        -- actualizar
                        UPDATE lc_transferencias
                           SET saldo         = nvl(saldo, 0) + rp_gmovi.monto,
                               estado        = nvl(est_anterior, estado),
                               nro_operacion = NULL,
                               est_anterior  = NULL
                         WHERE cod_tip_referencia = rp_gmovi.cod_ref_cambio
                           AND nro_referencia = rp_gmovi.nro_documento2;
                     END IF;
                  EXCEPTION
                     WHEN no_data_found THEN
                        raise_application_error(-20000,
                                                'No existe Transf. a Reversar ' ||
                                                 rp_gmovi.cod_ref_cambio || '-' ||
                                                 rp_gmovi.nro_documento2);
                     WHEN OTHERS THEN
                        IF SQLCODE <= -20000 THEN
                           RAISE;
                        ELSE
                           raise_application_error(-20000,
                                                   'Recup. Transf. a Reversar ' ||
                                                    rp_gmovi.cod_ref_cambio || '-' ||
                                                    rp_gmovi.nro_documento2 || '.' || SQLERRM);
                        END IF;
                  END;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  IF SQLCODE <= -20000 THEN
                     RAISE;
                  ELSE
                     NULL;
                  END IF;
            END;
         END IF;
         -- eliminar la retención, reversar el límite de la cta de cambios
         IF rp_gmovi.monto <> 0 AND rp_gmovi.cod_transaccion = 760 THEN
            --afectación de límite
            --eliminar retención
            DELETE lc_retenciones
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND liberado = 'N'
               AND nro_boleta = rp_gmovi.nro_documento;
            --actualizar cta
            BEGIN
               UPDATE lc_cta_cambios
                  SET mto_utilizado = nvl(mto_utilizado, 0) + r_gmovi.monto
                WHERE nro_cuenta = rp_gmovi.nro_cuenta;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, 'Actualiza Límite Cuenta ' || rp_gmovi.nro_cuenta);
            END;
         END IF;
         -- Modifica Estado Operaciones Futuras
         IF rp_gmovi.cod_ref_cambio = 76 AND rp_gmovi.nro_secuencia = 1 THEN
            BEGIN
               UPDATE lc_ope_futuras c
                  SET c.fec_liquidacion  = NULL,
                      c.mto_utilizado    = 0,
                      c.estado           = 'N'
                WHERE c.cod_persona      = rp_gmovi.cod_persona
                  AND c.fec_liquidacion  = rp_gmovi.fecha
                  AND c.usu_modificacion = rp_gmovi.cod_usuario
                  AND c.estado           = 'L'
                  AND c.nro_referencia   = rp_gmovi.nro_documento2; -- RABP/09-2016/DYDMR-5027
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20002,
                                          'Actualiza Operación Futura ' || rp_gmovi.nro_documento2);
            END;
         END IF;
      END IF; --hasta aquí oper. cambios
      ----comex, cci y cobranzas
      IF rp_gmovi.cod_mod_padre = 8 THEN
         --utilización
         IF rp_gmovi.cod_tra_padre = 890 AND rp_gmovi.cod_mad_padre IN (81, 82) AND
            rp_gmovi.nro_secuencia = 1 THEN
            --utilización
            BEGIN
               SELECT '*'
                 INTO v_pagado
                 FROM cx_embarques
                WHERE nvl(mto_utilizado,0) <> nvl(saldo, 0) --no fue pagada ninguna porción
                  AND nro_embarque = rp_gmovi.nro_documento2
                  AND nro_cuenta = rp_gmovi.nro_cuenta;
               IF v_pagado IS NOT NULL THEN
                  raise_application_error(-20000,
                                          'El Embarque ' || rp_gmovi.nro_documento2 ||
                                           ' posee pagos/cobros totales o parciales. Debe reversar primero éstos movimientos');
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
            END;
            --deshacer el embarque y las cuotas
            DELETE cx_cuotas
             WHERE nro_embarque = rp_gmovi.nro_documento2
               AND nro_cuenta = rp_gmovi.nro_cuenta;
            DELETE cx_embarques
             WHERE nro_embarque = rp_gmovi.nro_documento2
               AND nro_cuenta = rp_gmovi.nro_cuenta;
            --actualizar el mto_utilizado
            IF rp_gmovi.cod_mad_padre = 81 THEN
               UPDATE cx_cta_importaciones
                  SET mto_utilizado = nvl(mto_utilizado, 0) - rp_gmovi.monto
                WHERE nro_cuenta = rp_gmovi.nro_cuenta;
            ELSE
               UPDATE cx_cta_exportaciones
                  SET mto_utilizado = nvl(mto_utilizado, 0) - rp_gmovi.monto
                WHERE nro_cuenta = rp_gmovi.nro_cuenta;
            END IF;
         END IF;
         IF rp_gmovi.cod_tra_padre IN (368, 384) AND rp_gmovi.nro_secuencia = 1 THEN
            --cobro y pago (cci,cobranza,cce)
            IF rp_gmovi.monto <> 0 THEN
               --actualizar carta de crédito, SALDO
               IF rp_gmovi.nro_documento3 IS NOT NULL THEN
                  --tiene cuotas, sólo cci y cce
                  --sólo se puede deshacer el último embarque, en orden

                  /* PN 17/05/2014 SC 5212: Se comenta debido a que no es necesario ya que los embarques no se
                                    pagan en forma secuencial*/
                   BEGIN
                     SELECT nvl(MAX(nro_embarque), 0)
                       INTO v_ult_embarque
                       FROM cx_cuotas
                      WHERE monto <> nvl(saldo, 0) --algo pagado
                        AND nro_cuenta = rp_gmovi.nro_cuenta;
                     IF rp_gmovi.nro_documento2 < v_ult_embarque THEN
                        raise_application_error(-20000,
                                                'Existen Embarques posteriores que deben ser reversados previamente.');
                     END IF;
                  END;
                  IF rp_gmovi.cod_mad_padre = 81 THEN
                     --actualiza saldo de la cci
                     UPDATE cx_cta_importaciones
                        SET saldo = nvl(saldo, 0) + rp_gmovi.monto
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                  ELSIF rp_gmovi.cod_mad_padre = 82 THEN
                     --actualiza saldo de la cce
                     UPDATE cx_cta_exportaciones
                        SET saldo = nvl(saldo, 0) + rp_gmovi.monto
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                  END IF;
                  --deshacer la cuota
                  UPDATE cx_cuotas
                     SET saldo  = nvl(saldo, 0) + rp_gmovi.monto,
                         estado = decode(monto, saldo, estado, 'N') --vuelve a pendiente, con la primera porción q reversa
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND nro_cuota = rp_gmovi.nro_documento3;
                  --deshacer el embarque
                  UPDATE cx_embarques
                     SET saldo  = nvl(saldo, 0) + rp_gmovi.monto,
                         estado = decode(mto_utilizado, saldo, estado, 'N') --vuelve a pendiente, con la primera porción q reversa
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND nro_embarque = rp_gmovi.nro_documento2;

               ELSIF rp_gmovi.cod_mad_padre IN (83, 84) THEN
                  --actualiza saldo de la cobranza
                  UPDATE cx_cta_cobranzas
                     SET saldo = nvl(saldo, 0) + rp_gmovi.monto
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta;
               END IF;
               IF rp_gmovi.cod_mad_padre = 81 THEN
                  ----si tiene límite recalcular, sólo cci
                  DECLARE
                     v_linea cx_cta_importaciones.nro_linea%TYPE;
                  BEGIN
                     SELECT nro_linea
                       INTO v_linea
                       FROM cx_cta_importaciones
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                     IF v_linea IS NOT NULL THEN
                        prp_rec_apl_limite(v_linea);
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        NULL;
                  END;
               END IF;
            END IF;
         END IF;
         --cancelación, actualizar el saldo, cci, cce, cobranzas
         IF rp_gmovi.cod_tra_padre = 380 THEN
            IF rp_gmovi.monto <> 0 THEN
               IF rp_gmovi.cod_mad_padre = 81 AND rp_gmovi.cod_transaccion IN (378, 379) THEN
                  --actualizar el saldo, el estado se hace x novedad
                  UPDATE cx_cta_importaciones
                     SET saldo = nvl(saldo, 0) + rp_gmovi.monto
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta;
               ELSIF rp_gmovi.cod_mad_padre = 81 and rp_gmovi.cod_transaccion = 711 then
                 BEGIN
                   select sum(nvl(m.monto,0))
                     into v_sal_cta_imp
                     from ge_movimientos m
                    where m.fecha = rp_gmovi.fecha
                      and m.hora = rp_gmovi.hora
                      and m.cod_usuario = rp_gmovi.cod_usuario
                      and m.cod_mod_padre = 8
                      and m.cod_mad_padre = 81
                      and m.cod_tra_padre = 380
                      and m.cod_transaccion in (875, 602);
                  EXCEPTION
                    WHEN OTHERS THEN
                      v_sal_cta_imp := 0;
                  END;

                  BEGIN
                    select nro_documento
                      into v_cta_importacion
                      from md_cta_documentos d
                     where d.nro_cuenta = rp_gmovi.nro_cuenta;
                  EXCEPTION
                    WHEN OTHERS THEN
                      v_cta_importacion := null;
                  END;

                  UPDATE cx_cta_importaciones i
                     set i.saldo = nvl(i.saldo, 0) + nvl(v_sal_cta_imp,0)
                   WHERE i.nro_cuenta = v_cta_importacion;

               ELSIF rp_gmovi.cod_mad_padre IN (83, 84) AND rp_gmovi.cod_transaccion IN (378, 379) THEN
                  --actualizar el saldo, el estado se hace x novedad
                  UPDATE cx_cta_cobranzas
                     SET saldo = nvl(saldo, 0) + rp_gmovi.monto
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta;
               ELSIF rp_gmovi.cod_mad_padre = 82 AND
                     rp_gmovi.cod_transaccion IN (376, 377, 378, 379) THEN
                  --actualizar el saldo, el estado se hace x novedad
                  UPDATE cx_cta_exportaciones
                     SET saldo = nvl(saldo, 0) + rp_gmovi.monto
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta;
               END IF;
               --
               -- reverso las cuotas y embarques en forma dinamica
               prg_rev_auditoria('CX_EMBARQUES', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                                 rp_gmovi.nro_cuenta);
               prg_rev_auditoria('CX_CUOTAS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                                 rp_gmovi.nro_cuenta);
               --
            END IF;
         END IF;
         --CNFVAR-57 Cancelación de Saldo no utilizado CCI Fecha: 01/02/2017
         -- Reverso de Cancelacion de Saldo no Utilizado CCI
         IF rp_gmovi.cod_tra_padre = 381 THEN
            IF rp_gmovi.monto <> 0 THEN
               IF rp_gmovi.cod_mad_padre = 81 AND rp_gmovi.cod_transaccion = 378 THEN
                  --Actualizar el saldo
                  UPDATE cx_cta_importaciones
                     SET saldo = nvl(saldo, 0) + rp_gmovi.monto
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta;

                  --Eliminar registro de monto no utilizado cancelado de la tabla BA_TAB_DAT_ADICIONALES
                  DELETE from ba_tab_dat_adicionales
                  WHERE referencia = rp_gmovi.nro_cuenta
                    AND tab_relacion = 'CX_CTA_IMPORTACIONES'
                    AND parametro = 'SAL_NO_UTI_CANCELADO';
                END IF;
             END IF;
         END IF;
         --
         -- Cuotas de Comision de Fianzas Recibidas y Emitidas
         IF rp_gmovi.cod_mad_padre IN (88, 89) AND rp_gmovi.cod_tra_padre = 580 THEN
            UPDATE cx_fia_comisiones x
               SET x.saldo  = nvl(x.saldo, 0) + rp_gmovi.monto,
                   x.estado = 'A'
             WHERE x.cod_fianza = rp_gmovi.nro_documento
               AND x.nro_cuota = rp_gmovi.nro_documento2;
         END IF;
         IF rp_gmovi.cod_transaccion = 845 AND rp_gmovi.cod_mad_padre = 81 THEN
            --contra préstamo
            IF rp_gmovi.monto <> 0 THEN
               --recupera los datos del préstamo relacionado
               prx_obt_pre_cci(rp_gmovi.nro_cuenta, rp_gmovi.nro_documento3, 'S', v_nro_sol_cci,
                               v_nro_cta_cci);
               IF v_nro_sol_cci IS NOT NULL THEN
                  BEGIN
                     SELECT estado
                       INTO v_est_solicitud
                       FROM pr_solicitudes
                      WHERE nro_solicitud = v_nro_sol_cci;
                     IF v_est_solicitud IN ('L', 'S') THEN
                        --sólo si no se desembolsó aún
                        --desasociar de la cci y cuota
                        BEGIN
                           --actualizar cci con la máxima cuota pagada en préstamo anterior a la q se reversa
                           UPDATE cx_cta_importaciones
                              SET nro_sol_prestamo = (SELECT a.nro_sol_prestamo
                                                        FROM cx_cuotas a
                                                       WHERE a.nro_cuenta = rp_gmovi.nro_cuenta
                                                         AND a.nro_cuota =
                                                             (SELECT MAX(b.nro_cuota)
                                                                FROM cx_cuotas b
                                                               WHERE b.nro_cuenta = a.nro_cuenta
                                                                 AND estado = 'P'
                                                                 AND nro_sol_prestamo IS NOT NULL
                                                                 AND nro_cuota <
                                                                     rp_gmovi.nro_documento3))
                            WHERE nro_sol_prestamo = v_nro_sol_cci
                              AND nro_cuenta = rp_gmovi.nro_cuenta;
                           --actualizar la cuota
                           UPDATE cx_cuotas
                              SET nro_sol_prestamo = NULL
                            WHERE nro_sol_prestamo = v_nro_sol_cci
                              AND nro_cuenta = rp_gmovi.nro_cuenta;
                           --
                           IF SQL%NOTFOUND THEN
                              --actualizar la cci
                              UPDATE cx_cta_importaciones
                                 SET nro_sol_prestamo = NULL
                               WHERE nro_sol_prestamo = v_nro_sol_cci
                                 AND nro_cuenta = rp_gmovi.nro_cuenta;
                           END IF;
                        END;
                     ELSIF v_est_solicitud = 'A' THEN
                        --desembolsada
                        raise_application_error(-20301,
                                                'Solicitud relacionada ' || v_nro_sol_cci ||
                                                 ' ya fue desembolsada. No se puede reversar.');
                     ELSE
                        raise_application_error(-20301,
                                                'Estado de la Solicitud relacionada ' ||
                                                 v_nro_sol_cci || ' no permite reversar.');
                     END IF;
                  EXCEPTION
                     WHEN no_data_found THEN
                        NULL;
                     WHEN OTHERS THEN
                        IF SQLCODE <= -20000 THEN
                           RAISE;
                        ELSE
                           raise_application_error(-20303,
                                                   'No se pudo actualizar solicitud prést. relacionada ' ||
                                                    v_nro_sol_cci);
                        END IF;
                  END;
               END IF;
            END IF;
         END IF;
      END IF;
      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 5
         and rp_gmovi.cod_tra_padre <> 945 THEN  -- DYDMR-5128 OMM OCT/2016
         --Obtener el tipo de procesadora
      begin
        SELECT tip.cod_ent_procesadora
          INTO v_cod_procesadora
          FROM ( SELECT DISTINCT
                  S.COD_ENT_PROCESADORA,
                  S.COD_MODALIDAD,
                  S.AFINIDAD
                  FROM  IT.TA_TIPOS S) tip, 
                        ta_cta_tarjetas ta
        WHERE tip.afinidad = ta.afinidad
          AND ta.nro_cuenta = rp_gmovi.nro_cuenta;
      exception
        when others then
          raise_application_error(-20000, 'No se encuentra codigo de procesadora '||sqlerrm);
      end;
      IF v_cod_procesadora = fug_obt_pardinamico('COD_PRO_BANCARD') THEN
        --Verificar que el pago no se haya enviado ya a BANCARD
        BEGIN
          SELECT est_envio, nro_tarjeta  --DYDMR-4001 recupera el nro de tarjeta (ALV - jul/2016)
            INTO v_est_envio, v_nro_tarjeta
            FROM ta_cobros
           WHERE fec_proceso = rp_gmovi.fecha
             AND nro_cuenta = rp_gmovi.nro_cuenta
             AND monto = rp_gmovi.monto
             AND estado IN ('P', 'C');
        EXCEPTION
          WHEN no_data_found THEN
            v_est_envio := 'N'; --No buscar en ta_cobros
          WHEN too_many_rows THEN
            raise_application_error(-20001,
                                    'Mas de un registro para' || ' Cuenta: ' ||
                                    rp_gmovi.nro_cuenta || ' Monto: ' || rp_gmovi.monto);
          WHEN OTHERS THEN
            raise_application_error(-20001,
                                    SQLERRM || ' Cuenta: ' || rp_gmovi.nro_cuenta ||
                                    ' Monto: ' || rp_gmovi.monto);
        END;
        IF v_est_envio in ('E','W') THEN --DYDMR-4001 Se agrega el EST_ENVIO = W (enviado via WS)-(ALV - jul/2016)
        --Enviado dar error
          if pae_cnf.G_PROGRAMA <> 'GPPROFIN' then
            raise_application_error(-20002,
                                    'Cobro ya enviado a la procesadora ' || ' Cuenta: ' ||
                                     rp_gmovi.nro_cuenta || ' Monto: ' || rp_gmovi.monto ||
                                     '. Notificar al Dpto. Operaciones.');
          else
            lp_env_mov_cob_pen(rp_gmovi.nro_cuenta, rp_gmovi.monto, rp_gmovi.concepto, rp_gmovi.cod_moneda);
          END IF;
        END IF;
        -- verifica si la reversion es de un deposito en efectivo o una
         -- liberacion de retencion para borrar el cobro
         -- AGREGAGO EL BORRADO DE LA 607 PORQUE CHEQUES SE ENVIA
         -- A LA PROCESADORA COMO EFECTIVO
         -- DYDMR-2249 ITGF - Reversar Pago Duplicado SC 18829
         --IF rp_gmovi.cod_transaccion IN (606, 607, 690, 515, 978, 613) THEN
        IF NVL(FUP_EXI_GRU_TRANSAC(14,rp_gmovi.cod_transaccion,5,51),'N') = 'S' THEN
          DELETE FROM ta_cobros
                WHERE fec_proceso = rp_gmovi.fecha
                  AND (hora = p_hora OR hora IS NULL OR rp_gmovi.cod_transaccion in (613,614))
                  AND ((cod_usuario = p_cod_usuario and hora = p_hora) OR
                      (cod_usuario IS NULL AND rp_gmovi.cod_transaccion in (613,614)))
                  AND nro_cuenta = rp_gmovi.nro_cuenta
                  AND monto = rp_gmovi.monto
                  AND estado IN ('P', 'C');

         /*DYDMR-4695 Se cambia el momento en el que se eliminan los registros de GE_PAR_WEB_SERVICIOS al ELSE de IF SQL%NOTFOUND (ALV-set/2016)*/

            --Si no encuentro el registro veo si la liberacion cargo ta_cobros
            IF SQL%NOTFOUND THEN
               BEGIN
                  SELECT e.cod_usuario, to_char(e.fec_insercion, 'hh24:mi:ss')
                    INTO v_cod_usu_lib, v_hora_insercion
                    FROM ge_movimientos e
                   WHERE e.nro_cuenta = rp_gmovi.nro_cuenta
                     AND e.nro_documento = rp_gmovi.nro_documento
                     AND e.fecha = rp_gmovi.fecha
                     AND e.monto = rp_gmovi.monto
                     AND e.cod_transaccion IN (515, 565, 560);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_cod_usu_lib    := NULL;
                     v_hora_insercion := NULL;
               END;
               --busco si se envio o no el registro de TA_COBROS
               BEGIN
                  SELECT est_envio, nro_tarjeta
                    INTO v_est_envio, v_nro_tarjeta --DYDMR-4001 recupera el nro de tarjeta (ALV - jul/2016)
                    FROM ta_cobros
                   WHERE fec_proceso = rp_gmovi.fecha
                     AND nro_cuenta = rp_gmovi.nro_cuenta
                     AND monto = rp_gmovi.monto
                     AND estado IN ('P', 'C')
                     AND usu_insercion = v_cod_usu_lib
                     AND to_char(fec_insercion, 'hh24:mi:ss') = v_hora_insercion;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_est_envio := 'N'; --No buscar en ta_cobros
                  WHEN too_many_rows THEN
                     raise_application_error(-20001,
                                             'Mas de un registro para' || ' Cuenta:' ||
                                              rp_gmovi.nro_cuenta || ' Monto:' || rp_gmovi.monto ||
                                              ' Usu_insercion: ' || v_cod_usu_lib ||
                                              ' Hora_insercion: ' || v_hora_insercion);
                  WHEN OTHERS THEN
                     raise_application_error(-20001,
                                             SQLERRM || ' Cuenta:' || rp_gmovi.nro_cuenta ||
                                              ' Monto:' || rp_gmovi.monto || ' Usu_insercion: ' ||
                                              v_cod_usu_lib || ' Hora_insercion: ' ||
                                              v_hora_insercion);
               END;
               IF v_est_envio = 'P' THEN
                  --P=Pendiente, se  puede borrar
                  DELETE FROM ta_cobros
                   WHERE fec_proceso = rp_gmovi.fecha
                     AND nro_cuenta = rp_gmovi.nro_cuenta
                     AND monto = rp_gmovi.monto
                     AND estado IN ('P', 'C')
                     AND usu_insercion = v_cod_usu_lib
                     AND to_char(fec_insercion, 'hh24:mi:ss') = v_hora_insercion;

                   --DYDMR-4001 Se elimina tambien el registro en la tabla GE_PAR_WEB_SERVICIOS (ALV - jul/2016)
                   delete from ge_par_web_servicios p
                    where p.fecha = rp_gmovi.fecha
                      and p.estado = 'P'
                      and substr(p.dat_enviados, 12, 16) = v_nro_tarjeta
                      and to_char(p.fec_insercion, 'hh24:mi:ss') = v_hora_insercion; /*DYDMR-4695 Se utiliza la hora de insercion de los registros para cobros con cheque CNB (ALV-set/2016)*/
               ELSIF v_est_envio IN ('E','W') THEN --DYDMR-4001 Se agrega el EST_ENVIO = W (enviado via WS)-(ALV - jul/2016)
                  --Enviado dar error
                  IF pae_cnf.G_PROGRAMA <> 'GPPROFIN' THEN
                     raise_application_error(-20002,
                                            'Cobro ya enviado a la procesadora ' || ' Cuenta:' ||
                                             rp_gmovi.nro_cuenta || ' Monto:' || rp_gmovi.monto ||
                                             ' Usu_insercion: ' || v_cod_usu_lib ||
                                             ' Hora_insercion: ' || v_hora_insercion);
                  ELSE
                    lp_env_mov_cob_pen(rp_gmovi.nro_cuenta, rp_gmovi.monto, rp_gmovi.concepto, rp_gmovi.cod_moneda);
                  END IF;
               END IF;
            ELSE --DYDMR-4695 Si no encuentra el registro correspondiente a una liberación. (ALV-set/2016)
              --DYDMR-4001 Se elimina tambien el registro en la tabla GE_PAR_WEB_SERVICIOS (ALV - jul/2016)
                delete from ge_par_web_servicios p
                 where p.fecha = rp_gmovi.fecha
                   and p.estado = 'P'
                   and substr(p.dat_enviados,12,16) = v_nro_tarjeta
                   and to_char(p.fec_insercion, 'hh24:mi:ss') = p_hora;
            END IF;
         END IF;
       ELSIF v_cod_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL') THEN
   --Obtener el estado del envio a la procesadora
             BEGIN
                SELECT est_envio, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
                       hora, cod_usuario, dia_mora
                  INTO v_est_envio, r_tacobros_gp.nro_tarjeta, r_tacobros_gp.nro_cta_debito, r_tacobros_gp.fec_proceso, r_tacobros_gp.monto,
                       r_tacobros_gp.estado, r_tacobros_gp.fec_valor, r_tacobros_gp.observacion, r_tacobros_gp.hora, r_tacobros_gp.cod_usuario,
                       r_tacobros_gp.dia_mora
                  FROM ta_cobros_gp
                 WHERE fec_proceso = rp_gmovi.fecha
                   AND hora = p_hora
                   AND cod_usuario = p_cod_usuario
                   AND nro_cuenta = rp_gmovi.nro_cuenta
                   AND monto = rp_gmovi.monto
                   AND estado IN ('P', 'C','E');
             EXCEPTION
               WHEN no_data_found THEN
                 v_est_envio := 'N';
               WHEN OTHERS THEN
                 IF rp_gmovi.cod_transaccion <> 607 THEN
                   raise_application_error(-20000, 'No existe el Cobro');
                 END IF;
             END;
             IF nvl(v_pag_lin_habilitado,'N') = 'N' THEN
               IF v_est_envio = 'E' THEN
                 raise_application_error(-20000, 'Cobro enviado a la procesadora no puede reversarse');
               ELSIF v_est_envio = 'P' THEN
                 DELETE FROM ta_cobros_gp
                  WHERE fec_proceso = rp_gmovi.fecha
                    AND hora = p_hora
                    AND cod_usuario = p_cod_usuario
                    AND nro_cuenta = rp_gmovi.nro_cuenta
                    AND monto = rp_gmovi.monto
                    AND estado IN ('P', 'C');
               END IF;

             ELSIF nvl(v_pag_lin_habilitado,'N') = 'S' THEN
                 --insertar la reversion en ta_cobros
                 --si es cheque y aun no ha sido liberado no se inserta en ta_cobros

               IF rp_gmovi.cod_retencion IS NOT NULL AND rp_gmovi.fec_fin_retencion IS NOT NULL THEN
                 SELECT liberado
                   INTO v_liberado
                   FROM ah_retenciones
                  WHERE nro_cuenta = rp_gmovi.nro_cuenta
                    AND nro_documento = rp_gmovi.nro_documento;
               END IF;

               IF ((rp_gmovi.cod_retencion IS NULL AND rp_gmovi.fec_fin_retencion IS NULL) OR v_liberado = 'S')
                   AND r_tacobros_gp.nro_tarjeta IS NOT NULL THEN ---Para que si lo inserte para operaciones que ya insertan en ta_cobros_gp antes de la confirmación o rechazo.

                 INSERT INTO ta_cobros_gp
                    (nro_cuenta, nro_tarjeta, nro_cta_debito, fec_proceso, monto, estado, fec_valor, observacion,
                     hora, cod_usuario, dia_mora, est_envio, tip_envio, tipo)
                 VALUES
                    (rp_gmovi.nro_cuenta, r_tacobros_gp.nro_tarjeta, r_tacobros_gp.nro_cta_debito, v_fec_actual, r_tacobros_gp.monto,
                     r_tacobros_gp.estado, v_fec_actual, 'Reversion de Pago de Tarjeta',v_hor_actual, v_cod_usuario,
                     r_tacobros_gp.dia_mora, 'P', 'O', 'R');
               END IF;
             END IF;
      END IF;
         IF v_est_envio in ('E','W') THEN --DYDMR-4001 Se agrega el EST_ENVIO = W (enviado via WS)-(ALV - jul/2016)
            --Enviado dar error
            if pae_cnf.G_PROGRAMA <> 'GPPROFIN' then
              raise_application_error(-20002,
                                    'Cobro ya enviado a la procesadora ' || ' Cuenta: ' ||
                                     rp_gmovi.nro_cuenta || ' Monto: ' || rp_gmovi.monto ||
                                     '. Notificar al Dpto. Operaciones.');
            else
              lp_env_mov_cob_pen(rp_gmovi.nro_cuenta, rp_gmovi.monto, rp_gmovi.concepto, rp_gmovi.cod_moneda);
            END IF;
         END IF;
     -- verifica si la reversion es de un deposito en efectivo o una
         -- liberacion de retencion para borrar el cobro
         -- AGREGAGO EL BORRADO DE LA 607 PORQUE CHEQUES SE ENVIA
         -- A LA PROCESADORA COMO EFECTIVO
         -- DYDMR-2249 ITGF - Reversar Pago Duplicado SC 18829
         --IF rp_gmovi.cod_transaccion IN (606, 607, 690, 515, 978, 613) THEN
         IF NVL(FUP_EXI_GRU_TRANSAC(14,rp_gmovi.cod_transaccion,5,51),'N') = 'S' THEN
            DELETE FROM ta_cobros
             WHERE fec_proceso = rp_gmovi.fecha
               AND (hora = p_hora OR hora IS NULL OR rp_gmovi.cod_transaccion in (613,614))
               AND ((cod_usuario = p_cod_usuario and hora = p_hora) OR
                   (cod_usuario IS NULL AND rp_gmovi.cod_transaccion in (613,614)))
               AND nro_cuenta = rp_gmovi.nro_cuenta
               AND monto = rp_gmovi.monto
               AND estado IN ('P', 'C');

         /*DYDMR-4695 Se cambia el momento en el que se eliminan los registros de GE_PAR_WEB_SERVICIOS al ELSE de IF SQL%NOTFOUND (ALV-set/2016)*/

            --Si no encuentro el registro veo si la liberacion cargo ta_cobros
            IF SQL%NOTFOUND THEN
               BEGIN
                  SELECT e.cod_usuario, to_char(e.fec_insercion, 'hh24:mi:ss')
                    INTO v_cod_usu_lib, v_hora_insercion
                    FROM ge_movimientos e
                   WHERE e.nro_cuenta = rp_gmovi.nro_cuenta
                     AND e.nro_documento = rp_gmovi.nro_documento
                     AND e.fecha = rp_gmovi.fecha
                     AND e.monto = rp_gmovi.monto
                     AND e.cod_transaccion IN (515, 565, 560);
               EXCEPTION
                  WHEN OTHERS THEN
                     v_cod_usu_lib    := NULL;
                     v_hora_insercion := NULL;
               END;
               --busco si se envio o no el registro de TA_COBROS
               BEGIN
                  SELECT est_envio, nro_tarjeta
                    INTO v_est_envio, v_nro_tarjeta --DYDMR-4001 recupera el nro de tarjeta (ALV - jul/2016)
                    FROM ta_cobros
                   WHERE fec_proceso = rp_gmovi.fecha
                     AND nro_cuenta = rp_gmovi.nro_cuenta
                     AND monto = rp_gmovi.monto
                     AND estado IN ('P', 'C')
                     AND usu_insercion = v_cod_usu_lib
                     AND to_char(fec_insercion, 'hh24:mi:ss') = v_hora_insercion;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_est_envio := 'N'; --No buscar en ta_cobros
                  WHEN too_many_rows THEN
                     raise_application_error(-20001,
                                             'Mas de un registro para' || ' Cuenta:' ||
                                              rp_gmovi.nro_cuenta || ' Monto:' || rp_gmovi.monto ||
                                              ' Usu_insercion: ' || v_cod_usu_lib ||
                                              ' Hora_insercion: ' || v_hora_insercion);
                  WHEN OTHERS THEN
                     raise_application_error(-20001,
                                             SQLERRM || ' Cuenta:' || rp_gmovi.nro_cuenta ||
                                              ' Monto:' || rp_gmovi.monto || ' Usu_insercion: ' ||
                                              v_cod_usu_lib || ' Hora_insercion: ' ||
                                              v_hora_insercion);
               END;
               IF v_est_envio = 'P' THEN
                  --P=Pendiente, se  puede borrar
                  DELETE FROM ta_cobros
                   WHERE fec_proceso = rp_gmovi.fecha
                     AND nro_cuenta = rp_gmovi.nro_cuenta
                     AND monto = rp_gmovi.monto
                     AND estado IN ('P', 'C')
                     AND usu_insercion = v_cod_usu_lib
                     AND to_char(fec_insercion, 'hh24:mi:ss') = v_hora_insercion;

                   --DYDMR-4001 Se elimina tambien el registro en la tabla GE_PAR_WEB_SERVICIOS (ALV - jul/2016)
                   delete from ge_par_web_servicios p
                    where p.fecha = rp_gmovi.fecha
                      and p.estado = 'P'
                      and substr(p.dat_enviados, 12, 16) = v_nro_tarjeta
                      and to_char(p.fec_insercion, 'hh24:mi:ss') = v_hora_insercion; /*DYDMR-4695 Se utiliza la hora de insercion de los registros para cobros con cheque CNB (ALV-set/2016)*/
               ELSIF v_est_envio IN ('E','W') THEN --DYDMR-4001 Se agrega el EST_ENVIO = W (enviado via WS)-(ALV - jul/2016)
                  --Enviado dar error
                  IF pae_cnf.G_PROGRAMA <> 'GPPROFIN' THEN
                     raise_application_error(-20002,
                                            'Cobro ya enviado a la procesadora ' || ' Cuenta:' ||
                                             rp_gmovi.nro_cuenta || ' Monto:' || rp_gmovi.monto ||
                                             ' Usu_insercion: ' || v_cod_usu_lib ||
                                             ' Hora_insercion: ' || v_hora_insercion);
                  ELSE
                    lp_env_mov_cob_pen(rp_gmovi.nro_cuenta, rp_gmovi.monto, rp_gmovi.concepto, rp_gmovi.cod_moneda);
                  END IF;
               END IF;
            ELSE --DYDMR-4695 Si no encuentra el registro correspondiente a una liberación. (ALV-set/2016)
              --DYDMR-4001 Se elimina tambien el registro en la tabla GE_PAR_WEB_SERVICIOS (ALV - jul/2016)
                delete from ge_par_web_servicios p
                 where p.fecha = rp_gmovi.fecha
                   and p.estado = 'P'
                   and substr(p.dat_enviados,12,16) = v_nro_tarjeta
                   and to_char(p.fec_insercion, 'hh24:mi:ss') = p_hora;
            END IF;
         END IF;
         IF rp_gmovi.cod_retencion IS NOT NULL THEN
            if rp_gmovi.cod_transaccion NOT IN (515, 565, 560) then  --DYDMR-5306 (ALV-NOV/2016)
              -- afecto la retencion, trato de borrar la retencion
              DELETE ah_retenciones
               WHERE nro_cuenta = rp_gmovi.nro_cuenta
                 AND nro_documento = rp_gmovi.nro_documento
                 AND cod_retencion = rp_gmovi.cod_retencion
                 AND fec_inicio = rp_gmovi.fecha
                 AND liberado = 'N';
              --Si ya fue liberado busco el registro y ademas borro de ge_movimientos
              IF SQL%NOTFOUND THEN
                 DELETE ah_retenciones
                  WHERE nro_cuenta = rp_gmovi.nro_cuenta
                    AND nro_documento = rp_gmovi.nro_documento
                    AND cod_retencion = rp_gmovi.cod_retencion
                    AND fec_inicio = rp_gmovi.fecha
                    AND liberado = 'S';
                 -- borro el movimiento de la liberacion para que no actualice el saldo batch
                 DELETE FROM ge_movimientos
                  WHERE nro_cuenta = rp_gmovi.nro_cuenta
                    AND nro_documento = rp_gmovi.nro_documento
                    AND cod_retencion = rp_gmovi.cod_retencion
                    AND fecha = rp_gmovi.fecha
                    AND monto = rp_gmovi.monto
                    AND cod_transaccion IN (515, 565, 560);
              END IF;
           else  --DYDMR-5306 (ALV-NOV/2016)
            --Modif. para reversar liberaciones x Cheque
            UPDATE ah_retenciones
               SET liberado      = 'N',
                   sal_retenido  = nvl(sal_retenido, 0) + rp_gmovi.monto,
                   lib_posterior = 'N'
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND nro_documento = rp_gmovi.nro_documento
               AND cod_retencion = rp_gmovi.cod_retencion
               AND fec_inicio = rp_gmovi.fec_valor;
           end if;
        END IF;
      END IF;
      IF rp_gmovi.cod_tra_padre in (2601, 359, 362) THEN
         BEGIN
            SELECT COUNT(g.cod_tra_padre)
              INTO v_can_bie_adjudicados
              FROM gv_movimientos g
             WHERE g.fecha = rp_gmovi.fecha
               AND g.hora = rp_gmovi.hora
               AND g.cod_usuario = rp_gmovi.cod_usuario
               AND g.monto <> 0
               AND g.cod_mod_padre = '26'
               AND g.cod_modulo = '26'
               AND g.reversado = 'N'
               AND g.cod_tra_padre = 2601
               AND exists
             (select 1
                      FROM gv_movimientos m
                     WHERE m.fecha = g.fecha
                       AND m.hora = g.hora
                       AND m.cod_usuario = g.cod_usuario
                       AND m.monto <> 0
                       and m.cod_mod_padre = '6'
                       AND m.cod_modulo = '26'
                       AND m.reversado = 'N'
                       AND m.cod_tra_padre = p_cod_tra_padre);
         EXCEPTION
            when others then
               v_can_bie_adjudicados := 0;
         END;
         IF v_can_bie_adjudicados = 0 then
            v_hora := lf_obt_hor_max_movimiento(rp_gmovi.fecha, rp_gmovi.hora, rp_gmovi.cod_usuario);
            BEGIN
               IF v_hora is not null then
                  SELECT COUNT(g.cod_tra_padre)
                    INTO v_can_bie_adjudicados
                    FROM gv_movimientos g
                   WHERE g.fecha = rp_gmovi.fecha
                     AND g.hora = v_hora
                     AND g.cod_usuario = rp_gmovi.cod_usuario
                     AND g.monto <> 0
                     and g.cod_mod_padre = '6'
                     AND g.cod_modulo = '26'
                     AND g.reversado = 'N'
                     AND g.cod_tra_padre in (359, 362)
                     and p_cod_tra_padre <> 2601
                     and g.referencia =
                         (select distinct m.referencia
                            FROM gv_movimientos m
                           WHERE m.fecha = g.fecha
                             AND m.hora = g.hora
                             AND m.cod_usuario = g.cod_usuario
                             AND m.monto <> 0
                             AND m.cod_mod_padre = '26'
                             AND m.cod_modulo = '26'
                             AND m.reversado = 'N'
                             AND m.cod_tra_padre = 2601);
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  v_can_bie_adjudicados := 0;
            END;
         END IF;
         IF nvl(v_can_bie_adjudicados, 0) > 0 THEN
            raise_application_error(-20000,
                                    'Prestamo Cancelado por Bienes Adjudicados. ' ||
                                     'Reverse desde la Transaccion 2601.');
         END IF;
      END IF;

      --Para setear a estado E cuando es una reversion de cobro de ahorro programado desde ITGF
      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.cod_modulo = 3 AND v_ope_pendiente = 'N' AND
         rp_gmovi.cod_tra_padre IN (2203)  THEN
               --Para reversar siempre la ultima cuota
               DECLARE
                  v_cant_cuotas NUMBER := 0;
                BEGIN
                  SELECT COUNT(*)
                   INTO v_cant_cuotas
                  FROM ah_pro_cuotas t
                  WHERE nro_cuenta = rp_gmovi.nro_cuenta
                    AND nro_cuota > regexp_substr(rp_gmovi.concepto, '\d+',5)
                    AND estado = 'P'
                    AND rownum = 1;
                  IF nvl(v_cant_cuotas, 0) > 0 THEN
                        raise_application_error(-20001,
                                                'La cuenta ' || rp_gmovi.nro_cuenta ||
                                                 ' tiene mov. posteriores de la cuota nro. ' ||
                                                 regexp_substr(rp_gmovi.concepto, '\d+',5) ||
                                                 ' Primero rev.esas cuotas');
                  END IF;

                If nvl(v_cant_cuotas,0) = 0 then
                   begin
                   UPDATE ah_pro_cuotas
                        SET fec_ult_pago       = null,
                            estado             = 'E',
                            sal_acumulado      = 0
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta
                        AND nro_cuota = regexp_substr(rp_gmovi.concepto, '\d+',5);
                   exception
                     when others then
                       null;
                   end;
                 End if;
                END;
      END IF;

      IF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.cod_modulo = 6 AND v_ope_pendiente = 'N' AND
         rp_gmovi.cod_tra_padre IN (142, 360, 359, 362, 364) THEN

         IF rp_gmovi.monto IS NULL AND v_gen_estado = 'N' THEN
            --El grupo de registros a reversar ya contiene la operación de cambio de estado por tanto ya no se debe generar más
            v_gen_estado := 'X';
         END IF;

         IF rp_gmovi.monto <> 0 THEN
            IF nvl(fup_obt_tip_descuento(rp_gmovi.cod_modalidad), 'x') = 'C' AND v_gen_estado = 'N' THEN
               --Generar cambio de estado con el estado de la cuota a ser reversada
               pr_gen_cam_estado(rp_gmovi);
            END IF;

            -- Recuperar datos del prestamo
            pap_pre.pr_obt_dat_prestamo(rp_gmovi.nro_cuenta, r_pcpre);

            --si es préstamo renovado el que se reversa verificar si se canceló por el desembolso del nuevo préstamo
            --para nular el campo nro_cta_renovada, ya que no debería quedar atado porque en el cierre de día se debe
            --eliminar ese nuevo préstamo desembolsado y cancelado en el mismo día. VC 18-08-2010
            IF rp_gmovi.cod_tra_padre = 359 AND (r_pcpre.nro_cta_renovada IS NOT NULL OR r_pcpre.nro_cta_novada IS NOT NULL) THEN
               --solo si tiene RRR
               --verificar si existe un movimiento de desembolso junto con la cancelación
               SELECT COUNT(*)
                 INTO v_rrr_desembolso
                  FROM ge_movimientos g
                 WHERE g.fecha = p_fecha
                   AND g.hora  = p_hora
                   AND g.cod_usuario = p_cod_usuario
                   AND g.cod_tra_padre = 358
                   AND g.nro_cuenta = nvl(r_pcpre.nro_cta_renovada,r_pcpre.nro_cta_novada)
                   AND g.reversado = 'N';
               IF v_rrr_desembolso > 0 THEN
                  --actualizar el préstamo viejo
                   IF r_pcpre.nro_cta_renovada IS NOT NULL THEN
                  UPDATE pr_cta_prestamos
                     SET nro_cta_renovada = NULL
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                   ELSE
                      UPDATE pr_cta_prestamos
                         SET nro_cta_novada = NULL
                       WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                   END IF;
               END IF;
            END IF;

            -- obtengo el tipo d/c y a que saldo afecto
            pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                   rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
            --- Inicializar errores de pag_cta
            pag_cta.g_msj_error := NULL;
            pag_cta.g_cod_error := 0;
            --- Inicializar variables de descuento
            v_estado            := NULL;
            v_est_cuenta        := NULL;
            v_est_anterior      := NULL;
            v_capital           := 0;
            v_interes           := 0;
            v_int_adelantado    := 0;
            v_val_recargo       := 0;
            v_int_descontado    := 0;
            v_cap_adelantado    := 0;
            v_devengado         := 0;
            v_dev_no_cobrado    := 0;
            v_dev_suspenso      := 0;
            v_capital_deven     := 0;
            v_mto_cap_cuota     := 0;
            v_mto_int_docum     := 0;
            v_cu_dev_acumulado  := 0;
            v_cu_dev_no_cobrado := 0;
            v_cu_dev_suspenso   := 0;

            --- Recuperar fecha de ultimo pago y estado anterior de pr_cobros
            BEGIN
               SELECT fec_ult_pago,
                      estado,
                      fec_ult_devengado,
                      estado,
                      dev_acumulado,
                      dev_suspenso,
                      dev_no_cobrado,
                      mto_int_descontado,
                      decode(rp_gmovi.cod_tra_padre, 362, mto_capital, 0)
                 INTO v_fec_ult_pago,
                      v_estado,
                      v_fec_ult_devengado,
                      v_est_cuenta,
                      v_cu_dev_acumulado,
                      v_cu_dev_suspenso,
                      v_cu_dev_no_cobrado,
                      v_int_descontado,
                      v_cap_adelantado
                 FROM pr_cobros
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND nro_cuota = rp_gmovi.nro_documento3
                  AND fecha = rp_gmovi.fecha
                  AND hora = rp_gmovi.hora;
               -- verifico sino hay otros cobros, en caso de intereses vencidos
               IF nvl(fup_obt_tip_descuento(rp_gmovi.cod_modalidad), 'x') NOT IN ('F', 'C', 'D') THEN
                  DECLARE
                     v_can_cuotas NUMBER := 0;
                  BEGIN
                     SELECT COUNT(*)
                       INTO v_can_cuotas
                       FROM pr_cobros
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta
                        AND ((fecha > rp_gmovi.fecha) OR
                            (fecha = rp_gmovi.fecha AND hora > rp_gmovi.hora))
                        AND rownum = 1;
                     IF v_can_cuotas > 0 THEN
                        raise_application_error(-20010,
                                                'La cuenta ' || rp_gmovi.nro_cuenta ||
                                                 ' tiene cobros posteriores que deben ser reversados previamente.');
                     END IF;
                  END;
               ELSE
                  --Para los casos de descuentos
                  DECLARE
                     v_can_cuotas NUMBER := 0;
                  BEGIN
                     SELECT COUNT(*)
                       INTO v_can_cuotas
                       FROM pr_cobros
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta
                        AND nro_cuota = rp_gmovi.nro_documento3
                        AND ((fecha > rp_gmovi.fecha) OR
                            (fecha = rp_gmovi.fecha AND hora > rp_gmovi.hora))
                        AND rownum = 1;
                     IF nvl(v_can_cuotas, 0) > 0 THEN
                        raise_application_error(-20001,
                                                'La cuenta ' || rp_gmovi.nro_cuenta ||
                                                 ' tiene mov. posteriores de la misma cuota nro. ' ||
                                                 rp_gmovi.nro_documento3 ||
                                                 ' Primero rev.esos movimientos.');
                     END IF;
                  END;
               END IF;

               IF p_fecha = v_fec_actual or
                  /*
                  || DYDMR-765 VERIFICACIÓN DE DIFERENCIAS CONTABLES SOBRE INTERESES EN SUSPENSO SC 5616
                  || Cuando se reversan cobros históricos de préstamos que ya devengaron totalmente
                  */
                 (p_fecha <> v_fec_actual and v_fec_actual > r_pcpre.fec_vencimiento - 1) THEN
                  --- Solo cuando se reversa cobros del mismo dia se reversa el devengado
                  --- en caso contrario el devengamiento se realizará por diferencia en el cierre
                  --- Recuperar datos de devengados actuales de la cuota
                  SELECT nvl(v_cu_dev_acumulado, 0) - nvl(dev_acumulado, 0),
                         nvl(v_cu_dev_no_cobrado, 0) - nvl(dev_no_cobrado, 0),
                         nvl(v_cu_dev_suspenso, 0) - nvl(dev_suspenso, 0),
                         nvl(mto_capital, 0),
                         nvl(mto_int_documentado, 0)
                    INTO v_devengado,
                         v_dev_no_cobrado,
                         v_dev_suspenso,
                         v_mto_cap_cuota,
                         v_mto_int_docum
                    FROM pr_cuotas
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND nro_cuota = rp_gmovi.nro_documento3;
                  --- Actualizar la cuota
                  UPDATE pr_cuotas
                     SET dev_acumulado  = v_cu_dev_acumulado,
                         dev_suspenso   = v_cu_dev_suspenso,
                         dev_no_cobrado = v_cu_dev_no_cobrado
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND nro_cuota = rp_gmovi.nro_documento3;
                  --- Actualizar el prestamo en el devengado ya la primera vez
                  UPDATE pr_cta_prestamos
                     SET dev_acumulado    = nvl(dev_acumulado, 0) + nvl(v_devengado, 0),
                         dev_no_cobrado   = nvl(dev_no_cobrado, 0) + nvl(v_dev_no_cobrado, 0),
                         dev_suspenso     = nvl(dev_suspenso, 0) + nvl(v_dev_suspenso, 0),
                         val_int_devengar = nvl(val_int_devengar, 0) - nvl(v_devengado, 0) +
                                            nvl(v_int_descontado, 0)
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta;
               END IF;
               --recuperar el estado de la cuota en el cobro
               BEGIN
                  SELECT estado
                    INTO v_est_cuo_cobro
                    FROM pr_cuotas
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND nro_cuota = rp_gmovi.nro_documento3;
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
               --- La primera vez que pasa por la cuota ya actualiza fecha de pago y estado,
               --- porque luego se borra este registro
               UPDATE pr_cuotas
                  SET fec_ult_pago       = v_fec_ult_pago,
                      estado             = v_estado,
                      mto_int_descontado = nvl(mto_int_descontado, 0) - nvl(v_int_descontado, 0),
                      mto_cap_adelantado = nvl(mto_cap_adelantado, 0) - nvl(v_cap_adelantado, 0)
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND nro_cuota = rp_gmovi.nro_documento3;
               -- SC 12793 - ITGF - Incidencia del Devengamiento de Interes - EP- NAN 2015-06-03
               -- Para cancelacion parcial de capital, se elimina PR_AMO_PAR_CAPITAL de la cuota con fecha y hora del mov reversado
               /*DYDMR-2003 FM 08/07/2015*/
               if rp_gmovi.cod_tra_padre = 362 then
                      BEGIN
                        UPDATE PR_COB_AMO_PARCIAL
                        SET REVERSADO='S'
                        where FECHA = p_fecha
                        and HORA = p_hora
                        and COD_USUARIO = p_cod_usuario
                        and NRO_CUENTA = rp_gmovi.nro_cuenta
                        and NRO_CUOTA = rp_gmovi.nro_documento3;
                      EXCEPTION
                        WHEN OTHERS THEN
                          NULL;
                      END;
               end if;
               --- Actualizar el devengado de la cuota en pr_devengados
               --- Solo si devengo, si se cambio los suspendidos o cobros nada mas no tocar
               IF nvl(v_devengado, 0) <> 0 THEN
                  --- Recuperar categoria del cliente
                  BEGIN
                     SELECT fup_obt_categoria(c.cat_automatica, c.cat_subjetiva) categoria
                       INTO v_categoria
                       FROM ge_clientes c, ge_cta_clientes b
                      WHERE b.nro_cuenta = rp_gmovi.nro_cuenta
                        AND b.cod_persona = c.cod_persona
                        AND b.relacion = 'P';
                  EXCEPTION
                     WHEN no_data_found THEN
                        raise_application_error(-20000,
                                                'Cliente Principal no registrado para cuenta ' ||
                                                 rp_gmovi.nro_cuenta);
                  END;
                  --- Recuperar tipo de devengado en el momento del cobro
                  IF v_est_cuenta IN ('A', 'C') AND v_categoria IN (1, 2) THEN
                     /* solo los est 'A' y 'C' y categ 1 y 2*/
                     v_tip_devengado := 'N'; --'C'  --RI:09/06/2010: Estaba 'C' se cambio por 'N'
                  ELSE
                     v_tip_devengado := 'S';
                  END IF;
                  --- Recuperar fecha de inicio del devengado
                  IF r_pcpre.tip_interes = 'V' THEN
                     --- Para prestamos vencidos recorrer cuotas cuya fecha de
                     --- inicio de devengado ha transcurrido
                     v_fec_ini_dev := nvl(pap_dev.fu_obt_fec_ini_cuota(rp_gmovi.nro_cuenta,
                                                                       rp_gmovi.nro_documento3),
                                          r_pcpre.fec_inicio);
                  ELSE
                     v_fec_ini_dev := r_pcpre.fec_inicio;
                  END IF;
                  --- Recuperar capital segun el tipo de prestamo
                  IF r_pcpre.tip_interes = 'A' THEN
                     v_capital_deven := nvl(v_mto_cap_cuota, 0) + nvl(v_mto_int_docum, 0);
                  ELSE
                     v_capital_deven := pap_int.fu_obt_capital_acumu(v_fec_ini_dev,
                                                                     rp_gmovi.nro_cuenta);
                  END IF;
                  --- Recuperar capital de la cuota
                  --- Solo se reversa si devengo el dia del cobro por esa fecha o adelantado
                  IF v_fec_ult_devengado IS NULL THEN
                     --se elimina pr_devengados
                     DELETE pr_devengados
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta
                        AND nro_cuota = rp_gmovi.nro_documento3
                        AND fec_inicio = v_fec_ini_dev
                        AND val_tasa = r_pcpre.val_tasa
                        AND categoria = v_categoria
                        AND estado = v_est_cuenta
                        AND cod_moneda = r_pcpre.cod_moneda
                        AND capital = v_capital_deven
                        AND tipo = v_tip_devengado;
                  ELSE
                     UPDATE pr_devengados
                        SET fecha             = v_fec_ult_devengado,
                            mto_dev_acumulado = mto_dev_acumulado - mto_dev_actual,
                            can_dia_interes   = nvl(can_dia_anterior, 0),
                            mto_dev_actual    = nvl(mto_dev_anterior, 0),
                            mto_ajuste        = NULL,
                            fec_ult_devengado = v_fec_ult_devengado
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta
                        AND nro_cuota = rp_gmovi.nro_documento3
                        AND fec_inicio = v_fec_ini_dev
                        AND val_tasa = r_pcpre.val_tasa
                        AND categoria = v_categoria
                        AND estado = v_est_cuenta
                        AND cod_moneda = r_pcpre.cod_moneda
                        AND capital = v_capital_deven
                        AND tipo = v_tip_devengado;
                  END IF;
               END IF;
               --- Actualizar el prestamo en el devengado ya la primera vez
               UPDATE pr_cta_prestamos
                  SET fec_ult_devengado = v_fec_ult_devengado,
                      estado            = nvl(v_est_cuenta, estado)
                WHERE nro_cuenta = rp_gmovi.nro_cuenta;

               --- Actualizar ge_che_custodia
               IF fup_obt_tip_descuento(r_pcpre.cod_modalidad) = 'C' THEN
                  UPDATE ge_che_custodias
                     SET estado = 'A' --DYDMR-4678-- Al reversar confirmación de cheques debe volver al estado 'A'(En compensacion).
                   WHERE nro_referencia = rp_gmovi.nro_cuenta
                     AND nro_cuota = rp_gmovi.nro_documento3
                     AND estado = 'D';
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  v_fec_ult_pago := NULL;
                  v_estado       := NULL;
            END;
            --- Verificar como afecta al prestamo la transaccion
            IF v_afecta = 'C' THEN
               --- Reversar capital
               v_capital := rp_gmovi.monto;
            ELSIF v_afecta = 'I' THEN
               --- Reversar interés vencido
               v_interes := rp_gmovi.monto;
            ELSIF v_afecta = 'A' THEN
               --- Reversar interés adelantado
               v_int_adelantado := rp_gmovi.monto;
            ELSIF v_afecta = 'E' THEN
               --- Reversar recargos
               v_val_recargo := rp_gmovi.monto;
            END IF;
            DECLARE
               v_can_cambios NUMBER(8); -- para contar cambios o mov posteriores
            BEGIN
               -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
               BEGIN
                  SELECT (CASE
                            WHEN ((nvl(v.est_cuenta, 'x') != 'N' AND v.cod_modulo != 6) OR
                                 (v.cod_modulo = 6 AND
                                 nvl(fup_obt_tip_descuento(v.cod_modalidad), 'x') != 'C')
                                 --Para el módulo de PRESTAMOS con el tipo diferente a descuento CHEQUES,
                                 --ya que para todas las otras modalidades del módulo PRESTAMOS,
                                 --QUE NO SEAN DE DESCUENTO DE CHEQUES, SE DEBE REVERSAR en el orden inverso en que fueron cargados.
                                 ) THEN
                             1
                            ELSE
                             0
                         END)
                    INTO v_can_cambios
                    FROM (SELECT est_cuenta, cod_modulo, cod_modalidad
                            FROM gv_movimientos
                           WHERE nro_cuenta = rp_gmovi.nro_cuenta
                             AND ((fec_valor > rp_gmovi.fec_valor) OR
                                 (fec_valor = rp_gmovi.fec_valor AND hora > rp_gmovi.hora))
                             AND reversado = 'N'
                             AND ((est_cuenta IS NOT NULL AND nvl(cod_tip_movimiento, 'x') = 'E') OR
                                 (v_est_anterior IS NOT NULL)) -- si hubo otro cambio de estado posterior
                             AND cod_tra_padre <> 945 --para que no tenga en cuenta los cambios de situaciones
                        ORDER BY fec_insercion DESC) v
                   WHERE rownum = 1;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_can_cambios := 0;
               END;
               IF nvl(v_can_cambios, 0) > 0 THEN
                  raise_application_error(-20011,
                                          'La cuenta ' || rp_gmovi.nro_cuenta ||
                                           ' tiene movimientos posteriores que deben ser reversados previamente.');
               END IF;
               IF v_fec_ult_mov_ant IS NOT NULL THEN
                  -- verifico sino hubo movimientos posteriores de la cuenta
                  SELECT COUNT(*)
                    INTO v_can_cambios
                    FROM gv_movimientos
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND ((fecha > rp_gmovi.fecha) OR
                         (fecha = rp_gmovi.fecha AND hora > rp_gmovi.hora))
                     AND reversado = 'N'
                     AND monto > 0 -- si hubo un mov posterior
                     AND rownum = 1;
                  IF nvl(v_can_cambios, 0) > 0 THEN
                     -- en este caso nada mas no se actualiza los datos del ultimo mov
                     v_fec_ult_mov_ant := NULL;
                     v_hor_ult_mov_ant := NULL;
                  END IF;
               END IF;
            EXCEPTION
               WHEN no_data_found THEN
                  v_fec_ult_mov_ant := NULL;
                  v_hor_ult_mov_ant := NULL;
               WHEN OTHERS THEN
                  raise_application_error(-20000, SQLERRM || ' Buscando ge_cuentas_nov ');
            END;

            --- Actualizar cuota
            UPDATE pr_cuotas
               SET fec_ult_pago        = nvl(v_fec_ult_pago, fec_ult_pago),
                   estado              = nvl(v_estado, estado),
                   sal_capital         = nvl(sal_capital, 0) + nvl(v_capital, 0),
                   sal_interes         = nvl(sal_interes, 0) + nvl(v_interes, 0),
                   val_recargo         = nvl(val_recargo, 0) - nvl(v_val_recargo, 0),
                   sal_int_documentado = nvl(sal_int_documentado, 0) + nvl(v_int_adelantado, 0)
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND nro_cuota = rp_gmovi.nro_documento3;
             --DYDMR-6419 - Existen escenarios que alteran el devengado al modificar el campo MTO_INTERES.-
             --DYDMR-3650-ITGF - Valor Cuota no Actualiza las Amortizaciones Parciales Anticipadas SC 27928
             --Una Cancelación Parcial de Capital también debe actualizar el valor de la Cuota (Monto Capital + Monto Interés).
             /*if rp_gmovi.cod_tra_padre = 362 then
                UPDATE pr_cuotas
                   SET mto_capital = nvl(mto_capital,0)+ nvl(v_capital, 0),
                       mto_interes = nvl(mto_interes,0)+ nvl(v_interes, 0)
                 WHERE nro_cuenta  = rp_gmovi.nro_cuenta
                   AND nro_cuota   = rp_gmovi.nro_documento3;
             end if;*/
            --- Actualizar maestro de prestamos
            UPDATE pr_cta_prestamos
               SET sal_capital        = nvl(sal_capital, 0) + nvl(v_capital, 0),
                   sal_interes        = nvl(sal_interes, 0) + nvl(v_interes, 0),
                   sal_int_adelantado = nvl(sal_int_adelantado, 0) + nvl(v_int_adelantado, 0),
                   fec_cancelacion    = NULL,
                   can_cuo_pagadas    = nvl(can_cuo_pagadas, 0) - decode(v_est_cuo_cobro, 'N', 1, 0) --sólo si hubo cuota pagada
             WHERE nro_cuenta = rp_gmovi.nro_cuenta;
            --- Actualizar cuotas restantes
            IF v_est_cuenta IS NOT NULL THEN
               UPDATE pr_cuotas
                  SET estado = v_est_cuenta
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND estado <> 'N'
                  AND nro_cuota > rp_gmovi.nro_documento3;
            END IF;

            --- actualizar pr_cta_gastos (gastos varios)
            BEGIN
               SELECT SUM(nvl(monto, 0))
                 INTO v_mto_gas_original
                 FROM pr_cta_gastos
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND fec_ult_pago = rp_gmovi.fecha
                  AND hor_ult_pago = rp_gmovi.hora;
            EXCEPTION
               WHEN no_data_found THEN
                  v_mto_gas_original := 0;
            END;
            DECLARE
               CURSOR gastos IS
                  SELECT nro_cuenta, monto, ROWID
                    FROM pr_cta_gastos
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND fec_ult_pago = rp_gmovi.fecha
                     AND hor_ult_pago = rp_gmovi.hora
                   ORDER BY nro_cuenta, cod_modalidad, cod_transaccion, fec_ingreso;
               v_cargo_tmp NUMBER;
            BEGIN
               v_cargo_tmp := nvl(v_mto_gas_original, 0);
               FOR g IN gastos LOOP
                  -- Si el gasto es mayor o igual al monto, actualizo la tabla pr_cta_gastos como NO cobrado
                  IF nvl(v_cargo_tmp, 0) >= nvl(g.monto, 0) THEN
                     BEGIN
                        UPDATE pr_cta_gastos
                           SET fec_ult_pago = NULL,
                               hor_ult_pago = NULL
                         WHERE nro_cuenta = rp_gmovi.nro_cuenta
                           AND ROWID = g.ROWID;
                     EXCEPTION
                        WHEN OTHERS THEN
                           NULL;
                     END;
                     v_cargo_tmp := nvl(v_cargo_tmp, 0) - nvl(g.monto, 0);
                  END IF;
               END LOOP;
            END;
            --END IF;

            --Obs: Controlar para que se ejecute solo una vez--
            --la actualizacion de garantias--
            v_con_pro_garantia := nvl(v_con_pro_garantia, 0) + 1;
            IF nvl(v_con_pro_garantia, 0) = 1 THEN
               --Actualizar mto. aplicado de la garantia
               FOR i IN garantias(rp_gmovi.nro_cuenta) LOOP
                  v_mto_apl_reversar := fup_obt_mto_apl_reversar(rp_gmovi.nro_cuenta, i.cod_garantia,
                                                                 i.nro_garantia, p_fecha, p_hora,
                                                                 p_cod_usuario);
                  IF i.cod_garantia = 1 THEN
                     UPDATE pr_cta_garantias x
                        SET x.mto_aplicado = nvl(x.mto_aplicado, 0) + nvl(v_mto_apl_reversar, 0)
                      WHERE x.nro_cuenta = rp_gmovi.nro_cuenta
                        AND x.cod_garantia = i.cod_garantia;
                  ELSE
                     UPDATE pr_cta_garantias x
                        SET x.mto_aplicado = nvl(x.mto_aplicado, 0) + nvl(v_mto_apl_reversar, 0)
                      WHERE x.nro_cuenta = rp_gmovi.nro_cuenta
                        AND x.cod_garantia = i.cod_garantia
                        AND x.nro_garantia = i.nro_garantia;
                  END IF;
               END LOOP;
            END IF;
            -- Recalcular línea
            IF r_pcpre.nro_linea IS NOT NULL THEN
               prp_rec_apl_limite(r_pcpre.nro_linea);
            END IF;

            --Elimiar la novedad de la garantia
            DELETE pr_cta_garantias_nov
             WHERE fecha = p_fecha
               AND hora = p_hora
               AND cod_usuario = p_cod_usuario
               AND nro_cuenta = rp_gmovi.nro_cuenta;

            --- Eliminar pr_cobros
            DELETE pr_cobros
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND nro_cuota = rp_gmovi.nro_documento3
               AND fecha = rp_gmovi.fecha
               AND hora = rp_gmovi.hora;
             --- Si es cobro de un préstamo renovado(RRR) que se está reversando y mejoró la categoría debe volver el préstamo
             --- a la categoría anterior.
             IF NVL(r_pcpre.tip_renovacion,'A') <> 'A'
               and r_pcpre.est_batch <> 'N' THEN -- DYDMR-5036 Solo si el cobro a reversar no canceló la cuenta ALV (Oct-2016)
                IF rp_gmovi.fecha <> v_fec_actual THEN
                   SELECT cat_ren_anterior
                     INTO v_cat_ren_anterior
                     FROM ge_cla_operaciones_his
                    WHERE nro_cuenta = r_pcpre.nro_cuenta
                      AND fecha = rp_gmovi.fecha;
                   SELECT MAX(fecha)
                     INTO v_fec_ult_categorizacion
                     FROM ge_cla_operaciones_his
                    WHERE nro_cuenta = r_pcpre.nro_cuenta
                      AND fecha < rp_gmovi.fecha
                      AND cat_ren_anterior > cat_renovaciones;
                   UPDATE pr_cta_prestamos
                      SET cat_renovaciones = v_cat_ren_anterior,
                          fec_ult_categorizacion = v_fec_ult_categorizacion
                    WHERE nro_cuenta = r_pcpre.nro_cuenta;
                END IF;
             END IF;

            Begin --CRO-HO-CROCPCCB-18/08/15 segun AT: CROAPARS-57
                 Select distinct('S'), a.nro_cheque
                   into v_cob_pre_che, v_nro_cheque
                  From pr_cob_cuo_otr_bco a
                  where a.nro_cuenta  = rp_gmovi.nro_cuenta
                    and a.estado      = 'P'
                    and a.nro_cuota   = rp_gmovi.nro_documento3
                    and a.fec_cobro   = rp_gmovi.fecha; --ALV DYDMR-4260
            Exception
                 When no_data_found then
                      v_cob_pre_che := 'N';
                 When too_many_rows Then
                      v_cob_pre_che := 'S';
                 When Others Then
                      v_cob_pre_che := 'N';
            End;

            if v_cob_pre_che = 'S' and v_entro = 'N' Then --CRO-HO-CROCPCCB-18/08/15 segun AT: CROAPARS-57
               v_cta_operativa :=  fug_obt_pardinamico('CTA_CRE_REV_PRESTAMO',
                                                       null,
                                                       null,
                                                       rp_gmovi.cod_moneda,
                                                       rp_gmovi.cod_oficina);
               v_nro_secuencia := nvl(v_nro_secuencia,0) + 1;
               v_hor_cre_pp    := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
               pag_cta.pr_act_operacion(v_cta_operativa        ,
                                        v_hor_cre_pp            ,
                                        'C'                    ,
                                        rp_gmovi.cod_moneda    ,
                                        v_mto_credito          ,
                                        1608                  ,
                                        1608                  ,
                                        r_gmovi.nro_documento  ,
                                        NULL                    ,
                                        rp_gmovi.cod_ofi_origen    ,
                                        4                      ,
                                        43                      ,
                                        null                    ,
                                        null                    ,
                                        'Rev. Cob. de Préstamo Che.C/O/B: '||rp_gmovi.nro_cuenta,
                                        'S'                    ,
                                        v_nro_secuencia        ,
                                        r_gmovi.fec_valor      ,
                                        null                    ,
                                        null                    ,
                                        null                    )
                                        ;
               If pag_cta.g_cod_error = 0 Then
                  v_entro := 'S';
               end if;
            end if;
            --- Solo si existe cancelacion parcial
            IF rp_gmovi.cod_tra_padre = 359 AND rp_gmovi.cod_transaccion = 747 THEN
               --- Recorrer
               v_nro_cuo_desde := rp_gmovi.nro_documento;
               v_nro_cuo_hasta := rp_gmovi.nro_documento3;
               FOR cob IN c_cobros LOOP
                  UPDATE pr_cuotas
                     SET mto_interes         = cob.mto_interes,
                         sal_interes         = cob.sal_interes_cuo,
                         mto_int_documentado = cob.mto_int_documentado,
                         sal_int_documentado = cob.sal_int_documentado,
                         dev_acumulado       = cob.dev_acumulado,
                         dev_no_cobrado      = cob.dev_no_cobrado,
                         dev_suspenso        = cob.dev_suspenso,
                         nro_documento       = cob.nro_documento
                   WHERE nro_cuenta = cob.nro_cuenta
                     AND nro_cuota = cob.nro_cuota;
                  IF SQL%NOTFOUND THEN
                     INSERT INTO pr_cuotas
                        (nro_cuenta, nro_cuota, fec_vencimiento, mto_capital, mto_interes, estado,
                         sal_capital, sal_interes, prioridad, fec_ult_pago, mto_int_documentado,
                         nro_documento, sal_int_documentado, dev_acumulado, dev_no_cobrado,
                         dev_suspenso)
                     VALUES
                        (cob.nro_cuenta, cob.nro_cuota, cob.fec_vencimiento, cob.mto_capital,
                         cob.mto_interes, cob.estado, cob.sal_capital_cuo, cob.sal_interes_cuo, 'I',
                         cob.fec_ult_pago, cob.mto_int_documentado, cob.nro_documento,
                         cob.sal_int_documentado, cob.dev_acumulado, cob.dev_no_cobrado,
                         cob.dev_suspenso);
                  END IF;
               END LOOP;
            END IF;
         END IF;
         /*
         || CROLIANC-4 AT - Liberacion Anticipada Cheques C/O con Creación de Cuentas de Préstamos
         */
         IF rp_gmovi.cod_mad_padre = 699 and rp_gmovi.cod_transaccion = 801 THEN
            select estado
              into v_est_liberacion
              from cc_lib_ant_cheques
             where nro_cta_prestamo = rp_gmovi.nro_cuenta;
            if v_est_liberacion = 'C' then
               update cc_lib_ant_cheques
                  set estado = 'D'
                where nro_cta_prestamo = rp_gmovi.nro_cuenta;
            end if;
         END IF;
         ---
      ELSIF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 6 AND
            v_ope_pendiente = 'N' AND rp_gmovi.cod_tra_padre IN (358) THEN
         --DESEMBOLSO

         IF rp_gmovi.cod_tra_padre = 358 THEN
            SELECT COUNT(g.cod_tra_padre) --Bienes Adjudicados
              INTO v_can_bie_adjudicados
              FROM gv_movimientos g
             WHERE g.fecha = rp_gmovi.fecha
               AND g.hora = rp_gmovi.hora
               AND g.cod_usuario = rp_gmovi.cod_usuario
               AND g.monto <> 0
               AND g.cod_modulo = 26
               AND g.reversado = 'N'
               AND g.cod_tra_padre = 261
               AND p_cod_tra_padre = 358;

            IF nvl(v_can_bie_adjudicados, 0) > 0 THEN
               raise_application_error(-20000,
                                       'Prest.Desembolsado p/Compra Bienes Adjudicados. ' ||
                                        'Reverse desde la Transaccion 261.');
            END IF;
         END IF;

         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         --- Inicializar errores de pag_cta
         pag_cta.g_msj_error := NULL;
         pag_cta.g_cod_error := 0;
         -- Recuperar datos de la propuesta
         v_nro_solicitud := NULL;
         BEGIN
            SELECT nro_solicitud, nro_linea
              INTO v_nro_solicitud, v_nro_linea
              FROM pr_cta_prestamos
             WHERE nro_cuenta = rp_gmovi.nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               v_nro_solicitud := NULL;
         END;
         IF fup_obt_tip_descuento(rp_gmovi.cod_modalidad) = 'C' AND v_nro_solicitud IS NOT NULL THEN
            --- Actualizo los cheques que corresponden a la solicitud
            UPDATE ge_che_custodias
               SET estado         = 'I',
                   nro_referencia = v_nro_solicitud
             WHERE nro_referencia = rp_gmovi.nro_cuenta
               AND estado <> 'D'
               AND tip_servicio IN ('D', 'G');
         END IF;
         --- Actualizo los documentos que corresponden a la solicitud
         IF fup_obt_tip_descuento(rp_gmovi.cod_modalidad) IN ('D', 'F') AND
            v_nro_solicitud IS NOT NULL THEN
            UPDATE pr_documentos
               SET nro_referencia = v_nro_solicitud
             WHERE nro_referencia = rp_gmovi.nro_cuenta
               AND estado = 'C';
         END IF;
         -- Actualizar solicitudes
         IF v_nro_solicitud IS NOT NULL THEN
            UPDATE pr_solicitudes
               SET estado = 'L',
                   fec_aprobacion = NULL
             WHERE nro_solicitud = v_nro_solicitud;

            --Verificar si la cuenta tiene seguro distribuido--
            select decode(nvl(COUNT(*),0),0,'N','S')
              into v_tie_cob_seg_distr
              from ba_tab_dat_adicionales t
             where t.tab_relacion = 'PR_SOLICITUDES'
               and t.parametro = 'PRE_IND_CUO_CAL_SEGURO'
               and t.referencia = trim(to_char(v_nro_solicitud))
               and t.val_parametro = 'S';

            ---------------------------------------------------------
            --Proyecto SDSEGVID-3 Seguro de Vida Distribuido (1521)--
            --Actualizar datos de la tabla auxiliar de seguros-------
            ---------------------------------------------------------
            if nvl(v_tie_cob_seg_distr,'N') = 'S' then
               update pr_cta_gas_seguros x
                  set x.nro_cuenta = null,
                      x.estado = 'I',
                      x.cod_tas_ref1 = null, x.val_tas_ref1 = null,
                      x.cod_tas_ref2 = null, x.val_tas_ref2 = null,
                      x.mto_car_dis_com_seguro = null, x.mto_car_dis_iva_seguro = null,
                      x.mto_car_dis_seguro = null, x.mto_car_dis_com_banco = null,
                      x.mto_car_dis_iva_banco = null, x.mto_car_dis_banco = null,
                      x.mto_car_pri_com_base  = null, x.mto_car_pri_iva_base = null,
                      x.mto_car_bco_com_base  = null, x.mto_car_bco_iva_base = null,
                      x.ano = null, x.dia_acu_cuota = null,
                      x.dia_cuota = null, x.ano_pag_prima = null,
                      x.mes_pag_prima = null, x.fec_pag_prima = null
                where x.nro_solicitud = v_nro_solicitud;
            end if;

            --Proyecto SDSEGVID-144--Seguro Anual de Consumo---
            --Elimina datos de cuentas con seguro pago anual--
            if nvl(v_pre_hab_cal_seg_anual,'N') = 'S' then
               prp_pro_dat_seg_anual('R', null, null, v_nro_solicitud);
            end if;
            ----------------------------------------------------------

            /* En caso de Prestamos en Etapas hay que actualizar la cantidad de desembolsos faltantes
               de la solicitud original - Buscar la solicitud original
            */
            DECLARE
               v_tip_renovacion   VARCHAR2(1);
               v_can_desembolsos  NUMBER;
               v_nro_sol_original NUMBER;
            BEGIN
               SELECT tip_renovacion, can_desembolsos, nro_sol_original
                 INTO v_tip_renovacion, v_can_desembolsos, v_nro_sol_original
                 FROM pr_solicitudes
                WHERE nro_solicitud = v_nro_solicitud;
               --
               IF v_tip_renovacion = 'A' AND nvl(v_can_desembolsos, 0) > 1 THEN
                  -- es el original
                  v_nro_sol_original := v_nro_solicitud;
               END IF;
               -- Si el tip_renovacion no es 'A' entonces en v_nro_sol_original viene la original,
               -- si no es en etapas viene nulo
               UPDATE pr_solicitudes
                  SET can_des_faltantes = can_des_faltantes + 1
                WHERE nro_solicitud = v_nro_sol_original;
            EXCEPTION
               WHEN OTHERS THEN
                  NULL;
            END;
            --- Verificar como afecta al prestamo la transaccion
            IF v_afecta = 'C' THEN
               --- Reversar capital
               v_capital := rp_gmovi.monto;
            ELSIF v_afecta = 'I' THEN
               --- Reversar interés vencido
               v_interes := rp_gmovi.monto;
            ELSIF v_afecta = 'A' THEN
               --- Reversar interés adelantado
               v_int_adelantado := rp_gmovi.monto;
            ELSIF v_afecta = 'E' THEN
               --- Reversar recargos
               v_val_recargo := rp_gmovi.monto;
            END IF;
            -- DYDMR 2794 ITGF - Prestamos Inconsistentes SC 21416
            -- Al reversar el desembolso de un préstamo, los saldos del devengado deben quedar en 0 (cero)
            UPDATE pr_cuotas
               SET estado                       = 'N',
                   sal_interes                   = 0,
                   sal_capital                   = 0,
                   sal_int_documentado  = 0,
                   fec_ult_pago                = rp_gmovi.fecha,
                   dev_acumulado            = 0,
                   dev_no_cobrado           = 0,
                   dev_suspenso               = 0
             WHERE nro_cuenta = rp_gmovi.nro_cuenta;
            UPDATE pr_cta_prestamos
               SET sal_capital               = 0,
                   sal_interes                 = 0,
                   sal_int_adelantado    = 0,
                   fec_cancelacion         = rp_gmovi.fecha,
                   estado                        = 'N',
                   nro_solicitud              = NULL,
                   val_int_devengar       = 0,
                   dev_acumulado         = 0,
                   dev_no_cobrado        = 0,
                   dev_suspenso            = 0
             WHERE nro_cuenta = rp_gmovi.nro_cuenta;
             DELETE pr_devengados where nro_cuenta = rp_gmovi.nro_cuenta;
         END IF;
         --- Eliminar garantias
         DELETE FROM pr_cta_garantias WHERE nro_cuenta = rp_gmovi.nro_cuenta;
         -- Recalcular línea
         IF v_nro_linea IS NOT NULL THEN
            prp_rec_apl_limite(v_nro_linea);
         END IF;
         --- Reversión de Pase Operaciones vencidas ---
      ELSIF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 15 AND
            v_ope_pendiente = 'N' AND rp_gmovi.cod_tra_padre IN (358) THEN
         -- pase a operaciones vencidas

         UPDATE ov_cta_vencidas
            SET sal_total          = 0,
                sal_tot_batch      = 0,
                fec_ult_movimiento = rp_gmovi.fecha,
                estado             = 'N'
          WHERE nro_cuenta = rp_gmovi.nro_cuenta;
         --- Eliminar garantias de op. vencidas
         DELETE FROM ov_cta_garantias WHERE nro_cuenta = rp_gmovi.nro_cuenta;

         --- Reversión de Cobros de Operaciones vencidas ---
      ELSIF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 15 AND
            v_ope_pendiente = 'N' AND rp_gmovi.cod_tra_padre IN (139) THEN
         -- Recuperar datos de la operación vencida
         pav_ove.pr_obt_dat_ope_vencida(rp_gmovi.nro_cuenta, r_vcven);
         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         --- Inicializar errores de pag_cta
         pag_cta.g_msj_error := NULL;
         pag_cta.g_cod_error := 0;
         --- Inicializar variables de descuento
         v_estado       := NULL;
         v_est_cuenta   := NULL;
         v_est_anterior := NULL;
         v_capital      := 0;
         v_val_recargo  := 0;

         --- Recuperar fecha de ultimo pago y estado anterior de ov_cobros
         BEGIN
            SELECT fec_ult_pago, estado, estado
              INTO v_fec_ult_pago, v_estado, v_est_cuenta
              FROM ov_cobros
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND fecha = rp_gmovi.fecha
               AND hora = rp_gmovi.hora;
            --- Actualizar el estado de la operación vencida
            UPDATE ov_cta_vencidas
               SET estado             = nvl(v_est_cuenta, estado),
                   fec_ult_movimiento = v_fec_ult_pago
             WHERE nro_cuenta = rp_gmovi.nro_cuenta;
         EXCEPTION
            WHEN no_data_found THEN
               v_fec_ult_pago := NULL;
               v_estado       := NULL;
         END;
         --- Verificar como afecta a la operación vencida la transaccion
         IF v_afecta = 'S' THEN
            --- Reversar saldo
            v_capital := rp_gmovi.monto;
         ELSIF v_afecta = 'E' THEN
            --- Reversar recargos
            v_val_recargo := rp_gmovi.monto;
         END IF;
         DECLARE
            v_can_cambios NUMBER(8); -- para contar cambios o mov posteriores
         BEGIN
            -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
            BEGIN
               SELECT (CASE
                         WHEN ((nvl(v.est_cuenta, 'x') != 'N' AND v.cod_modulo != 6) OR
                              (v.cod_modulo = 6 AND
                              nvl(fup_obt_tip_descuento(v.cod_modalidad), 'x') != 'C')
                              --Para el módulo de PRESTAMOS con el tipo diferente a descuento CHEQUES,
                              --ya que para todas las otras modalidades del módulo PRESTAMOS,
                              --QUE NO SEAN DE DESCUENTO DE CHEQUES, SE DEBE REVERSAR en el orden inverso en que fueron cargados.
                              ) THEN
                          1
                         ELSE
                          0
                      END)
                 INTO v_can_cambios
                 FROM (SELECT est_cuenta, cod_modulo, cod_modalidad
                         FROM gv_movimientos
                        WHERE nro_cuenta = rp_gmovi.nro_cuenta
                          AND ((fec_valor > rp_gmovi.fec_valor) OR
                              (fec_valor = rp_gmovi.fec_valor AND hora > rp_gmovi.hora))
                          AND reversado = 'N'
                          AND cod_tra_padre NOT IN (150, 200, 730, 731, 945)
                          AND ((est_cuenta IS NOT NULL AND nvl(cod_tip_movimiento, 'x') = 'E') OR
                              (v_est_anterior IS NOT NULL)) -- si hubo otro cambio de estado posterior
                        ORDER BY fec_insercion DESC) v
                WHERE rownum = 1;
            EXCEPTION
               WHEN no_data_found THEN
                  v_can_cambios := 0;
            END;
            IF nvl(v_can_cambios, 0) > 0 THEN
               raise_application_error(-20003,
                                       'La cuenta ' || rp_gmovi.nro_cuenta ||
                                        ' tiene movimientos posteriores que deben ser reversados previamente.');
            END IF;
            IF v_fec_ult_mov_ant IS NOT NULL THEN
               -- verifico sino hubo movimientos posteriores de la cuenta
               SELECT COUNT(*)
                 INTO v_can_cambios
                 FROM gv_movimientos
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND ((fecha > rp_gmovi.fecha) OR
                      (fecha = rp_gmovi.fecha AND hora > rp_gmovi.hora))
                  AND reversado = 'N'
                  AND monto > 0 -- si hubo un mov posterior
                  AND rownum = 1;
               IF nvl(v_can_cambios, 0) > 0 THEN
                  -- en este caso nada mas no se actualiza los datos del ultimo mov
                  v_fec_ult_mov_ant := NULL;
                  v_hor_ult_mov_ant := NULL;
               END IF;
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               v_fec_ult_mov_ant := NULL;
               v_hor_ult_mov_ant := NULL;
            WHEN OTHERS THEN
               raise_application_error(-20000, SQLERRM || ' Buscando ge_cuentas_nov ');
         END;
         --- Actualizar maestro de op.vencidas
         UPDATE ov_cta_vencidas
            SET sal_total = nvl(sal_total, 0) + nvl(v_capital, 0)
          WHERE nro_cuenta = rp_gmovi.nro_cuenta;

         -- actualizacion de garantias--
         v_con_garantia_ven := nvl(v_con_garantia_ven, 0) + 1;
         IF nvl(v_con_garantia_ven, 0) = 1 THEN
            --Actualizar mto. aplicado de la garantia
            FOR i IN garantias_ov(rp_gmovi.nro_cuenta) LOOP
               v_mto_apl_reversar := lf_obt_mto_apl_reversar(rp_gmovi.nro_cuenta, i.cod_garantia,
                                                             i.nro_garantia, p_fecha, p_hora,
                                                             p_cod_usuario);
               IF i.cod_garantia = 1 THEN
                  UPDATE ov_cta_garantias x
                     SET x.mto_aplicado = nvl(x.mto_aplicado, 0) + v_mto_apl_reversar
                   WHERE x.nro_cuenta = rp_gmovi.nro_cuenta
                     AND x.cod_garantia = i.cod_garantia;
               ELSE
                  UPDATE ov_cta_garantias x
                     SET x.mto_aplicado = nvl(x.mto_aplicado, 0) + v_mto_apl_reversar
                   WHERE x.nro_cuenta = rp_gmovi.nro_cuenta
                     AND x.cod_garantia = i.cod_garantia
                     AND x.nro_garantia = i.nro_garantia;
               END IF;
            END LOOP;
         END IF;
         --Eliminar la novedad de la garantia
         DELETE ov_cta_garantias_nov
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_cuenta = rp_gmovi.nro_cuenta;

         --- Eliminar pr_cobros
         DELETE ov_cobros
          WHERE nro_cuenta = rp_gmovi.nro_cuenta
            AND fecha = rp_gmovi.fecha
            AND hora = rp_gmovi.hora;

         --- actualizar pr_cta_gastos (gastos varios)
         IF nvl(v_val_recargo, 0) > 0 THEN
            DECLARE
               CURSOR gastos IS
                  SELECT nro_cuenta, monto, saldo, ROWID
                    FROM ov_cta_gastos
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND ((cod_transaccion = rp_gmovi.cod_transaccion) OR
                         (rp_gmovi.concepto LIKE 'Iva Gasto Manual ' || cod_transaccion))
                     AND nvl(saldo, 0) < nvl(monto, 0)
                   ORDER BY nro_cuenta, cod_modalidad, cod_transaccion, fec_ingreso DESC;
            BEGIN
               v_sal_recargo := v_val_recargo; -- Si existe mas de un cargo con la misma transaccion
               FOR g IN gastos LOOP
                  -- Si el gasto es mayor o igual al monto, actualizo la tabla ov_cta_gastos como NO cobrado
                  BEGIN
                     IF nvl(v_val_recargo, 0) + nvl(g.saldo, 0) < nvl(g.monto, 0) THEN
                        ---
                        UPDATE ov_cta_gastos
                           SET fec_ult_pago = NULL,
                               hor_ult_pago = NULL,
                               saldo        = nvl(saldo, 0) + v_val_recargo
                         WHERE nro_cuenta = rp_gmovi.nro_cuenta
                           AND ROWID = g.ROWID;
                        v_sal_recargo := v_sal_recargo - v_val_recargo;
                     ELSE
                        UPDATE ov_cta_gastos
                           SET fec_ult_pago = NULL,
                               hor_ult_pago = NULL,
                               saldo        = g.monto
                         WHERE nro_cuenta = rp_gmovi.nro_cuenta
                           AND ROWID = g.ROWID;
                        v_sal_recargo := v_sal_recargo - g.monto;
                     END IF;
                  EXCEPTION
                     WHEN OTHERS THEN
                        NULL;
                  END;
               END LOOP;
            END;
         END IF;
      ELSIF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 10 AND
            v_ope_pendiente = 'N' AND rp_gmovi.cod_tra_padre IN (101) THEN
         -- COMPRA DOCUMENTO

         -- Actualizar el estado del documento
         IF rp_gmovi.nro_cuenta IS NOT NULL THEN
            BEGIN
               -- reverso El documento
               prg_rev_auditoria('MD_CTA_DOCUMENTOS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                                 rp_gmovi.nro_cuenta);
               -- Actualiza MD_DOC_DETALLES
               prg_rev_auditoria('MD_DOC_DETALLES', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                                 rp_gmovi.nro_cuenta);
               -- Actualizar los documentos relacionados
               FOR doc IN documentos LOOP
                  UPDATE md_cta_documentos SET estado = 'S' WHERE nro_cuenta = doc.nro_cuenta;
                  UPDATE md_cuo_instrumentos SET estado = 'S' WHERE nro_cuenta = doc.nro_cuenta
                         and nro_cta_repo = rp_gmovi.nro_cuenta;
               END LOOP;
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000,
                                          'Error al modificar MD_CTA_DOCUMENTOS. ' || SQLERRM);
            END;
         END IF;
      ELSIF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 10 AND
            v_ope_pendiente = 'N' AND rp_gmovi.cod_tra_padre = 102 THEN
         -- Recuperar datos del documento
         pam_doc.pr_obt_datos(rp_gmovi.nro_cuenta, r_docu);
         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         --- Inicializar errores de pag_cta
         pag_cta.g_msj_error := NULL;
         pag_cta.g_cod_error := 0;
         --- Inicializar variables de descuento
         v_estado           := NULL;
         v_est_cuenta       := NULL;
         v_est_anterior     := NULL;
         v_capital          := 0;
         v_interes          := 0;
         v_val_recargo      := 0;
         v_int_descontado   := 0;
         v_devengado        := 0;
         v_capital_deven    := 0;
         v_mto_cap_cuota    := 0;
         v_mto_dev_actual   := 0;
         v_cu_dev_acumulado := 0;

         --- Verificar como afecta al prestamo la transaccion
         IF v_afecta = 'C' THEN
            --- Reversar capital
            v_capital := rp_gmovi.monto;
         ELSIF v_afecta = 'I' THEN
            --- Reversar interes vencido
            v_interes := rp_gmovi.monto;
         END IF;

         IF v_devengo = 'N' THEN
            v_devengo := 'S';
            --- Recuperar datos del devengado
            BEGIN
               BEGIN
                  SELECT estado, mto_dev_actual, fec_inicio
                    INTO v_est_cuenta, v_mto_dev_actual, v_fec_ini_dev
                    FROM md_devengados
                   WHERE nro_cuenta = rp_gmovi.nro_cuenta
                     AND fecha = rp_gmovi.fecha;

                  v_fec_ult_devengado := pag_cal.fu_obt_fec_ant_hab(rp_gmovi.fecha,
                                                                    rp_gmovi.cod_ofi_origen);

               EXCEPTION
                  WHEN no_data_found THEN
                     v_fec_ult_devengado := NULL;
                     v_est_cuenta        := NULL;
                     v_mto_dev_actual    := NULL;
               END;
               --- Actualizar el devengado de la cuota en pr_devengados
               --- Solo si devengo, si se cambio los suspendidos o cobros nada mas no tocar
               IF nvl(v_mto_dev_actual, 0) <> 0 THEN
                  --- Recuperar capital segun el tipo de documento
                  IF r_docu.tip_calculo = 'A' THEN
                     v_capital_deven := nvl(r_docu.val_presente, 0) + nvl(r_docu.mto_interes, 0);
                  ELSE
                     IF r_docu.fec_vencimiento > v_fec_ini_dev THEN
                        v_capital_deven := nvl(r_docu.val_presente, 0);
                     END IF;
                  END IF;

                  --- Recuperar capital
                  --- Solo se reversa si devengo el dia del cobro por esa fecha o adelantado
                  IF v_fec_ult_devengado IS NULL THEN
                     --se elimina md_devengados
                     DELETE md_devengados
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                  ELSE
                     UPDATE md_devengados
                        SET fecha             = v_fec_ult_devengado,
                            mto_dev_acumulado = mto_dev_acumulado - mto_dev_actual,
                            can_dia_interes   = nvl(can_dia_anterior, 0),
                            mto_dev_actual    = nvl(mto_dev_anterior, 0),
                            mto_ajuste        = NULL,
                            fec_ult_devengado = v_fec_ult_devengado
                      WHERE nro_cuenta = rp_gmovi.nro_cuenta;
                  END IF;
               END IF;
            END;
         END IF;
         --
         DECLARE
            v_can_cambios NUMBER(8); -- para contar cambios o mov posteriores
         BEGIN
            -- verifico sino hubo un cambio posterior de estado o un mov. posterior a este cambio de estado
            SELECT COUNT(*)
              INTO v_can_cambios
              FROM ge_movimientos
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND hora > rp_gmovi.hora
               AND reversado = 'N'
               AND (est_cuenta IS NOT NULL OR v_est_anterior IS NOT NULL) -- si hubo otro cambio de estado posterior
               AND rownum = 1;
            IF nvl(v_can_cambios, 0) > 0 THEN
               raise_application_error(-20000,
                                       'La cuenta ' || rp_gmovi.nro_cuenta ||
                                        ' tiene movimientos posteriores que deben ser reversados previamente.');
            END IF;
            IF v_fec_ult_mov_ant IS NOT NULL THEN
               -- verifico sino hubo movimientos posteriores de la cuenta
               SELECT COUNT(*)
                 INTO v_can_cambios
                 FROM ge_movimientos
                WHERE nro_cuenta = rp_gmovi.nro_cuenta
                  AND hora > rp_gmovi.hora
                  AND reversado = 'N'
                  AND monto > 0 -- si hubo un mov posterior
                  AND rownum = 1;
               IF nvl(v_can_cambios, 0) > 0 THEN
                  -- en este caso nada mas no se actualiza los datos del ultimo mov
                  v_fec_ult_mov_ant := NULL;
                  v_hor_ult_mov_ant := NULL;
               END IF;
            END IF;
         EXCEPTION
            WHEN no_data_found THEN
               v_fec_ult_mov_ant := NULL;
               v_hor_ult_mov_ant := NULL;
            WHEN OTHERS THEN
               raise_application_error(-20000, SQLERRM || ' Buscando ge_cuentas_nov ');
         END;
         --- Actualizar maestro del documento
         prg_rev_auditoria('MD_CTA_DOCUMENTOS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                           rp_gmovi.nro_cuenta);
         -- Actualiza MD_DOC_DETALLES
         prg_rev_auditoria('MD_DOC_DETALLES', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                           rp_gmovi.nro_cuenta);
         ---CNFREINT-1 --LCABRERA / AGOSTO-2015
         -- Actualiza MD_CUO_INSTRUMENTOS
         prg_rev_auditoria('MD_CUO_INSTRUMENTOS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                           rp_gmovi.nro_cuenta);
      ELSIF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 10 AND
            v_ope_pendiente = 'N' AND rp_gmovi.cod_tra_padre = 360 THEN
         --
         v_capital := 0;
         v_interes := 0;
         -- Recuperar datos del documento
         pam_doc.pr_obt_datos(rp_gmovi.nro_cuenta, r_docu);
         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         --- Inicializar errores de pag_cta
         pag_cta.g_msj_error := NULL;
         pag_cta.g_cod_error := 0;

         --- Verificar como afecta al prestamo la transaccion
         IF v_afecta = 'C' THEN
            --- Reversar capital
            v_capital := rp_gmovi.monto;
            v_interes := 0;
         ELSIF v_afecta = 'I' THEN
            --- Reversar interes vencido
            v_interes := rp_gmovi.monto;
            v_capital := 0;
         END IF;
         --
         --DYDMR-3625 ITGF - Incidencia en Actualizacion de Saldos de Anticipo SC 27815
         BEGIN
            -- reverso El documento
            prg_rev_ran_auditoria('MD_CTA_DOCUMENTOS',rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                              rp_gmovi.nro_cuenta);

            /*prg_rev_auditoria('MD_CTA_DOCUMENTOS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                              rp_gmovi.nro_cuenta);*/

         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al modificar MD_CTA_DOCUMENTOS. ' || SQLERRM);
         END;
         --
         BEGIN
            -- reverso estado de las cuotas
            prg_rev_auditoria('MD_CUO_INSTRUMENTOS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                              rp_gmovi.nro_cuenta);
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20002, 'Error al modificar MD_CUO_INSTRUMENTOS. ' || SQLERRM);
         END;
         --
         --
         BEGIN
            UPDATE md_doc_detalles
               SET sal_interes        = nvl(sal_interes, 0) + nvl(v_interes, 0),
                   sal_capital        = nvl(sal_capital, 0) + nvl(v_capital, 0),
                   mto_int_descontado = 0,
                   estado             = 'C',
                   fec_ult_pago       = NULL
             WHERE nro_cuenta = rp_gmovi.nro_cuenta
               AND nro_cuota = rp_gmovi.nro_documento3;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error update MD_DOC_DETALLES. ' || SQLERRM);
         END;
      ELSIF rp_gmovi.monto <> 0 AND rp_gmovi.cod_modulo = 16 AND v_ope_pendiente = 'N' AND
            rp_gmovi.cod_tra_padre IN (369, 987) THEN
         --Cajas de Seguridad

         -- obtengo el tipo d/c y a que saldo afecto
         pr_obt_tip_transaccion(rp_gmovi.cod_transaccion, rp_gmovi.cod_modulo,
                                rp_gmovi.cod_modalidad, v_tip_movimiento, v_afecta);
         --- Inicializar errores de pag_cta
         pag_cta.g_msj_error := NULL;
         pag_cta.g_cod_error := 0;
         --- Inicializar variables de descuento
         v_estado  := NULL;
         v_capital := 0;
         --- Verificar como afecta al prestamo la transaccion
         IF v_afecta = 'C' OR rp_gmovi.cod_transaccion = 518 THEN
            --- Reversar capital
            v_capital := rp_gmovi.monto;
         END IF;

         DECLARE
            v_can_cambios NUMBER(8); -- para contar cambios o mov posteriores
         BEGIN
            -- verifico sino hubo un mov. posterior
            SELECT COUNT(*)
              INTO v_can_cambios
              FROM gv_movimientos
             WHERE nro_documento = rp_gmovi.nro_documento
               AND ((fec_valor > rp_gmovi.fec_valor) OR
                   (fec_valor = rp_gmovi.fec_valor AND hora > rp_gmovi.hora))
               AND reversado = 'N'
               AND cod_mod_padre = 16
               AND rownum = 1;
            IF nvl(v_can_cambios, 0) > 0 THEN
               raise_application_error(-20000,
                                       'El Contrato ' || rp_gmovi.nro_documento ||
                                        ' tiene movimientos posteriores que deben ser reversados previamente.');
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, SQLERRM || ' Buscando datos del contrato ');
         END;
         IF nvl(rp_gmovi.monto, 0) > 0 THEN
            BEGIN
               prg_rev_auditoria('CS_CONTRATOS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                                 rp_gmovi.nro_documento);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, SQLERRM || ' Al actualizar el contrato ');
            END;
            BEGIN
               prg_rev_auditoria('CS_CON_CUOTAS', rp_gmovi.fec_insercion, rp_gmovi.cod_usuario,
                                 rp_gmovi.nro_documento);
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000, SQLERRM || ' Al actualizar cuotas del contrato ');
            END;
         END IF;
      ELSIF rp_gmovi.nro_cuenta IS NOT NULL AND rp_gmovi.monto <> 0 AND --sipap
            rp_gmovi.cod_tra_padre = pas_snp.fu_obt_cod_tra_padre AND
            rp_gmovi.cod_mod_padre = pas_snp.fu_obt_cod_mod_padre AND
            rp_gmovi.cod_mad_padre = pas_snp.fu_obt_cod_mad_padre THEN
         -- Movimientos relacionados a SNP
         DECLARE
            v_nro_referencia   ge_snp_transferencias.nro_referencia%TYPE;
            v_cod_tip_circuito wf_tip_circuitos.cod_tip_circuito%TYPE;
            rg_cir             wf_circuitos%ROWTYPE;
            v_ind_circuito     VARCHAR2(1) := 'N';
         BEGIN
            -- Si todavía no se encontró la mensajería se busca.
            IF v_snp_exi_transferencia = 'N' THEN
               BEGIN
                  SELECT t.nro_referencia
                    INTO v_nro_referencia
                    FROM ge_snp_transferencias t
                   WHERE t.nro_referencia = rp_gmovi.nro_documento;

                  pas_snp.pr_obt_mensaje(v_nro_referencia);
                  IF pas_snp.fu_obt_cod_error <> 0 THEN
                     raise_application_error(-20000,
                                             pas_snp.fu_obt_cod_error || ' - ' ||
                                              pas_snp.fu_obt_msj_error);
                  END IF;
                  -- Si encontró la transferencias SNP, se guarda la mensajería en la variable rg_snp_msj
                  v_snp_exi_transferencia := 'S';
                  rg_snp_msj              := pas_snp.fu_obt_reg_transferencias;
                  --
                  /*
                  || Para transferencias con detalle de recaudación relacionada se deben desmarcar los registros que forman parte de la transferencia reversada.
                  || Como toda la recaudación debe informarse a IPS los registros del extracto reversados recientemente
                  || deben ser enviados nuevamente con la transferencia pendiente de envío al BCP.
                  */
                  IF rg_snp_msj.cod_servicio IS NOT NULL THEN
                     BEGIN
                        prs_snp_rev_tra_servicio(rg_snp_msj.nro_referencia);
                     EXCEPTION
                        WHEN OTHERS THEN
                           IF SQLCODE <= -20000 THEN
                              RAISE;
                           ELSE
                              raise_application_error(-20001,
                                                      'Intentando actualizar transferencia por Cobro del Servicio Nro. ' ||
                                                       rg_snp_msj.cod_servicio || ': ' || SQLERRM);
                           END IF;
                     END;
                  END IF;
               EXCEPTION
                  WHEN no_data_found THEN
                     v_snp_exi_transferencia := 'N';
                     RAISE pas_snp.ex_salir;
                  WHEN OTHERS THEN
                     v_snp_exi_transferencia := 'N';
                     raise_application_error(-20002,
                                             'Error al obtener datos de la mensajería ' ||
                                              rp_gmovi.nro_documento || ' ' || 'Fec/Hora: ' ||
                                              to_char(rp_gmovi.fecha, 'DD/MM/YYYY') || ' ' ||
                                              rp_gmovi.hora || 'Usuario: ' || rp_gmovi.cod_usuario || ', ' ||
                                              SQLERRM);
               END;
            END IF;

            --- verificación de la mensajería a partir del movimiento de la interbancaria.
            IF rp_gmovi.cod_modulo = pas_snp.fu_obt_cod_mod_padre AND
               rp_gmovi.cod_modalidad = pas_snp.fu_obt_cod_mad_padre AND
               rg_snp_msj.nro_referencia IS NOT NULL AND rp_gmovi.nro_documento2 IS NOT NULL THEN
               /*
               || Todos los SWIFTs APROBADOS, pero con situación distinta a CANCELADO, ERROR y LIQUIDADO NO podrán reversarse.
               || Para todos los otros estados (SOLICITADO, VERIFICADO, etc) de la mensajería que no estén con estado APROBADOS podrán reversarse.
               || Si una mensajería ya fue LIQUIDADA se podrá reversar el movimiento, se colocará a la mensajería el estado SOLICITADO y situación
               || PENDIENTE DE AUTORIZACION EN WF
               || Al reversar la operación se intentará cancelar la mensajería asociada y tareas pendientes del Workflow.
               || Si se reversa una mensajería LIQUIDADA se creará otro WorkFlow para su posterior proceso.
               */
               IF rg_snp_msj.plataforma = 'X' THEN
                  IF rg_snp_msj.estado = 'A' THEN
                     IF (pas_snp.fu_val_es_enviado(rg_snp_msj) AND -- Si es enviado
                        nvl(rg_snp_msj.situacion, '~') NOT IN ('P', 'C', 'E') AND -- Si la situación no es Pendiente de Envío a BCP, Cancelado o con Error
                        nvl(pae_cnf.g_programa, '~') IN ('GMREVOPE', 'GMREVHIS')) OR
                        (NOT pas_snp.fu_val_es_enviado(rg_snp_msj) AND -- Si es recibido
			rg_snp_msj.cod_msj_swift != 104 AND 
                        nvl(rg_snp_msj.situacion, '~') NOT IN ('C', 'E', 'L') -- Si la situación no es Cancelado o con Error o Liquidado
                        ) THEN
                        raise_application_error(-20003,
                                                ' No se puede reversar Transferencia Interbancaria con situación ' || CASE
                                                    WHEN upper(fue_obt_des_refcodes('SITUACION', nvl(rg_snp_msj.situacion, '~'))) LIKE
                                                         '%REF%REG%SISTEMA' THEN
                                                     'NULA'
                                                    ELSE
                                                     upper(fue_obt_des_refcodes('SITUACION', nvl(rg_snp_msj.situacion, '~')))
                                                 END || ' Fec/Hora: ' ||
                                                 to_char(rp_gmovi.fecha, 'DD/MM/YYYY') || ' ' ||
                                                 rp_gmovi.hora || ' Usuario: ' ||
                                                 rp_gmovi.cod_usuario || ' Cod. Mod. Padre: ' ||
                                                 rp_gmovi.cod_mod_padre);
                     ELSIF NOT pas_snp.fu_val_es_enviado(rg_snp_msj) AND
                           nvl(rg_snp_msj.situacion, '~') = 'L' THEN
                        -- Para mensajes recibidos con estado Aprobado y situación Liquidada
                        -- se recupera el circuito que debe iniciar solo cuando la mensajería es RECIBIDA
                        v_cod_tip_circuito := pas_snp.fu_obt_cod_tip_cir_workflow(rg_snp_msj.cod_msj_swift,
                                                                                  'C',
                                                                                  -- Reversado
                                                                                  rg_snp_msj.cod_tip_operacion,
                                                                                  rg_snp_msj.cod_sub_tip_operacion);
                        IF pas_snp.fu_obt_cod_error <> 0 THEN
                           raise_application_error(-20004,
                                                   pas_snp.fu_obt_cod_error || '-' ||
                                                    pas_snp.fu_obt_msj_error);
                        END IF;
                        --
                        -- Se desvincula a la mensajería del movimiento y se levanta nuevamente WF.
                        rg_snp_msj.estado      := 'S';
                        rg_snp_msj.situacion   := 'I';
                        rg_snp_msj.fecha       := NULL;
                        rg_snp_msj.hora        := NULL;
                        rg_snp_msj.cod_usuario := NULL;
                        v_ind_circuito         := 'S';
                        pas_snp.pr_set_transferencias(rg_snp_msj);
                        -- Si es MT102 ó MT103 recibido y liquidado se debe enviar alerta al cliente por la Transferencia (si aplica)
                        IF rg_snp_msj.cod_msj_swift IN (103, 102) THEN
                           v_snp_env_alerta := 'S';
                        END IF;
                        --
                     END IF;
                  END IF;
                  --
                  --Se cancela el circuito
                  BEGIN
                     /*Se recupera el circuito generado para la cancelación*/
                     SELECT *
                       INTO rg_cir
                       FROM wf_circuitos
                      WHERE referencia = pas_snp.g_msj.nro_referencia
                        AND estado NOT IN ('C', 'F');

                     --Se actualiza a cancelada las tareas para las tablas
                     --wf_cir_tareas y wf_circuitos
                     UPDATE wf_cir_tareas
                        SET estado = 'C'
                      WHERE cod_circuito = rg_cir.cod_circuito
                        AND estado = 'P';
                     --
                     UPDATE wf_circuitos SET estado = 'C' WHERE cod_circuito = rg_cir.cod_circuito;

                     IF v_ind_circuito = 'S' AND v_cod_tip_circuito IS NOT NULL THEN
                        IF paw_cir.fu_ini_circuito(v_cod_tip_circuito, rg_cir.referencia,
                                                   rg_cir.cod_persona) <> 0 THEN
                           RAISE pas_snp.ex_workflow;
                        END IF;
                     END IF;

                  EXCEPTION
                     WHEN pas_snp.ex_workflow THEN
                        raise_application_error(-20005,
                                                'Error al ejecutar el PAW_CIR.FU_INI_CIRCUITO: ' ||
                                                 SQLERRM);
                     WHEN no_data_found THEN
                        IF v_ind_circuito = 'S' AND v_cod_tip_circuito IS NOT NULL THEN
                           IF paw_cir.fu_ini_circuito(v_cod_tip_circuito,
                                                      pas_snp.g_msj.nro_referencia,
                                                      nvl(pas_snp.g_msj.cod_per_solicitante,
                                                           fug_obt_per_entidad)) <> 0 THEN
                              raise_application_error(-20006,
                                                      'Error al iniciar CIRCUITO p/ MT Nro.Ref.: ' ||
                                                       pas_snp.g_msj.nro_referencia);
                           END IF;
                        END IF;
                     WHEN OTHERS THEN
                        raise_application_error(-20007,
                                                'Error al cancelar circuito: ' ||
                                                 nvl(paw_cir.fu_obt_cod_error, SQLERRM));
                  END;
               ELSIF rg_snp_msj.plataforma = 'G' THEN
                  IF rg_snp_msj.cod_msj_swift IN (103, 102) THEN
                     v_snp_env_alerta := 'S';
                  END IF;
               END IF;
               -- Si no inicia CIRCUITO y es llamado desde el programa GMSNP202 o GMSNP103, el update se hace a nivel de formulario
               IF v_ind_circuito = 'N' AND
                  nvl(pae_cnf.g_programa, '~') NOT IN ('GMSNP202', 'GMSNP103') AND
                  nvl(rg_snp_msj.estado, '~') <> 'C' THEN
                  rg_snp_msj.estado := 'C';
                  pas_snp.pr_set_transferencias(rg_snp_msj);
               END IF;
               --
            END IF;
         EXCEPTION
            WHEN pas_snp.ex_salir THEN
               NULL;
            WHEN OTHERS THEN
               RAISE;
         END;
      ELSIF p_cod_mod_padre = 3 AND p_cod_mad_padre = 36 THEN
         --- Movimiento de Devengado de Plusvalía/Minusvalía,
         --- debe actualizar la tabla AH_DEV_BON_SUBORDINADOS a sus valores anteriores
         --- RABF 16/ene/2012
         BEGIN
            SELECT cod_ente
              INTO v_cod_empresa
              FROM ge_entes
             WHERE tipo = 'BO';
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20000, 'Sin datos para el ente de Bonos');
            WHEN too_many_rows THEN
               raise_application_error(-20000, 'Mas de un ente para Bonos');
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error Obt.Ente p/Bonos:' || SQLERRM);
         END;
         IF rp_gmovi.cod_transaccion IN (fug_obt_parentes(v_cod_empresa, 'COD_TRA_DEV_PLUSVALIA'),
                                         fug_obt_parentes(v_cod_empresa, 'COD_TRA_DEV_MINUSVALIA')) THEN
            UPDATE ah_dev_bon_subordinados t
            SET    t.mto_dev_acumulado = nvl(t.mto_dev_acumulado,0) - nvl(t.mto_dev_actual,0),
                   t.mto_dev_actual = nvl(t.mto_dev_anterior,0),
                   t.can_dia_actual = nvl(t.can_dia_anterior,0),
                   t.fec_ult_proceso = t.fec_ult_proceso - nvl(t.can_dia_actual,0)
            WHERE  t.nro_cuenta = rp_gmovi.referencia;
         END IF;
      END IF;
   END;
   /* Actualiza los movimientos historicos a reversado. */
   PROCEDURE lp_act_dat_histo
   (
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_nro_secuencia     IN ge_movimientos.nro_secuencia%TYPE,
      p_cod_usu_insercion IN ge_movimientos.cod_usu_reversion%TYPE,
      p_hor_reversion     IN ge_movimientos.hor_reversion%TYPE,
      p_cod_modulo        IN ge_movimientos.cod_modulo%TYPE
   ) IS
   BEGIN
      -- AHORRO
      IF p_cod_modulo = 3 THEN
         UPDATE ah_movimientos_his
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = p_nro_secuencia
            AND reversado = 'N';
         -- CUENTA CORRIENTE
      ELSIF p_cod_modulo = 4 THEN
         UPDATE cc_movimientos_his
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = p_nro_secuencia
            AND reversado = 'N';
         -- PRESTAMO
      ELSIF p_cod_modulo = 6 THEN
         UPDATE pr_movimientos_his
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = p_nro_secuencia
            AND reversado = 'N';
         --  CAMBIOS
      ELSIF p_cod_modulo = 7 THEN
         UPDATE lc_movimientos_his
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = p_nro_secuencia
            AND reversado = 'N';
         -- COMERCIO EXTERIOR
      ELSIF p_cod_modulo = 8 THEN
         UPDATE cx_movimientos_his
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = p_nro_secuencia
            AND reversado = 'N';
      END IF;
   END;
   ---------------- función garantias de operaciones vencidas
   FUNCTION lf_obt_mto_apl_reversar
   (
      p_nro_cuenta   IN VARCHAR2,
      p_cod_garantia IN NUMBER,
      p_nro_garantia IN NUMBER,
      p_fecha        IN DATE,
      p_hora         IN VARCHAR2,
      p_cod_usuario  IN VARCHAR2
   ) RETURN NUMBER IS
      --Obtiene el monto a reversar de la garantia--
      --segun sus registros de novedades--
      v_mto_apl_reversar NUMBER(18, 2) := 0;

   BEGIN
      --Obtener el monto a reversar--
      SELECT a.mto_aplicado
        INTO v_mto_apl_reversar
        FROM ov_cta_garantias_nov a
       WHERE a.fecha = p_fecha
         AND a.hora = p_hora
         AND a.cod_usuario = p_cod_usuario
         AND a.nro_cuenta = p_nro_cuenta
         AND a.cod_garantia = p_cod_garantia
         AND nvl(a.nro_garantia, 999) = nvl(p_nro_garantia, 999);
      RETURN v_mto_apl_reversar;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error en fl_obt_mto_apl_reversar : ' || SQLERRM);
   END;
   ---------------------------------------------------------------------------
   --Traer datos de la retencion
   PROCEDURE lp_obt_retencion
   (
      p_nro_cuenta      ah_retenciones.nro_cuenta%TYPE,
      p_nro_documento   ah_retenciones.nro_documento%TYPE,
      p_cod_retencion   ah_retenciones.cod_retencion%TYPE,
      p_fec_inicio      ah_retenciones.fec_inicio%TYPE,
      rp_ah_retenciones IN OUT ah_retenciones%ROWTYPE
   ) IS

   BEGIN

      SELECT *
        INTO rp_ah_retenciones
        FROM ah_retenciones
       WHERE nro_cuenta = p_nro_cuenta
         AND nro_documento = p_nro_documento
         AND cod_retencion = p_cod_retencion
         AND fec_inicio = p_fec_inicio;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error en lp_obt_retencion : ' || SQLERRM);

   END;
   FUNCTION lf_ver_est_bien(p_cod_grupo IN VARCHAR2) RETURN VARCHAR2 IS
      v_estado VARCHAR2(1);
   BEGIN
      BEGIN
         SELECT estado
           INTO v_estado
           FROM bu_bienes a
          WHERE a.cod_grupo = p_cod_grupo;
      EXCEPTION
         WHEN OTHERS THEN
            v_estado := NULL;
      END;
      RETURN v_estado;
   END;

   FUNCTION lf_obt_ref_mov_mayor(p_hora2 in varchar2) return varchar2 is
      v_existe varchar2(1);
      v_hora ge_movimientos.hora%type;
      pragma autonomous_transaction;
   BEGIN
     v_hora := lf_obt_hor_max_movimiento(p_fecha, p_hora2, p_cod_usuario);
      begin
         SELECT 'S'
           into v_existe
           FROM ge_movimientos g
          WHERE g.fecha = p_fecha
            AND g.hora > p_hora2
            AND g.cod_usuario = p_cod_usuario
            AND g.monto <> 0
            AND g.cod_modulo = 26
            AND g.reversado = 'N'
            AND g.referencia =
                (SELECT m.referencia
                   FROM ge_movimientos m
                  WHERE m.fecha = p_fecha
                    AND m.hora = v_hora
                    AND m.cod_usuario = p_cod_usuario
                    AND m.monto <> 0
                    AND m.cod_modulo = 26
                    AND m.cod_tra_padre = p_cod_tra_padre
                    AND m.cod_transaccion = v_cod_tra_pago)
            and rownum = 1;

      EXCEPTION
         WHEN OTHERS THEN
            v_existe := 'N';
      end;
      return v_existe;
   end;


   PROCEDURE lp_rev_che_cust(p_tip_control   varchar2, /*A= transacciones 59, B= transacciones 58*/
                             p_cod_tra_padre varchar2,
                             p_cod_mod_padre varchar2,
                             p_cod_mad_padre varchar2,
                             p_nro_documento ge_movimientos.nro_documento%TYPE) IS
  BEGIN
    IF p_tip_control = 'A' then
      /*------------------------------------------------------
      control de reversión de transacciones de alta cheq favor (Tr. 59)
      ------------------------------------------------------*/
      DECLARE
        v_existe varchar2(1) := 'N';
      BEGIN

        IF p_cod_tra_padre = 59 AND p_cod_mod_padre IN (3, 4) AND
           p_cod_mad_padre IN (31, 41) THEN
          --TRANSACCION DE (CHEQUES DE FAVOR - ALTA)-- 4 - 41 - 59
          --1) se búsca que todo el lote de cheques esten en estado C = CUSTODIO
          BEGIN
            --1buscamos si existe en el detalle cheques con movimientos.
            SELECT 'S'
              into v_existe
              FROM cc_che_custodias ccf, cc_che_custodias_det ccfd
             where ccf.cod_che_custodia = p_nro_documento
               and ccf.estado = 'N'
               and ccfd.cod_che_custodia = ccf.cod_che_custodia
               and ccfd.estado != 'C' --en custodio (primer estado al dar de alta el cheque)
               and rownum = 1;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              NULL;
            WHEN OTHERS THEN
              raise_application_error(-20006,
                                      'Error al buscar el detalle de Cheques en Custodia, Referencia Nro ' ||
                                      p_nro_documento || 'Error: ' ||
                                      sqlerrm);
          END;

          --1control de operaciones posteriores
          IF v_existe = 'S' THEN
            raise_application_error(-20006,
                                    'Cheque en Custodia Nro: ' ||
                                    p_nro_documento ||
                                    ' tiene movimientos posteriores que deben ser reversados previamente.');
          END IF;

        END IF;

      END;

    ELSIF p_tip_control = 'B' THEN
      /*------------------------------------------------------
      se reversa las transacciones alta y baja cheq favor (Tr. 59 y 58 )
      ------------------------------------------------------*/

      -- CRO-JM-10/2014: Se verifica que exista previamente cod_tra_padre 351 y se haya reversado previamente.
      declare
        v_cta_credito     ge_movimientos.nro_cuenta%type;
        v_nro_boleta      ge_movimientos.nro_documento%type;
        v_existe_custodia varchar2(1);
      begin
        begin
          SELECT ccf.nro_cta_credito, ccfd.nro_boleta
            into v_cta_credito, v_nro_boleta
            FROM cc_che_custodias ccf, cc_che_custodias_det ccfd
           where ccf.cod_che_custodia = p_nro_documento
             and ccf.estado = 'C'
             and ccfd.cod_che_custodia = ccf.cod_che_custodia
             and ccfd.cod_emisor = fug_obt_cod_banco -- solo nuestro banco
             and ccfd.estado != 'C' --en custodio (primer estado al dar de alta el cheque)
             and rownum = 1;
        exception
          when others then
            v_cta_credito := null;
            v_nro_boleta  := null;
        end;
        if v_nro_boleta is not null then
          -- CRO-JM-10/2014: buscamos en ge_movimientos:
          begin
            select 'S'
              into v_existe_custodia
              from ge_movimientos a
             where a.nro_documento = v_nro_boleta
               and a.nro_cuenta = v_cta_credito
               and a.cod_tra_padre = 351  -- CRO-JM-10/2014: verificamos explicitamente esta transaccion
               and nvl(a.reversado, 'N') = 'S';
          exception
            when others then
              v_existe_custodia := 'N';
          end;
          if nvl(v_existe_custodia, 'N') = 'N' then
             raise_application_error(-20001,
                                      'Error. Primero debe reversar el depósito 351.-');
          end if;
        end if;

      end;


      DECLARE
        v_existe      varchar2(1) := 'N';
        v_actualizado varchar2(1) := 'N';
        --para tratar las reversiones de baja de cheque de favor (transacción 58)
        v_cod_che_favor cc_che_custodias_det.cod_che_custodia%type := 0;
        v_nro_secuencia cc_che_custodias_det.nro_secuencia%type := 0;
        --guardamos la posición del 2do punto del concepto.
        v_pos_2do_punto cc_che_custodias_det.nro_secuencia%type := 0; --instr(p_concepto,'.',1,2);
        --
        v_longitud cc_che_custodias_det.nro_secuencia%type := 0;
        --

      BEGIN
        --reversión de alta de cheq de favor TR. 59
        IF p_cod_tra_padre = 59 AND p_cod_mod_padre IN (3, 4) AND
           p_cod_mad_padre IN (31, 41) THEN
          /*actualizamos el detalle de cheque de favor
          CANCELADO = S
          FEC_CANCELACION = fec_actual
          USU_CANCELACION = user*/
          BEGIN
            update cc_che_custodias_det t
               set t.cancelado       = 'S',
                   t.fec_cancelacion = v_fec_actual,
                   t.usu_cancelacion = user,
                   t.nro_boleta = null
             where t.cod_che_custodia = p_nro_documento;
          EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20006,
                                      'Error al actualizar datos del detalle de Cheque en Custodia Nro.' ||
                                      p_nro_documento || 'Error: ' ||
                                      sqlerrm);
          END;
          /*Actualizamos la cabecera de cheque de favor*/
          BEGIN
            update cc_che_custodias t
               set t.estado          = 'C',
                   t.fec_cancelacion = v_fec_actual,
                   t.cobrado         = 'N'
             where t.cod_che_custodia = p_nro_documento;
          EXCEPTION
            WHEN OTHERS THEN
              raise_application_error(-20006,
                                      'Error al actualizar datos de la cabecera Cheque en Custodia Nro.' ||
                                      p_nro_documento || 'Error: ' ||
                                      sqlerrm);
          END;
        END IF;
        --reversión de bsjs de cheq de favor TR. 58
        IF p_cod_tra_padre = 58 AND p_cod_mod_padre IN (3, 4) AND
           p_cod_mad_padre IN (31, 41) THEN

          --buscamos el nro de cheque de favor y la secuencia del detalle para reversar el cheque
          --ej.: g.concepto = Canc.Docum.Cust.35-1 -> Canc.Docum.Cust. = 17 letras
          BEGIN

            select to_number(DECODE(instr(g.concepto, '.', 1, 2),
                                    11,substr(substr(g.concepto, 17),1,instr(substr(g.concepto, 17), '-') - 1),
                                    22,substr(substr(g.concepto, 23),1,instr(substr(g.concepto, 23), '-') - 1),
                                    '0')) cod_che_favor,

                   to_number(DECODE(instr(g.concepto, '.', 1, 2),
                                    11,substr(substr(g.concepto, 17),instr(substr(g.concepto, 17), '-') + 1),
                                    22,substr(substr(g.concepto, 23),instr(substr(g.concepto, 23), '-') + 1),
                                    '0')) nro_secuencia
              into v_cod_che_favor, v_nro_secuencia
              from ge_movimientos g
             where g.cod_usuario = p_cod_usuario
               and g.hora = p_hora
               and g.fecha = p_fecha
               and g.reversado = 'N'
              -- and g.nro_documento = p_nro_documento  -- CRO-JM-10/2014: Se agregó el cambio para lo que respecta a reversiones, de esta manera se realizará la reversion en GS y USD
               and g.cod_tra_padre = p_cod_tra_padre; --transacción baja de cheque de favor.
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_cod_che_favor := 0;
              v_nro_secuencia := 0;
            WHEN OTHERS THEN
              raise_application_error(-20006,
                                      'Error al actualizar datos del detalle Cheque en Custodia, Error: ' ||
                                      sqlerrm);
          END;
          --si se encuentra el cod_cheque y la secuencia lo reversamos
          IF v_cod_che_favor != 0 AND v_nro_secuencia != 0 THEN
            BEGIN
              update cc_che_custodias_det t
                 set t.cancelado       = 'N',
                     t.usu_cancelacion = null,
                     t.fec_cancelacion = null,
                     t.estado          = 'C', --volvemos al primer estado (Custodio)
                     t.nro_boleta      = null
               where t.cod_che_custodia = v_cod_che_favor
                 and t.nro_secuencia = v_nro_secuencia;

              -- v_actualizado := 'S';--marca de actualización realizada
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20006,
                                        'Error al actualizar datos del detalle Cheque en Custodia Nro.' ||
                                        v_cod_che_favor || 'Error: ' ||
                                        sqlerrm);

            END;
            --volvemos al estado de Normal y cobrado NO de la cabecera de cheque de favor
            BEGIN
              update cc_che_custodias t
                 set t.estado = 'N', t.cobrado = 'N'
               where t.cod_che_custodia = v_cod_che_favor;
            EXCEPTION
              WHEN OTHERS THEN
                raise_application_error(-20006,
                                        'Error al actualizar datos de la cabecera Cheque en Custodia Nro.' ||
                                        v_cod_che_favor || 'Error: ' ||
                                        sqlerrm);
            END;
          END IF;
        END IF;
      END;
    END IF;

  END lp_rev_che_cust;

  procedure lp_eli_exoneraciones(
      p_fecha             IN ge_movimientos.fecha%TYPE,
      p_hora              IN ge_movimientos.hora%TYPE,
      p_cod_usuario       IN ge_movimientos.cod_usuario%TYPE,
      p_cod_mod_padre     IN ge_movimientos.cod_mod_padre%TYPE,
      p_cod_autorizacion  IN ge_autorizaciones.cod_autorizacion%TYPE default null,
      p_modo              IN varchar2 default 'D' -- del dia; H - historico
    ) is
  BEGIN
    /*
   || BSEVOCORE-40 Reversion de Exoneraciones de Prestamos 2019/10 NAF
   */
   IF upper(nvl(fug_obt_pardinamico('EXO_HAB_REV_MODULO',p_cod_mod_padre),'N')) = 'S' THEN
      -- se eliminan los registros de exoneraciones
      BEGIN
        IF p_modo = 'D' then
            -- se elimina de tabla diaria
            -- intenta primero directamente por pk movimiento
            DELETE FROM GE_EXONERACIONES e
            WHERE e.fec_movimiento  =  p_fecha
                and e.hor_movimiento =  p_hora
                and e.cod_usu_movimiento = p_cod_usuario;
            IF SQL%NOTFOUND THEN
                -- intenta por cod autorizacion
                DELETE FROM GE_EXONERACIONES e
                WHERE (e.fecha, e.cod_modulo, e.cod_modalidad, e.cod_autorizacion) IN
                      (SELECT distinct r.fecha, r.cod_modulo, r.cod_modalidad, r.cod_autorizacion
                       FROM GE_MOVIMIENTOS r
                       WHERE r.fecha = p_fecha
                            and r.hora = p_hora
                            and r.cod_usuario = p_cod_usuario
                            and r.cod_autorizacion is not null);
            END IF;
         ELSE
            -- Se elimina del historico
            -- intenta primero directamente por pk movimiento
            DELETE FROM GE_EXONERACIONES_HIS e
            WHERE e.fec_movimiento  =  p_fecha
                and e.hor_movimiento =  p_hora
                and e.cod_usu_movimiento = p_cod_usuario;
            IF SQL%NOTFOUND THEN
               -- intenta por cod autorizacion
               DELETE FROM GE_EXONERACIONES_HIS e
               WHERE e.fecha = p_fecha
                    and e.cod_modulo = p_cod_mod_padre
                    and e.cod_autorizacion = p_cod_autorizacion;
            END IF;
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN others THEN
            NULL;
      END;
   END IF;
  END lp_eli_exoneraciones;

   /* PROCESO PRINCIPAL DEL PROCEDIMIENTO */
BEGIN
   -- 
   v_es_nocturno := p_es_nocturno;
   --
   --Inicializar errores de pag_cta
   pag_cta.g_msj_error := NULL;
   pag_cta.g_cod_error := 0;
   --
   IF p_es_nocturno = 'X' THEN
      -- Buscar si es nocturno o diurno
      v_est_modulo := pae_cnf.fu_obt_est_modulo(pae_cnf.g_cod_modulo);
      IF v_est_modulo = 2 THEN
         v_es_nocturno := 'N';
      ELSE
         v_es_nocturno := 'S';
      END IF;
   END IF;

   IF NVL(v_es_nocturno,'N') = 'S' THEN/*UPS-633*/
      pag_cta.g_horario := 'N';-- noche
   ELSE
      pag_cta.g_horario := 'D';-- dia normal
   END IF;

   -- Verificar si existian movimientos pendientes de pasar por caja
   IF p_cod_tra_padre IN (101, 102, 358, 359, 360, 362, 364, 139) OR p_cod_tra_padre IN (384, 150) THEN
      --- Comercio Exterior
      --- Por el momento solo prestamos genera movimientos pendientes de pasar
      --- por caja
      BEGIN
         SELECT 'S'
           INTO v_ope_pendiente
           FROM ge_movimientos
          WHERE cod_mod_padre <> 9
            AND estado = 'N'
            AND reversado = 'N'
            AND cod_transaccion IN (840, 740, 607, 610, 632, 606)
            AND cod_usuario = p_cod_usuario
            AND fecha = p_fecha
            AND hora = p_hora
            AND nro_caja IS NOT NULL; -- Que haya pasado por caja
      EXCEPTION
         WHEN no_data_found THEN
            v_ope_pendiente := 'N';
         WHEN too_many_rows THEN
            v_ope_pendiente := 'S';
      END;
   END IF;
   --
   --Inicializar variables de cambio de estado
   r_mov_cam_est := NULL;
   v_gen_estado  := 'N';
   --
   IF v_es_nocturno = 'N' THEN
      v_fec_actual := pag_cal.fu_obt_fec_actual(p_cod_mod_padre);
      --
      IF p_fecha < v_fec_actual THEN
         --MOV. DEL HISTORICO
         v_mod_habilitados := fug_obt_pardinamico('MOD_GV_MOV_PAR',p_cod_mod_padre,p_cod_mad_padre);--modulos habilitados separados por coma
         v_enc_gv_mov_par  := fug_obt_pardinamico('ENC_GV_MOV_PAR');--encendido de gv_movimientos_par

         IF v_mod_habilitados = 'S' AND v_enc_gv_mov_par = 'S' THEN--primero se confirma que el modulo padre esta dentro de la lista, luego se verifica si esta encendido la opcion
            lp_bus_dat_histo_par(p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, p_cod_usu_reversion, p_hor_reversion);
         ELSE
            lp_bus_dat_histo(p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre, p_cod_usu_reversion, p_hor_reversion);
         END IF;
      ELSIF p_fecha = v_fec_actual THEN
         --REVERSIONES DE MOVIMIENTO POR NRO DE LOTE -->PAGO SUELDOS
        IF p_cod_tra_padre in (304,1304,1305,1306) and p_cod_transaccion = 503 then
          FOR c1s IN cur_gmovi_sue LOOP
              lp_ins_movimientos(c1s, p_cod_usu_reversion, p_hor_reversion, 'N');
          END LOOP;
           IF v_ope_pendiente = 'N' THEN
            UPDATE ge_movimientos
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               AND nro_documento2 = p_nro_lote
               AND cod_usuario = p_cod_usuario
               AND reversado = 'N'
               AND cod_tra_padre in (304,1304,1305,1306);

               UPDATE ge_movimientos
               SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
             WHERE fecha = p_fecha
               and nro_documento2 = p_nro_lote
               AND cod_usuario = p_cod_usuario
               AND reversado = 'N'
               and cod_tra_padre in (186,986)
               AND (cod_transaccion NOT IN (941, 661) OR cod_transaccion IS NULL);
           END IF;
         -- si no
        ELSE
         FOR c1 IN cur_gmovi LOOP
             lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'N');
             If c1.cod_transaccion = 515 and p_cod_tra_padre in (359,360,362) Then --CRO-HO-CROCPCCB-27/08/15 se asigna valor a la variable

               v_mto_credito   := c1.monto;
               v_nro_documento := c1.nro_documento;
            Else
               -- Cuando es Cancelación Anticipada y Cobro parcial de capital con cheque cargo otros bancos, al reversar
               -- el detalle del cheque ya se reversa por completo porque
               if p_cod_tra_padre in (359,362,361) and c1.cod_transaccion in (607, 610, 632) Then
                  v_ope_pendiente := 'N';
                  v_nro_cuenta    := c1.nro_cuenta;
               End If;
            End If;
            if p_cod_tra_padre = 444 then
               v_cod_ente := c1.nro_documento;
               v_nro_documento := c1.nro_documento3;
            end if;
         END LOOP;
          IF v_ope_pendiente = 'N' Then
            --CRO-HO-CROCPCCB-16/09/15
             If nvl(v_mto_credito,0) = 0 THEN
                UPDATE ge_movimientos
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha = p_fecha
                   AND hora = p_hora
                   AND cod_usuario = p_cod_usuario
                   AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
                   AND reversado = 'N';
             Else --> Debe Actualizar todos los registros menos el de la liberación
                 UPDATE ge_movimientos
                   SET reversado         = 'S',
                       cod_usu_reversion = p_cod_usu_reversion,
                       hor_reversion     = p_hor_reversion
                 WHERE fecha             = p_fecha
                   AND hora              = p_hora
                   AND cod_usuario       = p_cod_usuario
                   AND nro_documento     <> v_nro_documento
                   AND reversado         = 'N';
             End IF;
          END IF;
             --REVERSIONES DE MOVIMIENTO INDIVIDUAL -->PAGO SUELDOS/AGUINALDO...DESDE
           if p_nro_lote is not null and p_cod_tra_padre in (304,1304,1305,1306) then
         --busca cuenta de debito(ente) para actualizar monto pago de sueldos
               begin
                   select monto, nro_cuenta,cod_ente,cod_moneda
                   into v_monto, v_nro_cuenta,v_cod_ente, v_cod_moneda_sue
                   from ge_pag_sueldos
                   where nro_lote=p_nro_lote
                   and tipo='D';
               end;

            --Obtener el monto de reversion individual de la cuenta credito
               begin
                 select monto
                 into v_monto_cre
                 from ge_movimientos
                  where nro_cuenta= p_nro_ncredito
                  and cod_tra_padre in (304,1304,1305,1306)
                  and cod_transaccion = 602
                   and nro_documento2=p_nro_lote
                    and cod_mad_padre =p_cod_mad_padre
                    and cod_mod_padre = p_cod_mod_padre
                   and reversado='S'
                   and monto > 0;
               end;

              if v_nro_cuenta is not null and p_cod_tra_padre in (304,1304,1305,1306)  then
               UPDATE ge_pag_sueldos
               SET monto= (v_monto - v_monto_cre)--v_monto_cre se resta al monto total
               WHERE nro_lote=p_nro_lote
               and nro_cuenta= v_nro_cuenta
               and monto = v_monto
               and tipo='D';
               v_max_sec_use_fgdiari := fug_obt_nro_sec_sueldo(p_nro_lote,p_cod_usu_reversion);--obtener nro secuencia +1
               v_cdofior := fug_obt_ofi_usuario(p_cod_usu_reversion);--obtener oficina nro cuenta
               v_cnmovim:= fug_obt_concepto(v_nro_cuenta,p_nro_lote,p_cod_mad_padre,p_cod_mod_padre,p_cod_tra_padre);
               --actualiza acreditacion a cuenta debito(del ente)
               PAG_CTA.PR_ACT_OPERACION(v_nro_cuenta,
                              p_hor_reversion,
                              'C',
                              v_cod_moneda_sue,
                              v_monto_cre,
                              p_cod_tra_padre,
                              602,
                              v_cod_ente,
                              NULL,
                              v_cdofior,
                              p_cod_mod_padre,
                              p_cod_mad_padre,
                              NULL,
                              NULL,
                              v_cnmovim,
                              'S',
                               v_max_sec_use_fgdiari,
                               p_fecha);
    --actualiza nro_documento2 para cuenta acreditada(ente) luego de la reversion individual
                     UPDATE GE_MOVIMIENTOS
                           SET nro_documento2 = p_nro_lote
                         WHERE nro_cuenta = v_nro_cuenta
                           and hora = p_hor_reversion
                           and cod_tra_padre in (304,1304,1305,1306)
                           and nro_documento = v_cod_ente
                           and cod_mod_padre = p_cod_mod_padre
                           and cod_mad_padre = p_cod_mad_padre
                           and fecha = p_fecha;
                  end if;
            end if;
          if v_nro_cuenta is not null and p_cod_tra_padre in (304,1304,1305,1306) and p_nro_lote is not null  then
            --consulta monto=0 cuando la reversion es individual
             begin
                   select monto,nro_cuenta
                   into v_monto,v_cuenta_ente
                   from ge_pag_sueldos
                   where nro_lote=p_nro_lote
                   and tipo='D';
               end;
            --si v_monto=0 se reversa los cargos generados al ente en el procesamiento de pago
             if p_cod_tra_padre in (304,1304,1305,1306) and v_monto=0 then
              FOR c1s IN cur_gmovi_car LOOP
                lp_ins_movimientos(c1s, p_cod_usu_reversion, p_hor_reversion, 'N');
              END LOOP;
              end if;
             --Reversa de lote completo de forma individual, si el monto =0
                if v_monto = 0 then
                 UPDATE ge_movimientos
                 SET reversado         = 'S',
                   cod_usu_reversion = p_cod_usu_reversion,
                   hor_reversion     = p_hor_reversion
                   WHERE fecha = p_fecha
                     AND nro_documento2 = p_nro_lote
                     AND cod_usuario = p_cod_usuario
                     AND reversado = 'N'
                     AND cod_tra_padre in (304,1304,1305,1306);
                 end if;
          --Borra los registros de ge_pag_sueldos al reversar cuando el monto=0 luego de reversion individual
          if v_monto = 0 and p_cod_mad_padre=31 and p_cod_tra_padre in (304,1304,1305,1306) then
           delete ge_pag_sueldos where nro_lote=p_nro_lote
           and nro_cuenta= v_nro_cuenta and procesado='S';
          end if;
          end if;
          --REVERSIONES DE MOVIMIENTO INDIVIDUAL -->PAGO SUELDOS/AGUINALDO...HASTA
          END IF;
        END IF;
             -->DYDMR-3304_MB-08/04/2016: Al reversar debe desllavear las cuotas para volver a cobrar.-
             Begin
                 delete pr_cob_cuo_otr_bco a
                  where a.nro_cuenta  = v_nro_cuenta
                    and a.estado      = 'C';
             Exception
                 when no_data_found Then
                      null;
                 When others Then
                      raise_application_error(-20000,'Error al eliminar registros de la tabla PR_COB_CUO_OTR_BCO '||sqlerrm);
             End;
             -->
             -- 13/08/2013-DI-PN:
             /*Eliminación de centro de costos en caso de reversión de la interface de transferencia de GTH*/
             IF p_cod_mod_padre = '14' and p_cod_mad_padre = '141' THEN
                IF p_cod_tra_padre = '1303' then

                  BEGIN
                    delete from CB_CAN_PER_GASTOS
                     where fec_proceso = p_fecha
                       and hor_proceso = p_hora;
                  EXCEPTION
                    when others then
                       raise_application_error(-20000, 'No se ha podido revertir en la tabla CB_CAN_PER_GASTOS. '||sqlerrm);
                  END;
                END IF;

                BEGIN
                  delete from CB_INF_DER_GASTOS
                   where fec_proceso = p_fecha
                     and hor_proceso = p_hora;
                EXCEPTION
                  when others then
                    raise_application_error(-20000, 'No se ha podido revertir en la tabla CB_INF_DER_GASTOS. '||sqlerrm);
                END;
             END IF;
             -- anula registro en tabla de cobros para que se pueda reprocesar
             IF p_cod_tra_padre = 1200 AND p_cod_mod_padre IN (3, 4, 5) THEN
               BEGIN
                 SELECT 'S' into v_exi_movimiento
                 FROM TA_COB_ESP_VIP
                 WHERE FECHA              = p_fecha
                   AND HOR_MOVIMIENTO     = p_hora
                   AND COD_USU_MOVIMIENTO = p_cod_usuario;

                 DELETE TA_COB_ESP_VIP
                 where FECHA          = p_fecha
                   AND HOR_MOVIMIENTO = p_hora
                   AND COD_USU_MOVIMIENTO = p_cod_usuario;
                EXCEPTION
                   WHEN OTHERS THEN
                      raise_application_error(-20011,'Al eliminar de TA_COB_ESP_VIP. '||sqlerrm);  -- SI NO PUDO ACTUALIZAR
               END;
             END IF;
             --

         -- BSEVOCORE-40 Reversion de Exoneraciones de Prestamos
         lp_eli_exoneraciones( p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre);
         IF v_gen_estado = 'S' THEN
            --Genera reversion de cambio de estado para DESCUENTO DE CHEQUES.
            lp_ins_movimientos(r_mov_cam_est, p_cod_usu_reversion, p_hor_reversion, 'N');
         END IF;

      --
   ELSIF v_es_nocturno = 'S' THEN
      --v_fec_actual := pag_cal.fu_obt_fec_actual(p_cod_mod_padre);/*FSOP-20695*/
      FOR c1 IN cur_gmono LOOP
         lp_ins_movimientos(c1, p_cod_usu_reversion, p_hor_reversion, 'S');
      END LOOP;
      IF v_ope_pendiente = 'N' THEN
         UPDATE ge_movimientos_noc
            SET reversado         = 'S',
                cod_usu_reversion = p_cod_usu_reversion,
                hor_reversion     = p_hor_reversion
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
            AND reversado = 'N';
      END IF;
      -- BSEVOCORE-40 Reversion de Exoneraciones de Prestamos
      lp_eli_exoneraciones( p_fecha, p_hora, p_cod_usuario, p_cod_mod_padre);
      IF v_gen_estado = 'S' THEN
         --Genera reversion de cambio de estado para DESCUENTO DE CHEQUES.
         lp_ins_movimientos(r_mov_cam_est, p_cod_usu_reversion, p_hor_reversion, 'N');
      END IF;
   END IF;
   --
   IF v_ope_pendiente = 'S' AND v_ope_ahorros = 'S' THEN
      --- Se realizo la reversion del ahorro
      --- Modificar movimientos de importes
      UPDATE ge_movimientos
         SET estado   = 'J',
             nro_caja = NULL
       WHERE cod_usuario = p_cod_usuario
         AND fecha = p_fecha
         AND hora = p_hora
         AND (nro_documento = p_nro_documento OR p_nro_documento IS NULL)
         AND reversado = 'N'
         AND cod_modulo IN (3, 4)
         AND cod_modalidad <> 43
         AND monto IS NOT NULL;
      --- Eliminar movimientos de cambios de estado
      DELETE ge_movimientos
       WHERE cod_usuario = p_cod_usuario
         AND fecha = p_fecha
         AND hora = p_hora
         AND cod_modulo IN (3, 4)
         AND reversado = 'N'
         AND cod_modalidad <> 43
         AND monto IS NULL;
   END IF;
   --envío de mail si todo fue ok.
   IF p_cod_mod_padre = 7 THEN
      IF v_ope_cambios IS NOT NULL AND v_nro_transf IS NOT NULL THEN
         BEGIN
            it_mail.mail(fug_obt_dir_correo,
                         fug_obt_dir_mail_usu(fug_obt_pardinamico('COD_USU_ENC_COMEX')),
                         'Reversión de Transferencia',
                         'La Operación Nro. ' || v_nro_transf ||
                          ' que involucra a una Transferencia Emitida ' || 'ha sido reversada.');
         EXCEPTION
            WHEN OTHERS THEN
               NULL;
         END;
      END IF;
   END IF;
   --Cuando se reversa pagos a proveedores debe dejar la orden pendiente de pago
   IF p_cod_tra_padre = 346 THEN
      BEGIN
         --Obtener nro_orden
         SELECT nro_documento2 orden_pago, nro_documento cod_ente
           INTO v_ord_pago, v_cod_ente
           FROM ge_movimientos
          WHERE cod_tra_padre = p_cod_tra_padre
            AND fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_secuencia = 1;
      EXCEPTION
         WHEN OTHERS THEN
            v_ord_pago := 0;
            v_cod_ente := 0;
      END;
      --Dejar la orden en estado Cargado para poder pagar
      IF v_ord_pago <> 0 THEN
         UPDATE ge_pag_proveedores
            SET estado      = 'C',
                fec_pago    = NULL,
                cod_oficina = NULL
          WHERE nro_orden = v_ord_pago
            AND cod_ente = v_cod_ente;
      END IF;
  --DYDMR-7799 - Incidencia SAU - ITGF - Incidencia al Reversar las facturas de proveedores
  ELSIF p_cod_tra_padre = 2801 THEN
       --DYDMR-8265 - Incidencia SAU - ITGF - Cambiar Estado
       if to_char(p_fecha,'MMYYYY') <> to_char(v_fec_actual,'MMYYYY') then
          raise_application_error(-20010, 'No puede reversar Compra de mes distinto a fecha actual.'||SQLERRM);
       end if;

    begin
      SELECT nro_documento2 cod_compra, nro_documento3 cod_ente
        INTO v_cod_compra, v_cod_ente
        FROM ge_movimientos
       WHERE cod_tra_padre = p_cod_tra_padre
         AND fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         AND nro_secuencia = 1;
     exception
       --DYDMR-8265 - Incidencia SAU - ITGF - Cambiar Estado
       when no_data_found then
         begin
           SELECT nro_documento2 cod_compra, nro_documento3 cod_ente
             INTO v_cod_compra, v_cod_ente
             FROM gv_movimientos
            WHERE cod_tra_padre = p_cod_tra_padre
              AND fecha = p_fecha
              AND hora = p_hora
              AND cod_usuario = p_cod_usuario
              AND nro_secuencia = 1;
         exception
           when others then
             v_cod_compra := 0;
             v_cod_ente   := 0;
         end;
       when others then
         v_cod_compra := 0;
         v_cod_ente   := 0;
      end;

    if v_cod_compra <> 0 then
        UPDATE pv_compras a
           SET a.estado = 'I'
         WHERE a.cod_compra = v_cod_compra
           AND a.cod_ent_proveedor = v_cod_ente;
    end if;

   END IF;

   IF p_cod_mod_padre = 26 AND p_cod_mad_padre = 261 THEN
      v_hor_reversion := p_hor_reversion;
      IF p_cod_tra_padre = 2601 THEN
         --Para la transaccíon padre 2601(Confirmacíon de bien) siempre sera la transaccíon 2602
         --Ingreso Bienes Adjudicados
         FOR i IN c_bienes(p_cod_tra_padre, v_cod_tra_pago) LOOP
            v_sig_hor_reversion := pag_gen.fu_obt_sig_segundo(v_hor_reversion);
            prg_rev_operacion(p_fecha, i.hora, p_cod_usuario, p_cod_mod_padre, p_cod_mad_padre,
                              p_cod_tra_padre, USER, v_sig_hor_reversion, 'N', p_concepto);
            v_hor_reversion := v_sig_hor_reversion;
         END LOOP;
         IF lf_obt_ref_mov_mayor(p_hora) <> 'S' then
         BEGIN
            SELECT m.referencia
              INTO v_referencia
              FROM gv_movimientos m
             WHERE m.fecha = p_fecha
               AND m.hora = p_hora
               AND m.cod_usuario = p_cod_usuario
               AND m.monto <> 0
               AND m.cod_modulo = 26
                  AND m.cod_tra_padre = p_cod_tra_padre
                  AND m.cod_transaccion = v_cod_tra_pago;
         EXCEPTION
            WHEN no_data_found THEN
                  raise_application_error(-20010, 'Error Al Obtener Código del Bien.'||SQLERRM);
            WHEN OTHERS THEN
                  raise_application_error(-20011, 'Error Obteniendo Código del Bien:' || SQLERRM);
         END;
            if lf_ver_est_bien(v_referencia) <> 'C' then
               raise_application_error(-20000, 'No se puede reversar, El Bien no se encuentra Confirmado.');
            end if;
         -- Actualizar el estado del Bien Adjudicado
            UPDATE bu_bienes
               SET estado = 'I'
             WHERE cod_grupo = v_referencia;
         -- Borrar la Cancelación
            DELETE bu_bie_cancelaciones
             WHERE cod_grupo = v_referencia;
         END IF;
      ELSIF p_cod_tra_padre = 2615 THEN
         --Ingreso Bienes Adjudicados
         FOR i IN c_bienes(p_cod_tra_padre, v_cod_tra_rubro) LOOP
            v_sig_hor_reversion := pag_gen.fu_obt_sig_segundo(p_hor_reversion);
            prg_rev_operacion(p_fecha, i.hora, p_cod_usuario, p_cod_mod_padre, p_cod_mad_padre,
                              p_cod_tra_padre, USER, v_sig_hor_reversion, 'N', p_concepto);
         END LOOP;

         IF LF_obt_ref_mov_mayor(p_hora) <> 'S' then
            BEGIN
               SELECT m.referencia
                 INTO v_referencia
                 FROM gv_movimientos m
                WHERE m.fecha = p_fecha
                  AND m.hora = p_hora
                  AND m.cod_usuario = p_cod_usuario
                  AND m.monto <> 0
                  AND m.cod_modulo = 26
                  AND m.cod_tra_padre = p_cod_tra_padre
                  AND m.cod_transaccion = v_cod_tra_rubro;
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20020, 'Error Al Obtener Código del Bien.'||SQLERRM);
               WHEN OTHERS THEN
                  raise_application_error(-20021, 'Error Obteniendo Código del Bien:' || SQLERRM);
            END;
           if lf_ver_est_bien(v_referencia) <> 'C' then
              raise_application_error(-20000, 'No se puede reversar, El Bien no se encuentra Confirmado.');
           end if;
           -- Actualizar el estado del Bien Adjudicado
           UPDATE bu_bienes
              SET estado = 'I'
            WHERE cod_grupo = v_referencia;
         END IF;
      ELSIF p_cod_tra_padre = 261 THEN
         --Venta de Bienes Adjudicados
         BEGIN
            SELECT m.referencia
              INTO v_referencia
              FROM gv_movimientos m
             WHERE m.fecha = p_fecha
               AND m.hora = p_hora
               AND m.cod_usuario = p_cod_usuario
               AND m.monto <> 0
               AND m.cod_modulo = 26
                  --and m.REVERSADO = 'N'
               AND m.cod_tra_padre = 261
               AND m.cod_transaccion = 2614;
         EXCEPTION
            WHEN no_data_found THEN
               raise_application_error(-20030, 'Error Al Obtener Código del Bien.'||SQLERRM);
            WHEN OTHERS THEN
               raise_application_error(-20031, 'Error Obteniendo Código del Bien:' || SQLERRM);
         END;
         -- Actualizar el estado del Bien Adjudicado
         UPDATE bu_bienes
            SET estado           = 'C',
                fec_venta        = NULL,
                cod_per_venta    = NULL,
                mto_efectivo     = NULL,
                mto_cheque       = NULL,
                mto_deb_cuenta   = NULL,
                nro_deb_cuenta   = NULL,
                mto_cta_contable = NULL,
                nro_cta_contable = NULL,
                mto_solicitud    = NULL,
                nro_solicitud    = NULL
          WHERE cod_bien = v_referencia;

      END IF;
   END IF;

   -- OMM 18/08/2011 Para reversion de Sobrantes
   -- Obs.: Considerar reutilizar el codigo para Faltantes
   IF p_cod_tra_padre IN (224, 232, 309) THEN

      BEGIN
         SELECT DISTINCT m.monto, m.nro_documento, m.estado, m.cod_transaccion
           INTO v_mto_sobrante, v_nro_documento, v_est_sobrante, v_cod_tra_sobrante
           FROM gv_movimientos m
          WHERE m.fecha = p_fecha
            AND m.hora = p_hora
            AND m.cod_usuario = p_cod_usuario
            AND m.cod_transaccion IN (232, 248, 224) -- VV 21/09/2011 Se agrego la transaccion 224 por si se trata de una reversion de sobrante.
            AND m.cod_tra_padre IN (224, 232, 309);
      EXCEPTION
         WHEN no_data_found THEN
            IF p_cod_tra_padre = 309 THEN
               v_nro_documento := NULL;
            ELSE
               raise_application_error(-20012, 'Error Al Obtener Sobrante.');
            END IF;
         WHEN OTHERS THEN
            raise_application_error(-20012, 'Error Obt.Sobrante:' || SQLERRM);
      END;
      -- VV 25/08/2011 Solo debe actualizar el sobrante cuando el estado del movimiento es Normal.
      IF v_est_sobrante = 'N' THEN
         -- OMM 18/08/2011 Se actualiza el reg. de Sobrante.
         IF v_cod_tra_sobrante = 224 THEN
            -- VV 21/09/2011 Consulta si la transacción es una reversion del sobrante de Caja.
            -- VV 23/09/2011 Busca el Nro. del Sobrante de Caja y Nro. Cta. del sobrante.
            BEGIN
               SELECT t.nro_sobrante, t.nro_cuenta
                 INTO v_nro_sobrante, v_cta_sobrante
                 FROM cj_sobrantes t
                WHERE t.fecha = p_fecha
                  AND t.hora = p_hora
                  AND t.cod_usuario = p_cod_usuario;
            EXCEPTION
               WHEN no_data_found THEN
                  raise_application_error(-20012, 'Error Al Obtener el Nro. Sobrante.' || SQLERRM);
               WHEN OTHERS THEN
                  raise_application_error(-20012, 'Error Al Obtener el Nro. Sobrante.' || SQLERRM);
            END;
            -- VV 23/09/2011 Verifica que el sobrante no tenga una regularizacion.
            BEGIN
               SELECT 1
                 INTO v_mov_sobrante
                 FROM ge_movimientos t
                WHERE t.nro_documento = v_nro_sobrante
                  AND t.reversado = 'N'
                  AND t.nro_cuenta = v_cta_sobrante
                  AND rownum = 1;
            EXCEPTION
               WHEN no_data_found THEN
                  v_mov_sobrante := 0;
               WHEN OTHERS THEN
                  v_mov_sobrante := 0;
            END;
            --Elimina el Sobrante de caja que fue reversado si no tiene movimientos de regularización..
            IF v_mov_sobrante = 0 THEN
               DELETE cj_sobrantes c WHERE c.nro_sobrante = v_nro_sobrante;
            ELSE
               raise_application_error(-20000,
                                       'El Sobrante ' || v_nro_sobrante ||
                                        ' tiene movimientos de Regularización que deben ser reversados previamente.');
            END IF;
         ELSE
            IF nvl(v_nro_documento, 0) > 0 THEN
               UPDATE cj_sobrantes c
                  SET c.saldo  = c.saldo + v_mto_sobrante,
                      c.estado = 'A'
                WHERE c.nro_sobrante = v_nro_documento;
            END IF;
         END IF;
      END IF;
   END IF;
   IF p_cod_tra_padre = 444 then
     BEGIN
       UPDATE ge_pag_recaudaciones a
          SET a.estado = 'P'
        WHERE a.cod_ente = v_cod_ente
          AND a.nro_documento = v_nro_documento;
     END;
   END IF;

   /*DYDMR-5485 Levantamiento de Embargos (ALV-MAR2017)*/
   IF p_cod_tra_padre = 112 then
     Declare
     cursor bloqueos (c_nro_documento ge_movimientos.nro_documento%type) is
       select d.nro_cuenta,
              a.fecha fec_inicio,
              a.cod_embargo nro_documento,
              fug_obt_pardinamico('COD_CAU_BLO_EMBAR') cod_causa,
              d.mto_mon_cuenta monto,
              a.hora hor_inicio,
              'S' tipo,
              'Inserción por reversión' observacion,
              d.cotizacion,
              d.mto_embargado mto_equivalente,
              'M' tip_bloqueo
         from ge_embargos a, ge_embargos_det d
        where a.cod_embargo = d.cod_embargo
          and a.cod_embargo = c_nro_documento;
     Begin
       Begin
         SELECT nro_documento
         INTO v_nro_documento
         FROM ge_movimientos
        WHERE cod_tra_padre = p_cod_tra_padre
          AND fecha = p_fecha
          AND hora = p_hora
          AND cod_usuario = p_cod_usuario
          AND rownum = 1;
       Exception
         when others
           then v_nro_documento := 0;
       End;
       if nvl(v_nro_documento,0) <> 0 then
         --Actualizar ge_embargos
         update ge_embargos g
            set g.estado         = 'A',
                g.lev_nro_oficio = null,
                g.lev_fec_oficio = null
          where g.cod_embargo = v_nro_documento
            and g.estado <> 'A';

         --Insertar bloqueos
         FOR b1 in bloqueos (v_nro_documento) loop
           insert into ge_bloqueos
             (nro_cuenta,
              fec_inicio,
              nro_documento,
              cod_causa,
              monto,
              hor_inicio,
              tipo,
              observacion,
              cotizacion,
              mto_equivalente,
              tip_bloqueo)
           values
             (b1.nro_cuenta,
              b1.fec_inicio,
              b1.nro_documento,
              b1.cod_causa,
              b1.monto,
              b1.hor_inicio,
              b1.tipo,
              b1.observacion,
              b1.cotizacion,
              b1.mto_equivalente,
              b1.tip_bloqueo);
         END LOOP;
       END IF;
     END;
   END IF;
   /*
   || PCC-MAS_INGRESOS
   || PCC-RET_COM_INT - Retrocesiones de Comisiones e Intereses
   || Vuelve a estado R/Rechazado para poder modificar desde la pantalla
   */
   IF p_cod_tra_padre = 2510 then
      SELECT max(nvl(m.nro_documento,0))
        INTO v_nro_documento
        FROM gv_movimientos m
       WHERE m.fecha = p_fecha
         AND m.hora = p_hora
         AND m.cod_usuario = p_cod_usuario
         AND m.cod_tra_padre = 2510;
      BEGIN
         UPDATE ge_ret_com_intereses a
            SET a.estado = 'R'
          WHERE a.nro_devolucion = v_nro_documento
            AND a.estado <> 'R';
      END;
   END IF;
   /*
   || PCCRECOIN-94
   || CC Restricción de transacciones que reversan historicos de comisiones cobradas.
   || Se debe retroceder.
   */
   IF p_fecha <> v_fec_actual THEN
      BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ge_gru_transacciones_det g
          WHERE g.cod_gru_transaccion = v_cod_gru_cob_com
            AND g.cod_modulo = p_cod_mod_padre
            AND g.cod_modalidad = p_cod_mad_padre
            AND g.cod_transaccion = p_cod_tra_padre;
         IF v_existe = 'S' THEN
            raise_application_error(-20001, 'No puede reversar Comisiones Cobradas. Se debe retroceder');
         END IF;
      EXCEPTION
         WHEN no_data_found THEN
            NULL;
         WHEN too_many_rows THEN
            raise_application_error(-20002, 'No puede reversar Comisiones Cobradas. Se debe retroceder');
      END;
   END IF;
   -- Si el movimiento corresponde a SNP se envía alerta al Oficial y/o al Cliente.
   --sipap
   IF v_snp_env_alerta = 'S' THEN
      -- Envía alerta al Oficial y/o al Cliente por la reversión de la transferencia realizada.
      pas_snp.pr_env_alerta(rg_snp_msj, 'R');
      --
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20099,
                                 'Fecha: ' || to_char(p_fecha, 'DD/MM/YYYY') || ' hora: ' ||
                                 p_hora || ' Cod. usuario: ' || p_cod_usuario || ' Cod. Mod. Padre: ' ||
                                 p_cod_mod_padre||' '||sqlerrm);
      end if;
END prg_rev_operacion;
/
