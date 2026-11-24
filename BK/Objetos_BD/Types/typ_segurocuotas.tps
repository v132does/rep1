CREATE OR REPLACE TYPE IT."TYP_SEGUROCUOTAS"                                          is OBJECT
(
-- Numero de cuotas
  nroCuota          NUMBER,
-- Descripcion especifica del seguro
  fecVencimiento     DATE,
-- Poliza
  monto         NUMBER(18,2),
-- Estados: P= pendiente; C=cancelado; I: monto abonado parcialmente.
  estado VARCHAR2(1),
  CONSTRUCTOR FUNCTION TYP_SEGUROCUOTAS RETURN SELF AS RESULT
)
/

