CREATE OR REPLACE TYPE IT.typ_val_das        is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Cantidad de Cuentas  
  cantidadCuentas      NUMBER,
--Lista de cuentas
  listaCuentas         it.typ_listaDetalledas,
  CONSTRUCTOR FUNCTION typ_val_das RETURN SELF AS RESULT
)
/
