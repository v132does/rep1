CREATE OR REPLACE TYPE IT."TYP_DETCOMSAL"                                          AS OBJECT
(
  error                varchar2(1),
  nombrerespuesta      varchar2(15),
  descripcionrespuesta varchar2(200),
  nrocomprobante       varchar2(15),
  fecharegistro        date,
  hora                 varchar2(8),
  fechapago            date,
  nroctadebito         varchar2(15),
  tipoctadebito        varchar2(150),
  moneda               varchar2(35),
  importedebito        number(18, 2),
  tipooperacion        varchar2(150),
  concepto             varchar2(150),
  ente                 varchar2(10),
  oficina              varchar2(35),
  canfirreq            integer,
  cotizacion           number(18, 2),
  cantregs             integer,
  tipopago             varchar2(3),
  codmoneda            varchar2(3),
  CONSTRUCTOR FUNCTION typ_detcomsal RETURN SELF AS result
)
/

