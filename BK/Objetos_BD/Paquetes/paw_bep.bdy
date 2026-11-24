CREATE OR REPLACE PACKAGE BODY IT.paw_bep IS
   /**
   * Paquete:         Banca Electronica <br/>
   * Description:     Maneja todas las operaciones de Banca Electronica<br/>
   * @headcom
   */

   /** Crea la sesion de un usuario, valida la clave del mismo.
   * @param p_password Clave del Usuario
   * @param p_dato Informacion del usuario, puede ser Documento, Pasaporte, RUC, 
   *                Nro de Cuenta, codigo de cliente o Nro de Tarjeta de Credito
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
                             p_codCanal       IN VARCHAR2) RETURN typ_iniciarSesion IS
   BEGIN
      RETURN paw_bem.fu_iniciarSesion(p_password, p_dato, p_tipoDato, p_nroDocEmpresa, p_tipoDocEmpresa, p_codCanal);
   END;

   FUNCTION fu_eliminarSesion(p_sesionUsuario IN VARCHAR2) RETURN typ_mensajeRespuesta IS
   BEGIN
      RETURN paw_bem.fu_eliminarSesion(p_sesionUsuario);
   END;

   FUNCTION fu_cambiarClaveAcceso(p_sesion      IN VARCHAR2,
                                  p_codCanal    IN VARCHAR2,
                                  p_claveActual IN VARCHAR2,
                                  p_claveNueva  IN VARCHAR2) RETURN typ_mensajeRespuesta IS
   BEGIN
      RETURN paw_bem.fu_cambiarClaveAcceso(p_sesion, p_codCanal, p_claveActual, p_claveNueva);
   END;

   FUNCTION fu_cambiarClaveTransaccion(p_sesion      IN VARCHAR2,
                                       p_codCanal    IN VARCHAR2,
                                       p_claveActual IN VARCHAR2,
                                       p_claveNueva  IN VARCHAR2) RETURN typ_mensajeRespuesta IS
   BEGIN
      RETURN paw_bem.fu_cambiarClaveTransaccion(p_sesion, p_codCanal, p_claveActual, p_claveNueva);
   END;
   
   /*FUNCTION fu_obtenerDetalleCheques(p_sesion           IN VARCHAR2,
                                     p_codCanal         IN VARCHAR2,
                                     p_nroCtaEspecifica IN VARCHAR2,
                                     p_nroInicial       IN VARCHAR2) RETURN typ_detallesChequeras IS
   BEGIN
      RETURN paw_bem.fu_obtenerDetalleCheques(p_sesion, p_codCanal, p_nroCtaEspecifica, p_nroInicial);
   END;*/

   FUNCTION fu_obtenerDetalleCuentas(p_sesion              IN VARCHAR2,
                                     p_codCanal            IN VARCHAR2,
                                     p_nroCuentaEspecifica IN VARCHAR2 DEFAULT NULL) RETURN typ_obtenerDetalleCuentas IS
   BEGIN
      RETURN paw_bem.fu_obtenerDetalleCuentas(p_sesion, p_codCanal, p_nroCuentaEspecifica);
   END;

   /*FUNCTION fu_obtenerDatosChequeCasa(p_sesion   IN VARCHAR2,
                                      p_codCanal IN VARCHAR2) RETURN typ_datosChequeCasa IS
   BEGIN
      RETURN paw_bem.fu_obtenerDatosChequeCasa(p_sesion, p_codCanal);
   END;*/

   FUNCTION fu_obtenerResumenCuentas(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_filtro   IN VARCHAR2 DEFAULT NULL) RETURN typ_resumenCuentas IS
   BEGIN
      RETURN paw_bem.fu_obtenerResumenCuentas(p_sesion, p_codCanal, p_filtro);
   END;

   FUNCTION fu_obtenerMovimientos(p_sesion              IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
				  p_cantDias            IN NUMBER DEFAULT NULL) RETURN typ_detalleMovimientos IS
   BEGIN
      RETURN paw_bem.fu_obtenerMovimientos(p_sesion, p_codCanal, p_nroCuentaEspecifica, p_nroPagina, p_cantItemsPagina, p_cantDias);
   END;

   FUNCTION fu_obtenerMovimientos_por_fec(p_sesion              IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                  p_fecha_inicio        IN DATE DEFAULT NULL,
                                  p_fecha_fin           IN DATE DEFAULT NULL) RETURN typ_detalleMovimientos IS
   BEGIN
      RETURN paw_bem.fu_obtenerMovimientos_por_fec(p_sesion, p_codCanal, p_nroCuentaEspecifica, p_nroPagina, p_cantItemsPagina, p_fecha_inicio, p_fecha_fin);
   END;

   FUNCTION fu_obtComprobanteMovimiento(p_sesion       IN VARCHAR2,
                                        p_codCanal     IN VARCHAR2,
                                        p_nroCuenta    IN VARCHAR2, --nro de cuenta o tarjeta
                                        p_fecha        IN DATE,
                                        p_nroDocumento IN NUMBER,
                                        p_monto        IN NUMBER,
                                        p_tipo         IN VARCHAR2,
                                        p_factura      IN VARCHAR2,
                                        p_nroSecuencia IN NUMBER DEFAULT NULL) RETURN typ_comprobanteMovimiento IS
   BEGIN
      RETURN paw_bem.fu_obtComprobanteMovimiento(p_sesion, p_codCanal, p_nroCuenta, p_fecha, p_nroDocumento, p_monto, p_tipo, p_factura, p_nroSecuencia);
   END;

   /*FUNCTION fu_obtenerOficinas RETURN typ_informacionOficinas IS
   BEGIN
      RETURN paw_bem.fu_obtenerOficinas();
   END;*/

   /*FUNCTION fu_obtenerChequesDevueltos(p_sesion    IN VARCHAR2,
                                       p_codCanal  IN VARCHAR2,
                                       p_nroCuenta IN VARCHAR2 DEFAULT NULL) RETURN typ_ChequesDevueltos IS
   BEGIN
      RETURN paw_bem.fu_obtenerChequesDevueltos(p_sesion, p_codcanal, p_nroCuenta);
   END;*/

   /*FUNCTION fu_obtenerDepositosConfirmar(p_sesion    IN VARCHAR2,
                                         p_codCanal  IN VARCHAR2,
                                         p_nroCuenta IN VARCHAR2 DEFAULT NULL) RETURN typ_depositosConfirmar IS
   BEGIN
      RETURN paw_bem.fu_obtenerDepositosConfirmar(p_sesion, p_codcanal, p_nroCuenta);
   END;*/

   /*FUNCTION fu_obtenerChequeras(p_sesion    IN VARCHAR2,
                                p_codCanal  IN VARCHAR2,
                                p_nroCuenta IN VARCHAR2) RETURN typ_detallesChequeras IS
   BEGIN
      RETURN paw_bem.fu_obtenerChequeras(p_sesion, p_codCanal, p_nroCuenta);
   END;*/

   /*FUNCTION fu_obtDetallesChequesChequera(p_sesion           IN VARCHAR2,
                                          p_codCanal         IN VARCHAR2,
                                          p_nroCuenta        IN VARCHAR2,
                                          p_nroChequeInicial IN NUMBER,
                                          p_tipo             IN VARCHAR2) RETURN typ_Chequera IS
   BEGIN
      RETURN paw_bem.fu_obtDetallesChequesChequera(p_sesion, p_codCanal, p_nroCuenta, p_nroChequeInicial, p_tipo);
   END;*/

   /*FUNCTION fu_obtenerCheque(p_sesion    IN VARCHAR2,
                             p_codCanal  IN VARCHAR2,
                             p_nroCuenta IN VARCHAR2,
                             p_nroCheque IN VARCHAR2) RETURN typ_detalleCheque IS
   BEGIN
      RETURN paw_bem.fu_obtenerCheque(p_sesion, p_codCanal, p_nrocuenta, p_nroCheque);
   END;*/

   FUNCTION fu_obtenerCotizacion RETURN typ_detallesCotizacion IS
   BEGIN
      RETURN paw_bem.fu_obtenerCotizacion;  
   END;

   /*FUNCTION fu_obtTransInternacional(p_sesion   IN VARCHAR2,
                                     p_codCanal IN VARCHAR2,
                                     p_inicio   IN DATE,
                                     p_fin      IN DATE) RETURN typ_detalleTransInternacional IS
   BEGIN
      RETURN paw_bem.fu_obtTransInternacional(p_sesion, p_codCanal, p_inicio, p_fin);
   END;*/

   FUNCTION fu_obtenerCalificacionRiesgo(p_sesion   IN VARCHAR2,
                                         p_codCanal IN VARCHAR2) RETURN typ_calificacionRiesgo IS
   BEGIN
      RETURN paw_bem.fu_obtenerCalificacionRiesgo(p_sesion, p_codCanal);
   END;

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
                                 p_nroDocAnterior  IN VARCHAR2 DEFAULT NULL) RETURN typ_mensajerespuesta IS
   BEGIN
      RETURN paw_bem.fu_autorizadorCheque(p_sesion, p_codCanal, p_modo, p_tipoDocumento, p_numeroDocumento, p_nombreCompleto, p_tipoLinea, p_numeroTelefono, p_interno, p_estado, p_tipDocAnterior, p_nroDocAnterior);
   END;*/

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
                                  p_claveToken         IN VARCHAR2) RETURN typ_solicitudClaves IS
   BEGIN
      RETURN paw_bem.fu_actDireccionCheque(p_sesion, p_codCanal, p_modo, p_direccion, p_codigoCiudad, p_codigoBarrio, p_observacion, p_numero, p_departamento, p_piso, p_edificio, p_codigoPostal, p_claveTransaccional, p_claveToken);
   END;*/

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
                                 p_claveToken         IN VARCHAR2) RETURN typ_mensajeResChequera IS
   BEGIN
      RETURN paw_bem.fu_solicitarChequera(p_sesion, p_codCanal, p_nroCuenta, p_codigoTipoChequera, p_canHojas, p_cantidadChequeras, p_modo, p_ofi_retencion, p_tip_solicitud, p_claveTransaccional, p_claveToken);
   END;

   /*FUNCTION fu_obtenerTiposChequeras(p_sesion    IN VARCHAR2,
                                     p_nroCuenta IN VARCHAR2,
                                     p_codCanal  IN VARCHAR2) RETURN typ_tiposChequeras IS
   BEGIN
      RETURN paw_bem.fu_obtenerTiposChequeras(p_sesion, p_nroCuenta, p_codCanal);
   END;*/

   /*FUNCTION fu_obtenerSaldosCuenta(p_sesion    IN VARCHAR2,
                                   p_codCanal  IN VARCHAR2,
                                   p_nroCuenta IN VARCHAR2,
                                   p_dias      IN NUMBER) RETURN typ_saldosCuentas IS
   BEGIN
      RETURN paw_bem.fu_obtenerSaldosCuenta(p_sesion, p_codCanal, p_nroCuenta, p_dias);
   END;*/

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
                          p_nombreDespachante  IN VARCHAR2 DEFAULT NULL) RETURN typ_pagoAduana IS
   BEGIN
      RETURN paw_bem.fu_pagoaduana(p_sesion, p_codCanal, p_cuentaDebito, p_metodo, p_monto, p_operacion, p_campo1, p_campo2,p_nombreImportador, p_nombreDespachante, p_claveToken, p_claveTransaccional);
   END;

    FUNCTION fu_obtenerDatosGeograficos(p_tipoPedido IN VARCHAR2,
                                        p_codPedido  IN NUMBER DEFAULT NULL) RETURN typ_datosGeograficos IS
    BEGIN
       RETURN paw_uti.fu_obtenerDatosGeograficos(p_tipoPedido, p_codPedido);
    END;

 

  /*FUNCTION fu_obtenerListaFacturas(p_sesion   IN VARCHAR2,
                                   p_codCanal IN VARCHAR2) RETURN typ_resumenFacturas IS
  BEGIN
     RETURN paw_bem.fu_obtenerListaFacturas(p_sesion, p_codCanal);
  END;*/

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
                                    p_claveToken         IN VARCHAR2) 
                                    RETURN typ_transferencia_hb IS
  BEGIN
     RETURN it.paw_bem.fu_transferenciasPropias(p_sesion => p_sesion,
                                                p_codCanal => p_codCanal,
                                                p_nroCtaDebito => p_nroCtaDebito,
                                                p_monto => p_monto,
                                                p_nroCtaCredito => p_nroCtaCredito,
                                                p_modo => p_modo,
                                                p_concepto => p_concepto,
                                                p_cotDebito => p_cotDebito,
                                                p_cotCredito => p_cotCredito,
                                                p_mtoCredito => p_mtoCredito,
                                                p_claveTransaccional => p_claveTransaccional,
                                                p_claveToken => p_claveToken,
                                                p_nro_mov_pendiente => null);
  END;

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
                                     p_claveToken         IN VARCHAR2)
                                     RETURN typ_transferencia_hb IS
  BEGIN
     RETURN paw_bem.fu_transferenciasTerceros(p_sesion => p_sesion,
                                                 p_codCanal => p_codCanal,
                                                 p_nroCtaDebito => p_nroCtaDebito,
                                                 p_monto => p_monto,
                                                 p_nroCtaCredito => p_nroCtaCredito,
                                                 p_codMonCredito => p_codMonCredito,
                                                 p_modo => p_modo,
                                                 p_nroDocCredito => p_nroDocCredito,
                                                 p_concepto => p_concepto,
                                                 p_nroContrato => p_nroContrato,
                                                 p_claveTransaccional => p_claveTransaccional,
                                                 p_claveToken => p_claveToken,
                                                 p_nro_mov_pendiente => null);
  END;

  /*FUNCTION fu_transferenciasConContrato(p_sesion             IN VARCHAR2,
                                        p_codCanal           IN VARCHAR2,
                                        p_nroCtaDebito       IN VARCHAR2,
                                        p_nroCtaCredito      IN VARCHAR2,
                                        p_modo               IN VARCHAR2,
                                        p_nroContrato        IN NUMBER,
                                        p_dirIP              IN VARCHAR2,
                                        p_claveTransaccional IN VARCHAR2,
                                        p_claveToken         IN VARCHAR2) 
                                        RETURN typ_transferencia IS
  BEGIN
     RETURN paw_bem.fu_transferenciasConContrato(p_sesion, p_codCanal, p_nroCtaDebito, p_nroCtaCredito, p_modo, p_nroContrato, p_dirIP, p_claveTransaccional, p_claveToken);
  END;*/

   
   FUNCTION fu_extractoARequerimiento(p_sesion             IN VARCHAR2,
                                      p_codcanal           IN VARCHAR2,
                                      p_nroCuenta          IN VARCHAR2,
                                      p_fechaHasta         IN DATE,
                                      p_clavetoken         IN VARCHAR2,
                                      p_clavetransaccional IN VARCHAR2)
                                      RETURN typ_extracto_hb IS
    BEGIN
       RETURN paw_bem.fu_extractoARequerimiento(p_sesion, p_codCanal, p_nroCuenta, p_fechaHasta, p_claveToken, p_claveTransaccional);
    END;

   -- Pago de Préstamo
   FUNCTION fu_pagoPrestamo(p_sesion             IN VARCHAR2,
                            p_codCanal           IN VARCHAR2,
                            p_nroPrestamo        IN VARCHAR2,
                            p_cuentaDebito       IN VARCHAR,
                            p_cantCuotas         IN VARCHAR2,
                            p_montoOperacion     IN VARCHAR2,
                            p_modo               IN VARCHAR2,
                            p_claveToken         IN VARCHAR2,
                            p_claveTransaccional IN VARCHAR2)
                            RETURN typ_pagoPrestamo IS
   BEGIN
     RETURN paw_bem.fu_pagoPrestamo(p_sesion,
                                    p_codCanal,
                                    p_nroPrestamo,
                                    p_cuentaDebito,
                                    p_cantCuotas,
                                    p_montoOperacion,
                                    p_modo,
                                    p_claveToken,
                                    p_claveTransaccional);
   END;
   
   -- Obtener Cuotas de Préstamo 
   FUNCTION fu_obtenerCuotasPrestamo(p_sesion      IN VARCHAR2,
                                     p_codCanal    IN VARCHAR2,
                                     p_nroPrestamo IN VARCHAR2)
                                     RETURN typ_obtCuotasPrestamo IS
   BEGIN
     RETURN paw_bem.fu_obtenerCuotasPrestamo(p_sesion,
                                             p_codCanal,
                                             p_nroPrestamo);
   END;
   
  -- Pago de Tarjeta de Crédito
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
                                  p_pagoOnline             IN VARCHAR2)
                                  RETURN typ_pagoTarjetaCredito IS
  BEGIN
     RETURN paw_bem.fu_pagoTarjetaCredito(p_sesion, p_codCanal, p_nroTarjetaCredito, p_cuentaDebito, p_modo, p_nroSobre, p_importeEfectivo, p_importeChequeBanco, p_importeChequeOtroBanco, p_importeDebito, p_totalPago, p_claveToken, p_claveTransaccional,p_pagoOnline);
  END;

  -- Obtener Saldos Diarios
  FUNCTION fu_obtenerSaldosDiarios(p_sesion       IN VARCHAR2,
                                   p_codCanal     IN VARCHAR2,
                                   p_numeroCuenta IN VARCHAR2,
                                   p_cantidadDias IN NUMBER)
                                   RETURN typ_detalleSaldosDiarios IS
  BEGIN
    RETURN paw_bem.fu_obtenerSaldosDiarios(p_sesion, p_codCanal,p_numeroCuenta, p_cantidadDias);
  END;

  -- Obtener Condicion Comercial
  FUNCTION fu_obtenerCondicionComercial(p_sesion    IN VARCHAR2,
                                        p_codCanal  IN VARCHAR2,
                                        p_nroCuenta IN VARCHAR2)
                                        RETURN typ_condicionComercial IS
  BEGIN
    RETURN paw_bem.fu_obtenerCondicionComercial(p_sesion, p_codCanal, p_nroCuenta);
  END;

  -- Obtener Tarjetas Adicionales
  FUNCTION fu_obtenerTarjetasAdicionales(p_sesion            IN VARCHAR2,
                                         p_codCanal          IN VARCHAR2,
                                         p_nroTarjetaCredito IN VARCHAR2)
                                         RETURN typ_resumenTarjetasAdicionales IS
  BEGIN
     RETURN paw_bem.fu_obtenerTarjetasAdicionales(p_sesion, p_codCanal, p_nroTarjetaCredito);
  END;

  -- Obtener Area del Cliente   
  /*FUNCTION fu_obtenerAreaCliente( p_sesion            IN VARCHAR2,
                                  p_codigoCanal       IN VARCHAR2)
                                  RETURN typ_respuestaAreaCliente IS
  BEGIN
     RETURN paw_bem.fu_obtenerAreaCliente(p_sesion, p_codigoCanal);
  END; */
   
  -- Obtener Historico de Cotizaciones
  FUNCTION fu_obtenerHisCotizaciones( p_sesion            IN VARCHAR2,
                                      p_codigoCanal       IN VARCHAR2,
                                      p_codigoMoneda      IN VARCHAR2,
                                      p_diasHistorico     IN NUMBER
                                      ) RETURN typ_respuestaHisCotizaciones IS
  BEGIN
     RETURN paw_bem.fu_obtenerHisCotizaciones(p_sesion, p_codigoCanal, p_codigoMoneda, p_diasHistorico);
  END;

  -- Pago de Servicios
  /*FUNCTION fu_pagoServicios(p_sesion      IN VARCHAR2,
                            p_codigoCanal IN VARCHAR2,
                            p_modo        IN VARCHAR2,
                            p_cuenta      IN VARCHAR2,
                            p_numeroIp    IN VARCHAR2,
                            p_claveTransaccional IN VARCHAR2,
                            p_claveToken IN VARCHAR2)
                            RETURN typ_pagoServicios IS
  BEGIN
     RETURN paw_bem.fu_pagoServicios(p_sesion, p_codigoCanal, p_modo, p_cuenta, p_numeroIp, p_claveTransaccional, p_claveToken);
  END;*/
                             
  FUNCTION fu_obtenerContratoCambio( p_sesion      IN VARCHAR2,
                                     p_codigoCanal IN VARCHAR2
                                    ) RETURN typ_respuestaContratoCambio IS
  BEGIN
    RETURN paw_bem.fu_obtenerContratoCambio(p_sesion, p_codigoCanal);
  END;

  -- Transferencias Interbancarias SNP
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
                                         p_prioridad                 IN VARCHAR2 DEFAULT NULL,
                                         p_nro_mov_pendiente  IN bw_mov_pendientes.nro_documento%type default null,
                                         p_alias                 IN VARCHAR2 default null)
                                         RETURN typ_transferenciaInterbancaria IS
  BEGIN
    RETURN paw_bem.fu_transferenciaInterbancaria(p_sesion, p_codigoCanal, p_modo, p_codigoSwift, p_numeroCuentaCredito, p_numeroCuentaDebito, p_codigoMonedaCredito, p_montoCredito, p_fechaOperacion, p_cargos, p_numeroDocumentoCredito, p_nombreBeneficiario, p_direccionBeneficiario, p_numeroContrato, p_concepto, p_numeroIp, p_tipoMensaje, p_tipoDocumentoBeneficiario, p_numeroReferencia, p_montoDebito, p_cotizacionDebito, p_cotizacionCredito, p_claveToken, p_claveTransaccional,p_prioridad,p_nro_mov_pendiente,p_alias);

  END;

  -- Consulta de Transferencia Interbancaria SNP
  /*FUNCTION fu_consultarTransferenciaSnp(p_sesion           IN VARCHAR2,
                                        p_codigoCanal      IN VARCHAR2,
                                        p_fechaDesde       IN DATE,
                                        p_fechaHasta       IN DATE,
                                        p_numeroPagina     IN NUMBER,
                                        p_transaccion      IN NUMBER DEFAULT NULL,
                                        p_numeroCuenta     IN VARCHAR2 DEFAULT NULL,
                                        p_montoDesde       IN NUMBER DEFAULT NULL,
                                        p_montoHasta       IN NUMBER DEFAULT NULL)
                                        RETURN typ_consultarTransferenciaSnp IS
  BEGIN
     RETURN paw_bem.fu_consultarTransferenciaSnp(p_sesion, p_codigoCanal, p_fechaDesde, p_fechaHasta, p_numeroPagina, p_transaccion,p_numeroCuenta, p_montoDesde, p_montoHasta);
  END;*/

  --Cancelación de Transferencia Interbancaria SNP
  /*FUNCTION fu_cancelarTransferenciaSnp(p_sesion           IN VARCHAR2,
                                       p_codigoCanal      IN VARCHAR2,
                                       p_modo             IN VARCHAR2,
                                       p_numeroReferencia IN VARCHAR2)
                                       RETURN typ_cancelarTransferenciaSnp IS
  BEGIN
     RETURN paw_bem.fu_cancelarTransferenciaSnp(p_sesion, p_codigoCanal, p_modo, p_numeroReferencia);
  END;*/

  FUNCTION fu_obtenerConfiguracion(p_parametro IN VARCHAR2,
                                   p_cod_modulo IN NUMBER DEFAULT NULL,
                                   p_cod_modalidad IN NUMBER DEFAULT NULL,
                                   p_cod_moneda IN VARCHAR2 DEFAULT NULL,
                                   p_cod_oficina IN NUMBER  DEFAULT NULL,
                                   p_cod_sub_modalidad IN VARCHAR2 DEFAULT NULL) RETURN typ_parametrosConfiguracion IS
  BEGIN
     RETURN paw_bem.fu_obtenerConfiguracion(p_parametro, p_cod_modulo, p_cod_modalidad, p_cod_moneda, p_cod_oficina, p_cod_sub_modalidad);
  END;

  FUNCTION fu_obtenerSnpHorarios(p_sesion IN VARCHAR2,p_codigoCanal in varchar2) RETURN typ_SnpPeriodos is
  begin 
  return paw_bem.fu_obtenerSnpHorarios(p_sesion ,p_codigoCanal ); 
  end;
  
    -- Adhesion debito automatico Tarjetas o Prestamos
  /*FUNCTION fu_adhesionDebitoAutomatico(p_sesion       IN VARCHAR2,
                                       p_codigoCanal  IN VARCHAR2,
                                       p_numeroCuenta IN VARCHAR2,
                                       p_cuentaDebito IN VARCHAR2,
                                       p_tipoAdhesion IN VARCHAR2,
                                       p_tipoCobro    IN VARCHAR2) RETURN typ_mensajerespuesta IS
  BEGIN
    RETURN paw_bem.fu_adhesionDebitoAutomatico(p_sesion, p_codigoCanal, p_numeroCuenta, p_cuentaDebito, p_tipoAdhesion, p_tipoCobro); 
  END;*/
  
  -- Pago de servicios
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
    RETURN typ_pagoServiciosWs IS
  BEGIN
    return paw_bem.fu_pagoServiciosWs(p_sesion,
                              p_codigoCanal,
                              p_modo,
                              p_cuentaDebito,
                              p_numeroIp,
                              p_sesionServicios,
                              p_servicio,
                              p_numeroTransaccion,
                              p_numeroLote,
                              p_terminal,
                              p_moneda,
                              p_monto,
                              p_importeComision,
                              p_importeMora,
                              p_importeInteres,
                              p_claveTransaccional,
                              p_claveToken,
                              p_tokenServicios,
                              p_proveedor,
                              p_extra);
  end;
  
  -- Reversion de pago de servicios
  /*FUNCTION fu_reversarPagoServiciosWs(p_sesion IN VARCHAR2, p_codigoCanal IN VARCHAR2, p_sesionServicios IN VARCHAR2, p_tokenServicios IN VARCHAR2)  RETURN typ_mensajerespuesta is
  begin
     return paw_bem.fu_reversarPagoServiciosWs(p_sesion, p_codigoCanal, p_sesionServicios, p_tokenServicios);

  end;*/
  
  -- Obtiene la linea de credito del cliente
  /*FUNCTION fu_obtenerLineaCredito(p_sesion      IN VARCHAR2,
                                  p_codigoCanal IN VARCHAR2) RETURN typ_lineaCredito is
  BEGIN
     RETURN paw_bem.fu_obtenerLineaCredito(p_sesion, p_codigoCanal);
  END; */      

  -- Obtiene las autorizaciones del dia
  FUNCTION fu_obtenerAutorizacionesDelDia(p_sesion      IN VARCHAR2,
                                          p_codigoCanal IN VARCHAR2,
                                          p_estado      IN VARCHAR2 DEFAULT NULL,
                                          p_permiso     IN VARCHAR2 DEFAULT 'N',
                                          p_rango       IN NUMBER DEFAULT 0,
                                          p_canItems    IN NUMBER DEFAULT NULL,
                                          p_nroPagina   IN NUMBER DEFAULT NULL ) 
                                          RETURN typ_autorizacionesDelDia IS
  BEGIN
    RETURN paw_bem.fu_obtenerAutorizacionesDelDia(p_sesion, p_codigoCanal, p_estado, p_permiso, p_rango, p_canItems, p_nroPagina);
  END;                                   

  -- Autorizar, Rechazar, Imprimir, Detallar una operacion
  FUNCTION fu_autorizarOperacion(p_sesion             IN VARCHAR2,
                                 p_codigoCanal        IN VARCHAR2,
                                 p_modo               IN VARCHAR2,
                                 p_numeroDocumento    IN NUMBER,
                                 p_comentario         IN VARCHAR2,
                                 p_online             IN VARCHAR2,
                                 p_claveTransaccional IN VARCHAR2,
                                 p_claveToken         IN VARCHAR2)
                                 RETURN typ_autorizaOperacion IS
  BEGIN
    RETURN paw_bem.fu_autorizarOperacion(p_sesion, p_codigoCanal, p_modo, p_numeroDocumento, p_comentario, p_online, p_claveTransaccional, p_claveToken);
  END;

  -- Obtener detalle de la autorizacion pendiente, cancelada, procsada
  FUNCTION fu_obtenerDetalleAutorizacion(p_sesion          IN VARCHAR2,
                                         p_codigoCanal     IN VARCHAR2,
                                         p_numeroDocumento IN bw_mov_pendientes.nro_documento%TYPE,
                                         p_estado          IN VARCHAR2 DEFAULT 'P',
                                         p_fecha           IN DATE DEFAULT NULL) RETURN typ_detalleAutorizacion IS
  BEGIN
     RETURN paw_bem.fu_obtenerDetalleAutorizacion(p_sesion, p_codigoCanal, p_numeroDocumento, p_estado, p_fecha);
  END;

  -- Pago de salarios
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
                           p_fecPago                IN DATE)
                           RETURN typ_pagoSalarios IS
  BEGIN
    RETURN paw_bem.fu_pagoSalarios(p_sesion, p_codigoCanal, p_codigoEnte, p_modoControl, p_codigoMoneda, p_montoTotal, p_tipoRemuneracion, p_cantCuentasParaCredito, p_canRegistrosLeidos, p_parametros, p_claveTransaccional, p_claveToken, p_fecPago);
  END;

  -- Pago a proveedores
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
                              p_claveToken             IN VARCHAR2)
                              RETURN typ_pagoProveedores IS----NVB-2232
   BEGIN
     RETURN paw_bem.fu_pagoProveedores_dev(p_sesion, p_codigoCanal, p_codigoEnte, p_modoControl, p_cuentaDebito, p_fechaPago, p_tipoPago, p_cantOrdenes, p_cantFacturas, p_parametros, p_par_errores, p_claveTransaccional, p_claveToken);
   END;

   /*FUNCTION fu_obtenerHistoricoProveedores(p_sesion             IN VARCHAR2,
                                           p_codigoCanal        IN VARCHAR2,
                                           p_fechaInicial       IN DATE DEFAULT NULL,
                                           p_fechaFinal         IN DATE DEFAULT NULL,
                                           p_cuentaBeneficiario IN VARCHAR2 DEFAULT NULL,
                                           p_nombreEntidad      IN VARCHAR2 DEFAULT NULL) 
                                           RETURN typ_pagoProveedores IS
   BEGIN
     RETURN paw_bem.fu_obtenerHistoricoProveedores(p_sesion, p_codigoCanal, p_fechaInicial, p_fechaFinal, p_cuentaBeneficiario, p_nombreEntidad);
   END;*/

   FUNCTION fu_obtenerPermisos(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2) RETURN typ_permisosUsuarios IS
   BEGIN
      RETURN paw_bem.fu_obtenerPermisos(p_sesion, p_codigoCanal);
   END;

   FUNCTION fu_obtenerHisPagoNomina(p_sesion          IN VARCHAR2,
                                    p_codigoCanal     IN VARCHAR2,
                                    p_fec_ini         IN DATE DEFAULT NULL,
                                    p_fec_fin         IN DATE DEFAULT NULL,
                                    p_nro_cuenta      IN VARCHAR2 DEFAULT NULL,
                                    p_beneficiario    IN VARCHAR2 DEFAULT NULL,
                                    p_parametro       IN VARCHAR2 DEFAULT 'H') RETURN typ_pagosalarios is
   BEGIN
      RETURN paw_bem.fu_obtenerHisPagoNomina(p_sesion, p_codigoCanal,p_fec_ini,p_fec_fin,p_nro_cuenta,p_beneficiario,p_parametro);
   END;

   FUNCTION fu_validarActividad(p_sesion   IN VARCHAR2,
                                p_codCanal IN VARCHAR2) RETURN typ_mensajerespuesta IS
   BEGIN
      RETURN paw_bem.fu_validarActividad(p_sesion, p_codCanal);
   END;
   /*FUNCTION fu_solicitarAdelanto(p_sesion IN VARCHAR2, p_codCanal IN VARCHAR2, p_modo IN VARCHAR2 DEFAULT NULL, p_nroTarjetaCredito IN VARCHAR2,
                                 p_monto IN NUMBER, p_plazo IN NUMBER, p_nro_cta_credito IN VARCHAR2, p_claveTransaccional IN VARCHAR2,
                                 p_claveToken IN VARCHAR2) RETURN typ_adelanto IS
   BEGIN
      RETURN paw_bem.fu_solicitarAdelanto(p_sesion,
                                          p_codCanal,
                                          p_modo,
                                          p_nroTarjetaCredito,
                                          p_monto,
                                          p_plazo,
                                          p_nro_cta_credito,
                                          p_claveTransaccional,
                                          p_claveToken);
   END;*/
   
   /*FUNCTION fu_obtTasasAdelanto RETURN typ_datostasas IS
   BEGIN
      RETURN paw_bem.fu_obtTasasAdelanto;
   END;*/

   /*FUNCTION fu_pagoServicioWsActualizar(p_xml IN VARCHAR2) RETURN NUMBER IS
   BEGIN    
      RETURN paw_bem.fu_pagoServicioWsActualizar(p_xml);
   END;*/
   
   FUNCTION fu_obtenerFeriados(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_fechaInicio   IN DATE,
                               p_fechaFin      IN DATE) RETURN typ_listaFeriados IS
   BEGIN
      RETURN paw_bem.fu_obtenerFeriados(p_sesion, p_codigoCanal, p_fechaInicio, p_fechaFin);
   END;

   /*FUNCTION fu_obtenerBancos(p_sesion      IN VARCHAR2,
                             p_codigoCanal IN VARCHAR2,
                             p_tipo        IN VARCHAR2 DEFAULT 'B',
                             p_codigoSwift IN VARCHAR2 DEFAULT NULL,
                             p_banco       IN VARCHAR2 DEFAULT NULL,
                             p_pais        IN VARCHAR2 DEFAULT NULL) RETURN typ_bancos IS
   BEGIN
      RETURN paw_bem.fu_obtenerBancos(p_sesion, p_codigoCanal, p_tipo, p_codigoSwift, p_banco, p_pais);
   END;*/

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
                                          p_comprobante             IN BLOB DEFAULT NULL) RETURN typ_transferencia IS
   BEGIN
      RETURN paw_bem.fu_transferenciaInternacional(p_sesion,
                                                   p_codigoCanal,
                                                   p_modo,
                                                   p_nombreBeneficiario,
                                                   p_direccionBeneficiario,
                                                   p_cuentaCredito,
                                                   p_codigoBanco,
                                                   p_nombreBanco,
                                                   p_codigoSwift,
                                                   p_codigoPais,
                                                   p_codigoCiudad,
                                                   p_codBancoCorresponsal,
                                                   p_nombreBancoCorresponsal,
                                                   p_swiftBancoCorresponsal,
                                                   p_codCiudadBcoCorresponsal,
                                                   p_codPaisBcoCorresponsal,
                                                   p_codigoMonedaCredito,
                                                   p_montoCredito,
                                                   p_numeroContrato,
                                                   p_cuentaDebito,
                                                   p_tipoCargo,
                                                   p_plazo,
                                                   p_tipoMotivo,
                                                   p_tipoFondo,
                                                   p_tipoFinanciacion,
                                                   p_referenciaBeneficiario,
                                                   p_observaciones,
                                                   p_claveTransaccional,
                                                   p_claveToken,
                                                   p_codPaisBeneficiario,
                                                   p_codCiudadBeneficiario,
                                                   p_comprobante,
                                                   p_nombreComprobante);
   END;*/                                         

   /*FUNCTION fu_recaudaciones(p_sesion                 IN VARCHAR2,
                             p_codigoCanal            IN VARCHAR2,
                             p_modo                   IN VARCHAR2,
                             p_cuentaCredito          IN VARCHAR2,
                             p_fechaOperacion         IN VARCHAR2,
                             p_cantidad               IN NUMBER,
                             p_cuentasDebito          IN CLOB,
                             p_claveTransaccional     IN VARCHAR2,
                             p_claveToken             IN VARCHAR2) RETURN typ_recaudaciones IS
   BEGIN
      RETURN paw_bem.fu_recaudaciones(p_sesion, p_codigoCanal, p_modo, p_cuentaCredito, p_fechaOperacion, p_cantidad, p_cuentasDebito, p_claveTransaccional, p_claveToken);
   END;*/

   /*FUNCTION fu_obtenerHisRecaudaciones(p_sesion        IN VARCHAR2,
                                       p_codigoCanal   IN VARCHAR2,
                                       p_cuentaCredito IN VARCHAR2 DEFAULT NULL,
                                       p_cuentaDebito  IN VARCHAR2 DEFAULT NULL,
                                       p_numeroFactura IN VARCHAR2 DEFAULT NULL,
                                       p_fechaInicial  IN DATE DEFAULT NULL,
                                       p_fechaFinal    IN DATE DEFAULT NULL,
                                       p_estado        IN VARCHAR2 DEFAULT NULL) RETURN typ_recaudaciones IS
   BEGIN
      RETURN paw_bem.fu_obtenerHisRecaudaciones(p_sesion, p_codigoCanal, p_cuentaCredito, p_cuentaDebito, p_numeroFactura, p_fechaInicial, p_fechaFinal, p_estado);
   END;*/

   FUNCTION fu_obtenerPreaprobados(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_listapreaprobado IS
   BEGIN
      RETURN paw_bem.fu_obtenerPreaprobados(p_sesion, p_codigoCanal);
   END;

   FUNCTION fu_solicitudPreaprobados(p_sesion         IN VARCHAR2,
                                     p_codigoCanal    IN VARCHAR2,
                                     p_modo           IN VARCHAR2,
                                     p_codigoModulo   IN NUMBER,
                                     p_xmlData        IN VARCHAR2) RETURN typ_preaprobado IS
   BEGIN
      RETURN paw_bem.fu_solicitudPreaprobados(p_sesion, p_codigoCanal, p_modo, p_codigoModulo, p_xmlData);
   END;
   
   /*FUNCTION fu_obtenerDirecciones(p_sesion   IN VARCHAR2,
                                  p_codigoCanal IN VARCHAR2) RETURN typ_direcciones IS
   BEGIN
      RETURN paw_bem.fu_obtenerDirecciones(p_sesion, p_codigoCanal);
   END; */  
   
    /*FUNCTION fu_solCancelacionProductos(p_sesion            IN VARCHAR2,
                                       p_codigoCanal        IN VARCHAR2,
                                       p_tip_producto       IN VARCHAR2,
                                       p_nro_producto       IN VARCHAR2,
                                       p_mot_cancelacion    IN VARCHAR2,
                                       p_comentario         IN VARCHAR2 DEFAULT NULL,
                                       p_tel_contacto       IN VARCHAR2,
                                       p_mail_contacto      IN VARCHAR2,
                                       p_cel_contacto       IN VARCHAR2) RETURN typ_mensajerespuesta IS
   BEGIN
      RETURN paw_bem.fu_solCancelacionProductos(p_sesion, p_codigoCanal, p_tip_producto, p_nro_producto, p_mot_cancelacion, p_comentario, p_tel_contacto, p_mail_contacto, p_cel_contacto);
   END;*/
   
   FUNCTION fu_obtenerTarjetas(p_sesion      IN VARCHAR2,
                               p_codigoCanal IN VARCHAR2,
                               p_relacion    IN VARCHAR2 DEFAULT NULL) RETURN typ_resumentarjetas IS
   BEGIN
      RETURN paw_bem.fu_obtenerTarjetas(p_sesion, p_codigoCanal, p_relacion);
   END;  

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
                              p_comercio             IN BW_CANJES.COMERCIO%TYPE DEFAULT NULL) RETURN TYP_CANJE IS
   BEGIN
      RETURN paw_bem.fu_ins_can_puntos(p_cod_sesion, p_cod_canal, p_nro_tarjeta, p_cat_producto, p_nom_producto, p_des_producto, p_tel_contacto, p_ema_contacto, p_ema_des_notificacion, p_cantidad, p_puntos, p_tel_proveedor, p_showroom, p_direccion, p_rec_autorizada, p_per_autorizada, p_cod_tip_autorizado, p_nro_doc_autorizado, p_hor_inicio, p_hor_fin, p_ben_titular, p_beneficiario, p_turno, p_sol_ida, p_fec_salida, p_fec_retorno, p_fec_flexible, p_cla_servicio, p_can_ninos, p_can_adultos, p_lin_aerea, p_nro_doc_beneficiario, p_fec_entrada, p_cod_verificador, p_condiciones, p_detalles, p_est_canje, p_comercio);
   END;*/

   /*FUNCTION fu_obt_can_puntos(p_cod_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                              p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                              p_nro_canje  IN BW_CANJES.NRO_CANJE%TYPE) RETURN TYP_CANJE IS
   BEGIN
      RETURN paw_bem.fu_obt_can_puntos(p_cod_sesion, p_cod_canal, p_nro_canje);
   END;*/
   
   /*FUNCTION fu_val_clave_otp(p_cod_sesion IN BW_AUT_SESIONES.COD_SESION%TYPE,
                             p_cod_canal  IN BW_AUT_SESIONES.COD_CANAL%TYPE,
                             p_cla_token  IN VARCHAR2,
                             p_modo       IN VARCHAR2) RETURN TYP_MENSAJERESPUESTA IS
   BEGIN
      RETURN paw_bem.fu_val_clave_otp(p_cod_sesion, p_cod_canal, p_cla_token, p_modo);
   END;*/
   
   /**
   * @p_sesion Código de sesión
   * @p_codCanal Código de canal   
   * @return Lista de Etiqueta Valor
   */                                    
   /*FUNCTION fu_obtInformeSemestral(p_sesion      IN VARCHAR2,
                                   p_codigoCanal IN VARCHAR2) RETURN typ_listaEtiquetaValor IS
    BEGIN
      RETURN paw_bem.fu_obtInformeSemestral(p_sesion, p_codigoCanal);
    END;*/

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
                                   p_claveToken IN VARCHAR2)   RETURN typ_acrGourmet is
   begin
      return paw_bem.fu_acreditacionGourmet(p_sesion , p_codigoCanal, p_codigoEnte , p_modoControl,
                                p_nroCuentaDebito , p_canTarjetasParaCredito , p_canRegistrosLeidos ,
                                p_montoTotal , p_parametros , p_claveTransaccional , p_claveToken );
   end;*/

   /*FUNCTION fu_acreditacionGourmetHis(p_sesion IN VARCHAR2, 
                                      p_codigoCanal IN VARCHAR2, 
                                      p_nro_tarjeta IN VARCHAR2, 
                                      p_fechaInicial IN DATE,
                                      p_fechaFinal IN DATE,
                                      p_nroDocumento IN VARCHAR2, 
                                      p_nombre IN VARCHAR2, 
                                      p_nroOperacion IN VARCHAR2,
                                      p_parametro IN VARCHAR2) RETURN typ_acrGourmet is
   begin
      return paw_bem.fu_acreditacionGourmetHis(p_sesion, p_codigoCanal,  p_nro_tarjeta, p_fechaInicial, p_fechaFinal,p_nroDocumento, p_nombre, p_nroOperacion, p_parametro);
   end;*/

   -- Retorna el listado de pizarra para el simulador de prestamos
   /*FUNCTION fu_simuladorPrestamo(
                                 p_codigoCanal IN VARCHAR2,
                                 p_moneda      IN VARCHAR2,
                                 p_apikey     IN VARCHAR2) RETURN TYP_SIMULADOR IS
   BEGIN
        return paw_bem.fu_simuladorPrestamo(p_codigoCanal,p_moneda ,p_apikey);                         
   END;*/

    /**
    * Actualiza la tabla bw_pag_servicios para almacenar la factura 
    * del pago de servicio enviada por la portadora
    * @param p_codSesion Sesion del cliente
    * @param p_codCanal Codigo del canal
    * @param p_modo Modo de invocacion, 'F' es guardar facturas
    * @param p_ticket Factura de la portadora (en TXT)
    * @param p_codPersona Nro de cliente PF logueado en la sesion
    * @param p_codEmpresa Nro de cliente PJ logueado en la sesion (si el pago es de empresa)
    * @param p_serConcepto Concepto del pago de servicios
    * @param p_codToken Id. del pago de servicio usado como clave en la busqueda para el update
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
                                    p_montoComision IN NUMBER) RETURN typ_mensajeRespuesta IS
    BEGIN
       RETURN paw_bem.fu_pagoServicioUpdateWs(p_codSesion, p_codCanal, p_modo, p_ticket, p_codPersona, p_codEmpresa, p_serConcepto, p_codToken, p_montoComision);
    END;*/

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
    * @param p_numeroPagina Nro de paginas
    * @param p_montoComision Monto de la comision indicado en la factura
    */                                
   /*FUNCTION fu_obtFacturasPagoServiciosWs(p_codSesion      IN VARCHAR2,
                                          p_codCanal       IN VARCHAR2,
                                          p_modo           IN VARCHAR2 default 'L',                                              
                                          p_codPersona     IN VARCHAR2, 
                                          p_codToken       IN VARCHAR2 default NULL,
                                          p_codEmpresa     IN VARCHAR2 default NULL, 
                                          p_numeroPagina   IN NUMBER DEFAULT NULL,
                                          p_cantidadPagina IN NUMBER DEFAULT NULL) RETURN typ_facturasServicios IS
   BEGIN
      RETURN paw_bem.fu_obtFacturasPagoServiciosWs(p_codSesion, p_codCanal, p_modo, p_codPersona, p_codToken, p_codEmpresa, p_numeroPagina, p_cantidadPagina);
   END;*/

  /*FUNCTION fu_obtenerSeguros(p_sesion      IN VARCHAR2,
                              p_codigoCanal IN VARCHAR2,
                              p_codigoSeguro IN VARCHAR2 DEFAULT NULL) RETURN TYP_SEGUROS is
   BEGIN
     return paw_bem.fu_obtenerSeguros(p_sesion,p_codigoCanal,p_codigoSeguro);
   END;*/

   -- registro de empleados
   /*FUNCTION fu_altaEmpleados(p_sesion             IN VARCHAR2,
                             p_codigoCanal        IN VARCHAR2,
                             p_modo               IN VARCHAR2,
                             p_codigoMoneda       IN VARCHAR2,
                             p_notificacionMail   IN VARCHAR2,
                             p_cantidad           IN NUMBER,
                             p_parametros         IN CLOB,                             
                             p_claveTransaccional IN VARCHAR2,
                             p_claveToken         IN VARCHAR2) RETURN typ_altaEmpleados IS
    BEGIN
      RETURN paw_bem.fu_altaEmpleados(p_sesion,p_codigoCanal, p_modo, p_codigoMoneda, p_notificacionMail, p_cantidad, p_parametros, p_claveTransaccional, p_claveToken);
    END;*/

    -- historico alta de empleados
    /*FUNCTION fu_altaEmpleadosHis(p_sesion            IN VARCHAR2,
                                p_codigoCanal        IN VARCHAR2,
                                p_fechaInicio        IN DATE DEFAULT NULL,
                                p_fechaFin           IN DATE DEFAULT NULL,
                                p_nombreDocumento    IN VARCHAR2 DEFAULT NULL,
                                p_numeroOperacion    IN NUMBER DEFAULT NULL,
                                p_numeroPagina       IN NUMBER DEFAULT NULL,
                                p_cantidadPagina     IN NUMBER DEFAULT NULL) RETURN typ_altaEmpleados IS
    BEGIN
       RETURN paw_bem.fu_altaEmpleadosHis(p_sesion, p_codigoCanal, p_fechaInicio, p_fechaFin, p_nombreDocumento, p_numeroOperacion, p_numeroPagina, p_cantidadPagina);
    END;*/

    /*FUNCTION fu_extractoDigital(p_sesion             IN VARCHAR2,
                              p_codigoCanal        IN VARCHAR2,
                              p_modo               IN VARCHAR2,
                              p_retenerCuentas     IN VARCHAR2,
                              p_retenerTarjetas    IN VARCHAR2,
                              p_numeroTarjeta      IN VARCHAR2 DEFAULT NULL) RETURN typ_datoscliente IS
    BEGIN
       RETURN paw_bem.fu_extractoDigital(p_sesion, p_codigoCanal, p_modo, p_retenerCuentas, p_retenerTarjetas, p_numeroTarjeta);
    END;*/
--add a pedido de José

                            
   FUNCTION fu_obt_lis_cas_spi(p_sesion              in varchar2,
                            p_codCanal          in varchar2
                            ) RETURN typ_LisAliasSpi is
                            
   begin
     return it.paw_bem.fu_obt_lis_cas_spi(p_sesion => p_sesion,
                                        p_codcanal => p_codcanal);
   end;
   FUNCTION fu_devolucionSpi(p_sesion              IN VARCHAR2,
                            p_codCanal          IN VARCHAR2,
                            p_modo                 IN VARCHAR2,
                            p_ref_tra_original     IN VARCHAR2,
                            p_mot_devol       IN VARCHAR2 DEFAULT NULL,
                            p_monto                IN NUMBER   DEFAULT NULL,
                            p_cod_solicitud        IN NUMBER   DEFAULT NULL,
                            p_claveTransaccional   IN VARCHAR2
                            ) RETURN typ_devolucionSpi is
                            
   begin
     return it.paw_bem.fu_devolucionSpi(p_sesion => p_sesion,
                                        p_codcanal => p_codcanal,
                                        p_modo => p_modo,
                                        p_ref_tra_original => p_ref_tra_original,
                                        p_mot_devol => p_mot_devol,
                                        p_monto => p_monto,
                                        p_cod_solicitud => p_cod_solicitud,
                                        p_clavetransaccional => p_clavetransaccional);
   end;

  FUNCTION fu_obt_lis_sol_spi(p_sesion        IN VARCHAR2,
                              p_codCanal      IN VARCHAR2,
                              p_offset        in number,
                              p_cantRegistros in number)
                              RETURN typ_LisSolicitudesSpi IS
   BEGIN
     RETURN paw_bem.fu_obt_lis_sol_spi(p_sesion, p_codCanal, p_offset, p_cantRegistros);
   END;
   FUNCTION fu_obt_lista_spi(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
   return typ_transSpi is
   begin
     return it.paw_bem.fu_obt_lista_spi(p_sesion => p_sesion,
                                        p_codcanal => p_codcanal,
                                        p_offset   => p_offset,
                                        p_cantRegistros => p_cantRegistros);
   end;
   FUNCTION fu_obt_lis_sol_dev(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
  return typ_LissoldevolucionesSpi is
  begin
    return paw_bem.fu_obt_lis_sol_dev(p_sesion => p_sesion,
                                          p_codcanal => p_codcanal,
                                          p_offset => p_offset,
                                          p_cantRegistros => p_cantRegistros);
  end;
  
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
                                 p_bic_rec              in varchar2 --codigo swift 
                                 )  --cod. swift del receptor
                               return typ_solicitudPagoSpi is
    Begin
     return  it.paw_bem.fu_solicitudPagoSPI(p_sesion,
                                            p_cod_canal,
                                            p_modo,
                                            p_cod_moneda, --moneda
                                            p_monto,      --monto a solicitar
                                            p_cta_sol, --cuenta solicitante
                                            p_cta_rec, --cuenta receptora
                                            p_tip_doc_rec, --tipo doc. del receptor       
                                            p_doc_rec, --documento del receptor
                                            p_nom_rec, --nombre del receptor
                                            p_bic_rec --codigo swift 
                                            );
    End;
    FUNCTION fu_SolicitudDevolucionSPI(p_sesion              IN VARCHAR2,
                            p_codCanal          IN VARCHAR2,
                            p_modo                 IN VARCHAR2,
                            p_ref_tra_original     IN VARCHAR2,
                            p_mot_devol       IN VARCHAR2 DEFAULT NULL,
                            p_monto                IN NUMBER   DEFAULT NULL,
                            p_cod_solicitud        IN NUMBER   DEFAULT NULL
                            ) RETURN typ_solicitudDevolucionSpi is
                            
   begin
     return it.paw_bem.fu_SolicitudDevolucionSPI(p_sesion => p_sesion,
                                        p_codcanal => p_codcanal,
                                        p_modo => p_modo,
                                        p_ref_tra_original => p_ref_tra_original,
                                        p_mot_devol => p_mot_devol,
                                        p_monto => p_monto,
                                        p_cod_solicitud => p_cod_solicitud);
   end; 
   FUNCTION fu_rch_solicitud(p_sesion              in varchar2,
                            p_codCanal          in varchar2,
                            p_modo              in varchar2,
                            p_cod_solicitud     in ge_spi_solicitudes.cod_sol_spi%type,
                            p_cod_rechazo       in ge_spi_solicitudes.tip_rechazo%type
                            ) RETURN typ_aut_solicitud is
                            
   begin
     return it.paw_bem.fu_rch_solicitud(p_sesion => p_sesion,
                                        p_codcanal => p_codcanal,
                                        p_modo => p_modo,
                                        p_cod_solicitud => p_cod_solicitud,
                                        p_cod_rechazo => p_cod_rechazo);
   end;
   
  FUNCTION fu_aut_solicitud(p_sesion             IN VARCHAR2,
                            p_codCanal           IN VARCHAR2,
                            p_modo               IN VARCHAR2,
                            p_cod_solicitud      in ge_spi_solicitudes.cod_sol_spi%type,
                            p_monto              IN NUMBER   DEFAULT NULL,
                            p_claveTransaccional IN VARCHAR2)
                            return typ_aut_solicitud is
                            
   begin
     return paw_bem.fu_aut_solicitud(p_sesion => p_sesion,
                                        p_codcanal => p_codcanal,
                                        p_modo => p_modo,
                                        p_cod_solicitud => p_cod_solicitud,
                                        p_monto => p_monto,
                                        p_clavetransaccional => p_clavetransaccional);
   end;
   
    FUNCTION fu_solicitud_regcas (p_sesion     in varchar2,
                        p_codCanal          in varchar2,
                        p_modo              in varchar2,
                        p_tip_ide_cli       in VARCHAR2,
                        p_val_ide_cli       in VARCHAR2,
                        p_tip_ide_alias     in VARCHAR2,
                        p_val_ide_alias     in VARCHAR2,
                        p_nro_cuenta        in VARCHAR2,
                        p_cta_defecto       in VARCHAR2,
                        p_tip_accion          in VARCHAR2) return typ_solicitudaltacas is
                        
   begin
     return it.paw_bem.fu_solicitud_regcas(p_sesion => p_sesion,
                                           p_codcanal => p_codcanal,
                                           p_modo => p_modo,
                                           p_tip_ide_cli => p_tip_ide_cli,
                                           p_val_ide_cli => p_val_ide_cli,
                                           p_tip_ide_alias => p_tip_ide_alias,
                                           p_val_ide_alias => p_val_ide_alias,
                                           p_nro_cuenta => p_nro_cuenta,
                                           p_cta_defecto => p_cta_defecto,
                                           p_tip_accion  => p_tip_accion);
   end;
   
   FUNCTION fu_sol_con_cas (p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_tip_consulta  IN VARCHAR2,
                            p_tip_identificador IN VARCHAR2,
                            p_val_identificador IN VARCHAR2) return typ_sol_con_cas is
                        
   begin
     return it.paw_bem.fu_sol_con_cas(p_sesion => p_sesion,
                                           p_codcanal => p_codcanal,
                                           p_tip_consulta=>p_tip_consulta,
                                           p_tip_identificador=>p_tip_identificador,
                                           p_val_identificador=>p_val_identificador);
   end;
   FUNCTION fu_res_con_cas (p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_nro_referencia IN VARCHAR2) return typ_res_con_cas is
                        
   begin
     return it.paw_bem.fu_res_con_cas(p_sesion => p_sesion,
                                           p_codcanal => p_codcanal,
                                           p_nro_referencia=>p_nro_referencia);
   end;

   FUNCTION fu_obt_lis_sol_pag(p_sesion        IN VARCHAR2,
                            p_codCanal      IN VARCHAR2,
                            p_offset        in number,
                            p_cantRegistros in number)
                            return typ_lisSolPagosSpi is
   begin
     return it.paw_bem.fu_obt_lis_sol_pag(p_sesion => p_sesion,
                                           p_codcanal => p_codcanal,
                                           p_offset   => p_offset,
                                           p_cantRegistros=> p_cantRegistros);
   end;
   FUNCTION fu_eliminar_regcas(p_sesion        in varchar2,
                              p_codcanal      in varchar2,
                              p_modo          in varchar2 default 'A',
                              p_ali_record_id in varchar2,
                              p_cta_record_id in varchar2,
                              p_accion        in varchar2 default 'ELI') return typ_solicitudaltacas is
    begin
     return it.paw_bem.fu_eliminar_regcas(p_sesion        => p_sesion,
                                           p_codcanal     => p_codcanal,
                                           p_modo         => p_modo,
                                           p_ali_record_id=> p_ali_record_id,
                                           p_cta_record_id=> p_cta_record_id,
                                           p_accion       =>p_accion);
   end;
   
   FUNCTION fu_Solicitud_EdiCAS(p_cli_recorid in varchar2,
                              p_cta_recorid in varchar2,
                              p_ali_recorid in varchar2,
                              p_accion      in varchar2,
                              p_canal       in VARCHAR2) return typ_solicitudPagoSpi is
   begin
     return paw_bem.fu_Solicitud_EdiCAS(p_cli_recorid => p_cli_recorid,
                                           p_cta_recorid => p_cta_recorid,
                                           p_ali_recorid => p_ali_recorid,
                                           p_accion => p_accion,
                                           p_canal => p_canal);
   end;    
   
    FUNCTION fu_obtenerMovimientos_por_fec_ext(p_sesion              IN VARCHAR2,
                                  p_codCanal            IN VARCHAR2,
                                  p_nroCuentaEspecifica IN VARCHAR2,
                                  p_nroPagina           IN NUMBER DEFAULT NULL,
                                  p_cantItemsPagina     IN NUMBER DEFAULT NULL,
                                  p_fecha_inicio        IN DATE DEFAULT NULL,
                                  p_fecha_fin           IN DATE DEFAULT NULL) RETURN typ_detalleMovimientos IS
   BEGIN
      RETURN paw_bem.fu_obtenerMovimientos_por_fec_ext(p_sesion, p_codCanal, p_nroCuentaEspecifica, p_nroPagina, p_cantItemsPagina, p_fecha_inicio, p_fecha_fin);
   END;                          

--add a pedido de José
END PAW_BEP;
/

