CREATE OR REPLACE TYPE IT."TYP_DETALLEBANCO"                                          FORCE IS OBJECT
(
   codigoSwift   VARCHAR2(20),
   nombreEntidad VARCHAR2(60),
   nombrePais    VARCHAR2(35),
   codigoBanco   NUMBER(5),
   nombreCiudad  VARCHAR2(40),
   codigoCiudad  NUMBER(3),
   codigoPais    NUMBER(3),
   CONSTRUCTOR FUNCTION typ_detalleBanco RETURN SELF AS result
)
/

