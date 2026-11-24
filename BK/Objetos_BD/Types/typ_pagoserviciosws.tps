CREATE OR REPLACE TYPE IT."TYP_PAGOSERVICIOSWS"                                          IS OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
   respuestaLimite      VARCHAR2(2),
   numeroSesion            VARCHAR2(32),
   firmasPendientes    NUMBER(2),
   nroDocumento          number(15),
   CONSTRUCTOR FUNCTION typ_pagoserviciosws RETURN SELF AS result
)
/

