CREATE OR REPLACE TYPE IT."TYP_OBTDATRESCLI"                                          FORCE AS OBJECT
(nro_referencia        VARCHAR(33),
 cli_recordID           VARCHAR2(33),
 est_cliente           VARCHAR2(20),
 error                 VARCHAR2(2000),
 tip_accion            VARCHAR2(1),
 CONSTRUCTOR FUNCTION TYP_OBTDATRESCLI RETURN SELF AS RESULT)
/

