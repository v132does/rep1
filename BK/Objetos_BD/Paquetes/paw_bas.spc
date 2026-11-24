CREATE OR REPLACE PACKAGE IT.PAW_BAS is

  -- Author  : XPY0040
  -- Created : 24/08/2017 01:53:56 p.m.
  -- Purpose : Agrupar las funciones de logica financiera y disponibilizar a otros servicios


  G_MON_LOCAL CONSTANT varchar2(3):='GS';

   /**
   * Funcion para activar chequeras
   * @p_nro_cuenta Numero de cuenta de la chequera
   * @p_nro_inicial Numero inicial de cheque
   * @p_nro_final Numero final de cheque
   * @return resultado de la operacion
   */
  FUNCTION fu_activarchequera(p_nro_cuenta  IN cc_chequeras.nro_cuenta%TYPE,
                            p_nro_inicial IN cc_chequeras.nro_che_inicial%TYPE,
                            p_nro_final   IN cc_chequeras.nro_che_final%TYPE)
  RETURN typ_mensajerespuesta;

   /**
   * Registrar acceso de clientes digitales: Inserta registro en bw_cli_digitales
   * @param p_cod_persona Codigo de Persona
   * @param p_cod_canal Codigo de Canal
   * @param p_fec_acceso Fecha de acceso
   */
   PROCEDURE pr_reg_acc_cli_digitales( p_cod_persona IN VARCHAR2,
                                       p_cod_canal IN NUMBER,
                                       p_fec_acceso IN DATE DEFAULT NULL );

  /**
  * Verificamos si se cumplen las condiciones para mostrar la oferta de seguro preaprobado
  * @p_codigoCanal Canal desde el que se llama
  * @p_codTipo Tipo de seguro que se quiere mostrar
  */
  FUNCTION fu_ver_seg_preaprob(p_codigoCanal IN  VARCHAR2,
                             p_codTipo IN NUMBER) RETURN BOOLEAN;


  /* Obtener Tasa Pizarra */
  FUNCTION fu_obt_tas_pizarra(p_plazo IN NUMBER,
                              p_monto IN NUMBER,
                              p_cod_moneda IN ba_monedas.cod_moneda%TYPE,
                              p_cod_modulo IN ba_modulos.cod_modulo%TYPE,
                              p_cod_modalidad IN ge_modalidades.cod_modalidad%TYPE,
                              p_cod_sub_modalidad IN ge_sub_modalidades.cod_sub_modalidad%TYPE DEFAULT NULL,
                              p_tip_capitalizacion IN cr_piz_plazos.tip_capitalizacion%TYPE DEFAULT NULL) RETURN NUMBER;

  /* Realiza el debito automatico de Prestamos, Tarjetas y Mov.Pendientes sin validar Ente */
  PROCEDURE pr_pro_deb_automatico( p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                                   p_mto_debito OUT ge_movimientos.monto%TYPE,
                                   p_error      OUT VARCHAR2
                                  );

  /* Apertura de Cuenta de Plazo Fijo*/
  FUNCTION fu_ape_cta_plazo(p_sesion             IN VARCHAR2,
                            p_cod_persona        IN ge_clientes.cod_persona%TYPE,
                            p_cod_canal          IN ge_canales.cod_canal%TYPE,
                            p_nro_caja           IN cj_cajas.nro_caja%TYPE,
                            p_tip_capitalizacion IN ah_cta_plazos.tip_capitalizacion%TYPE,
                            p_nro_cta_credito    IN ah_cta_plazos.nro_cta_capitalizacion%TYPE,
                            p_monto              IN ah_cta_plazos.capital%TYPE,
                            p_can_meses          IN NUMBER
                            ) RETURN typ_cuentagenerada;

  /**
   * Funcion que verifica si uno de los titulares de una cuenta tiene inhibiciones.
   * @param p_nroCuenta Numero de cuenta a verificar
   * @return resultado de la operacion
   */
  FUNCTION fu_tieneInhibiciones(p_nroCuenta IN VARCHAR2) RETURN typ_mensajerespuesta;

  FUNCTION fu_ver_horario(p_horario        OUT VARCHAR2,
                          p_es_mov_noc     OUT VARCHAR2,
                          p_es_cta_noc     OUT VARCHAR2,
                          p_ult_cierre     IN DATE,
                          p_cod_ofi_origen IN VARCHAR2,
                          p_fec_actual     OUT DATE) RETURN typ_MensajeRespuesta;

  FUNCTION fu_obt_fec_snp(p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                          p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                          p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE) RETURN DATE;

  FUNCTION fu_val_cta_credito(p_nro_cuenta     IN ge_cuentas.nro_cuenta%TYPE,
                              p_cod_tra_padre  IN ge_transacciones.cod_transaccion%TYPE,
                              p_cod_modulo     IN ge_modalidades.cod_modulo%TYPE,
                              p_cod_modalidad  IN ge_modalidades.cod_modalidad%TYPE,
                              p_monto          IN ge_movimientos.monto%TYPE DEFAULT NULL,
                              p_cod_ofi_origen IN ba_oficinas.cod_oficina%TYPE DEFAULT NULL) RETURN typ_mensajeRespuesta;

  /**
   * Obtener la hora fin de un periodo snp.
   *
   * @param p_cod_periodo periodo en ge_snp_horarios.
   */
  FUNCTION fu_obt_hor_fin_snp(p_cod_periodo IN ge_snp_horarios.cod_periodo%TYPE) RETURN VARCHAR2;

  --
  FUNCTION fu_obt_hor_fin_snp(p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                              p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                              p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                              p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type default null) RETURN VARCHAR2;

  FUNCTION fu_obt_hor_ini_snp(p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                              p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                              p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                              p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type default null) RETURN VARCHAR2;
  --

  FUNCTION fu_TransferenciaLocal(p_mensajeCaja      IN typ_mensajeCaja,
                                 p_canal            IN VARCHAR2,
                                 p_codigoPersona    IN VARCHAR2,
                                 p_codigoEmpresa    IN VARCHAR2,
                                 p_fechaValor       IN DATE,
                                 p_nroCuentaDebito  IN VARCHAR2,
                                 p_nroCuentaCredito IN VARCHAR2,
                                 p_montoDebito      IN NUMBER,
                                 p_montoCredito     IN NUMBER,
                                 p_concepto         IN VARCHAR2,
                                 p_codigoOperacion  IN VARCHAR2,
                                 p_sesion in varchar2,
                                 p_modo in varchar2,
                                 p_nroDocumento     in number,
                                 p_nroDocBeneficiario VARCHAR2) RETURN typ_transferencialote;

   FUNCTION fu_TransferenciaInterbancaria(p_mensajeCaja IN typ_mensajeCaja,
                                         p_canal                 IN VARCHAR2,
                                         p_modo                  IN VARCHAR2,
                                         p_codigoPersona         IN VARCHAR2,
                                         p_codigoEmpresa         IN VARCHAR2,
                                         p_fechaValor            IN DATE,
                                         p_nroCuentaDebito       IN VARCHAR2,
                                         p_nroCuentaCredito      IN VARCHAR2,
                                         p_codMonCredito         IN VARCHAR2,
                                         p_montoCredito          IN NUMBER,
                                         p_concepto              IN VARCHAR2,
                                         p_codigoSwift           IN varchar2,
                                         p_nombreBeneficiario    IN VARCHAR2,
                                         p_DirBeneficiario       IN VARCHAR2,
                                         p_codTipoDocumentoBen   IN NUMBER,
                                         p_numeroDocBeneficiario IN VARCHAR2,
                                         p_sesion                IN VARCHAR2,
                                         p_prioridad             IN VARCHAR2,
                                         p_tip_cargos            IN VARCHAR2,
                                         p_firmasRequeridas      IN NUMBER DEFAULT NULL,
                                         p_numeroContrato        IN NUMBER DEFAULT NULL) RETURN typ_transferencialote;

  -- Validar horario de contratos de cambios. 'S' horario valido, 'N' caso contratio.
  FUNCTION fu_ver_hor_contrato RETURN VARCHAR2;

  /**
   * Funcion que valida un contrato de cambio en base a la moneda debito y credito,
   * arbitraje incluido.
   *
   * @param p_cod_mon_debito moneda debito
   * @param p_cod_mon_credito moneda credito
   * @param p_nro_contrato nro diario de contrato
   * @param p_cod_persona codigo cliente
   * @param p_cod_tip_operacion tipo de operacion venta
   * @param p_cod_per_tercero codigo cliente tercero
   *
   * @return  0: Ok
             -1: horario de contrato invalido
             -2: nro de contrato inexistente
             -3: nro de contarto no coincide con la moneda debito y/o credito
            -99: error no tratado
   */
  FUNCTION fu_val_contrato(p_cod_mon_debito    IN ba_monedas.cod_moneda%TYPE,
                           p_cod_mon_credito   IN ba_monedas.cod_moneda%TYPE,
                           p_nro_contrato      IN lc_ope_pendientes.nro_diario%TYPE,
                           p_cod_persona       IN ba_personas.cod_persona%TYPE,
                           p_cod_tip_ope_venta IN lc_ope_pendientes.cod_tip_operacion%TYPE,
                           p_cod_per_tercero   IN ba_personas.cod_persona%TYPE DEFAULT NULL,
                           p_nro_ope_cambio    OUT lc_ope_pendientes.nro_operacion%TYPE,
                           p_monto             OUT lc_ope_pendientes.monto%TYPE,
                           p_mto_credito       OUT lc_ope_pendientes.monto%TYPE,
                           p_cot_debito        OUT lc_ope_pendientes.cotizacion%TYPE,
                           p_cot_credito       OUT lc_ope_pendientes.cotizacion%TYPE,
                           p_mto_equ_local     OUT lc_ope_pendientes.mto_equ_local%TYPE,
                           p_tip_operacion     OUT VARCHAR2) RETURN NUMBER;
  /**
   * Liquidar el contrato de cambio.
   *
   * @param p_cod_usuario codigo usuario del canal
   * @param p_nro_cta_debito cuenta a debitar
   * @param p_mto_debito monto a debitar
   * @param p_cod_mon_debito moneda debito
   * @param p_cod_mon_credito moneda credito
   * @param p_nro_operacion numero de operacion de cambio
   */
  PROCEDURE pr_liq_ope_cambio(p_cod_usuario     IN ba_usuarios.cod_usuario%TYPE,
                              p_nro_cta_debito  IN ge_cuentas.nro_cuenta%TYPE,
                              p_mto_debito      IN ge_movimientos.monto%TYPE,
                              p_cod_mon_debito  IN ba_monedas.cod_moneda%TYPE,
                              p_cod_mon_credito IN ba_monedas.cod_moneda%TYPE,
                              p_nro_operacion   IN lc_ope_pendientes.nro_operacion%TYPE);

  /**
   * Actualizacion en linea de movimientos de cambio sipap
   *
   */
  PROCEDURE pr_act_mov_ope_cam_snp(p_hora                IN ge_movimientos.hora%TYPE,
                                   p_nro_documento       IN ge_movimientos.nro_documento%TYPE,
                                   p_cod_mon_debito      IN ge_movimientos.cod_moneda%TYPE,
                                   p_cod_mon_credito     IN ge_movimientos.cod_moneda%TYPE,
                                   p_usuario             IN VARCHAR2);

   /** Determina si la cuenta es una Cuenta Conjunta*/
   FUNCTION fu_es_conjunta(p_numeroCuenta IN VARCHAR2,p_can_aut_requeridas number) RETURN VARCHAR2;


   FUNCTION fu_obtenerresumencuentas(p_codpersona          IN VARCHAR2,
                                     p_codempresa          IN VARCHAR2,
                                     p_codcanal            IN VARCHAR2,
                                     p_identificadorsesion IN VARCHAR2,
                                     p_canFirmas           IN NUMBER,
                                     p_filtro              IN VARCHAR2 DEFAULT NULL)
     RETURN typ_resumencuentas;

   FUNCTION fu_obtenerSaldos(p_nro_cuenta IN VARCHAR2) RETURN typ_saldos;

   FUNCTION fu_obtenerMovimientos_por_fec(p_cod_persona          IN VARCHAR2,
                                          p_cod_empresa          IN VARCHAR2,
                                          p_cod_canal            IN VARCHAR2,
                                          p_identificadorsesion IN VARCHAR2,
                                          p_nroCuentaEspecifica IN VARCHAR2,
                                          p_nroPagina           IN NUMBER DEFAULT NULL,
                                          p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                          p_fec_inicio          IN DATE DEFAULT NULL,
                                          p_fec_fin             IN DATE DEFAULT NULL)
      RETURN typ_detalleMovimientos;

   /**
    * Validar si se debe generar movimiento por cierre de modulo 9.
    */
   FUNCTION fu_val_gen_ope_cierre RETURN VARCHAR2;

  FUNCTION fu_obtTotCuoPrestamo(p_cod_persona          IN VARCHAR2,
                                p_cod_empresa          IN VARCHAR2,
                                p_cod_canal            IN VARCHAR2,
                                p_nro_prestamo         IN VARCHAR2,
                                p_identificador_sesion IN VARCHAR2 DEFAULT NULL)
    RETURN typ_obtCuotasPrestamo;

    FUNCTION fu_obt_prestamo(p_cod_persona          IN VARCHAR2,
                            p_cod_empresa          IN VARCHAR2,
                            p_cod_canal            IN VARCHAR2,
                            p_nro_prestamo         IN VARCHAR2,
                            p_identificador_sesion IN VARCHAR2 DEFAULT NULL)
    RETURN typ_mapa;

   FUNCTION fu_obt_liq_prestamo(p_cod_persona IN VARCHAR2,
                                p_nro_cuenta IN VARCHAR2)
   RETURN typ_infoLiquidacionPrestamo;

   FUNCTION fu_obt_dat_cliente(p_cod_persona IN VARCHAR2)
       RETURN TYP_CONTACTOSCLIENTE;

   FUNCTION fu_cta_alias(p_cod_persona IN VARCHAR2,
                         p_cod_per_vinculada IN VARCHAR2,
                         p_cod_canal IN VARCHAR2,
                         p_id_producto IN VARCHAR2,
                         p_alias IN VARCHAR2,
                         p_id_sesion IN VARCHAR2 DEFAULT NULL)
       RETURN TYP_MENSAJERESPUESTA;

   FUNCTION fu_obt_terminosycondiciones(p_cod_persona IN VARCHAR2,
                                        p_cod_empresa IN VARCHAR2,
                                        p_aplicacion  IN VARCHAR2,
                                        p_cod_canal   IN VARCHAR2,
                                        p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                        RETURN TYP_TERMINOSYCONDICIONES;

   FUNCTION fu_reg_terminosycondiciones(p_cod_persona IN VARCHAR2,
                                        p_cod_empresa IN VARCHAR2,
                                        p_aplicacion  IN VARCHAR2,
                                        p_cod_canal   IN VARCHAR2,
                                        p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                        RETURN TYP_MENSAJERESPUESTA;

   FUNCTION fu_reg_ema_login_blacklist(p_cod_persona IN VARCHAR2,
                                       p_cod_empresa IN VARCHAR2,
                                       p_cod_dispositivo IN VARCHAR2,
                                       p_version_ema IN VARCHAR2,
                                       p_mobile_os IN VARCHAR2,
                                       p_estado IN VARCHAR2,
                                       p_cod_canal   IN VARCHAR2,
                                       p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                       RETURN TYP_TERMINOSYCONDICIONES;

   FUNCTION fu_obt_ema_login_blacklist(p_cod_persona IN VARCHAR2,
                                       p_cod_empresa IN VARCHAR2,
                                       p_cod_canal   IN VARCHAR2,
                                       p_cod_sesion  IN VARCHAR2 DEFAULT NULL)
                                       RETURN TYP_MENSAJERESPUESTA;

   FUNCTION fu_obt_snp_fec_acreditacion(p_cod_msj_swift IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                                        p_cod_mon_credito   IN ge_snp_transferencias.cod_moneda%type) RETURN DATE;

   FUNCTION fu_obt_tip_TransfInterbancaria( p_cod_msj_swift     IN ge_snp_par_mensajes.cod_msj_swift%TYPE,
                                            p_tip_operacion     IN ge_snp_par_mensajes.cod_tip_operacion%TYPE,
                                            p_sub_tip_operacion IN ge_snp_par_mensajes.cod_sub_tip_operacion%TYPE,
                                            p_cod_tra_padre     IN ge_snp_par_mensajes.cod_tra_padre%type,
                                            p_monto             IN ge_snp_transferencias.monto%type,
                                            p_cod_mon_credito   IN ge_snp_transferencias.cod_moneda%type,
                                            p_fec_pago          IN ge_snp_transferencias.fec_valor%type default null,
                                            p_cod_persona       IN ge_snp_transferencias.cod_per_solicitante%type default null) return varchar2;
    
   FUNCTION fu_obtenerMovimientos_por_fec_ext(p_cod_persona          IN VARCHAR2,
                                              p_cod_empresa          IN VARCHAR2,
                                              p_cod_canal            IN VARCHAR2,
                                              p_identificadorsesion  IN VARCHAR2,
                                              p_nroCuentaEspecifica  IN VARCHAR2,
                                              p_nroPagina            IN NUMBER DEFAULT NULL,
                                              p_cantItemsPagina      IN NUMBER DEFAULT NULL,
                                              p_fec_inicio           IN DATE DEFAULT NULL,
                                              p_fec_fin              IN DATE DEFAULT NULL)
      RETURN typ_detalleMovimientos;                                            

end PAW_BAS;
/

