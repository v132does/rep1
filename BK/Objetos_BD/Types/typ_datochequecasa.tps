CREATE OR REPLACE TYPE IT."TYP_DATOCHEQUECASA"                                          is OBJECT
(
   nombre   VARCHAR2(120),
   cedula   VARCHAR2(20),
   estado   VARCHAR2(15),
   telefono VARCHAR2(10),
   tipDocumento VARCHAR(4),
  CONSTRUCTOR FUNCTION typ_datoChequeCasa RETURN SELF AS RESULT
)
/

