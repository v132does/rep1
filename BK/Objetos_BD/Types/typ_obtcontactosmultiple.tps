CREATE OR REPLACE TYPE IT."TYP_OBTCONTACTOSMULTIPLE"                                          IS OBJECT
   (
      error                 VARCHAR2(1),   
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
	  cantidad		        NUMBER,
      lista           		typ_listacontactosmultiple,
      CONSTRUCTOR FUNCTION  typ_obtcontactosmultiple RETURN SELF AS RESULT
   )
/

