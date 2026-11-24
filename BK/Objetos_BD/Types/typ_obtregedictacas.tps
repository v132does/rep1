CREATE OR REPLACE TYPE IT."typ_ObtRegedictacas"                                          force as OBJECT
(nro_referencia        VARCHAR2(33),
nro_cta_solicitante     VARCHAR2(35),
cli_recordID            VARCHAR2(33),
cta_recordID            VARCHAR2(33),
ali_recordID            VARCHAR2(33),
cod_persona             VARCHAR2(10),
fec_cancelacion         DATE    ,
moneda                  VARCHAR2(3) ,
cta_por_defecto         VARCHAR2(1) ,
est_solicitud           VARCHAR2(1) ,
tip_identificador       VARCHAR2(10),
identificador           VARCHAR2(20),
tip_edicion             VARCHAR2(3),
error                   varchar2(2000),
tip_canal               VARCHAR2(4),
CONSTRUCTOR FUNCTION "typ_ObtRegedictacas"  RETURN SELF AS RESULT)
/

