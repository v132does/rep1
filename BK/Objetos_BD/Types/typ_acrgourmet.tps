CREATE OR REPLACE TYPE IT."TYP_ACRGOURMET"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--Respuesta de limite de operaciones
  respuestaLimite      VARCHAR2(2),
--Cantidad de firmas para autorizacion
  cantidadAutorizadores NUMBER,
--Numero de documento de la operacion
  numeroDocumento       NUMBER(15),
--Tamaño de lista de cuentas
  cantidadCuentas      NUMBER,
--Lista de cuentas
  listaCuentas         TYP_LISTAACRGOURMET,
  CONSTRUCTOR FUNCTION typ_acrGourmet RETURN SELF AS RESULT
)
/

