begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into it.ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('ACT_COB_CTA_OPERATIVA', 'N');
/
commit;
