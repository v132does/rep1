begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('WS_URL_INH_BCP', 'https://kongcloud-private.ind-prod-sae1.ueno.com.py/crc-connector/v1/inhabilitado-por-persona');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('ACT_SER_BCP', 'N');

commit;
