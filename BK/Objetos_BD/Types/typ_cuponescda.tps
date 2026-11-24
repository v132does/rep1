CREATE OR REPLACE TYPE IT."TYP_CUPONESCDA"                                          FORCE AS OBJECT
(
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      numeroCda             VARCHAR2(18),
      cantidadCuotas        NUMBER(3),
      listaCuotas           typ_listaCuponCda,
      CONSTRUCTOR FUNCTION typ_cuponesCda RETURN SELF AS RESULT
)
/

