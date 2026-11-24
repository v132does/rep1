BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('MAD_VAL_CTA_ALIAS', 'Mad. Ctas. para validar numeracion', 'GE_PAR_DINAMICOS', 'Mod. para validar numeracion de cuentas contra alias vision', 'N');

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO)
values ('MAD_VAL_CTA_ALIAS', '#31#334#41#');

commit;
