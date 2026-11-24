CREATE OR REPLACE TYPE IT."TYP_DETCOMTRAI"                                          AS OBJECT
(
  error                varchar2(1),
  nombrerespuesta      varchar2(20),
  descripcionrespuesta varchar2(200),
  nrooperacion         varchar2(100),
  concepto             varchar2(150),
  ctadebito            varchar2(20),
  denominacionctadeb   varchar2(150),
  desmonedadeb         varchar2(50),
  importedeb           number(18, 2),
  fechacre             date,
  nrotransferencia     varchar2(20),
  monedatransf         varchar2(50),
  nrodocbeneficiario   varchar2(20),
  beneficiario         varchar2(150),
  ctacredito           varchar2(35),
  importecre           number(18, 2),
  codswift             varchar2(20),
  entidad              varchar2(100),
  fechasolicitud       date,
  horasolicitud        varchar2(20),
  oficina              varchar2(35),
  cantfirreq           integer,
  cotizacion           number(18, 2),
  codmonedadeb         varchar2(3),
  codmonedatransf      varchar2(3),
  cantidad             integer,
  CONSTRUCTOR FUNCTION typ_detcomtrai RETURN SELF AS result
)
/

