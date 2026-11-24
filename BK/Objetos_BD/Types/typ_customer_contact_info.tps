CREATE OR REPLACE TYPE IT."TYP_CUSTOMER_CONTACT_INFO"                                          FORCE as object
(
  -- Author  : XPG0671
  -- Created : 28/8/2018 09:42:21
  -- Purpose : Type que contiene la info de un contacto del cliente
  
  tipoContacto varchar2(20),
  contacto varchar2(120),
  
  pais varchar2(40),
  codigoRegional varchar2(5),
  extension varchar2(5),
  operadoraTelefonica varchar2(20),
  
  principal VARCHAR2(1),
  verificado VARCHAR2(1),
  permiteAnuncions  VARCHAR2(1),
  ultimaActualizacion     DATE,
  
  CONSTRUCTOR FUNCTION typ_customer_contact_info RETURN SELF AS RESULT
)
/

