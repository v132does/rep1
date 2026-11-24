CREATE OR REPLACE TYPE IT."TYP_SALDOSCUENTAS"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
-- Cantidad de saldos 
  cantidad NUMBER(3),
--Lista de saldos
  saldosCuentas typ_listaSaldosCuenta,
  CONSTRUCTOR FUNCTION typ_saldosCuentas RETURN SELF AS RESULT
)
/

