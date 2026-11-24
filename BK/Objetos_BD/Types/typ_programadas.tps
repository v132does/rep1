CREATE OR REPLACE TYPE IT."TYP_PROGRAMADAS"                                          is OBJECT
(
   error                VARCHAR2(1),
   nombreRespuesta      VARCHAR2(15),
   descripcionRespuesta VARCHAR2(200),
   cantidad             NUMBER,
   listaDetalles        typ_listaProgramadas, 
  CONSTRUCTOR FUNCTION typ_programadas RETURN SELF AS RESULT
)
/

