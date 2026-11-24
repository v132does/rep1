create or replace package it.paw_log is

  -- Author  : Samuel da Costa
  -- Created : 03/05/2013 06:08:50 p.m.
  -- Purpose : Paquete creado para realizar las pruebas del paw_bel. Se crean las variables publicas
  --           de los types para ser leidas en la función

  --
  g_log clob;
  g_typ_iniciarSesion                typ_iniciarSesion;
  g_typ_mensajeRespuesta             typ_mensajeRespuesta;
  g_typ_obtenerDetalleCuentas        typ_obtenerDetalleCuentas;
  g_typ_detalleCuenta                typ_detalleCuenta;
  g_typ_resumenCuentas               typ_resumenCuentas;
  g_typ_resumenCuenta                typ_resumenCuenta;
  g_typ_detalleMovimientos           typ_detalleMovimientos;
  g_typ_movimiento                   typ_movimiento;
  g_typ_pagoTarjetaCredito           typ_pagoTarjetaCredito;
  g_typ_pagoProveedores              typ_pagoProveedores;
  g_typ_detalleProveedor             typ_detalleProveedor;
  g_typ_pagoSalarios                 typ_pagoSalarios;
  g_typ_detalleSalario               typ_detalleSalario;
  g_typ_chequesDevueltos             typ_chequesDevueltos;
  g_typ_chequeDevuelto               typ_chequeDevuelto;
  g_typ_depositosConfirmar           typ_depositosConfirmar;
  g_typ_depositoConfirmar            typ_depositoConfirmar;
  g_typ_saldosCuentas                typ_saldosCuentas;
  g_typ_saldoCuenta                  typ_saldoCuenta;
  g_typ_transferencia                typ_transferencia;
  g_typ_detallesFactura              typ_detallesFactura;
  g_typ_detallesFactura_hb           typ_detallesFactura_hb;--NVB-2232
  g_typ_detalleFactura               typ_detalleFactura;
  g_typ_extracto                     typ_extracto ;
  g_typ_extractoCuentas              typ_extractoCuentas;
  g_typ_extractoMovimientos          typ_extractoMovimientos;
  g_typ_extractoRetenciones          typ_extractoRetenciones;
  g_typ_extractoResumenes            typ_extractoResumenes;
  g_typ_extractoBloqueos             typ_extractoBloqueos;
  g_typ_resumenFacturas              typ_resumenFacturas;
  g_typ_resumenFactura               typ_resumenFactura;
  g_typ_pagoPrestamo                 typ_pagoPrestamo;
  g_typ_obtCuotasPrestamo            typ_obtCuotasPrestamo;
  g_typ_cuotaPrestamo                typ_cuotaPrestamo;
  g_typ_autorizaOperacion            typ_autorizaOperacion;
  g_typ_detalleAutorizador           typ_detalleAutorizador;
  g_typ_consultaAutorizaciones       typ_consultaAutorizaciones;
  g_typ_resumenAutorizacion          typ_resumenAutorizacion;
  g_typ_parametroInicialSnp          typ_parametrizacionInicialSnp;
  g_typ_transferenciasSnp            typ_transferenciasSnp;
  g_typ_respuestaTransfSnp           typ_respuestaTransferenciaSnp;
  g_typ_transferenciaFuturaSnp       typ_transferenciaFuturaSnp;
  g_typ_calificacionRiesgo           typ_calificacionRiesgo;
  g_typ_parametrosBancard            typ_parametrosBancard;
  g_typ_TransFrecuentes              typ_TransFrecuentes;
  g_typ_ta_pagoPrestamo              typ_ta_pagoPrestamo;
  g_typ_cancelacionSNP         typ_cancelacionSNP;
  g_typ_ta_deposito                  typ_ta_deposito;
  g_typ_ta_pagoTarjetaCredito        typ_ta_pagoTarjetaCredito;
  g_typ_ta_transferencia             typ_ta_transferencia;
  g_typ_administracionDatos          typ_administracionDatos;
  g_typ_actualizacionDatos           typ_actualizacionDatos;
  g_typ_movimientosTarjeta           typ_movimientosTarjeta;
  g_typ_altaPersona                  typ_altaPersona;
  g_typ_geolocalizacionesPronet      typ_geolocalizacionesPronet;
  g_typ_obtSimulacionPrestamo        typ_obtenerSimulacionPrestamo;
  g_typ_movSemestrales               typ_movimientosSemestral;
  g_typ_cuponesCda                   typ_cuponesCda;
  g_typ_pagoServicios                typ_pagoservicios;
  g_typ_mensajeria                   typ_mensajeria;
  g_typ_devolucionSpi                typ_devolucionSpi;--NVB-2232
  g_typ_solicitudPagoSpi             typ_solicitudPagoSpi;--NVB-2232
  g_typ_solicitudDevolucionSpi       typ_solicitudDevolucionSpi;--NVB-2232
  function  fu_obtieneCollection (p_type in varchar2)
    return  varchar2;
  procedure pr_retornaValoresTypes(p_type in varchar2);
  function fu_retornaValoresTypes(p_type in varchar2)
    return  clob;
  procedure pr_logValoresTypes(p_type in varchar2,
                               p_generarLog in varchar2 default null,
                               p_canal      in varchar2 default null);
  function fu_getLog
    return  clob;
  procedure pr_setLog (p_log in clob);
  function fu_generarLog
    return varchar2;

end paw_log;
/

