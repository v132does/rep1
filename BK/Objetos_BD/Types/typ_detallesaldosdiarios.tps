CREATE OR REPLACE TYPE IT."TYP_DETALLESALDOSDIARIOS"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
-- Codigo de moneda de la cuenta
  codigoMoneda          varchar2(3),
-- Numero de cuenta
  numeroCuenta          varchar2(15),
-- Cantidad de items
  cantidadSaldos        number(3),
-- lista de detalle de saldos
  listaSaldos           typ_listaSaldosDiarios,
      CONSTRUCTOR FUNCTION typ_detallesaldosdiarios RETURN SELF AS RESULT
)
/

