CREATE OR REPLACE TYPE IT."TYP_INSCTACAS"                                          FORCE AS OBJECT
(
  nro_referencia      VARCHAR2(33),
  nro_cta_solicitante VARCHAR2(35),
  cli_recordid        VARCHAR2(33),
  cta_recordid        VARCHAR2(33),
  ali_recordid        VARCHAR2(33),
  cod_persona         VARCHAR2(10),
  tip_cuenta          VARCHAR2(3),
  fec_apertura        DATE,
  fec_cancelacion     DATE,
  moneda              VARCHAR2(3),
  cta_por_defecto     VARCHAR2(1),
  est_solicitud       VARCHAR2(1),
  tip_identificador   VARCHAR2(10),
  identificador       VARCHAR2(20),
  CONSTRUCTOR FUNCTION TYP_INSCTACAS RETURN SELF AS RESULT)
/

