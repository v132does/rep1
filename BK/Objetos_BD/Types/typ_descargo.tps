CREATE OR REPLACE TYPE IT."TYP_DESCARGO"                                          IS OBJECT
(
      COD_TRANSACCION    NUMBER(4),
      DES_TRANSACCION    VARCHAR2(60),
      COD_ENT_SEGURO     NUMBER(5),
      NOM_SEGURO         VARCHAR2(40),
      VAL_TASA           NUMBER(18,4),
      COD_MONEDA         VARCHAR2(3),
      MONTO              NUMBER(18,4),
      MTO_MON_PRESTAMO   NUMBER(18,4),
      COD_TASA           NUMBER(3),
      FEC_TASA           DATE
      ,

  CONSTRUCTOR FUNCTION typ_descargo RETURN SELF AS result
)
/

