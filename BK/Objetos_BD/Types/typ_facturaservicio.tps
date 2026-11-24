CREATE OR REPLACE TYPE IT."TYP_FACTURASERVICIO"                                          FORCE IS OBJECT
( 
   --
   -- Type usado para retornar el contenido de una factura de pago de servicio (CANREQVAR-229)
   --
   tokenCode    VARCHAR2(50), --Identificador de la transaccion
   fecha        DATE, --Fecha de la factura
   servConcepto VARCHAR2(50), --concepto del servicio
   totalFactura NUMBER, --Monto total de la factura
   ticket       CLOB, --Ticket del servicio
   codServicio  NUMBER, --Codigo del servicio al que pertenece la factura
   codProveedor NUMBER, --Codigo del proveedor(portadora)
   nroLote      VARCHAR2(250), --Número de Lote de la Transacción

   CONSTRUCTOR FUNCTION typ_facturaServicio RETURN SELF AS RESULT
)
/

