CREATE OR REPLACE TYPE IT."TYP_DETALLECUPONESCDA"                                          IS OBJECT
   (
      nroCupon          NUMBER(7),
      montoInteres      NUMBER(18,2),
      fechaVencimiento  DATE,
      fechaPago         DATE,
      estado            VARCHAR2(1),

      CONSTRUCTOR FUNCTION TYP_DETALLECUPONESCDA RETURN SELF AS RESULT
   )
/

