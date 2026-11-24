begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_cta_dat_adicionales (NRO_CUENTA, PARAMETRO, VAL_PARAMETRO)
values ('2345974', 'NRO_SEC_CTA_MT940', '0');

insert into ge_cta_dat_adicionales (NRO_CUENTA, PARAMETRO, VAL_PARAMETRO)
values ('2346009', 'NRO_SEC_CTA_MT940', '0');

insert into ge_cta_dat_adicionales (NRO_CUENTA, PARAMETRO, VAL_PARAMETRO)
values ('900321465', 'NRO_SEC_CTA_MT940', '0');

insert into ge_cta_dat_adicionales (NRO_CUENTA, PARAMETRO, VAL_PARAMETRO)
values ('900321472', 'NRO_SEC_CTA_MT940', '0');

insert into ge_cta_dat_adicionales (NRO_CUENTA, PARAMETRO, VAL_PARAMETRO)
values ('900429020', 'NRO_SEC_CTA_MT940', '0');

commit;
