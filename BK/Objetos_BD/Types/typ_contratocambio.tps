CREATE OR REPLACE TYPE IT."TYP_CONTRATOCAMBIO"                                          FORCE                                       IS OBJECT
(
   -- numero de operacion
   numeroContrato    NUMBER(7),
   -- tipo de operacion
   tipoOperacion     VARCHAR2(3),
   -- valor de la cotizacion
   cotizacion        NUMBER(14, 8),
   -- moneda de la operacion
   codigoMoneda      VARCHAR2(3),
   -- monto de la operacion
   monto             NUMBER(18, 2),
   -- monto equivalente moneda local
   montoEqLocal      NUMBER(18, 2),
   montoCargo1       NUMBER(18, 2),
   montoCargo2       NUMBER(18, 2),
   montoCargo3       NUMBER(18, 2),
   montoCargo4       NUMBER(18, 2),
   -- contra cuenta debito
   cuentaReferencia3 VARCHAR2(15),
   -- monto contra cuenta (cuenta debito)
   montoContra3      NUMBER(18, 2),
   -- numero operacion generada para el homebanking
   numeroDiario      NUMBER(3),
   CONSTRUCTOR FUNCTION typ_contratocambio RETURN SELF AS result
)
/

