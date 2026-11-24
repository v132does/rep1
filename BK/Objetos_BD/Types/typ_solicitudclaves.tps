CREATE OR REPLACE TYPE IT."TYP_SOLICITUDCLAVES"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error                VARCHAR2(1),
-- Nombre de la respuesta
  nombreRespuesta      VARCHAR2(15),
-- Mensaje de la respuesta
  descripcionRespuesta VARCHAR2(200),
--Que clave solicitar al usuario, 
--'00':Libre, '10': Transaccional, '01': OTP, '11': Transaccional + OTP
  solicitud             VARCHAR2(2),
  CONSTRUCTOR FUNCTION typ_solicitudClaves RETURN SELF AS RESULT
)
/

