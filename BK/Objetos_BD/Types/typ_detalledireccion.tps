CREATE OR REPLACE TYPE IT."TYP_DETALLEDIRECCION"                                          is OBJECT
(
   codigo       NUMBER(3),
   tipo         VARCHAR2(1),
   principal    VARCHAR2(1),
   direccion    VARCHAR2(80),
   codigoPais   NUMBER(3),
   nombrePais   VARCHAR2(35),
   codigoCiudad NUMBER(3),
   nombreCiudad VARCHAR2(35),
   codigoBarrio NUMBER(3),
   nombreBarrio VARCHAR2(40),
   numero       VARCHAR2(8),
   departamento VARCHAR2(8),
   piso         VARCHAR2(8),
   edificio	    VARCHAR2(35),
   codigoPostal VARCHAR2(10),
  CONSTRUCTOR FUNCTION typ_detalleDireccion RETURN SELF AS RESULT
)
/

