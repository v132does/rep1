CREATE OR REPLACE TYPE IT."TYP_OBTLISTASOFTTOKENADM"                                          FORCE IS OBJECT
   (
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      cantidad              NUMBER,
      lista                 typ_listaSofttokenAdm,
      CONSTRUCTOR FUNCTION  typ_obtListaSofttokenAdm RETURN SELF AS RESULT
   )
/

