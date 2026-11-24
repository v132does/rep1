CREATE OR REPLACE TYPE IT."TYP_MONEDA"                                          FORCE IS OBJECT
(
   codigo                VARCHAR2(5),
   descripcion      VARCHAR2(35),
   codigo_numerico NUMBER(5),
   codigo_bcp             NUMBER(5),
   codigo_iso             VARCHAR2(5),
   codigo_pais             NUMBER(5),
   CONSTRUCTOR FUNCTION typ_moneda RETURN SELF AS result
)
/

