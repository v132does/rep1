begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/
update ge_par_dinamicos d set d.val_parametro = '26'
where d.parametro = 'COD_ENT_BAS_POSITIVA';


commit;
