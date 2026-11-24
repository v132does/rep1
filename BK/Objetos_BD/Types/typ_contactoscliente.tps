CREATE OR REPLACE TYPE IT."TYP_CONTACTOSCLIENTE"                                          IS OBJECT
(
  --Indica si es un mensaje de error
  error varchar2(1),
  --Nombre de la respuesta
  nombreRespuesta varchar2(15),
  --Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
  -- Cantidad de contactos
  cantContactos NUMBER(8),
  -- Listado de contactos de cliente
  listaContactoCliente typ_listacontactocliente,

  CONSTRUCTOR FUNCTION typ_contactoscliente RETURN SELF AS RESULT
)
/

