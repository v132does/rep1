CREATE OR REPLACE TYPE IT."TYP_OBTREGALICAS"                                          force as OBJECT
( nro_referencia     VARCHAR2(33),
  cli_recorid        VARCHAR2(33),
  tip_identificador   VARCHAR2(10),
  val_identificador   VARCHAR2(80),
  fec_registro        DATE,
  fec_ven_registro    DATE,
  nro_cta_solicitante   VARCHAR2(35),
  est_alias    VARCHAR2(20),
  tip_accion            VARCHAR2(1),
  CONSTRUCTOR FUNCTION "TYP_OBTREGALICAS"  RETURN SELF AS RESULT)
/

