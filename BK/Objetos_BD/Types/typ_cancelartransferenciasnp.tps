CREATE OR REPLACE TYPE IT."TYP_CANCELARTRANSFERENCIASNP"                                          IS OBJECT
(
   error                 VARCHAR(1),
   nombreRespuesta       VARCHAR2(15),
   descripcionRespuesta  VARCHAR2(200),
   autorizacionesRequeridas NUMBER(5),
   cantidadCancelaciones NUMBER(3),
   listaCancelaciones    typ_listaCancelacionesSnp,
   comprobanteMovimiento typ_comprobanteMovimiento,
   CONSTRUCTOR FUNCTION typ_cancelartransferenciasnp RETURN SELF AS result
)
/

