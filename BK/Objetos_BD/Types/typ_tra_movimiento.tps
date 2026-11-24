CREATE OR REPLACE TYPE IT."TYP_TRA_MOVIMIENTO"                                          FORCE AS OBJECT
(
      error                 VARCHAR2(1),
      nombreRespuesta       VARCHAR2(15),
      descripcionRespuesta  VARCHAR2(200),
      numeroDocumento       NUMBER(15),
      ind_nocturno          VARCHAR2(1), 
      cotizacion            NUMBER(18,2),
      CONSTRUCTOR FUNCTION typ_tra_movimiento RETURN SELF AS RESULT
)
/
