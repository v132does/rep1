CREATE OR REPLACE TYPE IT."TYP_TRANSFRECUENTES"                                          FORCE IS OBJECT
(
--Indica si es un mensaje de error
  error varchar2(1),
--Código de la respuesta
  nombreRespuesta varchar2(15),
--Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
--Lista de transferencias
  listatransferencias typ_listaTransferencias,
  CONSTRUCTOR FUNCTION typ_TransFrecuentes RETURN SELF AS RESULT
)
;
/

