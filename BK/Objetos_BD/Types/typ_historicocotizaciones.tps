CREATE OR REPLACE TYPE IT."TYP_HISTORICOCOTIZACIONES"                                          force                                       IS OBJECT
(
   codigoMoneda           VARCHAR2(3),
   descripcionMoneda      VARCHAR2(35),
   compra                 NUMBER(14, 8),
   venta                  NUMBER(14, 8),
   compraBancaElectronica NUMBER(14, 8),
   ventaBancaElectronica  NUMBER(14, 8),
   fecha                  DATE,
   CONSTRUCTOR FUNCTION typ_historicocotizaciones RETURN SELF AS result
)
/

