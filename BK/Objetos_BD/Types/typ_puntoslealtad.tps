CREATE OR REPLACE TYPE IT."TYP_PUNTOSLEALTAD"                                          IS OBJECT
   (
      nomPrograma       VARCHAR2(50),
      canPuntos         NUMBER(15,2),
      nroTarjeta        VARCHAR2(20),
      fecProceso        DATE,     
      CONSTRUCTOR FUNCTION TYP_PUNTOSLEALTAD RETURN SELF AS RESULT
   )
/

