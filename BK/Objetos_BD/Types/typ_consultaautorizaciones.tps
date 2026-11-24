CREATE OR REPLACE TYPE IT."TYP_CONSULTAAUTORIZACIONES"                                          FORCE AS OBJECT
(
  error                    VARCHAR2(1),             -- Indica si es un mensaje de error
  nombreRespuesta          VARCHAR2(15),            -- Nombre de la respuesta
  descripcionRespuesta     VARCHAR2(200),           -- Mensaje de la respuesta
  cantidadAutorizaciones   NUMBER,                  -- Tamaño de la lista de Autorizaciones
  listaAutorizaciones      typ_listaAutorizaciones, -- Lista de Autorizaciones
  CONSTRUCTOR FUNCTION typ_consultaAutorizaciones RETURN SELF AS RESULT
)
/

