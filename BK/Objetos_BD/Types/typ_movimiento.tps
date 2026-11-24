CREATE OR REPLACE TYPE IT."TYP_MOVIMIENTO"                                          FORCE IS OBJECT
(
--Fecha del movimiento
   fecha VARCHAR2(8),
--Hora del movimiento
   hora VARCHAR2(8),
--Fecha de confirmacion
   fechaValor VARCHAR2(8),
-- Numero de documento (opcional)
   numeroDocumento VARCHAR2(15),
--Descripcion de la transaccion padre
   descripcionTransaccionPadre VARCHAR2(100),
--Abreviatura de la transaccion padre
   abreviaturaTransaccionPadre VARCHAR2(10),
--Tipo del Movimiento <ul><li><b>D:</b> Debito</il><li><b>C:</b> Credito</il></ul>
   tipoMovimiento VARCHAR2(1),
--Monto total del movimiento
   monto VARCHAR2(20),
-- Saldo calculado en el momento del movimiento
   saldo VARCHAR2(20),
-- Nro de tarjeta
   nro_tarjeta VARCHAR2(25),
-- Numero de documento (opcional)
   nroDocumento VARCHAR2(15),
-- Codigo de modulo
   codigoModulo NUMBER(3),
-- Codigo de modalidad
   codigoModalidad NUMBER(3),
-- Fecha de Insercion
   fechaInsercion DATE,
-- Numero de Secuencia
   nroSecuencia NUMBER(3),
-- Reversado
   esReversado VARCHAR2(1),
-- Tipo de reporte a generar
   reportType VARCHAR2(10),
-- saldo incial,
   saldoInicial NUMBER(18,2),  
-- Concepto
   concepto   VARCHAR2(100), 
   CONSTRUCTOR FUNCTION typ_movimiento RETURN SELF AS result
)
/