CREATE OR REPLACE TYPE IT."TYP_CHEQUES"                                          is OBJECT
(
--Indica si es un mensaje de error
  error varchar2(1),
--Código de la respuesta
  nombreRespuesta varchar2(15),
--Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Lista de transferencias
  listacheques typ_listacheques,
  CONSTRUCTOR FUNCTION typ_cheques RETURN SELF AS RESULT
)
/

