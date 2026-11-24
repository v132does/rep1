CREATE OR REPLACE TYPE IT."TYP_DETALLEFERIADO"                                          FORCE IS OBJECT
(
   fecha         DATE,
   codigoOficina NUMBER(3),
   motivo        VARCHAR2(35),
   CONSTRUCTOR FUNCTION typ_detalleferiado RETURN SELF AS result
)
/

