CREATE OR REPLACE TYPE IT."TYP_DOCUMENTOSNP"                                          FORCE IS OBJECT
(
-- Código del Tipo de Documento
  codigoDocumento number(3),
-- Abreviatura del Documento
  abreviatura varchar2(4),
-- Descripción
  descripcion varchar2(100),
  CONSTRUCTOR FUNCTION typ_documentoSnp RETURN SELF AS RESULT
)
/

