CREATE OR REPLACE TYPE IT."TYP_PIZARRAICONOS"                                          FORCE AS OBJECT
(
-- modulo
  modulo                  NUMBER(3),
-- modalidad
  modalidad              NUMBER(3),
-- sub modalidad
  subModalidad           NUMBER(3),
-- url del icono
  directorio            VARCHAR2(80),
  /*
 0 : Todos los prestamos
 1 : Prestamos Hipotecaros
 2 : Prestamos Auto
 3 : Pretamos consumo personal
 */
  tipo             NUMBER(1),
  CONSTRUCTOR FUNCTION typ_pizarraiconos RETURN SELF AS RESULT
  )
/

