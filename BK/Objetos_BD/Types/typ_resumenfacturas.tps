CREATE OR REPLACE TYPE IT."TYP_RESUMENFACTURAS"                                          is OBJECT
(
-- Indica si es un mensaje de error
  error varchar2(1),
-- Nombre de la respuesta
  nombreRespuesta varchar2(15),
-- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Tamaño de lista de facturas  
  cantFacturas         NUMBER,
--Lista de facturas  
  listaFacturas        typ_listafacturas,

  CONSTRUCTOR FUNCTION typ_resumenFacturas RETURN SELF AS RESULT
)
/

