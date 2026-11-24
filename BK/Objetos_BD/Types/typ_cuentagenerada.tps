CREATE OR REPLACE TYPE IT."TYP_CUENTAGENERADA"                                          IS OBJECT
   (
      error                 VARCHAR2(1),
      NRO_CUENTA       VARCHAR2(15),
      COD_MODALIDAD    NUMBER(3),
      COD_MODULO       NUMBER(3),
      FECHA_APERTURA   DATE,
      ESTADO           VARCHAR2(1),
      CONSTRUCTOR FUNCTION typ_cuentagenerada RETURN SELF AS RESULT
   )
/

