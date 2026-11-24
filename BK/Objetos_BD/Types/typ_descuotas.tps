CREATE OR REPLACE TYPE IT."TYP_DESCUOTAS"                                          is OBJECT
(
--Indica si es un mensaje de error
  error varchar2(1),
--Código de la respuesta
  nombreRespuesta varchar2(15),
--Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Lista de Cuotas
  listadescuotas typ_listadescuota,
  CONSTRUCTOR FUNCTION typ_descuotas RETURN SELF AS RESULT
)
/

