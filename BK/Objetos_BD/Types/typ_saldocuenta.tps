CREATE OR REPLACE TYPE IT."TYP_SALDOCUENTA"                                          IS OBJECT
(
--Codigo de la moneda
  moneda varchar2(3),
--<ul><li><b>Saldo Mes</b> (AV, CDA, CC, CB)</li><li> <b>Saldo de Capital</b> (PR)</li><li><b>Deuda</b> (TJ)</li><li> <b>Sal. Confirmado</b> (CX)</li></ul>    
  saldoPromedio number(18, 2),
--Saldo Cierre Mensual
  saldoCierre number(18,2),
-- Año al que corresponde
  anho number(4),
-- Mes al que corresponde
  mes number(2),
  CONSTRUCTOR FUNCTION typ_SaldoCuenta RETURN SELF AS RESULT
)
/

