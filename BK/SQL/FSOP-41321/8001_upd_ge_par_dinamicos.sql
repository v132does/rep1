begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
update ge_par_dinamicos t
set t.val_parametro = 10000000
where t.parametro = 'SNP_MTO_UNI_TITULO';
/
commit;
