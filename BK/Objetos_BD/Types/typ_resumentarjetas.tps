CREATE OR REPLACE TYPE IT."TYP_RESUMENTARJETAS"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Cantidad de tarjetas
  canTarjetas          NUMBER(3),
-- Lista de tarjetas del cliente
  listaTarjetas        typ_listaResumenTarjeta,
  CONSTRUCTOR FUNCTION typ_resumenTarjetas RETURN SELF AS RESULT
)
/

