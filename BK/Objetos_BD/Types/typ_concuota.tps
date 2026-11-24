CREATE OR REPLACE TYPE IT."TYP_CONCUOTA"                                          IS OBJECT
(
  nroSolicitud    NUMBER(7),
  nroCuota        NUMBER(3),
  fecVencimiento  DATE,
  mtoCapital      NUMBER(18,2),
  mtoInteres      NUMBER(20,4),
  diaPeriodo      NUMBER(4),
  CONSTRUCTOR FUNCTION typ_concuota RETURN SELF AS result
)
/

