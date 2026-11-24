--
alter trigger it.ca_ah_cta_certificados disable;
truncate table ah_cta_certificados_crm;--14608
--
alter trigger it.ca_ah_cta_vistas disable;
truncate table ah_cta_vistas_crm;--652685
--
alter trigger it.CA_AH_TAR_DEBITOS disable;
truncate table ah_tar_debitos_crm;--455399

alter trigger it.CA_BA_DIRECCIONES disable;
truncate table ba_direcciones_crm;--517677

alter trigger it.CA_BA_PER_FISICAS disable;
truncate table ba_per_fisicas_crm;--375656
--
alter trigger it.ca_ba_personas disable;
truncate table ba_personas_crm;--434482
--
alter trigger it.ca_ba_telefonos disable;
truncate table ba_telefonos_crm;--523361
--
alter trigger it.ca_ba_usuarios disable;
truncate table ba_usuarios_crm;--1350
--
alter trigger it.CA_CC_CTA_CORRIENTES disable;
truncate table cc_cta_corrientes_crm;--43
--
alter trigger it.ca_cc_lin_sobregiros disable;
truncate table cc_lin_sobregiros_crm;--188
--
alter trigger it.ca_ge_clientes disable;
truncate table ge_clientes_crm;--435708
--
alter trigger it.ca_ge_cta_clientes disable;
truncate table ge_cta_clientes_crm;--459186
--
alter trigger it.ca_ge_cuentas disable;
truncate table ge_cuentas_crm;--1206059
--
alter trigger it.CA_GE_GRU_ECONOMICOS disable;
truncate table ge_gru_economicos_crm;--3
--
alter trigger it.CA_GE_PER_INHIBIDAS disable;
truncate table ge_per_inhibidas_crm;--362510
--
alter trigger it.CA_PR_CTA_PRESTAMOS disable;
truncate table pr_cta_prestamos_crm;--760386
--
alter trigger it.CA_PR_SOLICITUDES disable;
truncate table pr_solicitudes_crm;--1185007
--
alter trigger it.CA_TA_CTA_TARJETAS disable;
truncate table ta_cta_tarjetas_crm;--104375
--
alter trigger it.CA_TA_TARJETAS disable;
truncate table ta_tarjetas_crm;--218281
