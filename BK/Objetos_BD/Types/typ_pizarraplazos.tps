CREATE OR REPLACE TYPE IT."TYP_PIZARRAPLAZOS"                                          is OBJECT
(
--  modulo
  modulo                  NUMBER(3),
-- modalidad
  modalidad              NUMBER(3),
-- sub modalidad
  subModalidad           NUMBER(3),
-- codigo de moneda
  codMoneda              VARCHAR(3),
--  plazo en dias desde
  plzDesde                  NUMBER(5),
-- plazo en dias hasta
  plzHasta                  NUMBER(5),
-- Tasa de interes
  tasInteres                NUMBER(20,4),
  /*
 0 : Todos los préstamos
 1 : Préstamos Hipotecaros
 2 : Préstamos Auto
 3 : Préstamos consumo personal
 */
  tipo             NUMBER(1),
  CONSTRUCTOR FUNCTION typ_pizarraplazos RETURN SELF AS RESULT
  )
/

