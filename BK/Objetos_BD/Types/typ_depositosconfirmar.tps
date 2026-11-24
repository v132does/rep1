CREATE OR REPLACE TYPE IT."TYP_DEPOSITOSCONFIRMAR"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
--Cantidad de depositos de confirmar
   cantDepositosConfirmar NUMBER(3),
--Lista de depositos a confirmar
   listaDepositosConfirmar typ_listaDepositosConfirmar,
   CONSTRUCTOR FUNCTION typ_depositosConfirmar RETURN SELF AS result
)
/

