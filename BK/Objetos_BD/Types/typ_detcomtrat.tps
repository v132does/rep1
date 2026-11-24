CREATE OR REPLACE TYPE IT."TYP_DETCOMTRAT"                                          AS OBJECT
(
  error                varchar2(1),
  nombrerespuesta      varchar2(30),
  descripcionrespuesta varchar2(200),
  nrooperacion         varchar2(100),
  tipooperacion        varchar2(100),
  ctadebito            varchar2(30),
  denominacionctadeb   varchar2(150),
  desmonedadeb         varchar2(50),
  ctacredito           varchar2(30),
  desmonedacre         varchar2(50),
  denominacionctacre   varchar2(150),
  doctitcred           varchar2(30),
  importecre           number(18, 2),
  fecha                date,
  hora                 varchar2(8),
  codmoneda            varchar2(3),
  cantfirreq           integer,
  cotizacion           number(18, 2),
  concepto             varchar2(150),
  codmonedacre         varchar2(3),
  importedev           number(18, 2),
  CONSTRUCTOR FUNCTION typ_detcomtrat RETURN SELF AS result
)
/

