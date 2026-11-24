CREATE OR REPLACE TYPE IT."TYP_SOLTARJETAS"                                          is OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   numeroDocumento      VARCHAR2(20),
   tipoDocumento        VARCHAR2(20),
   nombreCompleto       VARCHAR2(100),
   numeroSolicitud      NUMBER,
   respuestaLimite      VARCHAR2(2),
  CONSTRUCTOR FUNCTION TYP_SOLTARJETAS RETURN SELF AS RESULT
)
/

