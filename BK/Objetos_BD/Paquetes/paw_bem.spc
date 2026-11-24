CREATE OR REPLACE PACKAGE IT.paw_bem IS

  v_nro_terminal      varchar2(3);   -- nro de terminal en el que se ingreso
  v_cod_operacion     varchar2(3);   -- codigo de la operacion recibida
  v_cod_aprobado      varchar2(03) := '000';
  v_mon_dec_invalida  varchar2(03) := '-87'; -- Moneda no permite decimal
  -- maximo numero de registros que se pueden importar por archivo
  v_max_imp_archivo   number := 1800;
  C_COD_HOMEBANKING  CONSTANT VARCHAR2(5)  := '999';
  C_COD_USSD         CONSTANT VARCHAR2(5)  := '993';
  v_tra_spi          varchar2(1) :='N';
  v_tra_spi_ind      varchar2(1) :='N';
  v_patrocinador     varchar2(1)           :='N'; --DA-7221
  v_mod_estado         ba_modulos.estado%TYPE;
  v_alias            varchar2(50); -- SPI fase 2


   /**
   *typ_validarSesion
   *  Tipo  privado utilizado para retornar el estado de
   *  validez de una sesion ademas de informacion relacionada
   *  a la sesion
   */
   TYPE typ_validarSesion IS RECORD(
      error                VARCHAR2(1),  -- hubo Error?
      nombreRespuesta      VARCHAR2(15), --Nombre del mensaje
      descripcionRespuesta VARCHAR2(200),-- Descripcion del mensaje
      codigoPersona        VARCHAR2(10), -- Nombre del mensaje
      codigoCanal          VARCHAR2(3),  -- Nombre del mensaje
      codigoEmpresa        VARCHAR2(10), -- Nombre del mensaje
      codigoPerfil         VARCHAR(20),
      numeroTelefono       VARCHAR2(30)); -- Número de Telefono

   /**
   * Guarda los permisos de un usuario para una persona juridica
   * @param error Indica si ocurrio un error recuperando la clave del usuario
   * @param nombreRespuesta Indica el nombre del mensaje
   * @param descripcionRespuesta Indica una descripcion de la respuesta
   * @param autoriza Indica si la persona tiene el permiso para autorizar operaciones(A)
   * @param registra Indica si la persona tiene el permiso para registrar operaciones(I)
   * @param consulta Indica si la persona tiene el permiso para registrar consultar()
   */
   TYPE typ_obtenerPermisos IS RECORD(
      error                        VARCHAR(1),
      nombreRespuesta              VARCHAR2(15),
      descripcionRespuesta         VARCHAR2(200),
      autoriza                     BOOLEAN,
      registra                     BOOLEAN,
      consulta                     BOOLEAN,
      autorizacionesRequeridas     NUMBER,
      canAutRequeridas             NUMBER);

   /**
   * Respuesta de la llamada a fu_obtenerLimite
   * @param error Indica si ocurrio un error recuperando la clave del usuario
   * @param nombreRespuesta Indica el nombre del mensaje
   * @param descripcionRespuesta Indica una descripcion de la respuesta
   * @param codRespuesta Indica que tipo de clave solicitar al usuario
   */
    TYPE typ_respuestaLimite IS RECORD(
      error                VARCHAR(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      codRespuesta         VARCHAR2(2));

    /**
   * @param p_cod_modulo
   * @param p_cod_modalidad
   * @param p_numeroCuenta
   */
   FUNCTION fu_obt_sal_actual(p_cod_modulo    IN NUMBER,
                              p_cod_modalidad IN NUMBER,
                              p_numeroCuenta  IN VARCHAR2) RETURN NUMBER;

   /**
   * @param p_cod_modulo
   * @param p_cod_modalidad
   */
   FUNCTION fu_tip_cuenta(p_cod_modulo    IN NUMBER,
                          p_cod_modalidad IN NUMBER) RETURN varchar2;

   /**
   * @param p_cod_mensaje
   * @param p_nro_cuenta
   * @param p_cod_canal
   * @param p_fecha
   */
   -- Verifica si el mensaje esta limitado
   FUNCTION fu_es_ope_limitadas(p_cod_mensaje in varchar2
                                ,p_nro_cuenta in varchar2
                                ,p_cod_canal  in varchar2
                                ,p_fecha       in date)
      return varchar2;

   /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_nroCtaDebito
   * @param p_monto
   * @param p_nroCtaCredito
   * @param p_modo
   * @param p_cotizacion
   * @param p_mtoCredito
   * @param p_concepto
   * @param p_nroDocCredito
   * @param p_conCambio
   * @param p_cotCredito
   * @param p_claveTransaccional
   * @param p_esTercero
   * @return typ_transferencia
   */
  /* FUNCTION fu_transferencias(p_sesion             IN VARCHAR2,
                             p_codCanal           IN VARCHAR2,
                             p_nroCtaDebito       IN VARCHAR2,
                             p_monto              IN NUMBER,
                             p_nroCtaCredito      IN VARCHAR2,
                             p_modo               IN VARCHAR2,
                             p_cotizacion         IN NUMBER,
                             p_mtoCredito         IN NUMBER,
                             p_concepto           IN VARCHAR2,
                             p_nroDocCredito      IN NUMBER,
                             p_conCambio          IN NUMBER,
                             p_cotCredito         IN NUMBER,
                             p_claveTransaccional IN VARCHAR2,
                             p_esTercero          IN VARCHAR2 DEFAULT NULL) RETURN typ_transferencia;

*/

/*FUNCTION fu_transferencias
  (
     p_codigoPersona         IN VARCHAR2,
     p_codigoEmpresa IN VARCHAR2,
     p_codcanal           IN VARCHAR2,
     p_nroctadebito       IN VARCHAR2,
     p_monto              IN NUMBER,
     p_nroctacredito      IN VARCHAR2,
     p_modo               IN VARCHAR2,
     p_cotizacion         IN NUMBER,
     p_mtocredito         IN NUMBER,
     p_concepto           IN VARCHAR2,
     p_nrodoccredito      IN NUMBER,
     p_concambio          IN NUMBER,
     p_cotcredito         IN NUMBER,
     p_clavetransaccional IN VARCHAR2,
     p_estercero          IN VARCHAR2 DEFAULT NULL
  ) RETURN typ_transferencia;*/



   /**Elimina la sesion del usuario
   * @param p_sesion Código de la sesión
   * @return Resultado de la operacion
   */
   FUNCTION depurarAlfanumerico(p_string  IN VARCHAR2,
                                maxLength IN NUMBER) RETURN VARCHAR2;


   /**Cambia la clave de la transacción
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_claveAntigua Clave anterior
   * @param p_claveNueva Clave nueva
   * @return Resultado de la operacion
   * @return typ_mensajeRespuesta
   */
   FUNCTION fu_cambiarClaveTransaccion(p_sesion      IN VARCHAR2,
                                       p_codCanal    IN VARCHAR2,
                                       p_claveActual IN VARCHAR2,
                                       p_claveNueva  IN VARCHAR2) RETURN typ_mensajeRespuesta;

   /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_nroCuentaEspecifica
   * @return typ_obtenerDetalleCuentas
   */
  /* FUNCTION fu_obtenerDetalleCuentas_ueno(p_codigoPersona         IN VARCHAR2,
                                     p_codigoEmpresa IN VARCHAR2,
                                     p_codCanal            IN VARCHAR2,
                                     p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDetalleCuentas;*/

   /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_tipoConsulta
   * @param p_verCuentas
   * @param p_codigoMoneda
   * @return typ_resumenCuentas
   */
   /*FUNCTION fu_obtenerResumenCuentas_ueno( p_codigoPersona         IN VARCHAR2,
                                     p_codigoEmpresa IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_tipoConsulta IN VARCHAR2 DEFAULT NULL,
                                     p_verCuentas   IN VARCHAR2 DEFAULT NULL,
                                     p_codigoMoneda IN VARCHAR2 DEFAULT NULL) RETURN typ_resumenCuentas;*/

     /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_nroCuentaEspecifica
   * @param p_nroPagina
   * @param p_cantItemsPagina
   * @return typ_detalleMovimientos
   */
  /* FUNCTION fu_obtenerMovimientos(p_codigoPersona         IN VARCHAR2,
                                 p_codigoEmpresa IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                  p_fechaDesde           IN VARCHAR2,
                                  p_fechaHasta           IN VARCHAR2) RETURN typ_detalleMovimientos;*/


   /**Listado de Cajeros Automáticos
   * @param p_codCanal Código del canal
   * @return Retorna los Cajeros Automáticos de la Entidad
   * @return typ_informacionCajeros
   */
  /* FUNCTION fu_obtenerCajeros (p_codCanal IN VARCHAR2) RETURN typ_informacionCajeros;*/


   /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_nroCuenta
   * @return Retorna cheques devueltos
   * @return typ_ChequesDevueltos
   */
  /* FUNCTION fu_obtenerChequesDevueltos(p_sesion    IN VARCHAR2,
                                       p_codCanal  IN VARCHAR2,
                                       p_nroCuenta IN VARCHAR2 DEFAULT NULL) RETURN typ_ChequesDevueltos;*/

   /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_nroCuenta
   * @param p_esFaxNocturno
   * @return Retorna confirmacion de depositos
   * @return typ_depositosConfirmar
   */
  /* FUNCTION fu_obtenerDepositosConfirmar(p_sesion    IN VARCHAR2,
                                         p_codCanal  IN VARCHAR2,
                                         p_nroCuenta IN VARCHAR2 DEFAULT NULL,
                                         p_esFaxNocturno IN VARCHAR2 DEFAULT 'N') RETURN typ_depositosConfirmar;*/

   /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_inicio
   * @param p_fin
   * @return Retorna detalle transacciones internacionales
   * @return typ_detalleTransInternacional
   */
   /*FUNCTION fu_obtTransInternacional(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_inicio   IN DATE,
                                     p_fin      IN DATE) RETURN typ_detalleTransInternacional;*/

    /**
   * @param p_sesion
   * @param p_codCanal
   * @return Retorna calificación de riesgo
   * @return typ_calificacionRiesgo
   */
   FUNCTION fu_obtenerCalificacionRiesgo(p_sesion   IN VARCHAR2,
                                         p_codCanal IN VARCHAR2) RETURN typ_calificacionRiesgo;

   /**
    * Pago de Servicio Mobile Banking
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_numeroCuenta Nro de cuenta
    * @param p_modo Modo
    * @param p_codigoServicio Código de Servicio
    * @param p_monto Monto
    * @param p_codigoMoneda Código de Moneda del Servicio
    * @param p_numeroLote Número de Lote
    * @param p_numeroOperacion Número de Operación
    * @param p_mora Monto de la Mora
    * @param p_comision Monto de la Comisión
    *  @return Resultado de la operacion
    * @return typ_mensajeRespuesta
   */
   /*FUNCTION fu_pagoServicioMovil(p_sesion             IN VARCHAR2,
                                 p_codCanal           IN VARCHAR2,
                                 p_numeroCuenta       IN VARCHAR2,
                                 p_modo               IN VARCHAR2,
                                 p_codigoServicio     IN NUMBER,
                                 p_monto              IN NUMBER,
                                 p_codigoMoneda       IN VARCHAR2,
                                 p_numeroLote         IN VARCHAR2,
                                 p_numeroOperacion    IN NUMBER,
                                 p_mora               IN NUMBER,
                                 p_comision           IN NUMBER,
                                 p_codigoTerminal     IN NUMBER) RETURN typ_mensajeRespuesta;*/

   /**
   *Obtiene los saldos de una cuenta
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_nroCuenta Nro de cuenta
   * @param p_dias Cantidad de dias
   * @return Resultado de la operacion
   * @return typ_saldosCuentas
   */
  /* FUNCTION fu_obtenerSaldosCuenta(p_sesion    IN VARCHAR2,
                                   p_codCanal  IN VARCHAR2,
                                   p_nroCuenta IN VARCHAR2,
                                   p_dias      IN NUMBER) RETURN typ_saldosCuentas;*/

    /**
   * @param p_tipoPedido
   * @param p_codPedido
   * @return Retorna datos geográficos
   * @return typ_datosGeograficos
   */
   /*FUNCTION fu_obtenerDatosGeograficos(p_tipoPedido IN VARCHAR2,
                                       p_codPedido  IN NUMBER DEFAULT NULL) RETURN typ_datosGeograficos;*/

   /** Validacion y/o Confirmacion de Transferencias entre Cuentas
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_nroCtaDebito Numero de la cuenta del cliente a la cual se realizara el debito
   * @param p_monto Monto de la transferencia a realizar
   * @param p_nroCtaCredito Numero de la cuenta del cliente a la cual se realizara el credito
   * @param p_modo Modo de la operacion <ul><il><b>V:</b> Verificación</il><il>  <b>C:</b> Confirmación</il></ul>
   * @param p_cotizacion Cotización con la cual se realiza la operación
   * @param p_mtoCredito Monto de credito
   * @param p_concepto Descripcion de la operacion ingresada por el usuario
   * @param p_nroDocCredito Número de Documento de la Cuenta de Credito
   * @param p_conCambio Número de Contrato de Cambios
   * @param p_cotCredito Cotización de Credito
   * @param p_claveToken Clave Token
   * @param p_esTercero Indica si la Transferencia es a un Tercero
   * @return Informacion sobre el resultado de la Transferencia
   * @return typ_resumenFacturas
   */

   /**Listado de Facturas  **/
   /*FUNCTION fu_obtenerListaFacturas(p_sesion   IN VARCHAR2,
                                    p_codCanal IN VARCHAR2) RETURN typ_resumenFacturas;*/

    /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_nroFactura
   * @return Retorna detalle facturas
   * @return typ_detallesFactura
   */
   FUNCTION fu_obtenerFactura(p_sesion     IN VARCHAR2,
                              p_codCanal   IN VARCHAR2,
                              p_nroFactura IN VARCHAR,
                              p_fechaFactura IN DATE) RETURN typ_detallesFactura_hb;--NVB-2232


    /** Pago de Préstamo
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroPrestamo Número de Préstamo
    * @param p_cuentaDebito Cuenta de Débito
    * @param p_cantCuotas Cantidad de Cuotas a Pagar
    * @param p_montoOperacion Monto de la Operación
    * @param p_modo Modo
    * @param p_claveToken Clave de Token
    * @return Resultado de la operacion de Pago de Préstamo
    * @return typ_pagoPrestamo
    */
  FUNCTION fu_pagoPrestamo(p_sesion             IN VARCHAR2,
                            p_codCanal           IN VARCHAR2,
                            p_nroPrestamo        IN VARCHAR2,
                            p_cuentaDebito       IN VARCHAR,
                            p_cantCuotas         IN VARCHAR2,
                            p_montoOperacion     IN VARCHAR2,
                            p_modo               IN VARCHAR2,
                            p_claveToken         IN VARCHAR2,
                            p_claveTransaccional IN VARCHAR2,
                            p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null) --UES-458
                            RETURN typ_pagoPrestamo;
  /**
    * Obtiene el número de Cuotas de un Préstamo que se pueden pagar
    * @Creado por: Sergio Ayala
    * @Fecha : 11-07-2012
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroPrestamo Número de Préstamo
    * @return Datos de las Cuotas de un Préstamo
    * @return typ_obtCuotasPrestamo
    */
   FUNCTION fu_obtenerCuotasPrestamo(p_sesion      IN VARCHAR2,
                                     p_codCanal    IN VARCHAR2,
                                     p_nroPrestamo IN VARCHAR2) RETURN typ_obtCuotasPrestamo;

   /**
    * Pago de Tarjetas de Crédito
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroTarjetaCredito Numero de tarjeta de credito a pagar
    * @param p_cuentaDebito Numero de cuenta a debitar
    * @param p_modo <ul><il><b>C</b>:Confirmar</il><il><b>V</b>:Verificar</il></ul>
    * @param p_nroSobre: Compatibilidad otros canales
    * @param p_importeEfectivo: Compatibilidad otros canales
    * @param p_importeChequeBanco : Compatibilidad otros canales
    * @param p_importeChequeOtroBanco: Compatibilidad otros canales
    * @param p_importeDebito: Total a debitar de la cuenta
    * @param p_totalPago: Monto a pagar
    * @param p_claveToken  Dependiendo de la configuración de limites operativos
    * @param p_numeroContrato Número de Contrato de Cambios
    * @param p_esTercero Indica si la Transferencia es a un Tercero
    * @return Resultado de la operacion
    * @return typ_pagoTarjetaCredito
   */
   /*FUNCTION fu_pagoTarjetaCredito(p_codigoPersona          IN VARCHAR2,
                                  p_codigoEmpresa          IN VARCHAR2,
                                  p_codCanal               IN VARCHAR2,
                                  p_nroTarjetaCredito      IN VARCHAR2,
                                  p_cuentaDebito           IN VARCHAR2,
                                  p_modo                   IN VARCHAR2,
                                  p_nroSobre               IN NUMBER,
                                  p_importeEfectivo        IN NUMBER,
                                  p_importeChequeBanco     IN NUMBER,
                                  p_importeChequeOtroBanco IN NUMBER,
                                  p_importeDebito          IN NUMBER,
                                  p_totalPago              IN NUMBER,
                                  p_claveToken             IN VARCHAR2,
                                  p_numeroContrato         IN VARCHAR2,
                                  p_esTercero              IN VARCHAR2 DEFAULT NULL,
                                  p_claveTransaccional     IN VARCHAR2) RETURN typ_pagoTarjetaCredito ;*/

   /**
      * saldo diarios
      * @Creado por: Fermín Giménez
      * @Fecha : 13-09-2012
      * @param p_sesion Código de la sesión
      * @param p_codCanal Código del canal
      * @param p_numeroCuenta Numero de cuenta
      * @param p_cantidadDias cantidad de dias.
      * @return Resultado de la operacion
      * @return typ_detalleSaldosDiarios
      */
      FUNCTION fu_obtenerSaldosDiarios(p_sesion       IN VARCHAR2,
                                       p_codCanal     IN VARCHAR2,
                                       p_numeroCuenta IN VARCHAR2,
                                       p_cantidadDias IN NUMBER) RETURN typ_detalleSaldosDiarios;

   /**
      * Condiciones comerciales  por cliente y cuenta
      * @Creado por: Fermín Giménez
      * @Fecha : 17-08-2012
      * @param p_sesion Código de la sesión
      * @param p_codCanal Código del canal
      * @param p_nroCuenta Numero de cuenta
      * @return Resultado de la operacion
      * @return typ_condicionComercial
      */
       FUNCTION fu_obtenerCondicionComercial(p_sesion    IN VARCHAR2,
                                             p_codCanal  IN VARCHAR2,
                                             p_nroCuenta IN VARCHAR2) RETURN typ_condicionComercial;

   /**
      * Obtener Tarjetas Adicionales
      * @Fecha : 28-09-2012
      * @param p_sesion Código de la sesión
      * @param p_codCanal Código del canal
      * @param p_nroTarjetaCredito Numero de la Tarjeta Credito
      * @return Resumen de Tarjetas Adicionales
      * @return typ_resumenTarjetasAdicionales
      */
      FUNCTION fu_obtenerTarjetasAdicionales(p_sesion            IN VARCHAR2,
                                             p_codCanal          IN VARCHAR2,
                                             p_nroCuenta         IN VARCHAR2)
                                             RETURN typ_resumenTarjetasAdicionales;

    /**
   * Area del Cliente
   * @Creado por: Fermín Giménez
   * @Fecha : 13-12-2012
   * @param p_sesion
   * @param p_codigoCanal
   * @return typ_respuestaAreaCliente
   */
   FUNCTION fu_obtenerAreaCliente(p_sesion            IN VARCHAR2,
                                  p_codigoCanal       IN VARCHAR2)
                                  RETURN typ_respuestaAreaCliente;




   /**
   * Obtiene nro de secuencia de sueldos.
   * @Fecha : 25-09-2014
   * @param p_cod_ente
   * @param p_fec_actual

   */
  FUNCTION fu_obt_nro_sec_sueldo(p_cod_ente   in ge_pag_sueldos.cod_ente%type,
                                 p_fec_actual in ge_pag_sueldos.fec_envio%type)
     RETURN NUMBER ;


   /**
   * Obtiene Sueldos.
   * @Fecha : 25-09-2014
   * @param p_cod_ente
   * @param p_tip_remuneracion

   */

  FUNCTION fu_obt_tra_sueldo(p_cod_ente         IN ge_entes.cod_ente%TYPE,
                             p_tip_remuneracion IN ge_pag_sueldos_tmp.tip_remuneracion%TYPE)
    RETURN NUMBER ;

   /**
   * Obtiene Datos.
   * @Fecha : 25-09-2014
   * @param p_for_archivo
   * @param p_nom_tabla
   * @param p_registro
   * @param p_campo

   */

  FUNCTION fu_obt_dato(p_for_archivo in varchar2,
                       p_nom_tabla   in varchar2,
                       p_registro    in varchar2,
                       p_campo       in varchar2) return varchar2;


   /**
   * Obtiene Operaciones.
   * @Fecha : 25-09-2014
   * @param p_nro_cuenta
   * @param p_monto
   * @param p_cod_transaccion
   * @param p_cod_tra_padre
   * @param p_tip_movimiento

   */
   FUNCTION fu_ver_operacion(p_nro_cuenta      in ge_cuentas.nro_cuenta%type,
                            p_monto            in ge_movimientos.monto%type,
                            p_cod_transaccion  in ge_movimientos.cod_transaccion%type,
                            p_cod_tra_padre    in ge_movimientos.cod_tra_padre%type,
                            p_tip_movimiento   in varchar2) return varchar2;


  /**
   * Obtiene el valor pendiente.
   * @Fecha : 25-09-2014
   * @param p_nro_documento
   * @param p_cod_persona
   */

  FUNCTION fu_val_per_pendiente(p_nro_documento in bw_mov_pendientes.nro_documento%type,
                              p_cod_persona   in ge_clientes.cod_persona%type)
  return varchar2;


  /**
   * @param p_cod_empresa
   * @param p_nro_documento
   */
  FUNCTION fu_obt_aut_limite(p_cod_empresa   in bw_mov_pendientes.cod_per_principal%type,
                             p_nro_documento in bw_mov_pendientes.nro_documento%type)
  return varchar2;

   /**
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_numeroDocumento
   * @param p_estado
   * @param p_fecha
   * @return detalle de autorización
   * @return typ_detalleAutorizacion
   */
  FUNCTION fu_obtenerDetalleAutorizacion(p_sesion           IN VARCHAR2,
                                          p_codigoCanal     IN VARCHAR2,
                                          p_numeroDocumento IN bw_mov_pendientes.nro_documento%TYPE,
                                          p_estado          IN VARCHAR2 DEFAULT 'P',
                                          p_fecha           IN DATE DEFAULT NULL) RETURN typ_detalleAutorizacion ;--NVB-2232

  PROCEDURE lp_obt_sue_errores(p_cod_ente             IN ge_entes.cod_ente%TYPE,
                                p_referencia          IN ge_pag_sueldos.nro_secuencia%TYPE,
                                p_listaDetalleSalario IN OUT typ_listaDetalleSalario,--NVB-2232
                                p_fecha               IN DATE DEFAULT NULL) ;

  PROCEDURE pr_act_fec_pag_pendiente(p_nro_documento in bw_mov_pendientes.nro_documento%type,
                                   p_cod_persona   in bw_mov_pendientes.cod_per_principal%type,
                                   p_fec_pago      in bw_mov_pendientes.dato2%type);

  /**
   * Obtiene Pago de Salarios.
   * @Fecha : 25-09-2014
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_codigoEnte
   * @param p_modoControl
   * @param p_codigoMoneda
   * @param p_montoTotal
   * @param p_tipoRemuneracion
   * @param p_cantCuentasParaCredito
   * @param p_canRegistrosLeidos
   * @param p_parametros
   * @param p_claveTransaccional
   * @param p_claveToken
   * @return typ_pagoSalarios
   */
  FUNCTION fu_pagoSalarios(p_sesion                 IN VARCHAR2,
                            p_codigoCanal            IN VARCHAR2,
                            p_codigoEnte             IN NUMBER,
                            p_modoControl            IN VARCHAR2,
                            p_codigoMoneda           IN VARCHAR2,
                            p_montoTotal             IN NUMBER,
                            p_tipoRemuneracion       IN VARCHAR2,
                            p_cantCuentasParaCredito IN NUMBER,
                            p_canRegistrosLeidos     IN NUMBER,
                            p_parametros             IN CLOB,
                            p_claveTransaccional     IN VARCHAR2,
                            p_claveToken             IN VARCHAR2,
                            p_fecPago                IN DATE) RETURN typ_pagoSalarios;--NVB-2232



/**
   * Obtiene Pago a Proveedores.
   * @Fecha : 01-10-2014
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_codigoEnte
   * @param p_modoControl
   * @param p_cuentaDebito
   * @param p_fechaPago
   * @param p_tipoPago
   * @param p_cantOrdenes
   * @param p_parametros
   * @param p_par_errores
   * @param p_claveTransaccional
   * @param p_claveToken
   * @return typ_pagoProveedores
   */
   /*FUNCTION fu_pagoProveedores(p_sesion                 IN VARCHAR2,
                               p_codigoCanal            IN VARCHAR2,
                               p_codigoEnte             IN NUMBER,
                               p_modoControl            IN VARCHAR2,
                               p_cuentaDebito           IN VARCHAR2,
                               p_fechaPago              IN DATE,
                               p_tipoPago               IN VARCHAR2,
                               p_cantFacturas           IN NUMBER,
                               p_parametros             IN CLOB,
                               p_claveTransaccional     IN VARCHAR2) RETURN typ_pagoProveedores;*/

  /**
   * @param p_cod_ente
   */
  FUNCTION fu_pagoProveedores_dev(p_sesion                 IN VARCHAR2,
                               p_codigoCanal            IN VARCHAR2,
                               p_codigoEnte             IN NUMBER,
                               p_modoControl            IN VARCHAR2,
                               p_cuentaDebito           IN VARCHAR2,
                               p_fechaPago              IN DATE,
                               p_tipoPago               IN VARCHAR2,
                               p_cantOrdenes            IN NUMBER,
                               p_cantFacturas           IN NUMBER,
                               p_parametros             IN CLOB,
                               p_par_errores            IN CLOB,
                               p_claveTransaccional     IN VARCHAR2,
                               p_claveToken             IN VARCHAR2) RETURN typ_pagoProveedores;--NVB-2232
  FUNCTION fu_obt_tip_pro_sueldo(p_cod_ente IN ge_entes.cod_ente%TYPE)
  RETURN VARCHAR2;

   /**
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_estado
   * @return consulta de autorizaciones
   * @return typ_consultaAutorizaciones
   */
  FUNCTION fu_obtenerAutorizacionUsuario( p_sesion      IN VARCHAR2,
                                          p_codigoCanal IN VARCHAR2,
                                          p_estado      IN VARCHAR2 DEFAULT NULL )
  RETURN typ_consultaAutorizaciones;

   /**
   * @param p_cod_per_empresa
   * @param p_cod_persona
   */
  FUNCTION lf_val_per_vinculada(p_cod_per_empresa in ge_clientes.cod_persona%type,
                                p_cod_persona     in ge_clientes.cod_persona%type)
  RETURN VARCHAR2;

  /**
   * @param p_cod_persona
   * @param p_cla_nueva
   */
  FUNCTION fu_val_vul_claves(p_cod_persona in bw_ope_claves.cod_persona%type,
                             p_cla_nueva   in bw_ope_claves.clave%type)
  RETURN VARCHAR2;

  /**
   * @param p_cod_cliente
   * @param p_cod_per_vinculada
   */
  FUNCTION fu_obt_nro_seguridad(p_cod_cliente       IN VARCHAR2,
                                p_cod_per_vinculada IN VARCHAR2,
                                p_tip_clave         IN VARCHAR2)
  RETURN NUMBER;

  /**
   * @param p_cod_persona
   * @param p_cod_per_vinculada
   * @param p_tipo
   * @param p_est_clave
   */
  FUNCTION fu_act_est_clave(p_cod_persona       bw_ope_claves.cod_persona%TYPE,
                            p_cod_per_vinculada bw_ope_claves.cod_per_vinculada%TYPE,
                            p_tipo              VARCHAR2,
                            p_est_clave         bw_ope_claves.est_clave%TYPE)
  RETURN BOOLEAN ;

  /**
   * @param p_clave
   * @param p_cod_persona
   * @param p_cod_per_vinculada
   * @param p_accion
   * @param p_tip_clave
   * @param p_cla_operacion
   */
  /*FUNCTION fu_gen_ope_clave (p_clave           IN VARCHAR2,
                           p_cod_persona       IN VARCHAR2,
                           p_cod_per_vinculada IN VARCHAR2,
                           p_accion            IN VARCHAR2,
                           p_tip_clave         IN VARCHAR2,
                           p_cla_operacion     OUT VARCHAR2)
  RETURN VARCHAR2;*/

  /**
   * @param p_cod_ente
   * @param p_fec_proceso
   */
  FUNCTION fu_obt_sig_nro_secuencia( p_cod_ente    IN ge_pag_sue_lotes.cod_ente%TYPE,
                                     p_fec_proceso IN ge_pag_sue_lotes.fec_proceso%TYPE)
  RETURN NUMBER;

  PROCEDURE lp_cla_reg_operacion(p_cod_persona       IN VARCHAR2,
                                 p_accion            IN VARCHAR2,
                                 p_cod_per_vinculada IN VARCHAR2,
                                 p_tip_clave         IN VARCHAR2);

  /**
   * @param p_clave
   * @param p_cod_persona
   * @param p_cod_per_vinculada
   * @param p_tip_clave
   * @param p_act_visitas
   * @return typ_mensajeRespuesta
   */
  FUNCTION fu_val_ope_clave(p_clave           IN VARCHAR2,
                          p_cod_persona       IN VARCHAR2,
                          p_cod_per_vinculada IN VARCHAR2,
                          p_tip_clave         IN VARCHAR2,
                          p_act_visitas       IN VARCHAR2 DEFAULT 'N')
  RETURN typ_mensajeRespuesta;


  /**
   * @param p_sesion
   * @param p_codigoCanal
   */
  FUNCTION fu_obtenerEnte(p_sesion   IN VARCHAR2,
                          p_codigoCanal IN VARCHAR2,
                          p_tipoentidad IN VARCHAR2) RETURN typ_ente;

   /**
   * Pago de Servicios
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_modo
   * @param p_cuenta
   * @param p_numeroIp
   * @param p_claveTransaccional
   * @return typ_pagoServicios
   */
   FUNCTION fu_pagoServicios(p_codigoPersona IN VARCHAR2,
                             p_codigoEmpresa IN VARCHAR2,
                             p_codigoCanal IN VARCHAR2,
                             p_modo        IN VARCHAR2,
                             p_cuenta      IN VARCHAR2,
                             p_montoOperacion  IN NUMBER,
                             p_montoComision   IN NUMBER,
                             p_numeroOperacion  IN NUMBER,
                             p_desOperacion IN VARCHAR2,
                             p_parEnviados IN VARCHAR2,
                             p_ideSeguridad IN VARCHAR2,
                             p_claveTransaccional IN VARCHAR2)
   RETURN typ_pagoServicios;


   /**
   * Carga de parámetros iniciales de SNP
   * @param p_sesion
   * @param p_codigoCanal
   * @return typ_parametrizacionInicialSnp
   */

  FUNCTION fu_parametrizacionInicialSnp( p_codigoPersona         IN VARCHAR2,
                                         p_codigoEmpresa IN VARCHAR2,
                                         p_codigoCanal  IN VARCHAR2)
                                         RETURN typ_parametrizacionInicialSnp ;

    /*
    Obtiene sipap Fu_transferenciaSipap
   * Carga de parámetros iniciales de fu_obtenerTransferenciaFutura
   * Obtiene Pago de SNP
   * @Fecha : 11-08-2015
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_modo
   * @param p_cuentaDebito
   * @param p_monedaCredito
   * @param p_montoCredito
   * @param p_montoCredito
   * @param p_cargos
   * @param p_cuentaCredito
   * @param p_codigoSwift
   * @param p_documentoCredito
   * @param p_codigoSwift
   * @param p_documentoCredito
   * @param p_nombreBeneficiario
   * @param p_direccionBeneficiario
   * @param p_tipoDocBeneficiario
   * @param p_numeroContrato
   * @param p_concepto
   * @param p_numeroIP
   * @param p_cotizacion
   * @param p_tipoMensaje
   * @param p_matricula
   * @param p_motivo
   * @return typ_transferenciasSnp
   */

   FUNCTION fu_transferenciaSnp( p_codigoPersona         IN VARCHAR2,
                                 p_codigoEmpresa IN VARCHAR2,
                                 p_codigoCanal    IN VARCHAR2,
                                 p_modo           IN VARCHAR2,
                                 p_cuentaDebito   IN VARCHAR2,
                                 p_monedaCredito  IN VARCHAR2,
                                 p_montoCredito   IN NUMBER,
                                 p_fechaOperacion IN VARCHAR2,
                                 p_cargos         IN VARCHAR2,
                                 p_cuentaCredito  IN VARCHAR2,
                                 p_codigoSwift    IN VARCHAR2,
                                 p_documentoCredito   IN VARCHAR2,
                                 p_nombreBeneficiario IN VARCHAR2,
                                 p_direccionBeneficiario IN VARCHAR2,
                                 p_tipoDocBeneficiario   IN VARCHAR2,
                                 p_numeroContrato        IN NUMBER,
                                 p_concepto              IN VARCHAR2,
                                 p_numeroIP              IN VARCHAR2,
                                 p_cotizacion            IN NUMBER,
                                 p_tipoMensaje           IN VARCHAR2,
                                 p_matricula             IN VARCHAR2,
                                 p_motivo                IN VARCHAR2 default null,
                                 p_numeroreferencia      IN NUMBER   default null,
                                 p_claveTransaccional    IN VARCHAR2,
                                 p_userInfo              in paw_bem.typ_validarSesion,
                                 p_cantidadAutorizacion  in out number,
                                 p_sesion                IN VARCHAR2,
                                 p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null,
                                 p_alias                 IN VARCHAR2 default null) RETURN typ_transferenciasSnp;



   /**
   * Obtener detalle de transferencia de SNP
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_numeroReferencia
   * @return typ_detalleTransferenciaSnp
   */

   /*FUNCTION fu_obtenerdetalleTransfSnp( p_codigoPersona         IN VARCHAR2,
                                       p_codigoEmpresa IN VARCHAR2,
                                       p_codigoCanal      IN VARCHAR2,
                                       p_numeroReferencia IN NUMBER)
     RETURN typ_detalleTransferenciaSnp;
*/
    /**
   * @param p_nro_referencia
   */
   FUNCTION lf_ver_snp_movimiento(p_nro_referencia in ge_snp_transferencias.nro_referencia%type)
     RETURN VARCHAR2;

     /**
   * @param p_observacion
   */
    FUNCTION lf_obt_nro_referencia(p_observacion in ge_snp_transferencias.observacion%type)
     RETURN VARCHAR2;

    /**
   * @param p_nro_ref_externa
   * @param p_nro_cta_solicitante
   * @param p_cod_swi_pte_solicitante
   * @param p_nro_cta_beneficiario
   * @param p_cod_swi_pte_beneficiario
   * @param p_monto
   * @param p_cod_moneda
   * @param p_nro_referencia
   */
   FUNCTION lf_obt_nro_ref_externa( p_nro_ref_externa in ge_snp_transferencias.nro_ref_externa%type,
                                    p_nro_cta_solicitante in ge_snp_transferencias.nro_cta_solicitante%type,
                                    p_cod_swi_pte_solicitante in ge_snp_transferencias.cod_swi_pte_solicitante%type,
                                    p_nro_cta_beneficiario in ge_snp_transferencias.nro_cta_beneficiario%type,
                                    p_cod_swi_pte_beneficiario in ge_snp_transferencias.cod_swi_pte_beneficiario%type,
                                    p_monto in ge_snp_transferencias.monto%type,
                                    p_cod_moneda in ge_snp_transferencias.cod_moneda%type,
                                    p_nro_referencia in ge_snp_transferencias.nro_referencia%type
                               )
    RETURN VARCHAR2 ;

     /**
   Obtiene sipap fu_obtenerTransferenciaSnp
   * Carga de parámetros iniciales de fu_obtenerTransferenciaFutura
   * Obtiene Pago de Servicios
   * @Fecha : 15-09-2015
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_fechaDesde
   * @param p_fechaHasta
   * @return typ_respuestaTransferenciaSnp
   */
  /* FUNCTION fu_obtenerTransferenciaSnp( p_codigoPersona         IN VARCHAR2,
                                       p_codigoEmpresa IN VARCHAR2,
                                       p_codigoCanal  IN VARCHAR2,
                                       p_fechaDesde   IN VARCHAR2,
                                       p_fechaHasta   IN VARCHAR2)
                                       RETURN typ_respuestaTransferenciaSnp;
*/
   /**
   Obtiene sipap fu_obtenerTransferenciaFutura
   * @Fecha : 15-09-2015
   * @param p_sesion
   * @param p_codigoCanal
   * @return typ_transferenciaFuturaSnp
   */

 /*  FUNCTION fu_obtenerTransferenciaFutura(p_sesion   IN VARCHAR2,
                                          p_codigoCanal  IN VARCHAR2) RETURN typ_transferenciaFuturaSnp;*/


   /**
   Obtiene sipap fu_obtenerTransferenciaFutura
   * @Fecha : 15-09-2015
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_numeroReferencia
   * @return typ_cancelacionsnp
   */


/*   FUNCTION fu_cancelacionSnp(p_sesion IN VARCHAR2,
                                   p_codigoCanal  IN VARCHAR2,
                                   p_modo         IN VARCHAR2,
                                   p_numeroReferencia IN NUMBER) RETURN typ_cancelacionsnp;*/
   /**
   Obtiene sipap fu_frecuenteSnp
   * @Fecha : 15-09-2015
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_modo
   * @param p_cuentaDebito
   * @param p_monedaCredito
   * @param p_montoCredito
   * @param p_cuentaCredito
   * @param p_codigoSwift
   * @param p_documentoCredito
   * @param p_nombreBeneficiario
   * @param p_direccionBeneficiario
   * @param p_tipoDocBeneficiario
   * @param p_numeroPlanilla
   * @return typ_mensajeRespuesta
   */
  /* FUNCTION fu_frecuenteSnp (p_sesion   IN VARCHAR2,
                            p_codigoCanal  IN VARCHAR2,
                            p_modo         IN VARCHAR2,
                            p_cuentaDebito   IN VARCHAR2 DEFAULT NULL,
                            p_monedaCredito  IN VARCHAR2 DEFAULT NULL,
                            p_montoCredito   IN NUMBER DEFAULT NULL,
                            p_cuentaCredito  IN VARCHAR2 DEFAULT NULL,
                            p_codigoSwift    IN VARCHAR2 DEFAULT NULL,
                            p_documentoCredito   IN VARCHAR2 DEFAULT NULL,
                            p_nombreBeneficiario IN VARCHAR2 DEFAULT NULL,
                            p_direccionBeneficiario IN VARCHAR2 DEFAULT NULL,
                            p_tipoDocBeneficiario   IN VARCHAR2 DEFAULT NULL,
                            p_numeroPlanilla        IN NUMBER DEFAULT 0) RETURN typ_mensajeRespuesta ;*/



   /**
   Obtiene parametros Bancard
   * @Fecha : 19-10-2015
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_tipoOperacion
   * @param p_tipoSolicitud
   * @return typ_parametrosBancard
   */

   FUNCTION fu_parametrosBancard(p_sesion        IN VARCHAR2,
                                p_codigoCanal   IN VARCHAR2,
                                p_tipoOperacion IN NUMBER,
                                p_tipoSolicitud IN NUMBER
                                )
    RETURN typ_parametrosBancard;


   /**
    Obtiene parametros Bancos
    * @Fecha : 28-10-2015
    * @param p_sesion
    * @param p_codigoCanal
    * @return typ_bancos
    */
/*
    FUNCTION Fu_obtenerBancos(p_sesion      IN VARCHAR2,
                             p_codigoCanal IN VARCHAR2) RETURN typ_bancos;*/

   /**
    Obtiene parametros Tipos Documentos
    * @Fecha : 28-10-2015
    * @param p_sesion
    * @param p_codigoCanal
    * @return typ_tipoDocumentos
    */

   FUNCTION Fu_obtenerTipoDocumentos(p_sesion      IN VARCHAR2,
                                     p_codigoCanal IN VARCHAR2)
     RETURN typ_tipoDocumentos;

   /**
    Obtiene parámetros Modalidad de Solicitudes
    * @Fecha : 28-10-2015
    * @param p_sesion
    * @param p_codigoCanal
    * @param p_codigoCanalp_tipo
    * @return typ_modalSolicitud
    */
   FUNCTION Fu_obtenerModalSolicitud(p_sesion      IN VARCHAR2,
                                      p_codigoCanal IN VARCHAR2,
                                      p_tipo        IN VARCHAR2)
     RETURN typ_modalSolicitud;

   /**
    Registra una solicitud
    * @Fecha : 28-10-2015
    * @param p_sesion
    * @param p_codigoCanal
    * @param p_cabeceraSolicitud
    * @return typ_cabecerasolicitud
    */
  /* FUNCTION fu_registrarSolicitud(p_sesion           IN VARCHAR2,
                                  p_codigoCanal       IN VARCHAR2,
                                  p_cabeceraSolicitud IN typ_cabecerasolicitud)
     RETURN typ_cabecerasolicitud;*/

  /**
    Consulta de solicitudes
    * @Fecha : 02-11-2015
    * @param p_sesion
    * @param p_codigoCanal
    * @param p_nro_sol_desde
    * @param p_nro_sol_hasta
    * @param p_fec_sol_desde
    * @param p_fec_sol_hasta
    * @param p_estado
    * @return typ_solicitudes
    */
  /* FUNCTION fu_obtenerSolicitudes(p_sesion           IN VARCHAR2,
                                p_codigoCanal       IN VARCHAR2,
                                p_nro_sol_desde     IN VARCHAR2,
                                p_nro_sol_hasta     IN VARCHAR2,
                                p_fec_sol_desde     IN VARCHAR2,
                                p_fec_sol_hasta     IN VARCHAR2,
                                p_estado            IN VARCHAR2)
     RETURN typ_solicitudes;*/

   /**
   Administracion Datos
   * @Fecha : 20-11-2015
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_typ_actualizacionDatos
   * @return typ_administracionDatos
    */
/*   FUNCTION fu_administracionDatos(p_sesion                 IN VARCHAR2,
                                   p_codigoCanal            IN VARCHAR2,
                                   p_modo                   IN VARCHAR2,
                                   p_typ_actualizacionDatos IN typ_actualizacionDatos)
     RETURN typ_administracionDatos;*/

   /**
       Obtener Barrios
       * @Fecha : 20-11-2015
       * @param p_sesion
       * @param p_codigoCanal
       * @param p_codigoCiudad
       * @return typ_barrios
        */

  /* FUNCTION fu_obtenerBarrios(p_sesion       IN VARCHAR2,
                              p_codigoCanal  IN VARCHAR2,
                              p_codigoCiudad IN VARCHAR2,
                              p_codigoPais  IN VARCHAR2)
     RETURN typ_barrios;*/

   /**
       Obtener Ciudades
       * @Fecha : 20-11-2015
       * @param p_sesion
       * @param p_codigoCanal
       * @param p_codigoPais
       * @return typ_ciudades
        */

  /* FUNCTION Fu_obtenerCiudades(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_codigoPais  IN VARCHAR2)
     RETURN typ_ciudades;*/


   /**
      Obtener Cargar transferencias
      * @Fecha : 23-11-2015
      * @param p_sesion
      * @param p_codigoCanal
      * @param p_modo
      * @param p_cuentaDebito
      * @param p_monedaCredito
      * @param p_montoCredito
      * @param p_cuentaCredito
      * @param p_documentoCredito
      * @param p_nombreBeneficiario
      * @param p_direccionBeneficiario
      * @param p_tipoDocBeneficiario
      * @param p_numeroTransferencia
      * @return typ_mensajeRespuesta
      */

  /* FUNCTION fu_cargarTransferencias(p_sesion                 IN VARCHAR2,
                                     p_codigoCanal           IN VARCHAR2,
                                     p_modo                  IN VARCHAR2,
                                     p_cuentaDebito          IN VARCHAR2 DEFAULT NULL,
                                     p_monedaCredito         IN VARCHAR2 DEFAULT NULL,
                                     p_montoCredito          IN NUMBER DEFAULT NULL,
                                     p_cuentaCredito         IN VARCHAR2 DEFAULT NULL,
                                     p_documentoCredito      IN VARCHAR2 DEFAULT NULL,
                                     p_nombreBeneficiario    IN VARCHAR2 DEFAULT NULL,
                                     p_direccionBeneficiario IN VARCHAR2 DEFAULT NULL,
                                     p_tipoDocBeneficiario   IN VARCHAR2 DEFAULT NULL,
                                     p_numeroTransferencia   IN NUMBER DEFAULT 0)
      RETURN typ_mensajeRespuesta;*/


   /**
    Obtener Obtener transferencias
    * @Fecha : 23-11-2015
    * @param p_sesion
    * @param p_codigoCanal
    * @return typ_TransFrecuentes
    */

   /*FUNCTION fu_obtenerTransferencias(p_sesion      IN VARCHAR2,
                                     p_codigoCanal IN VARCHAR2)
      RETURN typ_TransFrecuentes;*/

   /**
    Obtener Obtener Descripción de Cuentas
    * @Fecha : 26-11-2015
    * @param p_numeroCuenta
    * @param p_tipoDocumento
    * @param p_numeroDocumento
    */
   FUNCTION fu_obtenerDesCuenta(p_numeroCuenta in varchar2,
                                p_tipoDocumento in varchar2,
                                p_numeroDocumento in varchar2)
       RETURN VARCHAR2;
   /**
    Obtener Obtener Código Ente
   */
   FUNCTION lf_obt_cod_entidad RETURN VARCHAR2;

   /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_nroCuentaEspecifica
   * @param p_nroPagina
   * @param p_cantItemsPagina
   * @return typ_detalleMovimientos
   */
  /* FUNCTION fu_obtenerMovimientosPrestamos(p_sesion              IN VARCHAR2,
                                           p_codCanal            IN VARCHAR2,
                                           p_nroCuentaEspecifica IN VARCHAR2,
                                           p_nroPagina           IN NUMBER DEFAULT NULL,
                                           p_cantItemsPagina     IN NUMBER DEFAULT NULL) RETURN typ_detalleMovimientos;*/


  /**
   * @param p_sesion
   * @param p_codCanal
   * @param p_numeroTarjeta
   * @param p_mes
   * @param p_anho
   * @parama p_tipoExtracto
   * @return typ_detalleMovimientos
   */
   /*FUNCTION fu_obtenerMovimientosTarjetas(p_sesion            IN VARCHAR2,
                                           p_codigoCanal       IN VARCHAR2,
                                           p_numeroTarjeta     IN VARCHAR2,
                                           p_mes               IN VARCHAR2,
                                           p_anho              IN VARCHAR2,
                                           p_tipoExtracto      IN VARCHAR2) RETURN typ_movimientosTarjeta;*/


  /**
   * @param p_codigoCanal
   * @param p_nroDocumento
   * @param p_tipoDocumento
   * @param p_codigoPais
   * @parama p_nombre
   * @parama p_apellido
   * @parama p_tipo
   * @parama p_codSexo
   * @parama p_fechaNacimiento
   * @parama p_direccionParticular
   * @parama p_codigoCiudad
   * @parama p_codigoBarrio
   * @parama p_nroVivienda
   * @parama p_observacionVivienda
   * @parama p_telefono
   * @parama p_area
   * @parama p_tipoLinea
   * @parama p_latitud
   * @parama p_longitud
   * @parama p_estadoClave
   * @parama p_tipoClave
   * @parama p_correoElectronico
   * @return typ_altaPersona
   */
  /* FUNCTION fu_altaPersona(p_codigoCanal         IN VARCHAR2,
                            p_nroDocumento        IN VARCHAR2,
                            p_tipoDocumento       IN VARCHAR2,
                            p_codigoPais          IN VARCHAR2,
                            p_nombre              IN VARCHAR2,
                            p_apellido            IN VARCHAR2,
                            p_tipo                IN VARCHAR2,
                            p_codSexo             IN VARCHAR2,
                            p_fechaNacimiento     IN VARCHAR2,
                            p_direccionParticular IN VARCHAR2,
                            p_codigoCiudad        IN NUMBER,
                            p_codigoBarrio        IN NUMBER,
                            p_nroVivienda         IN VARCHAR2,
                            p_observacionVivienda IN VARCHAR2,
                            p_telefono            IN VARCHAR2,
                            p_area                IN VARCHAR2,
                            p_tipoLinea           IN VARCHAR2,
                            p_latitud             IN VARCHAR2,
                            p_longitud            IN VARCHAR2,
                            p_estadoClave         IN VARCHAR2,
                            p_tipoClave           IN VARCHAR2,
                            p_correoElectronico   IN VARCHAR2
                         ) RETURN typ_altaPersona;*/




/*    FUNCTION fu_registrarDatosPersonales(p_sesion       IN VARCHAR2,
                                  p_codigoCanal  IN VARCHAR2,
                                  p_modo         IN VARCHAR2,
                                  p_typ_actualizacionDatos IN typ_administracionDatos)

    RETURN typ_administracionDatos;*/

   /**
   * @param p_sesion
   * @param p_codigoCanal
   * @param p_ann
   *@return p_semester
    */
    /*FUNCTION fu_informeSemestral (p_sesion        IN VARCHAR2,
                                  p_codigoCanal   IN VARCHAR2,
                                  p_ann           IN VARCHAR2,
                                  p_semester      IN VARCHAR2) RETURN typ_movimientosSemestral;*/

    FUNCTION fu_obtenerCuponesCda(p_sesion      IN VARCHAR2,
                                  p_codCanal    IN VARCHAR2,
                                  p_nroCda      IN VARCHAR2) RETURN typ_cuponesCda;

    FUNCTION fu_obtenerCliente(p_codPersona in varchar2, p_codEmpresa in varchar2)
    return typ_clientefielco;

    FUNCTION fu_obtenerClienteCuenta(p_nroCuenta in varchar2, p_tipoDocumento in number, p_nroDocumento in varchar2)
    return typ_clientefielco;

    FUNCTION fu_obtenerClienteDocumento(p_tipoDocumento in number, p_nroDocumento in varchar2)
    return typ_clientefielco;

    procedure lp_env_tra_notificacion(p_cod_persona in ba_personas.cod_persona%type,
                                   p_tip_producto in ge_mai_onb_templates.tip_producto%type,
                                   p_inf_json in ba_env_correos.parametros%type,
                                   p_tip_mensaje in bw_tip_mensajes.cod_tip_mensaje%type,
                                   p_retorno OUT typ_mensajerespuesta);
   FUNCTION fu_obt_hora(p_ind_usuario number) return varchar2;

   /** Crea la sesion de un usuario, valida la clave del mismo.
   * @param p_password Clave del Usuario
   * @param p_dato Informacion del usuario, puede ser Documento, Pasaporte, RUC, Nro de Cuenta, codigo de cliente o Nro de Tarjeta de Credito
   * @param p_tipoDato Indica el tipo de dato
   * @param p_nroDocEmpresa Informacion de la empresa, puede ser RUC, codigo de persona
   * @param p_tipoDocEmpresa Indica el tipo de dato de la empresa
   * @param p_codCanal Indica el canal
   * @return Informacion sobre el resultado del inicio de sesion
   */
   FUNCTION fu_iniciarSesion(p_password       IN VARCHAR2,
                             p_dato           IN VARCHAR2,
                             p_tipoDato       IN VARCHAR2,
                             p_nroDocEmpresa  IN VARCHAR2,
                             p_tipoDocEmpresa IN VARCHAR2,
                             p_codCanal       IN VARCHAR2) RETURN typ_iniciarsesion;
   FUNCTION depurarNumerico(p_string IN VARCHAR2, maxLength IN NUMBER) RETURN VARCHAR2;
   /** Verifica la validez de una sesión obtenida previamente de fu_iniciarSesion
    *
    * @param p_sesionUsuario Identificador de sesión a ser verificado
    * @param p_codCanal Identificador del canal para el cual la sesión fue obtenida
    * @return retorna Información de la sesión o error si no pudo comprobarse su validez
   */
   FUNCTION fu_validarSesion(p_sesionUsuario IN VARCHAR2,
                             p_codCanal      IN VARCHAR2,
                             p_validar       IN VARCHAR DEFAULT 'S') RETURN typ_validarSesion;
   PROCEDURE pr_mensajeUsuario(mensaje IN VARCHAR2, nombreMensaje OUT VARCHAR2, descripcionMensaje OUT VARCHAR2, error OUT VARCHAR2);

    /**Elimina la sesion del usuario
   * @param p_sesion Código de la sesión
   * @return Resultado de la operacion
   */
   FUNCTION fu_eliminarSesion(p_sesionUsuario IN VARCHAR2) RETURN typ_mensajeRespuesta;

    /**Cambia la clave de acceso
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_claveAntigua Clave anterior
   * @param p_claveNueva Clave nueva
   * @return Resultado de la operacion
   */
   FUNCTION fu_cambiarClaveAcceso(p_sesion      IN VARCHAR2,
                                  p_codCanal    IN VARCHAR2,
                                  p_claveActual IN VARCHAR2,
                                  p_claveNueva  IN VARCHAR2) RETURN typ_mensajeRespuesta;
   FUNCTION fu_obtenerMovimientos(p_sesion              IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                  p_cantDias            IN NUMBER DEFAULT NULL) RETURN typ_detalleMovimientos;

   FUNCTION fu_obtenerMovimientos_por_fec(p_sesion              IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                  p_fec_inicio          IN DATE DEFAULT NULL,
                                  p_fec_fin             IN DATE DEFAULT NULL) RETURN typ_detalleMovimientos;


   FUNCTION fu_obtComprobanteMovimiento(p_sesion       IN VARCHAR2,
                                        p_codCanal     IN VARCHAR2,
                                        p_nroCuenta    IN VARCHAR2, --nro de cuenta o tarjeta
                                        p_fecha        IN DATE,
                                        p_nroDocumento IN NUMBER,
                                        p_monto        IN NUMBER,
                                        p_tipo         IN VARCHAR2,
                                        p_factura      IN VARCHAR2,
                                        p_nroSecuencia IN NUMBER DEFAULT NULL,
                                        p_hora         IN VARCHAR2 DEFAULT NULL) RETURN typ_comprobanteMovimiento;
  /* FUNCTION fu_obtenerOficinas RETURN typ_informacionOficinas;*/
   FUNCTION fu_obtenerCotizacion RETURN typ_detallesCotizacion;
   /**
   * Historico de Cotizaciones
   * @Creado por: Fermín Giménez
   * @Fecha : 17-12-2012
   */
   FUNCTION fu_obtenerHisCotizaciones(p_sesion            IN VARCHAR2,
                                      p_codigoCanal       IN VARCHAR2,
                                      p_codigoMoneda      IN VARCHAR2,
                                      p_diasHistorico     IN NUMBER
                                     )RETURN typ_respuestaHisCotizaciones;

     /**
    * fu_obtenerPermisosUsuario, Obtiene los permisos que posee un usuario

    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @return Lista de permisos
   */
   FUNCTION fu_obtenerPermisos(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2) RETURN typ_permisosUsuarios;

   /** Verifica la validez de una sesion obtenida previamente de fu_iniciarSesion
   * @param p_sesion identificador de sesion a ser verificado
   * @param p_codCanal identificador del Canal para el cual la sesion fue obtenida
   * @return retorna información de la actividad de sesion o error si no pudo comprobarse su validez
   */
   FUNCTION fu_validarActividad(p_sesion   IN VARCHAR2,
                                p_codCanal IN VARCHAR2) RETURN typ_mensajerespuesta;

    FUNCTION fu_datoCliente(p_codPersona         IN VARCHAR2,
                            p_codEmpresa        IN VARCHAR2,
                            p_codigoCanal       IN VARCHAR2,
                            p_direccion         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B. Debe tener mayor a 10 caracteres
                            p_codCiudad         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codBarrio         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codNumero         IN VARCHAR2 DEFAULT NULL,--numero de casa
                            p_codEdificio       IN VARCHAR2 DEFAULT NULL,
                            p_codPiso           IN VARCHAR2 DEFAULT NULL,
                            p_codDepartamento   IN VARCHAR2 DEFAULT NULL,
                            p_codigoArea        IN VARCHAR2 DEFAULT NULL,
                            p_telefono          IN VARCHAR2 DEFAULT NULL,
                            p_email             IN VARCHAR2 DEFAULT NULL,
                            p_modo              IN VARCHAR2, --Modos-> D: Consulta Detalles, V: Verificar, C: Confirmar
                            p_tipoSolicitud     IN VARCHAR2 DEFAULT NULL--Solo puede ser nulo en el Modo D. B : Base, E; Email, C: Celular, EC: Email Confirmado, CC: Celular Confirmado ATM, CR: Celular Rechazado ATM
                            )
                            RETURN typ_datosCliente;

    /**
   * Obtiene el último monto acreditado al beneficiario.
   * @p_nro_cuenta Número de cuenta del beneficiario
   * @p_cod_ente Ente a la cual pertenece el beneficirio
   * @p_fec Ultima fecha de acreditación de salario.
   **/
   FUNCTION fu_obt_ult_salario(p_nro_cuenta IN VARCHAR2, p_cod_ente IN NUMBER, p_fec IN DATE) RETURN NUMBER ;

    /**
   * Obtiene listado de beneficiarios o histórico de pago de salarios.
   * @p_sesion Código de la sesión
   * @p_codigoCanal Código de canal
   * @p_fec_ini Fecha inicio
   * @p_fec_fin Fecha fin
   * @p_nro_cuenta Nro. de cuenta débito del beneficiario
   * @p_beneficiario Nombre del beneficiario
   * @p_parametro default 'H' visualización de histórico ó 'B' para ver listado de beneficiarios
   **/
   FUNCTION fu_obtenerHisPagoNomina(p_sesion        IN VARCHAR2,
                                    p_codigoCanal   IN VARCHAR2,
                                    p_fec_ini       IN DATE DEFAULT NULL,
                                    p_fec_fin       IN DATE DEFAULT NULL,
                                    p_nro_cuenta    IN VARCHAR2 DEFAULT NULL,
                                    p_beneficiario  IN VARCHAR2 DEFAULT NULL,
                                    p_parametro     IN VARCHAR2 DEFAULT 'H') RETURN typ_pagosalarios;--NVB-2232

   FUNCTION fu_generarBitacora(error in varchar2, nombreRespuesta in varchar2 ,descripcionRespuesta in varchar2, mensajesAdicionales in varchar2  := NULL ) RETURN VARCHAR2 ;

   FUNCTION fu_obtenerDetalleCuentas(p_sesion              IN VARCHAR2,
                                     p_codCanal            IN VARCHAR2,
                                     p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDetalleCuentas;


   /**
    * fu_obtenerAutorizacionesDelDia, encargada de obtener los movimienos de la banca empresa del dia
    *
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @param p_estado Si se recibe, se consulta movimientos de la banca empresa segun el estado,
    *                 A-Anulados, P-Pendientes, C-Confirmados.
    *                 Si no se recibe el parametro, devuelve todos los estados.
    * @param p_permiso Indica si debe controlar el permiso por mensaje de la persona
    * @param p_rango rango de dias a considerar
    * @param p_canItems Cantidad de items a desplegar
    * @param p_nroPagina Numero de pagina a desplegar
    * @return Lista de autorizaciones con sus estados
    */
   FUNCTION fu_obtenerAutorizacionesDelDia(p_sesion      IN VARCHAR2,
                                           p_codigoCanal IN VARCHAR2,
                                           p_estado      IN VARCHAR2 DEFAULT NULL,
                                           p_permiso     IN VARCHAR2 DEFAULT 'N',
                                           p_rango       IN NUMBER DEFAULT 0,
                                           p_canItems    IN NUMBER DEFAULT NULL,
                                           p_nroPagina   IN NUMBER DEFAULT NULL ) RETURN typ_autorizacionesDelDia;

    FUNCTION fu_obtenerResumenCuentas(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_filtro   IN VARCHAR2 DEFAULT NULL) RETURN typ_resumenCuentas;

    FUNCTION fu_obtenerConfiguracion(p_parametro IN VARCHAR2,
                                    p_cod_modulo IN NUMBER DEFAULT NULL,
                                    p_cod_modalidad IN NUMBER DEFAULT NULL,
                                    p_cod_moneda IN VARCHAR2 DEFAULT NULL,
                                    p_cod_oficina IN NUMBER  DEFAULT NULL,
                                    p_cod_sub_modalidad IN VARCHAR2 DEFAULT NULL) RETURN typ_parametrosConfiguracion;
    /**
       * Obtiene los CDAs del cliente con los detalles de los cupones
       * @param p_sesion sesion del cliente
       * @param p_codCanal codigo del canal
       * @param p_nroCuentaEspecifica numero de cuenta del cda
      */
      FUNCTION fu_obt_cda_cupones(p_sesion    IN VARCHAR2,
         p_codCanal     IN VARCHAR2, p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDatosCda;
   /**
   * Permite recuperar/actualizar datos del cliente segun el modo en que se utilice.
   */
   FUNCTION fu_datosCliente(p_sesion            IN VARCHAR2,
                            p_codigoCanal       IN VARCHAR2,
                            p_direccion         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B. Debe tener mayor a 10 caracteres
                            p_codCiudad         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codBarrio         IN VARCHAR2 DEFAULT NULL,--No debe ser nulo para p_tipoSolicitud = B.
                            p_codNumero         IN VARCHAR2 DEFAULT NULL,--numero de casa
                            p_codEdificio       IN VARCHAR2 DEFAULT NULL,
                            p_codPiso           IN VARCHAR2 DEFAULT NULL,
                            p_codDepartamento   IN VARCHAR2 DEFAULT NULL,
                            p_codigoArea        IN VARCHAR2 DEFAULT NULL,
                            p_telefono          IN VARCHAR2 DEFAULT NULL,
                            p_email             IN VARCHAR2 DEFAULT NULL,
                            p_modo              IN VARCHAR2, --Modos-> D: Consulta Detalles, V: Verificar, C: Confirmar
                            p_tipoSolicitud     IN VARCHAR2 DEFAULT NULL--Solo puede ser nulo en el Modo D. B : Base, E; Email, C: Celular, EC: Email Confirmado, CC: Celular Confirmado ATM, CR: Celular Rechazado ATM
                            )
                            RETURN typ_datosCliente;

  /**
    * Obtiene el plan de pagos del nro de prestamo recibido como parametro
    * @param p_sesion sesion del cliente
    * @param p_codCanal codigo del canal
    * @param p_nroPrestamo nro del prestamo
    * @return plan de pagos del prestamo
   */
   FUNCTION fu_obtTotCuoPrestamo(p_sesion      IN VARCHAR2,
                                     p_codCanal    IN VARCHAR2,
                                     p_nroPrestamo IN VARCHAR2) RETURN typ_obtCuotasPrestamo;

     /**
    * Obtiene liquidacion de prestamos para reporte
    * @p_cod_canal canal desde el cual se hace la solicitud
    * @p_nro_cuenta cuenta correspondiente al prestamo
    **/
    FUNCTION fu_obt_liq_prestamo(p_sesion IN VARCHAR2,
                             p_cod_canal IN VARCHAR2,
                             p_nro_cuenta IN VARCHAR2) RETURN typ_infoLiquidacionPrestamo;
    -- Obtencion de feriados
   FUNCTION fu_obtenerFeriados(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_fechaInicio   IN DATE,
                               p_fechaFin      IN DATE) RETURN typ_listaFeriados;

   PROCEDURE pr_con_mon_a_moneda(p_cod_mon_original IN ba_monedas.cod_moneda%TYPE,
                                 p_cod_mon_destino  IN ba_monedas.cod_moneda%TYPE,
                                 p_mto_mon_original IN NUMBER,
                                 p_mto_mon_destino  OUT NUMBER,
                                 p_cot_mon_original IN OUT NUMBER,
                                 p_cot_mon_destino  IN OUT NUMBER,
                                 p_interbancaria    IN VARCHAR2 DEFAULT NULL);


     -- obtiene el total de límite máximo operativo por mensaje
   FUNCTION fu_obtenerLimite(p_usuario                IN typ_validarSesion,
                             p_codigoTipoMensaje      IN VARCHAR2,
                             p_codigoPersona          IN VARCHAR2,
                             p_numeroCuenta           IN VARCHAR2,
                             p_codigoMoneda           IN VARCHAR2,
                             p_codigoTransaccion      IN NUMBER,
                             p_codigoTransaccionPadre IN NUMBER,
                             p_monto                  IN NUMBER,
                             p_modo                   IN VARCHAR2,
                             p_codigoEnte             IN NUMBER DEFAULT NULL,
                             p_sesion                 IN VARCHAR2 DEFAULT NULL,
                             p_numeroIp               IN VARCHAR2 DEFAULT NULL,
                             p_cantidad               IN NUMBER DEFAULT 1)
                             RETURN typ_respuestaLimite;

   FUNCTION fu_transferenciasPropias(p_sesion             IN VARCHAR2,
                                     p_codCanal           IN VARCHAR2,
                                     p_nroCtaDebito       IN VARCHAR2,
                                     p_monto              IN NUMBER,
                                     p_nroCtaCredito      IN VARCHAR2,
                                     p_modo               IN VARCHAR2,
                                     p_concepto           IN VARCHAR2,
                                     p_cotDebito          IN NUMBER,
                                     p_cotCredito         IN NUMBER,
                                     p_mtoCredito         IN NUMBER,
                                     p_claveTransaccional IN VARCHAR2,
                                     p_claveToken         IN VARCHAR2,
                                     p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null) RETURN typ_transferencia_hb;

   FUNCTION fu_transferenciasTerceros(p_sesion             IN VARCHAR2,
                                      p_codCanal           IN VARCHAR2,
                                      p_nroCtaDebito       IN VARCHAR2,
                                      p_monto              IN NUMBER,
                                      p_nroCtaCredito      IN VARCHAR2,
              p_codMonCredito      IN VARCHAR2,
                                      p_modo               IN VARCHAR2,
                                      p_nroDocCredito      IN VARCHAR2,
                                      p_concepto           IN VARCHAR2,
                                      p_nroContrato       IN NUMBER,
                                      p_claveTransaccional IN VARCHAR2,
                                      p_claveToken         IN VARCHAR2,
                                      p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null) RETURN typ_transferencia_hb;
  FUNCTION depurarTextos_dev(p_string  IN VARCHAR2, maxLength IN NUMBER, p_documento IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2;
  /**
    * fu_autorizarOperacion, encargada de detallar, autorizar o rechazar un
    * movimiento
    *
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @param p_modo Modo de operacion, D-Detalle, A-Autorizar, R-Rechazar, I-Imprimir
    * @param p_numeroDocumento Numero de documento de la operacion
    * @param p_comentario Comentario del autorizador
    * @param p_claveTransaccional Dependiendo de la configuración de limites operativos
    * @param p_claveToken Dependiendo de la configuración de límites operativos
    * @return Resultado de la operacion
   */
  FUNCTION fu_autorizarOperacion(p_sesion             IN VARCHAR2,
                                  p_codigoCanal        IN VARCHAR2,
                                  p_modo               IN VARCHAR2,
                                  p_numeroDocumento    IN NUMBER,
                                  p_comentario         IN VARCHAR2,
                                  p_online             IN VARCHAR2,
                                  p_claveTransaccional IN VARCHAR2,
                                  p_claveToken         IN VARCHAR2) RETURN typ_autorizaOperacion;
  FUNCTION fu_transferencia_dev(p_sesion             IN VARCHAR2,
                             p_codCanal           IN VARCHAR2,
                             p_nroCtaDebito       IN VARCHAR2,
                             p_montoCredito       IN NUMBER,
                             p_nroCtaCredito      IN VARCHAR2,
                             p_codMonCredito      IN VARCHAR2,
                             p_modo               IN VARCHAR2,
                             p_nroDocCredito      IN VARCHAR2,
                             p_concepto           IN VARCHAR2,
                             p_nroContrato        IN NUMBER,
                             p_nombreBeneficiario IN VARCHAR2,
                             p_claveTransaccional IN VARCHAR2,
                             p_claveToken         IN VARCHAR2) RETURN typ_transferencia_hb;

  
   FUNCTION fu_pagoTarjetaCredito/*_dev*/(p_sesion                 IN VARCHAR2,--NVB-2461
                                  p_codCanal               IN VARCHAR2,
                                  p_nroTarjetaCredito      IN VARCHAR2,
                                  p_cuentaDebito           IN VARCHAR2,
                                  p_modo                   IN VARCHAR2,
                                  p_nroSobre               IN NUMBER,
                                  p_importeEfectivo        IN NUMBER,
                                  p_importeChequeBanco     IN NUMBER,
                                  p_importeChequeOtroBanco IN NUMBER,
                                  p_importeDebito          IN NUMBER,
                                  p_totalPago              IN NUMBER,
                                  p_claveToken             IN VARCHAR2,
                                  p_claveTransaccional     IN VARCHAR2,
                                  p_pagoOnline             IN VARCHAR2,
                                  p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null) RETURN typ_pagoTarjetaCredito/*_hb*/ ;
   FUNCTION fu_pagoAduana(p_sesion             IN VARCHAR2,
                          p_codCanal           IN VARCHAR2,
                          p_cuentaDebito       IN VARCHAR2,
                          p_metodo             IN VARCHAR2,
                          p_monto              IN VARCHAR2,
                          p_operacion          IN VARCHAR2,
                          p_campo1             IN VARCHAR2,
                          p_campo2             IN VARCHAR2,
                          p_nombreImportador   IN VARCHAR2,
                          p_nombreDespachante  IN VARCHAR2,
                          p_claveToken         IN VARCHAR2,
                          p_claveTransaccional IN VARCHAR2) RETURN typ_pagoAduana;

  FUNCTION fu_solicitarChequera(p_sesion             IN VARCHAR2,
                                 p_codCanal           IN VARCHAR2,
                                 p_nroCuenta          IN VARCHAR2,
                                 p_codigoTipoChequera IN VARCHAR2,
                                 p_canHojas           IN NUMBER,
                                 p_cantidadChequeras  IN NUMBER,
                                 p_modo               IN VARCHAR2 DEFAULT NULL,
                                 p_ofi_retencion      IN NUMBER DEFAULT NULL,
                                 p_tip_solicitud      IN VARCHAR2 DEFAULT 'M',
                                 p_claveTransaccional IN VARCHAR2,
                                 p_claveToken         IN VARCHAR2) RETURN typ_mensajeResChequera;
  FUNCTION fu_transferenciaInterbancaria
   (
      p_sesion                    IN VARCHAR2,
      p_codigoCanal               IN VARCHAR2,
      p_modo                      IN VARCHAR2,
      p_codigoSwift               IN VARCHAR2,
      p_numeroCuentaCredito       IN VARCHAR2,
      p_numeroCuentaDebito        IN VARCHAR2,
      p_codigoMonedaCredito       IN VARCHAR2,
      p_montoCredito              IN NUMBER,
      p_fechaOperacion            IN DATE,
      p_cargos                    IN VARCHAR2,
      p_numeroDocumentoCredito    IN VARCHAR2,
      p_nombreBeneficiario        IN VARCHAR2,
      p_direccionBeneficiario     IN VARCHAR2,
      p_numeroContrato            IN NUMBER,
      p_concepto                  IN VARCHAR2,
      p_numeroIp                  IN VARCHAR2,
      p_tipoMensaje               IN VARCHAR2,
      p_tipoDocumentoBeneficiario IN NUMBER,
      p_numeroReferencia          IN NUMBER,
      p_montoDebito               IN NUMBER,
      p_cotizacionDebito          IN NUMBER,
      p_cotizacionCredito         IN NUMBER,
      p_claveToken                IN VARCHAR2,
      p_claveTransaccional        IN VARCHAR2,
      p_prioridad                 IN VARCHAR2,
      p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null,
      p_alias                 IN VARCHAR2 default null
   ) RETURN typ_transferenciaInterbancaria;

   FUNCTION fu_obtenerSnpHorarios(p_sesion IN VARCHAR2,p_codigoCanal in varchar2) RETURN typ_SnpPeriodos;
   FUNCTION fu_pagoServiciosWs(p_sesion             IN VARCHAR2,
                               p_codigoCanal        IN VARCHAR2,
                               p_modo               IN VARCHAR2,
                               p_cuentaDebito       IN VARCHAR2,
                               p_numeroIp           IN VARCHAR2,
                               p_sesionServicios    IN VARCHAR2,
                               p_servicio           IN VARCHAR2,
                               p_numeroTransaccion  varchar2,
                               p_numeroLote         varchar2,
                               p_terminal           varchar2,
                               p_moneda             NUMBER,
                               p_monto              NUMBER,
                               p_importeComision    NUMBER,
                               p_importeMora        NUMBER,
                               p_importeInteres     NUMBER,
                               p_claveTransaccional IN VARCHAR2,
                               p_claveToken         IN VARCHAR2,
                               p_tokenServicios     IN VARCHAR2,
                               p_proveedor          IN NUMBER,
                               p_extra              IN VARCHAR2)
    RETURN typ_pagoServiciosWs;

    FUNCTION fu_pagoSet(p_sesion              IN VARCHAR2,
                       p_codigoCanal         IN VARCHAR2,
                       p_modo                IN VARCHAR2,
                       p_cuentaDebito        IN VARCHAR2,
                       p_numeroTransaccion   IN VARCHAR2,
                       p_xml_boleta          IN VARCHAR2,
                       p_claveTransaccional  IN VARCHAR2,
                       p_claveToken          IN VARCHAR2) RETURN typ_pagoServiciosWs;

    FUNCTION fu_pagoBancardWs(p_sesion             IN VARCHAR2,
                             p_codigoCanal        IN VARCHAR2,
                             p_modo               IN VARCHAR2,
                             p_cuentaDebito       IN VARCHAR2,
                             p_numeroIp           IN VARCHAR2,
                             p_sesionServicios    IN VARCHAR2,
                             p_numeroTransaccion  VARCHAR2,
                             p_servicio           IN VARCHAR2,
                             p_terminal           VARCHAR2,
                             p_moneda             NUMBER,
                             p_monto              NUMBER,
                             p_importeComision    NUMBER,
                             p_claveTransaccional IN VARCHAR2,
                             p_claveToken         IN VARCHAR2,
                             p_tokenServicios     IN VARCHAR2,
                             p_proveedor          IN NUMBER,
                             p_extra              IN VARCHAR2) RETURN typ_pagoserviciosws;

  FUNCTION fu_pagoBancardPMWs(p_sesion             IN VARCHAR2,
                                p_codigoCanal        IN VARCHAR2,
                                p_modo               IN VARCHAR2,
                                p_cuentaDebito       IN VARCHAR2,
                                p_numeroIp           IN VARCHAR2,
                                p_sesionServicios    IN VARCHAR2,
                                p_numeroTransaccion  VARCHAR2,
                                p_servicio           IN VARCHAR2,
                                p_terminal           VARCHAR2,
                                p_moneda             NUMBER,
                                p_monto              NUMBER,
                                p_importeComision    NUMBER,
                                p_claveTransaccional IN VARCHAR2,
                                p_claveToken         IN VARCHAR2,
                                p_tokenServicios     IN VARCHAR2,
                                p_proveedor          IN NUMBER,
                                p_extra              IN VARCHAR2) RETURN typ_pagoserviciosws;

  FUNCTION fu_pagoServiciosEmp (p_sesion      IN VARCHAR2,
                                 p_codigoCanal IN VARCHAR2,
                                 p_modo        IN VARCHAR2,
                                 p_cuenta      IN VARCHAR2,
                                 p_moneda      IN NUMBER,
                                 p_monto       IN NUMBER,
                                 p_proveedor   IN NUMBER,
                                 p_numeroIp    IN VARCHAR2,
                                 p_claveTransaccional IN VARCHAR2,
                                 p_claveToken  IN VARCHAR2,
                                 p_identificador IN VARCHAR2 DEFAULT 'N'
                                 ) RETURN typ_pagoServicios;
    /**
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal
   * @p_relacion Relación con la cuenta
   * @return Lista de Tarjetas
   */
   FUNCTION fu_obtenerTarjetas(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_relacion    IN VARCHAR2 DEFAULT NULL) RETURN typ_resumentarjetas;
  /** Obtiene la lista de productos preaprobados del cliente
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @return Lista de productos preaprobados
   */
  FUNCTION fu_obtenerPreaprobados(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_listapreaprobado;

  FUNCTION fu_solicitudPreaprobados(p_sesion         IN VARCHAR2,
                                     p_codigoCanal    IN VARCHAR2,
                                     p_modo           IN VARCHAR2,
                                     p_codigoModulo   IN NUMBER,
                                     p_xmlData        IN VARCHAR2) RETURN typ_preaprobado;

  FUNCTION fu_val_sol_seguro(p_cod_canal      IN VARCHAR2,
                             p_cod_persona    IN VARCHAR2,
                             p_mto_asegurado  IN NUMBER,
                             p_cod_tip_seguro IN NUMBER,
                             p_mto_cuota      IN NUMBER,
                             p_cod_seguro     IN NUMBER) RETURN TYP_MENSAJERESPUESTA;

  FUNCTION fu_obt_edad(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN NUMBER;
  FUNCTION fu_obt_fec_nacimiento(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;
  FUNCTION fu_obtenerContratoCambio( p_sesion      IN VARCHAR2,
                                      p_codigoCanal IN VARCHAR2
                                    ) RETURN typ_respuestaContratoCambio;
  FUNCTION fu_extractoARequerimiento(  p_sesion             IN VARCHAR2,
                                        p_codCanal           IN VARCHAR2,
                                        p_nroCuenta          IN VARCHAR2,
                                        p_fechaHasta         IN DATE,
                                        p_claveToken         IN VARCHAR2,
                                        p_claveTransaccional IN VARCHAR2) RETURN typ_extracto_hb;
  FUNCTION fu_devolucionSpi(p_sesion              IN VARCHAR2,
                            p_codCanal          IN VARCHAR2,
                            p_modo                 IN VARCHAR2,
                            p_ref_tra_original     IN VARCHAR2,
                            p_mot_devol       IN VARCHAR2 DEFAULT NULL,
                            p_monto                IN NUMBER   DEFAULT NULL,
                            p_cod_solicitud        IN NUMBER   DEFAULT NULL,
                            p_claveTransaccional   IN VARCHAR2,
                            p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null
                            ) RETURN typ_devolucionSpi;
  FUNCTION fu_obtenerMovimientos_det(p_nro_cta  in varchar2,
                                     p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2)
    return TYP_OBTDETALLEMOVIMIENTOS;
  FUNCTION fu_obt_lista_spi(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
    return typ_transSpi;
  PROCEDURE lp_env_not_preaprobados(p_sesion        IN VARCHAR2,
                                    p_codCanal      IN VARCHAR2,
                                    p_monto       in pr_cta_prestamos.monto%type,
                                    p_can_cuotas  in pr_cta_prestamos.can_cuotas%type,
									p_tip_solicitud  IN varchar2, --BWP-491
                                    p_retorno     OUT typ_mensajerespuesta);



  FUNCTION fu_obt_nro_documento(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                p_tip_documento  in out ba_personas.cod_tip_documento%type)RETURN VARCHAR2;

  FUNCTION fu_obtMov_detalles(p_nro_cta       in VARCHAR2,
                                p_cod_persona in VARCHAR2,
                                p_fec_desde   in date,
                                p_fec_hasta   in date,
                                p_cant_desde  in number,
                                p_cant_hasta  in number,
                                p_sesion      in VARCHAR2,
                                p_codCanal    in VARCHAR2)
      return TYP_OBTDETALLEMOVIMIENTOS_HIS;
  FUNCTION fu_obt_lis_sol_spi(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
  return typ_LisSolicitudesSpi;
  FUNCTION fu_obt_lis_sol_dev(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
  return typ_LissoldevolucionesSpi;

    FUNCTION fu_obt_lis_sol_pag(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
  return typ_LisSolPagosSpi;

  FUNCTION fu_solicitudPagoSPI(p_sesion               in varchar2,
                               p_cod_canal            in varchar2,
                               p_modo                 in varchar2,
                               p_cod_moneda           in varchar2, --moneda
                               p_monto                in number,   --monto a solicitar
                               p_cta_sol              in varchar2, --cuenta solicitante
                               p_cta_rec              in varchar2, --cuenta receptora
                               p_tip_doc_rec          in varchar2, --tipo doc. del receptor
                               p_doc_rec              in varchar2, --documento del receptor
                               p_nom_rec              in varchar2, --nombre del receptor
                               p_bic_rec              in varchar2)  --cod. swift del receptor
                               return typ_solicitudPagoSpi;
  FUNCTION fu_SolicitudDevolucionSPI(p_sesion              IN VARCHAR2,
                            p_codCanal          IN VARCHAR2,
                            p_modo                 IN VARCHAR2,
                            p_ref_tra_original     IN VARCHAR2,
                            p_mot_devol       IN VARCHAR2 DEFAULT NULL,
                            p_monto                IN NUMBER   DEFAULT NULL,
                            p_cod_solicitud        IN NUMBER   DEFAULT NULL
                            ) RETURN typ_solicitudDevolucionSpi;
  FUNCTION fu_obt_lis_cas_spi(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2)
    return typ_LisAliasSpi;
    
  /*BWP-328 - glopez*/                           
  FUNCTION fu_aut_solicitud(p_sesion             IN VARCHAR2,
                            p_codCanal           IN VARCHAR2,
                            p_modo               IN VARCHAR2,
                            p_cod_solicitud      in ge_spi_solicitudes.cod_sol_spi%type,
                            p_monto              IN NUMBER   DEFAULT NULL,
                            p_claveTransaccional IN VARCHAR2)
                            return typ_aut_solicitud;
  /*BWP-331*/
  FUNCTION fu_rch_solicitud(p_sesion              in varchar2,
                            p_codCanal          in varchar2,
                            p_modo              in varchar2,
                            p_cod_solicitud     in ge_spi_solicitudes.cod_sol_spi%type,
                            p_cod_rechazo       in ge_spi_solicitudes.tip_rechazo%type)
                            return typ_aut_solicitud; 
                            
  FUNCTION fu_obtenerDetalleCuentas_bancard(p_sesion              IN VARCHAR2,
                                            p_codCanal            IN VARCHAR2,
                                            p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL)
                                            return typ_obtdetctas_hb_bancard;
                                            
 FUNCTION fu_solicitud_regcas (p_sesion     in varchar2,
                        p_codCanal          in varchar2,
                        p_modo              in varchar2  default 'A',
                        p_tip_ide_cli       in VARCHAR2,
                        p_val_ide_cli       in VARCHAR2,
                        p_tip_ide_alias     in VARCHAR2,
                        p_val_ide_alias     in VARCHAR2,
                        p_nro_cuenta          in VARCHAR2,
                        p_cta_defecto         in VARCHAR2,
                        p_tip_accion          in VARCHAR2) return typ_solicitudaltacas;
                        
  FUNCTION fu_eliminar_regcas(p_sesion        in varchar2,
                              p_codcanal      in varchar2,
                              p_modo          in varchar2 default 'A',
                              p_ali_record_id in varchar2,
                              p_cta_record_id in varchar2,
                              p_accion        in varchar2 default 'ELI') return typ_solicitudaltacas;
  
   FUNCTION fu_sol_con_cas(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_tip_consulta  IN VARCHAR2,
                            p_tip_identificador IN VARCHAR2,
                            p_val_identificador IN VARCHAR2) return typ_sol_con_cas;
                            
   FUNCTION fu_res_con_cas(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_nro_referencia IN VARCHAR2) return typ_res_con_cas;
							
    FUNCTION fu_Solicitud_EdiCAS(p_cli_recorid in varchar2,
                              p_cta_recorid in varchar2,
                              p_ali_recorid in varchar2,
                              p_accion      in varchar2,
                              p_canal       in VARCHAR2) return typ_solicitudPagoSpi;
   FUNCTION lf_obt_bco_snp_swift(p_cod_swift IN VARCHAR2) RETURN VARCHAR2;
    
   PROCEDURE lp_ins_databag( p_estado        IN VARCHAR2 DEFAULT 'P',
                             p_peticion      IN LONG DEFAULT NULL,
                             p_cod_entidad   IN VARCHAR2 DEFAULT NULL,
                             p_nro_cuenta    IN VARCHAR2 DEFAULT NULL,
                             p_cod_moneda    IN VARCHAR2 DEFAULT NULL,
                             p_monto         IN NUMBER DEFAULT NULL,
                             p_nro_operacion OUT INTEGER);
							 
   FUNCTION fu_val_arc_das(p_sesion                  IN VARCHAR2,
                            p_codmoneda              in ge_cuentas.cod_moneda%type,
                            p_codigoCanal            IN VARCHAR2,
                            p_codigoEnte             IN NUMBER,
                            p_parametros             IN CLOB,
                            p_cantCuentasParaCredito IN NUMBER,
                            p_canRegistrosLeidos     IN NUMBER) RETURN typ_val_das;--UES-618
                                
   FUNCTION fu_obtenerMovimientos_por_fec_ext(p_sesion              IN VARCHAR2,
                                              p_codCanal            IN VARCHAR2,
                                              p_nroCuentaEspecifica IN VARCHAR2,
                                              p_nroPagina           IN NUMBER DEFAULT NULL,
                                              p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                              p_fec_inicio          IN DATE DEFAULT NULL,
                                              p_fec_fin             IN DATE DEFAULT NULL) RETURN typ_detalleMovimientos;

   PROCEDURE pr_set_aut_operacion (p_aut_operacion in boolean);
   
   PROCEDURE pr_set_can_aut_requeridas (p_can_aut_requeridas in NUMBER);

END paw_bem;
/
