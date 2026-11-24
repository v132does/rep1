CREATE OR REPLACE TYPE IT."TYP_OBTMOVIMIENTOS"                                          FORCE AS OBJECT
(
  transactionStatus VARCHAR2(1),
  operationDate     Date,
  processDate       Date,
  couponNumber      integer,
  description       VARCHAR2(140),
  amount            NUMBER(18,2),
  cashBack          VARCHAR2(1),
  cardNumnber       VARCHAR2(1),
  tipMov            VARCHAR2(1),
  movDescription    VARCHAR2(13),
  CONSTRUCTOR FUNCTION typ_obtmovimientos RETURN SELF AS RESULT
)
/

