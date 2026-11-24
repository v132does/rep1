CREATE OR REPLACE TYPE IT."TYP_CHEQUEDEVUELTO"                                          IS OBJECT
(
--Numero de cuenta del cheque
   nroCuenta VARCHAR2(18),
--Descripcion del banco del cheque
   banco VARCHAR2(35),
--Numero de cheque guardado
   nroCheque VARCHAR2(10),
--Importe del cheque
   importe VARCHAR2(16),
--Descripcion del motivo
   motivoDevolucion VARCHAR2(53),
--Fecha
   fecha DATE,
   CONSTRUCTOR FUNCTION typ_ChequeDevuelto RETURN SELF AS result
)
/

