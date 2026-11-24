CREATE OR REPLACE TYPE IT."TYP_OBTDATCABCONCAS"                                          FORCE AS OBJECT
(tip_participante       VARCHAR2(2),
 cod_swi_pte_solicitante VARCHAR2(500),
 nro_referencia  VARCHAR2(33),
  CONSTRUCTOR FUNCTION TYP_OBTDATCABCONCAS RETURN SELF AS RESULT);
/

