CREATE OR REPLACE TYPE IT."TYP_OBTSOLRECIBIDO"                                          FORCE AS OBJECT
(
nro_ref_externa       varchar2(35),
nro_ref_original      varchar2(35),
fec_valor             date,
msj_mx                varchar2(4000),
cod_msj_mx            varchar2(20),
nom_receptor          varchar2(120),
nro_doc_receptor      varchar2(20),
cod_tip_doc_receptor  varchar2(3),
nro_cta_receptor      varchar2(35),
swi_pte_receptor      varchar2(20),
cod_swi_suc_emisor    varchar2(20),
identificacion        varchar2(140),
uetr                  varchar2(50),
cod_motivo_dev        varchar2(10),
cod_moneda            varchar2(3),
monto                 number(18,2),
swi_pte_emisor        varchar2(20),
nom_emisor            varchar2(120) ,
nro_doc_emisor        varchar2(20),
cod_tip_doc_emisor    varchar2(3),
nro_cta_emisor        varchar2(35),
info_remesa           varchar2(1000),
info_envio            varchar2(1000),
cod_tip_operacion     varchar2(3),
CONSTRUCTOR FUNCTION typ_ObtSolRecibido RETURN SELF AS RESULT
);
/

