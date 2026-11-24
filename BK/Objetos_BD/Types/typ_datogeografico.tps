CREATE OR REPLACE TYPE IT."TYP_DATOGEOGRAFICO"                                          force                                         IS OBJECT
(
-- Código identificador del dato
   codigo VARCHAR2(3),
-- Descripción del dato
   descripcion VARCHAR2(35),
   CONSTRUCTOR FUNCTION typ_datogeografico RETURN SELF AS result
)
/

