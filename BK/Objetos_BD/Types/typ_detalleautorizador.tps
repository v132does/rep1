CREATE OR REPLACE TYPE IT."TYP_DETALLEAUTORIZADOR"                                          force is OBJECT
(
-- Numero de documento
  nombre         VARCHAR2(240),
-- fecha y hora del movimiento
  fechaHora      DATE,
-- Comentario
  comentario     VARCHAR2(250),
-- Estado del movimiento
  estado         VARCHAR2(20),

  CONSTRUCTOR FUNCTION typ_detalleautorizador RETURN SELF AS RESULT
)
/

