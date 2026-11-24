CREATE OR REPLACE TYPE IT."TYP_DETALLEPROGRAMADA"                                          is OBJECT
(
   numeroDetalle     NUMBER,
   estado            VARCHAR2(1),
   fechaProgramada   DATE,
   fechaMovimiento   DATE,
   horaMovimiento    VARCHAR2(8),
   numeroDocumento   NUMBER(15),
   montoDebito       NUMBER(18,2),
   montoCredito      NUMBER(18,2),
   cotizacionDebito  NUMBER(14,8),
   cotizacionCredito NUMBER(14,8),
  CONSTRUCTOR FUNCTION typ_detalleProgramada RETURN SELF AS RESULT
)
/

