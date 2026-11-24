CREATE OR REPLACE TYPE IT."TYP_OBTSOLMULTIPLE"                                          IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
	  cantidad            NUMBER,
      lista               typ_listasolmultiple,
      CONSTRUCTOR FUNCTION  typ_obtsolmultiple RETURN SELF AS RESULT
   )
/

