CREATE OR REPLACE TYPE IT."TYP_TIPODOCUMENTOS"                                          FORCE IS OBJECT
(
-- Indica si es un mensaje de error
  error VARCHAR2(1),
-- Código de la respuesta
  nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Cantidad de Oficinas
  cantdocumentos NUMBER(3),
-- Lista de Oficinas
  informacionDocumentos typ_listadocumentos,
  CONSTRUCTOR FUNCTION typ_tipoDocumentos RETURN SELF AS result
)
/

