CREATE OR REPLACE TYPE IT."TYP_OBTENERSIMULACIONPRESTAMO"                                          AS OBJECT
(
error VARCHAR2(1),
nombreRespuesta VARCHAR2(15),
descripcionRespuesta VARCHAR2(200),
plazo NUMBER(5),
montoPrestamo NUMBER(18,2),
moneda VARCHAR2(3),
montoCuota NUMBER(18,2),
CONSTRUCTOR FUNCTION typ_obtenerSimulacionPrestamo RETURN SELF AS RESULT
)
/

