CREATE OR REPLACE TYPE IT."TYP_OBTEDIALICAS"                                          force as OBJECT
( nro_referencia       VARCHAR2(33),
ali_recordID           VARCHAR(33) ,
cue_recordID           VARCHAR(33) ,
nro_cta_solicitante    VARCHAR2(35),
cta_por_defecto        VARCHAR2(1) ,
est_alias              varchar2(10),
fec_ven_registro       DATE      ,
tip_edicion            VARCHAR2(3) ,
error                  VARCHAR2(4000),
canal                  VARCHAR2(4),
CONSTRUCTOR FUNCTION "TYP_OBTEDIALICAS"  RETURN SELF AS RESULT)
/

