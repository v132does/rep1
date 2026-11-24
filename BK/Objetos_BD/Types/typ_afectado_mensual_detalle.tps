CREATE OR REPLACE TYPE IT."TYP_AFECTADO_MENSUAL_DETALLE"                                          IS OBJECT
(
   codentidad           VARCHAR2(4),
   desentidad           VARCHAR2(60),
   periodo              VARCHAR2(8),
   deuda                VARCHAR2(18),
   codeudoria           VARCHAR2(18),
   contingencia         VARCHAR2(18),
   deudavendida         VARCHAR2(18),
   deudafideicomiso     VARCHAR2(18),
   clasificacionentidad VARCHAR2(2),

   CONSTRUCTOR FUNCTION typ_afectado_mensual_detalle RETURN SELF AS result
)
/

