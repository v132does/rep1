CREATE OR REPLACE TYPE IT."TYP_DETALLESAPF"                                          FORCE IS OBJECT
   (
      nroCupon          NUMBER(7),
      montoInteres      NUMBER(18,2),
      fechaVencimiento  DATE,
      fechaPago         DATE,
      estado            VARCHAR2(1),
      descripcionEstado VARCHAR2(240),
      montoAcumulado    NUMBER(18,2),
      monto             NUMBER(18,2),
      tipo              VARCHAR2(1),
      CONSTRUCTOR FUNCTION TYP_DETALLESAPF RETURN SELF AS RESULT
   )
/

