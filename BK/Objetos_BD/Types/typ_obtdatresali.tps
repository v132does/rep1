CREATE OR REPLACE TYPE IT."TYP_OBTDATRESALI"                                          force as OBJECT
( nro_referencia VARCHAR(33),
  ali_recordID   VARCHAR(33),
  est_alias      varchar2(20),
  error          VARCHAR2(2000),
  tip_accion     varchar2(1),
   CONSTRUCTOR FUNCTION "TYP_OBTDATRESALI"  RETURN SELF AS RESULT)
/

