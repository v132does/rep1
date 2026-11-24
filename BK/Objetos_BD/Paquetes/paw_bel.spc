CREATE OR REPLACE PACKAGE IT.PAW_BEL IS
  v_patrocinador     varchar2(1) :='N'; 
  v_tra_spi          varchar2(1) :='N';
  v_tra_spi_ind      varchar2(1) :='N';
  C_COD_HOMEBANKING  CONSTANT VARCHAR2(5)  := '999';
  v_mod_estado       ba_modulos.estado%TYPE;
  v_cod_operacion    varchar2(3);   -- codigo de la operacion recibida
  v_alias            varchar2(50); -- SPI fase 2

   /** 
   *typ_validarSesion
   *  Tipo  privado utilizado para retornar el estado de
   *    validez de una sesion ademas de informacion relacionada
   *    a la sesion
   */
   TYPE typ_validarSesion IS RECORD(
      error                VARCHAR2(1), -- hubo Error?
      nombreRespuesta      VARCHAR2(15), --Nombre del mensaje
      descripcionRespuesta VARCHAR2(200), -- Descripcion del mensaje
      codigoPersona        VARCHAR2(10),  -- Nombre del mensaje
      codigoCanal          VARCHAR2(3),   -- Nombre del mensaje
      codigoEmpresa        VARCHAR2(10),  -- Nombre del mensaje
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
      error                VARCHAR(1),
      nombreRespuesta      VARCHAR2(15),
      descripcionRespuesta VARCHAR2(200),
      autoriza             BOOLEAN,
      registra             BOOLEAN,
      consulta             BOOLEAN,
      canAutRequeridas     NUMBER);
      
    
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
   * Obtiene fecha de nacimiento de persona fisica
   */
   FUNCTION fu_obt_fec_nacimiento(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN VARCHAR2;
   /**
   * Calcula la edad de una persona fisica
   */
   FUNCTION fu_obt_edad(p_cod_persona IN ba_personas.cod_persona%TYPE) RETURN NUMBER;
     
   /**
   * Funcion que obtiene la transaccion padre de pago de sueldo de acuerdo al tipo de remuneracion
   * @param p_cod_ente Codigo del ente
   * @param p_tip_remuneracion A-Aguinaldo, S-Sueldo, C-Comision, T-Credito
   * @return Numbero de transaccion padre
   */
   FUNCTION fu_obt_tra_sueldo(p_cod_ente         IN ge_entes.cod_ente%TYPE,
                              p_tip_remuneracion IN ge_pag_sueldos_tmp.tip_remuneracion%TYPE) RETURN NUMBER;

   -- establecer modo autorizacion
   PROCEDURE pr_set_autorizacion;

   /** Funcion que obtiene el tipo de proceso de sueldo
   * @param p_cod_ente Codigo del ente
   *   
   * @return Tipo de proceso del pago de sueldo. O-Online, B-Batch, R-Requerimiento
   */
   FUNCTION fu_obt_tip_pro_sueldo(p_cod_ente IN ge_entes.cod_ente%TYPE) RETURN VARCHAR2;

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
                             p_codCanal       IN VARCHAR2) RETURN typ_iniciarSesion;
                                                 
   /**Elimina la sesion del usuario
   * @param p_sesion Código de la sesión
   * @return Resultado de la operacion
   */
   FUNCTION fu_eliminarSesion(p_sesionUsuario IN VARCHAR2) RETURN typ_mensajeRespuesta;
   
   /** Verifica la validez de una sesión obtenida previamente de fu_iniciarSesion
    *
    * @param p_sesionUsuario Identificador de sesión a ser verificado
    * @param p_codCanal Identificador del canal para el cual la sesión fue obtenida
    * @return retorna Información de la sesión o error si no pudo comprobarse su validez
   */
   FUNCTION fu_validarSesion(p_sesionUsuario IN VARCHAR2,
                             p_codCanal      IN VARCHAR2,
                             p_validar       IN VARCHAR DEFAULT 'S') RETURN typ_validarSesion;

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

   /**Cambia la clave de la transacción
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_claveAntigua Clave anterior
   * @param p_claveNueva Clave nueva
   * @return Resultado de la operacion
   */
   FUNCTION fu_cambiarClaveTransaccion(p_sesion      IN VARCHAR2,
                                       p_codCanal    IN VARCHAR2,
                                       p_claveActual IN VARCHAR2,
                                       p_claveNueva  IN VARCHAR2) RETURN typ_mensajeRespuesta;

   FUNCTION fu_obtenerDetalleCheques(p_sesion           IN VARCHAR2,
                                     p_codCanal         IN VARCHAR2,
                                     p_nroCtaEspecifica IN VARCHAR2,
                                     p_nroInicial       IN VARCHAR2) RETURN typ_detallesChequeras;

   FUNCTION fu_obtenerDetalleCuentas(p_sesion              IN VARCHAR2,
                                     p_codCanal            IN VARCHAR2,
                                     p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDetalleCuentas;

   FUNCTION fu_obtenerDatosChequeCasa(p_sesion   IN VARCHAR2,
                                      p_codCanal IN VARCHAR2) RETURN typ_datosChequeCasa;

   FUNCTION fu_obtenerResumenCuentas(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_filtro   IN VARCHAR2 DEFAULT NULL) RETURN typ_resumenCuentas;


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

   FUNCTION fu_obtComprobanteMovAutDeb(p_sesion       IN VARCHAR2,
                                        p_codCanal     IN VARCHAR2,
                                        p_nroCuenta    IN VARCHAR2, --nro de cuenta o tarjeta
                                        p_fecha        IN DATE,
                                        p_nroDocumento IN NUMBER,
                                        p_monto        IN NUMBER,
                                        p_tipo         IN VARCHAR2,
                                        p_factura      IN VARCHAR2,
                                        p_nroSecuencia IN NUMBER DEFAULT NULL,
                                        p_hora         IN VARCHAR2 DEFAULT NULL) RETURN typ_comprobanteMovAutDeb;

   FUNCTION fu_obtenerOficinas RETURN typ_informacionOficinas;

   FUNCTION fu_obtenerChequesDevueltos(p_sesion    IN VARCHAR2,
                                       p_codCanal  IN VARCHAR2,
                                       p_nroCuenta IN VARCHAR2 DEFAULT NULL) RETURN typ_ChequesDevueltos;

   FUNCTION fu_obtenerDepositosConfirmar(p_sesion    IN VARCHAR2,
                                         p_codCanal  IN VARCHAR2,
                                         p_nroCuenta IN VARCHAR2 DEFAULT NULL) RETURN typ_depositosConfirmar;

   FUNCTION fu_obtenerChequeras(p_sesion    IN VARCHAR2,
                                p_codCanal  IN VARCHAR2,
                                p_nroCuenta IN VARCHAR2) RETURN typ_detallesChequeras;

   FUNCTION fu_obtenerCheque(p_sesion    IN VARCHAR2,
                             p_codCanal  IN VARCHAR2,
                             p_nroCuenta IN VARCHAR2,
                             p_nroCheque IN VARCHAR2) RETURN typ_detalleCheque;

   FUNCTION fu_obtDetallesChequesChequera(p_sesion           IN VARCHAR2,
                                          p_codCanal         IN VARCHAR2,
                                          p_nroCuenta        IN VARCHAR2,
                                          p_nroChequeInicial IN NUMBER,
                                          p_tipo             IN VARCHAR2) RETURN typ_Chequera;

   FUNCTION fu_obtenerCotizacion RETURN typ_detallesCotizacion;

   FUNCTION fu_obtTransInternacional(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_inicio   IN DATE,
                                     p_fin      IN DATE) RETURN typ_detalleTransInternacional;

   FUNCTION fu_obtenerCalificacionRiesgo(p_sesion   IN VARCHAR2,
                                         p_codCanal IN VARCHAR2) RETURN typ_calificacionRiesgo;

   FUNCTION fu_autorizadorCheque(p_sesion          IN VARCHAR2,
                                 p_codCanal        IN VARCHAR2,
                                 p_modo            IN VARCHAR2,
                                 p_tipoDocumento   IN NUMBER,
                                 p_numeroDocumento IN VARCHAR2,
                                 p_nombreCompleto  IN VARCHAR2,
                                 p_tipoLinea       IN VARCHAR2,
                                 p_numeroTelefono  IN VARCHAR2,
                                 p_interno         IN VARCHAR2,
                                 p_estado          IN VARCHAR2,
                                 p_tipDocAnterior  IN NUMBER DEFAULT NULL,
                                 p_nroDocAnterior  IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta;

   FUNCTION fu_actDireccionCheque(p_sesion             IN VARCHAR2,
                                  p_codCanal           IN VARCHAR2,
                                  p_modo               IN VARCHAR2,
                                  p_direccion          IN VARCHAR2,
                                  p_codigoCiudad       IN NUMBER,
                                  p_codigoBarrio       IN NUMBER,
                                  p_observacion        IN VARCHAR2,
                                  p_numero             IN  VARCHAR2,
                                  p_departamento       IN  VARCHAR2,
                                  p_piso               IN VARCHAR2,
                                  p_edificio           IN VARCHAR2,
                                  p_codigoPostal       IN VARCHAR2,
                                  p_claveTransaccional IN VARCHAR2,
                                  p_claveToken         IN VARCHAR2) RETURN typ_solicitudClaves;
   /**
    * Se encarga de la Solicitud de chequeras 060
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroCuenta Nro de cuenta
    * @param p_codigoTipoChequera Código de tipo de chequera
    * @param p_canHojas Cantidad de hojas
    * @param p_cantidadChequeras Cantidad de chequeras
    * @param p_modo Modo
    * @param p_ofi_retencion Oficina de retensión
    * @param p_tip_solicitud Tipo de Solicitud, M : Mostrador, C : En casa
    * @param p_claveTransaccional Clave Transaccional
    * @param p_claveToken Clave Dinamica
     @return Resultado de la operacion
   */
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
   /**
    * Se encarga de obtener información de los tipos de chequeras existentes
    * @param p_sesion Código de la sesión
    * @param p_nroCuenta Nro de cuenta
    * @param p_codCanal Código del canal
    * @return Resultado de la operacion
   */
   FUNCTION fu_obtenerTiposChequeras(p_sesion    IN VARCHAR2,
                                     p_nroCuenta IN VARCHAR2,
                                     p_codCanal  IN VARCHAR2) RETURN typ_tiposChequeras;

   /**
   *Obtiene los saldos de una cuenta
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_nroCuenta Nro de cuenta
   * @param p_dias Cantidad de dias
   * @return Resultado de la operacion
   */
   FUNCTION fu_obtenerSaldosCuenta(p_sesion    IN VARCHAR2,
                                   p_codCanal  IN VARCHAR2,
                                   p_nroCuenta IN VARCHAR2,
                                   p_dias      IN NUMBER) RETURN typ_saldosCuentas;


   /**
    * Pago por Despachos aduaneros(Sofia)
    * @Migrado por: Sergio Ayala
    * @Fecha : 03-07-2012
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroCuenta Nro de cuenta
    * @param p_metodo V: Verificación,   C: Confirmación
    * @param p_monto  Monto de la operación
    * @param p_operacion  TDA: Pagos despachos aduaneros, TID: Pago de IVA despachante
                          TCA: Pago canon informático, TLE: Liquidación de expedientes
    * @param p_campo1 TDA: Ruc Importador, TID: Ruc Importador, TCA: Nro Ticket, TLE: Nro Ticket
    * @param p_campo2 TDA: Ruc Despachante, TID: Ruc Despachante,
                      TCA: Ruc Despachante, TLE: Ruc Solicitante
    * @param p_claveToken  Dependiendo de la configuración de limites operativos
    * @param p_claveTransaccional  Dependiendo de la configuración de limites operativos.
    * @return Resultado de la operacion
   */
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
                                     p_claveToken         IN VARCHAR2) RETURN typ_transferenciaban;

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
                                      p_claveToken         IN VARCHAR2) RETURN typ_transferenciaban;

   FUNCTION fu_transferenciasConContrato(p_sesion             IN VARCHAR2,
                                         p_codCanal           IN VARCHAR2,
                                         p_nroCtaDebito       IN VARCHAR2,
                                         p_nroCtaCredito      IN VARCHAR2,
                                         p_modo               IN VARCHAR2,
                                         p_nroContrato        IN NUMBER,
                                         p_dirIP              IN VARCHAR2,
                                         p_claveTransaccional IN VARCHAR2,
                                         p_claveToken         IN VARCHAR2) RETURN typ_transferenciaban;

   /**Listado de Facturas  **/
   FUNCTION fu_obtenerListaFacturas(p_sesion   IN VARCHAR2,
                                    p_codCanal IN VARCHAR2) RETURN typ_resumenFacturas;

   FUNCTION fu_obtenerFactura(p_sesion     IN VARCHAR2,
                              p_codCanal   IN VARCHAR2,
                              p_nroFactura IN VARCHAR,
                              p_fecha IN DATE) RETURN typ_detallesFactura;

  /**
    *  Extracto por cliente y cuenta
    * @Creado por: Fermín Giménez
    * @Fecha : 11-07-2012
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroCuenta Numero de cuenta
    * @param p_fechaHasta Fecha final para el extracto
    * @param p_claveToken  Dependiendo de la configuración de limites operativos
    * @param p_claveTransaccional  Dependiendo de la configuración de limites operativos.
    * @return Resultado de la operacion
   */
   FUNCTION fu_extractoARequerimiento(  p_sesion             IN VARCHAR2,
                                        p_codCanal           IN VARCHAR2,
                                        p_nroCuenta          IN VARCHAR2,
                                        p_fechaHasta         IN DATE,
                                        p_claveToken         IN VARCHAR2,
                                        p_claveTransaccional IN VARCHAR2) RETURN typ_extracto;

  /**
    * Pago de Préstamo
    * @Creado por: Sergio Ayala
    * @Fecha : 11-07-2012
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroPrestamo Número de Préstamo
    * @param p_cuentaDebito Cuenta de Débito
    * @param p_cantCuotas Cantidad de Cuotas a Pagar
    * @param p_montoOperacion Monto de la Operación
    * @param p_modo Modo
    * @param p_claveToken Clave de Token
    * @param p_claveTransaccional Clave Transaccional
    * @return Resultado de la operacion de Pago de Préstamo
   */
   FUNCTION fu_pagoPrestamo(p_sesion             IN VARCHAR2,
                            p_codCanal           IN VARCHAR2,
                            p_nroPrestamo        IN VARCHAR2,
                            p_cuentaDebito       IN VARCHAR,
                            p_cantCuotas         IN VARCHAR2,
                            p_montoOperacion     IN VARCHAR2,
                            p_modo               IN VARCHAR2,
                            p_claveToken         IN VARCHAR2,
                            p_claveTransaccional IN VARCHAR2) RETURN typ_pagoPrestamo;

  /**
    * Obtiene el número de Cuotas de un Préstamo que se pueden pagar
    * @Creado por: Sergio Ayala
    * @Fecha : 11-07-2012
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroPrestamo Número de Préstamo
    * @return Datos de las Cuotas de un Préstamo
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
    * @param p_claveTransaccional  Dependiendo de la configuración de limites operativos.
    * @return Resultado de la operacion
   */
   FUNCTION fu_pagoTarjetaCredito(p_sesion                 IN VARCHAR2,
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
                                  p_pagoOnline             IN VARCHAR2) RETURN typ_pagoTarjetaCredito ;

   /**
     *  saldo diarios
     * @Creado por: Fermín Giménez
     * @Fecha : 13-09-2012
     * @param p_sesion Código de la sesión
     * @param p_codCanal Código del canal
     * @param p_numeroCuenta Numero de cuenta
     * @param p_cantidadDias cantidad de dias.
     * @return Resultado de la operacion
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
     */                                         
   FUNCTION fu_obtenerTarjetasAdicionales(p_sesion            IN VARCHAR2,
                                          p_codCanal          IN VARCHAR2,
                                          p_nroTarjetaCredito IN VARCHAR2)
                                          RETURN typ_resumenTarjetasAdicionales;
   
  
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

   /**
   * Area del Cliente
   * @Creado por: Fermín Giménez
   * @Fecha : 13-12-2012
   */
   FUNCTION fu_obtenerAreaCliente(p_sesion            IN VARCHAR2,
                                  p_codigoCanal       IN VARCHAR2)
                                  RETURN typ_respuestaAreaCliente;
                                  
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
   * Pago de Servicios
   * @Creado por:
   * @Fecha : 17-01-2013
   */
   FUNCTION fu_pagoServicios(p_sesion      IN VARCHAR2,
                             p_codigoCanal IN VARCHAR2,
                             p_modo        IN VARCHAR2,
                             p_cuenta      IN VARCHAR2,
                             p_numeroIp    IN VARCHAR2,
                             p_claveTransaccional IN VARCHAR2,
                             p_claveToken IN VARCHAR2)
                             RETURN typ_pagoServicios;

   FUNCTION fu_obtenerContratoCambio( p_sesion      IN VARCHAR2,
                                      p_codigoCanal IN VARCHAR2
                                    ) RETURN typ_respuestaContratoCambio;

  /**
   * Transferencias Interbancarias SNP
   * @Fecha : 31-01-2013
   * @param p_prioridad     IN VARCHAR2 <ul><li>Si p_prioridad= A entonces v_cod_mt=103</li><li>   Si p_prioridad= B entonces v_cod_mt=102</li></ul>
   */
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
      p_prioridad                 IN VARCHAR2
   ) RETURN typ_transferenciaInterbancaria;

   /**
   * Consulta de Transferencia Interbancaria SNP
   * @Fecha : 05-02-2013
   */
   FUNCTION fu_consultarTransferenciaSnp
   (
      p_sesion           IN VARCHAR2,
      p_codigoCanal      IN VARCHAR2,
      p_fechaDesde       IN DATE,
      p_fechaHasta       IN DATE,
      p_numeroPagina     IN NUMBER,
      p_transaccion      IN NUMBER DEFAULT NULL,
      p_numeroCuenta     IN VARCHAR2 DEFAULT NULL,
      p_montoDesde       IN NUMBER DEFAULT NULL,
      p_montoHasta       IN NUMBER DEFAULT NULL
   ) RETURN typ_consultarTransferenciaSnp;

   /**
   * Cancelación de Transferencia Interbancaria SNP
   * @Fecha : 06-02-2013
   */
   FUNCTION fu_cancelarTransferenciaSnp
   (
      p_sesion           IN VARCHAR2,
      p_codigoCanal      IN VARCHAR2,
      p_modo             IN VARCHAR2,
      p_numeroReferencia IN VARCHAR2
   ) RETURN typ_cancelarTransferenciaSnp;
   
   FUNCTION fu_obtenerConfiguracion(p_parametro IN VARCHAR2,
                                    p_cod_modulo IN NUMBER DEFAULT NULL,
                                    p_cod_modalidad IN NUMBER DEFAULT NULL,
                                    p_cod_moneda IN VARCHAR2 DEFAULT NULL,
                                    p_cod_oficina IN NUMBER  DEFAULT NULL,
                                    p_cod_sub_modalidad IN VARCHAR2 DEFAULT NULL) RETURN typ_parametrosConfiguracion;

  -- Obtiene los periodos de horario de SNP
   FUNCTION fu_obtenerSnpHorarios(p_sesion IN VARCHAR2,p_codigoCanal in varchar2) RETURN typ_SnpPeriodos;                    

   -- Adhesión Débito Automático para Préstamo o Tarjeta
   FUNCTION fu_adhesionDebitoAutomatico(p_sesion       IN VARCHAR2,
                                        p_codigoCanal  IN VARCHAR2,
                                        p_numeroCuenta IN VARCHAR2,
                                        p_cuentaDebito IN VARCHAR2,
                                        p_tipoAdhesion IN VARCHAR2,
                                        p_tipoCobro    IN VARCHAR2) RETURN typ_mensajerespuesta;                    

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

   FUNCTION fu_reversarPagoServiciosWs(p_sesion IN VARCHAR2, p_codigoCanal IN VARCHAR2, p_sesionServicios IN VARCHAR2, p_tokenServicios VARCHAR2) RETURN typ_mensajerespuesta;

   FUNCTION depurarNumerico(p_string IN VARCHAR2, maxLength IN NUMBER) RETURN VARCHAR2;
      --JCBM 10/08/2024
   FUNCTION depurarNumerico(p_string  IN VARCHAR2,maxLength IN NUMBER,p_conDecimal IN VARCHAR2) RETURN VARCHAR2;
   FUNCTION depurarAlfanumerico(p_string IN VARCHAR2, maxLength IN NUMBER, p_espacio IN CHAR DEFAULT 'N') RETURN VARCHAR2;
   PROCEDURE pr_insertarBitacora(p_codigoPersona IN VARCHAR2 DEFAULT NULL,
                                 p_codigoCanal   IN VARCHAR2 DEFAULT NULL,
                                 p_codSesion     IN VARCHAR2 DEFAULT NULL,
                                 p_tipoMensaje   IN VARCHAR2 DEFAULT NULL,
                                 p_codigoEmpresa IN VARCHAR2 DEFAULT NULL,
                                 p_datos         IN VARCHAR2 DEFAULT NULL,
                                 p_tipo                IN VARCHAR2 DEFAULT NULL,
                                 p_numeroTelefono      IN VARCHAR2 DEFAULT NULL,
                                 p_codigoError         IN VARCHAR2 DEFAULT NULL,
                                 p_observacion         IN VARCHAR2 DEFAULT NULL,
                                 p_codigoMotivo        IN VARCHAR2 DEFAULT NULL,
                                 p_numeroCuentaDebito  IN VARCHAR2 DEFAULT NULL,
                                 p_numeroCuentaCredito IN VARCHAR2 DEFAULT NULL,
                                 p_monto               IN NUMBER DEFAULT NULL,
                                 p_codigoMoneda        IN VARCHAR2 DEFAULT NULL,
                                 p_dato2               IN CLOB DEFAULT NULL
                                 );
   PROCEDURE pr_mensajeUsuario(mensaje IN VARCHAR2, nombreMensaje OUT VARCHAR2, descripcionMensaje OUT VARCHAR2, error OUT VARCHAR2);
   FUNCTION fu_generarBitacora(error in varchar2, nombreRespuesta in varchar2 ,descripcionRespuesta in varchar2, mensajesAdicionales in varchar2 := NULL) RETURN VARCHAR2;
   FUNCTION depurarTextos(p_string  IN VARCHAR2, maxLength IN NUMBER, p_documento IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2;
   FUNCTION fu_validarOTP(p_cla_token IN VARCHAR2, p_cod_persona IN VARCHAR2, p_cod_per_vinculada IN VARCHAR2, p_modo IN VARCHAR2) RETURN typ_mensajeRespuesta;
   FUNCTION fu_ver_horario(p_horario OUT VARCHAR2, p_es_mov_noc OUT VARCHAR2, p_es_cta_noc OUT VARCHAR2, p_ult_cierre IN DATE, p_cod_ofi_origen IN VARCHAR2, p_fec_actual OUT DATE) RETURN typ_MensajeRespuesta;
   FUNCTION lf_val_mail(p_mail IN VARCHAR2) RETURN VARCHAR2;
   PROCEDURE pr_con_mon_a_moneda(p_cod_mon_original IN ba_monedas.cod_moneda%TYPE,
                                 p_cod_mon_destino  IN ba_monedas.cod_moneda%TYPE,
                                 p_mto_mon_original IN NUMBER,
                                 p_mto_mon_destino  OUT NUMBER,
                                 p_cot_mon_original IN OUT NUMBER,
                                 p_cot_mon_destino  IN OUT NUMBER,
                                 p_interbancaria    IN VARCHAR2 DEFAULT NULL);

   -- Obtencion de linea de credito
   FUNCTION fu_obtenerLineaCredito(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_lineaCredito;

   -- Que operaciones tiene configurado el usuario
   FUNCTION fu_obtenerPermisos(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2) RETURN typ_permisosUsuarios;
   
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

   /**
    * fu_obtenerDetalleAutorizacion, obtener de autorizacion    
    * @param p_numeroDocumento Numero del documento pendiente/procesado/anulado
    * @param p_estado estado del movimiento
    * @param p_fecha fecha de la operacion
    * @return Resultado del detalle de la autorizacion
   */
   FUNCTION fu_obtenerDetalleAutorizacion(p_sesion          IN VARCHAR2,
                                          p_codigoCanal     IN VARCHAR2,
                                          p_numeroDocumento IN bw_mov_pendientes.nro_documento%TYPE,
                                          p_estado          IN VARCHAR2 DEFAULT 'P',
                                          p_fecha           IN DATE DEFAULT NULL) RETURN typ_detalleAutorizacion;

    /**
    * fu_pagoSalarios, encargada de validar y confirmar pago de salarios
    
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @param p_codigoEnte Código del Ente
    * @param p_modoControl Modo de Control, L-Verificación(Carga manual), V-Verificación(Carga Archivo), C-Confirmación
    * @param p_codigoMoneda Moneda de la operación
    * @param p_montoTotal Monto total de la operación
    * @param p_tipoRemuneracion Tipo de pago, S-Sueldo, A-Aguinaldo, C-Comisión, T-Crédito
    * @param p_cantCuentasParaCredito Total de cuentas a acreditar
    * @param p_canRegistrosLeidos Total de registros a pasar en p_parametros
    * @param p_parametros Detalles de los datos
    * @param p_claveTransaccional Dependiendo de la configuración de limites operativos
    * @param p_claveToken Dependiendo de la configuración de límites operativos
    * @param p_fecPago fecha de pago.
    * @return Resultado de la operacion
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
                            p_fecPago                IN DATE) RETURN typ_pagoSalarios;

   /**
    * fu_pagoProveedores, encargada de validar y confirmar pago a proveedores
    
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @param p_codigoEnte Código del Ente    
    * @param p_modoControl Modo de Control, L-Verificación(Carga manual), V-Verificación(Carga Archivo), C-Confirmación
    * @param p_cuentaDebito Cuenta a debitar
    * @param p_codigoMoneda Moneda de la operación
    * @param p_montoTotal Monto total de la operación
    * @param p_fechaPago Fecha a pagar
    * @param p_tipoPago  Tipo de Pago, C-Credito en Cuenta, P-Pago proveedor, G-Cheque Gerencia
    * @param p_cantOrdenes Cantidad de registros a acreditar
    * @param p_cantFacturas Cantidad de facturas
    * @param p_parametros Registro de detalles
    * @param p_par_errores Registro de detalles con error
    * @param p_claveTransaccional Dependiendo de la configuración de limites operativos
    * @param p_claveToken Dependiendo de la configuración de límites operativos
    * @return Resultado de la operacion
   */
   FUNCTION fu_pagoProveedores(p_sesion                 IN VARCHAR2,
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
                               p_claveToken             IN VARCHAR2) RETURN typ_pagoProveedores;

   /**
    * fu_obtenerHistoricoProveedores, para obtener el historico de pago a proveedores
    
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @param p_fechaInicial Fecha inicio de busqueda de pago (Defecto: Fecha del dia - 60)
    * @param p_fechaFinal Fecha Final de busqueda del pago (Defecto: Fecha del dia)
    * @param p_cuentaBeneficiario Numero o nombre de la cuenta para buscar
    * @param p_nombreEntidad Nombre banco a buscar
    * @return Resultado de la operacion
   */
   FUNCTION fu_obtenerHistoricoProveedores(p_sesion             IN VARCHAR2,
                                           p_codigoCanal        IN VARCHAR2,
                                           p_fechaInicial       IN DATE DEFAULT NULL,
                                           p_fechaFinal         IN DATE DEFAULT NULL,
                                           p_cuentaBeneficiario IN VARCHAR2 DEFAULT NULL,
                                           p_nombreEntidad      IN VARCHAR2 DEFAULT NULL) RETURN typ_pagoProveedores;

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
                                    p_parametro     IN VARCHAR2 DEFAULT 'H') RETURN typ_pagosalarios;
   /**
   * Obtiene el último monto acreditado al beneficiario.
   * @p_nro_cuenta Número de cuenta del beneficiario
   * @p_cod_ente Ente a la cual pertenece el beneficirio
   * @p_fec Ultima fecha de acreditación de salario.
   **/                                 
   FUNCTION fu_obt_ult_salario(p_nro_cuenta IN VARCHAR2, p_cod_ente IN NUMBER, p_fec IN DATE) RETURN NUMBER ;                                    

   /** Verifica la validez de una sesion obtenida previamente de fu_iniciarSesion
   * @param p_sesion identificador de sesion a ser verificado
   * @param p_codCanal identificador del Canal para el cual la sesion fue obtenida
   * @return retorna información de la actividad de sesion o error si no pudo comprobarse su validez
   */
   FUNCTION fu_validarActividad(p_sesion   IN VARCHAR2,
                                p_codCanal IN VARCHAR2) RETURN typ_mensajerespuesta;

   /**
   * Valida si el cliente está habilitado para realizar Adelanto Fácil
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal
   * @p_nroTarjetaCredito Número de tarjeta de crédito
   * @p_monto Monto de adelanto 
   * @p_plazo Cantidad de meses 
   * @return typ_valadelantofacil
   */
   FUNCTION fu_valAdelantoFacil(p_sesion IN VARCHAR2,
                                p_codCanal IN VARCHAR2,
                                p_nroTarjetaCredito IN VARCHAR2,
                                p_monto IN NUMBER, 
                                p_plazo IN NUMBER) RETURN typ_valadelantofacil;
   
   /**
   * Valida y confirma la solicitud de Adelanto fácil
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal
   * @p_nroTarjetaCredito Número de tarjeta de crédito
   * @p_monto Monto de adelanto 
   * @p_plazo Cantidad de meses 
   * @p_nro_cta_credito Número de tarjeta de débito al que se acredita el adelanto
   * @p_claveTransaccional Clave transaccional del cliente
   * @p_claveToken Clave dinámica o token
   * @return typ_adelanto
   */
   FUNCTION fu_solicitarAdelanto(p_sesion             IN VARCHAR2,
                                 p_codCanal           IN VARCHAR2,
                                 p_modo               IN VARCHAR2  DEFAULT NULL,
                                 p_nroTarjetaCredito  IN VARCHAR2,
                                 p_monto              IN NUMBER, 
                                 p_plazo              IN NUMBER,
                                 p_nro_cta_credito    IN VARCHAR2,
                                 p_claveTransaccional IN VARCHAR2,
                                 p_claveToken         IN VARCHAR2) RETURN typ_adelanto;
   /**
   * Devuelve el valor mínimo y máximo de cuotas y el porcentaje de la tasa
   * @return typ_datostasas
   */
   FUNCTION fu_obtTasasAdelanto RETURN typ_datostasas;
   
   /**
   * Realiza el proceso de debito para pagos SET
   * @p_sesion Código de la sesión
   * @p_codigoCanal Código de canal
   * @p_modo Modo de proceso, V, C, G, A
   * @p_cuentaDebito Cuenta a debitar
   * @p_numeroTransaccion Numero de transaccion de servicio
   * @p_xml_boleta Boleta de pago a la SET
   * @p_claveTransaccional Clave transaccional
   * @p_claveToken Clave OTP
     
   */
   FUNCTION fu_pagoSet(p_sesion              IN VARCHAR2,
                       p_codigoCanal         IN VARCHAR2,
                       p_modo                IN VARCHAR2,
                       p_cuentaDebito        IN VARCHAR2,
                       p_numeroTransaccion   IN VARCHAR2,
                       p_xml_boleta          IN VARCHAR2,
                       p_claveTransaccional  IN VARCHAR2,
                       p_claveToken          IN VARCHAR2) RETURN typ_pagoServiciosWs;
   
   /**
   * Actualiza el estado del reenvio de un pago de servicios
   * @p_xml XML de la transaccion
   * @retorno Number Cantidad de filas afectadas
   */
   FUNCTION fu_pagoServicioWsActualizar(p_xml IN VARCHAR2) RETURN NUMBER;

   -- Obtencion de feriados
   FUNCTION fu_obtenerFeriados(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_fechaInicio   IN DATE,
                               p_fechaFin      IN DATE) RETURN typ_listaFeriados;

   /** Obtener bancos para transferencias internacionales
    *
    * @param p_sesion Sesion del usuario
    * @param p_codigoCanal Numero de caja
    * @param p_tipo B: Beneficiarios, C: Corresponsal
    * @param p_codigoSwift Codigo Swift del Banco
    * @param p_banco Descripcion del Banco
    * @param p_pais Descripcion del Pais
    *
    * @return Lista de Bancos
    */
   FUNCTION fu_obtenerBancos(p_sesion      IN VARCHAR2,
                             p_codigoCanal IN VARCHAR2,
                             p_tipo        IN VARCHAR2 DEFAULT 'B',
                             p_codigoSwift IN VARCHAR2 DEFAULT NULL,
                             p_banco       IN VARCHAR2 DEFAULT NULL,
                             p_pais        IN VARCHAR2 DEFAULT NULL) RETURN typ_bancos;

   /** Proceso que maneja la validacion y confirmacion de transferencias internacionales
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo V: Valida, C: Confirma, A: Autoriza
    * @param p_nombreBeneficiario
    * @param p_direccionBeneficiario
    * @param p_cuentaCredito Referencia de cta credito
    * @param p_codigoBanco Codigo del Banco Receptor
    * @param p_nombreBanco Nombre del Banco (en caso que p_codigoBanco sea nulo)
    * @param p_codigoSwift Swift Banco Receptor
    * @param p_codigoPais Pais del Banco Receptor
    * @param p_codigoCiudad Codigo Ciudad Banco receptor
    * @param p_codBancoCorresponsal Codigo de Banco Corresponsal
    * @param p_nombreBancoCorresponsal 
    * @param p_codigoMonedaCredito Codigo moneda del credito
    * @param  p_montoCredito Monto a acreditar
    * @param p_numeroContrato Numbero de contrato de cambio (Opcional)
    * @param p_cuentaDebito 
    * @param p_tipoGasto OUR: costo para el emisor, BEN: costo para el beneficiario
    * @param p_codigoTipoReferencia 0Hrs, 12Hrs, 24Hrs
    * @param p_tipoMotivo
    * @param p_tipoFondo 
    * @param p_tipoFinanciacion
    * @param p_referenciaBeneficiario
    * @param p_observaciones
    * @param p_claveTransaccional
    * @param p_claveToken
    * @param p_codPaisBeneficiario Codigo Pais del Beneficiario
    * @param p_codCiudadBeneficiario Codigo Ciudad del Beneficiario
    * @param p_comprobante Comprobante transferencia
    * @param p_numeroReferencia Referencia de la Operacion (Opcional)
    * @param p_ordenPago Orden de pago para DNA (Obligatorio segun p_tipoMotivo)
    * @return Resultado de la operacion
    */
   FUNCTION fu_transferenciaInternacional(p_sesion                  IN VARCHAR2,
                                          p_codigoCanal             IN VARCHAR2,
                                          p_modo                    IN VARCHAR2,
                                          p_nombreBeneficiario      IN VARCHAR2,
                                          p_direccionBeneficiario   IN VARCHAR2,
                                          p_cuentaCredito           IN VARCHAR2,
                                          p_codigoBanco             IN VARCHAR2,
                                          p_nombreBanco             IN VARCHAR2,
                                          p_codigoSwift             IN VARCHAR2,
                                          p_codigoPais              IN VARCHAR2,
                                          p_codigoCiudad            IN VARCHAR2,
                                          p_codBancoCorresponsal    IN VARCHAR2,
                                          p_nombreBancoCorresponsal IN VARCHAR2,
                                          p_swiftBancoCorresponsal  IN VARCHAR2,
                                          p_codCiudadBcoCorresponsal IN NUMBER,
                                          p_codPaisBcoCorresponsal  IN NUMBER,
                                          p_codigoMonedaCredito     IN VARCHAR2,
                                          p_montoCredito            IN NUMBER,
                                          p_numeroContrato          IN VARCHAR2,
                                          p_cuentaDebito            IN VARCHAR2,
                                          p_tipoCargo               IN VARCHAR2,
                                          p_plazo                   IN VARCHAR2,
                                          p_tipoMotivo              IN VARCHAR2,
                                          p_tipoFondo               IN VARCHAR2,
                                          p_tipoFinanciacion        IN VARCHAR2,
                                          p_referenciaBeneficiario  IN VARCHAR2,
                                          p_observaciones           IN VARCHAR2,
                                          p_claveTransaccional      IN VARCHAR2,
                                          p_claveToken              IN VARCHAR2,                                          
                                          p_codPaisBeneficiario     IN NUMBER DEFAULT NULL,
                                          p_codCiudadBeneficiario   IN NUMBER DEFAULT NULL,
                                          p_comprobante             IN BLOB DEFAULT NULL,
                                          p_nombreComprobante       IN VARCHAR2 DEFAULT NULL,                                        
                                          p_numeroReferencia        IN NUMBER DEFAULT NULL,
                                          p_ordenPago               IN VARCHAR2 DEFAULT NULL) RETURN typ_transferenciaban;

  
   /** Obtiene la lista de productos preaprobados del cliente
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @return Lista de productos preaprobados
   */
   FUNCTION fu_obtenerPreaprobados(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_listapreaprobado;

   /** Validacion y confirmacion de producto preaprobado
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo Modo de Operacion, D: listado, V: validacion, C: Confirmacion
    * @param p_codigoModulo Modulo de Producto a solicitar
    * @param p_xmlData XML de datos a solicitar    
    * @return resultado de la operacion
   */
   FUNCTION fu_solicitudPreaprobados(p_sesion         IN VARCHAR2,
                                     p_codigoCanal    IN VARCHAR2,
                                     p_modo           IN VARCHAR2,
                                     p_codigoModulo   IN NUMBER,
                                     p_xmlData        IN VARCHAR2) RETURN typ_preaprobado;

   /** Obtener las direcciones de un cliente
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @return lista de direcciones
   */
   FUNCTION fu_obtenerDirecciones(p_sesion   IN VARCHAR2,
                                  p_codigoCanal IN VARCHAR2) RETURN typ_direcciones;

   /** Proceso que maneja la validacion y confirmacion de recaudaciones
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo V: Valida Archivo, C: Confirma, L: Valida Manual
    * @param p_cuentaCredito Cuenta del Ente para acreditar
    * @param p_fechaOperacion Fecha a procesar el pago
    * @param p_cantidad Total de cuentas a debitar
    * @param p_cuentasDebito Detalle de cuentas a procesar
    * @param p_claveTransaccional
    * @param p_claveToken
    * @return Resultado de la operacion
   */
   FUNCTION fu_recaudaciones(p_sesion                 IN VARCHAR2,
                             p_codigoCanal            IN VARCHAR2,
                             p_modo                   IN VARCHAR2,
                             p_cuentaCredito          IN VARCHAR2,
                             p_fechaOperacion         IN DATE,
                             p_cantidad               IN NUMBER,
                             p_cuentasDebito          IN CLOB,
                             p_claveTransaccional     IN VARCHAR2,
                             p_claveToken             IN VARCHAR2) RETURN typ_recaudaciones;

   /** Obtiene el historico de recaudaciones para un ente
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_cuentaCredito Cuenta acreditada (Opcional)
    * @param p_cuentaDebito Cuenta debitada (Opcional)
    * @param p_numeroFactura Numero de factura procesada (Opcional)
    * @param p_fechaInicial Fecha inicial de pago (Opcional)
    * @param p_fechaFinal Fecha final de pago (Opcional)
    * @param p_estado Estado del cobro (Opcional)
    * @return Lista de recaudaciones
   */
   FUNCTION fu_obtenerHisRecaudaciones(p_sesion        IN VARCHAR2,
                                       p_codigoCanal   IN VARCHAR2,
                                       p_cuentaCredito IN VARCHAR2 DEFAULT NULL,
                                       p_cuentaDebito  IN VARCHAR2 DEFAULT NULL,
                                       p_numeroFactura IN VARCHAR2 DEFAULT NULL,
                                       p_fechaInicial  IN DATE DEFAULT NULL,
                                       p_fechaFinal    IN DATE DEFAULT NULL,
                                       p_estado        IN VARCHAR2 DEFAULT NULL) RETURN typ_recaudaciones;
   
   /**
   * Inserta una solicitud de cancelación de producto o servicio
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal
   * @p_tip_producto Tipo de producto
   * @p_nro_producto Número del producto a cancelar
   * @p_mot_cancelacion Motivo de la cancelación
   * @p_comentario Comentarios del cliente
   * @p_tel_contacto Teléfono de contacto
   * @p_mail_contacto Email de contacto
   */
   FUNCTION fu_solCancelacionProductos(p_sesion             IN VARCHAR2,
                                       p_codigoCanal        IN VARCHAR2,
                                       p_tip_producto       IN VARCHAR2,
                                       p_nro_producto       IN VARCHAR2,
                                       p_mot_cancelacion    IN VARCHAR2,
                                       p_comentario         IN VARCHAR2 DEFAULT NULL,
                                       p_tel_contacto       IN VARCHAR2,
                                       p_mail_contacto      IN VARCHAR2,
                                       p_cel_contacto       IN VARCHAR2) RETURN typ_mensajerespuesta;
   /**
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal
   * @p_relacion Relación con la cuenta
   * @return Lista de Tarjetas
   */
   FUNCTION fu_obtenerTarjetas(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_relacion    IN VARCHAR2 DEFAULT NULL) RETURN typ_resumentarjetas;

   /** Registra una operación de canje de puntos
    *
    * @param p_cod_sesion Sesión del cliente
    * @param p_cod_canal Código del canal
    * @param p_nro_tarjeta Los 4 últimos números de tarjeta utilizada para el canje de puntos
    * @param p_cat_producto Categoría del producto canjeado (1=Tangibles, 2=Servicios, 3=Viajes)
    * @param p_nom_producto Nombre del producto canjeado
    * @param p_des_producto Descripción del producto canjeado
    * @param p_tel_contacto Teléfono de contacto del cliente
    * @param p_ema_contacto Dirección de correo del cliente
    * @param p_ema_des_notificacion Dirección de correo al cual notificar sobre el canje de puntos realizado
    * @param p_cantidad Cantidad de productos o servicios canjeados (Opcional)
    * @param p_puntos Total de puntos canjeados (Opcional)
    * @param p_tel_proveedor Telefono del proveedor del producto o servicio canjeado (Opcional)
    * @param p_showroom Retiro del producto canjeada del showroom (S=SI / N=NO) (Opcional)
    * @param p_direccion Dirección a enviar o dirección del proveedor del producto/servicio canjeado (Opcional)
    * @param p_rec_autorizada Retiro o recepción del producto canjeado por una persona autorizada (S=SI / N=NO) (Opcional)
    * @param p_per_autorizada Nombre y apellido de la persona autorizada para retiro o recepción del producto canjeado (Opcional)
    * @param p_cod_tip_autorizado Tipo de documento de la persona autorizada para retiro o recepción del producto canjeado (Opcional)
    * @param p_nro_doc_autroizado Número de documento de la persona autorizada para retiro o recepción del producto canjeado (Opcional)
    * @param p_hor_inicio Horario de entrega desde a partir del cual se puede recibir el producto canjeado (Opcional)
    * @param p_hor_fin Horario de entrega hasta el cual se puede recibir el producto canjeado (Opcional)
    * @param p_ben_titular Beneficiario del servicio canjeado es el titular de la tarjeta utilizada en el canje de puntos (S=SI / N=NO) (Opcional)
    * @param p_beneficiario Nombre y apellido de la persona a la cual se emite el voucher del servcio canjeado (Opcional)
    * @param p_turno Reservar turno para el servicio canjeado (S=SI / N=NO) (Opcional)
    * @param p_sol_ida Pasaje del viaje canjeado es solo de ida (S=Pasaje de solo ida / N=Pasaje de ida y vuelta) (Opcional)
    * @param p_fec_salida Fecha del salida del viaje canjeado (Opcional)
    * @param p_fec_retorno Fecha de retorno del viaje canjeado (Opcional)
    * @param p_fec_flexible Fechas de salida y retorno son flexibles (S=SI / N=NO) (Opcional)
    * @param p_cla_servicio Clase del viaje canjeado (1=Turista, 2=Ejecutivo) (Opcional)
    * @param p_can_ninos Cantidad de niños para el viaje canjeado (Opcional)
    * @param p_can_adultos Cantidad de adultos para el viaje canjeado (Opcional)
    * @param p_lin_aerea Línea aérea de preferencia del cliente (Opcional)
    * @param p_nro_doc_beneficiario Número de documento del beneficiario(Opcional)
    * @param p_fec_entrada Fecha de entrada para el servicio de hospedajes(Opcional)
    * @param p_cod_verificador Código verificador del canje(Opcional)
    * @param p_condiciones texto de condiciones dinámico(Opcional)
    * @param p_detalles Lista de detalles de canjes (Opcional)
    * @param p_est_canje Estado del canje
    * @param p_nom_proveedor Nombre del comercio/proveedor (Opcional)
    * @return Resultado de la insercion
   */
   FUNCTION fu_ins_can_puntos(p_cod_sesion           IN BW_AUT_SESIONES.COD_SESION%TYPE,
                              p_cod_canal            IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_tarjeta          IN BW_CANJES.NRO_TARJETA%TYPE DEFAULT NULL,
                              p_cat_producto         IN BW_CANJES.CAT_PRODUCTO%TYPE,
                              p_nom_producto         IN BW_CANJES.NOM_PRODUCTO%TYPE,
                              p_des_producto         IN BW_CANJES.DES_PRODUCTO%TYPE,
                              p_tel_contacto         IN BW_CANJES.TEL_CONTACTO%TYPE,
                              p_ema_contacto         IN BW_CANJES.EMA_CONTACTO%TYPE,
                              p_ema_des_notificacion IN BW_CANJES.EMA_DES_NOTIFICACION%TYPE,
                              p_cantidad             IN BW_CANJES.CANTIDAD%TYPE DEFAULT NULL,
                              p_puntos               IN BW_CANJES.PUNTOS%TYPE DEFAULT NULL,
                              p_tel_proveedor        IN BW_CANJES.TEL_PROVEEDOR%TYPE DEFAULT NULL,
                              p_showroom             IN BW_CANJES.SHOWROOM%TYPE DEFAULT NULL,
                              p_direccion            IN BW_CANJES.DIRECCION%TYPE DEFAULT NULL,
                              p_rec_autorizada       IN BW_CANJES.REC_AUTORIZADA%TYPE DEFAULT NULL,
                              p_per_autorizada       IN BW_CANJES.PER_AUTORIZADA%TYPE DEFAULT NULL,
                              p_cod_tip_autorizado   IN BW_CANJES.COD_TIP_AUTORIZADO%TYPE DEFAULT NULL,
                              p_nro_doc_autorizado   IN BW_CANJES.NRO_DOC_AUTORIZADO%TYPE DEFAULT NULL,
                              p_hor_inicio           IN BW_CANJES.HOR_INICIO%TYPE DEFAULT NULL,
                              p_hor_fin              IN BW_CANJES.HOR_FIN%TYPE DEFAULT NULL,
                              p_ben_titular          IN BW_CANJES.BEN_TITULAR%TYPE DEFAULT NULL,
                              p_beneficiario         IN BW_CANJES.BENEFICIARIO%TYPE DEFAULT NULL,
                              p_turno                IN BW_CANJES.TURNO%TYPE DEFAULT NULL,
                              p_sol_ida              IN BW_CANJES.SOL_IDA%TYPE DEFAULT NULL,
                              p_fec_salida           IN BW_CANJES.FEC_SALIDA%TYPE DEFAULT NULL,
                              p_fec_retorno          IN BW_CANJES.FEC_RETORNO%TYPE DEFAULT NULL,
                              p_fec_flexible         IN BW_CANJES.FEC_FLEXIBLE%TYPE DEFAULT NULL,
                              p_cla_servicio         IN BW_CANJES.CLA_SERVICIO%TYPE DEFAULT NULL,
                              p_can_ninos            IN BW_CANJES.CAN_NINOS%TYPE DEFAULT NULL,
                              p_can_adultos          IN BW_CANJES.CAN_ADULTOS%TYPE DEFAULT NULL,
                              p_lin_aerea            IN BW_CANJES.LIN_AEREA%TYPE DEFAULT NULL,
                              p_nro_doc_beneficiario IN Bw_Canjes.NRO_DOC_BENEFICIARIO%TYPE DEFAULT NULL,
                              p_fec_entrada          IN BW_CANJES.FEC_ENTRADA%TYPE DEFAULT NULL,
                              p_cod_verificador      IN BW_CANJES.COD_VERIFICADOR%TYPE DEFAULT NULL,
                              p_condiciones          IN VARCHAR2 DEFAULT NULL,
                              p_detalles             IN TYP_LISTADETALLECANJE DEFAULT NULL,
                              p_est_canje            IN BW_CANJES.ESTADO%TYPE,
                              p_nom_proveedor        IN BW_CANJES.COMERCIO%TYPE DEFAULT NULL,
                              p_cod_producto         IN BW_CANJES.COD_PRODUCTO%TYPE DEFAULT NULL) RETURN TYP_CANJE;

   /**
   * Obtiene una operación de canje de puntos
   *
   * @param p_cod_sesion Sesión del cliente
   * @param p_cod_canal Código del canal
   * @param p_nro_canje Número de identificación del canje de puntos
   * @return El registro del canje realizado
   */
   FUNCTION fu_obt_can_puntos(p_cod_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE) RETURN TYP_CANJE;

   /**
   * Obtiene una operación de canje de puntos asociado a entradas de cinemark
   *
   * @param p_cod_sesion Sesión del cliente
   * @param p_cod_canal Código del canal
   * @param p_nro_canje Número de identificación del canje de puntos
   * @return El registro del canje realizado
   */
   FUNCTION fu_obt_can_entradas(p_cod_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                                p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                                p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE) RETURN typ_canjeentradas;

   /**
   * Valida la clave token
   *
   * @param p_cod_sesion Sesión del cliente
   * @param p_cod_canal Código del canal
   * @param p_cla_token Clave token a validar
   * @param p_modo Modo 'V' pedir a VASCO envío de challenge SMS , 'C' verificar la clave OTP con VASCO
   * @return Resultado de la validación
   */                    
   FUNCTION fu_val_clave_otp(p_cod_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                             p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                             p_cla_token  IN VARCHAR2,
                             p_modo       IN VARCHAR2) RETURN TYP_MENSAJERESPUESTA;
                             
    /**
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal   
   * @return Lista de Etiqueta Valor
   */                                    
   FUNCTION fu_obtInformeSemestral(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_listaEtiquetaValor;

   FUNCTION fu_acreditacionGourmet(p_sesion IN VARCHAR2, 
                                   p_codigoCanal IN VARCHAR2, 
                                   p_codigoEnte IN NUMBER, 
                                   p_modoControl IN VARCHAR2,
                                   p_nroCuentaDebito IN VARCHAR2, 
                                   p_canTarjetasParaCredito IN NUMBER, 
                                   p_canRegistrosLeidos IN NUMBER,
                                   p_montoTotal IN ge_movimientos.monto%TYPE, 
                                   p_parametros IN CLOB, 
                                   p_claveTransaccional IN VARCHAR2, 
                                   p_claveToken IN VARCHAR2) RETURN typ_acrGourmet;

   FUNCTION fu_acreditacionGourmetHis(p_sesion IN VARCHAR2, 
                                      p_codigoCanal IN VARCHAR2, 
                                      p_nro_tarjeta IN VARCHAR2, 
                                      p_fechaInicial IN DATE,
                                      p_fechaFinal IN DATE,
                                      p_nroDocumento IN VARCHAR2, 
                                      p_nombre IN VARCHAR2, 
                                      p_nroOperacion IN VARCHAR2,
                                      p_parametro IN VARCHAR2 DEFAULT 'H') RETURN typ_acrGourmet;

   /**
   * Retorna un listado de los prestamos simulables con sus tasas de interes y plazos
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal
   * @p_apikey key de la APP que llama al servicio
   **/                          
   FUNCTION fu_simuladorPrestamo(
                                 p_codigoCanal IN VARCHAR2,
                                 p_moneda      IN VARCHAR2,                                 
                                 p_apikey     IN VARCHAR2) RETURN TYP_SIMULADOR;

   /* @param p_codToken Id. del pago de servicio usado como clave en la busqueda para el update
    * @param p_montoComision Monto de la comision indicado en la factura
    */                                
   FUNCTION fu_pagoServicioUpdateWs(p_codSesion     IN VARCHAR2,
                                    p_codCanal      IN VARCHAR2,
                                    p_modo          IN VARCHAR2 default 'F',
                                    p_ticket        IN CLOB,
                                    p_codPersona    IN VARCHAR2, 
                                    p_codEmpresa    IN VARCHAR2 default NULL, 
                                    p_serConcepto   IN VARCHAR2,
                                    p_codToken      IN VARCHAR2, 
                                    p_montoComision IN NUMBER) RETURN typ_mensajeRespuesta;

   /**
    * Recupera y retorna de la tabla bw_pag_servicios el listado de facturas de pago de servicios de un cliente
    * @param p_codSesion Sesion del cliente
    * @param p_codCanal Codigo del canal
    * @param p_modo Modo de invocacion, 'L' es obtener lista de facturas    
    * @param p_codPersona Nro de cliente PF logueado en la sesion, cuyas facturas se desea listar
    * @param p_codToken Id. del pago de servicio usado como clave en la busqueda para 1 detalle
    * @param p_codEmpresa Nro de cliente PJ logueado en la sesion, cuyas facturas se desea listar
    *        Si viene codToken, se busca el detalle de 1 sola factura
    *        Si no viene codToken, se busca el listado de facturas de los ultimos 6 meses del cliente indicado 
    * @param p_numeroPagina Nro de pagina solicitada
    * @param p_cantidadPagina Nro de registros por pagina
    */                                
   FUNCTION fu_obtFacturasPagoServiciosWs(p_codSesion      IN VARCHAR2,
                                          p_codCanal       IN VARCHAR2,
                                          p_modo           IN VARCHAR2 default 'L',                                              
                                          p_codPersona     IN VARCHAR2, 
                                          p_codToken       IN VARCHAR2 default NULL,
                                          p_codEmpresa     IN VARCHAR2 default NULL, 
                                          p_numeroPagina   IN NUMBER DEFAULT NULL,
                                          p_cantidadPagina IN NUMBER DEFAULT NULL) RETURN typ_facturasServicios;                                

   /**
   * Retorna un listado de los seguros contratados para el usuario con la sesion ingresada
   * @p_sesion Codigo de sesion
   * @p_codCanal Codigo de canal
   * @return Lista de Etiqueta Valor
   **/
   FUNCTION fu_obtenerSeguros(p_sesion      IN VARCHAR2,
                              p_codigoCanal IN VARCHAR2,
                              p_codigoSeguro IN VARCHAR2 DEFAULT NULL) RETURN TYP_SEGUROS;

   -- registro y alta de funcionarios
   FUNCTION fu_altaEmpleados(p_sesion             IN VARCHAR2,
                             p_codigoCanal        IN VARCHAR2,
                             p_modo               IN VARCHAR2,
                             p_codigoMoneda       IN VARCHAR2,
                             p_notificacionMail   IN VARCHAR2,
                             p_cantidad           IN NUMBER,
                             p_parametros         IN CLOB,                             
                             p_claveTransaccional IN VARCHAR2,
                             p_claveToken         IN VARCHAR2,
                             p_numeroDocumento    IN NUMBER DEFAULT NULL) RETURN typ_altaEmpleados;

   -- Historico de alta de funcionarios
   FUNCTION fu_altaEmpleadosHis(p_sesion             IN VARCHAR2,
                                p_codigoCanal        IN VARCHAR2,
                                p_fechaInicio        IN DATE DEFAULT NULL,
                                p_fechaFin           IN DATE DEFAULT NULL,
                                p_nombreDocumento    IN VARCHAR2 DEFAULT NULL,
                                p_numeroOperacion    IN NUMBER DEFAULT NULL,
                                p_numeroPagina       IN NUMBER DEFAULT NULL,
                                p_cantidadPagina     IN NUMBER DEFAULT NULL) RETURN typ_altaEmpleados;
   
   /**
   * Registra los movimientos de operaciones de cambios para transacciones sipap
   * @p_hora Hora de la transaccion
   * @p_nro_documento Numero de la operacion
   * @p_cod_mon_debito Codigo de la moneda de la cuenta debito
   * @p_cod_mon_credito Codigo de la moneda de la cuenta credito
   * @p_usuario Usuario de registro de la operacion
   **/                           
   PROCEDURE pr_act_mov_ope_cambios(p_hora                IN ge_movimientos.hora%TYPE,
                                   p_nro_documento       IN ge_movimientos.nro_documento%TYPE,
                                   p_cod_mon_debito      IN ge_movimientos.cod_moneda%TYPE,
                                   p_cod_mon_credito     IN ge_movimientos.cod_moneda%TYPE,
                                   p_usuario             IN VARCHAR2);

    
  /**
   * Registra los movimientos de operaciones de cambios para transacciones sipap
   * @p_cod_canal Identificador del canal que realiza la peticion
   * @p_cod_persona Identificador de la personal que realiza la peticion
   * @p_mto_asegurado Monto del capital asegurado
   * @p_cod_tip_seguro Identificador del tipo de seguro de la tabla ge_tip_seguros
   * @p_mto_cuota Monto de la primera cuota
   **/
  FUNCTION fu_val_sol_seguro(p_cod_canal      IN VARCHAR2,
                             p_cod_persona    IN VARCHAR2,
                             p_mto_asegurado  IN NUMBER,
                             p_cod_tip_seguro IN NUMBER,
                             p_mto_cuota      IN NUMBER,
                             p_cod_seguro     IN NUMBER) RETURN TYP_MENSAJERESPUESTA;

   /**
   * Solicitud de extractos digitales
   * @p_sesion Codigo de sesion
   * @p_codCanal Codigo de canal
   * @p_modo Modo de invocacion
   * @p_retencionCuentas Indicador de retencion de Extracto de Cuentas
   * @p_retencionTarjetas Indicador de retencion de Extracto de Cuentas
   * @p_numeroTarjeta Numero de tarjeta de credito
   **/                               
   FUNCTION fu_extractoDigital(p_sesion             IN VARCHAR2,
                               p_codigoCanal        IN VARCHAR2,
                               p_modo               IN VARCHAR2,
                               p_retencionCuentas   IN VARCHAR2,
                               p_retencionTarjetas  IN VARCHAR2,
                               p_numeroTarjeta      IN VARCHAR2) RETURN typ_datoscliente;
             
   /**
  * Procesa los pagos de servicios de la portadora Bancard (PESA)
  * @p_sesion sesión del cliente
  * @p_codigoCanal código del canal de origen
  * @p_modo modo de invocación
  * @p_cuentaDebito número de cuenta de la que se realiza débito
  * @p_numeroIp ip del cliente
  * @p_sesionServicios sesión de pago de servicios
  * @p_numeroTransaccion número de la transacción
  * @p_servicio código de servicio que se va a pagar
  * @p_terminal número de terminal
  * @p_moneda código de moneda del servicio
  * @p_monto monto a pagar
  * @p_importeComision importe de la comisión por el pago de servicio
  * @p_claveTransaccional clave transaccional ingresada por el cliente
  * @p_claveToken clave token ingresada por el cliente
  * @p_tokenServicios token relacionado al servicio
  * @p_proveedor código de portadora
  * @p_extra datos extra de la transacción
  **/  
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
           
  /**
   * Funcion para suscripcion y configuracion de operaciones sin tarjeta
   * @p_cod_sesion Código de sesión
   * @p_cod_canal Código del canal
   * @p_nro_cuenta Número de cuenta a ser vinculada
   * @p_nro_celular Número de celular a vincular a la cuenta
   * @p_modo Modo de control V: Verificación, C : Confirmación, A: actualización
   * @p_tip_pedido Tipo de configuración a ser realizada S Suscripcion, M Modificacion, B Bloqueo, D Desbloqueo
   * @p_estado Estado del servicio (solo en p_modo -> A)
   */                             
   FUNCTION fu_configurarOpSinTarjeta(p_cod_sesion          IN BW_AUT_SESIONES.COD_SESION%TYPE,
                                         p_cod_canal           IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                                         p_nro_cuenta          IN BW_CTA_TELEFONOS.NRO_CUENTA%TYPE,
                                         p_nro_celular         IN BW_CTA_TELEFONOS.NRO_CELULAR%TYPE,
                                         p_modo                IN VARCHAR2,
                                         p_tip_pedido          IN VARCHAR2,
                                         p_estado              IN VARCHAR2 DEFAULT NULL) RETURN typ_solicitudClaves;           

  /**
   * Funcion para activar chequeras.
   * Validacion de claves (transaccional, otp, softoken) se mueven al BE.
   *
   * @p_cod_sesion Código de sesión
   * @p_cod_canal Código del canal
   * @p_nro_cuenta Número de cuenta de la chequera
   * @p_nro_inicial Numero inicial de cheque
   * @p_nro_final Numero final de cheque
   * @return resultado de la operacion
   */
  FUNCTION fu_activarchequera(p_cod_sesion  IN bw_aut_sesiones.cod_sesion%TYPE,
                              p_cod_canal   IN bw_aut_sesiones.cod_canal%TYPE,
                              p_modo        IN VARCHAR2,
                              p_nro_cuenta  IN cc_chequeras.nro_cuenta%TYPE,
                              p_nro_inicial IN cc_chequeras.nro_che_inicial%TYPE,
                              p_nro_final   IN cc_chequeras.nro_che_final%TYPE) RETURN typ_ActivacionChequeras;

    /**
     * @ p_cod_sesion Codigo de la Sesion del Cliente
     * @ p_cod_canal Codigo del Canal de la Sesion
     * @ p_cod_pol_seguro Codigo de la Poliza de Seguros
     **/
   FUNCTION fu_obt_pol_seguros(p_cod_sesion IN bw_aut_sesiones.cod_sesion%TYPE,
                                               p_cod_canal IN bw_aut_sesiones.cod_canal%TYPE,
                                               p_nro_poliza IN ge_pol_seguros.nro_poliza%TYPE) RETURN typ_arc_seguros;
   /**
   * @ p_cod_sesion Codigo de la Sesion del Cliente
   * @ p_cod_canal Canal de la Sesion
   * @ p_ente_poliza Cod. Ente Poliza del Cliente
   * @ p_cod_pol_seguro Cod. Poliza del Cliente
   * @ p_arc_base64 Archivo BASE64 - Poliza del Cliente
    **/
   FUNCTION fu_ins_pol_seguros(p_cod_sesion BW_AUT_SESIONES.COD_SESION%TYPE,
                                              p_cod_canal BW_AUT_SESIONES.COD_CANAL%TYPE,
                                              p_nro_poliza GE_POL_SEGUROS.Nro_Poliza%TYPE,
                                              p_arc_base64 BW_POL_ARCHIVOS.ARC_BASE64%TYPE) RETURN typ_mensajerespuesta;
                                              
                                              
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
    * Obtiene la cantidad de puntos por tarjeta, solo de las que generen puntos
    * @param p_sesion sesion del cliente
    * @param p_codCanal codigo del canal
    * @return lista de tarjetas con la cantidad de puntos
   */                                  
   FUNCTION fu_obt_punt_lealtad(p_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                                p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE) RETURN TYP_OBTPUNTOSLEALTAD;
       
   /**
    * Inicia sesion utilizando una clave estatica para el login biometrico
    * @param p_clave clave del cliente generado de forma automatica en fu_reg_cla_privada
    * @param p_cod_persona codigo de persona del cliente
    * @param p_cod_dispositivo identificador del dispositivo
    * @return lista de tarjetas con la cantidad de puntos
   */                                  
   FUNCTION fu_ini_sesion(p_clave          IN VARCHAR2,
                          p_cod_persona   IN VARCHAR2,
                          p_cod_dispositivo IN VARCHAR2) RETURN typ_iniciarSesion;
   
   /**
    * Registra el dispositivo del cliente para login biometrico
    * @param p_sesion sesion del cliente
    * @param p_codCanal codigo del canal
    * @param p_id_dispositivo identificador del registro a insertar
    * @param p_cod_dispositivo identificador unico por instalacion del dispositivo
    * @param p_cla_privada clave privada RSA en base64
    * @param p_marca marca del dispositivo
    * @param p_modelo  modelo del dispositivo
    * @param p_sistema sistema del dispositivo
    * @param p_sis_version version del so del dispositivo
    * @param p_alias alias del dispositivo
    * @param p_modo modo (A: alta, M: modificacion)
    * @return lista de tarjetas con la cantidad de puntos
   */                           
   FUNCTION fu_reg_cla_privada(p_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_id_dispositivo IN BW_CLA_CLI_ACCESO.ID_DISPOSITIVO%TYPE,
                              p_cod_dispositivo IN BW_CLA_CLI_ACCESO.COD_DISPOSITIVO%TYPE,
                              p_cla_privada IN BW_CLA_CLI_ACCESO.CLA_PRIVADA%TYPE,
                              p_marca IN BW_CLA_CLI_ACCESO.MARCA%TYPE,
                              p_modelo IN BW_CLA_CLI_ACCESO.MODELO%TYPE,
                              p_sistema IN BW_CLA_CLI_ACCESO.SISTEMA%TYPE,
                              p_sis_version IN BW_CLA_CLI_ACCESO.SIS_VERSION%TYPE,
                              p_alias IN BW_CLA_CLI_ACCESO.ALIAS%TYPE,
                              p_modo IN VARCHAR2) RETURN typ_regclave;
   
   /**
    * Registra clave de encriptacion para SoftToken
    * @param p_sesion sesion del cliente
    * @param p_cod_canal codigo del canal
    * @param p_nro_serial identificador unico del serial SoftToken
    * @param p_cod_dispositivo identificador unico del dispositivo
    * @param p_cla_encriptacion clave de encriptado AES
    * @param p_vec_inicializacion vector de inicializacion de la clave AES
    * @param p_estado estado del serial SoftToken
    * @return tipo retorno de la funcion
   */                           
   FUNCTION fu_reg_cla_softoken(p_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_serial IN BW_SOF_SERIALES.NRO_SERIAL%TYPE,
                              p_cod_dispositivo IN BW_SOF_SERIALES.COD_DISPOSITIVO%TYPE,
                              p_cla_encriptacion IN BW_SOF_SERIALES.CLA_ENCRIPTACION%TYPE,
                              p_vec_inicializacion IN BW_SOF_SERIALES.VEC_INICIALIZACION%TYPE,
                              p_estado IN BW_SOF_SERIALES.ESTADO%TYPE) 
                              RETURN typ_regsoftokenkey;
   
   /**
    * Obtiene las tarjetas de debito del cliente
    * @param p_sesion sesion del cliente
    * @param p_codCanal codigo del canal
    * @return typ_obtenerDetalleCuentas
   */                           
   FUNCTION fu_obt_tar_debito(p_sesion              IN VARCHAR2,
                              p_codCanal            IN VARCHAR2) RETURN typ_obtenerDetalleCuentas;

      /**
       * Obtiene los CDAs del cliente con los detalles de los cupones
       * @param p_sesion sesion del cliente
       * @param p_codCanal codigo del canal
       * @param p_nroCuentaEspecifica numero de cuenta del cda
      */
      FUNCTION fu_obt_cda_cupones(p_sesion    IN VARCHAR2,
         p_codCanal     IN VARCHAR2, p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDatosCda;
   /**
   * Obtiene los saldos de la cuenta en las fechas que se envian como parametro
   * @param p_sesion sesion del cliente
   * @param p_codCanal codigo del canal
   * @param p_nroCuenta numero de cuenta de la que se quiere descargar el extracto
   * @param p_fechaInicial fecha inicial del extracto
   * @param p_fechaFinal fecha final del extracto
  */
  FUNCTION fu_obt_sal_por_fecha(p_sesion       IN VARCHAR2,
                               p_codCanal      IN VARCHAR2, 
                               p_nroCuenta     IN VARCHAR2 DEFAULT NULL,
                               p_fechaInicial  IN DATE,
                               p_fechaFinal    IN DATE) RETURN typ_saldosdiarios;                                                
   /** Validacion y confirmacion de producto Plazo Fijo Digital
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo Modo de Operacion, D: listado, V: validacion, C: Confirmacion
    * @param p_codigoModulo Modulo de Producto a solicitar
    * @param p_xmlData XML de datos de Producto a solicitar    
    * @return resultado de la operacion
   */
   FUNCTION fu_solicitudPlazoFijo( p_sesion         IN VARCHAR2,
                                   p_codigoCanal    IN VARCHAR2,
                                   p_modo           IN VARCHAR2,
                                   p_codigoModulo   IN NUMBER,
                                   p_xmlData        IN VARCHAR2 ) RETURN typ_preaprobado;

    /** Validacion y confirmacion de Cancelacion Anticipada de Plazo Fijo Digital
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo Modo de Operacion, D: listado, V: validacion, C: Confirmacion
    * @param p_codigoModulo Modulo de Producto a cancelar
    * @param p_xmlData XML de datos de Producto a cancelar    
    * @return resultado de la operacion
   */
   FUNCTION fu_cancelacionPlazoFijo(p_sesion IN VARCHAR2, 
                                    p_codigoCanal IN VARCHAR2, 
                                    p_modo IN VARCHAR2, 
                                    p_codigoModulo IN NUMBER, 
                                    p_xmlData IN VARCHAR2) RETURN typ_preaprobado;
  /**
   * Obtiene los Ahorros a Plazo Fijo APF del cliente con los detalles de los cupones
   * @param p_sesion sesion del cliente
   * @param p_codCanal codigo del canal
   * @param p_nroCuentaEspecifica numero de cuenta del Plazo Fijo
  */
  FUNCTION fu_obt_apf_detalles(p_sesion    IN VARCHAR2,
                               p_codCanal     IN VARCHAR2, 
                               p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDatosApf;

    /**
    * Inserta solicitudes de transferencia
    * @param p_sesion        sesion del cliente
    * @param p_codCanal      codigo del canal
    * p_serial               numero de serial del token
    **/
FUNCTION fu_agregarSoftoken(p_sesion IN VARCHAR2, p_codigoCanal IN VARCHAR2, p_serial IN VARCHAR2,
                            p_modo IN VARCHAR2, p_nro_telefono IN VARCHAR2, p_can_activacion IN VARCHAR2 )
  RETURN TYP_MENSAJESOFTOKEN;
   /**
    * Envia mail de aviso por reintento de pago
    * @param p_token codigo de token de la operacion
    * @param p_cuentaDebito numero de cuenta
    */
   FUNCTION fu_env_mail_avi_reintento(p_token        IN VARCHAR2,
                                      p_cuentaDebito IN VARCHAR2) RETURN NUMBER;

   /* Procedimiento que inserta operaciones de pago de servicios con errores con la portadora o por timeout
    * @param p_cod_token token de pago
    * @param p_nro_documento numero de documento
    * @param p_nro_cuenta numero de cuenta
    * @param p_descripcion descripcion del servicio
    * @param p_portadora nombre de la portadora
    * @param p_monto monto de la operacion
    * @param p_fecha fecha de la operacion
    * @param p_cod_sesion sesion del cliente
    */
    PROCEDURE pr_ins_pag_ser_error(p_cod_token IN bw_pag_ser_error.cod_token%TYPE,
                                   p_nro_documento IN bw_pag_ser_error.nro_documento%TYPE,
                                   p_nro_cuenta IN bw_pag_ser_error.nro_cuenta%TYPE,
                                   p_descripcion IN bw_pag_ser_error.descripcion%TYPE,
                                   p_portadora  IN bw_pag_ser_error.portadora%TYPE,
                                   p_monto  IN bw_pag_ser_error.monto%TYPE,
                                   p_fecha  IN bw_pag_ser_error.fec_hora%TYPE,
                                   p_cod_sesion  IN bw_pag_ser_error.cod_sesion%TYPE);

   /** Validacion y confirmacion Transferencias en lote
    * @param p_sesion  Sesion del Cliente
    * @param p_codigo Canal Numero de caja
    * @param p_modo  V: validacion, C: Confirmacion
    * @param p_numeroLote Agrupador de transferencias
    * @param p_codigoPersona Persona a la cual se le va a acreditar, si corresponde
    * @param p_numeroCuenta Nro de Cuenta a la cual se le va a debitar
    * @param p_monto Monto a transferir
    * @param p_fechaPago Fecha de Pago
    * @param p_nroCuentaDebito Nmero de cuenta a la cual se le va a acreditar
    * @param p_CodigoBanco Banco destino, usar el codigo de BBVA para transferencias internas
    * @param p_nroDocumentoBeneficiario Numero de documento del beneficiario si aplica
    * @param p_nom_beneficiario Nombre del Beneficiario para sipap
    * @param p_codigoMonedaCredito Codigo de la moneda de credito
    * @param p_concepto Concepto
    * @param p_tipo E: Envio S: Solicitud
    * @param p_cantidadTotal Cantidad total a enviar (para limites)
    * @param p_montoTotal Monto total a enviar (para limites)
    * @return TYP_TRANSFERENCIALOTE
    */
    /*FUNCTION fu_transferenciaEnlote(p_sesion                    IN VARCHAR2,
                                    p_codigoCanal               IN NUMBER,
                                    p_modo                      IN VARCHAR2,
                                    p_numeroLote                IN NUMBER,
                                    p_numeroCuenta              IN VARCHAR2,
                                    p_monto                     IN NUMBER,
                                    p_fechaPago                 IN DATE,
                                    p_nroCuentaCredito          IN VARCHAR2,
                                    p_CodigoSwiftBanco          IN varchar2,
                                    p_nroDocumentoBeneficiario  IN VARCHAR2,
                                    p_tipoDocumentoBeneficiario IN NUMBER,
                                    p_nombreBeneficiario        IN VARCHAR2,
                                    p_codigoMonedaCredito       IN VARCHAR2,
                                    p_concepto                  IN VARCHAR2,
                                    p_tipo                      IN VARCHAR2,
                                    p_claveTransaccional        IN VARCHAR2,
                                    p_claveToken                IN VARCHAR2, 
                                    p_cod_solicitud             IN VARCHAR2) 
                                    RETURN TYP_TRANSFERENCIASLOTE;*/

    /**
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de canal
    */
    FUNCTION fu_obt_sol_transferencias( p_session IN VARCHAR2 , p_codCanal IN VARCHAR2, p_tipo IN VARCHAR2, p_estado IN VARCHAR2) RETURN typ_obtsolmultiple ;

    /**
    * @param p_sesion Sesion del Cliente
    * @param p_codCanal Numero de canal
    * @param p_codSolicitud Numero de pedido de transferencia
    * @param p_ctaCredito Numero de cuenta credito
    * @param p_ctaDebito Numero cuenta de debito
    * @param p_modo V: Validacion. C: Confirmacion
    */
    FUNCTION fu_can_sol_transferencias(  p_session IN VARCHAR2 , p_codCanal IN VARCHAR2, p_codSolicitud IN VARCHAR2,
    p_ctaCredito IN VARCHAR2, p_ctaDebito IN VARCHAR2, p_modo IN VARCHAR2 ) RETURN typ_solmultiple;

    /**
    * Obtienen las cuentas de una lista de telefonos
    * @param p_sesion    sesion del cliente
    * @param p_codCanal  codigo del canal
    * @param p_can_contactos cantidad de contactos a leer
    * @param p_contactos String lista de los telefonos
    * @return TYP_OBTCONTACTOSMULTIPLE
    */
    FUNCTION fu_obt_cta_telefonos(p_sesion        IN VARCHAR2,
                                  p_codCanal      IN VARCHAR2,
                                  p_can_contactos IN NUMBER,
                                  p_contactos     IN CLOB) RETURN typ_obtContactosMultiple;

    /**
    * Inserta solicitudes de transferencia
    * @param p_sesion        sesion del cliente
    * @param p_codCanal      codigo del canal
    * @param p_contactos     lista de los contactos a guardar
    * @param p_monto         Monto de la operacion
    * @param p_mensaje       concepto de la operacion
    * @param p_cta_acreditar cuenta donde acreditar
    * @param p_cod_persona   persona solicitante
    * @param p_nro_lote      numero de lote
    * @return VARCHAR2       Devuelve un OK en caso de que todo haya salido bien
    */
     FUNCTION fu_ins_sol_transferencia(p_sesion        IN VARCHAR2,
                                p_codCanal      IN VARCHAR2,
                                p_modo          IN VARCHAR2,
                                p_ctaCredito IN VARCHAR2,
                                p_ctaDebito  IN VARCHAR2,
                                p_monto      IN NUMBER,
                                p_concepto   IN VARCHAR2,
                                p_claveTransaccional IN VARCHAR2,
                                p_claveToken IN VARCHAR2,
                                p_nroPedido  IN VARCHAR2,
                                p_total      IN NUMBER) RETURN typ_transferenciaban;


  /**
   * Validacion y confirmacion de solicitud de ahorro programado.
   *
   * @param p_sesion sesion del cliente
   * @param p_codCanal codigo del canal
   * @param p_modo modo de operacion, V: validar, C: confirmar
   * @param p_tipo tipo de ahorro, M: mensual, T: total, R: refuerzo, C: cancelar, U: modificar
   * @param p_dato codigoMoneda al simular, numero de cuenta a debitar en otros casos
   * @param p_monto monto del ahorro
   * @param p_canCuotas numero de cuotas
   * @param p_descripcion descripcion del ahorro
   * @param p_rangoFecha rango de fechas para el debito
   * @param p_cuentaAhorro cuenta de ahorro programado, para modicacion, cancelacion y refuerzo
  */                               
  FUNCTION fu_solicitarProgramado(p_sesion IN VARCHAR2, 
                                  p_codigoCanal IN VARCHAR2,
                                  p_modo IN VARCHAR2,
                                  p_tipo IN VARCHAR2,
                                  p_dato IN VARCHAR2,
                                  p_monto IN NUMBER,
                                  p_canCuotas IN NUMBER,
                                  p_descripcion IN VARCHAR2,
                                  p_rangoFecha IN VARCHAR2,
                                  p_cuentaAhorro IN VARCHAR2 DEFAULT NULL) RETURN typ_ahoProgramado;
                                  
  /**
   * Validacion y confirmacion de solicitud de adicional de tarjeta.
   *
   * @param p_sesion sesion del cliente
   * @param p_codCanal codigo del canal
   * @param p_modo modo de operacion, V: validar, C: confirmar
   * @param p_numeroTarjeta numero de plastico
   * @param p_tipoSolicitud, 1: adicional, 2: aumento de linea
   * @param p_datosJson datos de entrada segun tipo de solicitud
   * @param p_nombreAdjunto nombre del documento adjunto
   * @param p_adjunto documento adjunto
   * @param p_claveToken clave otp
   */                               
  FUNCTION fu_solicitudTarjeta(p_sesion        IN VARCHAR2, 
                               p_codigoCanal   IN VARCHAR2,
                               p_modo          IN VARCHAR2,
                               p_numeroTarjeta IN VARCHAR2,
                               p_tipoSolicitud IN NUMBER,
                               p_datosJson     IN VARCHAR2,
                               p_nombreAdjunto IN VARCHAR2,
                               p_adjunto       IN BLOB,
                               p_claveToken    IN VARCHAR2) RETURN typ_solTarjetas;

  /**
    * Procesa los pagos de servicios de la portadora Bancard Pago Móvil
    * @p_sesion sesión del cliente
    * @p_codigoCanal código del canal de origen
    * @p_modo modo de invocación
    * @p_cuentaDebito número de cuenta de la que se realiza débito
    * @p_numeroIp ip del cliente
    * @p_sesionServicios sesión de pago de servicios
    * @p_numeroTransaccion número de la transacción
    * @p_servicio código de servicio que se va a pagar
    * @p_terminal número de terminal
    * @p_moneda código de moneda del servicio
    * @p_monto monto a pagar
    * @p_importeComision importe de la comisión por el pago de servicio
    * @p_claveTransaccional clave transaccional ingresada por el cliente
    * @p_claveToken clave token ingresada por el cliente
    * @p_tokenServicios token relacionado al servicio
    * @p_proveedor código de portadora
    * @p_extra datos extra de la transacción
    */
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

    FUNCTION fu_renovarPolizaSeguro(p_sesion       IN VARCHAR2,
                                 p_codigoCanal  IN VARCHAR2,
                                 p_codSeguro    IN NUMBER,
                 p_cuentaDebito IN VARCHAR2)
    RETURN typ_detallesegurorenovado;

    FUNCTION fu_cambiarCanalActivSoftoken(p_sesion IN VARCHAR2, 
                                          p_codigoCanal IN VARCHAR2, 
                                          p_serial IN VARCHAR2,
                                          p_nue_canal IN VARCHAR2) RETURN NUMBER;

   -- actualizacion dato token digital
   FUNCTION fu_asi_nro_token(p_session            IN VARCHAR2,
                             p_codCanal           IN NUMBER,
                             p_modo               IN VARCHAR2,
                             p_nro_telefono       IN VARCHAR2,
                             p_claveTransaccional IN VARCHAR2,
                             p_claveToken         IN VARCHAR2,
                             p_cod_operador       IN VARCHAR2 DEFAULT NULL) RETURN typ_regCelToken;

    /**
    * Obtiene liquidacion de prestamos para reporte
    * @p_cod_canal canal desde el cual se hace la solicitud
    * @p_nro_cuenta cuenta correspondiente al prestamo
    **/
    FUNCTION fu_obt_liq_prestamo(p_sesion IN VARCHAR2, 
                             p_cod_canal IN VARCHAR2,
                             p_nro_cuenta IN VARCHAR2) RETURN typ_infoLiquidacionPrestamo;

      /**
    * Funcion validadora de datos para el pago via Bancard QR
    * @p_sesion sesión del cliente
    * @p_cod_canal código del canal de origen
    * @p_cod_persona código del canal de origen
    * @p_metodo_pago 'debit' para el debito en cuenta. 'credit' para pago con tarjetas
    *     de credito, gourmet o prepaga.
    * @p_monto monto de la transaccion, para el contro de limites y saldo para debito en cuenta.
    * @p_nro_cuenta numero de la cuenta. Obligatorio para metodo de pago [debit|credit]
    * @p_nro_tarjeta nro de tarjeta de credito. Obligatorio para metodo de pago [credit]
    */   
  FUNCTION fu_val_ventas_qr(p_sesion      IN VARCHAR2,
                            p_cod_canal   IN VARCHAR2,
                            p_cod_persona IN ba_personas.cod_persona%TYPE,
                            p_metodo_pago IN VARCHAR,
                            p_monto       IN NUMBER,
                            p_nro_cuenta  IN VARCHAR2,
                            p_nro_tarjeta IN VARCHAR2 DEFAULT NULL)
    RETURN TYP_PAGOSERVICIOS;
    
  FUNCTION fu_con_ventas_qr(
                            p_cod_persona IN ba_personas.cod_persona%TYPE,
                            p_metodo_pago IN VARCHAR,
                            p_monto       IN NUMBER,
                            p_nro_cuenta  IN VARCHAR2,
                            p_nro_tarjeta IN VARCHAR2,
                            p_nro_operacion IN VARCHAR2,
                            p_nro_cuotas IN NUMBER,
                            p_fecha IN DATE,
                            p_descripcion IN VARCHAR2,
                            p_ext_ticket IN VARCHAR2,
                            p_ext_cod_autorizacion IN VARCHAR2,
                            p_comercio IN VARCHAR2,
                            p_sucursal IN VARCHAR2,
                            p_estado IN VARCHAR2)
    RETURN typ_mapa ;
      
    
  /**
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal
   * @p_nroCuentaEspecifica Número de cuenta
   * @return Lista de Tarjetas
   */
    FUNCTION fu_obtenerTarjetasCanceladas(p_sesion              IN VARCHAR2,
                                          p_codCanal            IN VARCHAR2,
                                          p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDetalleCuentas ;
    
FUNCTION fu_transferenciaGnb(p_sesion             IN VARCHAR2,
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
                             p_claveToken         IN VARCHAR2) RETURN typ_transferenciaban;
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
								 p_alias                 IN VARCHAR2 default null ) RETURN typ_transferenciasSnp;
FUNCTION lf_obt_bco_swift(p_cod_banco ge_bancos.cod_banco%TYPE) RETURN varchar2;
   /*Procesar la devolucion de transferencias SPI*/
   FUNCTION fu_DevolucionSPI (p_cod_persona   in varchar2,
                              p_ref_tra_original in varchar2,
                              p_cod_canal      in varchar2,
                              p_modo             in varchar2,
                              p_mot_devol        in varchar2,
                              p_monto            in number) 
                              return typ_devolucionSpi;
       /*Procesar solicitudes de pago SPI*/                          
    FUNCTION fu_SolicitudPagoSPI(p_cod_persona    in varchar2,
                                 p_cod_canal      in varchar2,
                                 p_modo           in varchar2,
                                 p_cod_moneda     in varchar2,--moneda
                                 p_monto          in number, --monto a solicitar
                                 p_cta_sol        in varchar2, --cuenta solicitante
                                 p_cta_rec        in varchar2, --cuenta receptora
                                 p_tip_doc_rec    in varchar2, --tipo doc. del receptor       
                                 p_doc_rec        in varchar2, --documento del receptor
                                 p_nom_rec        in varchar2, --nombre del receptor
                                 p_bic_rec        in varchar2)  --cod. swift del receptor
                                 return typ_solicitudPagoSpi;
    /*Procesar solicitudes de Devolución SPI*/                          
    FUNCTION fu_SolicitudDevolucionSPI(p_cod_persona   in varchar2,
                                      p_ref_tra_original in varchar2,
                                      p_cod_canal      in varchar2,
                                      p_modo             in varchar2,
                                      p_mot_devol        in varchar2,
                                      p_monto            in number)  --cod. swift del receptor
                                       return typ_solicitudDevolucionSpi;
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
   FUNCTION fu_transferencias
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
               p_estercero          IN VARCHAR2 DEFAULT NULL,
               p_consumidor         IN VARCHAR2 DEFAULT NULL,
               p_cod_tra_padre_d    IN NUMBER DEFAULT NULL,
               p_cod_tra_padre_c    IN NUMBER DEFAULT NULL,
               p_cod_mod_padre_d    IN NUMBER DEFAULT NULL,
               p_cod_mod_padre_c    IN NUMBER DEFAULT NULL,
               p_cod_mad_padre_d    IN NUMBER DEFAULT NULL,
               p_cod_mad_padre_c    IN NUMBER DEFAULT NULL,
               p_cod_tra_debito     IN NUMBER DEFAULT NULL,
               p_cod_tra_credito    IN NUMBER DEFAULT NULL                  
            ) RETURN typ_transferencia;
            
   --TCE-521 Inicio
   FUNCTION fu_val_transferencias
            (
               p_codigoPersona      IN VARCHAR2,
               p_codigoEmpresa      IN VARCHAR2,
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
               p_estercero          IN VARCHAR2 DEFAULT NULL,
               p_consumidor         IN VARCHAR2 DEFAULT NULL,
               p_cod_tra_padre_d    IN NUMBER DEFAULT NULL,
               p_cod_tra_padre_c    IN NUMBER DEFAULT NULL,
               p_cod_mod_padre_d    IN NUMBER DEFAULT NULL,
               p_cod_mod_padre_c    IN NUMBER DEFAULT NULL,
               p_cod_mad_padre_d    IN NUMBER DEFAULT NULL,
               p_cod_mad_padre_c    IN NUMBER DEFAULT NULL,
               p_cod_tra_debito     IN NUMBER DEFAULT NULL,
               p_cod_tra_credito    IN NUMBER DEFAULT NULL,
               --TCE-521 Parametros de Debito pag_cta.pr_act_operacion               
               p_v_nro_cta_debito_d        OUT  VARCHAR2,
               p_v_hor_actual_d            OUT  VARCHAR2,
               p_v_cod_mon_debito_d        OUT  VARCHAR2,
               p_v_monto_d                 OUT  NUMBER,
               p_v_cod_tra_padre_d         OUT  NUMBER,
               p_v_cod_trans_debi_d        OUT  NUMBER,
               p_v_nro_operacion_d         OUT  NUMBER,
               p_v_cotizacion_d            OUT  NUMBER,
               p_v_codigoOficinaOrigen_d   OUT  GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE,
               p_v_cod_mod_padre_d         OUT  NUMBER,
               p_v_cod_mad_padre_d         OUT  NUMBER,
               p_v_concepto_d              OUT  VARCHAR2,
               p_v_nro_cta_credito_d       OUT  VARCHAR2,
               p_v_nro_secuencia_d         OUT  NUMBER,
               p_v_fec_valor_d             OUT  DATE,
               p_v_mto_equ_local_d         OUT  NUMBER,
               --TCE-521 Parametros de Credito pag_cta.pr_act_operacion
               p_v_nro_cta_credito_c       OUT  VARCHAR2,
               p_v_hor_actual_c            OUT  VARCHAR2,
               p_v_cod_mon_credito_c       OUT  VARCHAR2,
               p_v_mto_credito_c           OUT  NUMBER,
               p_v_cod_tra_padre_c_c       OUT  NUMBER,
               p_v_cod_trans_cred_c        OUT  NUMBER,
               p_v_nro_operacion_c         OUT  NUMBER,
               p_v_cot_credito_c           OUT  NUMBER,
               p_v_cod_ofi_origen_c        OUT  GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE,
               p_v_cod_mod_padre_c_c       OUT  NUMBER, 
               p_v_cod_mad_padre_c_c       OUT  NUMBER,
               p_v_concepto_c              OUT  VARCHAR2,
               p_v_nro_secuencia_c         OUT  NUMBER, 
               p_v_fec_valor_c             OUT  DATE,
               p_v_mto_equ_local_c         OUT  NUMBER               
               
            ) RETURN typ_transferencia;
   --TCE-521 Fin
      
   FUNCTION fu_obt_hora(p_ind_usuario number) return varchar2;
   PROCEDURE pr_obt_usu_hor_mov_int(p_usuario   in varchar2,p_usu_mov    out varchar2,p_hor_mov    out varchar2);
   
   /**
   * @param p_cod_ente
   * @param p_fec_proceso
   */
  FUNCTION fu_obt_sig_nro_secuencia( p_cod_ente    IN ge_pag_sue_lotes.cod_ente%TYPE,
                                     p_fec_proceso IN ge_pag_sue_lotes.fec_proceso%TYPE)
  RETURN NUMBER;
  
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
   RETURN VARCHAR2;
   
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
                                                                      
END PAW_BEL;
/
