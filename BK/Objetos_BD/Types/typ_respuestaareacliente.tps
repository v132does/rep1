CREATE OR REPLACE TYPE IT."TYP_RESPUESTAAREACLIENTE"                                          force  IS OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   nombreCompleto       VARCHAR2(120),
   direccionPrincipal   VARCHAR2(200),
   telefonoPrincipal    VARCHAR2(21),
   email                VARCHAR2(80),
   documento            VARCHAR2(30),
   tipoDocumento        VARCHAR2(3),
   abreviaturaDocumento VARCHAR2(30),
   CONSTRUCTOR FUNCTION typ_respuestaAreaCliente RETURN SELF AS result
)
/

