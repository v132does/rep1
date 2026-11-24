CREATE OR REPLACE TYPE IT."TYP_OBTDETALLEMOVIMIENTOS_HIS"                                          FORCE AS OBJECT
(
  error                VARCHAR2(1), -- Indica si es un mensaje de error
  nombreRespuesta      VARCHAR2(30), -- Nombre de la respuesta
  descripcionRespuesta VARCHAR2(300), -- Mensaje de la respuesta
  cantidadMovimientos  NUMBER(8), -- Cantidad de movimientos
  listaMovimientos     typ_obtlistamovimientos_his,
  CONSTRUCTOR FUNCTION typ_obtdetallemovimientos_his RETURN SELF AS RESULT
)
/

