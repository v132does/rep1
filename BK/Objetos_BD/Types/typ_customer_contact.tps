CREATE OR REPLACE TYPE IT."TYP_CUSTOMER_CONTACT"                                          as object
(
  -- Author  : XPG0671
  -- Created : 28/8/2018 09:26:59
  
  -- Indica si es un mensaje de error
  error varchar2(1),
  -- Nombre de la respuesta
  nombreRespuesta varchar2(15),
  -- Mensaje de la respuesta
  descripcionRespuesta varchar2(200),
  
  --Cantidad de contactos TOTAL
  cantContactos           NUMBER(3),
  --Indica si tiene algun contacto de tipo email
  tieneEmail varchar2(1),
  --indica si tiene algun contacto de tipo celular
  tieneCelular varchar2(1),
  --indica si tiene algun contacto de tipo telefono
  tieneTelefono varchar2(1),
  
  -- Lista de contacto
  listaContactos          TYP_LIST_CUSTOMER_CONTACT_INFO,
  CONSTRUCTOR FUNCTION typ_customer_contact RETURN SELF AS RESULT
)
/

