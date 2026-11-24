CREATE OR REPLACE PACKAGE IT.PAA_PRO IS

  -- Author  : XPY4615
  -- Created : 22/1/2019 10:40:42
  -- Purpose : Procedimientos y funciones relacionados con ahorro programado

  /* Obtener dato de monto de pizarra */
  PROCEDURE pr_obt_mto_pizarra(p_piz_monto         IN OUT cr_piz_montos%ROWTYPE,
                               p_cod_modulo        IN cr_piz_montos.cod_modulo%TYPE,
                               p_cod_modalidad     IN cr_piz_montos.cod_modalidad%TYPE,
                               p_cod_moneda        IN cr_piz_montos.cod_moneda%TYPE,
                               p_cod_sub_modalidad IN cr_piz_montos.cod_sub_modalidad%TYPE DEFAULT NULL);

  /* Obtener dato plazo min y max de pizarra */
  PROCEDURE pr_obt_plz_pizarra(p_cod_modulo        IN cr_piz_montos.cod_modulo%TYPE,
                               p_cod_modalidad     IN cr_piz_montos.cod_modalidad%TYPE,
                               p_cod_moneda        IN cr_piz_montos.cod_moneda%TYPE,
                               p_cod_sub_modalidad IN cr_piz_montos.cod_sub_modalidad%TYPE DEFAULT NULL,
                               p_min_plazo         OUT cr_piz_plazos.plz_desde%TYPE,
                               p_max_plazo         OUT cr_piz_plazos.plz_hasta%TYPE);
  /**
   * Retorna la lista de simulacion para un ahorro programado
   */
  FUNCTION fu_sim_aho_programado(p_monto      IN cr_piz_plazos.mto_desde%TYPE,
                                 p_tipo       IN VARCHAR2,
                                 p_cod_moneda IN cr_piz_plazos.cod_moneda%TYPE) RETURN typ_simulador;

  /**
   * Calcular el valor total ahorrado
   *
   * @param p_monto Monto a ahorrar
   * @param p_plazo Cantidad de cuotas (en meses)
   * @param p_tipo Tipo de ahorro, M: Mensual, T: Total
   * @param p_cod_moneda Moneda del ahorro
   * @param p_tasa interes aplicado (out)
   * @param p_tot_ahorro total de ahorro calculado (out)
   */
  PROCEDURE pr_cal_aho_programado(p_monto      IN cr_piz_plazos.mto_desde%TYPE,
                                  p_plazo      IN cr_piz_plazos.plz_hasta%TYPE,
                                  p_tipo       IN VARCHAR2,
                                  p_cod_moneda IN cr_piz_plazos.cod_moneda%TYPE,
                                  p_tasa       OUT cr_piz_plazos.tas_interes%TYPE,
                                  p_tot_ahorro OUT cr_piz_montos.mto_hasta%TYPE);

  /**
   * Envio de contrato de ahorro al principal de la cuenta
   * @param p_nro_cuenta Cuenta de ahorro programado
   */
  PROCEDURE pr_env_contrato(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE);

  /**
   * Genera la cuenta ahorro programado
   * @param p_mto_cuota Monto de cuota
   * @param p_per_debito Periodo del debito
   * @param p_plazo Plazo del ahorro
   * @param p_nro_cta_debito Cuenta debito del ahorro
   * @param p_meta Descripcion de la Meta del ahorro
   * @param p_cod_canal Canal donde se solicita
   * @param p_nro_cuenta Nro cuenta creado (out)
   * @param p_cod_error Codigo de error (out)
   */
  PROCEDURE pr_gen_aho_programado(p_mto_cuota      IN ah_pro_cuotas.mto_cuota%TYPE,
                                  p_per_debito     IN NUMBER,
                                  p_plazo          IN NUMBER,
                                  p_nro_cta_debito IN ah_cta_plazos.nro_cta_capitalizacion%TYPE,
                                  p_meta           IN ah_cta_plazos.denominacion%TYPE,
                                  p_cod_canal      IN ge_canales.cod_canal%TYPE,
                                  p_nro_cuenta     OUT ah_cta_plazos.nro_cuenta%TYPE,
                                  p_cod_error      OUT NUMBER);

  /**
   * Inserta en GE_CTA_CLIENTES
   * @param p_cod_persona Codigo de persona
   * @param p_nro_cuenta Nro de cuenta del ahorro
   * @param p_dig_verificador Digito verificador
   * @param p_cod_oficina Codigo de oficina
   * @param p_cod_modulo Codigo de Modulo
   * @param p_cod_modalidad Codigoo de la Modalidad
   * @param p_relacion Relacion de cliente
   */
  PROCEDURE pr_ins_cta_cliente(p_cod_persona     IN ge_cta_clientes.cod_persona%TYPE,
                               p_nro_cuenta      IN ge_cta_clientes.nro_cuenta%TYPE,
                               p_dig_verificador IN ge_cta_clientes.dig_verificador%TYPE,
                               p_cod_oficina     IN ge_cta_clientes.cod_oficina%TYPE,
                               p_cod_modulo      IN ge_cta_clientes.cod_modulo%TYPE,
                               p_cod_modalidad   IN ge_cta_clientes.cod_modalidad%TYPE,
                               p_relacion        IN ge_cta_clientes.relacion%TYPE);

  /**
   * Inserta Ahorro Programado en AH_CTA_PLAZOS
   * @param rp_aplazo Campos de AH_CTA_PLAZOS
   */
  PROCEDURE pr_ins_cta_aho_programado(rp_aplazo IN ah_cta_plazos%ROWTYPE);

  /**
   * Inserta las cuotas en AH_PRO_CUOTAS
   * @param rp_apcuota registro de cuotas
   * @param p_plazo plazo del ahorro programado
   * @param p_tasa tasa del ahorro programado
   * @param p_cod_oficina codigo de oficina
   * @param p_cod_moneda codigo de la moneda
   * @param p_periodo periodo de debito
   */
  PROCEDURE pr_ins_cuo_ahorro(rp_apcuota    IN ah_pro_cuotas%ROWTYPE,
                              p_plazo       IN NUMBER,
                              p_tasa        IN NUMBER,
                              p_cod_oficina IN ah_cta_plazos.cod_oficina%TYPE,
                              p_cod_moneda  IN ah_cta_plazos.cod_moneda%TYPE,
                              p_periodo       IN ah_cta_plazos.per_debito%TYPE);

  /**
   * Obtiene el codigo de periodo segun la fecha
   */
  FUNCTION fu_obt_dia_debito(p_fecha IN DATE) RETURN VARCHAR2;

  /**
   * Obtener el ultimo dia para cobro segun el periodo
   *
   * @param p_cod_oficina numero de oficina de la cuenta
   * @param p_periodo Periodo del debito
   */
  FUNCTION fu_obt_ult_dia_debito(p_cod_oficina IN ba_oficinas.cod_oficina%TYPE,
                                 p_periodo     IN ah_cta_plazos.per_debito%TYPE) RETURN DATE;
  /**
   * Cobrar cuota de ahorro programado
   * @param p_nro_cuenta numero de cuenta del ahorro programado
   * @param p_nro_cuota cuota a cobrar
   */
  PROCEDURE pr_cob_cuota(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE,
                         p_nro_cuota  IN ah_pro_cuotas.nro_cuota%TYPE);

  /**
   * Debito automatico por periodo de cuotas al dia y atrasadas ahorro programado -- Cierre
   * @param p_nro_cuenta numero de cuenta del ahorro programado
   */
  PROCEDURE pr_deb_automatico(p_nro_cuenta IN ah_cta_plazos.nro_cuenta%TYPE DEFAULT NULL);

  /**
   * Calcular monto interes cuota de ahorro programado
   * @param p_nro_cuenta numero de cuenta del ahorro programado
   * @param p_nro_cuenta cuota ahorro programado
   * @param p_mto_cuota monto de la cuota
   */
  FUNCTION fu_cal_interes(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE,
                          p_nro_cuota  IN ah_pro_cuotas.nro_cuota%TYPE,
                          p_mto_cuota  IN ah_pro_cuotas.mto_cuota%TYPE) RETURN NUMBER;

  /**
   * Obtiene los datos del ahorro programado
   * @param p_nro_cuenta numero de cuenta del ahorro programado
   * @param rp_dat_ahorro registro con los datos de la cuenta (out)
   */
  PROCEDURE pr_obt_dat_ahorro(p_nro_cuenta  IN ah_pro_cuotas.nro_cuenta%TYPE,
                              rp_dat_ahorro OUT ah_cta_plazos%ROWTYPE);

  /**
   * Actualiza los datos del ahorro programado. Meta, Cta debito, Periodo de debito
   * @param p_nro_cuenta numero de cuenta del ahorro programado
   * @param rp_dat_ahorro registro con los datos de la cuenta (out)
   */
  PROCEDURE pr_act_dat_ahorro(p_nro_cuenta  IN ah_cta_plazos.nro_cuenta%TYPE,
                              p_meta        IN ah_cta_plazos.denominacion%TYPE DEFAULT NULL,
                              p_cta_debito  IN ah_cta_plazos.nro_cta_capitalizacion%TYPE DEFAULT NULL,
                              p_per_debito  IN ah_cta_plazos.per_debito%TYPE DEFAULT NULL);

  /**
   * Funcion para validar el monto maximo de un refuerzo
   * @param p_nro_cuenta numero de cuenta del ahorro programado
   * @param p_monto monto del refuerzo
   */
  FUNCTION fu_val_mto_refuerzo(p_nro_cuenta IN ah_cta_plazos.nro_cuenta%TYPE,
                               p_monto      IN NUMBER) RETURN VARCHAR2;

  /**
   * Funcion para validar y obtener la fecha de vencimiento
   * @param p_nro_cuenta numero de cuenta del ahorro programado
   * @param p_monto monto del refuerzo
   */
  FUNCTION fu_obt_fec_vencimiento(p_fec_apertura IN ah_cta_plazos.fec_apertura%TYPE,
                                  p_plazo        IN NUMBER,
                                  p_cod_oficina  IN ge_clientes.cod_oficina%TYPE) RETURN DATE;

  /**
   * Funcion que obtiene el numero de cuota segun la fecha
   * @param p_nro_cuenta numero cuenta del ahorro programado
   * @param p_fecha fecha 
   */
  FUNCTION fu_obt_cuota(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE,
                        p_fecha      IN DATE) RETURN NUMBER;

  /**
   * Procedimiento para insertar los refuerzos del ahorro programado
   * @param p_nro_cuenta numero cuenta del ahorro programado
   * @param p_nro_cta_debito numero cuenta a debitar el refuerzo
   * @param p_monto  monto del refuerzo a debitar/acreditar
   */
  PROCEDURE pr_ins_ref_ahorro(p_nro_cuenta     IN ah_pro_cuotas.nro_cuenta%TYPE,
                              p_nro_cta_debito IN ge_cuentas.nro_cuenta%TYPE,
                              p_monto          IN ah_pro_cuotas.mto_cuota%TYPE);

  /**
   * Procedimiento que calcula el cargo por cancelación anticipada
   * @param p_nro_cuenta numero cuenta del ahorro programado
   * @param p_mto_car_fij monto cargo a cobrar por cancelacion
   * @param p_imp_car_fij monto impuesto cargo
   * @param p_mto_car_por monto cargo a cobrar por cancelacion porcetaje del saldo
   * @param p_imp_car_por monto impuesto del porcentaje
   */
  PROCEDURE pr_can_cal_mto_aho_pro (p_nro_cuenta   cc_cta_corrientes.nro_cuenta%TYPE,
                                    p_mto_car_fij  OUT ge_movimientos.monto%type,
                                    p_imp_car_fij  OUT ge_movimientos.monto%type,
                                    p_mto_car_por  OUT ge_movimientos.monto%type,
                                    p_imp_car_por  OUT ge_movimientos.monto%type,
                                    p_tot_cre_neto OUT ge_movimientos.monto%type);

  /**
   * Procedimiento cancelacion de ahorro programado
   * @param p_nro_cuenta numero de cuenta a cancelar
   */
  PROCEDURE pr_can_mov_aho_pro (p_nro_cuenta  cc_cta_corrientes.nro_cuenta%TYPE, p_ind_cob_cargo varchar2 default 'S',
                                p_mto_car_total ge_movimientos.monto%type default 0);

  /**
   * Proceso automático de Cancelación durante el cierre por incumplimento -- Cierre
   */
  PROCEDURE pr_can_aut_cierre;

  /**
   * Procedimiento Autonomo para registro de errores
   * @param p_nro_cuenta numero cuenta ahorro programado
   * @param p_monto monto a debitar
   * @param p_sal_total saldo de la cuenta debito
   * @param p_lugar lugar del error
   * @param p_observacion descripcion del error
   */

  PROCEDURE pr_ins_log_error(p_nro_cuenta   tm_log_nominas.nro_cuenta%type,
                             p_monto        tm_log_nominas.monto%type,
                             p_sal_total    tm_log_nominas.sal_total%type,
                             p_lugar        tm_log_nominas.lugar%type,
                             p_observacion  tm_log_nominas.observacion%type);

  /**
   * Procedimiento que actualiza las cuotas a vencidas -- Cierre
   * @param p_nro_cuenta numero de cuenta ahorro programado
   */
  PROCEDURE pr_act_cuo_vencidas(p_nro_cuenta ah_cta_plazos.nro_cuenta%TYPE DEFAULT NULL);

  /**
   * Proceso automático de pago de ahorro programado -- Cierre
   */
  PROCEDURE pr_pag_aho_programado;

  /**
   * Proceso calculo de capitalizacion del ahorro programado 
   * @param p_nro_cuenta cuenta de ahorro programado
   * @param p_ins_capitalizacion S para insertar capitalizacion, N solo calcula
   * @param p_fec_capitalizacoin fecha de capitalizacion
   * @param p_mto_interes monto de interes generado (out)
   */
  PROCEDURE pr_cap_aho_programado(p_nro_cuenta                IN VARCHAR2 := NULL,
                                  p_ins_capitalizacion        IN VARCHAR2 := 'S',
                                  p_fec_capitalizacion        IN DATE,
                                  p_mto_interes               OUT NUMBER);
  /**
   * Proceso actualiza a vencido/concluido el ahorro programado
   */
  PROCEDURE pr_act_ven_aho_prog;
                               
                                      
  FUNCTION fu_obt_can_cuo_pag(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE) RETURN NUMBER;
  
  function fu_obt_dev_acu(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE) 
                          return ah_devengados.mto_dev_acumulado%type;
                          
  function fu_obt_dev_acu_ah_sal(p_nro_cuenta IN ah_pro_cuotas.nro_cuenta%TYPE,
                          anio_mes      in number) 
                          return ah_sal_mensuales.mto_int_devengado%type;
                                                
  PROCEDURE pr_pro_aho_programado(p_nro_cuenta                IN VARCHAR2 := NULL,
                                  p_ins_capitalizacion        IN VARCHAR2 := 'S',
                                  p_fec_capitalizacion        IN DATE,
                                  p_mto_interes               OUT NUMBER);
  function fu_rec_int_ap(p_nro_cuenta  ah_cta_plazos.nro_cuenta%type) RETURN ah_cta_plazos.sal_total%type;
END PAA_PRO;
/
