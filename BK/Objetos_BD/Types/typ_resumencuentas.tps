CREATE OR REPLACE TYPE IT."TYP_RESUMENCUENTAS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
  error VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Cantidad de cuentas
  cantCuentas NUMBER,
-- Lista de resumen de cuentas
  resumenCuentas typ_listaResumenCuenta,
  CONSTRUCTOR FUNCTION typ_ResumenCuentas RETURN SELF AS RESULT
)
/

