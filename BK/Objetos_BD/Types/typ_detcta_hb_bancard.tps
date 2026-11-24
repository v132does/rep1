CREATE OR REPLACE TYPE IT."TYP_DETCTA_HB_BANCARD"                                          FORCE IS OBJECT
(
--   Numero de la Cuenta
  nroCuenta varchar2(17),
--  Codigo de Tipo de Cuenta <ul><li> <b>AH:</b> Ahorro a la Vista</li> <li> <b>CD:</b> CDA</li><li> <b>AP:</b> Ahorros a Plazo Fijo</li> <li> <b>TI:</b> Titulos de Inversion</li> <li> <b>CC:</b> Cuenta Corriente</li> <li> <b>PT:</b> Prestamos</li> <li> <b>TJ:</b> Tarjetas</li> <li> <b>SV:</b> Sobregiros Vencidos</li> <li> <b>BA:</b> Venta a Plazo de Bienes Adjudicados</li></ul>
  tipoCuenta varchar2(2),
--  Descripcion del tipo de Cuenta
  descTipoCuenta varchar2(35),
--  Denominacion de la cuenta
  denominacion varchar2(70),
--  Codigo de moneda de la cuenta
  codMoneda varchar2(16),
--  <ul> <li> <b>TJ:</b> Saldo disponible para compras normales de la tarjeta de crédito.</li><li> <b>AH:</b> Saldo Actual de la cuenta.</li><li> <b>PT:</b> Monto del Préstamo.</li><li> <b>CD:</b> Capital.</li><li> <b>CC:</b> Saldo Actual de la cuenta.</li></ul>
  monto1 varchar2(16),
--  <ul>  <li> <b>TJ:</b> Saldo de la deuda total de la tarjeta de crédito</li><li> <b>AH:</b> Saldo disponible total de la cuenta.</li><li> <b>PT:</b> Saldo Capital + Saldo Interés adelantado.</li><li> <b>CD:</b> Interés pendiente.</li><li> <b>AH:</b> Saldo disponible total de la cuenta. </li><li> <b>CC:</b> Saldo disponible total de la cuenta.</li></ul>
  monto2 varchar2(16),
--  <ul><li> <b>TJ:</b> Monto del Pago Mínimo aún pendiente de la tarjeta de crédito.</li><li> <b>AH:</b> Saldo retenido total de la cuenta.</li><li> <b>PT:</b> Saldo Interés.</li><li> <b>CD:</b> Saldo Retenido.</li><li> <b>CC:</b> Saldo retenido total de la cuenta.</li></ul>
  monto3 varchar2(16),
--  <ul> <li> <b>TJ:</b> Línea de crédito de la tarjeta</li><li> <b>CC:</b> Línea de sobregiro.</li></ul>
  monto4 varchar2(16),
-- Tasa TA
  tasa varchar2(8),
--  <ul> <li> <b>TJ:</b> Fecha de apertura de la cuenta.</li><li> <b>PT:</b> Fecha de inicio.</li><li> <b>CD:</b> Fecha de apertura.</li><li> <b>CC:</b> Fecha de apertura</li></ul>
  fechaInicio varchar2(8),
--  <ul>     <li> <b>TJ:</b> Fecha vencimiento pago mínimo.</li><li> <b>AH:</b> Fecha de vencimiento.</li><li> <b>PT:</b> Fecha de vencimiento.</li><li> <b>CD:</b> Fecha de vencimiento.</li><li> <b>CC:</b> Fecha de vencimiento.</li></ul>
  fechaVencimiento varchar2(8),
--  <ul>     <li> <b>TJ:</b> Fecha del proximo cierre</li></ul>
  fechaProximoVencimiento varchar2(8),
-- diasMora
  diasMora varchar2(5),
-- chequeDevuelto
  chequeDevuelto varchar2(1),
--Indica la relacion de la cuenta con el usuario logueado  <ul><li> <b>P:</b> Principal </li><li> <b>Y:</b>Firmante conj.</li><li> <b>O:</b>Firmante ind.</li><li> <b>G:</b>Garante</li><li> <b>C:</b>codDeudor</li><li> <b>A:</b>Adicional</li></ul>
  relacion varchar2(1),
--numero plastico de la tarjeta
  numeroTarjeta varchar2(20),
--campo abierto
  dato1 varchar2(300),
--campo abierto
  dato2 varchar2(300),
-- S: imprime extracto, N: no imprime extracto
  imprimeExtracto VARCHAR2(1),
  extraData VARCHAR2(400),
  alias     VARCHAR2(200),
  monto5    varchar2(16), -- Saldo al cierre
  CONSTRUCTOR FUNCTION typ_detcta_hb_bancard RETURN SELF AS RESULT
)
/

