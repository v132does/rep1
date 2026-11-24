CREATE OR REPLACE TYPE IT."TYP_SALDOS"                                          is object
(
  -- Author  : XPY0040
  -- Created : 5/1/2019 5:29:12 PM
  -- Purpose : 

  disponible number(18,2),
  actual number(18,2),
  retenido  number(18,2),
  bloqueado   number(18,2),
  CONSTRUCTOR FUNCTION typ_saldos RETURN SELF AS RESULT
)
/

