BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update ge_par_dinamicos c
set c.val_parametro = 'paola.gonzalez@ueno.com.py'
where c.parametro = 'PRV_DIR_COR_RETENCION';

commit;
