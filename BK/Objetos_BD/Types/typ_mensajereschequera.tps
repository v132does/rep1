CREATE OR REPLACE TYPE IT."TYP_MENSAJERESCHEQUERA"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error                VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de autorizaciones requeridas
   canAutRequeridas     NUMBER(3),
--Numero de comprobante
   nroDocumento         NUMBER(15),
-- Monto de la comisión por emisión de chequeras
   mtoComision          NUMBER(18,2),
--Que clave solicitar al usuario,
--'00':Libre, '10': Transaccional, '01': OTP, '11': Transaccional + OTP
   solicitud            VARCHAR2(2),
-- moneda
   codigoMoneda         VARCHAR2(3),
   CONSTRUCTOR FUNCTION typ_mensajereschequera RETURN SELF AS result
)
/

