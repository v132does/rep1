CREATE OR REPLACE TYPE IT."TYP_FIDEICOMISO_DETALLE"                                          IS OBJECT
(
   codentidad           VARCHAR2(4),
   desentidad           VARCHAR2(60),
   periodo              VARCHAR2(8),
   moneda               VARCHAR2(3),
   desoperacion         VARCHAR2(100),
   deuda                VARCHAR2(18),
   clasificacionsistema VARCHAR2(2),
   fideicomitente       VARCHAR2(255),

   CONSTRUCTOR FUNCTION typ_fideicomiso_detalle RETURN SELF AS result
)
/

