CREATE OR REPLACE TYPE IT."TYP_RESUMENTARJETAADICIONAL"                                          IS OBJECT
(
   nombreEmbozado VARCHAR2(26),
   numeroTarjeta VARCHAR2(25),
   fechaVencimiento    DATE,
   CONSTRUCTOR FUNCTION typ_resumenTarjetaAdicional RETURN SELF AS result
)
/

