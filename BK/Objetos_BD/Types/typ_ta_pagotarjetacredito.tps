CREATE OR REPLACE TYPE IT."TYP_TA_PAGOTARJETACREDITO"                                          FORCE AS OBJECT
(
   error                    VARCHAR2(1), -- Indica si es un mensaje de error
   nombreRespuesta          VARCHAR2(15), -- Nombre de la respuesta
   descripcionRespuesta     VARCHAR2(200), -- Mensaje de la respuesta
   codigoMoneda             VARCHAR2(3), -- Moneda del Pago
   denominacionCuenta       VARCHAR2(50), -- Denominacion de la cuenta de debito
   numeroCuentaDebito       VARCHAR2(15), -- Numero de Cuenta Debito
   monedaDebito             VARCHAR2(3), -- Moneda del debito
   importeDebito            NUMBER(18, 2), -- Importe del debito
   montoPagoMinimo          NUMBER(18, 2), -- Monto de pago mnimo
   numeroTarjeta            VARCHAR2(17), -- Numero de la tarjeta de credito
   nombreTarjeta            VARCHAR2(50), -- Nombre en la tarjeta de credito
   cotizacion               NUMBER(18, 2), -- Cotizacion utilizada para la transaccn
   numeroDocumento          NUMBER(15), -- Numero de comprobante de movimientos
   fechaMovimiento          VARCHAR2(10), -- Fecha de movimiento para impresión de comprobantes
   CONSTRUCTOR FUNCTION typ_ta_pagoTarjetaCredito RETURN SELF AS result
)
/

