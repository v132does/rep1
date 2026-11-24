CREATE OR REPLACE TYPE IT."TYP_RESUMENFACTURA"                                          is OBJECT
(
--Numero de factura
  nroFactura           varchar2(20),
--Fecha de la factura  
  fecha                date,
--Tipo de factura  
  tipo                 varchar2(20),
--Moneda de la factura  
  codMoneda            varchar2(3),
--Monto total de la factura  
  totalFactura         varchar2(18),
--Monto total de la factura en Gs
  totalFacturaGs       varchar2(18),
--Monto Total  con IVA
  totalIva             varchar2(18),

      CONSTRUCTOR FUNCTION typ_resumenFactura RETURN SELF AS RESULT
)
/

