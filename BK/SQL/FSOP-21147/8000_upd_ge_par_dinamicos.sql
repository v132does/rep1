BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/

update ge_par_dinamicos d
set d.val_parametro = 24
where d.parametro = 'COD_CAU_INHIBICION';

update ge_par_dinamicos d
set d.val_parametro = 32
where d.parametro = 'COD_CAU_ONU';

commit;
