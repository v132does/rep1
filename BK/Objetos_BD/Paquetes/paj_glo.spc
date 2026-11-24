CREATE OR REPLACE PACKAGE IT.PAJ_GLO is
  v_cod_msg_exito number := nvl(fug_obt_pardinamico('COD_MSG_EXITO'), 200); -- cod. exitoso web service
  v_pro_correcto  number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'), 0); -- cod. exitoso core
  v_err_sql       number := nvl(fug_obt_pardinamico('COD_ERR_SQL'), 999);

  v_ser_digital   varchar2(100):= nvl(fug_obt_pardinamico('COD_SER_DIG_GLOBAL'), 'INTERNATIONAL_AUTH');
  v_cod_trn_digital  varchar2(100):= nvl(fug_obt_pardinamico('COD_TRN_DIG_GLOBAL'), '519');


  --Proceso principal
  PROCEDURE pr_principal(p_monto IN NUMBER, --amount
                         p_cod_comercio        IN VARCHAR2, --commerce.code
                         p_nom_comercio        IN VARCHAR2, --commerce.name
                         p_mcc                 IN VARCHAR2, --commerce.mcc
                         p_cod_postal          IN VARCHAR2, --commerce.postal_code
                         p_id_cuenta           IN VARCHAR2, --account_id
                         p_nro_tarjeta         IN VARCHAR2, --trunc_card_number
                         p_cod_mon_transaccion IN VARCHAR2, --original_currency_id
                         p_fec_proceso         IN VARCHAR2, --date_time
                         p_hor_proceso         IN VARCHAR2, --date_time
                         p_cod_terminal        IN VARCHAR2, --sta
                         p_accion              IN VARCHAR2, --action
                         p_cod_transaccion     IN VARCHAR2, --request_id
                         p_cod_moneda          IN VARCHAR2, --currency_id
                         p_cod_tra_cancelacion IN VARCHAR2, --request_id_to_cancel
                         p_mot_cancelacion     IN VARCHAR2, --reason_id
                         p_tag_internacional   IN VARCHAR2 DEFAULT NULL, --tag international_auth
                         p_men_json            IN VARCHAR2 DEFAULT NULL, --Request json Global
                         p_estado              OUT VARCHAR2,
                         p_codigo              OUT VARCHAR2,
                         p_id_interno          OUT VARCHAR2,
                         p_fec_creado          OUT VARCHAR2,
                         p_hor_creado          OUT VARCHAR2,
                         p_id_respuesta        OUT VARCHAR2,
                         --netamente balance
                         p_sal_disponible      OUT VARCHAR2,
                         p_cod_mon_id          OUT VARCHAR2,
                         --OPI 2.43.3
                         p_id_mon_orig         IN VARCHAR2,
                         p_cod_adquiriente     IN VARCHAR2,
                         p_mod_entrada         IN VARCHAR2,
                         p_3ds                 IN VARCHAR2,
                         p_mon_original        IN VARCHAR2,
                         p_liq_moneda          IN VARCHAR2,
                         p_mon_liquidacion     IN VARCHAR2,
                         p_fac_tit_mon_id      IN VARCHAR2,
                         p_fac_ti_monto        IN VARCHAR2,
                         p_otr_montos          IN VARCHAR2,
                         p_fec_liquidacion     IN NUMBER,
                         p_cod_reenvio         IN NUMBER,
                         p_ref_recuperacion    IN VARCHAR2,
                         p_ter_id              IN VARCHAR2,
                         p_dat_red             IN VARCHAR2,
                         p_id_externo          OUT VARCHAR2,
                         p_pai_comercio        IN VARCHAR2,
                         p_ciu_comercio      IN VARCHAR2
                         );
  -- Obtenemos algunos datos de la cuenta.
  PROCEDURE pr_obt_dat_cta(p_nro_cuenta    IN OUT VARCHAR2,
                           p_cod_modulo    OUT NUMBER,
                           p_cod_modalidad OUT NUMBER,
                           p_cod_oficina   OUT NUMBER,
                           p_cod_moneda    OUT VARCHAR2);

  -- Proceso de generacion de movimientos
  PROCEDURE pr_car_aut_operacion(p_nro_cta_deb      ge_movimientos.nro_cuenta%TYPE,
                                 p_nro_cta_cre      ge_movimientos.nro_cuenta%TYPE,
                                 p_cod_tra_padre    ge_movimientos.cod_tra_padre%TYPE,
                                 p_cod_tra_debito   ge_movimientos.cod_transaccion%TYPE,
                                 p_cod_tra_credito  ge_movimientos.cod_transaccion%TYPE,
                                 p_cod_mod_cta_deb  ge_movimientos.cod_modulo%TYPE,
                                 p_cod_mad_cta_deb  ge_movimientos.cod_modalidad%TYPE,
                                 p_cod_ofi_cta_deb  ge_movimientos.cod_oficina%TYPE,
                                 p_cod_mon_deb      ge_movimientos.cod_moneda%TYPE,
                                 p_cod_mod_cta_cre  ge_movimientos.cod_modulo%TYPE,
                                 p_cod_mad_cta_cre  ge_movimientos.cod_modalidad%TYPE,
                                 p_cod_ofi_cta_cre  ge_movimientos.cod_oficina%TYPE,
                                 p_cod_mon_cre      ge_movimientos.cod_moneda%TYPE,
                                 p_hor_proceso      ge_movimientos.hora%TYPE,
                                 p_fec_proceso      ge_movimientos.fecha%TYPE,
                                 p_cod_bco_credito  ge_movimientos.cod_banco%TYPE,
                                 p_cod_bco_debito   ge_movimientos.cod_banco%TYPE,
                                 p_nro_transaccion  ta_dig_cobrados.referencia%TYPE,
                                 p_ofi_origen       ge_movimientos.cod_oficina%TYPE,
                                 p_concepto         ge_movimientos.concepto%TYPE,
                                 p_est_cuenta       ge_movimientos.est_cuenta%TYPE,
                                 p_cod_ope_int      ge_movimientos.nro_documento%TYPE,
                                 p_imp_debito       ge_movimientos.monto%TYPE,
                                 p_imp_credito      ge_movimientos.monto%TYPE,
                                 p_val_cargo        ge_movimientos.val_tasa%TYPE,
                                 p_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE,
                                 p_val_tas_cargo    ge_movimientos.val_tasa%TYPE,
                                 p_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE,
                                 p_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE,
                                 p_val_tas_impuesto ge_movimientos.val_tasa%TYPE,
                                 p_val_impuesto     ge_movimientos.val_tasa%TYPE,
                                 p_hor_global       ge_movimientos.nro_documento3%type,
                                 p_cod_usuario      ba_usuarios.cod_usuario%type,
                                 p_ind_usuario      number,
                                 p_cot_debito       ge_movimientos.cotizacion%type default null,
                                 p_cot_credito      ge_movimientos.cotizacion%type default null,
                                 p_es_nocturno      varchar2 default 'N',
                                 p_mcc              varchar2 default null,
                                 p_imp_digital      varchar2 default null);

  -- Proceso de generacion de movimientos para consulta de saldo.
  PROCEDURE pr_car_aut_ope_consulta(p_nro_cta_deb      ge_movimientos.nro_cuenta%TYPE,
                                    p_cod_tra_padre    ge_movimientos.cod_tra_padre%TYPE,
                                    p_cod_tra_debito   ge_movimientos.cod_transaccion%TYPE,
                                    p_cod_mod_cta_deb  ge_movimientos.cod_modulo%TYPE,
                                    p_cod_mad_cta_deb  ge_movimientos.cod_modalidad%TYPE,
                                    p_cod_ofi_cta_deb  ge_movimientos.cod_oficina%TYPE,
                                    p_cod_mon_deb      ge_movimientos.cod_moneda%TYPE,
                                    p_hor_proceso      ge_movimientos.hora%TYPE,
                                    p_fec_proceso      ge_movimientos.fecha%TYPE,
                                    p_cod_bco_debito   ge_movimientos.cod_banco%TYPE,
                                    p_nro_transaccion  ge_movimientos.nro_documento%TYPE,
                                    p_ofi_origen       ge_movimientos.cod_oficina%TYPE,
                                    p_concepto         ge_movimientos.concepto%TYPE,
                                    p_est_cuenta       ge_movimientos.est_cuenta%TYPE,
                                    p_cod_ope_int      ge_movimientos.nro_documento%TYPE,
                                    p_imp_debito       ge_movimientos.monto%TYPE,
                                    p_val_cargo        ge_movimientos.val_tasa%TYPE,
                                    p_cod_tas_cargo    ge_movimientos.cod_tasa%TYPE,
                                    p_val_tas_cargo    ge_movimientos.val_tasa%TYPE,
                                    p_cod_tra_impuesto ge_movimientos.cod_transaccion%TYPE,
                                    p_cod_tas_impuesto ge_movimientos.cod_tasa%TYPE,
                                    p_val_tas_impuesto ge_movimientos.val_tasa%TYPE,
                                    p_val_impuesto     ge_movimientos.val_tasa%TYPE,
                                    p_hor_global       ge_movimientos.nro_documento3%type,
                                    p_cod_usuario      ba_usuarios.cod_usuario%type,
                                    p_ind_usuario      number,
                                    p_es_nocturno      varchar2 default 'N');

  --Actualizamos la cuenta de credito y debito.
  PROCEDURE pr_upd_cta_debito(p_ind_cta_contable VARCHAR2,
                              p_es_nocturno      VARCHAR2,
                              p_cod_mod_cta      ge_movimientos.cod_modulo%TYPE,
                              p_cod_mad_cta      ge_movimientos.cod_modalidad%TYPE,
                              p_nro_cuenta       ge_movimientos.nro_cuenta%TYPE,
                              p_fec_proceso      ge_movimientos.fecha%TYPE,
                              p_hor_proceso      ge_movimientos.hora%TYPE,
                              p_importe          ge_movimientos.monto%TYPE);

  PROCEDURE pr_upd_cta_credito(p_ind_cta_contable VARCHAR2,
                               p_es_nocturno      VARCHAR2,
                               p_cod_mod_cta      ge_movimientos.cod_modulo%TYPE,
                               p_cod_mad_cta      ge_movimientos.cod_modalidad%TYPE,
                               p_nro_cuenta       ge_movimientos.nro_cuenta%TYPE,
                               p_fec_proceso      ge_movimientos.fecha%TYPE,
                               p_hor_proceso      ge_movimientos.hora%TYPE,
                               p_importe          ge_movimientos.monto%TYPE);

  --Insertamos el log.
  PROCEDURE pr_ins_log(p_fec_sistema       IN cj_log_glo_pro.fec_sistema%TYPE,
                       p_pedido            IN cj_log_glo_pro.pedido%TYPE,
                       p_respuesta         IN cj_log_glo_pro.respuesta%TYPE,
                       p_msj_error         IN cj_log_glo_pro.msj_error%TYPE,
                       p_fecha             IN cj_log_glo_pro.fecha%TYPE,
                       p_hora              IN cj_log_glo_pro.hora%TYPE,
                       p_nro_transaccion   IN cj_log_glo_pro.nro_transaccion%TYPE,
                       p_nro_cta_debito    IN cj_log_glo_pro.nro_cta_debito%TYPE,
                       p_cod_bco_debito    IN cj_log_glo_pro.cod_bco_debito%TYPE,
                       p_nro_cta_credito   IN cj_log_glo_pro.nro_cta_credito%TYPE,
                       p_cod_bco_credito   IN cj_log_glo_pro.cod_bco_credito%TYPE,
                       p_cod_operacion     IN cj_log_glo_pro.cod_operacion%TYPE,
                       p_mto_total         IN cj_log_glo_pro.mto_total%TYPE,
                       p_cod_moneda        IN cj_log_glo_pro.cod_moneda%TYPE,
                       p_nro_atm           IN cj_log_glo_pro.nro_atm%TYPE,
                       p_cod_bco_atm       IN cj_log_glo_pro.cod_bco_atm%TYPE,
                       p_nro_pos           IN cj_log_glo_pro.nro_pos%TYPE,
                       p_tra_pos           IN cj_log_glo_pro.tra_pos%TYPE,
                       p_tip_hora          IN cj_log_glo_pro.tip_hora%TYPE,
                       p_nom_comercio      IN cj_log_glo_pro.nom_comercio%TYPE,
                       p_nro_documento IN cj_log_glo_pro.nro_documento%TYPE,
                       p_nro_tra_cancelado IN cj_log_glo_pro.nro_tra_cancelado%TYPE,
                       p_mot_cancelado     IN cj_log_glo_pro.mot_cancelacion%TYPE,
                       p_cod_estado        IN cj_log_glo_pro.cod_estado%TYPE,
                       p_cod_comercio      IN cj_log_glo_pro.cod_comercio%type,
                       p_mcc               IN cj_log_glo_pro.mcc%type,
                       p_cod_postal        IN cj_log_glo_pro.cod_postal%type,
                       p_nro_tarjeta       IN cj_log_glo_pro.nro_tarjeta%type,
                       p_cod_mon_iso       IN cj_log_glo_pro.cod_mon_iso%type,
                       p_cod_mon_iso_tra   IN cj_log_glo_pro.cod_mon_iso_tra%type,
                       p_fec_proceso       IN cj_log_glo_pro.fec_proceso%type,
                       p_hor_proceso       IN cj_log_glo_pro.hor_proceso%type,
                       p_cod_usuario       IN cj_log_glo_pro.cod_usuario%type,
                       p_tag_internacional IN cj_log_glo_pro.tag_internacional%type,
                       p_men_json          IN cj_log_glo_pro.men_json%type);

  -- Obtener datos transaccion atm
  PROCEDURE pr_obt_dat_tra_atm(p_cod_tra_padre       IN GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE,
                               p_cod_modulo          IN GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE,
                               p_cod_modalidad       IN GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE,
                               p_ntr_atm             IN VARCHAR2,
                               p_cod_gru_transaccion OUT ge_gru_transacciones_det.cod_gru_transaccion%TYPE,
                               p_cod_tra_cargo       OUT NUMBER,
                               p_par_dinamico        OUT VARCHAR2);

  -- Alta/Modificacion de cotizacion USD en Global Processing
  PROCEDURE pr_web_cotizacion(p_tipo             IN VARCHAR2,
                              p_pagaOtorEntiCodi IN VARCHAR2,
                              p_date             IN DATE,
                              p_bidPrice         IN number,
                              p_askPrice         IN NUMBER,
                              p_cod_error        OUT NUMBER,
                              p_men_error        OUT VARCHAR2);

  PROCEDURE lp_con_mon_a_moneda(p_cod_mon_debito  in ba_monedas.cod_moneda%type,
                                p_cod_mon_credito in ba_monedas.cod_moneda%type,
                                p_mto_mon_debito  in out number,
                                p_mto_mon_credito in out number,
                                p_cot_mon_debito  out number,
                                p_cot_mon_credito out number);

END PAJ_GLO;
/
