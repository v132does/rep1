CREATE OR REPLACE TYPE IT."TYP_SOL_CON_CAS"                                          FORCE AS OBJECT
(
      error                  VARCHAR2(1),
      nombreRespuesta        VARCHAR2(100),
      descripcionRespuesta   VARCHAR2(2000),
      nro_referencia       VARCHAR2(33),
      CONSTRUCTOR FUNCTION typ_sol_con_cas RETURN SELF AS RESULT
)
/

