CREATE OR REPLACE TYPE IT."TYP_CONDICIONCOMERCIAL"                                          IS OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   cantidad        NUMBER(3),
   detallesCondicion    typ_listaCondiciones,
   CONSTRUCTOR FUNCTION typ_condicioncomercial RETURN SELF AS result
)
/

