CREATE OR REPLACE TYPE IT."TYP_DETCOMPPRE"                                          AS OBJECT
(
  error                VARCHAR2(1),
  nombrerespuesta      VARCHAR2(15),
  descripcionrespuesta VARCHAR2(200),
  nrooperacion         VARCHAR2(150),
  tipooperacion        VARCHAR2(150),
  nroprestamo          VARCHAR2(100),
  tipoprestamo         VARCHAR2(150),
  cuentadebito         VARCHAR2(15),
  monto                NUMBER(18, 2),
  cuotapagada          NUMBER(3),
  fecha                DATE,
  hora                 VARCHAR2(8),
  cantfirreq           integer,
  cotizacion           number(18, 2),
  CONSTRUCTOR FUNCTION typ_detcomppre RETURN SELF AS result
)
/

