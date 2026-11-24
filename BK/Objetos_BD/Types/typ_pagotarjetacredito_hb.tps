CREATE OR REPLACE TYPE IT."TYP_PAGOTARJETACREDITO_HB"                                          IS OBJECT
(
  -- Indica si es un mensaje de error
   error                 VARCHAR2(1),
   -- Nombre de la respuesta
   nombreRespuesta       VARCHAR2(15),
   -- Mensaje de la respuesta
   descripcionRespuesta  VARCHAR2(200),
   --Moneda del Pago
   codigoMoneda          VARCHAR2(3),
   --Denominacion de la cuenta de debito
   denominacionCuenta    VARCHAR2(50),
   --Moneda del debito
   monedaDebito          VARCHAR2(3),
   --Importe del debito
   importeDebito         VARCHAR2(16),
   --Numero de la tarjeta de credito
   numeroTarjeta         VARCHAR2(17),
   --Nombre en la tarjeta de credito
   nombreTarjeta         VARCHAR2(50),
   --Indica el nro de documento al confirmar la operacion
   numeroOperacion       NUMBER,
   --Respuesta del limite de operacion
   respuestaLimite       VARCHAR2(2),
   --Cantidad de firmas requeridas
   cantidadAutorizadores NUMBER,
   CONSTRUCTOR FUNCTION typ_pagotarjetacredito_hb RETURN SELF AS result
)
/

