CREATE OR REPLACE TYPE IT."TYP_CHEQUERA"                                          IS OBJECT
(
-- Indica si es un mensaje de error
   error VARCHAR2(1),
-- Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
-- Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cheque inicial 
   chequeinicial VARCHAR2(15),
-- Cheque final
   chequeFinal VARCHAR2(15),
-- Cantidad de cheques solicitados
   solicitados NUMBER(5),
-- Cantidad de cheques entregados
   entregados NUMBER(5),
-- Cantidad de cheques pagados
   pagados NUMBER(5),
-- Cantidad de cheques anulados
   anulados NUMBER(5),
-- Cantidad de cheques con orden de no pago
   ordenNoPago NUMBER(5),

   certificados NUMBER(5),
   CONSTRUCTOR FUNCTION typ_Chequera RETURN SELF AS result
)
/

