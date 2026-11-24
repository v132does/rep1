CREATE OR REPLACE TYPE IT."TYP_MAPA"                                          is OBJECT
(
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- cantidad de datos adicionales
  cantidad             NUMBER,
-- atributos clave-valor-tipo
  datosAdicionales     typ_listaClaveValor,
  CONSTRUCTOR FUNCTION typ_mapa RETURN SELF AS RESULT
)
/

