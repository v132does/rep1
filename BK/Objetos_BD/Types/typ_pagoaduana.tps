CREATE OR REPLACE TYPE IT."TYP_PAGOADUANA"                                          is Object
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Número de Cuenta de Debito
  numeroCuenta varchar2(18),
--Método de Pedido
  metodoPedido varchar2(1),
--Operacion DNA
  operacionDna varchar2(3),
--Campo 1:TDA:  Ruc Importador, TDI: Ruc Importador, TCA:  Nro Ticket, TLE: Nro Ticket 
  campo1 varchar2(16),
--Campo2: TDA: Ruc Despachante, TDI: Ruc Despachante, TCA: Ruc Despachante, TLE: Nombre Despachante
  campo2 varchar2(16),
--nombreDespachante 
  nombreDespachante varchar2(30),
--monto Monto de la operacion
  monto number(18,2), 
--respuestaLimite   Opcional
  respuestaLimite varchar2(2),
--cantidad de autorizaciones para confirmar la operacion
  cantAutorizadores number(3),
-- numero de documento al confirmar la operacion 
  nroDocumento number(15),
--nombre del importador 
  nombreImportador varchar2(30),
  CONSTRUCTOR FUNCTION typ_pagoAduana RETURN SELF AS RESULT
)
/

