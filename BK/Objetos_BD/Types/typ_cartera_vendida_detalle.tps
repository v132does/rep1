CREATE OR REPLACE TYPE IT."TYP_CARTERA_VENDIDA_DETALLE"                                          IS OBJECT
(
   codentidad           VARCHAR2(4),
   desentidad           VARCHAR2(60),
   periodo              VARCHAR2(8),
   moneda               VARCHAR2(3),
   desoperacion         VARCHAR2(100),
   deuda                VARCHAR2(18),
   clasificacionsistema VARCHAR2(2),
   comprador            VARCHAR2(255),

   CONSTRUCTOR FUNCTION typ_cartera_vendida_detalle RETURN SELF AS result
)
/

