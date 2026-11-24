CREATE OR REPLACE TYPE IT."TYP_LINEACREDITO"                                          IS OBJECT
(
  -- Indica si es un mensaje de error
   error                VARCHAR2(1),
   -- Nombre de la respuesta
   nombreRespuesta      VARCHAR2(15),
   -- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
   -- USD,GS, ...
   codigoMoneda         VARCHAR2(3),
   -- monto de la linea
   monto                NUMBER(18,2),
   -- fecha validez
   fechaVencimiento     DATE,
   -- fecha otorgamiento
   fechaOtorgada        DATE,
   -- fecha aprobada
   fechaAprobada        DATE,
   -- monto utilizado
   montoAplicado        NUMBER(18,2),
   -- descripcion de la linea
   descripcion          VARCHAR2(60),
   -- cotizacion de la linea
   cotizacion           NUMBER(14,8),
   CONSTRUCTOR FUNCTION typ_lineaCredito RETURN SELF AS result
)
/

