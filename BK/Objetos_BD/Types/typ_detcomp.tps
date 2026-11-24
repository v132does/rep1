CREATE OR REPLACE TYPE IT."TYP_DETCOMP"                                          AS OBJECT
(
  error                VARCHAR2(1),
  nombrerespuesta      VARCHAR2(15),
  descripcionrespuesta VARCHAR2(200),
  nrodocumento         NUMBER(15),
  fecha                DATE,
  hora                 VARCHAR2(8),
  nrocuenta            VARCHAR2(15),
  tipocuenta           VARCHAR2(150),
  codmoneda            VARCHAR2(3),
  monto                NUMBER(18, 2),
  nrotarjeta           VARCHAR2(20),
  afinidad             VARCHAR2(150),
  tipooperacion        VARCHAR2(150),
  cantfirreq           integer,
  cotizacion           number(18, 2),
  CONSTRUCTOR FUNCTION typ_detcomp RETURN SELF AS result
)
/

