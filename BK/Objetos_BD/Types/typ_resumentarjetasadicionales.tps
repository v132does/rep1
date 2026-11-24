CREATE OR REPLACE TYPE IT."TYP_RESUMENTARJETASADICIONALES"                                          IS OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   cantidad				NUMBER(3),
   tarjetasAdicionales    typ_listaTarjetasAdicionales,
   CONSTRUCTOR FUNCTION typ_resumenTarjetasAdicionales RETURN SELF AS result
)
/

