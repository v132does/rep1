CREATE OR REPLACE TYPE IT."TYP_CUPONCDA"                                          FORCE AS OBJECT
(
      numeroCupon       NUMBER(5),
      monto             NUMBER(18,2),
      fechaVencimiento  VARCHAR2(8),
      CONSTRUCTOR FUNCTION typ_cuponCda RETURN SELF AS RESULT
)
/

