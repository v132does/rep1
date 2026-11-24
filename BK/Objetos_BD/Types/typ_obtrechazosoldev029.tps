CREATE OR REPLACE TYPE IT."TYP_OBTRECHAZOSOLDEV029"                                          FORCE AS OBJECT
(
nro_ref_externa      VARCHAR2(33),
swi_pte_emisor       VARCHAR2(20),
swi_pte_receptor     VARCHAR2(20),
fec_valor            DATE,
cod_clave            VARCHAR2(10),
nro_ref_original     VARCHAR2(33),
cod_msj_mx_original  VARCHAR2(20),
fec_original         DATE,
cod_motivo_rechazo   VARCHAR2(8),
mot_rechazo          VARCHAR2(200),
tip_pte_emisor       VARCHAR2(20),
tip_pte_receptor     VARCHAR2(20),
CONSTRUCTOR FUNCTION typ_ObtRechazoSoldev029 RETURN SELF AS RESULT
)
/

