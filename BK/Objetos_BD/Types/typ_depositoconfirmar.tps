CREATE OR REPLACE TYPE IT."TYP_DEPOSITOCONFIRMAR"                                          IS OBJECT
(
-- Numero de cuenta destino del deposito
   nroCuenta VARCHAR2(18),
-- Numero de Boleta del Depósito
   nroBoleta VARCHAR2(7),
-- Importe del deposito
   importe VARCHAR2(16),
-- Fecha en que se realizo el deposito
   fechaDeposito VARCHAR2(8),
-- Fecha en que se debe confirmar el deposito
   fechaConfirmar VARCHAR2(8),
   CONSTRUCTOR FUNCTION typ_depositoConfirmar RETURN SELF AS result
)
/

