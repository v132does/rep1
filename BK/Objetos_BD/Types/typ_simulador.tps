CREATE OR REPLACE TYPE IT."TYP_SIMULADOR"                                          FORCE AS OBJECT
(
  -- Indica si es un mensaje de error
  error                VARCHAR2(1),
  -- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
  -- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
  -- pizarra montos
  listaPizarra         typ_listapizarra,
  -- plazos
  listaPlazos          typ_listapizarraplazos,
  -- iconos
  listaIconos          typ_listapizarraiconos,
  -- Tamaño de listado de los datos de montos de pizarra
  cantDetallesPizarra    NUMBER(4),
  -- Tamaño de listado de los datos de plazos de pizarra
  cantDetallesPlazos     NUMBER(4),
  -- Tamaño de listado de los datos de iconos
  cantDetallesIconos    NUMBER(4),
  CONSTRUCTOR FUNCTION TYP_SIMULADOR RETURN SELF AS RESULT
)
/

