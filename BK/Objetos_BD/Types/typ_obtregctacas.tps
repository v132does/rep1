CREATE OR REPLACE TYPE IT."typ_ObtRegctacas"                                          FORCE AS OBJECT
(nro_referencia      VARCHAR2(33),
nro_cta_solicitante   VARCHAR2(35),
cli_recordID          VARCHAR2(33),
cta_recordID          VARCHAR2(33),
cod_persona           VARCHAR2(10),
tip_cuenta            VARCHAR2(3),
fec_apertura          DATE,
fec_cancelacion       DATE,
moneda                VARCHAR2(3),
cta_por_defecto       VARCHAR2(1),
est_solicitud         VARCHAR2(1),
tip_accion            VARCHAR2(1),
CONSTRUCTOR FUNCTION "typ_ObtRegctacas" RETURN SELF AS RESULT)
/

