CREATE OR REPLACE TYPE IT."TYP_SALDOSDIARIOS"                                          IS OBJECT
   (
    -- Author  : XPG0613
    -- Created : 24/10/2018 9:05:50
    -- Purpose : Estructutra para obtener saldos de las fechas solicitadas
  
    -- Attributes
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(25),
      descripcionRespuesta  VARCHAR2(200), 
      nroCuenta             VARCHAR2(18),
      salAnterior           NUMBER(18,2),
      salActual             NUMBER(18,2),
     
      CONSTRUCTOR FUNCTION typ_saldosdiarios RETURN SELF AS RESULT
   );
/

