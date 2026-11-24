CREATE OR REPLACE TYPE IT."TYP_DETALLETRANSINTERNACIONAL"                                          IS OBJECT
(
--Indica si es un mensaje de error
   error VARCHAR2(1),
--Nombre de la respuesta
   nombreRespuesta VARCHAR2(15),
--Mensaje de la respuesta
   descripcionRespuesta VARCHAR2(200),
-- Cantidad de transferencias
   cantTransferencias NUMBER(3),
--Lista de transferencias
   listaTransferencias typ_listaTransInternacional,
   CONSTRUCTOR FUNCTION typ_detalleTransInternacional RETURN SELF AS result
)
/

