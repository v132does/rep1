BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
/
update ge_par_dinamicos h
set  h.val_parametro=replace(h.val_parametro,',309','')
where h.parametro='COD_TRA_CARGOS';
/
commit;
