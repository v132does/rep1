CREATE OR REPLACE TYPE IT."TYP_DETCOMSER"                                          AS OBJECT
(
  error                varchar2(1),
  nombrerespuesta      varchar2(15),
  descripcionrespuesta varchar2(200),
  nrocomprobante       varchar2(15),
  tipooperacion        varchar2(150),
  nroctadebito         varchar2(15),
  moneda               varchar2(35),
  importedebito        number(18, 2),
  fechapago            date,
  hora                 varchar2(8),
  codmoneda            varchar2(3),
  servicio             varchar2(300),
  cantfirreq           integer,
  denominacioncta      varchar2(100),
  CONSTRUCTOR FUNCTION typ_detcomser RETURN SELF AS result
)
/

