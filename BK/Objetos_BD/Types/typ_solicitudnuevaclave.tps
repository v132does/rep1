CREATE OR REPLACE TYPE IT."TYP_SOLICITUDNUEVACLAVE"                                          IS OBJECT
(
-- Indica si es un mensaje de error
  error VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta VARCHAR2(15) ,
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
-- Token de autorización
  token VARCHAR2(200),
-- Nro Tarjeta de debito
  nroTarjeta VARCHAR2(20),
  CONSTRUCTOR FUNCTION TYP_SOLICITUDNUEVACLAVE RETURN SELF AS result
)
/

