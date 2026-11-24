CREATE OR REPLACE TYPE IT."TYP_OBTPUNTOSLEALTAD"                                          IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      cantidad              NUMBER,
      lisBolsas      typ_listapuntoslealtad,
      CONSTRUCTOR FUNCTION TYP_OBTPUNTOSLEALTAD RETURN SELF AS RESULT
   )
/

