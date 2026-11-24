CREATE OR REPLACE TYPE IT."TYP_TIPOTRANSFERENCIASSNP"                                          FORCE IS OBJECT
(
-- Código tipo
  codigoTipo varchar2(5),
-- Descripción del Tipo
  tipo varchar2(100),

  CONSTRUCTOR FUNCTION typ_tipoTransferenciasSnp RETURN SELF AS RESULT
)
/

