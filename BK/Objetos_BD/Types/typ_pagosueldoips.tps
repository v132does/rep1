CREATE OR REPLACE TYPE IT."TYP_PAGOSUELDOIPS"                                          IS object
(
  nroOrden 	                  		 NUMBER(10),
  nroLote				                NUMBER(10),
  nroComprobante                     NUMBER(15),
  nroCtaJubilado                     VARCHAR(15),
  nroDocJubilado                     VARCHAR(20),
  nombreJubilado                     VARCHAR2(120),
  importe                            NUMBER(18, 2),
  feVidaVigente                      VARCHAR2(1), --S/N
  estado                             VARCHAR2(1), --S/N
  comentarios                        VARCHAR2(1000),
  fechaAcreditacion                  DATE,
  fechaConcilacion                   DATE,
  nroComprobanteDuplicado            varchar2(1),

  CONSTRUCTOR FUNCTION TYP_PAGOSUELDOIPS RETURN SELF AS result
)
/

