CREATE OR REPLACE TYPE IT."TYP_MENSAJECAJA"                                          AS OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   estadoCaja           VARCHAR2(1),
   tipoCaja             VARCHAR2(1),
   codigoOficinaOrigen  NUMBER(3),
   codigoUsuario        VARCHAR2(10),
   fechaUltimoCierre    DATE,
   fechaCierre          DATE,

   CONSTRUCTOR FUNCTION typ_mensajecaja RETURN SELF AS result
)
/

