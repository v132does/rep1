CREATE OR REPLACE TYPE IT."TYP_ALTAPERSONA"                                          FORCE AS OBJECT
(
   error                VARCHAR2(1), -- Indica si es un mensaje de error
   nombreRespuesta      VARCHAR2(15), -- Nombre de la respuesta
   descripcionRespuesta VARCHAR2(200), -- Mensaje de la respuesta
   numeroDocumento      VARCHAR2(20), -- Nmero de operacion confirmada
   codigoPersona        NUMBER, -- Código de persona
   nombreCompleto       VARCHAR2(60), --Nombre completo
   claveUsuario         VARCHAR2(60), --Clave de usuario
   numerotelefono       VARCHAR2(60), --Número de telefóno
   claveVerificador     NUMBER, --Clave Verificador
   CONSTRUCTOR FUNCTION typ_altaPersona RETURN SELF AS result
)
/

