CREATE OR REPLACE TYPE IT."TYP_CONSULTARTRANSFERENCIASNP"                                          IS OBJECT
(
   error                VARCHAR(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   cantidadConsultas    NUMBER(3),
   listaConsultas       typ_listaConsultaSnp,
   CONSTRUCTOR FUNCTION typ_consultarTransferenciaSnp RETURN SELF AS result
)
/

