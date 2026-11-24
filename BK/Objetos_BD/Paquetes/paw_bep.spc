CREATE OR REPLACE PACKAGE IT.paw_bep IS
   /**
   * Paquete:         Banca Electronica <br/>
   * Description:     Maneja todas las operaciones de Banca Electronica<br/>
   * @headcom
   */

   -- ######################  FUNCIONES     ############################################
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

   /**
   * Obtiene el detalle de los cheques asociados
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_nroCtaEspecifica Numero de la cuenta
   * @param p_nroInicial Numero inicial del cheque
   */
   /*FUNCTION fu_obtenerDetalleCheques(p_sesion           IN VARCHAR2,
                                     p_codCanal         IN VARCHAR2,
                                     p_nroCtaEspecifica IN VARCHAR2,
                                     p_nroInicial       IN VARCHAR2) RETURN typ_detallesChequeras;*/
   /**
   * Obtiene los detalles de las cuentas
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_nroCuentaEspecifica (opcional) En caso de especificarse se retornara
   * @return typ_obtenerDetalleCuentas
   */
   FUNCTION fu_obtenerDetalleCuentas(p_sesion              IN VARCHAR2,
                                     p_codCanal            IN VARCHAR2,
                                     p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDetalleCuentas;

   /**
   * Obtiene los detalles de las personas autorizadas para chequera en casa
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @return typ_datosChequeCasa
   */
   /*FUNCTION fu_obtenerDatosChequeCasa(p_sesion   IN VARCHAR2,
                                      p_codCanal IN VARCHAR2) RETURN typ_datosChequeCasa;*/
                                       
  /**
   * Obtiene los resumenes de cuentas
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_filtro (opcional) Se implementara mas adelante
   * @return typ_resumenCuentas
   */
   FUNCTION fu_obtenerResumenCuentas(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_filtro   IN VARCHAR2 DEFAULT NULL) RETURN typ_resumenCuentas;
   /**
   * Obtiene los movimientos de cuentas
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_nroCuentaEspecifica Numero de cuenta a retornar
   * @param p_nroPagina Numero de pagina a retornar. 
   * @param p_cantItemsPagina Cantidad de items a retornar
   * @return typ_detalleMovimientos
   */
   FUNCTION fu_obtenerMovimientos(p_sesion              IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                  p_cantDias            IN NUMBER DEFAULT NULL) RETURN typ_detalleMovimientos;
	
   FUNCTION fu_obtenerMovimientos_por_fec(p_sesion   IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                  p_fecha_inicio        IN DATE DEFAULT NULL,
                                  p_fecha_fin           IN DATE DEFAULT NULL) RETURN typ_detalleMovimientos;

   /**
   * Obtiene los movimientos de cuentas
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param P_FECHA fecha del movimiento
   * @param P_NRO_DOCUMENTO Numero de documento
   * @param P_MONTO Monto
   * @param P_TIPO  
   * @param P_FACTURA
   * @return typ_comprobanteMovimiento
   */
   FUNCTION fu_obtComprobanteMovimiento(p_sesion       IN VARCHAR2,
                                        p_codCanal     IN VARCHAR2,
                                        p_nroCuenta    IN VARCHAR2, --nro de cuenta o tarjeta
                                        p_fecha        IN DATE,
                                        p_nroDocumento IN NUMBER,
                                        p_monto        IN NUMBER,
                                        p_tipo         IN VARCHAR2,
                                        p_factura      IN VARCHAR2,
                                        p_nroSecuencia IN NUMBER DEFAULT NULL) RETURN typ_comprobanteMovimiento;

   /**
   * Obtiene los movimientos de cuentas
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @return ttyp_informacionOficinas
   */
   /*FUNCTION fu_obtenerOficinas RETURN typ_informacionOficinas;*/

   /**
   * Obtiene los cheques depositados en la cuenta devueltos
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_nroCuenta Numero de cuenta a retornar
   * @return typ_ChequesDevueltos
   */
   /*FUNCTION fu_obtenerChequesDevueltos(p_sesion    IN VARCHAR2,
                                       p_codCanal  IN VARCHAR2,
                                       p_nroCuenta IN VARCHAR2 DEFAULT NULL) RETURN typ_ChequesDevueltos;*/

   /**
   * Obtiene las chequeras de una cuenta
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_nroCuenta Numero de cuenta a retornar   
   * @return typ_detallesChequeras
   */
   /*FUNCTION fu_obtenerChequeras(p_sesion    IN VARCHAR2,
                                p_codCanal  IN VARCHAR2,
                                p_nroCuenta IN VARCHAR2) RETURN typ_detallesChequeras;*/
   /**
   * Obtiene informacion de un cheque
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_nroCuenta Numero de cuenta a retornar
   * @param p_nroCheque Numero de cheque
   * @return typ_detalleCheque
   */
   /*FUNCTION fu_obtenerCheque(p_sesion    IN VARCHAR2,
                             p_codCanal  IN VARCHAR2,
                             p_nroCuenta IN VARCHAR2,
                             p_nroCheque IN VARCHAR2) RETURN typ_detalleCheque;*/


   /**Obtiene los depositos realizados que no fueron confirmados
     * @param p_sesion Token de Sesion
     * @param p_codCanal Codigo del canal que invoca a ITGF
     * @param p_nroCuenta Numero de cuenta a retornar 
   */
   /*FUNCTION fu_obtenerDepositosConfirmar(p_sesion    IN VARCHAR2,
                                         p_codCanal  IN VARCHAR2,
                                         p_nroCuenta IN VARCHAR2 DEFAULT NULL) RETURN typ_depositosConfirmar;*/
   /**
   * Obtiene informacion de los cheques de una chequera
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_nroCuenta Numero de cuenta a retornar
   * @param p_nroChequeInicial Cheque inicial de la chequera
   * @param p_tipo Tipo de chequera, 1-25H Vista, 2-50H Vista, etc
   * @return typ_Chequera
   */
   /*FUNCTION fu_obtDetallesChequesChequera(p_sesion           IN VARCHAR2,
                                          p_codCanal         IN VARCHAR2,
                                          p_nroCuenta        IN VARCHAR2,
                                          p_nroChequeInicial IN NUMBER,
                                          p_tipo             IN VARCHAR2) RETURN typ_Chequera;*/

   /** Obtiene la cotizacion de las monedas habilitadas en el sistema
   */
   FUNCTION fu_obtenerCotizacion RETURN typ_detallesCotizacion;
   /**
   * Obtiene el listado de transferencias internacionales
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   * @param p_inicio Fecha de inicio, si es null se retornan los ultimos 3 meses
   * @param p_fin Fecha de Fin, si es p_inicio es null no se concidera
   * @return typ_detalleTransInternacional
   */
   /*FUNCTION fu_obtTransInternacional(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_inicio   IN DATE,
                                     p_fin      IN DATE) RETURN typ_detalleTransInternacional;*/
   /**
   * Obtiene la calificacion de riesgo
   * @param p_sesion Token de Sesion
   * @param p_codCanal Codigo del canal que invoca a ITGF
   */
   FUNCTION fu_obtenerCalificacionRiesgo(p_sesion   IN VARCHAR2,
                                         p_codCanal IN VARCHAR2) RETURN typ_calificacionRiesgo;

   /**
    * Se encarga de la Solicitud de chequeras 060
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_modo Modo de operacion V: Verificar, C: Confirmacion
    * @param p_tipoDocumento Tipo de Documento. CI, RUC, etc
    * @param p_numeroDocumento Numero del documento
    * @param p_nombreCompleto Nombre del autorizador
    * @param p_tipoLinea Tipo de Numero de telefono C:Celular, B: Linea Baja
    * @param p_numeroTelefono Numero de telefono
    * @param p_interno Numero de interno (para oficina)
    * @param p_estado Estado del autorizador A: Activo, I: Inactivo
    * @param p_tipDocAnterior Indica si se debe borrar el tipo de documento (Opcional)
    * @param p_nroDocAnterior Indica si se debe borrar el numero de documento (Opcional)
      @return Resultado de la operacion
   */
   /*FUNCTION fu_autorizadorCheque(p_sesion          IN VARCHAR2,
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
                                 p_nroDocAnterior  IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta;*/

   /**
    * Se encarga de la actualizacion de direcciones para entrega de chequera en casa
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_modo Modo de operacion V: Verificacion, C: Confirmacion
    * @param p_direccion Direccion de entrega
    * @param p_codigoCiudad Codigo de ciudad de entrega
    * @param p_codigoBarrio Codigo de barrio de entrega
    * @param p_observacion Observacion de direccion de entrega
    * @param p_numero Numero de direccion de entrega
    * @param p_departamento Departamento de entrega
    * @param p_piso Numero de piso de entrega
    * @param p_edificio Nombre edificio
    * @param p_codigoPostal Codigo postal
    * @param p_claveTransaccional Clave transaccional
    * @param p_claveToken Clave dinamica
      @return Resultado de la operacion
   */
   /*FUNCTION fu_actDireccionCheque(p_sesion             IN VARCHAR2,
                                  p_codCanal           IN VARCHAR2,
                                  p_modo               IN VARCHAR2,
                                  p_direccion          IN VARCHAR2,
                                  p_codigoCiudad       IN NUMBER,
                                  p_codigoBarrio       IN NUMBER,
                                  p_observacion        IN VARCHAR2,
                                  p_numero             IN VARCHAR2,
                                  p_departamento       IN VARCHAR2,
                                  p_piso               IN VARCHAR2,
                                  p_edificio           IN VARCHAR2,
                                  p_codigoPostal       IN VARCHAR2,
                                  p_claveTransaccional IN VARCHAR2,
                                  p_claveToken         IN VARCHAR2) RETURN typ_solicitudClaves;*/
   /**
    * Se encarga de la Solicitud de chequeras 060
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroCuenta Nro de cuenta
    * @param p_codigoTipoChequera Código de tipo de chequera
    * @param p_canHojas Cantidad de hojas
    * @param p_cantidadChequeras Cantidad de chequeras
    * @param p_modo Modo
    * @param p_ofi_retencion Oficina de retención
    * @param p_tip_solicitud Tipo de Solicitud M : Retirar en Mostrador, C : Retirar en Casa
    * @param p_claveTransaccional Clave Transaccional
    * @param p_claveToken Clave dinamica
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
   /*FUNCTION fu_obtenerTiposChequeras(p_sesion    IN VARCHAR2,
                                     p_nroCuenta IN VARCHAR2,
                                     p_codCanal  IN VARCHAR2) RETURN typ_tiposChequeras;*/
   /**
   *Obtiene los saldos de una cuenta
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_nroCuenta Nro de cuenta
   * @param p_dias Cantidad de dias
   * @return Resultado de la operacion
   */
   /*FUNCTION fu_obtenerSaldosCuenta(p_sesion    IN VARCHAR2,
                                   p_codCanal  IN VARCHAR2,
                                   p_nroCuenta IN VARCHAR2,
                                   p_dias      IN NUMBER) RETURN typ_saldosCuentas;*/

   /**
    * Pago por Despachos aduaneros(Sofia): Realiza los pagos a DNA
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroCuenta Nro de cuenta
    * @param p_metodo <ul><il><b>V:</b> Verificación</il><il>  <b>C:</b> Confirmación</il></ul>
    * @param p_monto  Monto de la operación
    * @param p_operacion <ul><il><b> TDA:</b> Pagos despachos aduaneros.</il> <il><b>TID: </b>Pago de IVA despachante</il><il><b>TCA:</b> Pago canon informático.</il> <il><b>TLE:</b> Liquidación de expedientes</il></ul>
    * @param p_campo1 <ul><il><b>TDA:</b> Ruc Importador. </il><il><b>TID:</b> Ruc Importador</il><il><b>TCA:</b> Nro Ticket </il><il><b>TLE:</b> Nro Ticket</il></ul>
    * @param p_campo2 <ul><il><b>TDA:</b> Ruc Despachante.</il> <il><b>TID:</b> Ruc Despachante </il><il><b>TCA:</b> Ruc Despachante </il><il><b>TLE:</b> Ruc Solicitante</il></ul>
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
                          p_claveToken         IN VARCHAR2,
                          p_claveTransaccional IN VARCHAR2,
                          p_nombreImportador   IN VARCHAR2 DEFAULT NULL,
                          p_nombreDespachante  IN VARCHAR2 DEFAULT NULL) RETURN typ_pagoAduana;

   /**
   * Obtiene informacion de Departamentos, Ciudades y Barrios parametrizados en ITGF
   * @param p_tipoPedido Debe ser un valor en: <ul><il><b>D</b>Departamentos</il><il><b>C</b>Ciudades</il><il><b>B</b>Barrios</il></ul>
   * @param p_codPedido Si p_tipoPedido es <ul><il><b>D</b> Debe ser Null</il><il><b>C</b> El codigo del departamento</il><il> <b>B</b> El Código de la ciudad</il></ul>
   * @return typ_datosGeograficos Coleccion de codigos y descripciones
   */
   FUNCTION fu_obtenerDatosGeograficos(p_tipoPedido IN VARCHAR2,
                                       p_codPedido  IN NUMBER DEFAULT NULL) RETURN typ_datosGeograficos;

 
   /** Realiza transferencias a cuentas en las que el cliente es titular
       * @param p_sesion Código de la sesión
       * @param p_codCanal Código del canal
       * @param p_nroCtaDebito Numero de la cuenta del cliente a la cual se realizara el debito
       * @param p_monto Monto de la transferencia a realizar
       * @param p_nroCtaCredito Numero de la cuenta del cliente a la cual se realizara el credito
       * @param p_modo Modo de la operacion <ul><il><b>V:</b> Verificación</il><il>  <b>C:</b> Confirmación</il></ul>
       * @param p_concepto Descripcion de la operacion ingresada por el usuario
       * @param p_cotDebito Por compatibilidad futura
       * @param p_cotCredito Por compatibilidad futura
       * @param p_mtoCredito Monto de credito
   */
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
                                     p_claveToken         IN VARCHAR2) RETURN typ_transferencia_hb;

   /** Realiza transferencias a cuentas de terceros clientes del banco
       * @param p_sesion Código de la sesión
       * @param p_codCanal Código del canal
       * @param p_nroCtaDebito Numero de la cuenta del cliente a la cual se realizara el debito
       * @param p_monto Monto de la transferencia a realizar
       * @param p_nroCtaCredito Numero de la cuenta del cliente a la cual se realizara el credito
       * @param p_modo Modo de la operacion <ul><il><b>V:</b> Verificación</il><il>  <b>C:</b> Confirmación</il></ul>
       * @param p_concepto Descripcion de la operacion ingresada por el usuario
       * @param p_nroContrato numero de contrato prepactado
       * @param p_claveTransaccional Clave transaccional para operaciones
       * @param p_claveToken Clave de Token
   */
   FUNCTION fu_transferenciasTerceros(p_sesion             IN VARCHAR2,
                                      p_codCanal           IN VARCHAR2,
                                      p_nroCtaDebito       IN VARCHAR2,
                                      p_monto              IN NUMBER,
                                      p_nroCtaCredito      IN VARCHAR2,
                                      p_codMonCredito      IN VARCHAR2,
                                      p_modo               IN VARCHAR2,
                                      p_nroDocCredito      IN VARCHAR2,
                                      p_concepto           IN VARCHAR2,
                                      p_nroContrato        IN NUMBER,
                                      p_claveTransaccional IN VARCHAR2,
                                      p_claveToken         IN VARCHAR2) RETURN typ_transferencia_hb;

   /** Realiza transferencias a cuentas donde el cliente es titular y existio un acuerdo previo de cotizacion de cambio
       * @param p_sesion Código de la sesión
       * @param p_codCanal Código del canal
       * @param p_nroCtaDebito Numero de la cuenta del cliente a la cual se realizara el debito
       * @param p_monto Monto de la transferencia a realizar
       * @param p_nroCtaCredito Numero de la cuenta del cliente a la cual se realizara el credito
       * @param p_modo Modo de la operacion <ul><il><b>V:</b> Verificación</il><il>  <b>C:</b> Confirmación</il></ul>
       * @param p_concepto Descripcion de la operacion ingresada por el usuario
       * @param p_claveTransaccional Clave transaccional para operaciones
       * @param p_claveToken Clave de Token
   */
   /*FUNCTION fu_transferenciasConContrato(p_sesion             IN VARCHAR2,
                                         p_codCanal           IN VARCHAR2,
                                         p_nroCtaDebito       IN VARCHAR2,
                                         p_nroCtaCredito      IN VARCHAR2,
                                         p_modo               IN VARCHAR2,
                                         p_nroContrato        IN NUMBER,
                                         p_dirIP              IN VARCHAR2,
                                         p_claveTransaccional IN VARCHAR2,
                                         p_claveToken         IN VARCHAR2) RETURN typ_transferencia;*/

   /**Listado de Facturas
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   */
   /*FUNCTION fu_obtenerListaFacturas(p_sesion   IN VARCHAR2,
                                    p_codCanal IN VARCHAR2) RETURN typ_resumenFacturas;*/

   /**
    *  Extracto por cliente y cuenta  
    * @param p_sesion Código de la sesión
    * @param p_codCanal Código del canal
    * @param p_nroCuenta Numero de cuenta
    * @param p_fechaHasta Fecha final para el extracto
    * @param p_claveToken  Dependiendo de la configuración de limites operativos
    * @param p_claveTransaccional  Dependiendo de la configuración de limites operativos.
    * @return typ_extracto
   */
   FUNCTION fu_extractoARequerimiento(p_sesion             IN VARCHAR2,
                                      p_codcanal           IN VARCHAR2,
                                      p_nroCuenta          IN VARCHAR2,
                                      p_fechaHasta         IN DATE,
                                      p_clavetoken         IN VARCHAR2,
                                      p_clavetransaccional IN VARCHAR2) RETURN typ_extracto_Hb;

  /** 
  * Pago de prestamos
  * @param p_sesion Código de la sesión
  * @param p_codCanal Código del canal
  * @param p_nroPrestamo Nro de prestamo
  * @param p_cuentaDebito Cuenta debito
  * @param p_cantCuotas Cantidad de cuotas a pagar
  * @param p_montoOperacion Monto de la operacion
  * @param p_modo <ul><il><b>V:</b> Verificación</il><il>  <b>C:</b> Confirmación</il></ul>
  * @param p_claveToken  Dependiendo de la configuración de limites operativos
  * @param p_claveTransaccional  Dependiendo de la configuración de limites operativos.
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
                           p_claveTransaccional IN VARCHAR2)
    RETURN typ_pagoPrestamo;
  
  /**
     * Obtiene los detalles de las cuotas de prestamo
     * @param p_sesion Token de Sesion
     * @param p_codCanal Codigo del canal que invoca a ITGF
     * @param p_nroPrestamo Numero del prestamo
     * @return typ_obtCuotasPrestamo
     */
  FUNCTION fu_obtenerCuotasPrestamo(p_sesion      IN VARCHAR2,
                                    p_codCanal    IN VARCHAR2,
                                    p_nroPrestamo IN VARCHAR2)
  RETURN typ_obtCuotasPrestamo;




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
    * @param p_pagoOnline S indica si es Online. N si es en batch
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
    * Obtiene informacion de los saldos de cuentas en un perido de dias
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
   * @return typ_condicionComercial
   */
   FUNCTION fu_obtenerCondicionComercial(p_sesion    IN VARCHAR2,
                                         p_codCanal  IN VARCHAR2,
                                         p_nroCuenta IN VARCHAR2)
                                         RETURN typ_condicionComercial;
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
                                                                                                                           
   /**
   * Area del Cliente
   * @Creado por: Fermín Giménez
   * @Fecha : 13-12-2012
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @return Datos de Area del cliente
   */
   /*FUNCTION fu_obtenerAreaCliente(p_sesion            IN VARCHAR2,
                                  p_codigoCanal       IN VARCHAR2
                                  ) RETURN typ_respuestaAreaCliente;*/
                                  
   /**
   * Historico de Cotizaciones
   * @Creado por: Fermín Giménez
   * @Fecha : 17-12-2012
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_codigoMoneda Código de moneda
   * @param p_diasHistorico Numero de días cuyo histórico se desea
   * @return Datos de Historico de Cotizaciones
   */
   FUNCTION fu_obtenerHisCotizaciones(p_sesion            IN VARCHAR2,
                                      p_codigoCanal       IN VARCHAR2,
                                      p_codigoMoneda      IN VARCHAR2,
                                      p_diasHistorico     IN NUMBER
                                      ) RETURN typ_respuestaHisCotizaciones;


   /**
   * Pago de Servicios
   * @Creado por: 
   * @Fecha : 18-01-2013
   * @param p_sesion Código de la sesión
   * @param p_codCanal Código del canal
   * @param p_modo Modo de la Operacion
   * @param p_cuenta  Numero de Cuenta
   * @param p_numeroIp Numero de direccion IP
   * @param claveTransaccional Clave Transaccional
   * @param claveToken Clave Token
   * @return Datos de la Sesion para Pago de Servicios
   */
   /*FUNCTION fu_pagoServicios( p_sesion      IN VARCHAR2,
                              p_codigoCanal IN VARCHAR2,
                              p_modo        IN VARCHAR2,
                              p_cuenta      IN VARCHAR2,
                              p_numeroIp    IN VARCHAR2,
                              p_claveTransaccional IN VARCHAR2,
                              p_claveToken IN VARCHAR2)
                              RETURN typ_pagoServicios;*/

   /** 
   * Obtener Contrato de Cambio
   *
   * 
   */
   FUNCTION fu_obtenerContratoCambio( p_sesion      IN VARCHAR2,
                                      p_codigoCanal IN VARCHAR2
                                    ) RETURN typ_respuestaContratoCambio;
   /**
    * Transferencias Interbancarias SNP
    * @Fecha : 31-01-2013
    */
   FUNCTION fu_transferenciaInterbancaria(p_sesion                    IN VARCHAR2,
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
                                          p_prioridad                 IN VARCHAR2  DEFAULT NULL,
                                          p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null,
                                          p_alias                 IN VARCHAR2 default null)
                                          RETURN typ_transferenciaInterbancaria;

   /**
    * Consulta de Transferencia Interbancaria SNP
    * @Fecha : 05-02-2013
    */
   /*FUNCTION fu_consultarTransferenciaSnp(p_sesion           IN VARCHAR2,
                                         p_codigoCanal      IN VARCHAR2,
                                         p_fechaDesde       IN DATE,
                                         p_fechaHasta       IN DATE,
                                         p_numeroPagina     IN NUMBER,
                                         p_transaccion      IN NUMBER DEFAULT NULL,
                                         p_numeroCuenta     IN VARCHAR2 DEFAULT NULL,
                                         p_montoDesde       IN NUMBER DEFAULT NULL,
                                         p_montoHasta       IN NUMBER DEFAULT NULL)
                                         RETURN typ_consultarTransferenciaSnp;*/

   /**
    * Cancelación de Transferencia Interbancaria SNP
    * @Fecha : 06-02-2013
    */
   /*FUNCTION fu_cancelarTransferenciaSnp(p_sesion           IN VARCHAR2,
                                        p_codigoCanal      IN VARCHAR2,
                                        p_modo             IN VARCHAR2,
                                        p_numeroReferencia IN VARCHAR2)
                                        RETURN typ_cancelarTransferenciaSnp;*/

   -- Consulta de parametros dinamicos
   FUNCTION fu_obtenerConfiguracion(p_parametro IN VARCHAR2,
                                    p_cod_modulo IN NUMBER DEFAULT NULL,
                                    p_cod_modalidad IN NUMBER DEFAULT NULL,
                                    p_cod_moneda IN VARCHAR2 DEFAULT NULL,
                                    p_cod_oficina IN NUMBER  DEFAULT NULL,
                                    p_cod_sub_modalidad IN VARCHAR2 DEFAULT NULL) RETURN typ_parametrosConfiguracion;
   
   FUNCTION fu_obtenerSnpHorarios(p_sesion IN VARCHAR2,p_codigoCanal in varchar2) RETURN typ_SnpPeriodos;

   /** Adhesión Débito Automático para Préstamo o Tarjeta
    * @param p_sesion Sesion del usuario
    * @param p_codigoCanal Codigo del Canal
    * @param p_numeroCuenta Cuenta del Préstamo/Débito
    * @param p_cuentaDebito Cuenta a debitar
    * @param p_tipoAdhesion T-Tarjeta, P-Préstamo
    * @param p_tipoCobro Solo para tarjetas, M-Monto Mínimo, T-Monto total
    * @return Operacion aprobada/Cancelada
    */
   /*FUNCTION fu_adhesionDebitoAutomatico(p_sesion       IN VARCHAR2,
                                        p_codigoCanal  IN VARCHAR2,
                                        p_numeroCuenta IN VARCHAR2,
                                        p_cuentaDebito IN VARCHAR2,
                                        p_tipoAdhesion IN VARCHAR2,
                                        p_tipoCobro    IN VARCHAR2) RETURN typ_mensajerespuesta; */   
  
    /** Pago de Servicios via WS de Pronet
    * @param p_sesion Sesion del usuario
    * @param p_codigoCanal Codigo del Canal
    * @param p_numeroCuenta Cuenta del Préstamo/Débito
    * @param p_numeroIp Numero de IP desde donde el cliente realizara el pago
    * @param p_servicio Codigo de Servicio (retornado por pronet) 
    * @param p_fecha fecha del pago (retornado por pronet)
    * @param p_hora (retornado por pronet)
    * @param p_numeroTransaccion  (retornado por pronet)
    * @param p_numeroLote (retornado por pronet) 
    * @param p_terminal (retornado por pronet)
    * @param p_moneda (retornado por pronet)
    * @param p_importeTransaccion (retornado por pronet)
    * @param p_importeComision (retornado por pronet)
    * @param p_importeMora (retornado por pronet)
    * @param p_importeInteres (retornado por pronet)
    * @param p_claveTransaccional valor de la clave transaccional 
    * @param p_claveToken  valor del token
    * @param p_claveToken  valor del token
    * @param p_tokenServicios Identificador de pago de servicio
    * @param p_proveedor Codigo de proveedor de servicio, 0-Pronet, 1-Netel, 2-SET
    * @param p_extra Datos extras del proveedor
    * @return typ_pagoServiciosWs 
    */                                       
    FUNCTION fu_pagoServiciosWs(p_sesion             IN VARCHAR2,
                                p_codigoCanal        IN VARCHAR2,
                                p_modo               IN VARCHAR2,
                                p_cuentaDebito       IN VARCHAR2,
                                p_numeroIp           IN VARCHAR2,
                                p_sesionServicios    IN VARCHAR2,
                                p_servicio           IN VARCHAR2,
                                p_numeroTransaccion  IN VARCHAR2,
                                p_numeroLote         IN VARCHAR2,
                                p_terminal           IN VARCHAR2,
                                p_moneda             IN NUMBER,
                                p_monto              IN NUMBER,
                                p_importeComision    IN NUMBER,
                                p_importeMora        IN NUMBER,
                                p_importeInteres     IN NUMBER,
                                p_claveTransaccional IN VARCHAR2,
                                p_claveToken         IN VARCHAR2,
                                p_tokenServicios     IN VARCHAR2,
                                p_proveedor          IN NUMBER,
                                p_extra              IN VARCHAR2 DEFAULT NULL)
     RETURN typ_pagoServiciosWs;

    /*FUNCTION fu_reversarPagoServiciosWs(p_sesion IN VARCHAR2, p_codigoCanal IN VARCHAR2, p_sesionServicios IN VARCHAR2, p_tokenServicios IN VARCHAR2)  RETURN typ_mensajerespuesta;*/

    /** Obtiene la linea de credito del cliente */
    /*FUNCTION fu_obtenerLineaCredito(p_sesion      IN VARCHAR2,
                                    p_codigoCanal IN VARCHAR2) RETURN typ_lineaCredito;*/

   /**
    * fu_obtenerAutorizacionesDelDia, encargada de obtener los movimienos de la banca empresa del dia
    *
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal  
    * @param p_estado Si se recibe, se consulta movimientos de la banca empresa segun el estado,
    *                 A-Anulados, P-Pendientes, C-Confirmados. 
    *                 Si no se recibe el parametro, devuelve todos los estados.
    * @param p_permiso Indica si se debe controlar el permiso por mensaje para la persona
    * @param p_rango Indica la cantidad de días, para el histórico.
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
    * @param p_online Para indicar autorizacion online de tarjetas
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
    *
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal   
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
                               p_claveToken             IN VARCHAR2) RETURN typ_pagoProveedores;----NVB-2232

   /**
    * fu_obtenerHistoricoProveedores, para obtener el historico de pago a proveedores
    
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @param p_fechaInicial Fecha inicio de busqueda de pago (Defecto: Fecha del dia - 60)
    * @param p_fechaFinal Fecha Final de busqueda del pago (Defecto: Fecha del dia)
    * @param p_cuentaBeneficiario Numero o nombre de la cuenta para buscar
    * @param p_nombreEntidad Nombre del banco a buscar
    * @return Resultado de la operacion
   */
   /*FUNCTION fu_obtenerHistoricoProveedores(p_sesion             IN VARCHAR2,
                                           p_codigoCanal        IN VARCHAR2,
                                           p_fechaInicial       IN DATE DEFAULT NULL,
                                           p_fechaFinal         IN DATE DEFAULT NULL,
                                           p_cuentaBeneficiario IN VARCHAR2 DEFAULT NULL,
                                           p_nombreEntidad IN VARCHAR2 DEFAULT NULL) RETURN typ_pagoProveedores;               */

   /**
    * fu_obtenerPermisosUsuario, Obtiene los permisos que posee un usuario
    
    * @param p_sesion Código de la sesión
    * @param p_codigoCanal Código del canal
    * @return Lista de permisos 
   */
   FUNCTION fu_obtenerPermisos(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2) RETURN typ_permisosUsuarios;

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

   /** Verifica la validez de una sesion obtenida previamente de fu_iniciarSesion
   * @param p_sesion identificador de sesion a ser verificado
   * @param p_codCanal identificador del Canal para el cual la sesion fue obtenida
   * @return retorna información de la actividad de sesion o error si no pudo comprobarse su validez
   */
   FUNCTION fu_validarActividad(p_sesion   IN VARCHAR2,
                                p_codCanal IN VARCHAR2) RETURN typ_mensajerespuesta;
                                 
    /*FUNCTION fu_solicitarAdelanto(p_sesion             IN VARCHAR2,
                                   p_codCanal           IN VARCHAR2,
                                   p_modo               IN VARCHAR2  DEFAULT NULL,
                                   p_nroTarjetaCredito  IN VARCHAR2,
                                   p_monto              IN NUMBER, 
                                   p_plazo              IN NUMBER,
                                   p_nro_cta_credito    IN VARCHAR2,
                                   p_claveTransaccional IN VARCHAR2,
                                   p_claveToken         IN VARCHAR2) RETURN typ_adelanto; */
                                   
    /*FUNCTION fu_obtTasasAdelanto RETURN typ_datostasas;*/
    
    /* procedimiento invocado por el API, para reintento de pagos de servicios */
    /*FUNCTION fu_pagoServicioWsActualizar(p_xml IN VARCHAR2) RETURN NUMBER;*/

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
   /*FUNCTION fu_obtenerBancos(p_sesion      IN VARCHAR2,
                             p_codigoCanal IN VARCHAR2,
                             p_tipo        IN VARCHAR2 DEFAULT 'B',
                             p_codigoSwift IN VARCHAR2 DEFAULT NULL,
                             p_banco       IN VARCHAR2 DEFAULT NULL,
                             p_pais        IN VARCHAR2 DEFAULT NULL) RETURN typ_bancos;*/

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
    * @param p_swiftBancoCorresponsal 
    * @param p_codCiudadBcoCorresponsal
    * @param p_codPaisBcoCorresponsal
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
    * @return Resultado de la operacion
    */
   /*FUNCTION fu_transferenciaInternacional(p_sesion                  IN VARCHAR2,
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
                                          p_codPaisBeneficiario     IN NUMBER,
                                          p_codCiudadBeneficiario   IN NUMBER,
                                          p_nombreComprobante       IN VARCHAR2 DEFAULT NULL,
                                          p_comprobante             IN BLOB DEFAULT NULL) RETURN typ_transferencia;*/

   /** Proceso que maneja la validacion y confirmacion del servicio de recaudaciones
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo V: Valida, C: Confirma, A: Autoriza
    * @param p_cuentaCredito
    * @param p_fechaOperacion
    * @param p_cantidad Referencia de cta credito
    * @param p_cuentasDebito Codigo del Banco Receptor
    * @param p_claveTransaccional
    * @param p_claveToken
    * @return Resultado de la operacion
    */
   /*FUNCTION fu_recaudaciones(p_sesion                 IN VARCHAR2,
                             p_codigoCanal            IN VARCHAR2,
                             p_modo                   IN VARCHAR2,
                             p_cuentaCredito          IN VARCHAR2,
                             p_fechaOperacion         IN VARCHAR2,
                             p_cantidad               IN NUMBER,
                             p_cuentasDebito          IN CLOB,
                             p_claveTransaccional     IN VARCHAR2,
                             p_claveToken             IN VARCHAR2) RETURN typ_recaudaciones;*/

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
   /*FUNCTION fu_obtenerHisRecaudaciones(p_sesion        IN VARCHAR2,
                                       p_codigoCanal   IN VARCHAR2,
                                       p_cuentaCredito IN VARCHAR2 DEFAULT NULL,
                                       p_cuentaDebito  IN VARCHAR2 DEFAULT NULL,
                                       p_numeroFactura IN VARCHAR2 DEFAULT NULL,
                                       p_fechaInicial  IN DATE DEFAULT NULL,
                                       p_fechaFinal    IN DATE DEFAULT NULL,
                                       p_estado        IN VARCHAR2 DEFAULT NULL) RETURN typ_recaudaciones;*/

   /** Obtiene productos preaprobados para un cliente
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @return Lista de productos preaprobados
   */
   FUNCTION fu_obtenerPreaprobados(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_listapreaprobado;
                                   
   /** Realiza la solicitud de un producto preaprobado para un cliente
    *
    * @param p_sesion Sesion del Cliente
    * @param p_codigoCanal Numero de caja
    * @param p_modo Modo de operacion. V: validar, C: confirmar
    * @param p_codigoModulo Modulo de la operacion
    * @param p_xmlData Datos del producto a solicitar
    * @return producto preaprobado
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
   /*FUNCTION fu_obtenerDirecciones(p_sesion   IN VARCHAR2,
                                  p_codigoCanal IN VARCHAR2) RETURN typ_direcciones;*/

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
   /*FUNCTION fu_solCancelacionProductos(p_sesion             IN VARCHAR2,
                                       p_codigoCanal        IN VARCHAR2,
                                       p_tip_producto       IN VARCHAR2,
                                       p_nro_producto       IN VARCHAR2,
                                       p_mot_cancelacion    IN VARCHAR2,
                                       p_comentario         IN VARCHAR2 DEFAULT NULL,
                                       p_tel_contacto       IN VARCHAR2,
                                       p_mail_contacto      IN VARCHAR2,
                                       p_cel_contacto       IN VARCHAR2) RETURN typ_mensajerespuesta;*/
                                       
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
    * @param p_tel_proveedor Teléfono del proveedor del producto o servicio canjeado (Opcional)
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
    * @param p_can_ninos Cantidad de ninos para el viaje canjeado (Opcional)
    * @param p_can_adultos Cantidad de adultos para el viaje canjeado (Opcional)
    * @param p_lin_aerea Línea aérea de preferencia del cliente (Opcional)
    * @param p_nro_doc_beneficiario Número de documento del beneficiario(Opcional)
    * @param p_fec_entrada Fecha de entrada para el servicio de hospedajes(Opcional)
    * @param p_cod_verificador Código verificador del canje(Opcional)
    * @param p_condiciones texto de condiciones dinámico(Opcional)
    * @param p_detalles Lista de detalles de canjes (Opcional)
    * @param p_est_canje Estado del canje
    * @param p_comercio Nombre del comercio
    * @return Resultado de la inserción
   */
   /*FUNCTION fu_ins_can_puntos(p_cod_sesion           IN BW_AUT_SESIONES.COD_SESION%TYPE,
                              p_cod_canal            IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_tarjeta          IN BW_CANJES.NRO_TARJETA%TYPE,
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
                              p_comercio             IN BW_CANJES.COMERCIO%TYPE DEFAULT NULL) RETURN TYP_CANJE;*/

   /**
   * Obtiene una operación de canje de puntos
   *
   * @param p_cod_sesion Sesión del cliente
   * @param p_cod_canal Código del canal
   * @param p_nro_canje Número de identificación del canje de puntos
   * @return El registro del canje realizado
   */
   /*FUNCTION fu_obt_can_puntos(p_cod_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE) RETURN TYP_CANJE;*/

   /**
   * Valida la clave token
   *
   * @param p_cod_sesion Sesión del cliente
   * @param p_cod_canal Código del canal
   * @param p_cla_token Clave token a validar
   * @param p_modo Modo 'V' pedir a VASCO envío de challenge SMS , 'C' verificar la clave OTP con VASCO
   * @return Resultado de la validación
   */  
   /*FUNCTION fu_val_clave_otp(p_cod_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                             p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                             p_cla_token  IN VARCHAR2,
                             p_modo       IN VARCHAR2) RETURN TYP_MENSAJERESPUESTA;*/
                             
   /**
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal   
   * @return Lista de Etiqueta Valor
   */                                    
   /*FUNCTION fu_obtInformeSemestral(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_listaEtiquetaValor;*/

   /*FUNCTION fu_acreditacionGourmet(p_sesion IN VARCHAR2, 
                                   p_codigoCanal IN VARCHAR2, 
                                   p_codigoEnte IN NUMBER, 
                                   p_modoControl IN VARCHAR2,
                                   p_nroCuentaDebito IN VARCHAR2, 
                                   p_canTarjetasParaCredito IN NUMBER, 
                                   p_canRegistrosLeidos IN NUMBER,
                                   p_montoTotal IN ge_movimientos.monto%TYPE, 
                                   p_parametros IN CLOB, 
                                   p_claveTransaccional IN VARCHAR2, 
                                   p_claveToken IN VARCHAR2) RETURN typ_acrGourmet;*/
        
/*FUNCTION fu_acreditacionGourmetHis(p_sesion IN VARCHAR2, 
                                   p_codigoCanal IN VARCHAR2, 
                                   p_nro_tarjeta IN VARCHAR2, 
                                   p_fechaInicial IN DATE,
                                   p_fechaFinal IN DATE,
                                   p_nroDocumento IN VARCHAR2, 
                                   p_nombre IN VARCHAR2, 
                                   p_nroOperacion IN VARCHAR2,
                                   p_parametro IN VARCHAR2 DEFAULT 'H') RETURN typ_acrGourmet;*/

    /**
    * Retorna datos de pizarra para el simulador WEB
    * @p_sesion Código de sesión
    * @p_codCanal Código de canal   
    * @p_apikey key de la APP que llama al servicio
    */
    /*FUNCTION fu_simuladorPrestamo(
                                 p_codigoCanal IN VARCHAR2,
                                 p_moneda      IN VARCHAR2,
                                 p_apikey     IN VARCHAR2) RETURN TYP_SIMULADOR;*/

   /* @param p_codToken Id. del pago de servicio usado como clave en la busqueda para el update
    * @param p_montoComision Monto de la comision indicado en la factura
    */                                
   /*FUNCTION fu_pagoServicioUpdateWs(p_codSesion     IN VARCHAR2,
                                    p_codCanal      IN VARCHAR2,
                                    p_modo          IN VARCHAR2 default 'F',
                                    p_ticket        IN CLOB, 
                                    p_codPersona    IN VARCHAR2, 
                                    p_codEmpresa    IN VARCHAR2 default NULL, 
                                    p_serConcepto   IN VARCHAR2,
                                    p_codToken      IN VARCHAR2, 
                                    p_montoComision IN NUMBER) RETURN typ_mensajeRespuesta;*/    
                                    
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
   /*FUNCTION fu_obtFacturasPagoServiciosWs(p_codSesion      IN VARCHAR2,
                                          p_codCanal       IN VARCHAR2,
                                          p_modo           IN VARCHAR2 default 'L',                                              
                                          p_codPersona     IN VARCHAR2, 
                                          p_codToken       IN VARCHAR2 default NULL,
                                          p_codEmpresa     IN VARCHAR2 default NULL, 
                                          p_numeroPagina   IN NUMBER DEFAULT NULL,
                                          p_cantidadPagina IN NUMBER DEFAULT NULL) RETURN typ_facturasServicios;*/                                                                                                
 /**
   * Retorna un listado de los seguros contratados para el usuario con la sesion ingresada
   * @p_sesion Codigo de sesion
   * @p_codCanal Codigo de canal
   * @return Lista de Etiqueta Valor
   **/
   /*FUNCTION fu_obtenerSeguros(p_sesion      IN VARCHAR2,
                              p_codigoCanal IN VARCHAR2,
                              p_codigoSeguro IN VARCHAR2 DEFAULT NULL) RETURN TYP_SEGUROS;*/


  /**
   * Suscripcion de empleados
   *
   * @param p_sesion Sesión del cliente
   * @param p_codigoCanal Código del canal
   * @param p_modo Modo V : validacion carga manua, L: validacion carga archivo, C: confirmacion
   * @param p_codigoMoneda Moneda del ente
   * @param p_notificacionMail Correo de notificacion para el ente
   * @param p_cantidad Cantidad de lineas a leer
   * @param p_parametros Parametros recibidos
   * @param p_claveTransaccional Clave transaccional
   * @param p_claveToken Clave OTP
   * @return Resultado de la validación
   */                                     
  /* FUNCTION fu_altaEmpleados(p_sesion             IN VARCHAR2,
                             p_codigoCanal        IN VARCHAR2,
                             p_modo               IN VARCHAR2,
                             p_codigoMoneda       IN VARCHAR2,
                             p_notificacionMail   IN VARCHAR2,
                             p_cantidad           IN NUMBER,
                             p_parametros         IN CLOB,                             
                             p_claveTransaccional IN VARCHAR2,
                             p_claveToken         IN VARCHAR2) RETURN typ_altaEmpleados;*/

  /**
   * Historico de alta de funcionarios
   *
   * @param p_sesion Sesión del cliente
   * @param p_codigoCanal Código del canal
   * @param p_fechaInicio Busqueda for fecha inicial
   * @param p_fechaFin Busqueda for fecha final
   * @param p_nombreDocumento Busqueda por Primer Nombre, Primer apellido o numero de documento
   * @param p_numeroOperacion Busqueda por numero de solicitud
   * @param p_numeroPagina Numero de pagina a devolver
   * @param p_cantidadPagina Cantidad de items a retornar por pagina
   * @return Resultado de la validación
   */ 
   /*FUNCTION fu_altaEmpleadosHis(p_sesion             IN VARCHAR2,
                                p_codigoCanal        IN VARCHAR2,
                                p_fechaInicio        IN DATE DEFAULT NULL,
                                p_fechaFin           IN DATE DEFAULT NULL,
                                p_nombreDocumento    IN VARCHAR2 DEFAULT NULL,
                                p_numeroOperacion    IN NUMBER DEFAULT NULL,
                                p_numeroPagina       IN NUMBER DEFAULT NULL,
                                p_cantidadPagina     IN NUMBER DEFAULT NULL) RETURN typ_altaEmpleados;*/

   /**
    * Solicitar la baja de impresion de extractos
    * 
    * 
    * @p_sesion Codigo de sesion
    * @p_codCanal Codigo de canal
    * @p_modo V-Validar, C-confirmar
    * @p_retenerCuentas retener CC/AH
    * @p_retenerTarjetas retener tarjetas
    * @p_numeroTarjeta Numero de plastico de tarjeta a solicitar
    * @return Datos asociados
    */
   /*FUNCTION fu_extractoDigital(p_sesion             IN VARCHAR2,
                               p_codigoCanal        IN VARCHAR2,
                               p_modo               IN VARCHAR2,
                               p_retenerCuentas     IN VARCHAR2,
                               p_retenerTarjetas    IN VARCHAR2,
                               p_numeroTarjeta      IN VARCHAR2 DEFAULT NULL) RETURN typ_datoscliente;*/
 
--add a pedido de José
    FUNCTION fu_obt_lis_cas_spi(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2
                            ) RETURN typ_LisAliasSpi;
    FUNCTION fu_devolucionSpi(p_sesion              IN VARCHAR2,
                            p_codCanal          IN VARCHAR2,
                            p_modo                 IN VARCHAR2,
                            p_ref_tra_original     IN VARCHAR2,
                            p_mot_devol       IN VARCHAR2 DEFAULT NULL,
                            p_monto                IN NUMBER   DEFAULT NULL,
                            p_cod_solicitud        IN NUMBER   DEFAULT NULL,
                            p_claveTransaccional   IN VARCHAR2
                            ) RETURN typ_devolucionSpi;
                                      
   FUNCTION fu_obt_lis_sol_spi(p_sesion        IN VARCHAR2,
                              p_codCanal      IN VARCHAR2,
                              p_offset        in number,
                              p_cantRegistros in number)
                              RETURN typ_LisSolicitudesSpi;
   FUNCTION fu_obt_lista_spi(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
   return typ_transSpi;
   
   FUNCTION fu_obt_lis_sol_dev(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
  return typ_LissoldevolucionesSpi; 
  
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
                                p_bic_rec              in varchar2 --cod. swift del receptor
                                )  
    return typ_solicitudPagoSpi;
    
   FUNCTION fu_rch_solicitud(p_sesion              in varchar2,
                            p_codCanal          in varchar2,
                            p_modo              in varchar2,
                            p_cod_solicitud     in ge_spi_solicitudes.cod_sol_spi%type,
                            p_cod_rechazo       in ge_spi_solicitudes.tip_rechazo%type
                            ) RETURN typ_aut_solicitud;
                            
    FUNCTION fu_aut_solicitud(p_sesion             IN VARCHAR2,
                            p_codCanal           IN VARCHAR2,
                            p_modo               IN VARCHAR2,
                            p_cod_solicitud      in ge_spi_solicitudes.cod_sol_spi%type,
                            p_monto              IN NUMBER   DEFAULT NULL,
                            p_claveTransaccional IN VARCHAR2)
                            return typ_aut_solicitud;
                            
        
FUNCTION fu_SolicitudDevolucionSPI(p_sesion   in varchar2,
                            p_codCanal            in varchar2,
                            p_modo                in varchar2,
                            p_ref_tra_original    in varchar2,
                            p_mot_devol           in varchar2 default null,
                            p_monto                in number   default null,
                            p_cod_solicitud        in number   default null
                            ) RETURN typ_solicitudDevolucionSpi;

   FUNCTION fu_solicitud_regcas (p_sesion     in varchar2,
                        p_codCanal          in varchar2,
                        p_modo              in varchar2,
                        p_tip_ide_cli       in VARCHAR2,
                        p_val_ide_cli       in VARCHAR2,
                        p_tip_ide_alias     in VARCHAR2,
                        p_val_ide_alias     in VARCHAR2,
                        p_nro_cuenta        in VARCHAR2,
                        p_cta_defecto       in VARCHAR2,
                        p_tip_accion          in VARCHAR2) return typ_solicitudaltacas;
                                    
   FUNCTION fu_sol_con_cas (p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_tip_consulta  IN VARCHAR2,
                            p_tip_identificador IN VARCHAR2,
                            p_val_identificador IN VARCHAR2) return typ_sol_con_cas;
                            
   FUNCTION fu_res_con_cas (p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_nro_referencia IN VARCHAR2) return typ_res_con_cas;

   FUNCTION fu_obt_lis_sol_pag(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)return typ_lisSolPagosSpi;
                            
   FUNCTION fu_eliminar_regcas(p_sesion        in varchar2,
                              p_codcanal      in varchar2,
                              p_modo          in varchar2 default 'A',
                              p_ali_record_id in varchar2,
                              p_cta_record_id in varchar2,
                              p_accion        in varchar2 default 'ELI') return typ_solicitudaltacas;
                             
   FUNCTION fu_Solicitud_EdiCAS(p_cli_recorid in varchar2,
                              p_cta_recorid in varchar2,
                              p_ali_recorid in varchar2,
                              p_accion      in varchar2,
                              p_canal       in VARCHAR2) return typ_solicitudPagoSpi;

   FUNCTION fu_obtenerMovimientos_por_fec_ext(p_sesion   IN VARCHAR2,
                                              p_codCanal            IN VARCHAR2,
                                              p_nroCuentaEspecifica IN VARCHAR2,
                                              p_nroPagina           IN NUMBER DEFAULT NULL,
                                              p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                              p_fecha_inicio        IN DATE DEFAULT NULL,
                                              p_fecha_fin           IN DATE DEFAULT NULL) RETURN typ_detalleMovimientos;                              

--add a pedido de José
END;
/

