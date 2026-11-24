CREATE OR REPLACE TYPE IT."TYP_PIZARRA"                                          is OBJECT
(
-- descripcion
  descripcion             VARCHAR2(60),
--  modulo
  modulo                  NUMBER(3),
-- modalidad
  modalidad              NUMBER(3),
-- sub modalidad
  subModalidad           NUMBER(3),
-- codigo de moneda
  codMoneda              VARCHAR(3),
-- monto hasta
  montoHasta             NUMBER(18,2),
-- monto desde
  montoDesde             NUMBER(18,2),
-- tipo de prestamo
 /*
 0 : Todos los préstamos
 1 : Préstamos Hipotecaros
 2 : Préstamos Auto
 3 : Préstamos consumo personal
 */
  tipo             NUMBER(1),
  CONSTRUCTOR FUNCTION typ_pizarra RETURN SELF AS RESULT
  )
/

