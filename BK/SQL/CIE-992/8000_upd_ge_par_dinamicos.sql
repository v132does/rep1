begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
update ge_par_dinamicos a
set a.val_parametro = 'PARALLEL_EXECUTE'
where a.parametro = 'PRG_ACT_MOV_INI_PARALLEL';
commit;
