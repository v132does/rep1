begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

update ge_par_dinamicos t set t.val_parametro = 9617 where t.parametro = 'COD_TRA_COM_TIGO';

commit;
