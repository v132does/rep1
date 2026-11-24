CREATE OR REPLACE TYPE IT."TYP_CONCARGO"                                          IS OBJECT
(
  nroSolicitud         NUMBER(7),
  codTransaccion       NUMBER(4),
  desTransaccion       VARCHAR2(60),
  valTasa              NUMBER(20,4),
  monto                NUMBER(18,2),
  codTasa              NUMBER(3),
  codEntSeguro         NUMBER(5),
  codMoneda            VARCHAR2(3),
  mtoMonPrestamo       NUMBER(18,2),
  CONSTRUCTOR FUNCTION typ_concargo RETURN SELF AS result
)
/

