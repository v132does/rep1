CREATE OR REPLACE TYPE IT."TYP_OBTRESPUESTA014"                                          FORCE AS OBJECT
(
nro_ref_externa       varchar2(35),
fec_valor             date,
swi_pte_emi_original  varchar2(20),
nro_ref_original      varchar2(35),
cod_msj_mx_original   varchar2(20),
fec_original          date,
resp_procesamiento    VARCHAR2(10),
swi_pte_emisor        VARCHAR2(20),
cod_motivo_rechazo    VARCHAR2(8),
mot_rechazo           VARCHAR2(200),
tip_pte_emi_original  VARCHAR2(20),
tip_pte_emisor        VARCHAR2(20),
CONSTRUCTOR FUNCTION typ_ObtRespuesta014 RETURN SELF AS RESULT
);
/

