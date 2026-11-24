begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
update ge_par_dinamicos p 
set p.val_parametro=',37,39,41,42,'
where p.parametro='COD_CIR_NOT_ONB';

commit;
