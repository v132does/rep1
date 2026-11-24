CREATE OR REPLACE TYPE IT."TYP_VALIDARSESION"                                          AS OBJECT
(
   error                VARCHAR2(1), -- hubo Error?
   nombreRespuesta      VARCHAR2(15), --Nombre del mensaje
   descripcionRespuesta VARCHAR2(200), -- Descripcion del mensaje
   codigoPersona        VARCHAR2(10), -- Nombre del mensaje
   codigoCanal          VARCHAR2(3), -- Nombre del mensaje
   codigoEmpresa        VARCHAR2(10), -- Nombre del mensaje
   codigoPerfil         VARCHAR(20),
   numeroTelefono       VARCHAR2(30),

   CONSTRUCTOR FUNCTION typ_validarSesion RETURN SELF AS result
)
/

