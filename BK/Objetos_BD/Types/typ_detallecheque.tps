CREATE OR REPLACE TYPE IT."TYP_DETALLECHEQUE"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Fecha del cheque
   fecha VARCHAR2(8),
-- Hora de..
   hora VARCHAR2(8),
-- Monto del Cheque   
   monto VARCHAR2(16),
-- Moneda    
   moneda VARCHAR2(3),
-- Beneficiario del cheque en caso de existir   
   beneficiario VARCHAR2(35),
-- Fecha de la operacion de pago    
   fechaPago VARCHAR2(8),
-- Descripcion de la transaccion    
   descripcionTransaccion VARCHAR2(35),
-- Estado del Cheque    
   estado VARCHAR2(20),
--  nombreSucursal     
   nombreSucursal VARCHAR2(35),
--  causaBloqueo    
   causaBloqueo VARCHAR2(35),
   CONSTRUCTOR FUNCTION typ_detalleCheque RETURN SELF AS result
)
/

