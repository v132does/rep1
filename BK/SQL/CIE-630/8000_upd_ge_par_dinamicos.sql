begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
update ge_par_dinamicos a
set a.val_parametro = '15'
where a.parametro = 'PRA_CON_TRA_DEL_FEC';

commit;
