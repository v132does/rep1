CREATE OR REPLACE TYPE IT."TYP_OBTSOLICITUDPAGO013"                                          force as object
(
nro_ref_externa                varchar2(35),
fecha                          date,
hora                           varchar2(10),
des_suc_sol_beneficiario       varchar2(100),
swi_suc_sol_beneficiario       varchar2(20),
cta_suc_sol_beneficiario       varchar2(35),
swi_pte_beneficiario           varchar2(20),
tip_pte_beneficiario           varchar2(3),
nom_beneficiario               varchar2(120),
nro_cta_beneficiario           varchar2(35),
nro_doc_beneficiario           varchar2(20),
cod_tip_doc_beneficiario       varchar2(15),
instrumento                    varchar2(10),
moneda                         varchar2(3),
monto                          number(18,2),
swi_pte_solicitante            varchar2(20),
tip_pte_solicitante            varchar2(3),
nom_solicitante                varchar2(120),
nro_doc_solicitante            varchar2(20),
cod_tip_doc_solicitante        varchar2(15),
nro_cta_solicitante            varchar2(35),
cod_tip_operacion              varchar2(3),
info_remesa                    varchar2(1000),
info_envio                     varchar2(1000),
uetr                           varchar2(50),
CONSTRUCTOR FUNCTION typ_ObtSolicitudPago013 RETURN SELF AS RESULT
);
/

